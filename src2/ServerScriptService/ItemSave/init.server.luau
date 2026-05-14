-- Full item loader excluding rods (supports Festival + Frozen fish)
local SAVE_ON_DEATH = true

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ItemsFolder = ServerStorage:WaitForChild("Fishes")
local DataManager = require(script.DataManager)
local moduleScript = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDataModule")
local FishIceEffect = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishIceEffectModule"))
local WeatherSystemModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeatherSystemModule"))
local FishData = require(moduleScript)

-- Real-time inventory tracking table per player
local PlayerInventoryTracker = {}

-- Debounce batch-save state (scheduleSave defined after saveCurrentInventory)
local pendingSaveTimers = {}
local SAVE_DEBOUNCE = 3.0
local scheduleSave -- forward declaration

-- StripSuffixes modified to handle Festival + Frozen fish
local function StripSuffixes(name: string)
	local originalName = name
	local hasFrozen = name:find("^Frozen ") ~= nil
	local hasFestival = name:find("^Festival ") ~= nil
	local hasBoth = name:find("^Frozen Festival ") ~= nil or name:find("^Festival Frozen ") ~= nil

	-- Handle prefixes in order
	if hasBoth then
		-- Remove both Frozen Festival or Festival Frozen
		name = name:gsub("^Frozen Festival ", "")
		name = name:gsub("^Festival Frozen ", "")
	elseif hasFrozen then
		name = name:gsub("^Frozen ", "")
	elseif hasFestival then
		name = name:gsub("^Festival ", "")
	end

	-- Remove kg and grade suffix
	name = name:match("^(.-) %-%s*[%d%.]+kg$") or name -- Remove kg
	name = name:match("^(.-)%s*%[.-%]$") or name       -- Remove [grade]

	-- Restore prefixes
	if hasBoth then
		-- Maintain original order
		if originalName:find("^Frozen Festival ") then
			name = "Frozen Festival " .. name
		else
			name = "Festival Frozen " .. name
		end
	elseif hasFrozen then
		name = "Frozen " .. name
	elseif hasFestival then
		name = "Festival " .. name
	end

	return name
end

local function ExtractWeightFromName(name)
	local w = name:match("%- ([%d%.]+)kg$")
	return tonumber(w)
end

local function IsRod(itemName)
	itemName = itemName:lower()
	return itemName:match("rod$") ~= nil or itemName:match("trap$") ~= nil
end


local ChangedItemName = require(script.ChangedItemName)
local OriginalItemName = {}
for i, v in pairs(ChangedItemName) do
	OriginalItemName[v] = i
end

local function FindItem(itemName)
	-- Check if it is a bubble tool
	if itemName:lower():match("bubble$") then
		local bubbleToolsFolder = ServerStorage:FindFirstChild("BubbleTools")
		if bubbleToolsFolder then
			local bubbleTool = bubbleToolsFolder:FindFirstChild(itemName)
			if bubbleTool then
				return bubbleTool
			end
		end
		return nil
	end

	local stripped = StripSuffixes(itemName):lower()

	-- Remove all prefixes to find base name
	local baseName = stripped:gsub("^frozen ", ""):gsub("^festival ", "")

	-- Handle Frozen Festival and Festival Frozen cases
	baseName = baseName:gsub("^frozen festival ", ""):gsub("^festival frozen ", "")

	-- Check ServerStorage models directly
	if baseName == "unknown" then
		local unknownModel = ItemsFolder:FindFirstChild("Unknown")
		if unknownModel then
			return unknownModel
		else
			warn("Unknown model not found in ServerStorage!")
		end
	end

	-- Check model reference in FishData
	for _, rarity in ipairs(FishData.Rarities) do
		for _, fish in ipairs(rarity.fishes) do
			local fishNameLower = fish.fishName:lower()
			if fishNameLower == baseName then
				-- Verify model exists and is valid
				if fish.model then
					if fish.model.Parent then
						return fish.model
					else
						-- Find directly from ServerStorage
						local directModel = ItemsFolder:FindFirstChild(fish.fishName)
						if directModel then
							return directModel
						end
					end
				else
					-- Find directly from ServerStorage
					local directModel = ItemsFolder:FindFirstChild(fish.fishName)
					if directModel then
						return directModel
					end
				end
			end
		end
	end

	return nil
