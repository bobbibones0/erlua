local erlua = {
	GlobalKey = nil,
	ServerKey = nil,
	Requests = {},
	Ratelimits = {}
}

local http = require("coro-http")
local json = require("json")
local timer = require("timer")

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

	if mode == "success" then
		print(date .. " | \27[32m\27[1m[ERLUA]\27[0m | " .. text)
	elseif mode == "warning" then
		print(date .. " | \27[33m\27[1m[ERLUA]\27[0m | " .. text)
	elseif mode == "error" then
		print(date .. " | \27[31m\27[1m[ERLUA]\27[0m | " .. text)
	elseif mode == "info" then
		print(date .. " | \27[35m\27[1m[ERLUA]\27[0m | " .. text)
	end
end

local function split(str, delim)
	local ret = {}
	if not str then return ret end
	if not delim or delim == "" then
		for c in string.gmatch(str, ".") do table.insert(ret, c) end
		return ret
	end
	local n = 1
	while true do
		local i, j = string.find(str, delim, n)
		if not i then break end
		table.insert(ret, string.sub(str, n, i - 1))
		n = j + 1
	end
	table.insert(ret, string.sub(str, n))
	return ret
end

local function header(headers, name) for _, header in pairs(headers) do if header[1]:lower() == name:lower() then return header[2] end end end

local function realtime()
	local seconds, microseconds = uv.gettimeofday()

	return seconds + (microseconds / 1000000)
end

local function Error(code, message)
	log(message, "error")
	return {
		code = code,
		message = message
	}
end

local function defer(fn)
	timer.setTimeout(0, fn)
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

function erlua:request(method, endpoint, body, callback, process, serverKey, globalKey)
	callback = callback or function() end
	serverKey = (serverKey or erlua.ServerKey) or nil
	globalKey = (globalKey or erlua.GlobalKey) or nil
	if not serverKey then return false, Error(400, "A server key was not provided.") end

	local url = "https://api.policeroleplay.community/v1/" .. endpoint
	local headers = {
		{
			"Content-Type",
			"application/json"
		}
	}

	table.insert(headers, {
		"Server-Key",
		serverKey
	})
	if globalKey then
		table.insert(headers, {
			"Authorization",
			globalKey
		})
	end

	log("Requesting " .. method .. " /" .. endpoint .. ".", "info")
	local result, response = http.request(method, url, headers, (body and json.encode(body)) or nil)
	response = response and json.decode(response)

	if result.code == 200 then
		if process then response = process(response) end

		callback(true, response, result)
		return true, result, response
	else
		callback(false, response, result)
		return false, result, response
	end
end

function erlua:queue(request)
	log("Request " .. request.method .. " /" .. request.endpoint .. " queued.", "info")
	request.timestamp = request.timestamp or os.time()

	table.insert(erlua.Requests, request)
	return #erlua.Requests
end

function erlua:dump()
	log("Scanning queue for a runnable request...", "info")
	table.sort(erlua.Requests, function(a, b) return a.timestamp < b.timestamp end)

	local now = realtime()
	local idx, req, state

	for i, oldest in ipairs(erlua.Requests) do
		local b = (oldest.method == "POST" and "bucket-" .. oldest.serverKey) or (oldest.globalKey and "global") or "unauthenticated-global"
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
				if unblock > now and unblock < soonest then soonest = unblock end
			end
		end
		if soonest < math.huge then
			local wait = soonest - now
			log("All buckets have been ratelimited, sleeping for " .. wait .. " seconds.", "warning")
			timer.sleep(wait * 1000)
		end
		return
	end

	if not req then return end

	local ok, result, response = erlua:request(req.method, req.endpoint, req.body, req.callback, req.process, req.serverKey, req.globalKey)
	
	local headers = result or {}
	local bucket = header(headers, "X-RateLimit-Bucket")
	local remaining = header(headers, "X-RateLimit-Remaining")
	local reset = header(headers, "X-RateLimit-Reset")

	if bucket and remaining and reset then
		erlua.Ratelimits[bucket] = {
			updated = realtime(),
			retry = response and response.retry_after,
			remaining = tonumber(remaining),
			reset = tonumber(reset)
		}
		log("The " .. (bucket:match("^(.-)%-") or bucket) .. " bucket has been updated: " .. remaining .. " left, resets in " .. (reset - os.time()) .. " seconds.")
	end

	if not ok and result.code == 429 then
		log("The " .. (bucket or "unknown") .. " bucket has been ratelimited, requeueing request.", "warning")
	else
		log("Request " .. req.method .. " /" .. req.endpoint .. " fulfilled.")
		table.remove(erlua.Requests, idx)
	end
end

coroutine.wrap(function()
	while true do
		if #erlua.Requests > 0 then erlua:dump() end

		timer.sleep(100)
	end
end)()

-- [[ Endpoint Functions ]] --

function erlua.Server(callback, serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server",
		serverKey = serverKey,
		globalkey = globalKey,
		callback = callback
	})
