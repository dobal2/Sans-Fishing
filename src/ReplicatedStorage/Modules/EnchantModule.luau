-- EnchantModule (ModuleScript in ReplicatedStorage.Modules)
-- 중앙화된 인첸트 시스템

local EnchantModule = {}

-- 인첸트 데이터베이스 (확률 및 효과 포함)
EnchantModule.ENCHANT_DATABASE = {
	-- Common (56.49%)
	["Little Strong"] = {
		rarity = "Common",
		chance = 56.49,
		stats = {Strong = 15}
	},
	["Little Bigger"] = {
		rarity = "Common",
		chance = 56.49,
		stats = {Size = 10}
	},
	["Little Luck"] = {
		rarity = "Common",
		chance = 56.49,
		stats = {Luck = 20}
	},

	-- Rare (35%)
	["More Strong"] = {
		rarity = "Rare",
		chance = 35,
		stats = {Strong = 30}
	},
	["More Bigger"] = {
		rarity = "Rare",
		chance = 35,
		stats = {Size = 25}
	},
	["More Luck"] = {
		rarity = "Rare",
		chance = 35,
		stats = {Luck = 35}
	},
	["Windy"] = {
		rarity = "Rare",
		chance = 35,
		stats = {Strong = 20, WindyMutation = 8}
	},
	["Wet"] = {
		rarity = "Rare",
		chance = 35,
		stats = {Size = 15, Luck = 25, WetMutation = 8}
	},

	-- Epic (7%)
	["赤(Red)"] = {
		rarity = "Epic",
		chance = 7,
		stats = {Strong = 40, Size = 5, Luck = 40, RedMutation = 8}
	},
	["青(Blue)"] = {
		rarity = "Epic",
		chance = 7,
		stats = {Strong = 15, Size = 30, Luck = 40, BlueMutation = 8}
	},
	["Long"] = {
		rarity = "Epic",
		chance = 7,
		stats = {Strong = 35, Size = 30, Luck = 40, LongMutation = 8}
	},
	["Massive"] = {
		rarity = "Epic",
		chance = 7,
		stats = {Strong = -50, Size = 50, Luck = 40, MassiveMutation = 7}
	},

	-- Legendary (1%)
	["Trinity"] = {
		rarity = "Legendary",
		chance = 1,
		stats = {Strong = 50, Size = 30, Luck = 50, TrinityMutation = 8}
	},
	["Rainbow"] = {
		rarity = "Legendary",
		chance = 1,
		stats = {Strong = 30, Size = 45, Luck = 50, RainbowMutation =8}
	},

	-- Mystic (0.5%)
	["Mutation"] = {
		rarity = "Mystic",
		chance = 0.5,
		stats = {
			Strong = 50,
			Size = 50,
			Luck = 50,
			LongMutation = 4,
			MassiveMutation = 4,
			WetMutation = 4,
			WindyMutation = 4
		}
	},
	["Luck"] = {
		rarity = "Mystic",
		chance = 0.5,
		stats = {
			Strong = 40,
			Size = 40,
			Luck = 70,
			CloverMutation = 8,
			LuckMutation = 4
		}
	},

	-- ??? (0.01%)
	["Void"] = {
		rarity = "???",
		chance = 0.01,
		stats = {
			Strong = 100,
			Size = 60,
			Luck = 90,
			VoidMutation = 5,
			ErrorMutation = 1
		}
	},
	["紫(Purple)"] = {
		rarity = "???",
		chance = 0.01,
		stats = {
			Strong = 80,
			Size = 70,
			Luck = 90,
			PurpleMutation = 4,
			RedMutation = 9,
			BlueMutation = 9
		}
	}
}

-- 희귀도별 가중치 테이블
EnchantModule.RARITY_WEIGHTS = {
	Common = 56.4,
	Rare = 35,
	Epic = 7,
	Legendary = 1,
	Mystic = 0.5,
	["???"] = 0.1
}

-- 인첸트 리스트 (배열 형태)
EnchantModule.ENCHANT_LIST = {
	-- Common
	"Little Strong",
	"Little Bigger",
	"Little Luck",
	-- Rare
	"More Strong",
	"More Bigger",
	"More Luck",
	"Windy",
	"Wet",
	-- Epic
	"赤(Red)",
	"青(Blue)",
	"Long",
	"Massive",
	-- Legendary
	"Trinity",
	"Rainbow",
	-- Mystic
	"Mutation",
	"Luck",
	-- ???
	"Void",
	"紫(Purple)"
}

