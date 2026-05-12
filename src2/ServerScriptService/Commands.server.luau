-- -----------[[Clean Admin System with Global Features]]------------

-- Services
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- Create/get announcement remote event
local announceRemote = ReplicatedStorage:FindFirstChild("AnnounceRemote")
if not announceRemote then
	announceRemote = Instance.new("RemoteEvent")
	announceRemote.Name = "AnnounceRemote"
	announceRemote.Parent = ReplicatedStorage
end

-- Permission setup
local Ranks = {
	Developer = {"tallmo_bim", "mkdoingsu"},
	Moderator = {},
}

local Permissions = {
	Developer = {
		speed = true,
		ang = true,
		kick = true,
		setcoins = true,
		announce = true,
		GlobalGiveCoins = true,
		SlapBattle = true,
		SlapBattleAll = true,
		DevRod = true,
		DevRodAll = true,
	},
	Moderator = {
		kick = true,
		announce = true,
		GlobalGiveCoins = true,
		SlapBattle = true,
		SlapBattleAll = true,
		DevRod = true,
		DevRodAll = true,
	}
}

local Prefix = ":"

-- Utility functions
local function getPlayerRank(playerName)
	for rank, players in pairs(Ranks) do
		for _, name in pairs(players) do
			if name == playerName then
				return rank
			end
		end
	end
	return nil
end

local function hasPermission(playerName, command)
	local rank = getPlayerRank(playerName)
	if not rank then return false end
	return Permissions[rank] and Permissions[rank][command] == true
end

