-- FishingConfigModule (ModuleScript in ReplicatedStorage.Modules)
-- Fixed Enchant System Support - 기본 설정과 인첸트 적용 분리

local FishingConfig = {}

-- EnchantModule 로드
local EnchantModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("EnchantModule"))

-- 기본 로드 설정 (인첸트 없는 순수 기본값)
local BaseRodConfigs = {
	FishingRod = {
		Distance = 60,
		Rarity = "Common",
		RodPower = 1.2,        -- 기본 힘 (1.0 → 1.2로 상향)
		DifficultyMod = 1.0    -- 기본 난이도
	},
	SliverRod = {
		Distance = 80,
		Rarity = "Uncommon",
		RodPower = 1.38,       -- 힘 +15% (1.2 × 1.15)
		DifficultyMod = 0.85   -- 15% 쉬워짐
	},
	GoldRod = {
		Distance = 85,
		Rarity = "Rare",
		RodPower = 1.41,       -- 힘 +17.5% (1.2 × 1.175)
		DifficultyMod = 0.825  -- 17.5% 쉬워짐
	},
	CrystalRod = {
		Distance = 90,
		Rarity = "Epic",
		RodPower = 1.44,       -- 힘 +20% (1.2 × 1.2)
		DifficultyMod = 0.8    -- 20% 쉬워짐
	},
	MagneticRod = {
		Distance = 95,
		Rarity = "Epic",
		RodPower = 1.5,        -- 힘 +25% (1.2 × 1.25)
		DifficultyMod = 0.75   -- 25% 쉬워짐
	},
	BoneRod = {
		Distance = 100,
		Rarity = "Fantasy",
		RodPower = 1.56,       -- 힘 +30% (1.2 × 1.3)
		DifficultyMod = 0.7    -- 30% 쉬워짐
	},
	CloverRod = {
		Distance = 105,
		Rarity = "Mystic",
		RodPower = 1.65,       -- 힘 +37.5% (1.2 × 1.375)
		DifficultyMod = 0.625  -- 37.5% 쉬워짐
	},
	RainbowRod = {
		Distance = 110,
		Rarity = "Legendary",
		RodPower = 1.74,       -- 힘 +45% (1.2 × 1.45)
		DifficultyMod = 0.55   -- 45% 쉬워짐
	},
	UnknownRod = {
		Distance = 115,
		Rarity = "Unknown",
		RodPower = 1.86,       -- 힘 +55% (1.2 × 1.55)
		DifficultyMod = 0.45   -- 55% 쉬워짐
	},
	RobuxRod = {
		Distance = 115,
		Rarity = "Unknown",
		RodPower = 1.92,       -- 힘 +60% (1.2 × 1.6)
		DifficultyMod = 0.45   -- 55% 쉬워짐
	},
	ElectricRod = {
		Distance = 120,
		Rarity = "Unknown",
		RodPower = 1.98,       -- 힘 +65% (1.2 × 1.65)
		DifficultyMod = 0.35   -- 65% 쉬워짐
	},
	RealisticRod = {
		Distance = 120,
		Rarity = "Unknown",
		RodPower = 2.16,       -- 힘 +80% (1.2 × 1.8)
		DifficultyMod = 0.2    -- 80% 쉬워짐
	},
	ArcaneRod = {
		Distance = 125,
		Rarity = "Unobtainable",
		RodPower = 2.22,       -- 힘 +85% (1.2 × 1.85)
		DifficultyMod = 0.15   -- 85% 쉬워짐
	},
	VoidRod = {
		Distance = 125,
		Rarity = "Unobtainable",
		RodPower = 3.0,        -- 힘 +150% (1.2 × 2.5)
		DifficultyMod = 0.1    -- 90% 쉬워짐
	},
	FriendRod = {
		Distance = 120,
		Rarity = "Special",
		RodPower = 2.64,       -- 힘 +120% (1.2 × 2.2)
		DifficultyMod = 0.1    -- 90% 쉬워짐
	},
	DevRod = {
		Distance = 150,
		Rarity = "Unobtainable",
		RodPower = 2364,       -- 개발자용 (1.2 × 1972)
		DifficultyMod = 0.01   -- 99% 쉬워짐
	}
}

-- ✅ 기본 로드 설정만 반환 (인첸트 적용하지 않음)
function FishingConfig.GetBaseRodConfig(rodName)
	local config = BaseRodConfigs[rodName]
	if not config then
		warn("알 수 없는 로드:", rodName)
		config = BaseRodConfigs.FishingRod -- 기본값
	end

	-- 깊은 복사로 반환 (원본 보호)
	return {
		Distance = config.Distance,
		Rarity = config.Rarity,
		RodPower = config.RodPower,
		DifficultyMod = config.DifficultyMod
	}
