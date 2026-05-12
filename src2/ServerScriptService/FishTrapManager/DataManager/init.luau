local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ProfileService = require(script.ProfileService)

-- Generate unique trap ID
local function generateTrapId()
	return "trap_" .. tick() .. "_" .. math.random(1000, 9999)
end

-- Trap performance settings per type (same as server)
local FISHTRAP_CONFIGS = {
	["BasicFishTrap"] = {
		catchInterval = 300,    -- 5 minutes
		maxCapacity = 30,       -- 30 fish
		rodType = "BasicRod"
	},
	["AdvancedFishTrap"] = {
		catchInterval = 240,    -- 4 minutes
		maxCapacity = 40,       -- 40 fish
		rodType = "SteelRod"
	},
	["MasterFishTrap"] = {
		catchInterval = 180,    -- 3 minutes
		maxCapacity = 50,       -- 50 fish
		rodType = "GoldRod"
	},
	["RobuxFishTrap"] = {
		catchInterval = 150,    -- 3 minutes
		maxCapacity = 80,       -- 80 fish
		rodType = "RobuxRod",   -- Best performance (gamepass rod)
		displayName = "Robux Fish Trap"
	}
}

local ProfileStore = ProfileService.GetProfileStore("FishingGameStore", {})
local Profiles = {}

local function HandleLockedUpdate(globalUpdates, update)
	local id = update[1]
	local data = update[2]
	globalUpdates:ClearLockedUpdate(id)
end

local DataManager = {}

function DataManager.OnPlayerAdded(player)
	local profile = ProfileStore:LoadProfileAsync("Player_"..player.UserId, "ForceLoad")

	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick()
		end)

		if player:IsDescendantOf(Players) then
			Profiles[player] = profile

			local globalUpdates = profile.GlobalUpdates

			for index, update in pairs(globalUpdates:GetActiveUpdates())do
				globalUpdates:LockActiveUpdate(update[1])
			end

			for index, update in pairs(globalUpdates:GetLockedUpdates())do
				HandleLockedUpdate(globalUpdates, update)
			end

			globalUpdates:ListenToNewActiveUpdate(function(id, data)
				globalUpdates:LockActiveUpdate(id)
			end)

			globalUpdates:ListenToNewLockedUpdate(function(id, data)
				HandleLockedUpdate(globalUpdates, {id, data})
			end)

			-- Restore fish traps (process offline delete signals first)
			task.spawn(function()
				DataManager:CheckOfflineDeleteSignals(player)
				DataManager:RestorePlayerFishTraps(player)
			end)

		else
			profile:Release()
		end
	else
		player:Kick("Data loading failed")
	end
end

function DataManager.OnPlayerRemoving(player)
	local profile = Profiles[player]
	if profile then
		profile:Save()
		profile:Release()
	end
end

function DataManager:GetData(player)
	local profile = Profiles[player]
	return profile and profile.Data or nil
end

function DataManager:UpdateData(player, key, data)
	local profile = Profiles[player]
	if not profile then
		warn("UpdateData failed: no profile", player.Name, key)
		return
	end

	profile.Data[key] = data
end

function DataManager:CheckOfflineDeleteSignals(player)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	-- Process queued trap-delete signals for this player
	for _, child in pairs(ReplicatedStorage:GetChildren()) do
		-- Individual delete
		if child.Name:find("DeleteTrapData_" .. player.Name .. "_") and child:IsA("StringValue") then
			local trapId = child.Name:match("DeleteTrapData_" .. player.Name .. "_(.+)")
			if trapId then
				self:UpdateData(player, "FishTrapData_" .. trapId, nil)
				child:Destroy()
			end
		end

		-- Delete all
		if child.Name == "DeleteAllTrapData_" .. player.Name and child:IsA("StringValue") then
			self:ClearAllPlayerTrapData(player)
			child:Destroy()
		end

		-- Force delete all (enhanced)
		if child.Name == "ForceDeleteAllTrapData_" .. player.Name and child:IsA("StringValue") then

			-- Force delete all
			local deletedCount = self:ClearAllPlayerTrapData(player)

			-- Also delete all variant keys
			local playerData = self:GetData(player)
			if playerData then
				local extraKeys = {}
				for key, value in pairs(playerData) do
					-- Find all variants of trap/fish keys
					if string.find(string.lower(key), "trap") or
						string.find(string.lower(key), "fish") then
						table.insert(extraKeys, key)
					end
				end

				for _, key in pairs(extraKeys) do
					self:UpdateData(player, key, nil)
					deletedCount = deletedCount + 1
				end
			end

			child:Destroy()
		end
	end
