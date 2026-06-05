-- FishDifficultyModule (ModuleScript in ReplicatedStorage.Modules)
local FishDifficulty = {}

-- Progress bar difficulty settings
FishDifficulty.Settings = {
	Common = {
		targetProgress = 100,
		hitSize = { min = 0.20, max = 0.25 },
		speed = { min = 1.5, max = 1.8 },
		progressMultiplier = 1.0,
		drainRate = 1,
	},
	Uncommon = {
		targetProgress = 120,
		hitSize = { min = 0.18, max = 0.22 },
		speed = { min = 1.5, max = 1.8 },
		progressMultiplier = 1,
		drainRate = 1.5,
	},
	Rare = {
		targetProgress = 140,
		hitSize = { min = 0.16, max = 0.20 },
		speed = { min = 1.5, max = 1.8 },
		progressMultiplier = 1,
		drainRate = 2,
	},
	Epic = {
		targetProgress = 160,
		hitSize = { min = 0.14, max = 0.18 },
		speed = { min = 1.5, max = 1.8 },
		progressMultiplier = 1,
		drainRate = 3,
	},
	Legendary = {
		targetProgress = 180,
		hitSize = { min = 0.12, max = 0.16 },
		speed = { min = 1.5, max = 1.8 },
		progressMultiplier = 1,
		drainRate = 4,
	},
	Mystic = {
		targetProgress = 200,
		hitSize = { min = 0.10, max = 0.14 },
		speed = { min = 1.5, max = 1.8 },
		progressMultiplier = 1,
		drainRate = 5.5,
	},
	Fantasy = {
		targetProgress = 250,
		hitSize = { min = 0.08, max = 0.12 },
		speed = { min = 1.1, max = 1.4 },
		progressMultiplier = 1,
		drainRate = 7,
	},
	Unknown = {
		targetProgress = 300,
		hitSize = { min = 0.06, max = 0.10 },
		speed = { min = 0.9, max = 1.2 },
		progressMultiplier = 1,
		drainRate = 9,
	},
	Soul = {
		targetProgress = 360,
		hitSize = { min = 0.09, max = 0.15 },
		speed = { min = 0.75, max = 1.05 },
		progressMultiplier = 1,
		drainRate = 12,
	},
}

-- Adjust difficulty settings based on rod power and fish weight.
-- fishWeight: actual weight of the fish (optional).
-- minWeight/maxWeight: the fish's natural weight range (optional, used for normalization).
-- Heavier fish (relative to their max weight) increase drainRate and reduce hitSize.
function FishDifficulty.GetModifiedSetting(rarityName, rodPower, fishWeight, minWeight, maxWeight)
	local base = FishDifficulty.Settings[rarityName] or FishDifficulty.Settings["Common"]
	local power = rodPower or 1.0

	-- Higher rod power = easier game
	local adjustedTargetProgress = math.max(50, base.targetProgress / power)
	local adjustedProgressMultiplier = base.progressMultiplier * power

	-- Weight difficulty: normalize weight within the fish's min-max range.
	-- weightRatio 0 = lightest, 1 = heaviest. Apply up to +80% drainRate and -20% hitSize at max weight.
	local weightPenalty = 0
	if fishWeight and fishWeight > 0 then
		local lo = minWeight or fishWeight
		local hi = maxWeight or fishWeight
		if hi > lo then
			weightPenalty = math.clamp((fishWeight - lo) / (hi - lo), 0, 1)
		end
	end
	local drainMult  = 1 + weightPenalty * 0.8   -- up to 1.8x drain at heaviest
	local hitShrink  = 1 - weightPenalty * 0.20   -- down to 0.80x hitSize at heaviest

	return {
		targetProgress = math.floor(adjustedTargetProgress),
		hitSize = {
			min = math.min(0.3,  base.hitSize.min * (1 + (power - 1) * 0.3) * hitShrink),
			max = math.min(0.35, base.hitSize.max * (1 + (power - 1) * 0.3) * hitShrink)
		},
		speed = {
			min = base.speed.min,
			max = base.speed.max
		},
		progressMultiplier = math.min(3.0, adjustedProgressMultiplier),
		drainRate = (base.drainRate or 4) * drainMult,
	}
end

-- Calculate base progress gain (with rod power applied)
function FishDifficulty.GetProgressGain(hitType, difficulty)
	local baseGain = {
		strong = 20,  -- Strong zone base gain
		normal = 15,  -- Normal zone base gain
		fail = -15    -- Miss penalty
	}

	local multiplier = difficulty.progressMultiplier or 1.0

	if hitType == "strong" then
		return math.floor(baseGain.strong * multiplier)
	elseif hitType == "normal" then
		return math.floor(baseGain.normal * multiplier)
	elseif hitType == "fail" then
		return baseGain.fail -- Miss is always fixed
	end

	return 0
end

-- Test function (dev only)
function FishDifficulty.TestAllRarities()

	--local testPowers = {1.0, 1.5, 2.0, 3.0}

	--for rarityName, settings in pairs(FishDifficulty.Settings) do

	--	for _, power in ipairs(testPowers) do
	--		local modified = FishDifficulty.GetModifiedSetting(rarityName, power)
	--		local strongGain = FishDifficulty.GetProgressGain("strong", modified)
	--		local normalGain = FishDifficulty.GetProgressGain("normal", modified)

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

	--		rod.name,
	--		rod.power,
	--		modified.targetProgress,
	--		(modified.hitSize.min + modified.hitSize.max) / 2 * 100, -- Average hit zone size
	--		strongGain,
	--		normalGain,
	--		modified.speed.min,
	--		modified.speed.max
	--		))
	--end
end

-- Run test on module load
task.spawn(function()
	task.wait(2)
	FishDifficulty.TestAllRarities()
end)

return FishDifficulty