end

local function GetOriginalNameFromChangedItemName(itemName)
	itemName = StripSuffixes(itemName)
	return OriginalItemName[itemName] or itemName
end

-- GetFishDataByName modified to handle Festival + Frozen fish
local function GetFishDataByName(name)
	local stripped = StripSuffixes(name)
	local strippedLower = stripped:lower()

	-- Remove all prefixes
	local baseName = strippedLower:gsub("^frozen ", ""):gsub("^festival ", "")
	baseName = baseName:gsub("^frozen festival ", ""):gsub("^festival frozen ", "")

	-- Search in new structure (case insensitive)
	for _, rarity in ipairs(FishData.Rarities) do
		for _, fish in ipairs(rarity.fishes) do
			if fish.fishName:lower() == baseName then
				return {
					name = rarity.name,        -- Rarity name
					fishName = fish.fishName,  -- Fish name (original)
					value = fish.value,
					model = fish.model,
					minWeight = fish.minWeight,
					maxWeight = fish.maxWeight,
					chance = rarity.chance
				}
			end
		end
	end

	return nil
end

-- Create save data from item
local function createItemData(tool)
	local weightObj = tool:FindFirstChild("FishWeight")
	local rarityObj = tool:FindFirstChild("FishRarity")
	local fishValueObj = tool:FindFirstChild("FishValue")
	local lockObj = tool:FindFirstChild("FishLock")

	local weight = weightObj and weightObj.Value
	local rarity = rarityObj and rarityObj.Value
	local isFish = fishValueObj ~= nil

	-- Build item name (strip non-ASCII characters that break DataStore UTF-8 validation)
	local function sanitizeName(s)
		return (s:gsub("[^\32-\126\194-\244][\128-\191]*", "?"))
	end
	local itemName
	if weight and rarity then
		local baseName = sanitizeName(StripSuffixes(tool.Name))
		itemName = string.format("%s [%s] - %.1fkg", baseName, rarity, weight)
	else
		itemName = sanitizeName(tool.Name)
	end

	-- Lock state (fish only)
	local isLocked = nil
	if isFish and lockObj then
		isLocked = lockObj.Value
	end

	local hotbarSlot = tool:GetAttribute("hotbarSlot")

	return {
		name = itemName,
		isLocked = isLocked,
		isFish = isFish,
		hotbarSlot = hotbarSlot,
	}
end

-- Real-time inventory update function
local function updatePlayerInventory(player)
	-- Skip if ItemReady not set
	if not player:FindFirstChild("ItemReady") then
		return
	end

	if not PlayerInventoryTracker[player] then
		PlayerInventoryTracker[player] = {}
	end

	local currentTools = {}

	-- Collect backpack tools
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and not IsRod(tool.Name) then
				table.insert(currentTools, tool)
			end
		end
	end

	-- Collect character tools
	local character = player.Character
	if character and character.Parent then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") and not IsRod(tool.Name) then
				table.insert(currentTools, tool)
			end
		end
	end

	PlayerInventoryTracker[player] = currentTools
end

