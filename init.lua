local erlua = {
	GlobalKey = nil,
	ServerKey = nil,
	LogLevel = 0,
	Requests = {},
	Ratelimits = {},
	validTeams = {
		civilian = true,
		police = true,
		sheriff = true,
		fire = true,
		dot = true,
		jail = true,
	},
}

--[[
	Log Levels:
	- Error = 2
	- Warning = 1
	- Info = 0
]]

local http = require("coro-http")
local json = require("json")
local timer = require("timer")
local uv = require("uv")

--[[
if not success or type(response) ~= "table" or response.code then
  return false, response
end
]]

--[[ Utility Functions ]]
--

local function log(text, mode)
	mode = mode or "info"

	local date = os.date("%x @ %I:%M:%S%p", os.time())

	if mode == "success" then -- unused??
		print(date .. " | \27[32m\27[1m[ERLUA]\27[0m | " .. text)
	elseif mode == "info" and not (erlua.LogLevel > 0) then
		print(date .. " | \27[35m\27[1m[ERLUA]\27[0m | " .. text)
	elseif mode == "warning" and not (erlua.LogLevel > 1) then
		print(date .. " | \27[33m\27[1m[ERLUA]\27[0m | " .. text)
	elseif mode == "error" then
		print(date .. " | \27[31m\27[1m[ERLUA]\27[0m | " .. text)
	end
end

local function split(str, delim)
	local ret = {}
	if not str then
		return ret
	end
	if not delim or delim == "" then
		for c in string.gmatch(str, ".") do
			table.insert(ret, c)
		end
		return ret
	end
	local n = 1
	while true do
		local i, j = string.find(str, delim, n)
		if not i then
			break
		end
		table.insert(ret, string.sub(str, n, i - 1))
		n = j + 1
	end
	table.insert(ret, string.sub(str, n))
	return ret
end

local function header(headers, name)
	for _, header in pairs(headers) do
		if type(header) == "table" and type(header[1]) == "string" and header[1]:lower() == name:lower() then
			return header[2]
		end
	end
end

local function realtime()
	local seconds, microseconds = uv.gettimeofday()

	return seconds + (microseconds / 1000000)
end

local function Error(code, message)
	log(message, "error")
	return {
		code = code,
		message = message,
	}
end

local function safeResume(co, ...)
	if type(co) ~= "thread" then return false, "Invalid coroutine" end
	if coroutine.status(co) ~= "suspended" then return false, "Coroutine not suspended" end

	local ok, result = coroutine.resume(co, ...)
	if not ok then
		return false, result
	end
	return true, result
end

-- [[ ERLua Functions ]] --

function erlua:SetGlobalKey(gk)
	erlua.GlobalKey = gk
	log("Set global key to [HIDDEN].", "info")
	return erlua
end

function erlua:SetServerKey(sk)
	erlua.ServerKey = sk
	log("Set server key to [HIDDEN].", "info")
	return erlua
end

function erlua:setLogLevel(logLevel)
	if tonumber(logLevel) and tonumber(logLevel) >= 0 and tonumber(logLevel) < 3 then
		erlua.LogLevel = tonumber(logLevel)
	elseif type(logLevel) == "string" then
		if logLevel:lower() == "info" then
			erlua.LogLevel = 0
		elseif logLevel:lower() == "warning" then
			erlua.LogLevel = 1
		elseif logLevel:lower() == "error" then
			erlua.LogLevel = 2
		end
	end

	return erlua
end

function erlua:request(method, endpoint, body, process, serverKey, globalKey)
	serverKey = (serverKey or erlua.ServerKey) or nil
	globalKey = (globalKey or erlua.GlobalKey) or nil
	if not serverKey then
		return false, Error(400, "A server key was not provided.")
	end

	local url = "https://api.policeroleplay.community/v1/" .. endpoint
	local headers = {
		{ "Content-Type", "application/json" },
		{ "Server-Key", serverKey },
	}
	if globalKey then
		table.insert(headers, { "Authorization", globalKey })
	end

	log("Requesting " .. method .. " /" .. endpoint .. ".", "info")
	local result, response = http.request(method, url, headers, (body and json.encode(body)) or nil)
	response = response and json.decode(response)

	if result.code == 200 then
		if process then
			response = process(response)
		end
		return true, result, response
	else
		return false, result, response
	end
