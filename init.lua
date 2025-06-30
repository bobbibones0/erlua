local erlua = {
	GlobalKey = nil,
	serverKey = nil
}

local http = require("coro-http")
local json = require("json")
local timer = require("timer")

<<<<<<< Updated upstream
local RateLimits = {}
_G.ERLUARateLimits = RateLimits

=======
>>>>>>> Stashed changes
local Queue = {}
local Ratelimits = {}

<<<<<<< Updated upstream
local timeoutTime = 10

--[[ Utility Functions ]] --
=======
--[[
if not success or type(response) ~= "table" or response.code then
  return false, response
end
]]

--[[ Utility Functions ]]
--
>>>>>>> Stashed changes

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

<<<<<<< Updated upstream
function split(str, delim)
  local ret = {}
  if not str then
      return ret
  end
  if not delim or delim == '' then
      for c in string.gmatch(str, '.') do
          table.insert(ret, c)
      end
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

local function Error(code, message)
  log(message, "error")
  return { code = code, message = message }
end

local function RateLimited(bucket)
  if (bucket) and (RateLimits[bucket]) and (RateLimits[bucket].remaining) and (RateLimits[bucket].reset) and (os.time() < RateLimits[bucket].reset) and (RateLimits[bucket].remaining < 1) then
      return true
  else
      return false
  end
end

local function updateRateLimit(result, bucket)
  local rateLimitBucket = bucket or getHeader(result, "X-RateLimit-Bucket")
  local rateLimitRemaining = getHeader(result, "X-RateLimit-Remaining")
  local rateLimitReset = getHeader(result, "X-RateLimit-Reset")

  if rateLimitBucket and rateLimitRemaining and rateLimitReset and tonumber(rateLimitRemaining) and tonumber(rateLimitReset) then
      RateLimits[rateLimitBucket] = {
          remaining = tonumber(rateLimitRemaining),
          reset = tonumber(rateLimitReset) + 0.2
      }
  end

  _G.ERLUARateLimits = RateLimits
end

local function getBucket(method, serverkey, globalkey)
  local bucket

  if method == "POST" then
      bucket = "command-" .. (serverkey or erlua.ServerKey)
  elseif globalkey or erlua.GlobalKey then
      bucket = "global"
  else
      bucket = "unauthenticated-global"
  end

  return bucket
end

local junkletters = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
  "U", "V", "W", "X", "Y", "Z" }
local junknums = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }

