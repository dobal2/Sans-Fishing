local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ProfileService = require(script.Parent.Parent.ProfileService)

local function generateTrapId()
	return "trap_" .. math.floor(tick() * 1000) .. "_" .. math.random(100000, 999999)
end

local FISHTRAP_CONFIGS = {
	["BasicFishTrap"]    = { catchInterval = 600, maxCapacity = 20 },
	["AdvancedFishTrap"] = { catchInterval = 480, maxCapacity = 30 },
	["MasterFishTrap"]   = { catchInterval = 360, maxCapacity = 40 },
	["RobuxFishTrap"]    = { catchInterval = 300, maxCapacity = 60, displayName = "Robux Fish Trap" },
}

local PROFILE_STORE_NAME = RunService:IsStudio() and "FishingGameStore_Studio" or "FishingGameStore"
local ProfileStore = ProfileService.New(PROFILE_STORE_NAME, {})
local Profiles = {}

local DataManager = {}

function DataManager.OnPlayerAdded(player)
	local profile
	for attempt = 1, 3 do
		profile = ProfileStore:StartSessionAsync("Player_" .. player.UserId, {Steal = true})
		if profile then break end
		if not player:IsDescendantOf(Players) then return end
		task.wait(3)
	end

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
			self:ClearAllPlayerTrapData(player)
			local playerData = self:GetData(player)
			if playerData then
				local extra = {}
				for key in pairs(playerData) do
					if key:lower():find("trap") or key:lower():find("fish") then
						table.insert(extra, key)
					end
				end
				for _, key in pairs(extra) do self:UpdateData(player, key, nil) end
			end
			child:Destroy()
		end
	end
end

function DataManager:ClearAllPlayerTrapData(player)
	local playerData = self:GetData(player)
	if not playerData then return 0 end
	local keys = {}
	for key in pairs(playerData) do
		if key:find("FishTrapData_") or key:find("TrapData_") or key:find("Trap_") or key:lower():find("fishtrap") then
			table.insert(keys, key)
		end
	end
	for _, key in pairs(keys) do self:UpdateData(player, key, nil) end
	return #keys
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

	local ov  = Instance.new("StringValue"); ov.Name  = "Owner";    ov.Value  = player.Name; ov.Parent  = newTrap
	local tv  = Instance.new("StringValue"); tv.Name  = "TrapId";   tv.Value  = trapId;      tv.Parent  = newTrap
	local ttv = Instance.new("StringValue"); ttv.Name = "TrapType"; ttv.Value = trapName;    ttv.Parent = newTrap

	if position then
		local rot = rotation or Vector3.new(0, 0, 0)
		newTrap:SetPrimaryPartCFrame(
			CFrame.new(position.X, position.Y, position.Z) *
			CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		)
	end

	newTrap.Parent = workspace

	local config = FISHTRAP_CONFIGS[trapName] or FISHTRAP_CONFIGS["BasicFishTrap"]
	local pos = newTrap.PrimaryPart and newTrap.PrimaryPart.Position or position
	self:UpdateData(player, "FishTrapData_" .. trapId, {
		position      = { x = pos.X, y = pos.Y, z = pos.Z },
		rotation      = { x = (rotation and rotation.X or 0), y = (rotation and rotation.Y or 0), z = (rotation and rotation.Z or 0) },
		storedFish    = {},
		nextCatchTime = tick() + config.catchInterval,
		lastSaveTime  = tick(),
		trapId        = trapId,
		trapType      = trapName,
		isActive      = true,
	})
	return trapId
end

