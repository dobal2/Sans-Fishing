-- RodData Module (Smart Position handling)
local RodData = {}

local function getSmartPosition(object)
	if not object then
		warn("Object does not exist")
		return Vector3.new(0, 0, 0)
	end

	if object:IsA("BasePart") then
		return object.Position
	end

	if object:IsA("Model") then
		if object.PrimaryPart then
			return object.PrimaryPart.Position
		end

		local success, cframe, size = pcall(function()
			return object:GetBoundingBox()
		end)
		if success then
			return cframe.Position
		end

		for _, child in pairs(object:GetChildren()) do
			if child:IsA("BasePart") then
				return child.Position
			end
		end

		warn("Cannot find Position in Model:", object.Name)
		return Vector3.new(0, 0, 0)
	end

	warn("Unsupported object type:", object.ClassName)
	return Vector3.new(0, 0, 0)
end

-- luck: % bonus applied to rare+ fish chances (Common reduced by this amount)
RodData.Rods = {
	["SliverRod"] = {
		price = 2000,
		storageName = "SliverRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("SliverRodModel")),
		luck = "+15%",
		power = "+15%",
		weight = "0.8 ~ 110kg",
	},
	["GoldRod"] = {
		price = 6000,
		storageName = "GoldRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("GoldRodModel")),
		luck = "+30%",
		power = "+17.5%",
		weight = "1 ~ 120kg",
	},
	["CrystalRod"] = {
		price = 20000,
		storageName = "CrystalRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("CrystalRodModel")),
		luck = "+50%",
		power = "+20%",
		weight = "2 ~ 130kg",
	},
	["MagneticRod"] = {
		price = 50000,
		storageName = "MagneticRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("MagneticRod")),
		luck = "+75%",
		power = "+25%",
		weight = "2 ~ 140kg",
	},
	["BoneRod"] = {
		price = 111111,
		storageName = "BoneRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("BoneRodModel")),
		luck = "+100%",
		power = "+30%",
		weight = "3 ~ 155kg",
	},
	["CloverRod"] = {
		price = 250000,
		storageName = "CloverRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("CloverRodModel")),
		luck = "+130%",
		power = "+37.5%",
		weight = "5 ~ 170kg",
	},
	["RainbowRod"] = {
		price = 500000,
		storageName = "RainbowRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("RainbowRodModel")),
		luck = "+120%",
		power = "+45%",
		weight = "3 ~ 185kg",
	},
	["UnknownRod"] = {
		price = 1000000,
		storageName = "UnknownRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("UnknownRodModel")),
		luck = "+170%",
		power = "+55%",
		weight = "1 ~ 200kg",
	},
	["RobuxRod"] = {
		price = 49,
		storageName = "RobuxRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("RobuxRodModel")),
		luck = "+200%",
		power = "+60%",
		weight = "1 ~ 200kg",
	},
	["ElectricRod"] = {
		price = 2250000,
		storageName = "ElectricRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("ElectricRodModel")),
		luck = "+300%",
		power = "+65%",
		weight = "1 ~ 200kg",
	},
	["RealisticRod"] = {
		price = 4500000,
		storageName = "RealisticRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("BlockyRodModel")),
		luck = "+380%",
		power = "+80%",
		weight = "1 ~ 200kg",
	},
	["ArcaneRod"] = {
		price = 6500000,
		storageName = "ArcaneRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("ArcaneRodModel")),
		luck = "+450%",
		power = "+85%",
		weight = "1 ~ 200kg",
	},
	["VoidRod"] = {
		price = 33550335,
		storageName = "VoidRod",
		position = Vector3.new(0, 0, 0),
		luck = "+600%",
		power = "+150%",
		weight = "1 ~ 200kg",
	},
}

return RodData