local function junkStr(len)
  local str = ""
  for i = 1, len do
      local letornum = math.random(1, 2)
      if letornum == 1 then
          local randomlet = junkletters[math.random(1, #junkletters)]
          local caporlow = math.random(1, 2)
          if caporlow == 1 then
              str = str .. randomlet
          else
              str = str .. randomlet:lower()
          end
      else
          local randomnum = junknums[math.random(1, #junknums)]
          str = str .. randomnum
      end
  end

  return str
=======
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
>>>>>>> Stashed changes
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
	serverKey = (serverKey or erlua.ServerKey) or nil
	globalKey = (globalKey or erlua.GlobalKey) or nil
	if not serverKey then return false, Error(400, "A server key was not provided.") end

<<<<<<< Updated upstream
  if (not serverkey) and (not erlua.ServerKey) then
    return false, Error(400, "A server key was not provided to " .. method .. " /" .. endpoint .. ".")
  else
    table.insert(headers, { "Server-Key", serverkey or erlua.ServerKey })
  end
=======
	local url = "https://api.policeroleplay.community/v1/" .. endpoint
	local headers = {
		{
			"Content-Type",
			"application/json"
		}
	}
>>>>>>> Stashed changes

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

<<<<<<< Updated upstream
  if RateLimited(bucket) then
    log("Bucket " .. bucket:sub(1, 7) .. " is being ratelimited.", "warning")
    if bucket:sub(1, 7) == "command" then
      log("Queuing command post request.", "warning")

      local id = junkStr(10)

      Queue[bucket] = Queue[bucket] or { active = false, requests = {} }

      table.insert(Queue[bucket].requests, id)

      local startTime = os.time()

      repeat
        timer.sleep(20)
      until ((Queue[bucket].requests[1] == id) and not RateLimited(bucket) and not Queue[bucket].active) or os.time() - startTime >= timeoutTime

      if os.time() - startTime >= timeoutTime then
        for i, req in ipairs(Queue[bucket].requests) do
            if req == id then
                table.remove(Queue[bucket].requests, i)
                break
            end
        end
        return false, Error(4001, "Queued command post requested timed-out.")
    end

      Queue[bucket].active = true

      table.remove(Queue[bucket].requests, 1)

      log("Executing ratelimited request " .. id, "info")

      local success, response = self:request(method, endpoint, body, serverkey, globalkey)

      Queue[bucket].active = false

      return success, response
    else
      return false, Error(4001, "The resource is being ratelimited.")
    end
  end


  if globalkey or erlua.GlobalKey then
    table.insert(headers, { "Authorization", globalkey or erlua.GlobalKey })
  end

  if method == "POST" then
    table.insert(headers, { "Content-Type", "application/json" })
  end

  if type(body) == "table" then
    local success, encoded = pcall(json.encode, body)

    if not success then
      return false, Error(500, "Body could not be encoded.")
    else
      body = encoded
    end
  end

  local _, result, response = pcall(function()
    return http.request(method, url, headers, body, {
        timeout = 2500,
        followRedirects = true
    })
  end)

  if type(response) == "string" then
    local success, decoded = pcall(json.decode, response)

    if not success then
      return false, Error(500, "Response could not be decoded.")
    else
      response = decoded
    end
  end

  updateRateLimit(result, bucket)

  if result.code == 200 then
    return true, response
  elseif result.code == 404 then
    return false, Error(404, "Endpoint /" .. endpoint .. " was not found. (" .. url .. ")")
  elseif response and response.code == 4001 then
    log("PRC API returned a ratelimit on bucket: " .. bucket:sub(1, 7), "error")
    if bucket:sub(1, 7) == "command" then
      log("Queuing command post request.", "warning")

      local id = junkStr(10)

      Queue[bucket] = Queue[bucket] or { active = false, requests = {} }

      table.insert(Queue[bucket].requests, id)

      local startTime = os.time()
      
      repeat
          timer.sleep(20)
      until ((Queue[bucket].requests[1] == id) and not RateLimited(bucket) and not Queue[bucket].active) 
          or (os.time() - startTime >= timeoutTime)
      
      if os.time() - startTime >= timeoutTime then
          for i, req in ipairs(Queue[bucket].requests) do
              if req == id then
                  table.remove(Queue[bucket].requests, i)
                  break
              end
          end
          return false, Error(4001, "Queued command post requested timed-out.")
      end

      Queue[bucket].active = true

      table.remove(Queue[bucket].requests, 1)

      log("Executing ratelimited request " .. id, "info")

      local success, response = self:request(method, endpoint, body, serverkey, globalkey)

      Queue[bucket].active = false

      return success, response
    else
      return false, Error(4001, "The resource is being ratelimited.")
    end
  elseif response and response.code then
    return false, response
  elseif result.code and result.reason then
    return false, Error(result.code, result.reason)
  else
    return false, Error(444, "The PRC API did not respond.")
  end
=======
	local result, response = http.request(method, url, headers, (body and json.decode(body)) or nil)
	response = response and json.decode(response)

	if result.code == 200 then
		if process then response = process(response) end

		callback(true, response, result)
		return true, result, response
	else
		callback(false, response, result)
		return false, result, response
	end
>>>>>>> Stashed changes
end

function erlua:queue(request)
	log("Request " .. request.method .. " /" .. request.endpoint .. " queued.", "info")
	request.timestamp = request.timestamp or os.time()

	table.insert(Queue, request)
	return #Queue
end

function erlua:dump()
	log("Scanning queue for a runnable request...", "info")
	table.sort(Queue, function(a, b) return a.timestamp < b.timestamp end)

	local now = realtime()
	local idx, req, state

	for i, oldest in ipairs(Queue) do
		local b = (oldest.method == "POST" and "bucket-" .. oldest.serverKey) or (oldest.globalKey and "global") or "unauthenticated-global"
		state = Ratelimits[b]

		if not (state and state.updated and state.retry and now < (state.updated + state.retry)) then
			idx = i
			req = oldest
			break
		end
	end

	if not req then
		local soonest = math.huge
		for _, state in pairs(Ratelimits) do
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

	local ok, result, response = erlua:request(req.method, req.endpoint, req.body, req.callback, req.process, req.serverKey, req.globalKey)

	local headers = result.headers or {}
	local bucket = header(headers, "X-RateLimit-Bucket")
	local remaining = header(headers, "X-RateLimit-Remaining")
	local reset = header(headers, "X-RateLimit-Reset")

	if bucket and remaining and reset then
		Ratelimits[bucket] = {
			updated = realtime(),
			retry = response and response.retry_after,
			remaining = tonumber(remaining),
			reset = tonumber(reset)
		}
		log("The " .. bucket .. "bucket has been updated: " .. remaining .. " left, resets in " .. (reset - os.time()) .. " seconds.")
	end

	if not ok and result.code == 429 then
		log("The " .. (bucket or "unknown") .. " bucket has been ratelimited, requeueing request.", "warning")
	else
		table.remove(Queue, idx)
	end
end

coroutine.wrap(function()
	while true do
		if #Queue > 0 then erlua:dump() end

		timer.sleep(500)
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

<<<<<<< Updated upstream
  if not success or type(response) ~= "table" or response.code then
      return false, response
  end

  table.sort(response, function(a, b)
      if (not a.Timestamp) or (not b.Timestamp) then
          return false
      else
          return a.Timestamp < b.Timestamp
      end
  end)

  return true, response
=======
			return data
		end
	})
>>>>>>> Stashed changes
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

<<<<<<< Updated upstream
  if not success or type(response) ~= "table" or response.code then
      return false, response
  end

  table.sort(response, function(a, b)
      if (not a.Timestamp) or (not b.Timestamp) then
          return false
      else
          return a.Timestamp < b.Timestamp
      end
  end)

  return true, response
=======
			return data
		end
	})
>>>>>>> Stashed changes
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

<<<<<<< Updated upstream
  if not success or type(response) ~= "table" or response.code then
      return false, response
  end

  table.sort(response, function(a, b)
      if (not a.Timestamp) or (not b.Timestamp) then
          return false
      else
          return a.Timestamp < b.Timestamp
      end
  end)

  return true, response
=======
			return data
		end
	})