end

-- ✅ 인챈트 효과가 적용된 로드 설정 가져오기 (명시적으로 인첸트 적용)
function FishingConfig.GetRodConfigWithEnchant(fullRodName, enchantName)
	-- 기본 로드명 추출 (EnchantModule 사용)
	local baseRodName, _ = EnchantModule.ParseRodName(fullRodName)

	-- 기본 설정 가져오기 (인첸트 없는 순수 기본값)
	local config = FishingConfig.GetBaseRodConfig(baseRodName)

	-- 인챈트가 없으면 기본 설정 그대로 반환
	if not enchantName or enchantName == "None" then
		return config
	end

	-- 인챈트 효과 적용 (EnchantModule 사용)
	local enchantData = EnchantModule.GetEnchantData(enchantName)
	if not enchantData then
		warn("알 수 없는 인챈트:", enchantName)
		return config
	end

	-- Strong 효과: 낚싯대 힘 증가
	if enchantData.stats.Strong then
		local multiplier = 1 + (enchantData.stats.Strong / 100)
		config.RodPower = config.RodPower * multiplier
		print("Strong 인챈트 적용:", enchantName, "힘 증가:", multiplier .. "x", "최종 힘:", config.RodPower)
	end

	-- Size 효과: 난이도 감소 (크기가 클수록 잡기 쉬워짐)
	if enchantData.stats.Size then
		local reduction = enchantData.stats.Size / 200 -- Size의 절반만큼 난이도 감소
		config.DifficultyMod = math.max(0.1, config.DifficultyMod - reduction)
		print("Size 인챈트 적용:", enchantName, "난이도 감소:", reduction, "최종 난이도:", config.DifficultyMod)
	end

	-- Luck 효과: 약간의 난이도 감소
	if enchantData.stats.Luck then
		local reduction = enchantData.stats.Luck / 400 -- Luck의 1/4만큼 난이도 감소
		config.DifficultyMod = math.max(0.1, config.DifficultyMod - reduction)
		print("Luck 인챈트 적용:", enchantName, "난이도 감소:", reduction, "최종 난이도:", config.DifficultyMod)
	end

	-- 변이 효과들은 추가 보너스
	if enchantData.stats.WindyMutation and enchantData.stats.WindyMutation > 0 then
		config.RodPower = config.RodPower * 1.1 -- 추가 10% 힘 보너스
		print("Windy 변이 추가 보너스: +10% 힘")
	end

	if enchantData.stats.WetMutation and enchantData.stats.WetMutation > 0 then
		config.DifficultyMod = math.max(0.1, config.DifficultyMod * 0.95) -- 5% 추가 난이도 감소
		print("Wet 변이 추가 보너스: -5% 난이도")
	end

	if enchantData.stats.RedMutation and enchantData.stats.RedMutation > 0 then
		config.RodPower = config.RodPower * 1.5 -- 50% 힘 보너스
		config.DifficultyMod = math.max(0.1, config.DifficultyMod * 0.8) -- 20% 난이도 감소
		print("赤 변이 보너스: +50% 힘, -20% 난이도")
	end

	if enchantData.stats.BlueMutation and enchantData.stats.BlueMutation > 0 then
		config.RodPower = config.RodPower * 1.3 -- 30% 힘 보너스
		config.DifficultyMod = math.max(0.1, config.DifficultyMod * 0.9) -- 10% 난이도 감소
		print("青 변이 보너스: +30% 힘, -10% 난이도")
	end

	if enchantData.stats.LongMutation and enchantData.stats.LongMutation > 0 then
		config.RodPower = config.RodPower * 1.8 -- 80% 힘 보너스
		config.DifficultyMod = math.max(0.1, config.DifficultyMod * 0.7) -- 30% 난이도 감소
		print("Long 변이 보너스: +80% 힘, -30% 난이도")
	end

	if enchantData.stats.MassiveMutation and enchantData.stats.MassiveMutation > 0 then
		config.RodPower = config.RodPower * 2.5 -- 150% 힘 보너스
		config.DifficultyMod = math.max(0.05, config.DifficultyMod * 0.5) -- 50% 난이도 감소
		print("Massive 변이 보너스: +150% 힘, -50% 난이도")
	end

	if enchantData.stats.TrinityMutation and enchantData.stats.TrinityMutation > 0 then
		config.RodPower = config.RodPower * 3.0 -- 200% 힘 보너스
		config.DifficultyMod = math.max(0.05, config.DifficultyMod * 0.4) -- 60% 난이도 감소
		print("Trinity 변이 보너스: +200% 힘, -60% 난이도")
	end

	if enchantData.stats.RainbowMutation and enchantData.stats.RainbowMutation > 0 then
		config.RodPower = config.RodPower * 2.8 -- 180% 힘 보너스
		config.DifficultyMod = math.max(0.05, config.DifficultyMod * 0.45) -- 55% 난이도 감소
		print("Rainbow 변이 보너스: +180% 힘, -55% 난이도")
	end

	if enchantData.stats.VoidMutation and enchantData.stats.VoidMutation > 0 then
		config.RodPower = config.RodPower * 5.0 -- 400% 힘 보너스
		config.DifficultyMod = math.max(0.01, config.DifficultyMod * 0.2) -- 80% 난이도 감소
		print("Void 변이 보너스: +400% 힘, -80% 난이도")
	end

	if enchantData.stats.PurpleMutation and enchantData.stats.PurpleMutation > 0 then
		config.RodPower = config.RodPower * 8.0 -- 700% 힘 보너스
		config.DifficultyMod = math.max(0.01, config.DifficultyMod * 0.1) -- 90% 난이도 감소
		print("紫 변이 보너스: +700% 힘, -90% 난이도")
	end

	if enchantData.stats.CloverMutation and enchantData.stats.CloverMutation > 0 then
		config.RodPower = config.RodPower * 4.0 -- 300% 힘 보너스
		config.DifficultyMod = math.max(0.02, config.DifficultyMod * 0.3) -- 70% 난이도 감소
		print("Clover 변이 보너스: +300% 힘, -70% 난이도")
	end

	if enchantData.stats.LuckMutation and enchantData.stats.LuckMutation > 0 then
		config.RodPower = config.RodPower * 6.0 -- 500% 힘 보너스
		config.DifficultyMod = math.max(0.01, config.DifficultyMod * 0.15) -- 85% 난이도 감소
		print("Lucky 변이 보너스: +500% 힘, -85% 난이도")
	end

	if enchantData.stats.ErrorMutation and enchantData.stats.ErrorMutation > 0 then
		config.RodPower = config.RodPower * 20.0 -- 1900% 힘 보너스
		config.DifficultyMod = math.max(0.001, config.DifficultyMod * 0.05) -- 95% 난이도 감소
		print("ERROR 변이 보너스: +1900% 힘, -95% 난이도")
	end

	return config
