-- -----------[[Clean Admin System with Global Features]]------------

-- Services
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LeaderstatsDataManager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))
local ItemSaveDataManager = require(ServerScriptService:WaitForChild("ItemSave"):WaitForChild("DataManager"))
local FishTrapDataManager = require(ServerScriptService:WaitForChild("FishTrapManager"):WaitForChild("DataManager"))
local SkillHelper = require(ServerScriptService:WaitForChild("SkillHelper"))
local RodDataModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RodDataModule"))
local FishDataModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDataModule"))

-- Create/get announcement remote event
local announceRemote = ReplicatedStorage:FindFirstChild("AnnounceRemote")
if not announceRemote then
	announceRemote = Instance.new("RemoteEvent")
	announceRemote.Name = "AnnounceRemote"
	announceRemote.Parent = ReplicatedStorage
end

-- Permission setup (UserId-based — immune to username changes)
local Ranks = {
	Developer = {1853104124, 1330397992},
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
		givefriendrod = true,
		forcefish = true,
		forcerandomfish = true,
		giverandom = true,
		reset = true,
		coinreset = true,
		invenreset = true,
		indexreset = true,
		indexfill = true,
		skillreset = true,
		rodreset = true,
		tutorialreset = true,
		updatelogreset = true,
		questreset = true,
		dailyquestreset = true,
		dailyquestcomplete = true,
		dailyquestgive = true,
		afkreconnect = true,
		trapfill = true,
		setstreak = true,
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
		giverandom = true,
		reset = true,
		coinreset = true,
		invenreset = true,
		indexreset = true,
		indexfill = true,
	}
}

local Prefix = ":"

-- Utility functions
local function getPlayerRank(player)
	local userId = player.UserId
	for rank, ids in pairs(Ranks) do
		for _, id in pairs(ids) do
			if id == userId then
				return rank
			end
		end
	end
	return nil
end

local function hasPermission(player, command)
	local rank = getPlayerRank(player)
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