-- Real-time inventory save function (revised)
local function saveCurrentInventory(player)
	-- Skip if ItemReady not set
	if not player:FindFirstChild("ItemReady") then
		return
	end

	local Data = DataManager:GetData(player)
	if not Data then return end


	local newItemsData = {}
	local newLocksData = {}
	local newHotbarSlots = {}
	local index = 0

	-- Tool scan function
	local function tryAddTool(tool)
		if not tool:IsA("Tool") or IsRod(tool.Name) then return end

		local itemData = createItemData(tool)
		index += 1
		table.insert(newItemsData, itemData.name)

		if itemData.isFish and itemData.isLocked ~= nil then
			newLocksData[tostring(index)] = itemData.isLocked
		end
		if itemData.hotbarSlot then
			newHotbarSlots[tostring(index)] = itemData.hotbarSlot
		end
	end

	-- Collect from Backpack
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			tryAddTool(tool)
		end
	end

	-- Collect from Character (before it gets destroyed)
	local character = player.Character
	if character and character.Parent then
		for _, tool in ipairs(character:GetChildren()) do
			tryAddTool(tool)
		end
	end

	-- Find Tools in all player descendants (extra safety)
	local success, allDescendants = pcall(function()
		return player:GetDescendants()
	end)

	if success then
		for _, descendant in ipairs(allDescendants) do
			if descendant:IsA("Tool") and not IsRod(descendant.Name) then
				-- Check if already added
				local alreadyAdded = false
				for _, existingName in ipairs(newItemsData) do
					if StripSuffixes(existingName):lower() == StripSuffixes(descendant.Name):lower() then
						alreadyAdded = true
						break
					end
				end

				if not alreadyAdded then
					tryAddTool(descendant)
				end
			end
		end
	end

	-- Final save
	Data.items = newItemsData
	Data.fishLocks = newLocksData
	Data.hotbarSlots = newHotbarSlots

	DataManager:SaveData(player)
end

scheduleSave = function(player)
	if pendingSaveTimers[player] then
		task.cancel(pendingSaveTimers[player])
	end
	pendingSaveTimers[player] = task.delay(SAVE_DEBOUNCE, function()
		pendingSaveTimers[player] = nil
		if player:IsDescendantOf(game.Players) then
			saveCurrentInventory(player)
		end
	end)
end

local function ItemObtained(player, itemName)
	-- Skip rods
	if IsRod(itemName) then
		return
	end

	-- Find tool (improved)
	local tool = nil
	local backpack = player:FindFirstChild("Backpack")

	-- Find in Backpack
	if backpack then
		tool = backpack:FindFirstChild(itemName)
	end
	if not tool and player.Character then
		-- Find in Character
		tool = player.Character:FindFirstChild(itemName)
	end

	-- Find by exact name again (Unknown case)
	if not tool then
		local strippedName = StripSuffixes(itemName)
		tool = (backpack and backpack:FindFirstChild(strippedName)) or
			(player.Character and player.Character:FindFirstChild(strippedName))
	end

	if tool then
		-- Check if bubble tool
		local isBubbleTool = itemName:lower():match("bubble$") ~= nil

		if isBubbleTool then
			-- Bubble tools are saved by name only
			local success, errorMsg = pcall(function()
				if SAVE_ON_DEATH then
					tool:Clone().Parent = player.StarterGear
				end

				local originalData = DataManager:GetData(player)
				if not originalData then
					error("No player data")
				end

				if not originalData.items then
					originalData.items = {}
				end

				table.insert(originalData.items, itemName)
				scheduleSave(player)
			end)

			if not success then
				warn("Bubble tool save failed:", errorMsg)
			end
			return
		end

		-- Fish tool processing (existing logic)
		local weightObj = tool:FindFirstChild("FishWeight")
		local rarityObj = tool:FindFirstChild("FishRarity")
		local fishValueObj = tool:FindFirstChild("FishValue")
		local lockObj = tool:FindFirstChild("FishLock")

		local weight = weightObj and weightObj.Value
		local rarity = rarityObj and rarityObj.Value
		local isFish = fishValueObj ~= nil
		local isLocked = false

		if isFish and lockObj then
			isLocked = lockObj.Value
		end

		local baseName = StripSuffixes(itemName)
		local fullName

		-- Special Unknown fish error diagnostics
		if baseName:lower() == "unknown" then

			-- Print all children of Unknown tool
			for _, child in pairs(tool:GetChildren()) do
			end

			-- Error if weight or grade missing
			if not weight or not rarity then
				error("Missing required data for Unknown fish! Weight: " .. tostring(weight) .. ", Grade: " .. tostring(rarity))
				return
			end
		end

		-- General processing
		if weight and rarity then
			fullName = string.format("%s [%s] - %.1fkg", baseName, rarity, weight)
		else
			-- Error if weight or grade missing for any fish
			error("Missing fish data! Item: " .. itemName .. ", Weight: " .. tostring(weight) .. ", Grade: " .. tostring(rarity))
			return
		end

		-- Attempt to save data
		local success, errorMsg = pcall(function()
			if SAVE_ON_DEATH then
				tool:Clone().Parent = player.StarterGear
			end

			local originalData = DataManager:GetData(player)
			if not originalData then
				error("No player data")
			end

			if not originalData.items then
				originalData.items = {}
			end

			table.insert(originalData.items, fullName)

			-- Save lock state for fish only
			if isFish then
				if not originalData.fishLocks then
					originalData.fishLocks = {}
				end
				local itemIndex = #originalData.items
				originalData.fishLocks[tostring(itemIndex)] = isLocked
			end

			scheduleSave(player)
		end)

		if not success then
			warn("Save failed:", errorMsg)
		end
	else
		-- Debug for Unknown case
		if itemName:lower():find("unknown") then
			for _, item in pairs(player.Backpack:GetChildren()) do
				if item:IsA("Tool") then
				end
			end

			if player.Character then
				for _, item in pairs(player.Character:GetChildren()) do
					if item:IsA("Tool") then
					end
				end
			end
		end
	end
