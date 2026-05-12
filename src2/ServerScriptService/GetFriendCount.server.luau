-- ServerScript (Place in ServerScriptService)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteFunction
local getFriendsCountRemote = Instance.new("RemoteFunction")
getFriendsCountRemote.Name = "GetFriendsCountRemote"
getFriendsCountRemote.Parent = ReplicatedStorage

-- Rate limiting system
local playerCooldowns = {}
local COOLDOWN_TIME = 3  -- 3 second cooldown
local MAX_REQUESTS_PER_MINUTE = 20  -- Max 20 requests per minute
local playerRequestCounts = {}

-- Count online friends function
local function getFriendsOnlineCount(player)
	local friendsCount = 0

	-- Check all players currently in the server
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			-- Check if friend
			local success, isFriend = pcall(function()
				return player:IsFriendsWith(otherPlayer.UserId)
			end)

			if success and isFriend then
				friendsCount = friendsCount + 1
			end
		end
	end

	return friendsCount
end

-- Rate limit check function
local function isRateLimited(player)
	local userId = player.UserId
	local currentTime = tick()

	-- Cooldown check
	if playerCooldowns[userId] and currentTime - playerCooldowns[userId] < COOLDOWN_TIME then
		local remainingTime = COOLDOWN_TIME - (currentTime - playerCooldowns[userId])
		--warn(player.Name .. " is on cooldown (remaining: " .. math.ceil(remainingTime) .. "s)")
		return true
	end

	-- Check request count per minute
	if not playerRequestCounts[userId] then
		playerRequestCounts[userId] = {requests = {}, count = 0}
	end

	local requests = playerRequestCounts[userId].requests

	-- Remove requests older than 1 minute
	for i = #requests, 1, -1 do
		if currentTime - requests[i] > 60 then
			table.remove(requests, i)
		end
	end

	-- Check request count
	if #requests >= MAX_REQUESTS_PER_MINUTE then
		warn(player.Name .. " exceeded max requests per minute (" .. #requests .. "/" .. MAX_REQUESTS_PER_MINUTE .. ")")
		return true
	end

	return false
end

-- Record request function
local function recordRequest(player)
	local userId = player.UserId
	local currentTime = tick()

	playerCooldowns[userId] = currentTime

	if not playerRequestCounts[userId] then
		playerRequestCounts[userId] = {requests = {}}
	end

	table.insert(playerRequestCounts[userId].requests, currentTime)
end

-- Handle client request
getFriendsCountRemote.OnServerInvoke = function(player)
	-- Rate limit check
	if isRateLimited(player) then
		return 0  -- Return 0 if limited
	end

	-- Record request
	recordRequest(player)

	-- Count friends
	local friendsCount = getFriendsOnlineCount(player)
	--print(player.Name .. " online friends:", friendsCount, "(bonus: " .. (friendsCount * 5) .. "%)")
	return friendsCount
end

-- Clean up data when player leaves
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	playerCooldowns[userId] = nil
	playerRequestCounts[userId] = nil
	--print(player.Name .. " data cleaned up")
end)
