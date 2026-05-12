-- FishIceEffectModule.lua
-- Module that adds a simple ice block to fish during Snow weather

local FishIceEffect = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ice effect settings
local ICE_SETTINGS = {
	material = Enum.Material.Plastic,
	transparency = 0.3,
	color = Color3.fromRGB(200, 240, 255),
	size_multiplier = 1,
	glow_intensity = 0.5    -- Moderate glow
}

-- createIceBlock function
local function createIceBlock(fishModel, fishInfo)
	if not fishModel then
		warn("Fish model is nil")
		return nil
	end

	local targetPart = fishModel.PrimaryPart or fishModel:FindFirstChild("Handle")
	if not targetPart then
		warn("Fish model has no PrimaryPart or Handle:", fishModel.Name)
		return nil
	end

	-- Calculate size multiplier based on weight
	local fishWeight = fishInfo and fishInfo.weight
	local sizeMultiplier = ICE_SETTINGS.size_multiplier or 1.15

	if fishWeight then
		-- 2% increase per kg
		local weightMultiplier = 1.0 + (fishWeight - 1) * 0.02
		weightMultiplier = math.max(0.8, math.min(2.5, weightMultiplier))
		sizeMultiplier = sizeMultiplier * weightMultiplier

	end


	local iceBlock = Instance.new("Part")
	iceBlock.Name = "IceBlock"
	iceBlock.Anchored = false
	iceBlock.CanCollide = false
	iceBlock.Massless = true

	-- Apply weight-based size
	iceBlock.Size = targetPart.Size * sizeMultiplier
	iceBlock.CFrame = targetPart.CFrame

	-- Force block shape
	iceBlock.Shape = Enum.PartType.Block
	for _, obj in pairs(iceBlock:GetChildren()) do
		if obj:IsA("SpecialMesh") or obj:IsA("Mesh") then
			obj:Destroy()
		end
	end

	-- Material and appearance
	iceBlock.Material = ICE_SETTINGS.material or Enum.Material.Plastic
	iceBlock.Transparency = ICE_SETTINGS.transparency
	iceBlock.Color = ICE_SETTINGS.color

	-- Place under same parent
	iceBlock.Parent = targetPart.Parent

	-- Fix with WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = targetPart
	weld.Part1 = iceBlock
	weld.Parent = iceBlock

	return iceBlock
end

-- ApplyIceEffect function
function FishIceEffect.ApplyIceEffect(fishModel, fishInfo)
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

	if fishInfo.weight then
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

-- Remove ice effect
function FishIceEffect.RemoveIceEffect(fishModel)
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

-- Remove all ice effects (on weather change)
function FishIceEffect.RemoveAllIceEffects()
	local removedCount = 0

	-- Find all fish models with ice effects
	local function searchForIceEffects(parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:GetAttribute("HasIceEffect") then
				FishIceEffect.RemoveIceEffect(child)
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

-- Check ice effect status
function FishIceEffect.HasIceEffect(fishModel)
	if not fishModel then return false end
	return fishModel:GetAttribute("HasIceEffect") == true
end

-- Auto-apply ice effect on fish creation (called from FishingSystem)
function FishIceEffect.CheckAndApplyIceEffect(fishModel, fishInfo)
	if not fishModel or not fishInfo then
		return false
	end

	-- Check current weather
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	if not modules then
		warn("Modules folder not found")
		return false
	end

	local weatherModule = modules:FindFirstChild("WeatherSystemModule")
	if not weatherModule then
		warn("WeatherSystemModule not found")
		return false
	end

	local success, WeatherSystem = pcall(function()
		return require(weatherModule)
	end)

	if not success then
		warn("WeatherSystem load failed:", WeatherSystem)
		return false
	end

	local weatherInfo = WeatherSystem.GetCurrentWeatherInfo()

	-- Only apply for Snow weather with Frozen prefix
	if weatherInfo and weatherInfo.isActive and weatherInfo.currentWeather == "Snow" then
		if fishInfo.fishName and string.find(fishInfo.fishName, "Frozen") then
			return FishIceEffect.ApplyIceEffect(fishModel, fishInfo)
		end
	end

	return false
end

-- Settings update function
function FishIceEffect.UpdateSettings(newSettings)
	if newSettings.material then ICE_SETTINGS.material = newSettings.material end
	if newSettings.transparency then ICE_SETTINGS.transparency = newSettings.transparency end
	if newSettings.color then ICE_SETTINGS.color = newSettings.color end
	if newSettings.size_multiplier then ICE_SETTINGS.size_multiplier = newSettings.size_multiplier end
	if newSettings.glow_intensity then ICE_SETTINGS.glow_intensity = newSettings.glow_intensity end

end

-- Test function
function FishIceEffect.TestIceEffect(fishModel)
	if not fishModel then
		warn("No fish model to test")
		return false
	end

	local testFishInfo = {
		fishName = "Frozen Test Fish",
		currentWeather = "Snow"
	}

	return FishIceEffect.ApplyIceEffect(fishModel, testFishInfo)
end

-- Force ice effect on all fish in workspace (test only)
function FishIceEffect.ForceIceEffectOnAll()
	local appliedCount = 0

	local function searchAndApplyIce(parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:IsA("Model") and child.Name and not FishIceEffect.HasIceEffect(child) then
				-- Force Frozen prefix on all fish for testing
				local fakeInfo = {fishName = "Frozen " .. child.Name}
				if FishIceEffect.ApplyIceEffect(child, fakeInfo) then
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

-- Ice effect statistics
function FishIceEffect.GetIceEffectStats()
	local stats = {
		totalFishWithIce = 0,
		totalFishModels = 0,
		iceEffectPercentage = 0
	}

	local function countModels(parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:IsA("Model") and child.Name then
				stats.totalFishModels = stats.totalFishModels + 1
				if FishIceEffect.HasIceEffect(child) then
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

return FishIceEffect