end

function DataManager:ClearAllPlayerTrapData(player)
	local playerData = self:GetData(player)
	if not playerData then return 0 end

	local deletedCount = 0
	local keysToDelete = {}

	-- Find all trap-related keys (comprehensive)
	for key, value in pairs(playerData) do
		if string.find(key, "FishTrapData_") or
			string.find(key, "TrapData_") or
			string.find(key, "Trap_") or
			string.find(string.lower(key), "fishtrap") then
			table.insert(keysToDelete, key)
		end
	end

	-- Batch delete
	for _, key in pairs(keysToDelete) do
		self:UpdateData(player, key, nil)
		deletedCount = deletedCount + 1
	end

	return deletedCount
end

-- Place fish trap (supports multiple trap types)
function DataManager:PlaceFishTrap(player, trapName, position, rotation)
	local fishTrapsFolder = ServerStorage:FindFirstChild("FishTraps")
	local trapModel = fishTrapsFolder and fishTrapsFolder:FindFirstChild(trapName)
	if not trapModel then
		warn("Trap model not found: ServerStorage > FishTraps >", trapName)
		return nil
	end

	local newTrap = trapModel:Clone()
	local trapId = generateTrapId()

	local ownerValue = Instance.new("StringValue")
	ownerValue.Name = "Owner"
	ownerValue.Value = player.Name
	ownerValue.Parent = newTrap

	local trapIdValue = Instance.new("StringValue")
	trapIdValue.Name = "TrapId"
	trapIdValue.Value = trapId
	trapIdValue.Parent = newTrap

	local trapTypeValue = Instance.new("StringValue")
	trapTypeValue.Name = "TrapType"
	trapTypeValue.Value = trapName
	trapTypeValue.Parent = newTrap

	if position and rotation then
		newTrap:SetPrimaryPartCFrame(CFrame.new(position.X, position.Y, position.Z) *
			CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z)))
	end

	newTrap.Parent = workspace

	-- Apply trap type performance settings
	local config = FISHTRAP_CONFIGS[trapName] or FISHTRAP_CONFIGS["BasicFishTrap"]

	local trapData = {
		position = {
			x = newTrap.PrimaryPart.Position.X,
			y = newTrap.PrimaryPart.Position.Y,
			z = newTrap.PrimaryPart.Position.Z
		},
		rotation = {
			x = newTrap.PrimaryPart.Rotation.X,
			y = newTrap.PrimaryPart.Rotation.Y,
			z = newTrap.PrimaryPart.Rotation.Z
		},
		storedFish = {},
		nextCatchTime = tick() + config.catchInterval,
		lastSaveTime = tick(),
		trapId = trapId,
		trapType = trapName,
		isActive = true -- Active flag
	}

	self:UpdateData(player, "FishTrapData_" .. trapId, trapData)
	return trapId
end