-- FriendRod functions
local function giveFriendRod(targetPlayer, executorName)
	local friendRodTool = ServerStorage:FindFirstChild("FriendRod")
	if not friendRodTool then
		warn("FriendRod tool not found in ServerStorage!")
		return false
	end

	local backpack = targetPlayer:FindFirstChild("Backpack")
	if not backpack then return false end

	-- Rods 폴더에 FriendRod BoolValue true로 세팅 (저장 포함)
	local ls = targetPlayer:FindFirstChild("leaderstats")
	local rodsFolder = ls and ls:FindFirstChild("Rods")
	local friendBool = rodsFolder and rodsFolder:FindFirstChild("FriendRod")
	if friendBool then
		friendBool.Value = true
	end

	-- ProfileService에 즉시 저장
	local data = LeaderstatsDataManager:GetData(targetPlayer)
	if data then
		if not data.Rods then data.Rods = {} end
		data.Rods["FriendRod"] = true
		LeaderstatsDataManager:UpdateData(targetPlayer, "Rods", data.Rods)
	end

	-- Backpack에 없으면 지급
	if not backpack:FindFirstChild("FriendRod") then
		local clone = friendRodTool:Clone()
		clone.Parent = backpack
	end

	announceRemote:FireClient(targetPlayer, string.format("FriendRod granted by %s", executorName), "SYSTEM")
	return true
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
			LeaderstatsDataManager:UpdateData(player, "Coins", stats.Coins.Value)
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
		if hasPermission(plr, "speed") then
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
		if hasPermission(plr, "ang") then
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
		if hasPermission(plr, "kick") then
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
		if hasPermission(plr, "setcoins") then
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
		if hasPermission(plr, "setcoins") then
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
		if hasPermission(plr, "announce") then
			local message = chat:sub(11)
			if message and message:len() > 0 then
				if RunService:IsStudio() then
					sendAnnounceToServer(message, plr.Name, getPlayerRank(plr))
				else
					local success = pcall(function()
						MessagingService:PublishAsync("GlobalAnnouncement", {
							message = message,
							senderName = plr.Name,
							senderRank = getPlayerRank(plr),
							timestamp = os.time()
						})
					end)
					if not success then
						sendAnnounceToServer(message, plr.Name, getPlayerRank(plr))
					end
				end
			end
		end
	end

	-- :GlobalGiveCoins
	if chat:find("^"..Prefix.."GlobalGiveCoins") then
		if hasPermission(plr, "GlobalGiveCoins") then
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
						senderRank = getPlayerRank(plr),
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
		if hasPermission(plr, "SlapBattleAll") then
			if RunService:IsStudio() then
				giveSlapBattleToAllInServer(plr.Name)
			else
				local success = pcall(function()
					MessagingService:PublishAsync("GlobalSlapBattleGive", {
						senderName = plr.Name,
						senderRank = getPlayerRank(plr),
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
		if hasPermission(plr, "SlapBattle") then
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
		if hasPermission(plr, "DevRodAll") then
			if RunService:IsStudio() then
				giveDevRodToAllInServer(plr.Name)
			else
				local success = pcall(function()
					MessagingService:PublishAsync("GlobalDevRodGive", {
						senderName = plr.Name,
						senderRank = getPlayerRank(plr),
						timestamp = os.time()
					})
				end)
				if not success then
					giveDevRodToAllInServer(plr.Name)
				end
			end
		end
	end

	-- :givefriendrod [player]
	if chat:sub(1, 14) == Prefix.."givefriendrod" then
		if hasPermission(plr, "givefriendrod") then
			local args = string.split(chat, " ")
			local targetName = args[2]
			if not targetName then return end
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				giveFriendRod(v, plr.Name)
			end
		end
	end

	-- :DevRod
	if chat:sub(1, 7) == Prefix.."DevRod" and not chat:find("DevRodAll") then
		if hasPermission(plr, "DevRod") then
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
				if hasPermission(plr, "forcefish") then
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
		if hasPermission(plr, "forcerandomfish") then
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

	-- :giverandom [count] [rarity] [target]
	if chat:lower():sub(1, #Prefix + 10) == Prefix .. "giverandom" then
		if hasPermission(plr, "giverandom") then
			local args = string.split(chat, " ")
			local GACHA_RARITIES = {
				epic="Epic", legendary="Legendary", mystic="Mystic",
				fantasy="Fantasy", unknown="Unknown"
			}
			local count = 1
			local forcedRarity = nil
			local targetName = plr.Name
			local parsedCount = false

			-- Parse remaining args: count (number), rarity (string), target (player name)
			for i = 2, #args do
				local arg = args[i]
				local asNum = tonumber(arg)
				if asNum and not parsedCount then
					count = math.clamp(math.floor(asNum), 1, 100)
					parsedCount = true
				elseif GACHA_RARITIES[arg:lower()] and not forcedRarity then
					forcedRarity = GACHA_RARITIES[arg:lower()]
				else
					targetName = arg
				end
			end

			local giveRandomBindable = ServerScriptService:FindFirstChild("GiveRandomFishBindable")
			if not giveRandomBindable then
				warn(":giverandom — GiveRandomFishBindable not found")
				return
			end

			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				pcall(function()
					giveRandomBindable:Invoke(v, count, forcedRarity)
				end)
			end
		end
	end

	-- :odds [target] — show current fish probabilities with luck applied
	if chat:lower():sub(1, #Prefix + 4) == Prefix .. "odds" then
		if hasPermission(plr, "forcefish") then
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
		if hasPermission(plr, "skillreset") then
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
				LeaderstatsDataManager:UpdateData(v, "Skills", {})
				LeaderstatsDataManager:UpdateData(v, "SkillPoints", 0)
				announceRemote:FireClient(plr, "Skill reset: " .. v.Name, "SYSTEM")
			end
		end
	end

	-- :reset [target] — full data reset (leaderstats + inventory)
	local resetWord = chat:lower():match("^" .. Prefix .. "(%a+)")
	if resetWord == "reset" then
		if hasPermission(plr, "reset") then
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
		if hasPermission(plr, "coinreset") then
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
		if hasPermission(plr, "invenreset") then
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
		if hasPermission(plr, "rodreset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local data = LeaderstatsDataManager:GetData(v)
				local hadVoidRod = false
				local hadFriendRod = false
				if data and data.Rods then
					hadVoidRod = data.Rods["VoidRod"] == true
					hadFriendRod = data.Rods["FriendRod"] == true
					data.Rods = { FishingRod = true, VoidRod = hadVoidRod, FriendRod = hadFriendRod }
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
								elseif rod.Name == "VoidRod" or rod.Name == "FriendRod" then
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
				-- Remove all rods from backpack/character except VoidRod and FriendRod
				for _, container in ipairs({ v:FindFirstChild("Backpack"), v.Character }) do
					if container then
						for _, tool in ipairs(container:GetChildren()) do
							if tool:IsA("Tool") and tool.Name ~= "VoidRod" and tool.Name ~= "FriendRod" then
								if RodDataModule.Rods[tool.Name] then
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

	-- :setstreak [target] [count] — set a player's catch streak (server + display)
	if chat:lower():sub(1, #Prefix + 9) == Prefix .. "setstreak" then
		if hasPermission(plr, "setstreak") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local count = tonumber(args[3]) or 0
			local streakEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("StreakUpdateEvent")
			local ok_fs, FishingServerModule = pcall(function()
				return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishingServerModule"))
			end)
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				if ok_fs and FishingServerModule then
					FishingServerModule.playerStreaks[v.UserId] = count
					LeaderstatsDataManager:UpdateData(v, "FishStreak", count)
				end
				streakEvent:FireClient(v, count)
				announceRemote:FireClient(plr, string.format("Set %s streak to %d.", v.Name, count), "SYSTEM")
			end
		end
	end

	-- :indexreset [target] — reset fish discovery catalog + claimed
	if chat:lower():sub(1, #Prefix + 10) == Prefix .. "indexreset" then
		if hasPermission(plr, "indexreset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local data = LeaderstatsDataManager:GetData(v)
				if data then
					data.Fish = {}
					data.DiscoveryClaimed = {}
					LeaderstatsDataManager:UpdateData(v, "Fish", {})
					LeaderstatsDataManager:UpdateData(v, "DiscoveryClaimed", {})
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

	-- :indexfill [target] — fill entire fish catalog (all fish discovered, not claimed)
	if chat:lower():sub(1, #Prefix + 9) == Prefix .. "indexfill" then
		if hasPermission(plr, "indexfill") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local data = LeaderstatsDataManager:GetData(v)
				local leaderstats = v:FindFirstChild("leaderstats")
				local fishFolder = leaderstats and leaderstats:FindFirstChild("Fish")
				if fishFolder then
					local fishData = {}
					for _, fishBool in ipairs(fishFolder:GetChildren()) do
						if fishBool:IsA("BoolValue") then
							fishBool.Value = true
							fishData[fishBool.Name] = true
						end
					end
					if data then
						data.DiscoveryClaimed = {}
						LeaderstatsDataManager:UpdateData(v, "Fish", fishData)
						LeaderstatsDataManager:UpdateData(v, "DiscoveryClaimed", {})
					end
				end
				announceRemote:FireClient(v, "All fish have been added to your catalog.", "SYSTEM")
			end
		end
	end

	-- :afkreconnect [target] — force auto-reconnect teleport (test AFK prevention)
	if chat:lower():sub(1, #Prefix + 12) == Prefix .. "afkreconnect" then
		if hasPermission(plr, "afkreconnect") then
			local TeleportService = game:GetService("TeleportService")
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local char = v.Character
				local rodName = nil
				-- 1. 현재 들고 있는 로드 확인
				if char then
					for _, obj in ipairs(char:GetChildren()) do
						if obj:IsA("Tool") and obj:FindFirstChild("CastRod") then
							rodName = obj.Name
							break
						end
					end
				end
				-- 2. 없으면 백팩에서 확인
				if not rodName then
					local bp = v:FindFirstChild("Backpack")
					if bp then
						for _, obj in ipairs(bp:GetChildren()) do
							if obj:IsA("Tool") and obj:FindFirstChild("CastRod") then
								rodName = obj.Name
								break
							end
						end
					end
				end
				-- 3. 그래도 없으면 leaderstats CurrentRod → storageName 변환
				if not rodName then
					local ls = v:FindFirstChild("leaderstats")
					local currentRod = ls and ls:FindFirstChild("CurrentRod")
					if currentRod and currentRod.Value ~= "" then
						local rodData = RodDataModule[currentRod.Value]
						rodName = (rodData and rodData.storageName) or currentRod.Value
					end
				end
				local options = Instance.new("TeleportOptions")
				options:SetTeleportData({ autoReconnect = true, rodName = rodName })
				local ok, err = pcall(function()
					TeleportService:TeleportAsync(game.PlaceId, { v }, options)
				end)
				if not ok then
					announceRemote:FireClient(plr, "Teleport failed: " .. tostring(err), "SYSTEM")
				end
			end
		end
	end

	-- :tutorialreset [target] — reset tutorial flag so tutorial plays again
	if chat:lower():sub(1, #Prefix + 13) == Prefix .. "tutorialreset" then
		if hasPermission(plr, "tutorialreset") then
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
		if hasPermission(plr, "questreset") then
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
		if hasPermission(plr, "dailyquestreset") then
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

	-- :dailyquestcomplete [target] — instantly complete the daily quest and give reward
	if chat:lower():sub(1, #Prefix + 18) == Prefix .. "dailyquestcomplete" then
		if hasPermission(plr, "dailyquestcomplete") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			local QuestDataManager = require(ServerScriptService:WaitForChild("QuestSaver"):WaitForChild("DataManager"))
			local LeaderstatsDataManager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))
			for _, v in pairs(foundPlayers) do
				local ls = v:FindFirstChild("leaderstats")
				local quests = ls and ls:FindFirstChild("Quests")
				local aq = quests and quests:FindFirstChild("ActiveQuests")
				local folder = aq and aq:FindFirstChild("daily_random_quest")
				if folder then
					local rewardCoinsVal = folder:FindFirstChild("RewardCoins")
					local rewardCoins = rewardCoinsVal and rewardCoinsVal.Value or 100000
					local coins = ls and ls:FindFirstChild("Coins")
					if coins then
						coins.Value = coins.Value + rewardCoins
						LeaderstatsDataManager:UpdateData(v, "Coins", coins.Value)
					end
					local data = QuestDataManager:GetData(v)
					if data and data.Quests then
						data.Quests.ActiveQuests = data.Quests.ActiveQuests or {}
						data.Quests.CompletedQuests = data.Quests.CompletedQuests or {}
						data.Quests.ActiveQuests["daily_random_quest"] = nil
						data.Quests.CompletedQuests["daily_random_quest"] = true
						QuestDataManager:UpdateData(v, "Quests", data.Quests)
						QuestDataManager:SaveData(v)
					end
					-- leaderstats CompletedQuests 폴더에도 기록 (SafeSavePlayer가 이 폴더를 읽어 저장하기 때문)
					local completedQuestsFolder = quests and quests:FindFirstChild("CompletedQuests")
					if completedQuestsFolder then
						local bv = completedQuestsFolder:FindFirstChild("daily_random_quest") or Instance.new("BoolValue")
						bv.Name = "daily_random_quest"
						bv.Value = true
						bv.Parent = completedQuestsFolder
					end
					folder:Destroy()
					announceRemote:FireClient(v, "Daily quest completed! +" .. tostring(rewardCoins) .. " Coins", "SYSTEM")
				else
					announceRemote:FireClient(plr, v.Name .. " has no active daily quest.", "SYSTEM")
				end
			end
		end
	end

	-- :dailyquestgive [target] — remove existing daily quest and give a fresh one immediately
	if chat:lower():sub(1, #Prefix + 14) == Prefix .. "dailyquestgive" then
		if hasPermission(plr, "dailyquestgive") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			local QuestDataManager = require(ServerScriptService:WaitForChild("QuestSaver"):WaitForChild("DataManager"))
			for _, v in pairs(foundPlayers) do
				-- 데이터에서 완료 기록 + 기존 퀘 제거
				local data = QuestDataManager:GetData(v)
				if data then
					if not data.Quests then data.Quests = {} end
					if not data.Quests.ActiveQuests then data.Quests.ActiveQuests = {} end
					if not data.Quests.CompletedQuests then data.Quests.CompletedQuests = {} end
					data.Quests.ActiveQuests["daily_random_quest"] = nil
					data.Quests.CompletedQuests["daily_random_quest"] = nil
					QuestDataManager:UpdateData(v, "Quests", data.Quests)
				end

				-- leaderstats 폴더에서도 제거
				local ls = v:FindFirstChild("leaderstats")
				local quests = ls and ls:FindFirstChild("Quests")
				local aq = quests and quests:FindFirstChild("ActiveQuests")
				local cq = quests and quests:FindFirstChild("CompletedQuests")
				if aq then
					local old = aq:FindFirstChild("daily_random_quest")
					if old then old:Destroy() end
				end
				if cq then
					local oldC = cq:FindFirstChild("daily_random_quest")
					if oldC then oldC:Destroy() end
				end

				-- 새 퀘스트 즉시 생성
				if aq then
					local newQuest = {
						id               = "daily_random_quest",
						name             = "Daily Playtime",
						description      = "Play for 10 minutes today",
						targetFish       = "",
						requiredProgress = 10,
						rewardCoins      = 100000,
						rewardFP         = 0,
						isReceived       = true,
						currentProgress  = 0,
						questType        = "daily_playtime",
						subType          = "playtime",
						targetRarity     = "",
					}
					local questFolder = Instance.new("Folder")
					questFolder.Name = "daily_random_quest"
					local function sv(n, val) local o = Instance.new("StringValue") o.Name = n o.Value = val o.Parent = questFolder end
					local function iv(n, val) local o = Instance.new("IntValue")  o.Name = n o.Value = val o.Parent = questFolder end
					local function bv(n, val) local o = Instance.new("BoolValue")  o.Name = n o.Value = val o.Parent = questFolder end
					sv("QuestName", "Daily Playtime")
					sv("QuestDescription", "Play for 10 minutes today")
					sv("TargetFish", "")
					sv("QuestType", "daily_playtime")
					sv("SubType", "playtime")
					sv("TargetRarity", "")
					iv("CurrentProgress", 0)
					iv("RequiredProgress", 10)
					iv("RewardCoins", 100000)
					iv("RewardFP", 0)
					bv("IsReceived", true)
					questFolder.Parent = aq

					if data then
						data.Quests.ActiveQuests["daily_random_quest"] = newQuest
						QuestDataManager:UpdateData(v, "Quests", data.Quests)
						QuestDataManager:SaveData(v)
					end
				end

				announceRemote:FireClient(v, "Daily quest given!", "SYSTEM")
			end
		end
	end

	-- :trapfill [target] — fill player's fish trap with fish to max capacity
	if chat:lower():sub(1, #Prefix + 8) == Prefix .. "trapfill" then
		if hasPermission(plr, "trapfill") then
			local FISHTRAP_CONFIGS = {
				["BasicFishTrap"]    = { maxCapacity = 30, rodType = "BasicRod" },
				["AdvancedFishTrap"] = { maxCapacity = 40, rodType = "SteelRod" },
				["MasterFishTrap"]   = { maxCapacity = 50, rodType = "GoldRod" },
				["RobuxFishTrap"]    = { maxCapacity = 100, rodType = "RobuxRod" },
			}
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local trapData = FishTrapDataManager:GetData(v)
				if not trapData then
					announceRemote:FireClient(plr, v.Name .. ": no trap data", "SYSTEM")
					continue
				end
				local filled = false
				for key, trap in pairs(trapData) do
					if type(trap) ~= "table" or not key:find("FishTrapData_") then continue end
					local trapType = trap.trapType or "BasicFishTrap"
					local config = FISHTRAP_CONFIGS[trapType] or FISHTRAP_CONFIGS["BasicFishTrap"]
					local storedFish = trap.storedFish or {}
					local toFill = config.maxCapacity - #storedFish
					for _ = 1, toFill do
						local fishInfo = FishDataModule.GetRandomFish(config.rodType, nil)
						if fishInfo then
							table.insert(storedFish, {
								name      = fishInfo.name,
								fishName  = fishInfo.fishName,
								value     = fishInfo.value,
								minWeight = fishInfo.minWeight,
								maxWeight = fishInfo.maxWeight,
								weight    = fishInfo.weight,
								chance    = fishInfo.chance,
							})
						end
					end
					trap.storedFish = storedFish
					FishTrapDataManager:UpdateData(v, key, trap)
					filled = true
					announceRemote:FireClient(plr, string.format("%s trap filled: %d fish", v.Name, #storedFish), "SYSTEM")
				end
				if not filled then
					announceRemote:FireClient(plr, v.Name .. ": no active trap found", "SYSTEM")
				end
			end
		end
	end

	-- :updatelogreset [target] — reset LastSeenUpdateVersion so update log shows again
	if chat:lower():sub(1, #Prefix + 14) == Prefix .. "updatelogreset" then
		if hasPermission(plr, "updatelogreset") then
			local args = string.split(chat, " ")
			local targetName = args[2] or plr.Name
			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local seenFlag = v:FindFirstChild("SeenUpdateLog")
				if seenFlag then seenFlag.Value = false end
				local lastSeen = v:FindFirstChild("LastSeenUpdateVersion")
				if lastSeen then lastSeen.Value = 0 end
				local data = LeaderstatsDataManager:GetData(v)
				if data then
					LeaderstatsDataManager:UpdateData(v, "SeenUpdateLog", false)
					LeaderstatsDataManager:UpdateData(v, "LastSeenUpdateVersion", 0)
				end
				announceRemote:FireClient(v, "Update log reset — rejoin to see it.", "SYSTEM")
			end
		end
	end

end

-- Connect player events
Players.PlayerAdded:Connect(function(plr)
	local rank = getPlayerRank(plr)
	if rank then
		plr.Chatted:Connect(function(msg)
			command(plr, msg)
		end)
	end
end)
