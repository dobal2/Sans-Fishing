-- ✅ 낚싯대 제외 완전한 아이템 로더 (Festival + Frozen 물고기 지원)
local SAVE_ON_DEATH = true

local ItemsFolder = game.ServerStorage:WaitForChild("Fishes")
local ServerStorage = game:GetService("ServerStorage")
local DataManager = require(script.DataManager)
local moduleScript = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("FishDataModule")
local FishIceEffect = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("FishIceEffectModule"))
local WeatherSystemModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("WeatherSystemModule"))
local FishData = require(moduleScript)
local Players = game:GetService("Players")

-- 🔥 플레이어별 실시간 인벤토리 추적 테이블 추가
local PlayerInventoryTracker = {}

local function StripSuffixes(name: string)
	local originalName = name

	-- 🆕 인첸트 변이 접두사들 추가
	local mutationPrefixes = {
		"Windy", "Wet", "赤", "青", "Long", "Massive",
		"Trinity", "Rainbow", "Clover", "Lucky", "Void", "ERROR", "紫",
		"Frozen", "Festival"
	}

	-- 원본에서 모든 접두사 찾기
	local foundPrefixes = {}
	local workingName = name

	-- 여러 접두사가 있을 수 있으므로 반복해서 찾기
	local changed = true
	while changed do
		changed = false
		for _, prefix in ipairs(mutationPrefixes) do
			local pattern = "^" .. prefix .. " "
			if workingName:find(pattern) then
				table.insert(foundPrefixes, 1, prefix)  -- 앞에서부터 삽입 (순서 유지)
				workingName = workingName:gsub(pattern, "")
				changed = true
				break
			end
		end
	end

	-- kg와 등급 제거
	workingName = workingName:match("^(.-) %-%s*[%d%.]+kg$") or workingName  -- kg 제거
	workingName = workingName:match("^(.-)%s*%[.-%]$") or workingName        -- [등급] 제거

	-- 접두사 복원 (원래 순서대로)
	if #foundPrefixes > 0 then
		local prefixString = table.concat(foundPrefixes, " ")
		workingName = prefixString .. " " .. workingName
	end

	return workingName
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
	-- 버블 툴인지 확인
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

	-- 🆕 모든 변이 접두사 제거해서 기본 이름 찾기
	local baseName = stripped
	local mutationPrefixes = {
		"windy", "wet", "赤", "青", "long", "massive",
		"trinity", "rainbow", "clover", "lucky", "void", "error", "紫",
		"frozen", "festival"
	}

	-- 모든 접두사 제거
	for _, prefix in ipairs(mutationPrefixes) do
		baseName = baseName:gsub("^" .. prefix .. " ", "")
	end

	-- ServerStorage 모델들 직접 확인
	if baseName == "unknown" then
		local unknownModel = ItemsFolder:FindFirstChild("Unknown")
		if unknownModel then
			return unknownModel
		else
			warn("❌ ServerStorage에 Unknown 모델이 없음!")
		end
	end

	-- 🔧 FishData에서 모델 참조 확인
	for _, rarity in ipairs(FishData.Rarities) do
		for _, fish in ipairs(rarity.fishes) do
			local fishNameLower = fish.fishName:lower()
			if fishNameLower == baseName then
				if fish.model then
					if fish.model.Parent then
						return fish.model
					else
						local directModel = ItemsFolder:FindFirstChild(fish.fishName)
						if directModel then
							return directModel
						end
					end
				else
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

