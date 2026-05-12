-- FishDifficultyModule (ModuleScript in ReplicatedStorage.Modules)
local FishDifficulty = {}

-- 🎯 프로그레스 바 방식에 맞춘 새로운 설정
FishDifficulty.Settings = {
	Common = {
		targetProgress = 100,     -- 목표 진행도 (기본 100%)
		hitSize = { min = 0.20, max = 0.25 },     -- 히트존 크기 (20-25%)
		speed = { min = 1.5, max = 1.8 },         -- 슬라이더 속도 (초)
		progressMultiplier = 1.0  -- 진행도 배율 (기본값)
	},
	Uncommon = {
		targetProgress = 120,     -- 20% 더 긴 게임
		hitSize = { min = 0.18, max = 0.22 },     -- 조금 더 작은 히트존
		speed = { min = 1.5, max = 1.8 },         -- 조금 더 빠름
		progressMultiplier =1  -- 진행도 획득량 10% 감소
	},
	Rare = {
		targetProgress = 140,     -- 40% 더 긴 게임
		hitSize = { min = 0.16, max = 0.20 },     -- 더 작은 히트존
		speed = { min = 1.5, max = 1.8 },         -- 더 빠름
		progressMultiplier = 1  -- 진행도 획득량 20% 감소
	},
	Epic = {
		targetProgress = 160,     -- 60% 더 긴 게임
		hitSize = { min = 0.14, max = 0.18 },     -- 작은 히트존
		speed = { min = 1.5, max = 1.8 },         -- 빠름
		progressMultiplier = 1  -- 진행도 획득량 30% 감소
	},
	Legendary = {
		targetProgress = 180,     -- 80% 더 긴 게임
		hitSize = { min = 0.12, max = 0.16 },     -- 매우 작은 히트존
		speed = { min = 1.5, max = 1.8 },         -- 매우 빠름
		progressMultiplier = 1  -- 진행도 획득량 40% 감소
	},
	Mystic = {
		targetProgress = 200,     -- 2배 더 긴 게임
		hitSize = { min = 0.10, max = 0.14 },     -- 극도로 작은 히트존
		speed = { min = 1.5, max = 1.8 },         -- 극도로 빠름
		progressMultiplier = 1  -- 진행도 획득량 50% 감소
	},
	Fantasy = {
		targetProgress = 250,     -- 2.5배 더 긴 게임
		hitSize = { min = 0.08, max = 0.12 },     -- 매우 극도로 작은 히트존
		speed = { min = 1.5, max = 1.8 },         -- 매우 극도로 빠름
		progressMultiplier = 1  -- 진행도 획득량 60% 감소
	},
	Unknown = {
		targetProgress = 300,     -- 3배 더 긴 게임
		hitSize = { min = 0.06, max = 0.10 },     -- 극한으로 작은 히트존
		speed = { min = 1.5, max = 1.8 },         -- 극한으로 빠름
		progressMultiplier = 1  -- 진행도 획득량 70% 감소
	},
}

-- 🎯 낚싯대 파워에 따른 설정 조정 함수
function FishDifficulty.GetModifiedSetting(rarityName, rodPower)
	local base = FishDifficulty.Settings[rarityName] or FishDifficulty.Settings["Common"]
	local power = rodPower or 1.0

	print("[DIFFICULTY]", rarityName, "→ 목표진행도 =", base.targetProgress, "낚싯대파워 =", power)

	-- 🔧 낚싯대 파워가 높을수록 게임이 쉬워짐
	local adjustedTargetProgress = math.max(50, base.targetProgress / power) -- 최소 50%
	local adjustedProgressMultiplier = base.progressMultiplier * power        -- 파워가 높으면 더 많이 증가

	return {
		targetProgress = math.floor(adjustedTargetProgress),
		hitSize = {
			min = math.min(0.3, base.hitSize.min * (1 + (power - 1) * 0.3)), -- 파워가 높으면 히트존도 커짐
			max = math.min(0.35, base.hitSize.max * (1 + (power - 1) * 0.3))
		},
		speed = {
			min = base.speed.min, -- 🔧 속도는 낚싯대와 관계없이 일정
			max = base.speed.max  -- 🔧 속도는 낚싯대와 관계없이 일정
		},
		progressMultiplier = math.min(3.0, adjustedProgressMultiplier) -- 최대 3배까지만
	}
