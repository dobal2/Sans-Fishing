-- FishData Module (Enhanced with Enchant System Support)
local FishData = {}
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local LuckGamePassId = 1289569606

local serverStorage = game:GetService("ServerStorage")
local fishFolder = serverStorage:WaitForChild("Fishes")

-- WeatherSystem 모듈 로드
local WeatherSystem = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("WeatherSystemModule"))

-- EnchantModule 로드
local EnchantModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("EnchantModule"))

local ICE_SETTINGS = {
	material = Enum.Material.Plastic,
	transparency = 0.3,
	color = Color3.fromRGB(200, 240, 255),
	size_multiplier = 1.05,
	glow_intensity = 0.3
}

-- FishData.Rarities (기존과 동일)
FishData.Rarities = {
	{
		name = "Common",
		chance = 46.9,
		fishes = {
			{ fishName = "Small Carp", value = 600, model = fishFolder:WaitForChild("small carp"), minWeight = 0.8, maxWeight = 100.0 },
			{ fishName = "Gold Fish", value = 660, model = fishFolder:WaitForChild("Gold Fish"), minWeight = 0.8, maxWeight = 100.0 },
			{ fishName = "Stone Fish", value = 600, model = fishFolder:WaitForChild("Stone Fish"), minWeight = 0.8, maxWeight = 100.0 }
		}
	},
	{
		name = "Uncommon",
		chance = 25,
		fishes = {
			{ fishName = "Crab", value = 920, model = fishFolder:WaitForChild("Crab"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Crystal Bass", value = 1020, model = fishFolder:WaitForChild("Crystal Bass"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Dust Fish", value = 1080, model = fishFolder:WaitForChild("Dust Fish"), minWeight = 1.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Rare",
		chance = 15,
		fishes = {
			{ fishName = "Bass", value = 2300, model = fishFolder:WaitForChild("Bass"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Snow Fish", value = 2450, model = fishFolder:WaitForChild("Snow Fish"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Diri", value = 2400, model = fishFolder:WaitForChild("Diri"), minWeight = 2, maxWeight = 100.0 }
		}
	},
	{
		name = "Epic",
		chance = 8,
		fishes = {
			{ fishName = "Dragon Head Fish", value = 3900, model = fishFolder:WaitForChild("Dragon Head Fish"), minWeight = 3.5, maxWeight = 100.0 },
			{ fishName = "Reggigash", value = 4400, model = fishFolder:WaitForChild("Reggigash"), minWeight = 2, maxWeight = 100.0 }
		}
	},
	{
		name = "Legendary",
		chance = 3,
		fishes = {
			{ fishName = "Golden Trout", value = 6300, model = fishFolder:WaitForChild("Golden Trout"), minWeight = 3.0, maxWeight = 100.0 },
			{ fishName = "Armor Fish", value = 7400, model = fishFolder:WaitForChild("Armor Fish"), minWeight = 3.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Mystic",
		chance = 1.5,
		fishes = {
			{ fishName = "Shark", value = 11300, model = fishFolder:WaitForChild("Shark"), minWeight = 5.0, maxWeight = 100.0 },
			{ fishName = "Ray", value = 12000, model = fishFolder:WaitForChild("Ray"), minWeight = 5.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Fantasy",
		chance = 0.5,
		fishes = {
			{ fishName = "Undyine", value = 31000, model = fishFolder:WaitForChild("Undyine"), minWeight = 3.0, maxWeight = 100.0 },
			{ fishName = "Sans", value = 33000, model = fishFolder:WaitForChild("Sans"), minWeight = 3.0, maxWeight = 100.0 },
			{ fishName = "Electric Fish", value = 48000, model = fishFolder:WaitForChild("Electric Fish"), minWeight = 3.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Unknown",
		chance = 0.1,
		fishes = {
			{ fishName = "Unknown", value = 130000, model = fishFolder:WaitForChild("Unknown"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Nyan Cat", value = 145000, model = fishFolder:WaitForChild("Nyan Cat"), minWeight = 1.0, maxWeight = 100.0 }
		}
	}
}

-- 기존 함수들 (createIceBlock, applyIceEffect 등) - 동일하게 유지
local function createIceBlock(fishModel, fishInfo)
	if not fishModel then
		warn("물고기 모델이 없습니다")
		return nil
	end

	local targetPart = fishModel.PrimaryPart or fishModel:FindFirstChild("Handle")
	if not targetPart then
		warn("물고기 모델에 PrimaryPart 또는 Handle이 없습니다:", fishModel.Name)
		return nil
	end

	local fishWeight = fishInfo and fishInfo.weight
	local sizeMultiplier = ICE_SETTINGS.size_multiplier or 1.2

	if fishWeight then
		local weightMultiplier = 1.0 + (fishWeight - 1) * 0.01
		weightMultiplier = math.max(0.9, math.min(1.5, weightMultiplier))
		sizeMultiplier = sizeMultiplier * weightMultiplier
	end

	local size = targetPart.Size
	local iceBlock = Instance.new("Part")
	iceBlock.Name = "IceBlock"
	iceBlock.Material = ICE_SETTINGS.material
	iceBlock.Transparency = ICE_SETTINGS.transparency
	iceBlock.Color = ICE_SETTINGS.color
	iceBlock.CanCollide = false
	iceBlock.Anchored = false
	iceBlock.Size = size * sizeMultiplier

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1.1, 0.8, 1.1)
	mesh.Parent = iceBlock

	local pointLight = Instance.new("PointLight")
	pointLight.Color = ICE_SETTINGS.color
	pointLight.Brightness = ICE_SETTINGS.glow_intensity
	pointLight.Range = size.Magnitude * 2
	pointLight.Parent = iceBlock

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = targetPart
	weld.Part1 = iceBlock
	weld.Parent = iceBlock

	iceBlock.Parent = fishModel
	return iceBlock
end

local function applyIceEffect(fishModel, fishInfo)
	if not fishModel then
		warn("물고기 모델이 없습니다")
		return false
	end

	if fishModel:FindFirstChild("IceBlock") then
		print("이미 얼음 효과가 적용되어 있습니다:", fishModel.Name)
		return false
	end

	if not fishInfo or not fishInfo.fishName or not string.find(fishInfo.fishName, "Frozen") then
		return false
	end

	local iceBlock = createIceBlock(fishModel, fishInfo)
	if not iceBlock then
		warn("얼음 블록 생성 실패")
		return false
	end

	fishModel:SetAttribute("HasIceEffect", true)
	fishModel:SetAttribute("IceAppliedTime", tick())
	return true
end

-- 무게 확률 함수 (기존과 동일)
local function getFixedProbabilityWeight(minW, maxW)
	local rng = Random.new()
	local r = rng:NextNumber()

	local ranges = {
		{low = 1,   high = 5,   chance = 0.708},
		{low = 5,   high = 10,  chance = 0.883},
		{low = 10,  high = 20,  chance = 0.923},
		{low = 20,  high = 40,  chance = 0.940},
		{low = 40,  high = 60,  chance = 0.945},
		{low = 60,  high = 70,  chance = 0.9475},
		{low = 70,  high = 80,  chance = 0.9495},
		{low = 80,  high = 90,  chance = 0.94995},
		{low = 90,  high = 100, chance = 0.95},
		{low = 1,   high = 5,   chance = 1.0}
	}

	for i, range in ipairs(ranges) do
		if r <= range.chance then
			local low = math.max(minW, range.low)
			local high = math.min(maxW, range.high)
			if low < high then
				local selectedWeight = rng:NextNumber(low, high)
				return selectedWeight
			end
		end
	end

	return rng:NextNumber(1, 5)
end

local function selectRandomFishFromRarity(rarityData)
	local fishes = rarityData.fishes
	if #fishes == 1 then
		return fishes[1]
	end

	local rng = Random.new(tick() * 1000000 + math.random(1, 1000000))
	local randomIndex = rng:NextInteger(1, #fishes)

	print("등급 내 선택:", randomIndex .. "/" .. #fishes, "→", fishes[randomIndex].fishName)
	return fishes[randomIndex]
end

-- FishData 모듈에 추가할 함수 (return FishData 위에 추가)

function FishData.CreateInventoryFishModel(fishInfo)
	if not fishInfo or not fishInfo.model then
		warn("물고기 정보 또는 모델이 없습니다")
		return nil
	end

	local fishModel = fishInfo.model:Clone()
	fishModel.Name = fishInfo.fishName
	fishModel.CanBeDropped = false

	-- effects 배열 처리 (파티클 효과)
	if fishInfo and fishInfo.effects then
		local particleFolder = game.ReplicatedStorage:WaitForChild("Particle")
		for _, effectName in ipairs(fishInfo.effects) do
			local attach = particleFolder:FindFirstChild(effectName)
			if attach and attach:IsA("Attachment") then
				local cloneAttach = attach:Clone()
				cloneAttach.Parent = fishModel.PrimaryPart or fishModel:FindFirstChild("Handle")
				print("인벤토리 물고기에 파티클 효과 적용:", effectName)
			end
		end
	end

	-- 얼음 효과 적용 (인벤토리용)
	local weatherInfo = WeatherSystem.GetCurrentWeatherInfo()
	if weatherInfo and weatherInfo.isActive and weatherInfo.currentWeather == "Snow" then
		if fishInfo.fishName and string.find(fishInfo.fishName, "Frozen") then
			-- FishIceEffect 모듈 로드
			local success, FishIceEffect = pcall(function()
				return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("FishIceEffectModule"))
			end)

			if success then
				FishIceEffect.ApplyIceEffect(fishModel, fishInfo)
				print("인벤토리 물고기에 얼음 효과 적용:", fishInfo.fishName)
			else
				-- 내장 얼음 효과 사용
				spawn(function()
					wait(0.1)
					applyIceEffect(fishModel, fishInfo)
				end)
			end
		end
	end

	-- 축제 효과 적용 (인벤토리용)
	if fishInfo.fishName and string.find(fishInfo.fishName, "Festival") then
		local weatherInfo = WeatherSystem.GetCurrentWeatherInfo()
		if weatherInfo and weatherInfo.isActive and weatherInfo.currentWeather == "Firework" then
			-- 축제 효과 적용
			local success = pcall(function()
				FishData.ApplyFestivalEffect(fishModel, fishInfo)
			end)

			if success then
				print("인벤토리 물고기에 축제 효과 적용:", fishInfo.fishName)
			end
		end
	end

	-- workspace에 추가하지 않음 (인벤토리용이므로)
	print("인벤토리 물고기 모델 생성 완료:", fishInfo.fishName)
	return fishModel
end

-- 수정된 GetRandomFish 함수 (EnchantModule 사용)
function FishData.GetRandomFish(fullRodName, player)
	-- 로드 이름과 인첸트 분리
	local rodName, enchantFromName = EnchantModule.ParseRodName(fullRodName)

	-- 플레이어의 인첸트 정보 가져오기 (로드별 인첸트 우선)
	local playerEnchant = EnchantModule.GetPlayerEnchant(player, rodName)
	local currentEnchant = playerEnchant ~= "None" and playerEnchant or enchantFromName

	print("사용 중인 낚싯대:", rodName)
	print("적용된 인첸트:", currentEnchant)

	local rng = Random.new()

	-- 현재 날씨 정보 출력
	local weatherInfo = WeatherSystem.GetCurrentWeatherInfo()
	if weatherInfo.isActive then
		print("현재 날씨:", weatherInfo.currentWeather, "남은시간:", math.floor(weatherInfo.remainingTime), "초")
	else
		print("현재 날씨: Clear (다음 날씨까지:", math.floor(weatherInfo.nextWeatherIn), "초)")
	end

	-- 기본 확률
	local baseChances = {
		["Common"] = 51.15,
		["Uncommon"] = 25.0,
		["Rare"] = 13.0,
		["Epic"] = 6.0,
		["Legendary"] = 3.0,
		["Mystic"] = 1.5,
		["Fantasy"] = 0.3,
		["Unknown"] = 0.05
	}

	-- 게임패스 및 버프 확인
	local hasLuckPass = false
	local hasLuckBubbleBuff = false

	if player then
		local success, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, LuckGamePassId)
		end)

		if success then
			hasLuckPass = result
		end

		hasLuckBubbleBuff = player:GetAttribute("LuckBubbleBuff") == true
	end

	-- 게임패스 효과 적용
	if hasLuckPass then
		baseChances = {
			["Common"] = 37.4,
			["Uncommon"] = 21.07,
			["Rare"] = 14.33,
			["Epic"] = 14.0,
			["Legendary"] = 8.0,
			["Mystic"] = 4.0,
			["Fantasy"] = 1.0,
			["Unknown"] = 0.2
		}
		print("게임패스 보유 - 희귀템 확률 2배 적용")
	end

	-- 운 버블 버프 적용
	if hasLuckBubbleBuff then
		baseChances = {
			["Common"] = baseChances["Common"] * 0.8,
			["Uncommon"] = baseChances["Uncommon"] * 0.9,
			["Rare"] = baseChances["Rare"] * 1.1,
			["Epic"] = baseChances["Epic"] * 1.3,
			["Legendary"] = baseChances["Legendary"] * 1.5,
			["Mystic"] = baseChances["Mystic"] * 1.8,
			["Fantasy"] = baseChances["Fantasy"] * 2.0,
			["Unknown"] = baseChances["Unknown"] * 2.5
		}
		print("운 버블 버프 추가 적용")
	end

	-- 인첸트 Luck 효과 적용 (EnchantModule 사용)
	if currentEnchant ~= "None" then
		local enchantData = EnchantModule.GetEnchantData(currentEnchant)
		if enchantData and enchantData.stats.Luck then
			local luckBonus = enchantData.stats.Luck / 100
			baseChances["Epic"] = baseChances["Epic"] * (1 + luckBonus * 0.5)
			baseChances["Legendary"] = baseChances["Legendary"] * (1 + luckBonus * 0.7)
			baseChances["Mystic"] = baseChances["Mystic"] * (1 + luckBonus)
			baseChances["Fantasy"] = baseChances["Fantasy"] * (1 + luckBonus * 1.5)
			baseChances["Unknown"] = baseChances["Unknown"] * (1 + luckBonus * 2)
			print("인첸트 Luck 효과 적용:", currentEnchant, "운 보너스:", enchantData.stats.Luck .. "%")
		end
	end

	-- 낚싯대 보너스 적용 (기존 로직 유지)
	local function applyRodBonus(chances, bonuses)
		if not bonuses then return chances end

		local totalBonus = 0
		for rarity, bonus in pairs(bonuses) do
			totalBonus = totalBonus + bonus
		end

		if totalBonus <= 0 then return chances end

		local toReduce = totalBonus
		local reductionOrder = {"Common", "Uncommon", "Rare", "Epic"}

		for _, rarity in ipairs(reductionOrder) do
			if toReduce <= 0 then break end

			local available = chances[rarity] or 0
			local reduction = math.min(available * 0.8, toReduce)

			chances[rarity] = available - reduction
			toReduce = toReduce - reduction
		end

		for rarity, bonus in pairs(bonuses) do
			local oldValue = chances[rarity] or 0
			chances[rarity] = oldValue + bonus
		end

		return chances
	end

	-- 낚싯대별 보너스 (기존과 동일)
	local rodBonuses = nil
	if rodName == "GoldRod" then
		rodBonuses = {["Rare"] = 4.0}
	elseif rodName == "CrystalRod" then
		rodBonuses = {["Epic"] = 3.0}
	elseif rodName == "MagneticRod" then
		rodBonuses = {["Mystic"] = 0.3, ["Legendary"] = 1.0, ["Epic"] = 2.0}
	elseif rodName == "BoneRod" then
		rodBonuses = {["Mystic"] = 0.7, ["Legendary"] = 3.0}
	elseif rodName == "CloverRod" then
		rodBonuses = {["Fantasy"] = 0.2, ["Mystic"] = 1.0, ["Legendary"] = 2.0}
	elseif rodName == "RainbowRod" then
		rodBonuses = {["Fantasy"] = 0.4, ["Mystic"] = 2.5, ["Legendary"] = 3.0}
	elseif rodName == "UnknownRod" then
		rodBonuses = {["Unknown"] = 0.1, ["Fantasy"] = 0.5, ["Mystic"] = 2.0}
	elseif rodName == "RobuxRod" then
		rodBonuses = {["Unknown"] = 0.2, ["Fantasy"] = 0.7, ["Mystic"] = 3.0}
	elseif rodName == "ElectricRod" then
		rodBonuses = {["Unknown"] = 0.25, ["Fantasy"] = 0.8, ["Mystic"] = 4.0}
	elseif rodName == "RealisticRod" then
		rodBonuses = {["Unknown"] = 0.5, ["Fantasy"] = 1.3, ["Mystic"] = 5.0}
	elseif rodName == "ArcaneRod" then
		rodBonuses = {["Unknown"] = 0.8, ["Fantasy"] = 1.6, ["Mystic"] = 5.5}
	elseif rodName == "VoidRod" then
		rodBonuses = {["Unknown"] = 1.5, ["Fantasy"] = 4.0, ["Mystic"] = 6.0, ["Legendary"] = 7.0}
	elseif rodName == "FriendRod" then
		rodBonuses = {
			["Rare"] = 4.0,
			["Epic"] = 4.0,
			["Legendary"] = 5.0,
			["Mystic"] = 2,
			["Fantasy"] = 1.2,
			["Unknown"] = 0.4
		}
	elseif rodName == "DevRod" then
		rodBonuses = {["Unknown"] = 100}
	end

	-- 보너스 적용
	local finalChances = {}
	for rarity, chance in pairs(baseChances) do
		finalChances[rarity] = chance
	end

	if rodBonuses then
		finalChances = applyRodBonus(finalChances, rodBonuses)
	end

	-- 확률 정규화
	local total = 0
	for _, chance in pairs(finalChances) do
		total = total + chance
	end

	if total ~= 100 then
		local factor = 100 / total
		for rarity, chance in pairs(finalChances) do
			finalChances[rarity] = chance * factor
		end
	end

	-- 물고기 선택
	local combinedList = {}
	local finalTotal = 0

	for _, rarity in ipairs(FishData.Rarities) do
		local name = rarity.name
		local finalChance = finalChances[name] or 0
		table.insert(combinedList, {rarity = rarity, chance = finalChance})
		finalTotal = finalTotal + finalChance
	end

	local target = rng:NextNumber(0, finalTotal)
	local cumulative = 0

	for i, entry in ipairs(combinedList) do
		cumulative = cumulative + entry.chance

		if target <= cumulative then
			local selectedFish = selectRandomFishFromRarity(entry.rarity)

			local minW = selectedFish.minWeight or 1
			local maxW = selectedFish.maxWeight or minW
			local weight = getFixedProbabilityWeight(minW, maxW)
			weight = math.floor(weight * 10 + 0.5) / 10

			local fishInfo = {
				name = entry.rarity.name,
				fishName = selectedFish.fishName,
				value = selectedFish.value,
				model = selectedFish.model,
				minWeight = selectedFish.minWeight,
				maxWeight = selectedFish.maxWeight,
				weight = weight,
				chance = entry.chance
			}

			-- 날씨 효과 적용
			fishInfo = WeatherSystem.ApplyWeatherEffects(fishInfo)

			-- 인첸트 효과 적용 (EnchantModule 사용)
			fishInfo = EnchantModule.ApplyEnchantToFish(fishInfo, currentEnchant)

			print("최종 결과:", fishInfo.fishName, "(" .. fishInfo.name .. ")", fishInfo.weight .. "kg", "가격:", fishInfo.value)
			return fishInfo
		end
	end

	-- 기본값 반환
	local commonRarity = FishData.Rarities[1]
	local defaultFish = commonRarity.fishes[1]
	local fishInfo = {
		name = commonRarity.name,
		fishName = defaultFish.fishName,
		value = defaultFish.value,
		model = defaultFish.model,
		minWeight = defaultFish.minWeight,
		maxWeight = defaultFish.maxWeight,
		weight = 1.0,
		chance = commonRarity.chance
	}

	fishInfo = WeatherSystem.ApplyWeatherEffects(fishInfo)
	return EnchantModule.ApplyEnchantToFish(fishInfo, currentEnchant)
end

-- 기존 함수들 유지 (removeIceEffect, applyFestivalEffect 등)
local function removeIceEffect(fishModel)
	if not fishModel then
		return false
	end

	local iceBlock = fishModel:FindFirstChild("IceBlock")
	if not iceBlock then
		return false
	end

	iceBlock:Destroy()
	fishModel:SetAttribute("HasIceEffect", nil)
	fishModel:SetAttribute("IceAppliedTime", nil)
	return true
end

-- 나머지 함수들도 기존과 동일하게 유지
function FishData.ApplyIceEffect(fishModel, fishInfo)
	return applyIceEffect(fishModel, fishInfo)
end

function FishData.RemoveIceEffect(fishModel)
	return removeIceEffect(fishModel)
end

function FishData.RemoveAllIceEffects()
	local workspace = game:GetService("Workspace")
	local removedCount = 0

	local function searchForIceEffects(parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:GetAttribute("HasIceEffect") then
				removeIceEffect(child)
				removedCount = removedCount + 1
			end

			if #child:GetChildren() > 0 then
				searchForIceEffects(child)
			end
		end
	end

	searchForIceEffects(workspace)
	print("모든 얼음 효과 제거 완료. 제거된 개수:", removedCount)
	return removedCount
end

function FishData.HasIceEffect(fishModel)
	if not fishModel then return false end
	return fishModel:GetAttribute("HasIceEffect") == true
end

function FishData.UpdateIceSettings(newSettings)
	if newSettings.material then ICE_SETTINGS.material = newSettings.material end
	if newSettings.transparency then ICE_SETTINGS.transparency = newSettings.transparency end
	if newSettings.color then ICE_SETTINGS.color = newSettings.color end
	if newSettings.size_multiplier then ICE_SETTINGS.size_multiplier = newSettings.size_multiplier end
	if newSettings.glow_intensity then ICE_SETTINGS.glow_intensity = newSettings.glow_intensity end
	print("얼음 효과 설정 업데이트 완료")
end

function FishData.GetFishByRarity(rarityName)
	for _, rarity in ipairs(FishData.Rarities) do
		if rarity.name == rarityName then
			local firstFish = rarity.fishes[1]
			return {
				name = rarity.name,
				fishName = firstFish.fishName,
				value = firstFish.value,
				model = firstFish.model,
				minWeight = firstFish.minWeight,
				maxWeight = firstFish.maxWeight,
				chance = rarity.chance
			}
		end
	end
	return nil
end

function FishData.GetAllFishInRarity(rarityName)
	for _, rarity in ipairs(FishData.Rarities) do
		if rarity.name == rarityName then
			return rarity.fishes
		end
	end
	return {}
end

function FishData.GetFishByName(fishName)
	for _, rarity in ipairs(FishData.Rarities) do
		for _, fish in ipairs(rarity.fishes) do
			if fish.fishName == fishName then
				return {
					name = rarity.name,
					fishName = fish.fishName,
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

function FishData.GetWeatherInfo()
	return WeatherSystem.GetCurrentWeatherInfo()
end

function FishData.SetWeather(weatherName, duration)
	return WeatherSystem.SetWeather(weatherName, duration)
end

-- 날씨 변경 이벤트 처리
if WeatherSystem.WeatherChanged then
	WeatherSystem.WeatherChanged.Event:Connect(function(newWeather)
		print("날씨 변경 감지:", newWeather)

		if newWeather ~= "Snow" then
			FishData.RemoveAllIceEffects()
			print("날씨 변경으로 얼음 효과 제거")
		end
	end)
end

function FishData.TestIceEffect(fishModel)
	if not fishModel then
		warn("테스트할 물고기 모델이 없습니다")
		return false
	end

	local testFishInfo = {
		fishName = "Frozen Test Fish",
		currentWeather = "Snow"
	}

	return applyIceEffect(fishModel, testFishInfo)
end

function FishData.ForceIceEffectOnAll()
	local workspace = game:GetService("Workspace")
	local appliedCount = 0

	local function searchAndApplyIce(parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:IsA("Model") and child.Name and not FishData.HasIceEffect(child) then
				local fakeInfo = {fishName = "Frozen " .. child.Name}
				if applyIceEffect(child, fakeInfo) then
					appliedCount = appliedCount + 1
				end
			end

			if #child:GetChildren() > 0 then
				searchAndApplyIce(child)
			end
		end
	end

	searchAndApplyIce(workspace)
	print("강제 얼음 효과 적용 완료. 적용된 개수:", appliedCount)
	return appliedCount
end

function FishData.GetIceEffectStats()
	local workspace = game:GetService("Workspace")
	local stats = {
		totalFishWithIce = 0,
		totalFishModels = 0,
		iceEffectPercentage = 0
	}

	local function countModels(parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:IsA("Model") and child.Name then
				stats.totalFishModels = stats.totalFishModels + 1
				if FishData.HasIceEffect(child) then
					stats.totalFishWithIce = stats.totalFishWithIce + 1
				end
			end

			if #child:GetChildren() > 0 then
				countModels(child)
			end
		end
	end

	countModels(workspace)

	if stats.totalFishModels > 0 then
		stats.iceEffectPercentage = (stats.totalFishWithIce / stats.totalFishModels) * 100
	end

	return stats
end

function FishData.PrintStatus()
	local weatherInfo = WeatherSystem.GetCurrentWeatherInfo()
	local iceStats = FishData.GetIceEffectStats()

	print("=== FishData 시스템 상태 ===")
	print("현재 날씨:", weatherInfo.currentWeather)
	print("날씨 활성:", weatherInfo.isActive)
	if weatherInfo.isActive then
		print("남은 시간:", math.floor(weatherInfo.remainingTime), "초")
	else
		print("다음 날씨까지:", math.floor(weatherInfo.nextWeatherIn), "초")
	end
	print("얼음 효과 적용된 물고기:", iceStats.totalFishWithIce)
	print("전체 물고기 모델:", iceStats.totalFishModels)
	print("얼음 효과 비율:", string.format("%.1f%%", iceStats.iceEffectPercentage))
	print("==============================")
end

-- 시스템 자동 초기화
spawn(function()
	WeatherSystem.Initialize()
	wait(5)

	local weatherInfo = WeatherSystem.GetCurrentWeatherInfo()
	if weatherInfo and weatherInfo.isActive and weatherInfo.currentWeather == "Snow" then
		print("서버 재시작 시 눈 날씨 감지 - 기존 물고기에 얼음 효과 적용")

		local function searchAndApplyIce(parent)
			for _, child in pairs(parent:GetChildren()) do
				if child:IsA("Model") and child.Name:find("Frozen") then
					if not FishData.HasIceEffect(child) then
						local fakeInfo = {fishName = child.Name}
						applyIceEffect(child, fakeInfo)
						print("기존 물고기에 얼음 효과 적용:", child.Name)
					end
				end

				if #child:GetChildren() > 0 then
					searchAndApplyIce(child)
				end
			end
		end

		searchAndApplyIce(workspace)
	end
end)

return FishData
