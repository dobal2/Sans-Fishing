local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local getFriendsCountRemote = Instance.new("RemoteFunction")
getFriendsCountRemote.Name = "GetFriendsCountRemote"
getFriendsCountRemote.Parent = ReplicatedStorage

-- Cache: userId → Set of friend userIds
local friendCache = {}

local function loadFriendCache(player)
	local userId = player.UserId
	local friendSet = {}

	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(userId)
	end)

	if not ok then
		warn("GetFriendsAsync failed for", player.Name, pages)
		friendCache[userId] = friendSet
		return
	end

	local safeRead = true
	while safeRead do
		local pageOk, items = pcall(function()
			return pages:GetCurrentPage()
		end)
		if not pageOk then break end
		for _, item in ipairs(items) do
			friendSet[item.Id] = true
		end
		if pages.IsFinished then break end
		local advOk = pcall(function() pages:AdvanceToNextPageAsync() end)
		if not advOk then break end
	end

	friendCache[userId] = friendSet
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		loadFriendCache(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	friendCache[player.UserId] = nil
end)

-- Preload for players already in game (server script start timing)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		loadFriendCache(player)
	end)
end

local playerCooldowns = {}
local COOLDOWN_TIME = 5

getFriendsCountRemote.OnServerInvoke = function(player)
	local userId = player.UserId
	local now = tick()

	if playerCooldowns[userId] and now - playerCooldowns[userId] < COOLDOWN_TIME then
		-- Return cached count without recomputing
		local cache = friendCache[userId]
		if not cache then return 0 end
		local count = 0
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and cache[other.UserId] then
				count += 1
			end
		end
		return count
	end

	playerCooldowns[userId] = now

	local cache = friendCache[userId]
	if not cache then
		-- Cache not loaded yet, try loading now
		loadFriendCache(player)
		cache = friendCache[userId] or {}
	end

	local count = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and cache[other.UserId] then
			count += 1
		end
	end
	return count
end
