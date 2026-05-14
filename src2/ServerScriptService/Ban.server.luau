local ADMINS = {1853104124}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local banStore = DataStoreService:GetDataStore("TestBannedUsers")

local function banPlayer(player)
	player:Kick("You've been banned!")
	local ok, err = pcall(function()
		banStore:SetAsync(player.UserId, true)
	end)
	if not ok then warn("Ban SetAsync failed:", err) end
end

local function unbanPlayer(id)
	local numId = tonumber(id)
	if not numId then return end
	local ok, err = pcall(function()
		banStore:SetAsync(numId, false)
	end)
	if not ok then warn("Unban SetAsync failed:", err) end
end

Players.PlayerAdded:Connect(function(player)
	local ok, banData = pcall(function()
		return banStore:GetAsync(player.UserId)
	end)
	if ok and banData then
		player:Kick("You've been banned by creator")
		return
	elseif not ok then
		warn("Ban GetAsync failed for", player.Name, banData)
	end

	if not table.find(ADMINS, player.UserId) then return end

	player.Chatted:Connect(function(msg)
		local splitMsg = string.split(msg, " ")
		local command = string.lower(splitMsg[1])

		if command == ":ban" then
			local username = splitMsg[2]
			if not username then return end
			local playerBanned = Players:FindFirstChild(username)
			if playerBanned then
				banPlayer(playerBanned)
			end

		elseif command == ":unban" then
			local id = splitMsg[2]
			if id then unbanPlayer(id) end
		end
	end)
end)
