local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local datamanager = require(script.DataManager)

-- Robux rod gamepass ID
local ROBUX_ROD_GAMEPASS_ID = 1410895892

local ROBUX_FISHTRAP_GAMEPASS_ID = 1423175879

local specialUserList = {
	-- Add by UserId (recommended)
	3027682121,
	1992864185,
	8740521599,
	1853104124,
	8696508978,
	1330397992,
	7190978074,
	8725769856,
	7670517305,
	8618607419,
	1505409265,
	5598168269,
	5017477876,
	8535369043,
	8405755138,
	4268542199,
	2979569956,
	3216409723,
	5457152687,
	4569564845,
	2693925665,
	2295552658,
	2237417772,
	3379348816,
	2843299351
}



-- Check if player is a special user
local function isSpecialUser(player)
	for _, userId in ipairs(specialUserList) do
		if player.UserId == userId then
			return true
		end
	end
	return false
end

-- Check gamepass ownership
local function hasGamepass(player, gamepassId)
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	return success and result
end

local playerSetupInProgress = {}

Players.PlayerAdded:Connect(function(plr)
	if playerSetupInProgress[plr.UserId] then return end
	playerSetupInProgress[plr.UserId] = true

	task.wait(2)

	-- Create base structure
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local Rods = Instance.new("Folder")
	Rods.Name = "Rods"

	local Fish = Instance.new("Folder")  -- Uppercase F for consistency
	Fish.Name = "Fish"

	local FishVariant = Instance.new("Folder")
	FishVariant.Name = "FishVariant"

	local Boats = Instance.new("Folder")  -- Boats folder
	Boats.Name = "Boats"

	local FishTraps = Instance.new("Folder")  -- Fish Trap folder
	FishTraps.Name = "FishTraps"

	local CurrentFishTrap = Instance.new("Folder")
	CurrentFishTrap.Name = "CurrentFishTrap"

	local CurrentFishTrapValue = Instance.new("StringValue")
	CurrentFishTrapValue.Name = "Value"
	CurrentFishTrapValue.Value = ""
	CurrentFishTrapValue.Parent = CurrentFishTrap

	local Coins = Instance.new("IntValue")
	Coins.Name = "Coins"
	Coins.Value = 0

	local TotalCatches = Instance.new("IntValue")
	TotalCatches.Name = "TotalCatches"
	TotalCatches.Value = 0

	local CurrentRod = Instance.new("StringValue")
	CurrentRod.Name = "CurrentRod"
	CurrentRod.Value = "FishingRod"

	local IsTutorialed = Instance.new("BoolValue")
	IsTutorialed.Name = "IsTutorialed"
	IsTutorialed.Value = false
	IsTutorialed.Parent = plr

	local SeenUpdateLog = Instance.new("BoolValue")
	SeenUpdateLog.Name = "SeenUpdateLog"
	SeenUpdateLog.Value = false
	SeenUpdateLog.Parent = plr

	local LastSeenUpdateVersion = Instance.new("IntValue")
	LastSeenUpdateVersion.Name = "LastSeenUpdateVersion"
	LastSeenUpdateVersion.Value = 0
	LastSeenUpdateVersion.Parent = plr

	local SkillPoints = Instance.new("IntValue")
	SkillPoints.Name = "SkillPoints"
	SkillPoints.Value = 0
	SkillPoints.Parent = plr

	local Skills = Instance.new("Folder")
	Skills.Name = "Skills"
	Skills.Parent = plr

	local SKILL_NAMES = {"Root", "AutoFish", "LuckUp", "SellBonus", "FriendBonus", "FishingPoint", "HitZoneUp", "WeightUp", "PowerUp", "AutoUp", "PointBoost", "QuickBite"}
	for _, skillName in ipairs(SKILL_NAMES) do
		local sv = Instance.new("IntValue")
		sv.Name = skillName
		sv.Value = 0
		sv.Parent = Skills
	end

	local rodList = {"FishingRod", "Silver Rod", "GoldRod", "CrystalRod", "MagneticRod", "BoneRod", "CloverRod", "RainbowRod", "UnknownRod", "RobuxRod", "ElectricRod","BlockyRod","ArcaneRod","FlameRod","VoidRod","FriendRod","InviteRod","EquinoxRod","SilkRod"}

	local boatList = {"BasicBoat"}  -- Boat list

	local fishTrapList = {"BasicFishTrap","AdvancedFishTrap","MasterFishTrap","RobuxFishTrap"}

	local BOBBER_LIST = {"Basic Bobber","Lucky Bobber","Frost Bobber","Heavyweight Bobber","Festival Bobber","Coin Bobber","Gold Bobber","Sans Bobber","Storm Bobber","Black Hole Bobber","Double Catch Bobber","Robux Bobber"}

	local fishList = {
		"Armor Fish",
		"Bass",
		"Crab",
		"Dragon Head Fish",
		"Electric Fish",
		"Gold Fish",
		"Golden Trout",
		"Nyan Cat",
		"Ray",
		"Sans",
		"Shark",
		"Undyine",
		"Unknown",
		"Small Carp",
		"Stone Fish",
		"Snow Fish",
		"Crystal Bass",
		"Reggigash",
		"Dust Fish",
		"Diri"
	}

	for _, fishTrapName in ipairs(fishTrapList) do
		local fishTrap = Instance.new("BoolValue")
		fishTrap.Name = fishTrapName
		fishTrap.Value = false  -- Default: not owned
		fishTrap.Parent = FishTraps
	end

	local OwnedBobbersFolder = Instance.new("Folder")
	OwnedBobbersFolder.Name = "OwnedBobbers"
	for _, bobberName in ipairs(BOBBER_LIST) do
		local bv = Instance.new("BoolValue")
		bv.Name = bobberName
		bv.Value = (bobberName == "Basic Bobber")
		bv.Parent = OwnedBobbersFolder
	end

	local EquippedBobberValue = Instance.new("StringValue")
	EquippedBobberValue.Name = "EquippedBobber"
	EquippedBobberValue.Value = "Basic Bobber"



	-- Create rods
	local specialUser = isSpecialUser(plr)
	for _, rodName in ipairs(rodList) do
		local rod = Instance.new("BoolValue")
		rod.Name = rodName
		rod.Value = (rodName == "FishingRod") or (rodName == "FriendRod" and specialUser)
		rod.Parent = Rods
	end

	-- Check Robux rod gamepass
	if hasGamepass(plr, ROBUX_ROD_GAMEPASS_ID) then
		local robuxRod = Rods:FindFirstChild("RobuxRod")
		if robuxRod then
			robuxRod.Value = true
		end
	end

	for _, boatName in ipairs(boatList) do
		local boat = Instance.new("BoolValue")
		boat.Name = boatName
		boat.Value = false
		boat.Parent = Boats
	end

	-- Create fish encyclopedia (with correct Parent)
	for _, fishName in ipairs(fishList) do
		local fishBool = Instance.new("BoolValue")
		fishBool.Name = fishName
		fishBool.Value = false
		fishBool.Parent = Fish  -- Add to Fish folder
	end

	-- Create variant encyclopedia (Gold/Frozen/Festival per fish)
	local VARIANT_PREFIXES = { "Gold", "Frozen", "Festival", "Sans" }
	for _, prefix in ipairs(VARIANT_PREFIXES) do
		for _, fishName in ipairs(fishList) do
			local vBool = Instance.new("BoolValue")
			vBool.Name = prefix .. " " .. fishName
			vBool.Value = false
			vBool.Parent = FishVariant
		end
	end

	-- Add to leaderstats
	Coins.Parent = leaderstats
	CurrentRod.Parent = leaderstats
	Rods.Parent = leaderstats
	Boats.Parent = leaderstats
	Fish.Parent = leaderstats  -- Add Fish folder to leaderstats
	FishVariant.Parent = leaderstats
	TotalCatches.Parent = leaderstats
	leaderstats.Parent = plr
	CurrentFishTrap.Parent = leaderstats
	FishTraps.Parent = leaderstats
	OwnedBobbersFolder.Parent = leaderstats
	EquippedBobberValue.Parent = leaderstats


	-- Load data
	local Data
	repeat
		task.wait()
		if not plr.Parent then return end
		Data = datamanager:GetData(plr)
	until Data

	-- Apply data
	if Data then
		Coins.Value = Data.Coins or 0
		TotalCatches.Value = Data.TotalCatches or 0

		-- Restore fishing streak
		local savedStreak = Data.FishStreak or 0
		if savedStreak > 0 then
			local ok_fs, FishingServerModule = pcall(function()
				return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("FishingServerModule"))
			end)
			if ok_fs and FishingServerModule then
				FishingServerModule.playerStreaks[plr.UserId] = savedStreak
				local streakEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("StreakUpdateEvent")
				streakEvent:FireAllClients(plr.UserId, savedStreak)
			end
		end

		-- Migration: SliverRod → Silver Rod
		if Data.CurrentRod == "SliverRod" then Data.CurrentRod = "Silver Rod" end
		if Data.Rods and Data.Rods["SliverRod"] then
			Data.Rods["Silver Rod"] = Data.Rods["SliverRod"]
			Data.Rods["SliverRod"] = nil
		end

		-- RealisticRod → BlockyRod 마이그레이션
		local savedRod = Data.CurrentRod or "FishingRod"
		if savedRod == "RealisticRod" then savedRod = "BlockyRod" end
		CurrentRod.Value = savedRod
		if Data.Rods and Data.Rods["RealisticRod"] then
			Data.Rods["BlockyRod"] = Data.Rods["RealisticRod"]
			Data.Rods["RealisticRod"] = nil
		end

		CurrentFishTrapValue.Value = Data.CurrentFishTrap or ""

		IsTutorialed.Value = Data.IsTutorialed
		SeenUpdateLog.Value = Data.SeenUpdateLog or false
		LastSeenUpdateVersion.Value = Data.LastSeenUpdateVersion or 0

		if Coins.Value < 0 then
			warn("Abnormal coin value detected (" .. Coins.Value .. ") - clamping to 0")
			Coins.Value = 0
		end

		SkillPoints.Value = Data.SkillPoints or 0

		for skillName, level in pairs(Data.Skills or {}) do
			local sv = Skills:FindFirstChild(skillName)
			if sv then sv.Value = level end
		end

		-- Apply rod data
		for rodName, hasRod in pairs(Data.Rods or {}) do
			local rodBool = Rods:FindFirstChild(rodName)
			if rodBool then
				-- RobuxRod is validated by gamepass only
				if rodName == "RobuxRod" then
					rodBool.Value = hasGamepass(plr, ROBUX_ROD_GAMEPASS_ID)
				else
					rodBool.Value = hasRod
				end
			elseif hasRod then
				warn("Unknown rod:", rodName, "->", plr.Name)
			end
		end

		-- Restore saved bubble tools to Backpack
		local bubbleToolsFolder = ServerStorage:FindFirstChild("BubbleTools")
		for _, savedBubbleName in ipairs(Data.Bubbles or {}) do
			if bubbleToolsFolder then
				local bubbleTool = bubbleToolsFolder:FindFirstChild(savedBubbleName)
				if bubbleTool then
					local playerBackpack = plr:FindFirstChild("Backpack")
					if playerBackpack then
						bubbleTool:Clone().Parent = playerBackpack
					end
				end
			end
		end

		-- Apply fish encyclopedia data
		for fishName, hasCaught in pairs(Data.Fish or {}) do
			local fishBool = Fish:FindFirstChild(fishName)
			if fishBool then
				fishBool.Value = hasCaught or false
			elseif hasCaught then
				warn("Unknown fish:", fishName, "->", plr.Name)
			end
		end

		-- Apply variant encyclopedia data
		for variantName, hasCaught in pairs(Data.FishVariant or {}) do
			local vBool = FishVariant:FindFirstChild(variantName)
			if vBool then
				vBool.Value = hasCaught or false
			end
		end

		-- Apply boat data
		for boatName, hasBoat in pairs(Data.Boats or {}) do
			local boatBool = Boats:FindFirstChild(boatName)
			if boatBool then
				boatBool.Value = hasBoat
			elseif hasBoat then
				warn("Unknown boat:", boatName, "->", plr.Name)
			end
		end

		if hasGamepass(plr, ROBUX_FISHTRAP_GAMEPASS_ID) then
			local robuxFishTrap = FishTraps:FindFirstChild("RobuxFishTrap")
			if robuxFishTrap then
				robuxFishTrap.Value = true
			end
		end


		for fishTrapName, hasFishTrap in pairs(Data.FishTraps or {}) do
			local fishTrapBool = FishTraps:FindFirstChild(fishTrapName)
			if fishTrapBool then
				-- RobuxFishTrap is validated by gamepass only
				if fishTrapName == "RobuxFishTrap" then
					fishTrapBool.Value = hasGamepass(plr, ROBUX_FISHTRAP_GAMEPASS_ID)
				else
					fishTrapBool.Value = hasFishTrap
				end
			elseif hasFishTrap then
				warn("Unknown Fish Trap:", fishTrapName, "->", plr.Name)
			end
		end

		-- Apply bobber data
		EquippedBobberValue.Value = Data.EquippedBobber or "Basic Bobber"
		for _, bobberName in ipairs(Data.OwnedBobbers or {"Basic Bobber"}) do
			local bv = OwnedBobbersFolder:FindFirstChild(bobberName)
			if bv then bv.Value = true end
		end
	end



	local equippedRod = CurrentRod.Value
	local ownedRod = Rods:FindFirstChild(equippedRod)

	-- Always set FishingRod to owned
	if equippedRod == "FishingRod" and ownedRod then
		ownedRod.Value = true
	end

	-- Re-check gamepass for RobuxRod
	if equippedRod == "RobuxRod" then
		if not hasGamepass(plr, ROBUX_ROD_GAMEPASS_ID) then
			warn("RobuxRod gamepass not owned - switching to default rod")
			equippedRod = "FishingRod"
			CurrentRod.Value = "FishingRod"
			ownedRod = Rods:FindFirstChild(equippedRod)
		end
	end

	-- Correct if invalid
	local rodModel = ServerStorage:FindFirstChild(equippedRod)
	if not ownedRod or not ownedRod.Value or not rodModel then
		warn("Invalid rod [" .. tostring(equippedRod) .. "] - switching to default rod")
		equippedRod = "FishingRod"
		CurrentRod.Value = "FishingRod"
		ownedRod = Rods:FindFirstChild(equippedRod)
		rodModel = ServerStorage:WaitForChild(equippedRod)
		-- Default rod must always be owned
		if ownedRod then
			ownedRod.Value = true
		end
	end

	-- Give rod with retry (max 20s)
	local rodGiveAttempts = 0
	while rodGiveAttempts < 40 do
		rodGiveAttempts += 1

		if not plr.Parent then
			warn("Player left - stopping rod give")
			break
		end

		local starterGear = plr:FindFirstChild("StarterGear")
		local backpack = plr:FindFirstChild("Backpack")

		if rodModel and ownedRod and ownedRod.Value and starterGear and backpack then
			local success, errorMsg = pcall(function()
				local existingStarterRod = starterGear:FindFirstChild(equippedRod)
				if not existingStarterRod then
					local gear = rodModel:Clone()
					gear.Parent = starterGear
				end

				local existingBackpackRod = backpack:FindFirstChild(equippedRod)
				if not existingBackpackRod then
					local now = rodModel:Clone()
					now.Parent = backpack
				end
			end)

			if success then
				local finalStarterCheck = starterGear:FindFirstChild(equippedRod)
				local finalBackpackCheck = backpack:FindFirstChild(equippedRod)

				if finalStarterCheck or finalBackpackCheck then
					break
				else
					warn("Rod give succeeded but not in inventory - retrying")
				end
			else
				warn("Rod give failed: " .. tostring(errorMsg))
			end
		else
			warn("Rod give conditions not met - waiting...")
		end

		task.wait(0.5)
	end
	if rodGiveAttempts >= 40 then
		warn("Rod give timed out for", plr.Name)
	end

	local equippedFishTrap = CurrentFishTrapValue.Value

	if equippedFishTrap == "RobuxFishTrap" then
		if not hasGamepass(plr, ROBUX_FISHTRAP_GAMEPASS_ID) then
			warn("RobuxFishTrap gamepass not owned - unequipping")
			equippedFishTrap = ""
			CurrentFishTrapValue.Value = ""
		end
	end

	-- Skip if no fish trap equipped
	if equippedFishTrap == "" then
	else
		local ownedFishTrap = FishTraps:FindFirstChild(equippedFishTrap)

		-- Unequip if invalid
		local fishTrapModel = ServerStorage:FindFirstChild(equippedFishTrap)
		if not ownedFishTrap or not ownedFishTrap.Value or not fishTrapModel then
			warn("Invalid Fish Trap [" .. tostring(equippedFishTrap) .. "] - unequipping")
			equippedFishTrap = ""
			CurrentFishTrapValue.Value = ""
		else
			-- Give fish trap with retry (max 20s)
			local trapGiveAttempts = 0
			while trapGiveAttempts < 40 do
				trapGiveAttempts += 1

				if not plr.Parent then
					warn("Player left - stopping Fish Trap give")
					break
				end

				local starterGear = plr:FindFirstChild("StarterGear")
				local backpack = plr:FindFirstChild("Backpack")

				if fishTrapModel and ownedFishTrap and ownedFishTrap.Value and starterGear and backpack then
					local success, errorMsg = pcall(function()
						local existingStarterTrap = starterGear:FindFirstChild(equippedFishTrap)
						if not existingStarterTrap then
							local gear = fishTrapModel:Clone()
							gear.Parent = starterGear
						end

						local existingBackpackTrap = backpack:FindFirstChild(equippedFishTrap)
						if not existingBackpackTrap then
							local now = fishTrapModel:Clone()
							now.Parent = backpack
						end
					end)

					if success then
						local finalStarterCheck = starterGear:FindFirstChild(equippedFishTrap)
						local finalBackpackCheck = backpack:FindFirstChild(equippedFishTrap)

						if finalStarterCheck or finalBackpackCheck then
							break
						else
							warn("Fish Trap give succeeded but not in inventory - retrying")
						end
					else
						warn("Fish Trap give failed: " .. tostring(errorMsg))
					end
				else
					warn("Fish Trap give conditions not met - waiting...")
				end

				task.wait(0.5)
			end
			if trapGiveAttempts >= 40 then
				warn("Fish Trap give timed out for", plr.Name)
			end
		end
	end

	-- Give fish trap to player function (after giveRodToPlayer)
	local function giveFishTrapToPlayer()
		local equippedFishTrap = CurrentFishTrapValue.Value

		if equippedFishTrap == "" then
			return true
		end

		local ownedFishTrap = FishTraps:FindFirstChild(equippedFishTrap)

		if equippedFishTrap == "RobuxFishTrap" then
			if not hasGamepass(plr, ROBUX_FISHTRAP_GAMEPASS_ID) then
				warn("RobuxFishTrap gamepass not owned - unequipping")
				equippedFishTrap = ""
				CurrentFishTrapValue.Value = ""
				return true
			end
		end

		local fishTrapModel = ServerStorage:FindFirstChild(equippedFishTrap)

		if not ownedFishTrap or not ownedFishTrap.Value or not fishTrapModel then
			warn("Invalid Fish Trap [" .. tostring(equippedFishTrap) .. "] - unequipping")
			equippedFishTrap = ""
			CurrentFishTrapValue.Value = ""
			return true
		end

		local reGiveAttempts = 0
		while reGiveAttempts < 40 do
			reGiveAttempts += 1

			if not plr.Parent then
				warn("Player left - stopping Fish Trap give")
				return false
			end

			local starterGear = plr:FindFirstChild("StarterGear")
			local backpack = plr:FindFirstChild("Backpack")

			if fishTrapModel and ownedFishTrap and ownedFishTrap.Value and starterGear and backpack then
				local success, errorMsg = pcall(function()
					local existingStarterTrap = starterGear:FindFirstChild(equippedFishTrap)
					if not existingStarterTrap then
						local gear = fishTrapModel:Clone()
						gear.Parent = starterGear
					end

					local existingBackpackTrap = backpack:FindFirstChild(equippedFishTrap)
					if not existingBackpackTrap then
						local now = fishTrapModel:Clone()
						now.Parent = backpack
					end
				end)

				if success then
					local finalStarterCheck = starterGear:FindFirstChild(equippedFishTrap)
					local finalBackpackCheck = backpack:FindFirstChild(equippedFishTrap)

					if finalStarterCheck or finalBackpackCheck then
						return true
					else
						warn("Fish Trap re-give succeeded but not in inventory - retrying")
					end
				else
					warn("Fish Trap re-give failed: " .. tostring(errorMsg))
				end
			else
				warn("Fish Trap re-give conditions not met - waiting...")
			end

			task.wait(0.5)
		end
		warn("Fish Trap re-give timed out for", plr.Name)
		return false
	end

	playerSetupInProgress[plr.UserId] = nil

	-- Signal data loading complete
	local dataReady = Instance.new("BoolValue")
	dataReady.Name = "DataReady"
	dataReady.Value = true
	dataReady.Parent = plr

	task.spawn(function()
		task.wait(1) -- Extra safety wait

		-- Create RemoteEvent if it does not exist
		local leaderboardNotificationEvent = ReplicatedStorage:FindFirstChild("LeaderboardNotificationEvent")
		if not leaderboardNotificationEvent then
			leaderboardNotificationEvent = Instance.new("RemoteEvent")
			leaderboardNotificationEvent.Name = "LeaderboardNotificationEvent"
			leaderboardNotificationEvent.Parent = ReplicatedStorage
		end

		-- Notify all clients if joining player appears in any leaderboard top 10
		local leaderboardChecks = {
			{ getter = "GetTopCoinPlayers",     label = "Coin",     color = "#FFD700" },
			{ getter = "GetTopDonationPlayers", label = "Donation", color = "#00FF00" },
			{ getter = "GetTopPlaytimePlayers", label = "Time",     color = "#00BFFF" },
		}

		for _, check in ipairs(leaderboardChecks) do
			local topPlayers = datamanager[check.getter](datamanager, 10)
			for i, entry in ipairs(topPlayers) do
				if entry.UserId == plr.UserId then
					local message = string.format("%s leaderboard top %d player %s has joined the game!", check.label, i, plr.Name)
					leaderboardNotificationEvent:FireAllClients(message, check.color)
					break
				end
			end
		end
	end)


	-- Give the player's equipped rod (retries until confirmed in inventory)
	local function giveRodToPlayer()



		local equippedRod = CurrentRod.Value
		local ownedRod = Rods:FindFirstChild(equippedRod)

		-- Always set FishingRod to owned
		if equippedRod == "FishingRod" and ownedRod then
			ownedRod.Value = true
		end

		-- Re-check RobuxRod
		if equippedRod == "RobuxRod" then
			if not hasGamepass(plr, ROBUX_ROD_GAMEPASS_ID) then
				warn("RobuxRod gamepass not owned - switching to default rod")
				equippedRod = "FishingRod"
				CurrentRod.Value = "FishingRod"
				ownedRod = Rods:FindFirstChild(equippedRod)
			end
		end

		-- Correct if invalid
		local rodModel = ServerStorage:FindFirstChild(equippedRod)
		if not ownedRod or not ownedRod.Value or not rodModel then
			warn("Invalid rod [" .. tostring(equippedRod) .. "] - switching to default rod")
			equippedRod = "FishingRod"
			CurrentRod.Value = "FishingRod"
			ownedRod = Rods:FindFirstChild(equippedRod)
			rodModel = ServerStorage:WaitForChild(equippedRod)
			if ownedRod then
				ownedRod.Value = true
			end
		end

		-- Attempt rod give (max 20 attempts × 0.5s = 10s timeout)
		local MAX_ROD_GIVE_ATTEMPTS = 20
		for _attempt = 1, MAX_ROD_GIVE_ATTEMPTS do
			if not plr.Parent then
				warn("Player left - stopping rod give")
				return false
			end

			local starterGear = plr:FindFirstChild("StarterGear")
			local backpack = plr:FindFirstChild("Backpack")

			if rodModel and ownedRod and ownedRod.Value and starterGear and backpack then
				local success, errorMsg = pcall(function()
					local existingStarterRod = starterGear:FindFirstChild(equippedRod)
					if not existingStarterRod then
						local gear = rodModel:Clone()
						gear.Parent = starterGear
					end

					local existingBackpackRod = backpack:FindFirstChild(equippedRod)
					if not existingBackpackRod then
						local now = rodModel:Clone()
						now.Parent = backpack
					end
				end)

				if success then
					local finalStarterCheck = starterGear:FindFirstChild(equippedRod)
					local finalBackpackCheck = backpack:FindFirstChild(equippedRod)

					if finalStarterCheck or finalBackpackCheck then
						return true
					else
						warn("Rod re-give succeeded but not in inventory - retrying")
					end
				else
					warn("Rod re-give failed: " .. tostring(errorMsg))
				end
			else
				warn("Rod re-give conditions not met - waiting...")
			end

			task.wait(0.5)
		end
		warn("Rod re-give failed after max attempts for", plr.Name)
		return false
	end


	-- After ItemSave finishes, verify rod and trap are present and re-give if missing
	task.spawn(function()
		repeat task.wait(0.1) until plr:FindFirstChild("ItemReady") and plr.ItemReady.Value == true
		task.wait(3)

		local currentRodName = CurrentRod.Value
		local hasRodInBackpack = plr:FindFirstChild("Backpack") and plr.Backpack:FindFirstChild(currentRodName) ~= nil
		local hasRodInCharacter = plr.Character and plr.Character:FindFirstChild(currentRodName) ~= nil

		if not hasRodInBackpack and not hasRodInCharacter then
			warn("No rod after ItemReady - re-giving (" .. plr.Name .. ")")
			local ok = giveRodToPlayer()
			if not ok then
				warn("Re-give also failed: " .. plr.Name)
			end
		end

		local currentTrapName = CurrentFishTrapValue.Value
		if currentTrapName ~= "" then
			local hasTrapInBackpack = plr:FindFirstChild("Backpack") and plr.Backpack:FindFirstChild(currentTrapName) ~= nil
			local hasTrapInCharacter = plr.Character and plr.Character:FindFirstChild(currentTrapName) ~= nil

			if not hasTrapInBackpack and not hasTrapInCharacter then
				warn("No Fish Trap after ItemReady - re-giving (" .. plr.Name .. ")")
				local ok = giveFishTrapToPlayer()
				if not ok then
					warn("Fish Trap re-give also failed: " .. plr.Name)
				end
			end
		end
	end)
end)



Players.PlayerRemoving:Connect(function(plr)
	playerSetupInProgress[plr.UserId] = nil
	datamanager:SafeSavePlayer(plr)
end)
