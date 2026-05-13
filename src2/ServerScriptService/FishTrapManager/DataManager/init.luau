local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ProfileService = require(script.Parent.Parent.ProfileService)

local function generateTrapId()
	return "trap_" .. tick() .. "_" .. math.random(1000, 9999)
end

local FISHTRAP_CONFIGS = {
	["BasicFishTrap"] = {
		catchInterval = 300,
		maxCapacity = 30,
		rodType = "BasicRod"
	},
	["AdvancedFishTrap"] = {
		catchInterval = 240,
		maxCapacity = 40,
		rodType = "SteelRod"
	},
	["MasterFishTrap"] = {
		catchInterval = 180,
		maxCapacity = 50,
		rodType = "GoldRod"
	},
	["RobuxFishTrap"] = {
		catchInterval = 150,
		maxCapacity = 80,
		rodType = "RobuxRod",
		displayName = "Robux Fish Trap"
	}
}

local ProfileStore = ProfileService.New("FishingGameStore", {})
local Profiles = {}

local DataManager = {}

function DataManager.OnPlayerAdded(player)
	local profile = ProfileStore:StartSessionAsync("Player_" .. player.UserId, {Steal = true})

	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			player:Kick()
		end)

		if player:IsDescendantOf(Players) then
			Profiles[player] = profile

			task.spawn(function()
				DataManager:CheckOfflineDeleteSignals(player)
				DataManager:RestorePlayerFishTraps(player)
			end)
		else
			profile:EndSession()
		end
	else
		player:Kick("Data loading failed")
	end
end

function DataManager.OnPlayerRemoving(player)
	local profile = Profiles[player]
	if profile and profile:IsActive() then
		profile:EndSession()
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

	for _, child in pairs(ReplicatedStorage:GetChildren()) do
		if child.Name:find("DeleteTrapData_" .. player.Name .. "_") and child:IsA("StringValue") then
			local trapId = child.Name:match("DeleteTrapData_" .. player.Name .. "_(.+)")
			if trapId then
				self:UpdateData(player, "FishTrapData_" .. trapId, nil)
				child:Destroy()
			end
		end

		if child.Name == "DeleteAllTrapData_" .. player.Name and child:IsA("StringValue") then
			self:ClearAllPlayerTrapData(player)
			child:Destroy()
		end

		if child.Name == "ForceDeleteAllTrapData_" .. player.Name and child:IsA("StringValue") then
			local deletedCount = self:ClearAllPlayerTrapData(player)
			local playerData = self:GetData(player)
			if playerData then
				local extraKeys = {}
				for key in pairs(playerData) do
					if string.find(string.lower(key), "trap") or string.find(string.lower(key), "fish") then
						table.insert(extraKeys, key)
					end
				end
				for _, key in pairs(extraKeys) do
					self:UpdateData(player, key, nil)
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

	for key in pairs(playerData) do
		if string.find(key, "FishTrapData_") or string.find(key, "TrapData_") or
			string.find(key, "Trap_") or string.find(string.lower(key), "fishtrap") then
			table.insert(keysToDelete, key)
		end
	end

	for _, key in pairs(keysToDelete) do
		self:UpdateData(player, key, nil)
		deletedCount = deletedCount + 1
	end

	return deletedCount
end

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

	local config = FISHTRAP_CONFIGS[trapName] or FISHTRAP_CONFIGS["BasicFishTrap"]
	local trapData = {
		position = {x = newTrap.PrimaryPart.Position.X, y = newTrap.PrimaryPart.Position.Y, z = newTrap.PrimaryPart.Position.Z},
		rotation = {x = newTrap.PrimaryPart.Rotation.X, y = newTrap.PrimaryPart.Rotation.Y, z = newTrap.PrimaryPart.Rotation.Z},
		storedFish = {},
		nextCatchTime = tick() + config.catchInterval,
		lastSaveTime = tick(),
		trapId = trapId,
		trapType = trapName,
		isActive = true
	}

	self:UpdateData(player, "FishTrapData_" .. trapId, trapData)
	return trapId
end

