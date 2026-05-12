-- RodData Module (Smart Position handling)
local RodData = {}

-- Smart Position getter function
local function getSmartPosition(object)
	if not object then
		warn("Object does not exist")
		return Vector3.new(0, 0, 0)
	end

	-- If Part: use Position directly
	if object:IsA("BasePart") then
		return object.Position
	end

	-- If Model: use PrimaryPart
	if object:IsA("Model") then

		-- Use PrimaryPart if set
		if object.PrimaryPart then
			return object.PrimaryPart.Position
		end

		-- Fall back to GetBoundingBox
		local success, cframe, size = pcall(function()
			return object:GetBoundingBox()
		end)
		if success then
			return cframe.Position
		end

		-- Backup: find first Part
		for _, child in pairs(object:GetChildren()) do
			if child:IsA("BasePart") then
				return child.Position
			end
		end

		warn("Cannot find Position in Model:", object.Name)
		return Vector3.new(0, 0, 0)
	end

	-- Other object types
	warn("Unsupported object type:", object.ClassName)
	return Vector3.new(0, 0, 0)
end

RodData.Rods = {
	["SliverRod"] = {
		price = 2000,
		storageName = "SliverRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("SliverRodModel")),
		desc = "<font color=\"#FF0000\">+15%</font> Rod Power"
	},
	["GoldRod"] = {
		price = 6000,
		storageName = "GoldRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("GoldRodModel")),
		desc = "<font color=\"#FF0000\">+17.5%</font> Rod Power\n+<font color=\"#0080FF\">5%</font> <font color=\"#0080FF\">Rare</font> chance"
	},
	["CrystalRod"] = {
		price = 20000,
		storageName = "CrystalRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("CrystalRodModel")),
		desc = "<font color=\"#FF0000\">+20%</font> Rod Power\n+<font color=\"#800080\">4%</font> <font color=\"#800080\">Epic</font> chance"
	},
	["MagneticRod"] = {
		price = 50000,
		storageName = "MagneticRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("MagneticModel")),
		desc = "<font color=\"#FF0000\">+25%</font> Rod Power\n+<font color=\"#FFA500\">0.3%</font> <font color=\"#FFA500\">Mystic</font> chance\n+<font color=\"#FF69B4\">1%</font> <font color=\"#FF69B4\">Legendary</font> chance\n+<font color=\"#800080\">2%</font> <font color=\"#800080\">Epic</font> chance"
	},
	["BoneRod"] = {
		price = 111111,
		storageName = "BoneRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("BoneRodModel")),
		desc = "<font color=\"#FF0000\">+30%</font> Rod Power\n+<font color=\"#FFA500\">0.7%</font> <font color=\"#FFA500\">Mystic</font> chance\n+<font color=\"#FF69B4\">3%</font> <font color=\"#FF69B4\">Legendary</font> chance"
	},
	["CloverRod"] = {
		price = 250000,
		storageName = "CloverRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("CloverRodModel")),
		desc = "<font color=\"#FF0000\">+37.5%</font> Rod Power\n+<font color=\"#87CEEB\">0.2%</font> <font color=\"#87CEEB\">Fantasy</font> chance\n+<font color=\"#FFA500\">1%</font> <font color=\"#FFA500\">Mystic</font> chance\n+<font color=\"#FF69B4\">2%</font> <font color=\"#FF69B4\">Legendary</font> chance"
	},
	["RainbowRod"] = {
		price = 500000,
		storageName = "RainbowRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("RainbowRodModel")),
		desc = "<font color=\"#FF0000\">+45%</font> Rod Power\n+<font color=\"#87CEEB\">0.4%</font> <font color=\"#87CEEB\">Fantasy</font> chance\n+<font color=\"#FFA500\">2.5%</font> <font color=\"#FFA500\">Mystic</font> chance\n+<font color=\"#FF69B4\">3%</font> <font color=\"#FF69B4\">Legendary</font> chance"
	},
	["UnknownRod"] = {
		price = 1000000,
		storageName = "UnknownRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("UnknownRodModel")),
		desc = "<font color=\"#FF0000\">+55%</font> Rod Power\n+<font color=\"#800080\">0.1%</font> <font color=\"#800080\">Unknown</font> chance\n+<font color=\"#87CEEB\">0.5%</font> <font color=\"#87CEEB\">Fantasy</font> chance\n+<font color=\"#FFA500\">2%</font> <font color=\"#FFA500\">Mystic</font> chance"
	},
	["RobuxRod"] = {
		price = 49,
		storageName = "RobuxRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("RobuxRodModel")),
		desc = "<font color=\"#FF0000\">+60%</font> Rod Power\n+<font color=\"#800080\">0.2%</font> <font color=\"#800080\">Unknown</font> chance\n+<font color=\"#87CEEB\">0.7%</font> <font color=\"#87CEEB\">Fantasy</font> chance\n+<font color=\"#FFA500\">3%</font> <font color=\"#FFA500\">Mystic</font> chance"
	},
	["ElectricRod"] = {
		price = 2250000,
		storageName = "ElectricRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("ElectricRodModel")),
		desc = "<font color=\"#FF0000\">+65%</font> Rod Power\n+<font color=\"#800080\">0.25%</font> <font color=\"#800080\">Unknown</font> chance\n+<font color=\"#87CEEB\">0.8%</font> <font color=\"#87CEEB\">Fantasy</font> chance\n+<font color=\"#FFA500\">4%</font> <font color=\"#FFA500\">Mystic</font> chance"
	},
	["RealisticRod"] = {
		price = 4500000,
		storageName = "RealisticRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("RealisticRodModel")),
		desc = "<font color=\"#FF0000\">+80%</font> Rod Power\n+<font color=\"#800080\">0.5%</font> <font color=\"#800080\">Unknown</font> chance\n+<font color=\"#87CEEB\">1.3%</font> <font color=\"#87CEEB\">Fantasy</font> chance\n+<font color=\"#FFA500\">5%</font> <font color=\"#FFA500\">Mystic</font> chance"
	},
	["ArcaneRod"] = {
		price = 6500000,
		storageName = "ArcaneRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("ArcaneRodModel")),
		desc = "<font color=\"#FF0000\">+85%</font> Rod Power\n+<font color=\"#800080\">0.8%</font> <font color=\"#800080\">Unknown</font> chance\n+<font color=\"#87CEEB\">1.6%</font> <font color=\"#87CEEB\">Fantasy</font> chance\n+<font color=\"#FFA500\">5.5%</font> <font color=\"#FFA500\">Mystic</font> chance"
	},
	["VoidRod"] = {
		price = 33550335,
		storageName = "VoidRod",
		position = getSmartPosition(workspace:WaitForChild("VoidRodModel")),
		desc = "<font color=\"#FF0000\">+150%</font> Rod Power\n+<font color=\"#800080\">1.5%</font> <font color=\"#800080\">Unknown</font> chance\n+<font color=\"#87CEEB\">4%</font> <font color=\"#87CEEB\">Fantasy</font> chance\n+<font color=\"#FFA500\">6%</font> <font color=\"#FFA500\">Mystic</font> chance\n+<font color=\"#FF69B4\">7%</font> <font color=\"#FF69B4\">Legendary</font> chance"
	}

}

return RodData

-- Simpler one-liner version (when confident):
--[[
position = workspace["Upgrade Shop"]["RealisticRodModel"]:IsA("Model") and
          workspace["Upgrade Shop"]["RealisticRodModel"].PrimaryPart.Position or
          workspace["Upgrade Shop"]["RealisticRodModel"].Position
--]]
