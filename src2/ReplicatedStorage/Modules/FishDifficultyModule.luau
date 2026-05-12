-- FishDifficultyModule (ModuleScript in ReplicatedStorage.Modules)
local FishDifficulty = {}

-- Progress bar difficulty settings
FishDifficulty.Settings = {
	Common = {
		targetProgress = 100,     -- Target progress (default 100%)
		hitSize = { min = 0.20, max = 0.25 },     -- Hit zone size (20-25%)
		speed = { min = 1.5, max = 1.8 },         -- Slider speed (seconds)
		progressMultiplier = 1.0  -- Progress multiplier (default)
	},
	Uncommon = {
		targetProgress = 120,     -- 20% longer game
		hitSize = { min = 0.18, max = 0.22 },     -- Slightly smaller hit zone
		speed = { min = 1.5, max = 1.8 },         -- Slightly faster
		progressMultiplier =1
	},
	Rare = {
		targetProgress = 140,     -- 40% longer game
		hitSize = { min = 0.16, max = 0.20 },     -- Smaller hit zone
		speed = { min = 1.5, max = 1.8 },         -- Faster
		progressMultiplier = 1
	},
	Epic = {
		targetProgress = 160,     -- 60% longer game
		hitSize = { min = 0.14, max = 0.18 },     -- Small hit zone
		speed = { min = 1.5, max = 1.8 },         -- Fast
		progressMultiplier = 1
	},
	Legendary = {
		targetProgress = 180,     -- 80% longer game
		hitSize = { min = 0.12, max = 0.16 },     -- Very small hit zone
		speed = { min = 1.5, max = 1.8 },         -- Very fast
		progressMultiplier = 1
	},
	Mystic = {
		targetProgress = 200,     -- 2x longer game
		hitSize = { min = 0.10, max = 0.14 },     -- Extremely small hit zone
		speed = { min = 1.5, max = 1.8 },         -- Extremely fast
		progressMultiplier = 1
	},
	Fantasy = {
		targetProgress = 250,     -- 2.5x longer game
		hitSize = { min = 0.08, max = 0.12 },     -- Very extremely small hit zone
		speed = { min = 1.5, max = 1.8 },         -- Very extremely fast
		progressMultiplier = 1
	},
	Unknown = {
		targetProgress = 300,     -- 3x longer game
		hitSize = { min = 0.06, max = 0.10 },     -- Extreme hit zone
		speed = { min = 1.5, max = 1.8 },         -- Extreme speed
		progressMultiplier = 1
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
			min = math.min(0.3, base.hitSize.min * (1 + (power - 1) * 0.3)), -- Larger hit zone with higher power
			max = math.min(0.35, base.hitSize.max * (1 + (power - 1) * 0.3))
		},
		speed = {
			min = base.speed.min, -- Speed is constant regardless of rod
			max = base.speed.max  -- Speed is constant regardless of rod
		},
		progressMultiplier = math.min(3.0, adjustedProgressMultiplier) -- Max 3x
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
spawn(function()
	wait(2)
	FishDifficulty.TestAllRarities()
end)

return FishDifficulty