function DataManager:RestorePlayerFishTraps(player)
	task.wait(1)

	local playerData = self:GetData(player)
	if not playerData then
		local flag = Instance.new("BoolValue"); flag.Name = "FishTrapReady"; flag.Value = true; flag.Parent = player
		return
	end

	local existingTraps = {}
	for _, obj in pairs(workspace:GetChildren()) do
		local ownerVal = obj:FindFirstChild("Owner")
		local trapIdVal = obj:FindFirstChild("TrapId")
		if ownerVal and ownerVal.Value == player.Name and trapIdVal then
			existingTraps[trapIdVal.Value] = obj
		end
	end

	local trapList = {}
	for key, trapData in pairs(playerData) do
		if key:find("FishTrapData_") and type(trapData) == "table" and trapData.isActive ~= false then
			table.insert(trapList, { key = key, data = trapData, saveTime = trapData.lastSaveTime or 0 })
		end
	end
	table.sort(trapList, function(a, b) return a.saveTime > b.saveTime end)

	if #trapList > 0 then
		local latest = trapList[1]
		local trapData = latest.data
		local trapId = latest.key:sub(14)

		if not existingTraps[trapId] then
			local trapType = trapData.trapType or "BasicFishTrap"
			local config = FISHTRAP_CONFIGS[trapType] or FISHTRAP_CONFIGS["BasicFishTrap"]
			local fishTrapsFolder = ServerStorage:FindFirstChild("FishTraps")
			local trapModel = fishTrapsFolder and fishTrapsFolder:FindFirstChild(trapType)

			if trapModel and trapData.position then
				-- 오프라인 물고기 계산 (10분 간격)
				local lastSave = trapData.lastSaveTime or tick()
				local elapsed = tick() - lastSave
				local currentCount = trapData.storedFish and #trapData.storedFish or 0
				local canAdd = config.maxCapacity - currentCount
				local offlineCatches = math.min(math.floor(elapsed / config.catchInterval), canAdd)

				if offlineCatches > 0 then
					local ok, FishData = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("FishDataModule"))
					if ok and FishData then
						local storedFish = trapData.storedFish or {}
						for _ = 1, offlineCatches do
							local fishInfo = FishData.GetRandomFish(trapType, nil, true)
							if fishInfo then
								table.insert(storedFish, {
									name = fishInfo.name, fishName = fishInfo.fishName,
									value = fishInfo.value, minWeight = fishInfo.minWeight,
									maxWeight = fishInfo.maxWeight, weight = fishInfo.weight,
									chance = fishInfo.chance,
								})
							end
						end
						trapData.storedFish = storedFish
					end
				end

				local newTrap = trapModel:Clone()
				newTrap.Name = (config.displayName or trapType) .. "_" .. trapId

				local ov  = Instance.new("StringValue"); ov.Name  = "Owner";    ov.Value  = player.Name; ov.Parent  = newTrap
				local tv  = Instance.new("StringValue"); tv.Name  = "TrapId";   tv.Value  = trapId;      tv.Parent  = newTrap
				local ttv = Instance.new("StringValue"); ttv.Name = "TrapType"; ttv.Value = trapType;    ttv.Parent = newTrap

				local pos = trapData.position
				local rot = trapData.rotation or { x=0, y=0, z=0 }
				newTrap:SetPrimaryPartCFrame(
					CFrame.new(pos.x, pos.y, pos.z) *
					CFrame.Angles(math.rad(rot.x), math.rad(rot.y), math.rad(rot.z))
				)
				newTrap.Parent = workspace

				local offlineUsed = offlineCatches * config.catchInterval
				local leftover = elapsed - offlineUsed
				trapData.lastSaveTime  = tick()
				trapData.nextCatchTime = tick() + math.max(0, config.catchInterval - leftover)
				trapData.isActive      = true
				self:UpdateData(player, latest.key, trapData)

			elseif not trapModel or not trapData.position then
				self:UpdateData(player, latest.key, nil)
			end
		end

		-- 중복 트랩 데이터 정리
		for i = 2, #trapList do
			self:UpdateData(player, trapList[i].key, nil)
		end
	end

	local flag = Instance.new("BoolValue"); flag.Name = "FishTrapReady"; flag.Value = true; flag.Parent = player
end

return DataManager
