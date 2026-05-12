local ADMINS = {1853104124} -- Admin list by UserId

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local banStore = DataStoreService:GetDataStore("TestBannedUsers")

-- Permanently ban a player
local function banPlayer(player)
	player:Kick("You've been banned!")
	banStore:SetAsync(player.UserId, true)
end

-- Unban a player
local function unbanPlayer(id)
	banStore:SetAsync(tonumber(id), false)
end

-- Check ban status when player joins
Players.PlayerAdded:Connect(function(player)
	local banData = banStore:GetAsync(player.UserId)
	if banData then
		player:Kick("You've been banned by creator")
	end

	-- Handle admin commands
	player.Chatted:Connect(function(msg)
		if not table.find(ADMINS, player.UserId) then return end

		local splitMsg = string.split(msg, " ")
		local command = string.lower(splitMsg[1])

		if command == ":ban" then
			local username = splitMsg[2]
			local playerBanned = Players:FindFirstChild(username)
			if playerBanned then
				banPlayer(playerBanned)
			end

		elseif command == ":unban" then
			local id = splitMsg[2]
			unbanPlayer(id)
		end
	end)
end)