end

function erlua.Players(callback, serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/players",
		serverKey = serverKey,
		globalkey = globalKey,
		callback = callback,
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
						Team = player.Team
					})
				end
			end

			return players
		end
	})
end

function erlua.Vehicles(callback, serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/vehicles",
		serverKey = serverKey,
		globalkey = globalKey,
		callback = callback
	})
end

function erlua.PlayerLogs(callback, serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/joinlogs",
		serverKey = serverKey,
		globalkey = globalKey,
		callback = callback,
		process = function(data)
			table.sort(data, function(a, b)
				if (not a.Timestamp) or not b.Timestamp then
					return false
				else
					return a.Timestamp < b.Timestamp
				end
			end)

			return data
		end
	})
end

function erlua.KillLogs(callback, serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/killlogs",
		serverKey = serverKey,
		globalkey = globalKey,
		callback = callback,
		process = function(data)
			table.sort(data, function(a, b)
				if (not a.Timestamp) or not b.Timestamp then
					return false
				else
					return a.Timestamp < b.Timestamp
				end
			end)

			return data
		end
	})
end

function erlua.CommandLogs(callback, serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/commandlogs",
		serverKey = serverKey,
		globalkey = globalKey,
		callback = callback,
		process = function(data)
			table.sort(data, function(a, b)
				if (not a.Timestamp) or not b.Timestamp then
					return false
				else
					return a.Timestamp < b.Timestamp
				end
			end)

			return data
		end
	})
end

function erlua.ModCalls(callback, serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/modcalls",
		serverKey = serverKey,
		globalkey = globalKey,
		callback = callback,
		process = function(data)
			table.sort(data, function(a, b)
				if (not a.Timestamp) or not b.Timestamp then
					return false
				else
					return a.Timestamp < b.Timestamp
				end
			end)

			return data
		end
	})
end

function erlua.Bans(callback, serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/bans",
		serverKey = serverKey,
		globalkey = globalKey,
		callback = callback
	})
end

function erlua.Queue(callback, serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/queue",
		serverKey = serverKey,
		globalkey = globalKey,
		callback = callback
	})
end

-- [[ Custom Functions ]] --

function erlua.Staff(callback, serverKey, globalKey, preloadPlayers)
	local function process(success, response, result)
		if success and response then
			local staff = {}

			for _, player in pairs(response) do if player.Permission and (player.Permission ~= "Normal") then table.insert(staff, player) end end

			callback(success, staff, result)
		else
			callback(success, response, result)
		end
	end

	if preloadPlayers then
		defer(function()
			process(true, preloadPlayers, {code = 200})
		end)
		return 0
	else
		return erlua.Players(process, serverKey, globalKey)
	end
end

function erlua.Team(callback, serverKey, globalKey, teamName, preloadPlayers)
	if not teamName or (not table.find({
		"civilian",
		"police",
		"sheriff",
		"fire",
		"dot",
		"jail"
	}, teamName:lower())) then
	 	callback(false, Error(400, "An invalid team name ('" .. tostring(teamName) .. "') was provided."), Error(400, "An invalid team name ('" .. tostring(teamName) .. "') was provided."))
		return 0
	end

	local function process(success, response, result)
		if success and response then
			local team = {}

			for _, player in pairs(response) do if player.Team and (player.Team:lower() == teamName:lower()) then table.insert(team, player) end end

			callback(success, team, result)
		else
			callback(success, response, result)
		end
	end

	if preloadPlayers then
		defer(function()
			process(true, preloadPlayers, {code = 200, message = "Ok"})
		end)
		return 0
	else
		return erlua.Players(process, serverKey, globalKey)
	end
end

function erlua.TrollUsernames(callback, serverKey, globalKey, preloadPlayers)
	local function process(success, response, result)
		if success and response then
			local trolls = {}

			for _, player in pairs(response) do
				local name = player.Player
				if name then
					local lname = name:lower()
					local startsWithAll = lname:sub(1, 3) == "all"
					local startsWithOthers = lname:sub(1, 6) == "others"

					local countIl = select(2, name:gsub("Il", ""))
					local countlI = select(2, name:gsub("lI", ""))
					local total = countIl + countlI

					if startsWithAll or startsWithOthers or total >= 2 then table.insert(trolls, player) end
				end
			end

			callback(success, trolls, result)
		else
			callback(success, response, result)
		end
	end

	if preloadPlayers then
		defer(function ()
			process(true, preloadPlayers, {code = 200, message = "Ok"})
		end)
		return 0
	else
		return erlua.Players(process, serverKey, globalKey)
	end
end

function erlua.Command(command, callback, serverKey, globalKey)
	return erlua:queue({
		method = "POST",
		endpoint = "server/command",
		body = {
			command = (command:sub(1, 1) == ":" and command) or (":" .. command)
		},
		serverKey = serverKey,
		globalkey = globalKey,
		callback = callback
	})
end

return erlua