local function findPlayers(executor, targetName)
	local foundPlayers = {}

	if targetName:lower() == "me" then
		table.insert(foundPlayers, executor)
		return foundPlayers
	end

	if targetName:lower() == "all" then
		for _, player in pairs(Players:GetPlayers()) do
			table.insert(foundPlayers, player)
		end
		return foundPlayers
	end

	for _, player in pairs(Players:GetPlayers()) do
		if player.Name:lower():sub(1, #targetName) == targetName:lower() then
			table.insert(foundPlayers, player)
		end
	end

	return foundPlayers
end

-- SlapBattle functions
local function giveSlapBattle(targetPlayer, executorName)
	local slapBattleTool = ServerStorage:FindFirstChild("SlapBattle")

	if not slapBattleTool then
		warn("SlapBattle tool not found in ServerStorage!")
		return false
	end

	local backpack = targetPlayer:FindFirstChild("Backpack")
	if not backpack then
		warn("Player backpack not found:", targetPlayer.Name)
		return false
	end

	-- Check for duplicates
	local existingTool = backpack:FindFirstChild("SlapBattle")
	if existingTool then
		return true
	end

	-- Clone and give SlapBattle
	local clonedTool = slapBattleTool:Clone()
	clonedTool.Parent = backpack

	return true
end

local function giveSlapBattleToAllInServer(senderName)
	local successCount = 0
	local failCount = 0

	for _, player in pairs(Players:GetPlayers()) do
		if giveSlapBattle(player, senderName) then
			successCount = successCount + 1
		else
			failCount = failCount + 1
		end

		-- Notify player
		local message = string.format("Received SlapBattle from developer %s", senderName)
		announceRemote:FireClient(player, message, "SYSTEM")
	end

end

-- DevRod functions
local function giveDevRod(targetPlayer, executorName)
	local devRodTool = ServerStorage:FindFirstChild("DevRod")

	if not devRodTool then
		warn("DevRod tool not found in ServerStorage!")
		return false
	end

	local backpack = targetPlayer:FindFirstChild("Backpack")
	if not backpack then
		warn("Player backpack not found:", targetPlayer.Name)
		return false
	end

	-- Check for duplicates
	local existingTool = backpack:FindFirstChild("DevRod")
	if existingTool then
		return true
	end

	-- Clone and give DevRod
	local clonedTool = devRodTool:Clone()
	clonedTool.Parent = backpack

	return true
end

local function giveDevRodToAllInServer(senderName)
	local successCount = 0
	local failCount = 0

	for _, player in pairs(Players:GetPlayers()) do
		if giveDevRod(player, senderName) then
			successCount = successCount + 1
		else
			failCount = failCount + 1
		end

		-- Notify player
		local message = string.format("Received DevRod from developer %s", senderName)
		announceRemote:FireClient(player, message, "SYSTEM")
	end

end

-- Coin functions
local function giveCoinsToAllInServer(amount, senderName)
	local playersAffected = 0

	for _, player in pairs(Players:GetPlayers()) do
		local stats = player:FindFirstChild("leaderstats")
		if stats and stats:FindFirstChild("Coins") then
			stats.Coins.Value = stats.Coins.Value + amount
			playersAffected = playersAffected + 1

			local message = string.format("Received %s coins from developer %s", amount, senderName)
			announceRemote:FireClient(player, message, "SYSTEM")
		end
	end

end

local function sendAnnounceToServer(message, senderName, senderRank)
	for _, player in pairs(Players:GetPlayers()) do
		announceRemote:FireClient(player, message, senderName, senderRank)
	end
end

-- Subscribe MessagingService
MessagingService:SubscribeAsync("GlobalAnnouncement", function(data)
	local messageData = data.Data
	sendAnnounceToServer(messageData.message, messageData.senderName, messageData.senderRank)
end)

MessagingService:SubscribeAsync("GlobalCoinGive", function(data)
	local coinData = data.Data
	giveCoinsToAllInServer(coinData.amount, coinData.senderName)
end)

MessagingService:SubscribeAsync("GlobalSlapBattleGive", function(data)
	local slapData = data.Data
	giveSlapBattleToAllInServer(slapData.senderName)
end)

MessagingService:SubscribeAsync("GlobalDevRodGive", function(data)
	local devRodData = data.Data
	giveDevRodToAllInServer(devRodData.senderName)
end)

-- Command handler
local function command(plr, chat)
	if not chat:find(Prefix) then return end

	-- :speed
	if chat:sub(1, 6) == Prefix.."speed" then
		if hasPermission(plr.Name, "speed") then
			local args = string.split(chat, " ")
			local targetName = args[2]
			local speed = tonumber(args[3]) or 16

			if not targetName then return end

			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				if v.Character and v.Character:FindFirstChild("Humanoid") then
					v.Character.Humanoid.WalkSpeed = speed
				end
			end
		end
	end

	-- :ang
	if chat:sub(1, 4) == Prefix.."ang" then
		if hasPermission(plr.Name, "ang") then
			local args = string.split(chat, " ")
			local targetName = args[2]

			if not targetName then return end

			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				if v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
					local explosion = Instance.new("Explosion")
					explosion.Position = v.Character.HumanoidRootPart.Position
					explosion.BlastRadius = 50
					explosion.BlastPressure = 1000000
					explosion.Parent = workspace
				end
			end
		end
	end

	-- :kick
	if chat:sub(1, 5) == Prefix.."kick" then
		if hasPermission(plr.Name, "kick") then
			local args = string.split(chat, " ")
			local targetName = args[2]
			local reason = table.concat(args, " ", 3) or "No reason provided"

			if not targetName or targetName:lower() == "all" then return end

			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				v:Kick("You have been kicked by " .. plr.Name .. ". Reason: " .. reason)
			end
		end
	end

	-- :setcoins
	if chat:sub(1, 9) == Prefix.."setcoins" then
		if hasPermission(plr.Name, "setcoins") then
			local args = string.split(chat, " ")
			local targetName = args[2]
			local amount = tonumber(args[3])

			if not targetName or not amount then return end

			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local stats = v:FindFirstChild("leaderstats")
				if stats and stats:FindFirstChild("Coins") then
					stats.Coins.Value = amount
				end
			end
		end
	end

	-- :announce
	if chat:sub(1, 9) == Prefix.."announce" then
		if hasPermission(plr.Name, "announce") then
			local message = chat:sub(11)

			if message and message:len() > 0 then
				local success, errorMessage = pcall(function()
					MessagingService:PublishAsync("GlobalAnnouncement", {
						message = message,
						senderName = plr.Name,
						senderRank = getPlayerRank(plr.Name),
						timestamp = os.time()
					})
				end)

				if not success then
					warn("MessagingService error:", errorMessage)
				end
			end
		end
	end

	-- :GlobalGiveCoins
	if chat:find("^"..Prefix.."GlobalGiveCoins") then
		if hasPermission(plr.Name, "GlobalGiveCoins") then
			local args = string.split(chat, " ")
			local amount = tonumber(args[2])

			if not amount or amount <= 0 then return end

			local success, errorMessage = pcall(function()
				MessagingService:PublishAsync("GlobalCoinGive", {
					amount = amount,
					senderName = plr.Name,
					senderRank = getPlayerRank(plr.Name),
					timestamp = os.time()
				})
			end)

			if not success then
				warn("MessagingService error:", errorMessage)
			end
		end
	end

	-- :SlapBattleAll
	if chat:sub(1, 14) == Prefix.."SlapBattleAll" then
		if hasPermission(plr.Name, "SlapBattleAll") then
			local success, errorMessage = pcall(function()
				MessagingService:PublishAsync("GlobalSlapBattleGive", {
					senderName = plr.Name,
					senderRank = getPlayerRank(plr.Name),
					timestamp = os.time()
				})
			end)

			if not success then
				warn("MessagingService error:", errorMessage)
				-- Fallback: give to current server only
				giveSlapBattleToAllInServer(plr.Name)
			end
		end
	end

	-- :SlapBattle
	if chat:sub(1, 11) == Prefix.."SlapBattle" and not chat:find("SlapBattleAll") then
		if hasPermission(plr.Name, "SlapBattle") then
			local args = string.split(chat, " ")
			local targetName = args[2]

			if not targetName then return end

			local foundPlayers = findPlayers(plr, targetName)
			local successCount = 0
			local failCount = 0

			for _, v in pairs(foundPlayers) do
				if giveSlapBattle(v, plr.Name) then
					successCount = successCount + 1
				else
					failCount = failCount + 1
				end
			end

		end
	end

	-- :DevRodAll
	if chat:sub(1, 10) == Prefix.."DevRodAll" then
		if hasPermission(plr.Name, "DevRodAll") then
			local success, errorMessage = pcall(function()
				MessagingService:PublishAsync("GlobalDevRodGive", {
					senderName = plr.Name,
					senderRank = getPlayerRank(plr.Name),
					timestamp = os.time()
				})
			end)

			if not success then
				warn("MessagingService error:", errorMessage)
				-- Fallback: give to current server only
				giveDevRodToAllInServer(plr.Name)
			end
		end
	end

	-- :DevRod
	if chat:sub(1, 7) == Prefix.."DevRod" and not chat:find("DevRodAll") then
		if hasPermission(plr.Name, "DevRod") then
			local args = string.split(chat, " ")
			local targetName = args[2]

			if not targetName then return end

			local foundPlayers = findPlayers(plr, targetName)
			local successCount = 0
			local failCount = 0

			for _, v in pairs(foundPlayers) do
				if giveDevRod(v, plr.Name) then
					successCount = successCount + 1
				else
					failCount = failCount + 1
				end
			end

		end
	end
end

-- Connect player events
Players.PlayerAdded:Connect(function(plr)
	local rank = getPlayerRank(plr.Name)
	if rank then
		plr.Chatted:Connect(function(msg)
			command(plr, msg)
		end)
	end
end)
