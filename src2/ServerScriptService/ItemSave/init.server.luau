-- ItemSave: server-side fish data store
-- Fish items are stored as data tables in PlayerFishData (not as Tool instances in Backpack).
-- Backpack holds at most one equipped fish Tool at a time (plus rods/bubbles).
-- Bubble tools retain the old clone-to-Backpack behaviour unchanged.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ItemsFolder = ServerStorage:WaitForChild("Fishes")
local DataManager = require(script.DataManager)
local moduleScript = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDataModule")
local FishIceEffect = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishIceEffectModule"))
local WeatherSystemModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeatherSystemModule"))
local FishData = require(moduleScript)

-- BindableEvent: FishingServerModule fires this when a fish is caught
local FishCaughtBindable = Instance.new("BindableEvent")
FishCaughtBindable.Name = "FishCaughtBindable"
FishCaughtBindable.Parent = ServerScriptService

-- BindableFunction: SellShopHandler calls this to sell fish from data table
-- Returns: totalBaseValue (number), itemsSoldCount (number)
local SellFishBindable = Instance.new("BindableFunction")
SellFishBindable.Name = "SellFishBindable"
SellFishBindable.Parent = ServerScriptService

-- Per-player tables
local PlayerFishData = {}       -- [player] = { {name, fishName, rarity, weight, value, isLocked, isFrozen, isFestival}, ... }
local PlayerEquippedIndex = {}  -- [player] = index or nil
local PlayerEquippedTool = {}   -- [player] = Tool instance or nil
local EquipCooldowns = {}       -- [player] = last equip timestamp

-- Debounce batch-save
local pendingSaveTimers = {}
local SAVE_DEBOUNCE = 3.0
local scheduleSave

-- Forward declarations for equip functions (defined below remote setup)
local cloneAndEquipFish
local unequipFish

-- Remotes (populated after RemoteInit runs)
local Misc = nil
local FishDataAddedRemote = nil
local InventoryDataSyncRemote = nil
local EquipFishRequestRemote = nil
local UnequipFishRequestRemote = nil
local GetInventoryDataRemote = nil
local SaveFishHotBarPinsRemote = nil
local GetFishHotBarPinsRemote = nil

-- BindableEvent for fish lock toggle (called from client via FishLockEvent server handler)
local FishLockBindable = Instance.new("BindableEvent")
FishLockBindable.Name = "FishLockBindable"
FishLockBindable.Parent = game:GetService("ServerScriptService")