end

-- 🎯 기본 진행도 증가량 계산 (낚싯대 파워 적용)
function FishDifficulty.GetProgressGain(hitType, difficulty)
	local baseGain = {
		strong = 20,  -- 스트롱존 기본 증가량
		normal = 10,  -- 일반존 기본 증가량
		fail = -15    -- 실패 시 감소량
	}

	local multiplier = difficulty.progressMultiplier or 1.0

	if hitType == "strong" then
		return math.floor(baseGain.strong * multiplier)
	elseif hitType == "normal" then
		return math.floor(baseGain.normal * multiplier)
	elseif hitType == "fail" then
		return baseGain.fail -- 실패는 항상 고정
	end

	return 0
end

-- 🧪 테스트 함수 (개발용)
function FishDifficulty.TestAllRarities()
	--print("🧪 === 모든 등급별 난이도 테스트 ===")

	--local testPowers = {1.0, 1.5, 2.0, 3.0}

	--for rarityName, settings in pairs(FishDifficulty.Settings) do
	--	print("\n📊", rarityName, "등급:")
	--	print("  기본 목표:", settings.targetProgress .. "%")
	--	print("  기본 속도:", string.format("%.1f-%.1fs", settings.speed.min, settings.speed.max))

	--	for _, power in ipairs(testPowers) do
	--		local modified = FishDifficulty.GetModifiedSetting(rarityName, power)
	--		local strongGain = FishDifficulty.GetProgressGain("strong", modified)
	--		local normalGain = FishDifficulty.GetProgressGain("normal", modified)

	--		print(string.format("  파워 %.1f: 목표 %d%%, 히트존 %.1f-%.1f%%, 속도 %.1f-%.1fs, 스트롱+%d%%, 일반+%d%%",
	--			power,
	--			modified.targetProgress,
	--			modified.hitSize.min * 100,
	--			modified.hitSize.max * 100,
	--			modified.speed.min,
	--			modified.speed.max,
	--			strongGain,
	--			normalGain
	--			))
	--	end
	--end

	--print("\n🎣 === 낚싯대별 효과 예시 (Fantasy 등급) ===")
	--local fantasyTests = {
	--	{name = "FishingRod", power = 1.0},
	--	{name = "GoldRod", power = 1.2},
	--	{name = "BoneRod", power = 1.5},
	--	{name = "RainbowRod", power = 1.8},
	--	{name = "FriendRod", power = 3.0}
	--}

	--for _, rod in ipairs(fantasyTests) do
	--	local modified = FishDifficulty.GetModifiedSetting("Fantasy", rod.power)
	--	local strongGain = FishDifficulty.GetProgressGain("strong", modified)
	--	local normalGain = FishDifficulty.GetProgressGain("normal", modified)

	--	print(string.format("🎣 %s (파워 %.1f): 목표 %d%%, 히트존 %.1f%%, 스트롱+%d%%, 일반+%d%% | 속도 %.1f-%.1fs (일정)",
	--		rod.name,
	--		rod.power,
	--		modified.targetProgress,
	--		(modified.hitSize.min + modified.hitSize.max) / 2 * 100, -- 평균 히트존 크기
	--		strongGain,
	--		normalGain,
	--		modified.speed.min,
	--		modified.speed.max
	--		))
	--end
end

-- 🚀 모듈 로드시 테스트 실행
spawn(function()
	wait(2)
	FishDifficulty.TestAllRarities()
end)

return FishDifficulty
