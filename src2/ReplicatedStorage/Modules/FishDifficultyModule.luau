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
		speed = { min = 1.5, max = 1.8 },
		progressMultiplier = 1,
		drainRate = 7,
	},
	Unknown = {
		targetProgress = 300,
		hitSize = { min = 0.06, max = 0.10 },
		speed = { min = 1.5, max = 1.8 },
		progressMultiplier = 1,
		drainRate = 9,
	},
}

-- Adjust difficulty settings based on rod power
function FishDifficulty.GetModifiedSetting(rarityName, rodPower)
	local base = FishDifficulty.Settings[rarityName] or FishDifficulty.Settings["Common"]
	local power = rodPower or 1.0


	-- Higher rod power = easier game
	local adjustedTargetProgress = math.max(50, base.targetProgress / power) -- Minimum 50%
	local adjustedProgressMultiplier = base.progressMultiplier * power        -- More gain with higher power

	return {
		targetProgress = math.floor(adjustedTargetProgress),
		hitSize = {
			min = math.min(0.3, base.hitSize.min * (1 + (power - 1) * 0.3)),
			max = math.min(0.35, base.hitSize.max * (1 + (power - 1) * 0.3))
		},
		speed = {
			min = base.speed.min,
			max = base.speed.max
		},
		progressMultiplier = math.min(3.0, adjustedProgressMultiplier),
		drainRate = base.drainRate or 4,
	}
end

-- Calculate base progress gain (with rod power applied)
function FishDifficulty.GetProgressGain(hitType, difficulty)
	local baseGain = {
		strong = 20,  -- Strong zone base gain
		normal = 10,  -- Normal zone base gain
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