>>>>>>> Stashed changes
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

<<<<<<< Updated upstream
  if not success or type(response) ~= "table" or response.code then
      return false, response
  end

  table.sort(response, function(a, b)
      if (not a.Timestamp) or (not b.Timestamp) then
          return false
      else
          return a.Timestamp < b.Timestamp
      end
  end)

  return true, response
=======
			return data
		end
	})
>>>>>>> Stashed changes
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
	local function process(success, response)
		if success and response then
			local staff = {}

			for _, player in pairs(response) do if player.Permission and (player.Permission ~= "Normal") then table.insert(staff, player) end end

			callback(success, staff)
		else
			callback(success, response)
		end
	end

	if preloadPlayers then
		process(true, preloadPlayers)
		return 0
	else
		return erlua.Players(process, serverKey, globalKey)
	end
end

<<<<<<< Updated upstream
function erlua.Team(teamName, serverKey, globalKey, preloadPlayers)
  if (not teamName) or (not table.find({ "civilian", "police", "sheriff", "fire", "dot", "jail" }, teamName:lower())) then
      return
          Error(400, "An invalid team name ('" .. tostring(teamName) .. "') was provided.")
  end
=======
function erlua.Team(callback, teamName, serverKey, globalKey, preloadPlayers)
	if not teamName or (not table.find({
		"civilian",
		"police",
		"sheriff",
		"fire",
		"dot",
		"jail"
	}, teamName:lower())) then callback(false, Error(400, "An invalid team name ('" .. tostring(teamName) .. "') was provided.")) end
>>>>>>> Stashed changes

	local function process(success, response)
		if success and response then
			local team = {}

			for _, player in pairs(response) do if player.Team and (player.Team:lower() == teamName:lower()) then table.insert(team, player) end end

			callback(success, team)
		else
			callback(success, response)
		end
	end

<<<<<<< Updated upstream

  if not players then
      return false, players
  end

  for _, player in pairs(players) do
      if (player.Team) and (player.Team:lower() == teamName:lower()) then
          table.insert(team, player)
      end
  end

  return true, team
=======
	if preloadPlayers then
		process(true, preloadPlayers)
		return 0
	else
		return erlua.Players(process, serverKey, globalKey)
	end
>>>>>>> Stashed changes
end

function erlua.TrollUsernames(callback, serverKey, globalKey, preloadPlayers)
	local function process(success, response)
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

<<<<<<< Updated upstream

  if not players then
      return false, players
  end

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
=======
					if startsWithAll or startsWithOthers or total >= 2 then table.insert(trolls, player) end
				end
			end

			callback(success, response)
		else
			callback(success, response)
		end
	end
>>>>>>> Stashed changes

	if preloadPlayers then
		process(true, preloadPlayers)
		return 0
	else
		return erlua.Players(process, serverKey, globalKey)
	end
end

<<<<<<< Updated upstream
function erlua.Command(command, serverKey, globalKey)
  if command:sub(1,1) ~= ":" then
    command = ":" .. command
  end

  return erlua:request("POST", "server/command", { command = command }, serverKey, globalKey)
=======
function erlua.Command(callback, command, serverKey, globalKey)
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
>>>>>>> Stashed changes
end

return erlua