function DataManager:RestorePlayerFishTraps(player)
	task.wait(1) -- Wait for stability

	local playerData = self:GetData(player)
	if not playerData then
		local fishTrapReady = Instance.new("BoolValue")
		fishTrapReady.Name = "FishTrapReady"
		fishTrapReady.Value = true
		fishTrapReady.Parent = player
		return
	end


	-- Check for existing traps in world
	local existingTrapsInWorld = {}
	for _, obj in pairs(workspace:GetChildren()) do
		local ownerValue = obj:FindFirstChild("Owner")
		local trapIdValue = obj:FindFirstChild("TrapId")
		if ownerValue and ownerValue.Value == player.Name and trapIdValue then
			existingTrapsInWorld[trapIdValue.Value] = obj
		end
	end

	-- Find all trap data entries
	local trapDataList = {}
	for key, trapData in pairs(playerData) do
		if string.find(key, "FishTrapData_") and trapData and type(trapData) == "table" then
			-- Include if isActive is not explicitly false (nil also counts for restore)
			if trapData.isActive ~= false then
				table.insert(trapDataList, {
					key = key,
					data = trapData,
					saveTime = trapData.lastSaveTime or 0
				})
			end
		end
	end

	-- Sort by save time descending (newest first)
	table.sort(trapDataList, function(a, b)
		return a.saveTime > b.saveTime
	end)

	-- Restore only the most recent trap
	if #trapDataList > 0 then
		local latestTrap = trapDataList[1]
		local trapData = latestTrap.data
		local trapId = string.sub(latestTrap.key, 14) -- Remove "FishTrapData_"


		-- Restore trap if not already present in world
		if not existingTrapsInWorld[trapId] then
			-- Restore trap
			local trapType = trapData.trapType or "BasicFishTrap"
			local config = FISHTRAP_CONFIGS[trapType] or FISHTRAP_CONFIGS["BasicFishTrap"]

			local fishTrapsFolder = ServerStorage:FindFirstChild("FishTraps")
			local trapModel = fishTrapsFolder and fishTrapsFolder:FindFirstChild(trapType)

			if trapModel and trapData.position then

				-- Calculate offline fish
				local lastSaveTime = trapData.lastSaveTime or tick()
				local currentTime = tick()
				local timeOffline = currentTime - lastSaveTime

				local currentFishCount = trapData.storedFish and #trapData.storedFish or 0
				local fishToCatch = math.floor(timeOffline / config.catchInterval)
				local maxPossibleCatch = config.maxCapacity - currentFishCount
				fishToCatch = math.min(fishToCatch, maxPossibleCatch)


				-- Add offline fish
				if fishToCatch > 0 then
					local success, FishData = pcall(function()
						return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("FishDataModule"))
					end)

					if success and FishData then
						local storedFish = trapData.storedFish or {}
						for i = 1, fishToCatch do
							local fishInfo = FishData.GetRandomFish(config.rodType, nil)
							if fishInfo then
								table.insert(storedFish, fishInfo)
							end
						end
						trapData.storedFish = storedFish
					else
						warn("FishData module load failed")
					end
				end

				-- Restore trap to world
				local newTrap = trapModel:Clone()
				newTrap.Name = (config.displayName or trapType) .. "_" .. trapId

				-- Set owner info
				local ownerValue = Instance.new("StringValue")
				ownerValue.Name = "Owner"
				ownerValue.Value = player.Name
				ownerValue.Parent = newTrap

				local trapIdValue = Instance.new("StringValue")
				trapIdValue.Name = "TrapId"
				trapIdValue.Value = trapId
				trapIdValue.Parent = newTrap

				local trapTypeValue = Instance.new("StringValue")
				trapTypeValue.Name = "TrapType"
				trapTypeValue.Value = trapType
				trapTypeValue.Parent = newTrap

				-- Set position
				local pos = trapData.position
				local rot = trapData.rotation or {x = 0, y = 0, z = 0}

				newTrap:SetPrimaryPartCFrame(CFrame.new(
					pos.x, pos.y, pos.z
					) * CFrame.Angles(
						math.rad(rot.x), math.rad(rot.y), math.rad(rot.z)
					))

				newTrap.Parent = workspace

				-- Save updated data
				trapData.lastSaveTime = currentTime
				trapData.nextCatchTime = currentTime + config.catchInterval
				trapData.isActive = true
				self:UpdateData(player, latestTrap.key, trapData)


			elseif not trapModel then
				-- Delete data if model not found
				self:UpdateData(player, latestTrap.key, nil)
				warn("Deleted trap data with no model:", trapType, trapId)
			elseif not trapData.position then
				-- Delete data if position missing
				self:UpdateData(player, latestTrap.key, nil)
				warn("Deleted trap data with no position:", trapId)
			end
		end

		-- Delete old trap data (keep only newest 1)
		for i = 2, #trapDataList do
			local oldTrap = trapDataList[i]
			self:UpdateData(player, oldTrap.key, nil)
		end

	end

	-- Set FishTrapReady flag
	local fishTrapReady = Instance.new("BoolValue")
	fishTrapReady.Name = "FishTrapReady"
	fishTrapReady.Value = true
	fishTrapReady.Parent = player

end

return DataManager
