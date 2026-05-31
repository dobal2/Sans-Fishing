-- FishData Module (Enhanced with Multiple Fish per Rarity + Weather System + Ice Effects + Fixed Probability)
local FishData = {}
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")
local LuckGamePassId = 1289569606

local fishFolder = serverStorage:WaitForChild("Fishes")

-- Load WeatherSystem module
local WeatherSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeatherSystemModule"))
local EventState = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EventStateModule"))

local RunService = game:GetService("RunService")
local SkillServer = nil
local BoostAPI = nil
if RunService:IsServer() then
	local ok, result = pcall(function()
		return require(game:GetService("ServerScriptService"):WaitForChild("SkillHelper"))
	end)
	if ok then SkillServer = result end

	local ok2, api = pcall(function()
		return game:GetService("ServerScriptService"):WaitForChild("ServerBoostManager"):WaitForChild("ServerBoostAPI", 30)
	end)
	if ok2 and api then BoostAPI = api end
end

local Players = game:GetService("Players")

local ICE_SETTINGS = {
	material = Enum.Material.Plastic,
	transparency = 0.3,
	color = Color3.fromRGB(200, 240, 255),
	size_multiplier = 1.05,
	glow_intensity = 0.3
}

-- New structure: multiple fish per rarity
FishData.Rarities = {
	{
		name = "Common",
		chance = 46.9,
		fishes = {
			{ fishName = "Small Carp", value = 116, model = fishFolder:WaitForChild("small carp"), minWeight = 0.8, maxWeight = 100.0 },
			{ fishName = "Gold Fish", value = 139, model = fishFolder:WaitForChild("Gold Fish"), minWeight = 0.8, maxWeight = 100.0 },
			{ fishName = "Stone Fish", value = 154, model = fishFolder:WaitForChild("Stone Fish"), minWeight = 0.8, maxWeight = 100.0 }
		}
	},
	{
		name = "Uncommon",
		chance = 25,
		fishes = {
			{ fishName = "Crab", value = 201, model = fishFolder:WaitForChild("Crab"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Crystal Bass", value = 240, model = fishFolder:WaitForChild("Crystal Bass"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Dust Fish", value = 262, model = fishFolder:WaitForChild("Dust Fish"), minWeight = 1.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Rare",
		chance = 15,
		fishes = {
			{ fishName = "Bass", value = 503, model = fishFolder:WaitForChild("Bass"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Snow Fish", value = 560, model = fishFolder:WaitForChild("Snow Fish"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Diri", value = 541, model = fishFolder:WaitForChild("Diri"), minWeight = 2, maxWeight = 100.0 }
		}
	},
	{
		name = "Epic",
		chance = 8,
		fishes = {
			{ fishName = "Dragon Head Fish", value = 734, model = fishFolder:WaitForChild("Dragon Head Fish"), minWeight = 3.5, maxWeight = 100.0 },
			{ fishName = "Reggigash", value = 927, model = fishFolder:WaitForChild("Reggigash"), minWeight = 2, maxWeight = 100.0 }
		}
	},
	{
		name = "Legendary",
		chance = 3,
		fishes = {
			{ fishName = "Golden Trout", value = 1662, model = fishFolder:WaitForChild("Golden Trout"), minWeight = 3.0, maxWeight = 100.0 },
			{ fishName = "Armor Fish", value = 2086, model = fishFolder:WaitForChild("Armor Fish"), minWeight = 3.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Mystic",
		chance = 1.5,
		fishes = {
			{ fishName = "Shark", value = 3594, model = fishFolder:WaitForChild("Shark"), minWeight = 5.0, maxWeight = 100.0 },
			{ fishName = "Ray", value = 3478, model = fishFolder:WaitForChild("Ray"), minWeight = 5.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Fantasy",
		chance = 0.5,
		fishes = {
			{ fishName = "Undyine", value = 8114, model = fishFolder:WaitForChild("Undyine"), minWeight = 3.0, maxWeight = 100.0 },
			{ fishName = "Sans", value = 8887, model = fishFolder:WaitForChild("Sans"), minWeight = 3.0, maxWeight = 100.0 },
			{ fishName = "Electric Fish", value = 10819, model = fishFolder:WaitForChild("Electric Fish"), minWeight = 3.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Unknown",
		chance = 0.1,
		fishes = {
			{ fishName = "Unknown", value = 50232, model = fishFolder:WaitForChild("Unknown"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Nyan Cat", value = 56028, model = fishFolder:WaitForChild("Nyan Cat"), minWeight = 1.0, maxWeight = 100.0 }
		}
	}
}

local function createIceBlock(fishModel, fishInfo)
	if not fishModel then
		warn("Fish model is nil")
		return nil
	end

	-- Find PrimaryPart or Handle
	local targetPart = fishModel.PrimaryPart or fishModel:FindFirstChild("Handle")

	if not targetPart then
		warn("Fish model has no PrimaryPart or Handle:", fishModel.Name)
		return nil
	end

	-- Calculate size multiplier based on weight
	local fishWeight = fishInfo and fishInfo.weight
	local sizeMultiplier = ICE_SETTINGS.size_multiplier or 1.2

	if fishWeight then
		-- 1% increase per kg
		local weightMultiplier = 1.0 + (fishWeight - 1) * 0.01
		weightMultiplier = math.max(0.9, math.min(1.5, weightMultiplier))
		sizeMultiplier = sizeMultiplier * weightMultiplier
	end

	local size = targetPart.Size

	-- Create ice block
	local iceBlock = Instance.new("Part")
	iceBlock.Name = "IceBlock"
	iceBlock.Material = ICE_SETTINGS.material
	iceBlock.Transparency = ICE_SETTINGS.transparency
	iceBlock.Color = ICE_SETTINGS.color
	iceBlock.CanCollide = false
	iceBlock.Anchored = false

	-- Apply weight-based size
	iceBlock.Size = size * sizeMultiplier

	-- Round shape
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1.1, 0.8, 1.1) -- Oval shape
	mesh.Parent = iceBlock

	-- Glow effect
	local pointLight = Instance.new("PointLight")
	pointLight.Color = ICE_SETTINGS.color
	pointLight.Brightness = ICE_SETTINGS.glow_intensity
	pointLight.Range = size.Magnitude * 2
	pointLight.Parent = iceBlock

	-- Weld to fish
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = targetPart
	weld.Part1 = iceBlock
	weld.Parent = iceBlock

	-- Attach to fish model
	iceBlock.Parent = fishModel

	return iceBlock
end

-- Apply ice effect to fish model
local function applyIceEffect(fishModel, fishInfo)
	if not fishModel then
		warn("Fish model is nil")
		return false
	end

	-- Check if ice effect already exists
	if fishModel:FindFirstChild("IceBlock") then
		return false
	end

	-- Check for Frozen prefix
	if not fishInfo or not fishInfo.fishName or not string.find(fishInfo.fishName, "Frozen") then
		return false
	end

	-- Create ice block with weight info
	local iceBlock = createIceBlock(fishModel, fishInfo)
	if not iceBlock then
		warn("Ice block creation failed")
		return false
	end

	-- Tag fish model
	fishModel:SetAttribute("HasIceEffect", true)
	fishModel:SetAttribute("IceAppliedTime", tick())

	return true
end

-- Create snow particles
local function createSnowParticles(iceBlock)
	if not iceBlock then return end

	local attachment = Instance.new("Attachment")
	attachment.Name = "IceAttachment"
	attachment.Parent = iceBlock

	-- Snow particles
	local snowParticles = Instance.new("ParticleEmitter")
	snowParticles.Name = "SnowParticles"
	snowParticles.Parent = attachment

	snowParticles.Texture = "rbxasset://textures/particles/snow_main_01.dds"
	snowParticles.SpreadAngle = Vector2.new(45, 45)
	snowParticles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	snowParticles.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 0.1)
	}
	snowParticles.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1.0)
	}

	-- Sparkle particles
	local sparkleParticles = Instance.new("ParticleEmitter")
	sparkleParticles.Name = "SparkleParticles"
	sparkleParticles.Parent = attachment

	sparkleParticles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkleParticles.Lifetime = NumberRange.new(1.0, 3.0)
	sparkleParticles.Rate = 3
	sparkleParticles.Speed = NumberRange.new(0.2, 1.0)
	sparkleParticles.SpreadAngle = Vector2.new(360, 360)
	sparkleParticles.Color = ColorSequence.new(ICE_SETTINGS.color)
	sparkleParticles.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.3, 0.2),
		NumberSequenceKeypoint.new(1, 0.05)
	}
end

-- Remove ice effect
local function removeIceEffect(fishModel)
	if not fishModel then
		warn("Fish model is nil")
		return false
	end

	local iceBlock = fishModel:FindFirstChild("IceBlock")
	if not iceBlock then
		return false
	end

	-- Remove ice block only
	iceBlock:Destroy()

	-- Remove tags
	fishModel:SetAttribute("HasIceEffect", nil)
	fishModel:SetAttribute("IceAppliedTime", nil)

	return true
end

-- Apply festival effect to fish model
local function applyFestivalEffect(fishModel, fishInfo)
	if not fishModel then
		warn("Fish model is nil")
		return false
	end

	-- Check if festival effect already exists
	if fishModel:FindFirstChild("FestivalEffect") then
		return false
	end

	-- Check for Festival prefix
	if not fishInfo or not fishInfo.fishName or not string.find(fishInfo.fishName, "Festival") then
		return false
	end

	-- Find PrimaryPart or Handle
	local targetPart = fishModel.PrimaryPart or fishModel:FindFirstChild("Handle")
	if not targetPart then
		warn("Fish model has no PrimaryPart or Handle:", fishModel.Name)
		return false
	end

	-- Find Festival particle in ReplicatedStorage
	local festivalParticle = ReplicatedStorage:FindFirstChild("Particle") and
		ReplicatedStorage.Particle:FindFirstChild("Festival")

	if not festivalParticle then
		warn("ReplicatedStorage.Particle.Festival not found!")
		return false
	end

	-- Clone and apply festival particle
	local festivalClone = festivalParticle:Clone()
	festivalClone.Name = "FestivalEffect"
	festivalClone.Parent = targetPart

	-- Tag fish model
	fishModel:SetAttribute("HasFestivalEffect", true)
	fishModel:SetAttribute("FestivalAppliedTime", tick())

	return true
end

-- Remove festival effect
local function removeFestivalEffect(fishModel)
	if not fishModel then
		warn("Fish model is nil")
		return false
	end

	local targetPart = fishModel.PrimaryPart or fishModel:FindFirstChild("Handle")
	if not targetPart then
		return false
	end

	local festivalEffect = targetPart:FindFirstChild("FestivalEffect")
	if not festivalEffect then
		return false
	end

	-- Remove festival effect only
	festivalEffect:Destroy()

	-- Remove tags
	fishModel:SetAttribute("HasFestivalEffect", nil)
	fishModel:SetAttribute("FestivalAppliedTime", nil)

	return true
end

-- Rod tier determines weight distribution shift.
-- Higher tier rods push probability toward heavier brackets.
local ROD_WEIGHT_TIER = {
	FishingRod   = 0,
	["Silver Rod"]    = 1,
	GoldRod      = 2,
	CrystalRod   = 3,
	MagneticRod  = 4,
	BoneRod      = 5,
	CloverRod    = 6,
	RainbowRod   = 7,
	UnknownRod   = 8,
	RobuxRod     = 8,
	ElectricRod  = 9,
	RealisticRod = 10,
	ArcaneRod    = 11,
	FlameRod     = 11,
	VoidRod      = 12,
}

-- Fixed probability weight function
-- rodName shifts high-weight bracket chances upward for better rods.
-- Tier 0 (FishingRod): 1~5kg = 70.8% (original)
-- Each tier transfers 2% from the 1~5kg bucket into 5~40kg buckets.
-- Max shift at tier 12 (VoidRod): 1~5kg drops to ~46.8%, mid-heavy gains ~24%.
local function getFixedProbabilityWeight(minW, maxW, rodName, extraShift)
	local rng = Random.new()
	local r = rng:NextNumber()

	local tier = ROD_WEIGHT_TIER[rodName] or 0
	local shift = tier * 0.02 + (extraShift or 0)

	-- Distribute the shift: 50% into 5~10kg, 30% into 10~20kg, 20% into 20~40kg
	local base1_5    = 0.708 - shift
	local base5_10   = 0.175 + shift * 0.50
	local base10_20  = 0.040 + shift * 0.30
	local base20_40  = 0.017 + shift * 0.20

	-- Build cumulative thresholds
	local c1  = base1_5
	local c2  = c1 + base5_10
	local c3  = c2 + base10_20
	local c4  = c3 + base20_40
	local c5  = c4 + 0.005   -- 40~60kg  (unchanged)
	local c6  = c5 + 0.0025  -- 60~70kg  (unchanged)
	local c7  = c6 + 0.002   -- 70~80kg  (unchanged)
	local c8  = c7 + 0.00045 -- 80~90kg  (unchanged)
	-- 90~100kg: remaining ~0.00005 + fallback to 1~5kg for the rest

	local ranges = {
		{low = 1,   high = 5,   threshold = c1},
		{low = 5,   high = 10,  threshold = c2},
		{low = 10,  high = 20,  threshold = c3},
		{low = 20,  high = 40,  threshold = c4},
		{low = 40,  high = 60,  threshold = c5},
		{low = 60,  high = 70,  threshold = c6},
		{low = 70,  high = 80,  threshold = c7},
		{low = 80,  high = 90,  threshold = c8},
		{low = 90,  high = 100, threshold = 0.95},
		{low = 1,   high = 5,   threshold = 1.0},  -- fallback
	}
	-- (legacy field name kept as "chance" → renamed to "threshold" above;
	--  loop below uses threshold)

	for _, range in ipairs(ranges) do
		if r <= range.threshold then
			local low = math.max(minW, range.low)
			local high = math.min(maxW, range.high)
			if low < high then
				return rng:NextNumber(low, high)
			end
		end
	end

	return rng:NextNumber(1, 5)
end

-- Select random fish from rarity
local function selectRandomFishFromRarity(rarityData)
	local fishes = rarityData.fishes
	if #fishes == 1 then
		return fishes[1]
	end

	-- Seed based on current time
	local rng = Random.new(tick() * 1000000 + math.random(1, 1000000))
	local randomIndex = rng:NextInteger(1, #fishes)

	return fishes[randomIndex]
end

function FishData.CreateFishModel(fishInfo, position)
	if not fishInfo or not fishInfo.model then
		warn("Fish info or model is nil")
		return nil
	end

	-- Clone fish model
	local fishModel = fishInfo.model:Clone()
	fishModel.Name = fishInfo.fishName

	-- Set position (using PrimaryPart or Handle)
	if position then
		local targetPart = fishModel.PrimaryPart or fishModel:FindFirstChild("Handle")
		if targetPart then
			targetPart.CFrame = CFrame.new(position)
		else
			warn("Failed to set position: no PrimaryPart or Handle")
		end
	end

	-- Auto-apply ice effect (Frozen prefix + Snow weather)
	local weatherInfo = WeatherSystem.GetCurrentWeatherInfo()
	if weatherInfo and weatherInfo.isActive and weatherInfo.currentWeather == "Snow" then
		if fishInfo.fishName and string.find(fishInfo.fishName, "Frozen") then
			task.spawn(function()
				task.wait(0.1)
				applyIceEffect(fishModel, fishInfo)
			end)
		end
	end

	if weatherInfo and weatherInfo.isActive and weatherInfo.currentWeather == "Firework" then
		if fishInfo.fishName and string.find(fishInfo.fishName, "Festival") then
			task.spawn(function()
				task.wait(0.1)
				applyFestivalEffect(fishModel, fishInfo)
			end)
		end
	end

	-- Place in workspace
	fishModel.Parent = workspace

	return fishModel
end

-- Updated probability calculation system
function FishData.GetRandomFish(rodName, player, noWeather)
	local rng = Random.new()

	-- Get current weather info
	local weatherInfo = WeatherSystem.GetCurrentWeatherInfo()

	-- Base probabilities (exactly 100%)
	local baseChances = {
		["Common"] = 50.0,
		["Uncommon"] = 25.0,
		["Rare"] = 13.0,
		["Epic"] = 6.5,
		["Legendary"] = 3.0,
		["Mystic"] = 1.8,
		["Fantasy"] = 0.5,
		["Unknown"] = 0.1
	}

	-- Check gamepasses
	local hasLuckPass = false
	local hasLuckBubbleBuff = false

	if player then
		-- Check gamepass
		local success, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, LuckGamePassId)
		end)

		if success then
			hasLuckPass = result
		end

		-- Check luck bubble buff
		hasLuckBubbleBuff = player:GetAttribute("LuckBubbleBuff") == true
	end

	-- Adjust probabilities with luck gamepass (exactly 100%)
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
	end

	-- luck bubble buff: handled via luckBonus after rod/skill bonuses are summed

	-- Rod-based max weight bonus (adds to maxW cap, up to 200kg)
	local ROD_MAX_WEIGHT_BONUS = {
		FishingRod  = 0,
		["Silver Rod"]   = 10,
		GoldRod     = 20,
		CrystalRod  = 30,
		MagneticRod = 40,
		BoneRod     = 55,
		CloverRod   = 70,
		RainbowRod  = 85,
		UnknownRod  = 100,
		RobuxRod    = 100,
		ElectricRod  = 110,
		RealisticRod = 130,
		ArcaneRod    = 150,
		FlameRod     = 175,
		VoidRod      = 200,
	}
	local weightBonus = ROD_MAX_WEIGHT_BONUS[rodName] or 0

	-- WeightUp skill: extra probability shift toward heavier brackets
	local weightUpShift = 0
	if player then
		local skillsFolder = player:FindFirstChild("Skills")
		local wuVal = skillsFolder and skillsFolder:FindFirstChild("WeightUp")
		local WEIGHT_UP_SHIFTS = { 0.04, 0.10, 0.18, 0.28 }
		local wuLevel = wuVal and wuVal.Value or 0
		weightUpShift = (wuLevel > 0 and WEIGHT_UP_SHIFTS[wuLevel]) or 0
	end

	-- Per-rod luck bonus: multiplies Uncommon+ chances by (1 + luckBonus).
	-- VoidRod = 2.50 means 3.5× multiplier on all rare+ rarities.
	-- Common absorbs the reduction naturally after normalization.
	local ROD_LUCK_BONUS = {
		FishingRod        = 0,
		["Silver Rod"]    = 0.15,
		GoldRod           = 0.30,
		CrystalRod        = 0.50,
		MagneticRod       = 0.70,
		BoneRod           = 0.95,
		CloverRod         = 1.05,
		RainbowRod        = 1.50,
		UnknownRod        = 2.20,
		RobuxRod          = 3.00,
		ElectricRod       = 3.60,
		RealisticRod      = 5.20,
		ArcaneRod         = 6.50,
		FlameRod          = 8.00,
		VoidRod           = 10.00,
	}
	local luckBonus = ROD_LUCK_BONUS[rodName] or 0

	-- 스킬 럭 보너스 + 친구 보너스 누적
	if player and SkillServer then
		luckBonus = luckBonus + SkillServer.GetLuckBonus(player)

		-- FriendBonus: 친구 수 × 스킬 효과값
		local friendBonusPerFriend = SkillServer.GetEffect(player, "FriendBonus")
		if friendBonusPerFriend > 0 then
			local friendsCount = 0
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player then
					local ok, isFriend = pcall(function()
						return player:IsFriendsWith(other.UserId)
					end)
					if ok and isFriend then
						friendsCount += 1
					end
				end
			end
			luckBonus = luckBonus + (friendsCount * friendBonusPerFriend)
		end
	end

	-- luck bubble: adds flat +2.0 (200%) to luckBonus
	if hasLuckBubbleBuff then
		luckBonus = luckBonus + 2.0
	end

	-- Server boost: multiply total luckBonus by server boost multiplier
	if BoostAPI then
		local getBoostMult = BoostAPI:FindFirstChild("GetBoostMult")
		if getBoostMult then
			local ok, boostMult = pcall(function() return getBoostMult:Invoke() end)
			if ok and type(boostMult) == "number" and boostMult > 1 then
				luckBonus = luckBonus * boostMult
			end
		end
	end

	-- Developer event luck multiplier
	if EventState.LuckMultiplier > 1 then
		luckBonus = luckBonus * EventState.LuckMultiplier
	end

	local finalChances = {}
	for rarity, chance in pairs(baseChances) do
		finalChances[rarity] = chance
	end

	if luckBonus > 0 then
		local rarityScale = {
			Uncommon = 1.0,
			Rare     = 1.2,
			Epic     = 1.5,
			Legendary= 2.0,
			Mystic   = 2.5,
			Fantasy  = 3.5,
			Unknown  = 5.0,
		}
		for r, scale in pairs(rarityScale) do
			finalChances[r] = finalChances[r] * (1 + luckBonus * scale)
		end
	end

	-- Validate and normalize final probabilities
	local total = 0
	for _, chance in pairs(finalChances) do
		total = total + chance
	end

	-- Normalize to exactly 100%
	if total ~= 100 then
		local factor = 100 / total

		for rarity, chance in pairs(finalChances) do
			finalChances[rarity] = chance * factor
		end
	end

	-- Guarantee Common is at least 10% regardless of luck
	local COMMON_MIN = 10
	if (finalChances["Common"] or 0) < COMMON_MIN then
		finalChances["Common"] = COMMON_MIN
		local othersTotal = 0
		for r, c in pairs(finalChances) do
			if r ~= "Common" then othersTotal = othersTotal + c end
		end
		local targetOthers = 100 - COMMON_MIN
		if othersTotal > 0 then
			local scale = targetOthers / othersTotal
			for r in pairs(finalChances) do
				if r ~= "Common" then
					finalChances[r] = finalChances[r] * scale
				end
			end
		end
	end

	-- Build final list
	local combinedList = {}
	local finalTotal = 0

	for _, rarity in ipairs(FishData.Rarities) do
		local name = rarity.name
		local finalChance = finalChances[name] or 0

		table.insert(combinedList, {rarity = rarity, chance = finalChance})
		finalTotal = finalTotal + finalChance
	end

	-- Forced rarity override (set via admin command)
	if player then
		local forced = player:GetAttribute("ForcedRarity")
		if forced then
			player:SetAttribute("ForcedRarity", nil)
			for _, rarity in ipairs(FishData.Rarities) do
				if rarity.name == forced then
					local selectedFish = selectRandomFishFromRarity(rarity)
					local minW = selectedFish.minWeight or 1
					local maxW = math.min(200, (selectedFish.maxWeight or minW) + weightBonus)
					local weight = getFixedProbabilityWeight(minW, maxW, rodName, weightUpShift)
					weight = math.min(maxW, weight * EventState.WeightMultiplier)
					weight = math.floor(weight * 10 + 0.5) / 10
					local fishInfo = {
						name = rarity.name,
						fishName = selectedFish.fishName,
						value = selectedFish.value,
						model = selectedFish.model,
						minWeight = selectedFish.minWeight,
						maxWeight = selectedFish.maxWeight,
						weight = weight,
						chance = 0
					}
					if noWeather then return fishInfo end
					return WeatherSystem.ApplyWeatherEffects(fishInfo)
				end
			end
		end
	end

	-- Draw result
	local target = rng:NextNumber(0, finalTotal)

	local cumulative = 0
	for i, entry in ipairs(combinedList) do
		cumulative = cumulative + entry.chance

		if target <= cumulative then
			-- Select random fish from chosen rarity
			local selectedFish = selectRandomFishFromRarity(entry.rarity)

			local minW = selectedFish.minWeight or 1
			local maxW = math.min(200, (selectedFish.maxWeight or minW) + weightBonus)
			local weight = getFixedProbabilityWeight(minW, maxW, rodName, weightUpShift)
			weight = math.min(maxW, weight * EventState.WeightMultiplier)
			weight = math.floor(weight * 10 + 0.5) / 10

			-- Build fishInfo structure (backward compatible)
			local fishInfo = {
				name = entry.rarity.name,
				fishName = selectedFish.fishName,
				baseFishName = selectedFish.fishName, -- always the unprefixed base name
				value = selectedFish.value,
				model = selectedFish.model,
				minWeight = selectedFish.minWeight,
				maxWeight = selectedFish.maxWeight,
				weight = weight,
				chance = entry.chance
			}

			-- Apply weather effects (skip for fish trap catches)
			if not noWeather then
				fishInfo = WeatherSystem.ApplyWeatherEffects(fishInfo)
			end

			return fishInfo
		end
	end

	-- Default return (error prevention)
	local commonRarity = FishData.Rarities[1]
	local defaultFish = commonRarity.fishes[1]
	local fishInfo = {
		name = commonRarity.name,
		fishName = defaultFish.fishName,
		baseFishName = defaultFish.fishName,
		value = defaultFish.value,
		model = defaultFish.model,
		minWeight = defaultFish.minWeight,
		maxWeight = defaultFish.maxWeight,
		weight = 1.0,
		chance = commonRarity.chance
	}

	if noWeather then return fishInfo end
	return WeatherSystem.ApplyWeatherEffects(fishInfo)
end

-- Ice effect functions
function FishData.ApplyIceEffect(fishModel, fishInfo)
	return applyIceEffect(fishModel, fishInfo)
end

function FishData.RemoveIceEffect(fishModel)
	return removeIceEffect(fishModel)
end

function FishData.RemoveAllIceEffects()
	local removedCount = 0

	-- Find all fish models with ice effects
	local function searchForIceEffects(parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:GetAttribute("HasIceEffect") then
				removeIceEffect(child)
				removedCount = removedCount + 1
			end

			-- Recursively check children
			if #child:GetChildren() > 0 then
				searchForIceEffects(child)
			end
		end
	end

	searchForIceEffects(workspace)

	return removedCount
end

function FishData.HasIceEffect(fishModel)
	if not fishModel then return false end
	return fishModel:GetAttribute("HasIceEffect") == true
end

-- Update ice effect settings
function FishData.UpdateIceSettings(newSettings)
	if newSettings.material then ICE_SETTINGS.material = newSettings.material end
	if newSettings.transparency then ICE_SETTINGS.transparency = newSettings.transparency end
	if newSettings.color then ICE_SETTINGS.color = newSettings.color end
	if newSettings.size_multiplier then ICE_SETTINGS.size_multiplier = newSettings.size_multiplier end
	if newSettings.rotation_speed then ICE_SETTINGS.rotation_speed = newSettings.rotation_speed end
	if newSettings.glow_intensity then ICE_SETTINGS.glow_intensity = newSettings.glow_intensity end
end

-- Get fish info by rarity name (backward compatible)
function FishData.GetFishByRarity(rarityName)
	for _, rarity in ipairs(FishData.Rarities) do
		if rarity.name == rarityName then
			-- Return first fish (backward compatible)
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

-- Get all fish in a rarity
function FishData.GetAllFishInRarity(rarityName)
	for _, rarity in ipairs(FishData.Rarities) do
		if rarity.name == rarityName then
			return rarity.fishes
		end
	end
	return {}
end

-- Get fish info by name
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

-- Weather related functions
function FishData.GetWeatherInfo()
	return WeatherSystem.GetCurrentWeatherInfo()
end

function FishData.SetWeather(weatherName, duration)
	return WeatherSystem.SetWeather(weatherName, duration)
end

-- Handle weather change events (auto-manage ice effects)
if WeatherSystem.WeatherChanged then
	WeatherSystem.WeatherChanged.Event:Connect(function(newWeather)

		if newWeather ~= "Snow" then
			-- Remove all ice effects when weather changes from Snow
			FishData.RemoveAllIceEffects()
		end
	end)
end

-- Test function (dev only)
function FishData.TestIceEffect(fishModel)
	if not fishModel then
		warn("No fish model to test")
		return false
	end

	local testFishInfo = {
		fishName = "Frozen Test Fish",
		currentWeather = "Snow"
	}

	return applyIceEffect(fishModel, testFishInfo)
end

-- Force ice effect on all fish (test only)
function FishData.ForceIceEffectOnAll()
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

	return appliedCount
end

-- Auto-initialize system
task.spawn(function()
	-- Initialize weather system
	WeatherSystem.Initialize()

	-- Apply ice effects to existing fish on server restart
	task.wait(5) -- Wait for all systems to load

	local weatherInfo = WeatherSystem.GetCurrentWeatherInfo()
	if weatherInfo and weatherInfo.isActive and weatherInfo.currentWeather == "Snow" then

		-- Find Frozen fish in workspace
		local function searchAndApplyIce(parent)
			for _, child in pairs(parent:GetChildren()) do
				if child:IsA("Model") and child.Name:find("Frozen") then
					if not FishData.HasIceEffect(child) then
						local fakeInfo = {fishName = child.Name}
						applyIceEffect(child, fakeInfo)
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

-- Stats and status functions
function FishData.GetIceEffectStats()
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

-- Festival effect functions
function FishData.ApplyFestivalEffect(fishModel, fishInfo)
	return applyFestivalEffect(fishModel, fishInfo)
end

function FishData.RemoveFestivalEffect(fishModel)
	return removeFestivalEffect(fishModel)
end

function FishData.RemoveAllFestivalEffects()
	local removedCount = 0

	-- Find all fish models with festival effects
	local function searchForFestivalEffects(parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:GetAttribute("HasFestivalEffect") then
				removeFestivalEffect(child)
				removedCount = removedCount + 1
			end

			-- Recursively check children
			if #child:GetChildren() > 0 then
				searchForFestivalEffects(child)
			end
		end
	end

	searchForFestivalEffects(workspace)

	return removedCount
end

function FishData.HasFestivalEffect(fishModel)
	if not fishModel then return false end
	return fishModel:GetAttribute("HasFestivalEffect") == true
end

-- Print current status
function FishData.PrintStatus()
	local weatherInfo = WeatherSystem.GetCurrentWeatherInfo()
	local iceStats = FishData.GetIceEffectStats()
end

-- 서버 시작 시 로드 테이블 누락 자동 검증
-- 새 로드를 추가할 때 이 목록에도 반드시 추가해야 한다.
-- 누락된 항목은 서버 콘솔에 warn으로 출력된다.
if RunService:IsServer() then
	task.defer(function()
		local RodDataModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RodDataModule"))
		local FishingConfigModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishingConfigModule"))

		local ROD_LUCK_BONUS_CHECK = {
			"FishingRod", "Silver Rod", "GoldRod", "CrystalRod", "MagneticRod",
			"BoneRod", "CloverRod", "RainbowRod", "UnknownRod", "RobuxRod",
			"ElectricRod", "RealisticRod", "ArcaneRod", "FlameRod", "VoidRod",
		}
		local ROD_WEIGHT_TIER_CHECK = ROD_LUCK_BONUS_CHECK
		local ROD_MAX_WEIGHT_BONUS_CHECK = ROD_LUCK_BONUS_CHECK

		-- RodDataModule에 등록된 모든 로드가 FishingConfig에도 있는지 확인
		for rodKey, _ in pairs(RodDataModule.Rods) do
			if rodKey == "FriendRod" then continue end -- 특수 로드 제외
			if not FishingConfigModule[rodKey] then
				local rd = RodDataModule.Rods[rodKey]
				local sn = rd and rd.storageName
				if not (sn and FishingConfigModule[sn]) then
					warn(string.format("[RodBalance] FishingConfigModule에 '%s'(storageName='%s') 항목 없음 — 추가 필요", rodKey, tostring(sn)))
				end
			end
		end

		-- ROD_LUCK_BONUS, ROD_WEIGHT_TIER, ROD_MAX_WEIGHT_BONUS 검증은
		-- GetRandomFish 내부 로컬 테이블이므로 목록 기반으로 경고
		for _, rodName in ipairs(ROD_LUCK_BONUS_CHECK) do
			local rd = RodDataModule.Rods[rodName]
			if not rd then
				warn(string.format("[RodBalance] RodDataModule에 '%s' 항목 없음", rodName))
			end
			if not FishingConfigModule[rodName] then
				local sn = rd and rd.storageName
				if not (sn and FishingConfigModule[sn]) then
					warn(string.format("[RodBalance] FishingConfigModule에 '%s' 항목 없음", rodName))
				end
			end
		end
	end)
end

return FishData