end

-- ItemLost function (revised, excludes rods)
local function ItemLost(player, itemName)
	-- Skip rods
	if IsRod(itemName) then
		return
	end

	local originalData = DataManager:GetData(player)
	if not originalData.items then originalData.items = {} end
	if not originalData.fishLocks then originalData.fishLocks = {} end

	local strippedItemName = StripSuffixes(itemName):lower()

	for i = #originalData.items, 1, -1 do
		local strippedStoredName = StripSuffixes(originalData.items[i]):lower()

		if strippedStoredName == strippedItemName then
			if SAVE_ON_DEATH then
				local stripped = StripSuffixes(itemName)
				for _, sgItem in ipairs(player.StarterGear:GetChildren()) do
					if StripSuffixes(sgItem.Name):lower() == stripped:lower() then
						sgItem:Destroy()
					end
				end
			end

			table.remove(originalData.items, i)

			-- Rebuild lock data (re-index after removal)
			local newFishLocks = {}
			for j = 1, #originalData.items do
				local oldKey = tostring(j < i and j or j + 1)
				if originalData.fishLocks[oldKey] then
					newFishLocks[tostring(j)] = originalData.fishLocks[oldKey]
				end
			end
			originalData.fishLocks = newFishLocks

			scheduleSave(player)
			return
		end
	end
end

-- Scale adjustment functions
local function scaleHandleByRatio(handle: BasePart, scaleRatio: number)
	if not handle or not handle:IsA("BasePart") then
		warn("Invalid handle")
		return
	end
	if scaleRatio == 1 then return end

	local originalCFrame = handle.CFrame
	local originalSize = handle.Size

	handle.Size = originalSize * scaleRatio
	handle.CFrame = originalCFrame
	handle.Massless = true

	if scaleRatio > 2 then
		handle.CustomPhysicalProperties = PhysicalProperties.new(
			0.01, 0.5, 0, 1, 1
		)
	end
end

local function getScaleRatio(weight, minWeight, maxWeight, maxScale)
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

		clone.Unequipped:Connect(function()
			-- Natural physics on unequip
		end)
	end
end