task.spawn(function()
	Misc = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc")
	FishDataAddedRemote = Misc:WaitForChild("FishDataAdded")
	InventoryDataSyncRemote = Misc:WaitForChild("InventoryDataSync")
	EquipFishRequestRemote = Misc:WaitForChild("EquipFishRequest")
	UnequipFishRequestRemote = Misc:WaitForChild("UnequipFishRequest")
	GetInventoryDataRemote = Misc:WaitForChild("GetInventoryData")
	SaveFishHotBarPinsRemote = Misc:WaitForChild("SaveFishHotBarPins")
	GetFishHotBarPinsRemote  = Misc:WaitForChild("GetFishHotBarPins")

	-- Wire up remotes
	GetInventoryDataRemote.OnServerInvoke = function(player)
		return PlayerFishData[player] or {}
	end

	GetFishHotBarPinsRemote.OnServerInvoke = function(player)
		local Data = DataManager:GetData(player)
		return Data and Data.hotbarSlots or {}
	end

	SaveFishHotBarPinsRemote.OnServerEvent:Connect(function(player, pins)
		if typeof(pins) ~= "table" then return end
		local clean = {}
		for slot = 1, 9 do
			local v = pins[slot]
			if typeof(v) == "number" and v == math.floor(v) and v >= 1 then
				clean[slot] = v
			end
		end
		local Data = DataManager:GetData(player)
		if Data then
			Data.hotbarSlots = clean
			scheduleSave(player)
		end
	end)

	-- FishLock toggle from client (index-based, no Tool reference needed)
	FishLockBindable.Event:Connect(function(player, index, lockState)
		local fishList = PlayerFishData[player]
		if not fishList or not fishList[index] then return end
		fishList[index].isLocked = lockState
		scheduleSave(player)
	end)

	local EQUIP_COOLDOWN = 0.3
	EquipFishRequestRemote.OnServerEvent:Connect(function(player, index)
		if type(index) ~= "number" or index < 1 or index ~= math.floor(index) then return end
		local now = tick()
		if (EquipCooldowns[player] or 0) + EQUIP_COOLDOWN > now then return end
		EquipCooldowns[player] = now
		cloneAndEquipFish(player, index)
	end)

	UnequipFishRequestRemote.OnServerEvent:Connect(function(player)
		unequipFish(player)
	end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Utility helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function IsRod(itemName)
	itemName = itemName:lower()
	return itemName:match("rods?$") ~= nil or itemName:match("trap$") ~= nil or itemName:match("bubble$") ~= nil
end

local ChangedItemName = require(script.ChangedItemName)
local OriginalItemName = {}
for i, v in pairs(ChangedItemName) do
	OriginalItemName[v] = i
end

local VARIANT_PREFIXES_ORDERED = { "Gold", "Sans", "Frozen", "Festival" }

-- 실제 물고기 이름 집합 (prefix 제거 후 검증용)
local _validFishNames = nil
local function getValidFishNames()
	if _validFishNames then return _validFishNames end
	_validFishNames = {}
	for _, rarity in ipairs(FishData.Rarities) do
		for _, fish in ipairs(rarity.fishes) do
			_validFishNames[fish.fishName:lower()] = true
		end
	end
	return _validFishNames
end

-- Strips all variant prefixes and weight/rarity suffixes, returns just the base fish name.
local function StripSuffixes(name)
	-- Remove weight/rarity suffix first: "Bass [Rare] - 5.2kg" -> "Bass"
	local stripped = name:match("^(.-) %-%s*[%d%.]+kg$") or name
	stripped = stripped:match("^(.-)%s*%[.-%]$") or stripped

	-- 접두사 제거 전에 현재 이름 자체가 실제 물고기인지 먼저 확인
	-- (예: "Gold Fish"는 물고기 이름이므로 "Gold" 접두사 제거 안 함)
	local validNames = getValidFishNames()
	if validNames[stripped:lower()] then
		return stripped
	end

	-- 실제 물고기 이름이 아닐 때만 variant prefix 제거 시도
	local changed = true
	while changed do
		changed = false
		for _, prefix in ipairs(VARIANT_PREFIXES_ORDERED) do
			local pattern = "^" .. prefix .. " "
			if stripped:find(pattern) then
				local candidate = stripped:gsub(pattern, "", 1)
				-- 제거 결과가 실제 물고기 이름인 경우에만 제거
				if validNames[candidate:lower()] then
					stripped = candidate
					changed = true
					break
				end
			end
		end
	end

	return stripped
end

local function ExtractWeightFromName(name)
	local w = name:match("%- ([%d%.]+)kg$")
	return tonumber(w)
end

local function FindItem(itemName)
	if itemName:lower():match("bubble$") then
		local bubbleToolsFolder = ServerStorage:FindFirstChild("BubbleTools")
		if bubbleToolsFolder then
			local bubbleTool = bubbleToolsFolder:FindFirstChild(itemName)
			if bubbleTool then return bubbleTool end
		end
		return nil
	end

	local stripped = StripSuffixes(itemName):lower()

	-- Match by suffix against known fish names (handles any prefix combo without false-positives)
	for _, rarity in ipairs(FishData.Rarities) do
		for _, fish in ipairs(rarity.fishes) do
			local fn = fish.fishName:lower()
			if stripped == fn or stripped:sub(-#fn) == fn and (stripped == fn or stripped:sub(-(#fn+1), -(#fn+1)) == " ") then
				if fish.model and fish.model.Parent then
					return fish.model
				end
				return ItemsFolder:FindFirstChild(fish.fishName)
			end
		end
	end

	if stripped == "unknown" then
		return ItemsFolder:FindFirstChild("Unknown")
	end

	return nil
end

local function GetFishDataByName(name)
	local stripped = StripSuffixes(name):lower()

	for _, rarity in ipairs(FishData.Rarities) do
		for _, fish in ipairs(rarity.fishes) do
			local fn = fish.fishName:lower()
			if stripped == fn or stripped:sub(-#fn) == fn and (stripped == fn or stripped:sub(-(#fn+1), -(#fn+1)) == " ") then
				return {
					name     = rarity.name,
					fishName = fish.fishName,
					value    = fish.value,
					model    = fish.model,
					minWeight = fish.minWeight,
					maxWeight = fish.maxWeight,
					chance   = rarity.chance,
				}
			end
		end
	end

	return nil
end

-- Size helpers (same as original)
local function scaleHandleByRatio(handle, scaleRatio)
	if not handle or not handle:IsA("BasePart") then return end
	if scaleRatio == 1 then return end
	local originalCFrame = handle.CFrame
	handle.Size = handle.Size * scaleRatio
	handle.CFrame = originalCFrame
	handle.Massless = true
	if scaleRatio > 2 then
		handle.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.5, 0, 1, 1)
	end
end

local function getScaleRatio(weight, minWeight, maxWeight, maxScale)
	if maxWeight - minWeight <= 0 then return 1 end
	local clampedWeight = math.clamp(weight, minWeight, maxWeight)
	local t = (clampedWeight - minWeight) / (maxWeight - minWeight)
	return 1 + (maxScale - 1) * t
end

local function fixLoadedFishSize(clone, weight, fishData)
	local handle = clone:FindFirstChild("Handle")
	if handle then
		handle.Anchored = false
		clone.CanBeDropped = false

		local minW, maxW = fishData.minWeight or 1, fishData.maxWeight or 1
		local scaleRatio = getScaleRatio(weight, minW, maxW, 5)
		scaleHandleByRatio(handle, scaleRatio)

		handle.AssemblyLinearVelocity = Vector3.zero
		handle.AssemblyAngularVelocity = Vector3.zero

		clone.Equipped:Connect(function()
			handle.AssemblyLinearVelocity = Vector3.zero
			handle.AssemblyAngularVelocity = Vector3.zero
			for _, obj in pairs(handle:GetChildren()) do
				if obj:IsA("BodyPosition") or obj:IsA("BodyVelocity") or obj:IsA("BodyAngularVelocity") or
					obj:IsA("BodyThrust") or obj:IsA("BodyForce") or obj:IsA("BodyGyro") then
					obj:Destroy()
				end
			end
			task.wait(0.1)
			handle.AssemblyLinearVelocity = Vector3.zero
			handle.AssemblyAngularVelocity = Vector3.zero
		end)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Save / sync helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function saveCurrentInventory(player)
	if not player:FindFirstChild("ItemReady") then return end
	local Data = DataManager:GetData(player)
	if not Data then return end

	local fishList = PlayerFishData[player] or {}
	local newItemsData = {}

	for _, fishItem in ipairs(fishList) do
		table.insert(newItemsData, {
			name          = fishItem.name,
			isLocked      = fishItem.isLocked      or false,
			isFrozen      = fishItem.isFrozen      or false,
			isFestival    = fishItem.isFestival    or false,
			isSansVariant = fishItem.isSansVariant or false,
			isGoldVariant = fishItem.isGoldVariant or false,
		})
	end

	Data.items    = newItemsData
	Data.fishLocks = nil  -- deprecated; lock is now embedded in each item entry
	-- hotbarSlots no longer used for fish (fish have no hotbar slot concept)

	DataManager:SaveData(player)
end

scheduleSave = function(player)
	if pendingSaveTimers[player] then
		task.cancel(pendingSaveTimers[player])
	end
	pendingSaveTimers[player] = task.delay(SAVE_DEBOUNCE, function()
		pendingSaveTimers[player] = nil
		if player:IsDescendantOf(Players) then
			saveCurrentInventory(player)
		end
	end)
end

local function syncInventory(player)
	if InventoryDataSyncRemote then
		InventoryDataSyncRemote:FireClient(player, PlayerFishData[player] or {})
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Equip / unequip
-- ─────────────────────────────────────────────────────────────────────────────

unequipFish = function(player)
	local prevTool = PlayerEquippedTool[player]
	if prevTool and prevTool.Parent then
		prevTool:Destroy()
	end
	PlayerEquippedTool[player]  = nil
	PlayerEquippedIndex[player] = nil
end

cloneAndEquipFish = function(player, index)
	local fishList = PlayerFishData[player]
	if not fishList then return end
	local fishData = fishList[index]
	if not fishData then return end

	-- Remove previous equipped fish tool
	unequipFish(player)

	-- Find base model
	local item = FindItem(fishData.name)
	if not item then
		warn("ItemSave: Model not found for equip:", fishData.name)
		return
	end

	local clone = item:Clone()
	clone.CanBeDropped = false
	clone.Name = fishData.name

	-- Value objects
	local valueObj = clone:FindFirstChild("FishValue") or Instance.new("IntValue")
	valueObj.Name = "FishValue"
	valueObj.Value = fishData.value
	valueObj:SetAttribute("OriginalBaseValue", fishData.baseValue or fishData.value)
	valueObj.Parent = clone

	local weightObj = clone:FindFirstChild("FishWeight") or Instance.new("NumberValue")
	weightObj.Name = "FishWeight"
	weightObj.Value = fishData.weight
	weightObj.Parent = clone

	local rarityObj = clone:FindFirstChild("FishRarity") or Instance.new("StringValue")
	rarityObj.Name = "FishRarity"
	rarityObj.Value = fishData.rarity
	rarityObj.Parent = clone

	if fishData.isLocked then
		local lockObj = clone:FindFirstChild("FishLock") or Instance.new("BoolValue")
		lockObj.Name = "FishLock"
		lockObj.Value = fishData.isLocked
		lockObj.Parent = clone
	end

	-- Size adjustment (must happen before visual effects so bounding box is correct)
	local fd = GetFishDataByName(fishData.name)
	if fd then
		fixLoadedFishSize(clone, fishData.weight, fd)
	end

	-- Visual effects (after size so IceBlock bounding box matches scaled Handle)
	if fishData.isFrozen then
		pcall(function()
			FishIceEffect.ApplyIceEffect(clone, { fishName = fishData.name, currentWeather = "Snow" })
		end)
	end
	if fishData.isFestival then
		pcall(function()
			FishData.ApplyFestivalEffect(clone, { fishName = fishData.name, currentWeather = "Firework" })
		end)
	end
	if fishData.isSansVariant then
		local handle = clone:FindFirstChild("Handle")
		if handle then
			local sansParticles = ReplicatedStorage:FindFirstChild("Particle") and ReplicatedStorage.Particle:FindFirstChild("Sans")
			if sansParticles then
				for _, p in ipairs(sansParticles:GetChildren()) do
					if p:IsA("ParticleEmitter") then p:Clone().Parent = handle end
				end
			end
		end
	end

	if fishData.isGoldVariant then
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Color = Color3.fromRGB(255, 235, 60)
				part.Material = Enum.Material.Metal
				part.Reflectance = 0.6
				if part:IsA("UnionOperation") then
					part.UsePartColor = true
				end
			end
		end
	end

	clone.Parent = player.Backpack

	PlayerEquippedTool[player]  = clone
	PlayerEquippedIndex[player] = index

	-- When the tool leaves the player (sold, dropped, etc.), remove from data and clear state
	clone.AncestryChanged:Connect(function(_, newParent)
		if PlayerEquippedTool[player] ~= clone then return end
		if newParent == nil or (newParent ~= player.Backpack and newParent ~= player.Character) then
			-- 리스폰 중이면 데이터 삭제하지 않음 (새 Character로 교체되는 과정에서 발동될 수 있음)
			local isRespawning = player:GetAttribute("IsRespawning")
			if isRespawning then
				PlayerEquippedTool[player]  = nil
				PlayerEquippedIndex[player] = nil
				return
			end
			-- Remove from PlayerFishData if the tool was destroyed externally (e.g. sold via SellShopHandler directly)
			local idx = PlayerEquippedIndex[player]
			if idx and PlayerFishData[player] and PlayerFishData[player][idx] then
				table.remove(PlayerFishData[player], idx)
				if InventoryDataSyncRemote then
					InventoryDataSyncRemote:FireClient(player, PlayerFishData[player])
				end
				scheduleSave(player)
			end
			PlayerEquippedTool[player]  = nil
			PlayerEquippedIndex[player] = nil
		end
	end)

	-- When the tool's Name changes (e.g. after gamble), sync data table
	clone:GetPropertyChangedSignal("Name"):Connect(function()
		if PlayerEquippedTool[player] ~= clone then return end
		local idx = PlayerEquippedIndex[player]
		if idx and PlayerFishData[player] and PlayerFishData[player][idx] then
			local fishItem = PlayerFishData[player][idx]
			fishItem.name = clone.Name
			-- Update weight and value from tool children
			local wObj = clone:FindFirstChild("FishWeight")
			local vObj = clone:FindFirstChild("FishValue")
			if wObj then fishItem.weight = wObj.Value end
			if vObj then fishItem.value  = vObj.Value end
			local basePart = clone.Name:match("^(.-)%s*%[") or clone.Name
			local strippedBase = StripSuffixes(basePart)
			local prefixPart = basePart:sub(1, #basePart - #strippedBase)
			fishItem.isFrozen      = prefixPart:find("Frozen")  ~= nil
			fishItem.isFestival    = prefixPart:find("Festival") ~= nil
			fishItem.isSansVariant = prefixPart:find("Sans")    ~= nil
			fishItem.isGoldVariant = prefixPart:find("Gold")    ~= nil and strippedBase:sub(1,4):lower() ~= "gold"
			scheduleSave(player)
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Build fish item data from fishInfo (used when a fish is caught)
-- ─────────────────────────────────────────────────────────────────────────────

local function buildFishItemData(fishInfo)
	local minW = fishInfo.minWeight or 1
	local maxW = fishInfo.maxWeight or 1
	local baseValue = fishInfo.value or 0
	local valueRatio = math.clamp((fishInfo.weight - minW) / math.max(maxW - minW, 0.001), 0, 1)
	local adjustedValue = math.floor(baseValue * (1.2 + math.pow(valueRatio, 0.8) * 7.0))

	local isFrozen      = fishInfo.isFrozen == true
	local isFestival    = fishInfo.isFestival == true
	local isSansVariant = fishInfo.isSansVariant == true
	local isGoldVariant = fishInfo.isGoldVariant == true

	-- Apply variant multipliers
	if isFrozen then adjustedValue = math.floor(adjustedValue * 2.0) end
	if isFestival then
		local festivalMultiplier = (WeatherSystemModule.WeatherTypes and
			WeatherSystemModule.WeatherTypes.Firework and
			WeatherSystemModule.WeatherTypes.Firework.effects.valueMultiplier) or 1.5
		adjustedValue = math.floor(adjustedValue * festivalMultiplier)
	end
	if isSansVariant then adjustedValue = math.floor(adjustedValue * 3.0) end
	if isGoldVariant then adjustedValue = math.floor(adjustedValue * 2.0) end

	local fullName = string.format("%s [%s] - %.1fkg", fishInfo.fishName, fishInfo.name, fishInfo.weight)

	return {
		name      = fullName,
		fishName  = fishInfo.fishName,
		rarity    = fishInfo.name,
		weight    = fishInfo.weight,
		value     = adjustedValue,
		baseValue = baseValue,
		isLocked      = false,
		isFrozen      = isFrozen,
		isFestival    = isFestival,
		isSansVariant = isSansVariant,
		isGoldVariant = isGoldVariant,
	}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- FishCaughtBindable handler
-- ─────────────────────────────────────────────────────────────────────────────

FishCaughtBindable.Event:Connect(function(player, fishInfo)
	if not player:FindFirstChild("ItemReady") then return end

	local fishItem = buildFishItemData(fishInfo)

	if not PlayerFishData[player] then
		PlayerFishData[player] = {}
	end

	table.insert(PlayerFishData[player], fishItem)

	-- Notify client of new fish
	if FishDataAddedRemote then
		FishDataAddedRemote:FireClient(player, fishItem, #PlayerFishData[player])
	end

	scheduleSave(player)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- ItemLost: called when a fish tool is sold/lost from Backpack
-- Removes the equipped fish from PlayerFishData when its Tool is destroyed
-- Also handles bubble tool loss (kept as legacy direct-save)
-- ─────────────────────────────────────────────────────────────────────────────

local function ItemLost(player, itemName)
	if IsRod(itemName) then return end

	-- If it is the currently equipped fish, remove from data table
	local equippedIdx = PlayerEquippedIndex[player]
	if equippedIdx and PlayerFishData[player] then
		local equippedItem = PlayerFishData[player][equippedIdx]
		if equippedItem then
			local strippedItem = StripSuffixes(equippedItem.name):lower()
			local strippedName = StripSuffixes(itemName):lower()
			if strippedItem == strippedName then
				table.remove(PlayerFishData[player], equippedIdx)
				PlayerEquippedTool[player]  = nil
				PlayerEquippedIndex[player] = nil
				if InventoryDataSyncRemote then
					InventoryDataSyncRemote:FireClient(player, PlayerFishData[player])
				end
				scheduleSave(player)
				return
			end
		end
	end

	-- Fallback: search entire list
	local fishList = PlayerFishData[player]
	if not fishList then return end

	local strippedName = StripSuffixes(itemName):lower()
	for i = #fishList, 1, -1 do
		if StripSuffixes(fishList[i].name):lower() == strippedName then
			table.remove(fishList, i)
			-- Adjust equipped index if needed
			if PlayerEquippedIndex[player] then
				if PlayerEquippedIndex[player] == i then
					PlayerEquippedTool[player]  = nil
					PlayerEquippedIndex[player] = nil
				elseif PlayerEquippedIndex[player] > i then
					PlayerEquippedIndex[player] = PlayerEquippedIndex[player] - 1
				end
			end
			if InventoryDataSyncRemote then
				InventoryDataSyncRemote:FireClient(player, PlayerFishData[player])
			end
			scheduleSave(player)
			return
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- PlayerAdded: load saved fish data into PlayerFishData table
-- ─────────────────────────────────────────────────────────────────────────────

local function safeValueRatio(weight, minW, maxW)
	if minW == maxW then return 0 end
	local ratio = (weight - minW) / (maxW - minW)
	if ratio ~= ratio or ratio == math.huge or ratio == -math.huge then return 0 end
	return math.clamp(ratio, 0, 1)
end

Players.PlayerAdded:Connect(function(player)
	local TIMEOUT = 40

	-- DataReady 대기: WaitForChild + Value 체크로 즉각 반응
	local dataReadyVal = player:WaitForChild("DataReady", TIMEOUT)
	if not dataReadyVal then
		warn("ItemSave: DataReady timeout for", player.Name)
		local itemReady = Instance.new("BoolValue")
		itemReady.Name  = "ItemReady"
		itemReady.Value = true
		itemReady.Parent = player
		return
	end
	if not dataReadyVal.Value then
		local deadline = tick() + TIMEOUT
		repeat task.wait(0.1) until dataReadyVal.Value == true
			or not player:IsDescendantOf(Players)
			or tick() > deadline
	end
	if not player:IsDescendantOf(Players) then return end

	-- DataManager:GetData 대기: 0.1초 간격으로 폴링
	local elapsed = 0
	repeat
		task.wait(0.1)
		elapsed += 0.1
		if not player:IsDescendantOf(Players) then return end
		if elapsed >= TIMEOUT then
			warn("ItemSave: DataManager timeout for", player.Name)
			local itemReady = Instance.new("BoolValue")
			itemReady.Name  = "ItemReady"
			itemReady.Value = true
			itemReady.Parent = player
			return
		end
	until DataManager:GetData(player)

	local Data = DataManager:GetData(player)

	PlayerFishData[player] = {}

	-- Load all items from saved data into PlayerFishData (no Backpack cloning)
	-- Supports both legacy format (string) and new format ({name=..., isLocked=...})
	for i, itemEntry in ipairs(Data.items or {}) do
		local itemName, isLocked
		if type(itemEntry) == "table" then
			itemName = itemEntry.name
			isLocked = itemEntry.isLocked
		else
			-- Legacy: plain string name; fall back to fishLocks table if present
			itemName = itemEntry
			isLocked = Data.fishLocks and Data.fishLocks[tostring(i)]
		end

		if IsRod(itemName) then continue end

		-- Bubble tools: still clone into Backpack (legacy behaviour)
		if itemName:lower():match("bubble$") then
			local success, errorMsg = pcall(function()
				local item = FindItem(itemName)
				if item then
					local clone = item:Clone()
					clone.Name = itemName
					clone.Parent = player.Backpack
				end
			end)
			if not success then
				warn("ItemSave: Bubble load failed:", itemName, errorMsg)
			end
			continue
		end

		-- Fish items: parse data and store in PlayerFishData table
		local success, errorMsg = pcall(function()
			local fishData = GetFishDataByName(itemName)
			if not fishData then
				error("No fish data: " .. itemName)
			end

			local weight = ExtractWeightFromName(itemName)
			if not weight then
				error("Weight extraction failed: " .. itemName)
			end

			-- Use saved boolean flags when available (new format).
			-- Legacy entries fall back to name-string parsing with safer rules.
			local hasSavedFlags = type(itemEntry) == "table" and itemEntry.isFrozen ~= nil
			local hasFrozen, hasFestival, hasSans, hasGold
			if hasSavedFlags then
				hasFrozen   = itemEntry.isFrozen      == true
				hasFestival = itemEntry.isFestival    == true
				hasSans     = itemEntry.isSansVariant == true
				hasGold     = itemEntry.isGoldVariant == true
			else
				-- Legacy: parse from name, but use suffix-safe check for Gold
				-- (avoid false-positive on fish whose base name contains "Gold")
				hasFrozen   = itemName:find("^Frozen ")   ~= nil or itemName:find("^Festival Frozen ") ~= nil
				hasFestival = itemName:find("^Festival ") ~= nil or itemName:find("^Frozen Festival ") ~= nil
				hasSans     = itemName:find("^Sans ")     ~= nil
				-- Gold variant: name must start with "Gold " AND base fish name
				-- does NOT start with "Gold" (e.g. "Gold Fish" is not a variant)
				local goldPrefix = itemName:match("^Gold (.+)%s*%[")
				hasGold = goldPrefix ~= nil and fishData.fishName:sub(1, 4):lower() ~= "gold"
			end

			local minW, maxW = fishData.minWeight or 1, fishData.maxWeight or 1
			local baseValue  = fishData.value or 0
			local valueRatio = safeValueRatio(weight, minW, maxW)
			local adjustedValue = math.floor(baseValue * (1.2 + math.pow(valueRatio, 0.8) * 7.0))

			local festivalMultiplier = (WeatherSystemModule.WeatherTypes and
				WeatherSystemModule.WeatherTypes.Firework and
				WeatherSystemModule.WeatherTypes.Firework.effects.valueMultiplier) or 1.5

			if hasFrozen   then adjustedValue = math.floor(adjustedValue * 2.0) end
			if hasFestival then adjustedValue = math.floor(adjustedValue * festivalMultiplier) end
			if hasSans     then adjustedValue = math.floor(adjustedValue * 3.0) end
			if hasGold     then adjustedValue = math.floor(adjustedValue * 2.0) end

			-- Reconstruct fishName (with variant prefix) from itemName
			local fishName = itemName:match("^(.-)%s*%[") or fishData.fishName

			local fishItem = {
				name      = itemName,
				fishName  = fishName,
				rarity    = fishData.name,
				weight    = weight,
				value     = adjustedValue,
				baseValue = baseValue,
				isLocked      = isLocked or false,
				isFrozen      = hasFrozen,
				isFestival    = hasFestival,
				isSansVariant = hasSans,
				isGoldVariant = hasGold,
			}

			table.insert(PlayerFishData[player], fishItem)
		end)

		if not success then
			warn("ItemSave: Item load failed:", itemName, errorMsg)
		end
	end

	-- Character tracking for bubble tool loss (fish loss is handled via ItemLost below)
	local function onCharacterAdded(character)
		-- 리스폰 완료 — AncestryChanged 오발동 방지 플래그 해제
		task.defer(function()
			player:SetAttribute("IsRespawning", false)
		end)

		local Humanoid = character:WaitForChild("Humanoid")

		Humanoid.Died:Connect(function()
			-- 사망 시 장착 물고기 먼저 unequip (AncestryChanged보다 먼저 처리)
			player:SetAttribute("IsRespawning", true)
			unequipFish(player)
			DataManager:SaveData(player)
		end)

		local function childRemoved(child)
			if Humanoid.Parent == nil or Humanoid.Health <= 0 then return end
			if not child:IsA("Tool") then return end
			if IsRod(child.Name) then return end
			if child.Parent == character or child.Parent == player.Backpack then return end

			-- Only track bubble tools through the old path; fish tracked via equipped index
			if child.Name:lower():match("bubble$") then
				ItemLost(player, child.Name)
			end
		end

		character.ChildRemoved:Connect(childRemoved)

		-- Track bubble tool removal from Backpack (sold etc.)
		player.Backpack.ChildRemoved:Connect(function(child)
			if not child:IsA("Tool") then return end
			if not child.Name:lower():match("bubble$") then return end
			if child.Parent == character or child.Parent == player.Backpack then return end
			ItemLost(player, child.Name)
		end)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then onCharacterAdded(player.Character) end

	-- Mark loading complete
	local itemReady = Instance.new("BoolValue")
	itemReady.Name  = "ItemReady"
	itemReady.Value = true
	itemReady.Parent = player

	-- Send initial inventory data to client once remotes are ready
	task.spawn(function()
		-- Wait until remotes are wired
		local waitCount = 0
		while not InventoryDataSyncRemote and waitCount < 30 do
			task.wait(0.5)
			waitCount += 1
		end
		if InventoryDataSyncRemote then
			InventoryDataSyncRemote:FireClient(player, PlayerFishData[player])
		end
	end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- PlayerRemoving: save and clean up
-- ─────────────────────────────────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player)
	-- AncestryChanged 오발동으로 장착 물고기가 데이터에서 삭제되기 전에 플래그 세팅
	player:SetAttribute("IsRespawning", true)

	if pendingSaveTimers[player] then
		task.cancel(pendingSaveTimers[player])
		pendingSaveTimers[player] = nil
	end

	if player:FindFirstChild("ItemReady") then
		saveCurrentInventory(player)
	end

	PlayerFishData[player]       = nil
	PlayerEquippedIndex[player]  = nil
	PlayerEquippedTool[player]   = nil
	EquipCooldowns[player]       = nil
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- FishGiveBindable handler
-- Called by GiveFish.server.luau to transfer equipped fish from sender to receiver.
-- Returns true on success, false on failure.
-- ─────────────────────────────────────────────────────────────────────────────

local FishGiveBindable = nil
local FishGaveBindable = nil
task.spawn(function()
	local SSS = game:GetService("ServerScriptService")
	FishGiveBindable = SSS:WaitForChild("FishGiveBindable", 30)
	FishGaveBindable = SSS:WaitForChild("FishGaveBindable", 30)
	if not FishGiveBindable then return end

	FishGiveBindable.OnInvoke = function(fromPlayer, toPlayer, tool)
		local equippedIdx = PlayerEquippedIndex[fromPlayer]

		-- Fallback: equip index가 없으면 tool 이름으로 PlayerFishData에서 직접 검색
		if not equippedIdx and tool then
			local fromList = PlayerFishData[fromPlayer]
			if fromList then
				for i, fishItem in ipairs(fromList) do
					if fishItem.name == tool.Name then
						equippedIdx = i
						PlayerEquippedIndex[fromPlayer] = i
						PlayerEquippedTool[fromPlayer] = tool
						break
					end
				end
			end
		end

		if not equippedIdx then return false end

		local fromList = PlayerFishData[fromPlayer]
		if not fromList or not fromList[equippedIdx] then return false end
		local fishItem = fromList[equippedIdx]
		if fishItem.isLocked then return false end

		-- Remove from sender
		table.remove(fromList, equippedIdx)
		local prevTool = PlayerEquippedTool[fromPlayer]
		if prevTool and prevTool.Parent then prevTool:Destroy() end
		PlayerEquippedTool[fromPlayer]  = nil
		PlayerEquippedIndex[fromPlayer] = nil
		if InventoryDataSyncRemote then
			InventoryDataSyncRemote:FireClient(fromPlayer, fromList)
		end
		scheduleSave(fromPlayer)

		-- Add to receiver
		if not PlayerFishData[toPlayer] then return false end
		table.insert(PlayerFishData[toPlayer], fishItem)
		if FishDataAddedRemote then
			FishDataAddedRemote:FireClient(toPlayer, fishItem, #PlayerFishData[toPlayer])
		end
		scheduleSave(toPlayer)

		if FishGaveBindable then
			FishGaveBindable:Fire(fromPlayer)
		end

		return true
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- SellFishBindable handler
-- Called by SellShopHandler to sell fish from data table.
-- mode: "all" (sell all unlocked) | "equipped" (sell currently equipped fish)
-- Returns: totalBaseValue (number), itemsSoldCount (number)
-- ─────────────────────────────────────────────────────────────────────────────

SellFishBindable.OnInvoke = function(player, mode)
	local fishList = PlayerFishData[player]
	if not fishList then return 0, 0 end

	local totalBaseValue = 0
	local itemsSoldCount = 0

	if mode == "all" then
		-- Sell all unlocked fish
		local remaining = {}
		local equippedIdx = PlayerEquippedIndex[player]

		for i, fishItem in ipairs(fishList) do
			if fishItem.isLocked then
				table.insert(remaining, fishItem)
			else
				-- If this was the equipped fish, destroy its Tool
				if i == equippedIdx then
					local tool = PlayerEquippedTool[player]
					if tool and tool.Parent then tool:Destroy() end
					PlayerEquippedTool[player]  = nil
					PlayerEquippedIndex[player] = nil
				end
				totalBaseValue += fishItem.value
				itemsSoldCount += 1
			end
		end

		PlayerFishData[player] = remaining
		-- Adjust equipped index: if equipped was not sold (still locked), find its new position
		if PlayerEquippedIndex[player] then
			-- Recalculate equipped index in new list
			local equippedItem = fishList[equippedIdx]
			if equippedItem then
				for newIdx, item in ipairs(remaining) do
					if item == equippedItem then
						PlayerEquippedIndex[player] = newIdx
						break
					end
				end
			end
		end

	elseif mode == "equipped" then
		-- Sell only the currently equipped fish
		local equippedIdx = PlayerEquippedIndex[player]
		if not equippedIdx then return 0, 0 end

		local fishItem = fishList[equippedIdx]
		if not fishItem or fishItem.isLocked then return 0, 0 end

		-- Destroy the equipped Tool
		local tool = PlayerEquippedTool[player]
		if tool and tool.Parent then tool:Destroy() end
		PlayerEquippedTool[player]  = nil
		PlayerEquippedIndex[player] = nil

		totalBaseValue = fishItem.value
		itemsSoldCount = 1
		table.remove(fishList, equippedIdx)
	end

	-- Sync to client and save
	if InventoryDataSyncRemote then
		InventoryDataSyncRemote:FireClient(player, PlayerFishData[player])
	end
	scheduleSave(player)

	return totalBaseValue, itemsSoldCount
end