end

-- ✅ 플레이어의 인챈트 정보를 포함한 로드 설정 가져오기
function FishingConfig.GetPlayerRodConfig(player, fullRodName)
	if not player then
		return FishingConfig.GetRodConfigWithEnchant(fullRodName, "None")
	end

	-- 기본 로드명 추출 (EnchantModule 사용)
	local baseRodName, _ = EnchantModule.ParseRodName(fullRodName)

	-- 플레이어의 인챈트 정보 가져오기 (EnchantModule 사용)
	local enchantName = EnchantModule.GetPlayerEnchant(player, baseRodName)

	return FishingConfig.GetRodConfigWithEnchant(fullRodName, enchantName)
end

-- ✅ 기존 호환성을 위한 함수들 - 기본 설정만 반환하도록 수정
function FishingConfig.GetRodConfig(fullRodName, enchantName)
	-- 이 함수는 명시적으로 인첸트를 적용할 때만 사용
	return FishingConfig.GetRodConfigWithEnchant(fullRodName, enchantName)
end

function FishingConfig.GetConfigByIndex(fullRodName)
	local baseRodName, _ = EnchantModule.ParseRodName(fullRodName)
	return FishingConfig.GetBaseRodConfig(baseRodName)  -- 기본 설정만 반환
end

-- ✅ 모든 기본 로드 설정 가져오기
function FishingConfig.GetAllBaseConfigs()
	return BaseRodConfigs
end

-- 인챈트 보너스 정보 가져오기 (EnchantModule 사용)
function FishingConfig.GetEnchantBonuses()
	return EnchantModule.ENCHANT_DATABASE
end

-- 특정 인챈트의 보너스 정보 가져오기 (EnchantModule 사용)
function FishingConfig.GetEnchantBonus(enchantName)
	return EnchantModule.GetEnchantData(enchantName)
end

-- 로드 목록 가져오기
function FishingConfig.GetRodList()
	local rodList = {}
	for rodName, _ in pairs(BaseRodConfigs) do
		table.insert(rodList, rodName)
	end
	return rodList
end

-- ✅ 기존 호환성을 위한 메타테이블 설정 - 기본 설정만 반환
setmetatable(FishingConfig, {
	__index = function(self, key)
		-- 기존 방식으로 접근할 때 기본 설정 반환 (인첸트 없음)
		return BaseRodConfigs[key]
	end
})

return FishingConfig