local MarketplaceService = game:GetService("MarketplaceService")
local INVENTORY_EXPANSION_GAMEPASS_ID = 1294285302

local function hasInventoryExpansionGamepass(player)
	local success, hasGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, INVENTORY_EXPANSION_GAMEPASS_ID)
	end)

	if success then
		return hasGamepass
	else
		warn("Failed to check inventory expansion gamepass:", player.Name)
		return false
	end
end

local function collectAllPlayerItems(player)
	local allItems = {}

	-- Collect items from Backpack (excluding rods)
	for _, tool in pairs(player.Backpack:GetChildren()) do
		if tool:IsA("Tool") and not IsRod(tool.Name) then
			table.insert(allItems, tool)
		end
	end

	-- Collect equipped items from Character (excluding rods)
	if player.Character then
		for _, tool in pairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") and not IsRod(tool.Name) then
				table.insert(allItems, tool)
			end
		end
	end

	return allItems
end

-- Load items on player join (excluding rods)
game.Players.PlayerAdded:Connect(function(player)
	repeat task.wait() until player:FindFirstChild("DataReady") and player:FindFirstChild("DataReady").Value == true

	repeat task.wait() until DataManager:GetData(player)
	local Data = DataManager:GetData(player)

	-- Ensure fishLocks compatibility with existing data
	if not Data.fishLocks then
		Data.fishLocks = {}
	end

	local hasExpansion = hasInventoryExpansionGamepass(player)
	local MAX_ITEMS = hasExpansion and 400 or 200
	local LOAD_LIMIT = hasExpansion and 200 or 100

	if #Data.items > MAX_ITEMS then
		local trimmed = {}
		local trimmedLocks = {}

		for i = 1, LOAD_LIMIT do
			if Data.items[i] then
				table.insert(trimmed, Data.items[i])
				-- Carry over lock state
				if Data.fishLocks[tostring(i)] then
					trimmedLocks[tostring(#trimmed)] = Data.fishLocks[tostring(i)]
				end
			end
		end

		Data.items = trimmed
		Data.fishLocks = trimmedLocks
		DataManager:UpdateData(player, "items", trimmed)
		DataManager:UpdateData(player, "fishLocks", trimmedLocks)
		DataManager:SaveData(player)
	end

	local function safeValueRatio(weight, minW, maxW)
		if minW == maxW then return 0 end
		local ratio = (weight - minW) / (maxW - minW)
		if ratio ~= ratio or ratio == math.huge or ratio == -math.huge then
			return 0
		end
		return math.clamp(ratio, 0, 1)
	end

	-- Loading loop (supports bubble tools)
	for i = 1, math.min(LOAD_LIMIT, #Data.items) do
		local itemName = Data.items[i]
		local isLocked = Data.fishLocks[tostring(i)]

		-- Skip rods
		if IsRod(itemName) then
			continue
		end

		local success, errorMsg = pcall(function()
			local item = FindItem(itemName)
			if item then
				local clone = item:Clone()

				-- Check if bubble tool
				local isBubbleTool = itemName:lower():match("bubble$") ~= nil

				if isBubbleTool then
					-- Simple loading for bubble tools
					clone.Name = itemName
					if SAVE_ON_DEATH then
						clone:Clone().Parent = player.StarterGear
					end
					clone.Parent = player.Backpack
					return -- Done processing bubble tool
				end

				-- Fish tool processing (existing logic)
				local fishData = GetFishDataByName(itemName)

				if fishData then
					local weight = ExtractWeightFromName(itemName)

					if weight then
						-- Detect and handle prefixes
						local hasFrozen = itemName:find("^Frozen ") or itemName:find("Frozen Festival") or itemName:find("Festival Frozen")
						local hasFestival = itemName:find("^Festival ") or itemName:find("Frozen Festival") or itemName:find("Festival Frozen")
						local hasBoth = itemName:find("Frozen Festival") or itemName:find("Festival Frozen")

						local nameWithGrade
						if hasBoth then
							-- Maintain original order
							if itemName:find("Frozen Festival") then
								nameWithGrade = string.format("Frozen Festival %s [%s] - %.1fkg", fishData.fishName, fishData.name, weight)
							else
								nameWithGrade = string.format("Festival Frozen %s [%s] - %.1fkg", fishData.fishName, fishData.name, weight)
							end
						elseif hasFrozen then
							nameWithGrade = string.format("Frozen %s [%s] - %.1fkg", fishData.fishName, fishData.name, weight)
						elseif hasFestival then
							nameWithGrade = string.format("Festival %s [%s] - %.1fkg", fishData.fishName, fishData.name, weight)
						else
							nameWithGrade = string.format("%s [%s] - %.1fkg", fishData.fishName, fishData.name, weight)
						end

						clone.Name = nameWithGrade

						local minW, maxW = fishData.minWeight or 1, fishData.maxWeight or 1
						local baseValue = fishData.value or 0
						local valueRatio = safeValueRatio(weight, minW, maxW)
						local adjustedValue = math.floor(baseValue * (1.2 + math.pow(valueRatio, 0.8) * 7.0))

						-- Get price multipliers from WeatherSystemModule
						local frozenMultiplier = 2.0  -- Base Frozen multiplier
						local festivalMultiplier = 1.0
						local combinedMultiplier = 1.0

						-- Get Festival multiplier from WeatherSystemModule
						if WeatherSystemModule and WeatherSystemModule.WeatherTypes and WeatherSystemModule.WeatherTypes.Firework then
							festivalMultiplier = WeatherSystemModule.WeatherTypes.Firework.effects.valueMultiplier or 1.5
						else
							festivalMultiplier = 1.5  -- Default value
						end

						-- Apply price bonuses
						if hasBoth then
							-- Both Frozen + Festival: multiply together
							combinedMultiplier = frozenMultiplier * festivalMultiplier
							adjustedValue = adjustedValue * combinedMultiplier
						elseif hasFrozen then
							-- Frozen only: 2x
							adjustedValue = adjustedValue * frozenMultiplier
						elseif hasFestival then
							-- Festival only: use WeatherSystemModule multiplier
							adjustedValue = adjustedValue * festivalMultiplier
						end

						-- Create value objects
						local valueObj = clone:FindFirstChild("FishValue")
						if not valueObj then
							valueObj = Instance.new("IntValue")
							valueObj.Name = "FishValue"
							valueObj.Parent = clone
						end
						valueObj.Value = adjustedValue

						local weightObj = clone:FindFirstChild("FishWeight")
						if not weightObj then
							weightObj = Instance.new("NumberValue")
							weightObj.Name = "FishWeight"
							weightObj.Parent = clone
						end
						weightObj.Value = weight

						local rarityObj = clone:FindFirstChild("FishRarity")
						if not rarityObj then
							rarityObj = Instance.new("StringValue")
							rarityObj.Name = "FishRarity"
							rarityObj.Parent = clone
						end
						rarityObj.Value = fishData.name

						-- Lock state object (fish only)
						if isLocked ~= nil then
							local lockObj = clone:FindFirstChild("FishLock")
							if not lockObj then
								lockObj = Instance.new("BoolValue")
								lockObj.Name = "FishLock"
								lockObj.Parent = clone
							end
							lockObj.Value = isLocked
						end

						-- Apply effects
						if hasFrozen then
							local fishInfo = {
								fishName = nameWithGrade,
								currentWeather = "Snow"
							}
							FishIceEffect.ApplyIceEffect(clone, fishInfo)
						end

						if hasFestival then
							local fishInfo = {
								fishName = nameWithGrade,
								currentWeather = "Firework"
							}
							-- Use FishData.ApplyFestivalEffect (function in FishDataModule)
							FishData.ApplyFestivalEffect(clone, fishInfo)
						end

						fixLoadedFishSize(clone, weight, fishData)
					else
						-- Error on weight extraction failure
						error("Weight extraction failed: " .. itemName)
					end
				else
					-- Error if no fish data found
					error("No fish data found: " .. itemName)
				end

				local hotbarSlot = Data.hotbarSlots and Data.hotbarSlots[tostring(i)]
				if hotbarSlot then
					clone:SetAttribute("hotbarSlot", hotbarSlot)
					clone:SetAttribute("position", hotbarSlot)
				end
				if SAVE_ON_DEATH then
					clone:Clone().Parent = player.StarterGear
				end
				clone.Parent = player.Backpack
			else
				-- Error if model not found
				error("Model not found: " .. itemName)
			end
		end)

		if not success then
			warn("Item loading failed:", itemName, "Error:", errorMsg)
		end
	end

	-- Detect character respawn
	local function onCharacterAdded(character)
		local Humanoid = character:WaitForChild("Humanoid")

		-- Death handling (save real-time inventory and kick)
		Humanoid.Died:Connect(function()
			player:Kick("How did you die?")
		end)

		-- Events for real-time inventory tracking
		local function childAdded(child)
			if not child:IsA("Tool") then return end
			if IsRod(child.Name) then return end

			ItemObtained(player, child.Name)

			-- Small delay for stability
			task.wait(0.1)
			updatePlayerInventory(player)
		end

		local function childRemoved(child)
			if Humanoid.Parent == nil or Humanoid.Health <= 0 then return end
			if not child:IsA("Tool") then return end
			if IsRod(child.Name) then return end
			if child.Parent == character or child.Parent == player.Backpack then return end

			ItemLost(player, child.Name)

			-- Update inventory
			task.wait(0.1)
			updatePlayerInventory(player)
		end

		character.ChildAdded:Connect(childAdded)
		character.ChildRemoved:Connect(childRemoved)
		player.Backpack.ChildAdded:Connect(childAdded)
		player.Backpack.ChildRemoved:Connect(childRemoved)

		-- Initial inventory tracking setup
		updatePlayerInventory(player)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then onCharacterAdded(player.Character) end

	-- Set ItemReady after all loading is complete
	local itemReady = Instance.new("BoolValue")
	itemReady.Name = "ItemReady"
	itemReady.Value = true
	itemReady.Parent = player

end)

-- PlayerRemoving event (revised, checks ItemReady)
game.Players.PlayerRemoving:Connect(function(player)
	-- Cancel any pending debounce timer; we save immediately below
	if pendingSaveTimers[player] then
		task.cancel(pendingSaveTimers[player])
		pendingSaveTimers[player] = nil
	end

	-- Skip save if ItemReady not set
	if not player:FindFirstChild("ItemReady") then
		PlayerInventoryTracker[player] = nil
		return
	end

	-- Use tracked inventory for saving if available
	if PlayerInventoryTracker[player] then
		local Data = DataManager:GetData(player)
		if Data then
			local newItemsData = {}
			local newLocksData = {}
			local newHotbarSlots = {}
			local index = 0

			for _, tool in ipairs(PlayerInventoryTracker[player]) do
				if tool and tool.Parent then -- Verify tool is still valid
					local itemData = createItemData(tool)
					index += 1
					table.insert(newItemsData, itemData.name)

					if itemData.isFish and itemData.isLocked ~= nil then
						newLocksData[tostring(index)] = itemData.isLocked
					end
					if itemData.hotbarSlot then
						newHotbarSlots[tostring(index)] = itemData.hotbarSlot
					end
				end
			end

			Data.items = newItemsData
			Data.fishLocks = newLocksData
			Data.hotbarSlots = newHotbarSlots
			DataManager:SaveData(player)
		end
	else
		-- Fall back to existing method if no tracked inventory
		saveCurrentInventory(player)
	end

	-- Clean up tracking data
	PlayerInventoryTracker[player] = nil
end)