local function GetFishDataByName(name)
	local stripped = StripSuffixes(name)
	local strippedLower = stripped:lower()

	-- 🆕 모든 변이 접두사 제거
	local baseName = strippedLower
	local mutationPrefixes = {
		"windy", "wet", "赤", "青", "long", "massive",
		"trinity", "rainbow", "clover", "lucky", "void", "error", "紫",
		"frozen", "festival"
	}

	for _, prefix in ipairs(mutationPrefixes) do
		baseName = baseName:gsub("^" .. prefix .. " ", "")
	end

	-- 새로운 구조에서 검색 (대소문자 무시)
	for _, rarity in ipairs(FishData.Rarities) do
		for _, fish in ipairs(rarity.fishes) do
			if fish.fishName:lower() == baseName then
				return {
					name = rarity.name,        -- 등급명
					fishName = fish.fishName,  -- 물고기명 (원본)
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

-- 🔥 새로운 함수: 아이템으로부터 저장용 데이터 생성
local function createItemData(tool)
	local weightObj = tool:FindFirstChild("FishWeight")
	local rarityObj = tool:FindFirstChild("FishRarity")
	local fishValueObj = tool:FindFirstChild("FishValue")
	local lockObj = tool:FindFirstChild("FishLock")

	local weight = weightObj and weightObj.Value
	local rarity = rarityObj and rarityObj.Value
	local isFish = fishValueObj ~= nil

	-- 아이템 이름 구성
	local itemName
	if weight and rarity then
		local baseName = StripSuffixes(tool.Name)
		itemName = string.format("%s [%s] - %.1fkg", baseName, rarity, weight)
	else
		itemName = tool.Name
	end

	-- 잠금 상태 (물고기만)
	local isLocked = nil
	if isFish and lockObj then
		isLocked = lockObj.Value
	end

	return {
		name = itemName,
		isLocked = isLocked,
		isFish = isFish
	}
end

-- 🔥 실시간 인벤토리 업데이트 함수
local function updatePlayerInventory(player)
	-- ItemReady가 없으면 추적하지 않음
	if not player:FindFirstChild("ItemReady") then
		return
	end

	if not PlayerInventoryTracker[player] then
		PlayerInventoryTracker[player] = {}
	end

	local currentTools = {}

	-- Backpack 도구 수집
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and not IsRod(tool.Name) then
				table.insert(currentTools, tool)
			end
		end
	end

	-- Character 도구 수집
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

-- 🔥 수정된 실시간 인벤토리 저장 함수
local function saveCurrentInventory(player)
	-- ItemReady가 없으면 저장하지 않음
	if not player:FindFirstChild("ItemReady") then
		print("⚠️ " .. player.Name .. " ItemReady가 없어서 저장하지 않음")
		return
	end

	local Data = DataManager:GetData(player)
	if not Data then return end

	print("💾 " .. player.Name .. " 실시간 인벤토리 저장 시작")

	local newItemsData = {}
	local newLocksData = {}
	local index = 0

	-- 도구 스캔 함수
	local function tryAddTool(tool)
		if not tool:IsA("Tool") or IsRod(tool.Name) then return end

		local itemData = createItemData(tool)
		index += 1
		table.insert(newItemsData, itemData.name)

		if itemData.isFish and itemData.isLocked ~= nil then
			newLocksData[tostring(index)] = itemData.isLocked
		end
	end

	-- ✅ Backpack 수집
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			tryAddTool(tool)
		end
	end

	-- ✅ Character 수집 (삭제되기 전에 먼저 시도)
	local character = player.Character
	if character and character.Parent then
		for _, tool in ipairs(character:GetChildren()) do
			tryAddTool(tool)
		end
	end

	-- ✅ Player의 모든 하위 객체에서 Tool 찾기 (추가 안전장치)
	local success, allDescendants = pcall(function()
		return player:GetDescendants()
	end)

	if success then
		for _, descendant in ipairs(allDescendants) do
			if descendant:IsA("Tool") and not IsRod(descendant.Name) then
				-- 이미 추가된 도구인지 확인
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

	-- 최종 저장
	Data.items = newItemsData
	Data.fishLocks = newLocksData

	--print("📦 " .. player.Name .. " 저장된 아이템 수: " .. #newItemsData)
	for i, item in ipairs(newItemsData) do
		local lockStatus = newLocksData[tostring(i)] and "🔒" or "🔓"
		--print("   " .. i .. ": " .. item .. " " .. lockStatus)
	end

	DataManager:SaveData(player)
	--print("✅ " .. player.Name .. " 인벤토리 저장 완료")
end

local function ItemObtained(player, itemName)
	-- 🚫 낚싯대는 저장하지 않음
	if IsRod(itemName) then
		return
	end

	-- 🔧 도구 찾기 개선
	local tool = nil

	-- Backpack에서 찾기
	tool = player.Backpack:FindFirstChild(itemName)
	if not tool and player.Character then
		-- Character에서 찾기
		tool = player.Character:FindFirstChild(itemName)
	end

	-- 🔧 정확한 이름으로 다시 찾기 (Unknown 케이스)
	if not tool then
		local strippedName = StripSuffixes(itemName)
		tool = player.Backpack:FindFirstChild(strippedName) or
			(player.Character and player.Character:FindFirstChild(strippedName))
	end

	if tool then
		-- 버블 도구인지 확인
		local isBubbleTool = itemName:lower():match("bubble$") ~= nil

		if isBubbleTool then
			-- 버블 도구는 단순히 이름만 저장
			local success, errorMsg = pcall(function()
				if SAVE_ON_DEATH then
					tool:Clone().Parent = player.StarterGear
				end

				local originalData = DataManager:GetData(player)
				if not originalData then
					error("플레이어 데이터 없음")
				end

				if not originalData.items then
					originalData.items = {}
				end

				table.insert(originalData.items, itemName)
				DataManager:SaveData(player)
			end)

			if not success then
				warn("❌ 버블 도구 저장 실패:", errorMsg)
			end
			return
		end

		-- 물고기 도구 처리 (기존 로직)
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

		-- 🚨 Unknown 특별 에러 진단
		if baseName:lower() == "unknown" then
			print("🚨 Unknown 물고기 에러 진단:")
			print("   - 도구명:", tool.Name)
			print("   - FishWeight:", weightObj and ("값: " .. weightObj.Value) or "❌ 없음")
			print("   - FishRarity:", rarityObj and ("값: " .. rarityObj.Value) or "❌ 없음")
			print("   - FishValue:", fishValueObj and ("값: " .. fishValueObj.Value) or "❌ 없음")
			print("   - FishLock:", lockObj and ("값: " .. tostring(lockObj.Value)) or "없음")

			-- Unknown 도구의 모든 자식 출력
			print("   - 도구 자식들:")
			for _, child in pairs(tool:GetChildren()) do
				print("     └", child.Name, "(" .. child.ClassName .. ")")
			end

			-- 무게나 등급이 없으면 에러 발생
			if not weight or not rarity then
				error("❌ Unknown 물고기에 필수 데이터 누락! 무게: " .. tostring(weight) .. ", 등급: " .. tostring(rarity))
				return
			end
		end

		-- 일반적인 처리
		if weight and rarity then
			fullName = string.format("%s [%s] - %.1fkg", baseName, rarity, weight)
		else
			-- 일반 물고기도 무게/등급 없으면 에러
			error("❌ 물고기 데이터 누락! 아이템: " .. itemName .. ", 무게: " .. tostring(weight) .. ", 등급: " .. tostring(rarity))
			return
		end

		-- 🔧 데이터 저장 시도
		local success, errorMsg = pcall(function()
			if SAVE_ON_DEATH then
				tool:Clone().Parent = player.StarterGear
			end

			local originalData = DataManager:GetData(player)
			if not originalData then
				error("플레이어 데이터 없음")
			end

			if not originalData.items then
				originalData.items = {}
			end

			table.insert(originalData.items, fullName)

			-- 물고기인 경우에만 잠금 상태 저장
			if isFish then
				if not originalData.fishLocks then
					originalData.fishLocks = {}
				end
				local itemIndex = #originalData.items
				originalData.fishLocks[tostring(itemIndex)] = isLocked
			end

			DataManager:SaveData(player)
		end)

		if not success then
			warn("❌ 저장 실패:", errorMsg)
		end
	else
		-- 🔍 Unknown 케이스 특별 디버깅
		if itemName:lower():find("unknown") then
			print("🚨 Unknown 도구 찾기 실패 디버깅:")
			print("📋 Backpack 내용:")
			for _, item in pairs(player.Backpack:GetChildren()) do
				if item:IsA("Tool") then
					print("   -", item.Name)
				end
			end

			if player.Character then
				print("📋 Character 내용:")
				for _, item in pairs(player.Character:GetChildren()) do
					if item:IsA("Tool") then
						print("   -", item.Name)
					end
				end
			end
		end
	end
end

-- 🔧 수정된 ItemLost 함수 (낚싯대 제외)
local function ItemLost(player, itemName)
	-- 🚫 낚싯대는 삭제 처리하지 않음
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

			-- 🔒 잠금 데이터도 정리 (인덱스 재조정)
			local newFishLocks = {}
			for j = 1, #originalData.items do
				local oldKey = tostring(j < i and j or j + 1)
				if originalData.fishLocks[oldKey] then
					newFishLocks[tostring(j)] = originalData.fishLocks[oldKey]
				end
			end
			originalData.fishLocks = newFishLocks

			DataManager:SaveData(player)
			return
		end
	end
end

-- 수정된 크기 조정 함수들
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
			-- Tool 해제 시 자연스러운 물리
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
		warn("인벤토리 확장 게임패스 확인 실패:", player.Name)
		return false
	end
end

local function collectAllPlayerItems(player)
	local allItems = {}

	-- Backpack에서 아이템 수집 (낚싯대 제외)
	for _, tool in pairs(player.Backpack:GetChildren()) do
		if tool:IsA("Tool") and not IsRod(tool.Name) then
			table.insert(allItems, tool)
		end
	end

	-- Character에서 장착된 아이템 수집 (낚싯대 제외)
	if player.Character then
		for _, tool in pairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") and not IsRod(tool.Name) then
				table.insert(allItems, tool)
			end
		end
	end

	return allItems
end

local function getMutationBonus(itemName)
	local totalBonus = 0
	local appliedMutations = {}

	-- 각 변이별 보너스 값 (합산 방식)
	local mutationValues = {
		["Windy"] = 0.6,
		["Wet"] = 0.6,
		["赤"] = 1.0,
		["青"] = 1.0,
		["Long"] = 1.5,
		["Massive"] = 3.0,
		["Trinity"] = 3.0,
		["Rainbow"] = 3.5,
		["Clover"] = 4.0,
		["Lucky"] = 5.0,
		["Void"] = 7.0,
		["ERROR"] = 20.0,
		["紫"] = 12.0,
		["Frozen"] = 0.4,
		["Festival"] = 0.3
	}

	-- 아이템 이름에서 변이 찾기 (합산)
	for mutation, bonus in pairs(mutationValues) do
		if itemName:find(mutation) then
			totalBonus = totalBonus + bonus
			table.insert(appliedMutations, mutation)
		end
	end

	return totalBonus, appliedMutations
end


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ParticleFolder = ReplicatedStorage:WaitForChild("Particle") -- 파티클 폴더

local function applyMutationEffects(clone, itemName, fishInfo)
	-- 변이 이름 매핑 (일본/중국어 → 영어 포함)
	local mutationMap = {
		["赤"] = "Red",
		["青"] = "Blue",
		["紫"] = "Purple",
		["Massive"] = "Massive",
		["Rainbow"] = "Rainbow",
		["Red"] = "Red",
		["Blue"] = "Blue",
		["Trinity"] = "Trinity",
		["Windy"] = "Windy",
		["Wet"] = "Wet",
		["Luck"] = "Luck",
		["Clover"] = "Clover",
		["Void"] = "Void",
	}

	for symbolOrName, mutation in pairs(mutationMap) do
		if itemName:find(symbolOrName) then
			for _, attach in ipairs(ParticleFolder:GetChildren()) do
				if attach:IsA("Attachment") and attach.Name:match("^" .. mutation) then
					local cloneAttach = attach:Clone()
					cloneAttach.Parent = clone
				end
			end
		end
	end

	if itemName:find("ERROR") then
		local errorFolder = ParticleFolder:FindFirstChild("ERROR")
		if errorFolder then
			for _, obj in ipairs(errorFolder:GetChildren()) do
				local cloneObj = obj:Clone()
				cloneObj.Parent = clone
			end
		end
	end

	-- 기존 Frozen, Festival 처리
	if itemName:find("Frozen") then
		FishIceEffect.ApplyIceEffect(clone, { fishName = itemName, currentWeather = "Snow" })
	end
	--if itemName:find("Festival") then
	--	FishData.ApplyFestivalEffect(clone, { fishName = itemName, currentWeather = "Firework" })
	--end
end


-- ✅ 플레이어 접속 시 불러오기 (낚싯대 제외)
game.Players.PlayerAdded:Connect(function(player)
	repeat task.wait() until player:FindFirstChild("DataReady") and player:FindFirstChild("DataReady").Value == true

	repeat task.wait() until DataManager:GetData(player)
	local Data = DataManager:GetData(player)

	-- 🔒 기존 데이터 호환성 확인
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
				-- 🔒 잠금 상태도 함께 정리
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

	-- 수정된 로딩 루프 (버블 도구 지원)
	for i = 1, math.min(LOAD_LIMIT, #Data.items) do
		local itemName = Data.items[i]
		local isLocked = Data.fishLocks[tostring(i)]

		-- 낚싯대는 로드하지 않음
		if IsRod(itemName) then
			continue
		end

		local success, errorMsg = pcall(function()
			local item = FindItem(itemName)
			if item then
				local clone = item:Clone()

				-- 버블 도구인지 확인
				local isBubbleTool = itemName:lower():match("bubble$") ~= nil

				if isBubbleTool then
					-- 버블 도구는 단순 로딩
					clone.Name = itemName
					if SAVE_ON_DEATH then
						clone:Clone().Parent = player.StarterGear
					end
					clone.Parent = player.Backpack
					return
				end

				-- 물고기 도구 처리
				local fishData = GetFishDataByName(itemName)

				if fishData then
					local weight = ExtractWeightFromName(itemName)

					if weight then
						-- 🆕 모든 변이 감지 (기존 Frozen, Festival 포함)
						local hasAnyMutation = false
						local mutationPrefixes = {}

						-- 변이들을 순서대로 감지
						local allMutations = {
							"Windy", "Wet", "赤", "青", "Long", "Massive",
							"Trinity", "Rainbow", "Clover", "Lucky", "Void", "ERROR", "紫",
							"Frozen", "Festival"
						}

						for _, mutation in ipairs(allMutations) do
							if itemName:find(mutation) then
								table.insert(mutationPrefixes, mutation)
								hasAnyMutation = true
							end
						end

						-- 이름 구성
						local nameWithGrade
						if hasAnyMutation and #mutationPrefixes > 0 then
							local prefixString = table.concat(mutationPrefixes, " ")
							nameWithGrade = string.format("%s %s [%s] - %.1fkg", prefixString, fishData.fishName, fishData.name, weight)
						else
							nameWithGrade = string.format("%s [%s] - %.1fkg", fishData.fishName, fishData.name, weight)
						end

						clone.Name = nameWithGrade

						-- 🆕 변이별 가격 배수 계산
						local minW, maxW = fishData.minWeight or 1, fishData.maxWeight or 1
						local baseValue = fishData.value or 0
						local valueRatio = safeValueRatio(weight, minW, maxW)
						local adjustedValue = math.floor(baseValue * (1.2 + math.pow(valueRatio, 0.8) * 7.0))

						-- 변이 배수 적용
						local mutationBonus, appliedMutations = getMutationBonus(itemName)
						adjustedValue = math.floor(adjustedValue * (1 + mutationBonus))

						if #appliedMutations > 0 then
							print("💰 변이 보너스 적용:", table.concat(appliedMutations, ", "), "보너스:", mutationBonus, "최종 가격:", adjustedValue)
						end

						-- 값 객체들 생성 (기존과 동일)
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

						-- 잠금 상태 객체
						if isLocked ~= nil then
							local lockObj = clone:FindFirstChild("FishLock")
							if not lockObj then
								lockObj = Instance.new("BoolValue")
								lockObj.Name = "FishLock"
								lockObj.Parent = clone
							end
							lockObj.Value = isLocked
						end

						-- 🆕 모든 변이 이펙트 적용
						applyMutationEffects(clone, itemName, fishData)

						fixLoadedFishSize(clone, weight, fishData)
					else
						error("무게 추출 실패: " .. itemName)
					end
				else
					error("물고기 데이터 없음: " .. itemName)
				end

				if SAVE_ON_DEATH then
					clone:Clone().Parent = player.StarterGear
				end
				clone.Parent = player.Backpack
			else
				error("모델을 찾을 수 없음: " .. itemName)
			end
		end)

		if not success then
			warn("아이템 로딩 실패:", itemName, "에러:", errorMsg)
		end
	end

	-- 캐릭터 리스폰 감지
	local function onCharacterAdded(character)
		local Humanoid = character:WaitForChild("Humanoid")

		-- 🔥 수정된 죽음 처리 - 실시간 저장으로 덮어쓰고 킥
		Humanoid.Died:Connect(function()
			print("사망")
			player:Kick("How did you die?")
		end)

		-- 🔥 실시간 인벤토리 추적을 위한 이벤트들
		local function childAdded(child)
			if not child:IsA("Tool") then return end
			if IsRod(child.Name) then return end

			ItemObtained(player, child.Name)

			-- 실시간 인벤토리 업데이트
			task.wait(0.1) -- 약간의 지연으로 안정성 확보
			updatePlayerInventory(player)
		end

		local function childRemoved(child)
			if Humanoid.Parent == nil or Humanoid.Health <= 0 then return end
			if not child:IsA("Tool") then return end
			if IsRod(child.Name) then return end
			if child.Parent == character or child.Parent == player.Backpack then return end

			ItemLost(player, child.Name)

			-- 실시간 인벤토리 업데이트
			task.wait(0.1)
			updatePlayerInventory(player)
		end

		character.ChildAdded:Connect(childAdded)
		character.ChildRemoved:Connect(childRemoved)
		player.Backpack.ChildAdded:Connect(childAdded)
		player.Backpack.ChildRemoved:Connect(childRemoved)

		-- 초기 인벤토리 추적 설정
		updatePlayerInventory(player)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then onCharacterAdded(player.Character) end

	-- ✅ ItemReady 설정 (모든 로딩이 끝난 후)
	local itemReady = Instance.new("BoolValue")
	itemReady.Name = "ItemReady"
	itemReady.Value = true
	itemReady.Parent = player

	print("✅ " .. player.Name .. " ItemReady 설정 완료")
end)



-- 🔥 수정된 PlayerRemoving 이벤트 (ItemReady 확인 포함)
game.Players.PlayerRemoving:Connect(function(player)
	print("🚪 " .. player.Name .. " 나가는 중")

	-- ItemReady가 없으면 저장하지 않음
	if not player:FindFirstChild("ItemReady") then
		print("⚠️ " .. player.Name .. " ItemReady가 없어서 저장하지 않고 종료")
		PlayerInventoryTracker[player] = nil
		return
	end

	-- 추적된 인벤토리가 있다면 그것을 사용하여 저장
	if PlayerInventoryTracker[player] then
		local Data = DataManager:GetData(player)
		if Data then
			local newItemsData = {}
			local newLocksData = {}
			local index = 0

			for _, tool in ipairs(PlayerInventoryTracker[player]) do
				if tool and tool.Parent then -- 도구가 아직 유효한지 확인
					local itemData = createItemData(tool)
					index += 1
					table.insert(newItemsData, itemData.name)

					if itemData.isFish and itemData.isLocked ~= nil then
						newLocksData[tostring(index)] = itemData.isLocked
					end
				end
			end

			Data.items = newItemsData
			Data.fishLocks = newLocksData
			DataManager:SaveData(player)
			print("📦 " .. player.Name .. " 추적된 인벤토리로 저장 완료: " .. #newItemsData .. "개")
		end
	else
		-- 추적된 인벤토리가 없다면 기존 방식 사용
		saveCurrentInventory(player)
	end

	-- 추적 데이터 정리
	PlayerInventoryTracker[player] = nil
end)