end

function erlua:queue(request)
	log("Request " .. request.method .. " /" .. request.endpoint .. " queued.", "info")
	request.timestamp = request.timestamp or os.time()
	request.co = coroutine.running()
	assert(request.co, "erlua:queue must be called from inside a coroutine")
	table.insert(erlua.Requests, request)
	return coroutine.yield()
end

function erlua:dump()
	log("Scanning queue for a runnable request...", "info")
	table.sort(erlua.Requests, function(a, b)
		return a.timestamp < b.timestamp
	end)

	local now = realtime()
	local idx, req, state

	for i, oldest in ipairs(erlua.Requests) do
		local b = (oldest.method == "POST" and "command-" .. oldest.serverKey or "unauthorized")
			or ((erlua.GlobalKey or oldest.globalKey) and "global")
			or "unauthenticated-global"
		state = erlua.Ratelimits[b]

		if not state or not state.updated or not state.retry or now >= (state.updated + state.retry) then
			idx = i
			req = oldest
			break
		end
	end

	if not req then
		local soonest = math.huge
		for _, state in pairs(erlua.Ratelimits) do
			if state.updated and state.retry then
				local unblock = state.updated + state.retry
				if unblock > now and unblock < soonest then
					soonest = unblock
				end
			end
		end
		if soonest < math.huge then
			local wait = soonest - now
			log("All buckets have been ratelimited, sleeping for " .. wait .. " seconds.", "warning")
			timer.sleep(wait * 1000)
		end
		return
	end

	local ok, result, response =
		erlua:request(req.method, req.endpoint, req.body, req.process, req.serverKey, req.globalKey)

	local headers = result or {}
	local bucket = header(headers, "X-RateLimit-Bucket")
	local remaining = header(headers, "X-RateLimit-Remaining")
	local reset = header(headers, "X-RateLimit-Reset")

	if bucket and remaining and reset then
		erlua.Ratelimits[bucket] = {
			updated = realtime(),
			retry = response and response.retry_after,
			remaining = tonumber(remaining),
			reset = tonumber(reset),
		}
		log(
			"The "
				.. (bucket:match("^(.-)%-") or bucket)
				.. " bucket has been updated: "
				.. remaining
				.. " left, resets in "
				.. (reset - os.time())
				.. " seconds."
		)
	end

	if not ok and result.code == 429 then
		log("The " .. (bucket or "unknown") .. " bucket has been ratelimited, requeueing request.", "warning")
	else
		log("Request " .. req.method .. " /" .. req.endpoint .. " fulfilled.")
		table.remove(erlua.Requests, idx)
	end

	safeResume(req.co, ok, response, result)
end

coroutine.wrap(function()
	while true do
		if #erlua.Requests > 0 then
			erlua:dump()
		end

		timer.sleep(5)
	end
end)()

-- [[ Endpoint Functions ]] --

function erlua.Server(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server",
		serverKey = serverKey,
		globalKey = globalKey,
	})
end

function erlua.Players(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/players",
		serverKey = serverKey,
		globalKey = globalKey,
		process = function(data)
			local players = {}

			for _, player in pairs(data) do
				if player.Player then
					table.insert(players, {
						Name = split(player.Player, ":")[1],
						ID = split(player.Player, ":")[2],
						Player = player.Player,
						Permission = player.Permission,
						Callsign = player.Callsign,
						Team = player.Team,
					})
				end
			end

			return players
		end,
	})
end

function erlua.Vehicles(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/vehicles",
		serverKey = serverKey,
		globalKey = globalKey,
	})
end

