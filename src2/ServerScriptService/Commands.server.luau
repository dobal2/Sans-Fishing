-- -----------[[Clean Admin System with Global Features]]------------

-- Services
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LeaderstatsDataManager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))
local ItemSaveDataManager = require(ServerScriptService:WaitForChild("ItemSave"):WaitForChild("DataManager"))
local SkillHelper = require(ServerScriptService:WaitForChild("SkillHelper"))
local RodDataModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RodDataModule"))

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
		skillreset = true,
		rodreset = true,
		tutorialreset = true,
		updatelogreset = true,
		questreset = true,
		dailyquestreset = true,
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
					LeaderstatsDataManager:UpdateData(v, "Coins", amount)
				end
			end
		end
	end

	-- :setfp
	if chat:sub(1, 6) == Prefix.."setfp" then
		if hasPermission(plr.Name, "setcoins") then
			local args = string.split(chat, " ")
			local targetName = args[2]
			local amount = tonumber(args[3])
			if not targetName or not amount then return end
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local sp = v:FindFirstChild("SkillPoints")
				if sp then
					sp.Value = amount
					LeaderstatsDataManager:UpdateData(v, "SkillPoints", amount)
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

			local ROD_LUCK_BONUS = {
				FishingRod=0, SliverRod=0.15, GoldRod=0.30, CrystalRod=0.50,
				MagneticRod=0.60, BoneRod=0.80, CloverRod=1.05, RainbowRod=1.50,
				UnknownRod=2.20, RobuxRod=2.60, ElectricRod=3.60, RealisticRod=4.80,
				ArcaneRod=6.00, VoidRod=10.00,
			}
			local BASE_CHANCES = {
				Common=46.9, Uncommon=25, Rare=15, Epic=8,
				Legendary=3, Mystic=1.5, Fantasy=0.5, Unknown=0.1,
			}
			local RARITY_SCALE = {
				Uncommon=1.0, Rare=1.2, Epic=1.5,
				Legendary=2.0, Mystic=2.5, Fantasy=3.5, Unknown=5.0,
			}

			for _, v in pairs(foundPlayers) do
				-- Get current rod
				local ls = v:FindFirstChild("leaderstats")
				local rodName = ls and ls:FindFirstChild("CurrentRod") and ls.CurrentRod.Value or "FishingRod"
				local luckBonus = ROD_LUCK_BONUS[rodName] or 0

				-- Skills + friend bonus
				luckBonus = luckBonus + SkillHelper.GetLuckBonus(v)
				local friendBonusPerFriend = SkillHelper.GetEffect(v, "FriendBonus")
				if friendBonusPerFriend > 0 then
					local friendCount = 0
					for _, other in ipairs(Players:GetPlayers()) do
						if other ~= v then
							local ok, isFriend = pcall(function() return v:IsFriendsWith(other.UserId) end)
							if ok and isFriend then friendCount += 1 end
						end
					end
					luckBonus = luckBonus + (friendCount * friendBonusPerFriend)
				end

				-- Luck bubble
				local hasBubble = v:GetAttribute("LuckBubbleBuff") == true
				if hasBubble then luckBonus = luckBonus + 2.0 end

				-- Luck x2 gamepass
				local hasLuckPass = false
				pcall(function()
					hasLuckPass = game:GetService("MarketplaceService"):UserOwnsGamePassAsync(v.UserId, 1289569606)
				end)
				if hasLuckPass then luckBonus = luckBonus * 2 end

				-- Apply rarityScale
				local chances = {}
				for rarity, base in pairs(BASE_CHANCES) do
					local scale = RARITY_SCALE[rarity]
					if scale then
						chances[rarity] = base * (1 + luckBonus * scale)
					else
						chances[rarity] = base
					end
				end

				-- Normalize
				local total = 0
				for _, w in pairs(chances) do total += w end

				local order = {"Common","Uncommon","Rare","Epic","Legendary","Mystic","Fantasy","Unknown"}
				local lines = {string.format("=== %s | Rod:%s Luck:%.2f%s%s ===",
					v.Name, rodName, luckBonus,
					hasLuckPass and " x2pass" or "",
					hasBubble and " bubble" or ""
				)}
				for _, rarity in ipairs(order) do
					local pct = chances[rarity] / total * 100
					table.insert(lines, string.format("  %s: %.2f%%", rarity, pct))
				end
				warn(table.concat(lines, "\n"))
				announceRemote:FireClient(plr, table.concat(lines, " | "), "SYSTEM")
			end
		end
	end

	-- :skillreset [target] — 스킬 데이터만 초기화 + SkillPoints 0
	if chat:lower():sub(1, #Prefix + 10) == Prefix .. "skillreset" then
		if hasPermission(plr.Name, "skillreset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				-- Skills 폴더 초기화
				local skillsFolder = v:FindFirstChild("Skills")
				if skillsFolder then
					for _, sv in ipairs(skillsFolder:GetChildren()) do
						if sv:IsA("IntValue") then sv.Value = 0 end
					end
				end
				-- SkillPoints 초기화
				local sp = v:FindFirstChild("SkillPoints")
				if sp then sp.Value = 0 end
				-- ProfileService 데이터 반영
				local data = LeaderstatsDataManager:GetData(v)
				if data then
					data.Skills = {}
					data.SkillPoints = 0
				end
				announceRemote:FireClient(plr, "Skill reset: " .. v.Name, "SYSTEM")
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
					data.Skills = {}
					data.SkillPoints = 0
					LeaderstatsDataManager:UpdateData(v, "Coins", 2000)
					LeaderstatsDataManager:UpdateData(v, "Skills", {})
					LeaderstatsDataManager:UpdateData(v, "SkillPoints", 0)
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

	-- :rodreset [target] — reset rods to FishingRod only (VoidRod kept)
	if chat:lower():sub(1, #Prefix + 8) == Prefix .. "rodreset" then
		if hasPermission(plr.Name, "rodreset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local data = LeaderstatsDataManager:GetData(v)
				local hadVoidRod = false
				if data and data.Rods then
					hadVoidRod = data.Rods["VoidRod"] == true
					data.Rods = { FishingRod = true, VoidRod = hadVoidRod }
					data.CurrentRod = "FishingRod"
					LeaderstatsDataManager:UpdateData(v, "Rods", data.Rods)
					LeaderstatsDataManager:UpdateData(v, "CurrentRod", "FishingRod")
				end
				local leaderstats = v:FindFirstChild("leaderstats")
				if leaderstats then
					local rodsFolder = leaderstats:FindFirstChild("Rods")
					if rodsFolder then
						for _, rod in ipairs(rodsFolder:GetChildren()) do
							if rod:IsA("BoolValue") then
								if rod.Name == "FishingRod" then
									rod.Value = true
								elseif rod.Name == "VoidRod" then
									-- keep as-is
								else
									rod.Value = false
								end
							end
						end
					end
					local currentRod = leaderstats:FindFirstChild("CurrentRod")
					if currentRod then currentRod.Value = "FishingRod" end
				end
				-- Remove all rods from backpack/character except VoidRod
				for _, container in ipairs({ v:FindFirstChild("Backpack"), v.Character }) do
					if container then
						for _, tool in ipairs(container:GetChildren()) do
							if tool:IsA("Tool") and tool.Name ~= "VoidRod" then
								if RodDataModule.Rods[tool.Name] or tool.Name == "FriendRod" then
									tool:Destroy()
								end
							end
						end
					end
				end
				announceRemote:FireClient(v, "Your rods have been reset to FishingRod.", "SYSTEM")
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

	-- :tutorialreset [target] — reset tutorial flag so tutorial plays again
	if chat:lower():sub(1, #Prefix + 13) == Prefix .. "tutorialreset" then
		if hasPermission(plr.Name, "tutorialreset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local isTutorialed = v:FindFirstChild("IsTutorialed")
				if isTutorialed then isTutorialed.Value = false end
				local data = LeaderstatsDataManager:GetData(v)
				if data then
					LeaderstatsDataManager:UpdateData(v, "IsTutorialed", false)
				end
				announceRemote:FireClient(v, "Your tutorial has been reset.", "SYSTEM")
			end
		end
	end

	-- :questreset [target] — wipe all quest data (active + completed + sequential index)
	if chat:lower():sub(1, #Prefix + 10) == Prefix .. "questreset" then
		if hasPermission(plr.Name, "questreset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			local QuestDataManager = require(ServerScriptService:WaitForChild("QuestSaver"):WaitForChild("DataManager"))
			for _, v in pairs(foundPlayers) do
				local data = QuestDataManager:GetData(v)
				if data then
					data.Quests = { ActiveQuests = {}, CompletedQuests = {} }
					data.SequentialQuestIndex = 0
					data.LastQuestDate = ""
					QuestDataManager:UpdateData(v, "Quests", data.Quests)
					QuestDataManager:UpdateData(v, "SequentialQuestIndex", 0)
					QuestDataManager:UpdateData(v, "LastQuestDate", "")
				end
				local ls = v:FindFirstChild("leaderstats")
				local quests = ls and ls:FindFirstChild("Quests")
				if quests then
					local aq = quests:FindFirstChild("ActiveQuests")
					local cq = quests:FindFirstChild("CompletedQuests")
					if aq then for _, c in pairs(aq:GetChildren()) do c:Destroy() end end
					if cq then for _, c in pairs(cq:GetChildren()) do c:Destroy() end end
				end
				announceRemote:FireClient(v, "Quest data reset.", "SYSTEM")
			end
		end
	end

	-- :dailyquestreset [target] — reset daily quest so a new one is assigned
	if chat:lower():sub(1, #Prefix + 15) == Prefix .. "dailyquestreset" then
		if hasPermission(plr.Name, "dailyquestreset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			local QuestDataManager = require(ServerScriptService:WaitForChild("QuestSaver"):WaitForChild("DataManager"))
			for _, v in pairs(foundPlayers) do
				local data = QuestDataManager:GetData(v)
				if data then
					data.LastQuestDate = ""
					QuestDataManager:UpdateData(v, "LastQuestDate", "")
					if data.Quests and data.Quests.ActiveQuests then
						data.Quests.ActiveQuests["daily_random_quest"] = nil
						data.Quests.ActiveQuests["daily_playtime_15min"] = nil
						QuestDataManager:UpdateData(v, "Quests", data.Quests)
					end
				end
				local ls = v:FindFirstChild("leaderstats")
				local quests = ls and ls:FindFirstChild("Quests")
				local aq = quests and quests:FindFirstChild("ActiveQuests")
				if aq then
					local dq = aq:FindFirstChild("daily_random_quest") or aq:FindFirstChild("daily_playtime_15min")
					if dq then dq:Destroy() end
				end
				announceRemote:FireClient(v, "Daily quest reset.", "SYSTEM")
			end
		end
	end

	-- :updatelogreset [target] — reset SeenUpdateLog so update log shows again
	if chat:lower():sub(1, #Prefix + 14) == Prefix .. "updatelogreset" then
		if hasPermission(plr.Name, "updatelogreset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local seenFlag = v:FindFirstChild("SeenUpdateLog")
				if seenFlag then seenFlag.Value = false end
				local data = LeaderstatsDataManager:GetData(v)
				if data then
					LeaderstatsDataManager:UpdateData(v, "SeenUpdateLog", false)
				end
				announceRemote:FireClient(v, "Your update log has been reset.", "SYSTEM")
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