function DataManager:RestorePlayerFishTraps(player)
	task.wait(1)

	local playerData = self:GetData(player)
	if not playerData then
		local flag = Instance.new("BoolValue")
		flag.Name = "FishTrapReady"
		flag.Value = true
		flag.Parent = player
		return
	end

	local existingTrapsInWorld = {}
	for _, obj in pairs(workspace:GetChildren()) do
		local ownerValue = obj:FindFirstChild("Owner")
		local trapIdValue = obj:FindFirstChild("TrapId")
		if ownerValue and ownerValue.Value == player.Name and trapIdValue then
			existingTrapsInWorld[trapIdValue.Value] = obj
		end
	end

	local trapDataList = {}
	for key, trapData in pairs(playerData) do
		if string.find(key, "FishTrapData_") and trapData and type(trapData) == "table" then
			if trapData.isActive ~= false then
				table.insert(trapDataList, {key = key, data = trapData, saveTime = trapData.lastSaveTime or 0})
			end
		end
	end

	table.sort(trapDataList, function(a, b) return a.saveTime > b.saveTime end)

	if #trapDataList > 0 then
		local latestTrap = trapDataList[1]
		local trapData = latestTrap.data
		local trapId = string.sub(latestTrap.key, 14)

		if not existingTrapsInWorld[trapId] then
			local trapType = trapData.trapType or "BasicFishTrap"
			local config = FISHTRAP_CONFIGS[trapType] or FISHTRAP_CONFIGS["BasicFishTrap"]
			local fishTrapsFolder = ServerStorage:FindFirstChild("FishTraps")
			local trapModel = fishTrapsFolder and fishTrapsFolder:FindFirstChild(trapType)

			if trapModel and trapData.position then
				local lastSaveTime = trapData.lastSaveTime or tick()
				local currentTime = tick()
				local timeOffline = currentTime - lastSaveTime
				local currentFishCount = trapData.storedFish and #trapData.storedFish or 0
				local fishToCatch = math.min(math.floor(timeOffline / config.catchInterval), config.maxCapacity - currentFishCount)

				if fishToCatch > 0 then
					local success, FishData = pcall(function()
						return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("FishDataModule"))
					end)
					if success and FishData then
						local storedFish = trapData.storedFish or {}
						for i = 1, fishToCatch do
							local fishInfo = FishData.GetRandomFish(config.rodType, nil)
							if fishInfo then
								table.insert(storedFish, {
									name = fishInfo.name,
									fishName = fishInfo.fishName,
									value = fishInfo.value,
									minWeight = fishInfo.minWeight,
									maxWeight = fishInfo.maxWeight,
									weight = fishInfo.weight,
									chance = fishInfo.chance
								})
							end
						end
						trapData.storedFish = storedFish
					end
				end

				local newTrap = trapModel:Clone()
				newTrap.Name = (config.displayName or trapType) .. "_" .. trapId

				local ov = Instance.new("StringValue"); ov.Name = "Owner"; ov.Value = player.Name; ov.Parent = newTrap
				local tv = Instance.new("StringValue"); tv.Name = "TrapId"; tv.Value = trapId; tv.Parent = newTrap
				local ttv = Instance.new("StringValue"); ttv.Name = "TrapType"; ttv.Value = trapType; ttv.Parent = newTrap

				local pos = trapData.position
				local rot = trapData.rotation or {x=0, y=0, z=0}
				newTrap:SetPrimaryPartCFrame(CFrame.new(pos.x, pos.y, pos.z) *
					CFrame.Angles(math.rad(rot.x), math.rad(rot.y), math.rad(rot.z)))
				newTrap.Parent = workspace

				trapData.lastSaveTime = currentTime
				trapData.nextCatchTime = currentTime + config.catchInterval
				trapData.isActive = true
				self:UpdateData(player, latestTrap.key, trapData)

			elseif not trapModel then
				self:UpdateData(player, latestTrap.key, nil)
			elseif not trapData.position then
				self:UpdateData(player, latestTrap.key, nil)
			end
		end

		for i = 2, #trapDataList do
			self:UpdateData(player, trapDataList[i].key, nil)
		end
	end

	local flag = Instance.new("BoolValue")
	flag.Name = "FishTrapReady"
	flag.Value = true
	flag.Parent = player
end

return DataManager