function erlua.PlayerLogs(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/joinlogs",
		serverKey = serverKey,
		globalKey = globalKey,
		process = function(data)
			table.sort(data, function(a, b)
				if (not a.Timestamp) or not b.Timestamp then
					return false
				else
					return a.Timestamp < b.Timestamp
				end
			end)

			return data
		end,
	})
end

function erlua.KillLogs(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/killlogs",
		serverKey = serverKey,
		globalKey = globalKey,
		process = function(data)
			table.sort(data, function(a, b)
				if (not a.Timestamp) or not b.Timestamp then
					return false
				else
					return a.Timestamp < b.Timestamp
				end
			end)

			return data
		end,
	})
end

function erlua.CommandLogs(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/commandlogs",
		serverKey = serverKey,
		globalKey = globalKey,
		process = function(data)
			table.sort(data, function(a, b)
				if (not a.Timestamp) or not b.Timestamp then
					return false
				else
					return a.Timestamp < b.Timestamp
				end
			end)

			return data
		end,
	})
end

function erlua.ModCalls(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/modcalls",
		serverKey = serverKey,
		globalKey = globalKey,
		process = function(data)
			table.sort(data, function(a, b)
				if (not a.Timestamp) or not b.Timestamp then
					return false
				else
					return a.Timestamp < b.Timestamp
				end
			end)

			return data
		end,
	})
end

function erlua.Bans(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/bans",
		serverKey = serverKey,
		globalKey = globalKey,
	})
end

function erlua.Queue(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/queue",
		serverKey = serverKey,
		globalKey = globalKey,
	})
end

-- [[ Custom Functions ]] --

function erlua.Staff(serverKey, globalKey, preloadPlayers)
	local players
	local result
	if preloadPlayers then
		players = preloadPlayers
	else
		local ok
		ok, players, result = erlua.Players(serverKey, globalKey)
		if not ok then
			return ok, players, result
		end
	end

	local staff = {}

	for _, player in pairs(players) do
		if player.Permission and player.Permission ~= "Normal" then
			table.insert(staff, player)
		end
	end

	return true, staff, result
end

function erlua.Team(serverKey, globalKey, teamName, preloadPlayers)
	if not teamName or not erlua.validTeams[teamName:lower()] then
		return false, Error(400, "An invalid team name ('" .. tostring(teamName) .. "') was provided.")
	end

	local players
	local result
	if preloadPlayers then
		players = preloadPlayers
	else
		local ok
		ok, players, result = erlua.Players(serverKey, globalKey)
		if not ok then
			return ok, players, result
		end
	end

	local team = {}
	local teamNameLower = teamName:lower()

	for _, player in pairs(players) do
		if player.Team and player.Team:lower() == teamNameLower then
			table.insert(team, player)
		end
	end

	return true, team, result
end

function erlua.TrollUsernames(serverKey, globalKey, preloadPlayers)
	local players
	local result
	if preloadPlayers then
		players = preloadPlayers
	else
		local ok
		ok, players, result = erlua.Players(serverKey, globalKey)
		if not ok then
			return ok, players, result
		end
	end

	local trolls = {}

	for _, player in pairs(players) do
		local name = player.Player
		if name then
			local lname = name:lower()
			local startsWithAll = lname:sub(1, 3) == "all"
			local startsWithOthers = lname:sub(1, 6) == "others"

			local countIl = select(2, name:gsub("Il", ""))
			local countlI = select(2, name:gsub("lI", ""))
			local total = countIl + countlI

			if startsWithAll or startsWithOthers or total >= 2 then
				table.insert(trolls, player)
			end
		end
	end

	return true, trolls, result
end

function erlua.Command(command, serverKey, globalKey)
	return erlua:queue({
		method = "POST",
		endpoint = "server/command",
		body = {
			command = (command:sub(1, 1) == ":" and command) or (":" .. command),
		},
		serverKey = serverKey,
		globalKey = globalKey,
	})
end

return erlua