-- 희귀도 선택 함수
function EnchantModule.SelectRarity()
	local totalWeight = 0
	for _, weight in pairs(EnchantModule.RARITY_WEIGHTS) do
		totalWeight = totalWeight + weight
	end

	local random = math.random() * totalWeight
	local currentWeight = 0

	for rarity, weight in pairs(EnchantModule.RARITY_WEIGHTS) do
		currentWeight = currentWeight + weight
		if random <= currentWeight then
			return rarity
		end
	end

	return "Common" -- 기본값
end

-- 선택된 희귀도에서 인첸트 랜덤 선택
function EnchantModule.SelectEnchantFromRarity(rarity)
	local availableEnchants = {}

	for enchantName, enchantData in pairs(EnchantModule.ENCHANT_DATABASE) do
		if enchantData.rarity == rarity then
			table.insert(availableEnchants, enchantName)
		end
	end

	if #availableEnchants > 0 then
		return availableEnchants[math.random(1, #availableEnchants)]
	else
		return "Little Strong" -- 기본값
	end
end

-- 랜덤 인첸트 선택 (확률 기반)
function EnchantModule.GetRandomEnchant()
	local selectedRarity = EnchantModule.SelectRarity()
	local selectedEnchant = EnchantModule.SelectEnchantFromRarity(selectedRarity)
	return selectedEnchant, selectedRarity
end

-- 인첸트 정보 가져오기
function EnchantModule.GetEnchantData(enchantName)
	return EnchantModule.ENCHANT_DATABASE[enchantName]
end

function EnchantModule.ApplyEnchantParticle(rodModel, enchantName)
	if not rodModel or not enchantName or enchantName == "None" then
		return
	end

	local handle = rodModel:FindFirstChild("Handle")
	if not handle then
		warn("Handle이 없습니다:", rodModel.Name)
		return
	end

	-- ReplicatedStorage에서 파티클 가져오기
	local particleTemplateFolder = game:GetService("ReplicatedStorage"):WaitForChild("RodEnchantEffects")
	local particleTemplates = particleTemplateFolder:GetChildren()
	if #particleTemplates == 0 then
		warn("EnchantParticles 폴더에 파티클 없음")
		return
	end

	-- 최대 2개 적용
	for i = 1, math.min(2, #particleTemplates) do
		local particleClone = particleTemplates[i]:Clone()
		particleClone.Color = ColorSequence.new(EnchantModule.GetRarityColor(enchantName))
		particleClone.Parent = handle
		particleClone.Enabled = true
	end
end



-- 사용 예시
-- local rodModel = workspace:WaitForChild("PlayerRod")
-- EnchantModule.ApplyEnchantParticle(rodModel, "Void")




-- EnchantModule의 ApplyEnchantToFish 함수 수정

function EnchantModule.ApplyEnchantToFish(fishInfo, enchantName)
	if not enchantName or enchantName == "None" then
		return fishInfo
	end

	local enchantData = EnchantModule.ENCHANT_DATABASE[enchantName]
	if not enchantData then
		return fishInfo
	end

	local stats = enchantData.stats

	-- Strong 효과: 물고기 가격 증가/감소 (기존 방식 유지)
	if stats.Strong then
		local multiplier = 1 + (stats.Strong / 100)
		fishInfo.value = math.floor(fishInfo.value * multiplier)
		print("Strong 인첸트 적용:", enchantName, "가격 변화:", multiplier .. "x")
	end

	-- Size 효과: 물고기 크기/무게 증가 (기존 방식 유지)
	if stats.Size then
		local multiplier = 1 + (stats.Size / 100)
		fishInfo.weight = fishInfo.weight * multiplier
		print("Size 인첸트 적용:", enchantName, "크기 증가:", multiplier .. "x")
	end

	-- Luck 효과는 확률 계산에서 이미 처리됨
	if stats.Luck then
		print("Luck 인첸트 적용:", enchantName, "운 증가:", stats.Luck .. "%")
	end

	-- 변이 효과들 - 아이템 세이브와 동일한 방식 (합산 후 곱셈)
	local mutations = {}
	local mutationTotalBonus = 0  -- 변이 보너스 합계

	if stats.WindyMutation and stats.WindyMutation > 0 then
		if math.random(1, 100) <= stats.WindyMutation then
			table.insert(mutations, "Windy")
			mutationTotalBonus = mutationTotalBonus + 0.6  -- 20% 추가
		end
	end

	if stats.WetMutation and stats.WetMutation > 0 then
		if math.random(1, 100) <= stats.WetMutation then
			table.insert(mutations, "Wet")
			mutationTotalBonus = mutationTotalBonus + 0.6  -- 15% 추가
		end
	end

	if stats.RedMutation and stats.RedMutation > 0 then
		if math.random(1, 100) <= stats.RedMutation then
			table.insert(mutations, "赤")
			mutationTotalBonus = mutationTotalBonus + 1.0  -- 100% 추가
		end
	end

	if stats.BlueMutation and stats.BlueMutation > 0 then
		if math.random(1, 100) <= stats.BlueMutation then
			table.insert(mutations, "青")
			mutationTotalBonus = mutationTotalBonus + 1.0  -- 80% 추가
		end
	end

	if stats.LongMutation and stats.LongMutation > 0 then
		if math.random(1, 100) <= stats.LongMutation then
			table.insert(mutations, "Long")
			mutationTotalBonus = mutationTotalBonus + 1.5  -- 150% 추가
		end
	end

	if stats.MassiveMutation and stats.MassiveMutation > 0 then
		if math.random(1, 100) <= stats.MassiveMutation then
			table.insert(mutations, "Massive")
			fishInfo.weight = fishInfo.weight * 2.0
			mutationTotalBonus = mutationTotalBonus + 2.0  -- 200% 추가
		end
	end

	if stats.TrinityMutation and stats.TrinityMutation > 0 then
		if math.random(1, 100) <= stats.TrinityMutation then
			table.insert(mutations, "Trinity")
			mutationTotalBonus = mutationTotalBonus + 3.0  -- 400% 추가
		end
	end

	if stats.RainbowMutation and stats.RainbowMutation > 0 then
		if math.random(1, 100) <= stats.RainbowMutation then
			table.insert(mutations, "Rainbow")
			mutationTotalBonus = mutationTotalBonus + 4.0  -- 650% 추가
		end
	end

	if stats.CloverMutation and stats.CloverMutation > 0 then
		if math.random(1, 100) <= stats.CloverMutation then
			table.insert(mutations, "Clover")
			mutationTotalBonus = mutationTotalBonus + 4.0  -- 1100% 추가
		end
	end

	if stats.LuckMutation and stats.LuckMutation > 0 then
		if math.random(1, 100) <= stats.LuckMutation then
			table.insert(mutations, "Lucky")
			mutationTotalBonus = mutationTotalBonus + 5.0  -- 900% 추가
		end
	end

	if stats.VoidMutation and stats.VoidMutation > 0 then
		if math.random(1, 100) <= stats.VoidMutation then
			table.insert(mutations, "Void")
			mutationTotalBonus = mutationTotalBonus + 7.0  -- 1500% 추가
		end
	end

	if stats.ErrorMutation and stats.ErrorMutation > 0 then
		if math.random(1, 10000) <= stats.ErrorMutation * 100 then
			table.insert(mutations, "ERROR")
			mutationTotalBonus = mutationTotalBonus + 20.0  -- 5000% 추가
		end
	end

	if stats.PurpleMutation and stats.PurpleMutation > 0 then
		if math.random(1, 100) <= stats.PurpleMutation then
			table.insert(mutations, "紫")
			mutationTotalBonus = mutationTotalBonus + 12.0  -- 1900% 추가
		end
	end

	-- 변이 보너스 최종 적용 (아이템 세이브와 동일한 방식)
	if mutationTotalBonus > 0 then
		fishInfo.value = math.floor(fishInfo.value * (1 + mutationTotalBonus))
		print("변이 보너스 적용:", mutationTotalBonus, "최종 가격:", fishInfo.value)
	end

	-- 변이 효과를 물고기 이름에 추가
	if #mutations > 0 then
		local mutationPrefix = table.concat(mutations, " ")
		fishInfo.fishName = mutationPrefix .. " " .. fishInfo.fishName
		print("변이 적용:", mutationPrefix, "→", fishInfo.fishName)
	end

	return fishInfo
end

-- FishingServerModule의 createFishTool 함수 내 getMutationBonus 함수 (아이템 세이브와 동일)
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



-- 인첸트 효과 적용 (로드 파워용)
function EnchantModule.ApplyEnchantToRodPower(basePower, enchantName)
	if not enchantName or enchantName == "None" then
		return basePower
	end

	local enchantData = EnchantModule.ENCHANT_DATABASE[enchantName]
	if not enchantData or not enchantData.stats.Strong then
		return basePower
	end

	local multiplier = 1 + (enchantData.stats.Strong / 100)
	return basePower * multiplier
end

-- 인첸트 효과 적용 (난이도용)
function EnchantModule.ApplyEnchantToDifficulty(baseDifficulty, enchantName)
	if not enchantName or enchantName == "None" then
		return baseDifficulty
	end

	local enchantData = EnchantModule.ENCHANT_DATABASE[enchantName]
	if not enchantData then
		return baseDifficulty
	end

	local stats = enchantData.stats
	local finalDifficulty = baseDifficulty

	-- Size 효과: 난이도 감소
	if stats.Size then
		local reduction = stats.Size / 200 -- Size의 절반만큼 난이도 감소
		finalDifficulty = math.max(0.1, finalDifficulty - reduction)
	end

	-- Luck 효과: 약간의 난이도 감소
	if stats.Luck then
		local reduction = stats.Luck / 400 -- Luck의 1/4만큼 난이도 감소
		finalDifficulty = math.max(0.1, finalDifficulty - reduction)
	end

	return finalDifficulty
end

-- 로드 이름에서 인첸트 분리
function EnchantModule.ParseRodName(fullRodName)
	if not fullRodName then
		return "FishingRod", "None"
	end

	-- [인첸트명] 로드명 형식 확인
	local enchantName, rodName = fullRodName:match("^%[(.+)%] (.+)")
	if enchantName and rodName then
		return rodName, enchantName
	else
		-- 인첸트가 없는 경우
		return fullRodName, "None"
	end
end

-- 플레이어의 인첸트 정보 가져오기
function EnchantModule.GetPlayerEnchant(player, rodName)
	if not player then return "None" end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return "None" end

	local rodEnchants = leaderstats:FindFirstChild("RodEnchants")
	if not rodEnchants then return "None" end

	local rodEnchantValue = rodEnchants:FindFirstChild(rodName)
	if not rodEnchantValue then return "None" end

	return rodEnchantValue.Value or "None"
end

-- 희귀도별 색상 코드 (GUI용)
EnchantModule.RARITY_COLORS = {
	Common = Color3.fromRGB(155, 155, 155),     -- 회색
	Rare = Color3.fromRGB(0, 162, 255),         -- 파란색
	Epic = Color3.fromRGB(163, 53, 238),        -- 보라색
	Legendary = Color3.fromRGB(255, 128, 0),    -- 주황색
	Mystic = Color3.fromRGB(255, 20, 147),      -- 핑크색
	["???"] = Color3.fromRGB(255, 2, 6)         -- 빨간색
}

-- 희귀도 색상 가져오기
function EnchantModule.GetRarityColor(enchantName)
	local enchantData = EnchantModule.ENCHANT_DATABASE[enchantName]
	if enchantData then
		return EnchantModule.RARITY_COLORS[enchantData.rarity] or Color3.fromRGB(255, 255, 255)
	end
	return Color3.fromRGB(255, 255, 255)
end

-- 디버그용 함수들
function EnchantModule.PrintEnchantStats(enchantName)
	local data = EnchantModule.ENCHANT_DATABASE[enchantName]
	if data then
		print("=== " .. enchantName .. " ===")
		print("희귀도:", data.rarity)
		print("확률:", data.chance .. "%")
		print("효과:")
		for stat, value in pairs(data.stats) do
			print("  " .. stat .. ": " .. value .. "%")
		end
		print("========================")
	else
		print("알 수 없는 인첸트:", enchantName)
	end
end

function EnchantModule.PrintAllEnchants()
	print("=== 모든 인첸트 목록 ===")
	for rarity, weight in pairs(EnchantModule.RARITY_WEIGHTS) do
		print(rarity .. " (" .. weight .. "%):")
		for enchantName, data in pairs(EnchantModule.ENCHANT_DATABASE) do
			if data.rarity == rarity then
				print("  - " .. enchantName)
			end
		end
	end
	print("========================")
end

return EnchantModule