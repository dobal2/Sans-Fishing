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
			{ fishName = "Small Carp", value = 300, model = fishFolder:WaitForChild("small carp"), minWeight = 0.8, maxWeight = 100.0 },
			{ fishName = "Gold Fish", value = 360, model = fishFolder:WaitForChild("Gold Fish"), minWeight = 0.8, maxWeight = 100.0 },
			{ fishName = "Stone Fish", value = 400, model = fishFolder:WaitForChild("Stone Fish"), minWeight = 0.8, maxWeight = 100.0 }
		}
	},
	{
		name = "Uncommon",
		chance = 25,
		fishes = {
			{ fishName = "Crab", value = 520, model = fishFolder:WaitForChild("Crab"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Crystal Bass", value = 620, model = fishFolder:WaitForChild("Crystal Bass"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Dust Fish", value = 680, model = fishFolder:WaitForChild("Dust Fish"), minWeight = 1.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Rare",
		chance = 15,
		fishes = {
			{ fishName = "Bass", value = 1300, model = fishFolder:WaitForChild("Bass"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Snow Fish", value = 1450, model = fishFolder:WaitForChild("Snow Fish"), minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Diri", value = 1400, model = fishFolder:WaitForChild("Diri"), minWeight = 2, maxWeight = 100.0 }
		}
	},
	{
		name = "Epic",
		chance = 8,
		fishes = {
			{ fishName = "Dragon Head Fish", value = 1900, model = fishFolder:WaitForChild("Dragon Head Fish"), minWeight = 3.5, maxWeight = 100.0 },
			{ fishName = "Reggigash", value = 2400, model = fishFolder:WaitForChild("Reggigash"), minWeight = 2, maxWeight = 100.0 }
		}
	},
	{
		name = "Legendary",
		chance = 3,
		fishes = {
			{ fishName = "Golden Trout", value = 4300, model = fishFolder:WaitForChild("Golden Trout"), minWeight = 3.0, maxWeight = 100.0 },
			{ fishName = "Armor Fish", value = 5400, model = fishFolder:WaitForChild("Armor Fish"), minWeight = 3.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Mystic",
		chance = 1.5,
		fishes = {
			{ fishName = "Shark", value = 9300, model = fishFolder:WaitForChild("Shark"), minWeight = 5.0, maxWeight = 100.0 },
			{ fishName = "Ray", value = 9000, model = fishFolder:WaitForChild("Ray"), minWeight = 5.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Fantasy",
		chance = 0.5,
		fishes = {
			{ fishName = "Undyine", value = 21000, model = fishFolder:WaitForChild("Undyine"), minWeight = 3.0, maxWeight = 100.0 },
			{ fishName = "Sans", value = 23000, model = fishFolder:WaitForChild("Sans"), minWeight = 3.0, maxWeight = 100.0 },
			{ fishName = "Electric Fish", value = 28000, model = fishFolder:WaitForChild("Electric Fish"), minWeight = 3.0, maxWeight = 100.0 }
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

-- Fixed probability weight function
local function getFixedProbabilityWeight(minW, maxW)
	local rng = Random.new()
	local r = rng:NextNumber()

	-- Correct cumulative probability (total 100%)
	local ranges = {
		{low = 1,   high = 5,   chance = 0.708},    -- 70.8%
		{low = 5,   high = 10,  chance = 0.883},    -- 17.5%
		{low = 10,  high = 20,  chance = 0.923},    -- 4.0%
		{low = 20,  high = 40,  chance = 0.940},    -- 1.7%
		{low = 40,  high = 60,  chance = 0.945},    -- 0.5%
		{low = 60,  high = 70,  chance = 0.9475},   -- 0.25%
		{low = 70,  high = 80,  chance = 0.9495},   -- 0.2%
		{low = 80,  high = 90,  chance = 0.94995},  -- 0.045% (80-90kg)
		{low = 90,  high = 100, chance = 0.95},     -- 0.005% (90-100kg)
		{low = 1,   high = 5,   chance = 1.0}       -- Remaining 5% is 1-5kg
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

	-- Backup (1-5kg only)
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
function FishData.GetRandomFish(rodName, player)
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

	-- Apply luck bubble buff (stacks with gamepass)
	if hasLuckBubbleBuff then
		baseChances = {
			["Common"] = baseChances["Common"] * 0.8,     -- Common -20%
			["Uncommon"] = baseChances["Uncommon"] * 0.9, -- Uncommon -10%
			["Rare"] = baseChances["Rare"] * 1.1,        -- Rare +10%
			["Epic"] = baseChances["Epic"] * 1.3,        -- Epic +30%
			["Legendary"] = baseChances["Legendary"] * 1.5, -- Legendary +50%
			["Mystic"] = baseChances["Mystic"] * 1.8,    -- Mystic +80%
			["Fantasy"] = baseChances["Fantasy"] * 2.0,  -- Fantasy +100%
			["Unknown"] = baseChances["Unknown"] * 2.5   -- Unknown +150%
		}
	end

	-- Rod-based max weight bonus (adds to maxW cap, up to 200kg)
	local ROD_MAX_WEIGHT_BONUS = {
		FishingRod  = 0,
		SliverRod   = 10,
		GoldRod     = 20,
		CrystalRod  = 30,
		MagneticRod = 40,
		BoneRod     = 55,
		CloverRod   = 70,
		RainbowRod  = 85,
		UnknownRod  = 100,
		RobuxRod    = 100,
		ElectricRod = 110,
		RealisticRod= 130,
		ArcaneRod   = 150,
		VoidRod     = 200,
	}
	local weightBonus = ROD_MAX_WEIGHT_BONUS[rodName] or 0

	-- Per-rod luck bonus: multiplies Uncommon+ chances by (1 + luckBonus).
	-- VoidRod = 2.50 means 3.5× multiplier on all rare+ rarities.
	-- Common absorbs the reduction naturally after normalization.
	local ROD_LUCK_BONUS = {
		FishingRod   = 0,
		SliverRod    = 0.15,
		GoldRod      = 0.30,
		CrystalRod   = 0.50,
		MagneticRod  = 0.75,
		BoneRod      = 1.00,
		CloverRod    = 1.30,
		RainbowRod   = 1.20,
		UnknownRod   = 1.70,
		RobuxRod     = 2.00,
		ElectricRod  = 3.00,
		RealisticRod = 3.80,
		ArcaneRod    = 4.50,
		VoidRod      = 6.00,
	}
	local luckBonus = ROD_LUCK_BONUS[rodName] or 0

	local finalChances = {}
	for rarity, chance in pairs(baseChances) do
		finalChances[rarity] = chance
	end

	if luckBonus > 0 then
		local multiplier = 1 + luckBonus
		local rareRarities = { "Uncommon", "Rare", "Epic", "Legendary", "Mystic", "Fantasy", "Unknown" }
		for _, r in ipairs(rareRarities) do
			finalChances[r] = finalChances[r] * multiplier
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
					local weight = getFixedProbabilityWeight(minW, maxW)
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
			local weight = getFixedProbabilityWeight(minW, maxW)
			weight = math.floor(weight * 10 + 0.5) / 10

			-- Build fishInfo structure (backward compatible)
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

			-- Apply weather effects
			fishInfo = WeatherSystem.ApplyWeatherEffects(fishInfo)

			return fishInfo
		end
	end

	-- Default return (error prevention)
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

return FishData
