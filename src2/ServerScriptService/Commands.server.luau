-- -----------[[Clean Admin System with Global Features]]------------

-- Services
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LeaderstatsDataManager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))
local ItemSaveDataManager = require(ServerScriptService:WaitForChild("ItemSave"):WaitForChild("DataManager"))

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
		forcefish = true,
		forcerandomfish = true,
		reset = true,
		coinreset = true,
		invenreset = true,
		indexreset = true,
	},
	Moderator = {
		kick = true,
		announce = true,
		GlobalGiveCoins = true,
		SlapBattle = true,
		SlapBattleAll = true,
		DevRod = true,
		DevRodAll = true,
		forcefish = true,
		forcerandomfish = true,
		reset = true,
		coinreset = true,
		invenreset = true,
		indexreset = true,
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

	local existingTool = backpack:FindFirstChild("SlapBattle")
	if existingTool then
		return true
	end

	local clonedTool = slapBattleTool:Clone()
	clonedTool.Parent = backpack

	return true
end

local function giveSlapBattleToAllInServer(senderName)
	for _, player in pairs(Players:GetPlayers()) do
		giveSlapBattle(player, senderName)
		announceRemote:FireClient(player, string.format("Received SlapBattle from developer %s", senderName), "SYSTEM")
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

	local existingTool = backpack:FindFirstChild("DevRod")
	if existingTool then
		return true
	end

	local clonedTool = devRodTool:Clone()
	clonedTool.Parent = backpack

	return true
end

local function giveDevRodToAllInServer(senderName)
	for _, player in pairs(Players:GetPlayers()) do
		giveDevRod(player, senderName)
		announceRemote:FireClient(player, string.format("Received DevRod from developer %s", senderName), "SYSTEM")
	end
end

-- Coin functions
local function giveCoinsToAllInServer(amount, senderName)
	for _, player in pairs(Players:GetPlayers()) do
		local stats = player:FindFirstChild("leaderstats")
		if stats and stats:FindFirstChild("Coins") then
			stats.Coins.Value = stats.Coins.Value + amount
			announceRemote:FireClient(player, string.format("Received %s coins from developer %s", amount, senderName), "SYSTEM")
		end
	end
end

local function sendAnnounceToServer(message, senderName, senderRank)
	for _, player in pairs(Players:GetPlayers()) do
		announceRemote:FireClient(player, message, senderName, senderRank)
	end
end

-- Subscribe MessagingService (disabled in Studio where it doesn't work)
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
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
end

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
				if RunService:IsStudio() then
					sendAnnounceToServer(message, plr.Name, getPlayerRank(plr.Name))
				else
					local success = pcall(function()
						MessagingService:PublishAsync("GlobalAnnouncement", {
							message = message,
							senderName = plr.Name,
							senderRank = getPlayerRank(plr.Name),
							timestamp = os.time()
						})
					end)
					if not success then
						sendAnnounceToServer(message, plr.Name, getPlayerRank(plr.Name))
					end
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
			if RunService:IsStudio() then
				giveCoinsToAllInServer(amount, plr.Name)
			else
				local success = pcall(function()
					MessagingService:PublishAsync("GlobalCoinGive", {
						amount = amount,
						senderName = plr.Name,
						senderRank = getPlayerRank(plr.Name),
						timestamp = os.time()
					})
				end)
				if not success then
					giveCoinsToAllInServer(amount, plr.Name)
				end
			end
		end
	end

	-- :SlapBattleAll
	if chat:sub(1, 14) == Prefix.."SlapBattleAll" then
		if hasPermission(plr.Name, "SlapBattleAll") then
			if RunService:IsStudio() then
				giveSlapBattleToAllInServer(plr.Name)
			else
				local success = pcall(function()
					MessagingService:PublishAsync("GlobalSlapBattleGive", {
						senderName = plr.Name,
						senderRank = getPlayerRank(plr.Name),
						timestamp = os.time()
					})
				end)
				if not success then
					giveSlapBattleToAllInServer(plr.Name)
				end
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
			for _, v in pairs(foundPlayers) do
				giveSlapBattle(v, plr.Name)
			end
		end
	end

	-- :DevRodAll
	if chat:sub(1, 10) == Prefix.."DevRodAll" then
		if hasPermission(plr.Name, "DevRodAll") then
			if RunService:IsStudio() then
				giveDevRodToAllInServer(plr.Name)
			else
				local success = pcall(function()
					MessagingService:PublishAsync("GlobalDevRodGive", {
						senderName = plr.Name,
						senderRank = getPlayerRank(plr.Name),
						timestamp = os.time()
					})
				end)
				if not success then
					giveDevRodToAllInServer(plr.Name)
				end
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
			for _, v in pairs(foundPlayers) do
				giveDevRod(v, plr.Name)
			end
		end
	end

	-- :common/:uncommon/:rare/:epic/:legendary/:mystic/:fantasy/:unknown [target]
	-- Forces the next normal fish catch to that rarity (one-time)
	do
		local VALID_RARITIES = {
			common="Common", uncommon="Uncommon", rare="Rare",
			epic="Epic", legendary="Legendary", mystic="Mystic",
			fantasy="Fantasy", unknown="Unknown"
		}
		local lowerChat = chat:lower()
		for cmdKey, rarityName in pairs(VALID_RARITIES) do
			if lowerChat:sub(1, #Prefix + #cmdKey) == Prefix .. cmdKey then
				if hasPermission(plr.Name, "forcefish") then
					local args = string.split(chat, " ")
					local targetName = args[2] or plr.Name
					local foundPlayers = findPlayers(plr, targetName)
					for _, v in pairs(foundPlayers) do
						v:SetAttribute("ForcedRarity", rarityName)
					end
				end
				return
			end
		end
	end

	-- :rf <epic|legendary|mystic|fantasy|unknown> [target]
	-- Forces next RandomFish gacha pull to that rarity (one-time)
	if chat:lower():sub(1, #Prefix + 2) == Prefix .. "rf" then
		if hasPermission(plr.Name, "forcerandomfish") then
			local args = string.split(chat, " ")
			local rarityArg = args[2] and args[2]:lower()
			local targetName = args[3] or plr.Name
			local GACHA_RARITIES = {
				epic="Epic", legendary="Legendary", mystic="Mystic",
				fantasy="Fantasy", unknown="Unknown"
			}
			local forcedRarity = rarityArg and GACHA_RARITIES[rarityArg]
			if forcedRarity then
				local foundPlayers = findPlayers(plr, targetName)
				for _, v in pairs(foundPlayers) do
					v:SetAttribute("ForcedRandomFish", forcedRarity)
				end
			end
		end
	end

	-- :odds [target] — show current fish probabilities with luck applied
	if chat:lower():sub(1, #Prefix + 4) == Prefix .. "odds" then
		if hasPermission(plr.Name, "forcefish") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			local MarketplaceService = game:GetService("MarketplaceService")
			local LuckGamePassId = 1289569606

			for _, v in pairs(foundPlayers) do
				local hasLuck = false
				local ok, res = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(v.UserId, LuckGamePassId)
				end)
				if ok then hasLuck = res end
				local hasBubble = v:GetAttribute("LuckBubbleBuff") == true

				local chances
				if hasLuck then
					chances = {
						Common=37.4, Uncommon=21.07, Rare=14.33, Epic=14.0,
						Legendary=8.0, Mystic=4.0, Fantasy=1.0, Unknown=0.2
					}
				else
					chances = {
						Common=50.0, Uncommon=25.0, Rare=13.0, Epic=6.5,
						Legendary=3.0, Mystic=1.8, Fantasy=0.5, Unknown=0.1
					}
				end

				if hasBubble then
					chances.Common    = chances.Common    * 0.8
					chances.Uncommon  = chances.Uncommon  * 0.9
					chances.Rare      = chances.Rare      * 1.1
					chances.Epic      = chances.Epic      * 1.3
					chances.Legendary = chances.Legendary * 1.5
					chances.Mystic    = chances.Mystic    * 1.8
					chances.Fantasy   = chances.Fantasy   * 2.0
					chances.Unknown   = chances.Unknown   * 2.5
				end

				-- Normalize to 100%
				local total = 0
				for _, w in pairs(chances) do total += w end

				local order = {"Common","Uncommon","Rare","Epic","Legendary","Mystic","Fantasy","Unknown"}
				local lines = {string.format("=== %s Fish Odds (Luck=%s Bubble=%s) ===", v.Name, tostring(hasLuck), tostring(hasBubble))}
				for _, rarity in ipairs(order) do
					local pct = chances[rarity] / total * 100
					table.insert(lines, string.format("%s: %.2f%%", rarity, pct))
				end
				local msg = table.concat(lines, "\n")
				announceRemote:FireClient(plr, msg, "SYSTEM")
			end
		end
	end

	-- :reset [target] — full data reset (leaderstats + inventory)
	if chat:lower():sub(1, #Prefix + 5) == Prefix .. "reset" and not chat:lower():find("coinreset") and not chat:lower():find("invenreset") and not chat:lower():find("indexreset") then
		if hasPermission(plr.Name, "reset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local data = LeaderstatsDataManager:GetData(v)
				if data then
					data.Coins = 2000
					data.CurrentRod = "FishingRod"
					data.Rods = {}
					data.Fish = {}
					data.Boats = {}
					data.FishTraps = {}
					data.Playtime = 0
					data.Donations = 0
					LeaderstatsDataManager:UpdateData(v, "Coins", 2000)
				end
				local itemData = ItemSaveDataManager:GetData(v)
				if itemData then
					itemData.items = {}
					itemData.hotbarSlots = {}
					ItemSaveDataManager:UpdateData(v, "items", {})
					ItemSaveDataManager:UpdateData(v, "hotbarSlots", {})
				end
				local leaderstats = v:FindFirstChild("leaderstats")
				if leaderstats then
					local coins = leaderstats:FindFirstChild("Coins")
					if coins then coins.Value = 2000 end
					local fishFolder = leaderstats:FindFirstChild("Fish")
					if fishFolder then
						for _, fish in ipairs(fishFolder:GetChildren()) do
							if fish:IsA("BoolValue") then fish.Value = false end
						end
					end
				end
				announceRemote:FireClient(v, "Your data has been fully reset.", "SYSTEM")
			end
		end
	end

	-- :coinreset [target] — reset coins to 0
	if chat:lower():sub(1, #Prefix + 9) == Prefix .. "coinreset" then
		if hasPermission(plr.Name, "coinreset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				LeaderstatsDataManager:UpdateData(v, "Coins", 0)
				local leaderstats = v:FindFirstChild("leaderstats")
				if leaderstats then
					local coins = leaderstats:FindFirstChild("Coins")
					if coins then coins.Value = 0 end
				end
				announceRemote:FireClient(v, "Your coins have been reset.", "SYSTEM")
			end
		end
	end

	-- :invenreset [target] — reset fish inventory (ItemSave)
	if chat:lower():sub(1, #Prefix + 10) == Prefix .. "invenreset" then
		if hasPermission(plr.Name, "invenreset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local itemData = ItemSaveDataManager:GetData(v)
				if itemData then
					itemData.items = {}
					itemData.hotbarSlots = {}
					ItemSaveDataManager:UpdateData(v, "items", {})
					ItemSaveDataManager:UpdateData(v, "hotbarSlots", {})
				end
				local backpack = v:FindFirstChild("Backpack")
				if backpack then
					for _, tool in ipairs(backpack:GetChildren()) do
						if tool:IsA("Tool") and tool:FindFirstChild("FishRarity") then
							tool:Destroy()
						end
					end
				end
				announceRemote:FireClient(v, "Your fish inventory has been reset.", "SYSTEM")
			end
		end
	end

	-- :indexreset [target] — reset fish discovery catalog
	if chat:lower():sub(1, #Prefix + 10) == Prefix .. "indexreset" then
		if hasPermission(plr.Name, "indexreset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local data = LeaderstatsDataManager:GetData(v)
				if data then
					data.Fish = {}
					LeaderstatsDataManager:UpdateData(v, "Fish", {})
				end
				local leaderstats = v:FindFirstChild("leaderstats")
				if leaderstats then
					local fishFolder = leaderstats:FindFirstChild("Fish")
					if fishFolder then
						for _, fish in ipairs(fishFolder:GetChildren()) do
							if fish:IsA("BoolValue") then fish.Value = false end
						end
					end
				end
				announceRemote:FireClient(v, "Your fish catalog has been reset.", "SYSTEM")
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
