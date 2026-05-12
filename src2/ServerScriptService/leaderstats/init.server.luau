local datamanager = require(script.DataManager)
local DataService = game:GetService("DataStoreService")
local MyData = DataService:GetDataStore("playerdata")
local ServerStorage = game:GetService("ServerStorage")
local players = game.Players
local MarketplaceService = game:GetService("MarketplaceService")

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

players.PlayerAdded:Connect(function(plr)
	wait(2)

	-- Create base structure
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local Rods = Instance.new("Folder")
	Rods.Name = "Rods"

	local Fish = Instance.new("Folder")  -- Uppercase F for consistency
	Fish.Name = "Fish"

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

	local CurrentRod = Instance.new("StringValue")
	CurrentRod.Name = "CurrentRod"
	CurrentRod.Value = "FishingRod"

	local IsTutorialed = Instance.new("BoolValue")
	IsTutorialed.Name = "IsTutorialed"
	IsTutorialed.Value = false
	IsTutorialed.Parent = plr

	local rodList = {"FishingRod", "SliverRod", "GoldRod", "CrystalRod", "MagneticRod", "BoneRod", "CloverRod", "RainbowRod", "UnknownRod", "RobuxRod", "ElectricRod","RealisticRod","ArcaneRod","VoidRod"}

	local boatList = {"BasicBoat"}  -- Boat list

	local fishTrapList = {"BasicFishTrap","AdvancedFishTrap","MasterFishTrap","RobuxFishTrap"}

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



	-- Create rods
	for _, rodName in ipairs(rodList) do
		local rod = Instance.new("BoolValue")
		rod.Name = rodName
		rod.Value = (rodName == "FishingRod")
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

	-- Add to leaderstats
	Coins.Parent = leaderstats
	CurrentRod.Parent = leaderstats
	Rods.Parent = leaderstats
	Boats.Parent = leaderstats
	Fish.Parent = leaderstats  -- Add Fish folder to leaderstats
	leaderstats.Parent = plr
	CurrentFishTrap.Parent = leaderstats
	FishTraps.Parent = leaderstats


	-- Load data
	local Data
	repeat
		task.wait()
		Data = datamanager:GetData(plr)
	until Data

	-- Debug original data backup
	if Data.Rods then
		for rodName, hasRod in pairs(Data.Rods) do
			if hasRod then
			end
		end
	end

	-- Apply data
	if Data then
		Coins.Value = Data.Coins or 0
		CurrentRod.Value = Data.CurrentRod or "FishingRod"

		CurrentFishTrapValue.Value = Data.CurrentFishTrap or ""

		IsTutorialed.Value = Data.IsTutorialed

		if(Coins.Value < 0) then
			warn("Abnormal coin value detected (" .. Coins.Value .. ") - correcting to 11111")
			Coins.Value = 11111
		end

		-- Apply rod data
		for rodName, hasRod in pairs(Data.Rods or {}) do
			local rodBool = Rods:FindFirstChild(rodName)
			if rodBool then
				-- RobuxRod checked by gamepass only
				if rodName == "RobuxRod" then
					rodBool.Value = hasGamepass(plr, ROBUX_ROD_GAMEPASS_ID)
					if rodBool.Value then
					end
				else
					rodBool.Value = hasRod
					if hasRod then
					end
				end
			else
				-- Warn if unknown rod found in data
				if hasRod then
					warn("Unknown rod:", rodName, "->", plr.Name)
				end
			end
		end

		-- Apply fish encyclopedia data
		for fishName, hasCaught in pairs(Data.Fish or {}) do
			local fishBool = Fish:FindFirstChild(fishName)
			if fishBool then
				fishBool.Value = hasCaught or false
				if hasCaught then
				end
			else
				-- Warn if unknown fish found in data
				if hasCaught then
					warn("Unknown fish:", fishName, "->", plr.Name)
				end
			end
		end

		-- Apply boat data
		for boatName, hasBoat in pairs(Data.Boats or {}) do
			local boatBool = Boats:FindFirstChild(boatName)
			if boatBool then
				boatBool.Value = hasBoat
				if hasBoat then
				end
			else
				if hasBoat then
					warn("Unknown boat:", boatName, "->", plr.Name)
				end
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
				-- RobuxFishTrap checked by gamepass only
				if fishTrapName == "RobuxFishTrap" then
					fishTrapBool.Value = hasGamepass(plr, ROBUX_FISHTRAP_GAMEPASS_ID)
					if fishTrapBool.Value then
					end
				else
					fishTrapBool.Value = hasFishTrap
					if hasFishTrap then
					end
				end
			else
				if hasFishTrap then
					warn("Unknown Fish Trap:", fishTrapName, "->", plr.Name)
				end
			end
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

	-- Give rod with infinite retry until actually given
	while true do
		-- Check if player left
		if not plr.Parent then
			warn("Player left - stopping rod give")
			break
		end

		-- Check if StarterGear and Backpack exist
		local starterGear = plr:FindFirstChild("StarterGear")
		local backpack = plr:FindFirstChild("Backpack")

		if rodModel and ownedRod and ownedRod.Value and starterGear and backpack then
			local success, errorMsg = pcall(function()
				-- Check if rod already in StarterGear
				local existingStarterRod = starterGear:FindFirstChild(equippedRod)
				if not existingStarterRod then
					local gear = rodModel:Clone()
					gear.Parent = starterGear
				end

				-- Check if rod already in Backpack
				local existingBackpackRod = backpack:FindFirstChild(equippedRod)
				if not existingBackpackRod then
					local now = rodModel:Clone()
					now.Parent = backpack
				end
			end)

			if success then
				-- Verify rod was actually given
				local finalStarterCheck = starterGear:FindFirstChild(equippedRod)
				local finalBackpackCheck = backpack:FindFirstChild(equippedRod)

				if finalStarterCheck or finalBackpackCheck then
					break -- Exit loop only when actually given
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

	-- Give FriendRod to special users
	if(isSpecialUser(plr)) then
		local newFriendRod = ServerStorage:FindFirstChild("FriendRod")
		if newFriendRod then
			newFriendRod = newFriendRod:Clone()
			newFriendRod.Parent = plr.Backpack
		end
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
			-- Give fish trap with infinite retry
			while true do
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

		while true do
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
	end

	-- Signal data loading complete
	local dataReady = Instance.new("BoolValue")
	dataReady.Name = "DataReady"
	dataReady.Value = true
	dataReady.Parent = plr

	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	task.spawn(function()
		task.wait(1) -- Extra safety wait

		-- Create RemoteEvent if it does not exist
		local leaderboardNotificationEvent = ReplicatedStorage:FindFirstChild("LeaderboardNotificationEvent")
		if not leaderboardNotificationEvent then
			leaderboardNotificationEvent = Instance.new("RemoteEvent")
			leaderboardNotificationEvent.Name = "LeaderboardNotificationEvent"
			leaderboardNotificationEvent.Parent = ReplicatedStorage
		end

		-- Check coin leaderboard
		local topCoinPlayers = datamanager:GetTopCoinPlayers(10)
		for i, data in ipairs(topCoinPlayers) do
			if data.UserId == plr.UserId then
				local message = string.format("Coin leaderboard top %d player %s has joined the game!", i, plr.Name)
				leaderboardNotificationEvent:FireAllClients(message, "#FFD700") -- Gold
				break
			end
		end

		-- Check donation leaderboard
		local topDonationPlayers = datamanager:GetTopDonationPlayers(10)
		for i, data in ipairs(topDonationPlayers) do
			if data.UserId == plr.UserId then
				local message = string.format("Donation leaderboard top %d player %s has joined the game!", i, plr.Name)
				leaderboardNotificationEvent:FireAllClients(message, "#00FF00") -- Green
				break
			end
		end

		-- Check playtime leaderboard
		local topPlaytimePlayers = datamanager:GetTopPlaytimePlayers(10)
		for i, data in ipairs(topPlaytimePlayers) do
			if data.UserId == plr.UserId then
				local message = string.format("Time leaderboard top %d player %s has joined the game!", i, plr.Name)
				leaderboardNotificationEvent:FireAllClients(message, "#00BFFF") -- Sky blue
				break
			end
		end
	end)


	-- Rod give function (add above spawn function)
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

		-- Attempt rod give
		while true do
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
	end


	spawn(function()
		-- Wait until ItemReady is created
		repeat
			task.wait(0.1)
		until plr:FindFirstChild("ItemReady") and plr.ItemReady.Value == true


		-- Wait extra 3 seconds as safety measure
		task.wait(3)

		-- Re-check if rod is actually in inventory
		local hasRodInBackpack = false
		local hasRodInCharacter = false
		local currentRodName = CurrentRod.Value

		-- Check Backpack
		if plr:FindFirstChild("Backpack") then
			hasRodInBackpack = plr.Backpack:FindFirstChild(currentRodName) ~= nil
		end

		-- Check Character (equipped tool)
		if plr.Character then
			hasRodInCharacter = plr.Character:FindFirstChild(currentRodName) ~= nil
		end

		if not hasRodInBackpack and not hasRodInCharacter then
			warn("No rod even after ItemReady! Attempting re-give (" .. plr.Name .. ")")

			-- Attempt re-give
			local secondGiveSuccess = giveRodToPlayer()

			if secondGiveSuccess then
			else
				warn("Re-give also failed: " .. plr.Name)
			end
		else
		end

		local currentTrapName = CurrentFishTrapValue.Value

		if currentTrapName == "" then
		else
			local hasTrapInBackpack = false
			local hasTrapInCharacter = false

			if plr:FindFirstChild("Backpack") then
				hasTrapInBackpack = plr.Backpack:FindFirstChild(currentTrapName) ~= nil
			end

			if plr.Character then
				hasTrapInCharacter = plr.Character:FindFirstChild(currentTrapName) ~= nil
			end

			if not hasTrapInBackpack and not hasTrapInCharacter then
				warn("No Fish Trap even after ItemReady! Attempting re-give (" .. plr.Name .. ")")

				local trapGiveSuccess = giveFishTrapToPlayer()

				if trapGiveSuccess then
				else
					warn("Fish Trap re-give also failed: " .. plr.Name)
				end
			else
			end
		end
	end)
end)



players.PlayerRemoving:Connect(function(plr)
	datamanager:SafeSavePlayer(plr)
end)
