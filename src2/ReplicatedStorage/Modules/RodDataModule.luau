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

-- luck 표시값 규칙: FishDataModule.luau의 ROD_LUCK_BONUS 테이블 값 × 100 = luck 문자열 숫자
-- 예) ROD_LUCK_BONUS.VoidRod = 10.00 → luck = "+1000%"
-- 두 파일의 값을 동시에 수정해야 상점 표시와 실제 확률이 일치한다
RodData.Rods = {
	["FishingRod"] = {
		price = 0,
		storageName = "FishingRod",
		displayName = "Fishing Rod",
		position = Vector3.new(0, 0, 0),
		luck = "+0%",
		power = "+15%",
		weight = "0.5 ~ 100kg",
	},
	["Silver Rod"] = {
		price = 2000,
		storageName = "Silver Rod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("Silver RodModel")),
		luck = "+15%",
		power = "+20%",
		weight = "0.8 ~ 110kg",
	},
	["GoldRod"] = {
		price = 6000,
		storageName = "GoldRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("GoldRodModel")),
		luck = "+30%",
		power = "+25%",
		weight = "1 ~ 120kg",
	},
	["CrystalRod"] = {
		price = 20000,
		storageName = "CrystalRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("CrystalRodModel")),
		luck = "+50%",
		power = "+30%",
		weight = "2 ~ 130kg",
	},
	["MagneticRod"] = {
		price = 50000,
		storageName = "MagneticRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("MagneticRodModel")),
		luck = "+70%",
		power = "+35%",
		weight = "2 ~ 140kg",
	},
	["BoneRod"] = {
		price = 111111,
		storageName = "BoneRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("BoneRodModel")),
		luck = "+95%",
		power = "+40%",
		weight = "3 ~ 150kg",
	},
	["CloverRod"] = {
		price = 250000,
		storageName = "CloverRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("CloverRodModel")),
		luck = "+105%",
		power = "+45%",
		weight = "5 ~ 160kg",
	},
	["RainbowRod"] = {
		price = 500000,
		storageName = "RainbowRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("RainbowRodModel")),
		luck = "+150%",
		power = "+50%",
		weight = "3 ~ 170kg",
	},
	["UnknownRod"] = {
		price = 1000000,
		storageName = "UnknownRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("UnknownRodModel")),
		luck = "+220%",
		power = "+55%",
		weight = "1 ~ 175kg",
	},
	["RobuxRod"] = {
		price = 49,
		storageName = "RobuxRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("RobuxRodModel")),
		luck = "+300%",
		power = "+60%",
		weight = "1 ~ 180kg",
	},
	["ElectricRod"] = {
		price = 2250000,
		storageName = "ElectricRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("ElectricRodModel")),
		luck = "+360%",
		power = "+65%",
		weight = "1 ~ 185kg",
	},
	["RealisticRod"] = {
		displayName = "BlockyRod",
		price = 4500000,
		storageName = "BlockyRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("BlockyRodModel")),
		luck = "+520%",
		power = "+68%",
		weight = "1 ~ 190kg",
	},
	["ArcaneRod"] = {
		price = 6500000,
		storageName = "ArcaneRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("ArcaneRodModel")),
		luck = "+650%",
		power = "+75%",
		weight = "1 ~ 195kg",
	},
	["FlameRod"] = {
		price = 20000000,
		storageName = "FlameRod",
		displayName = "Flame Rod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("FlameRodModel")),
		luck = "+800%",
		power = "+82%",
		weight = "1 ~ 198kg",
	},
	["VoidRod"] = {
		price = 33550335,
		storageName = "VoidRod",
		position = Vector3.new(0, 0, 0),
		luck = "+1000%",
		power = "+100%",
		weight = "1 ~ 200kg",
	},
	["InviteRod"] = {
		price = 0,
		storageName = "InviteRod",
		displayName = "Invite Rod",
		position = Vector3.new(0, 0, 0),
		luck = "+80%",
		power = "+38%",
		weight = "2 ~ 145kg",
	},
	["FriendRod"] = {
		price = 0,
		storageName = "FriendRod",
		displayName = "Friend Rod",
		position = Vector3.new(0, 0, 0),
		luck = "Special",
		power = "Special",
		weight = "Special",
	},
	["EquinoxRod"] = {
		price = 0,
		storageName = "EquinoxRod",
		displayName = "Equinox Rod",
		position = Vector3.new(0, 0, 0),
		luck = "+95%",
		power = "+50%",
		weight = "3 ~ 150kg",
	},
	["SilkRod"] = {
		price = 0,
		storageName = "SilkRod",
		displayName = "Silk Rod",
		position = Vector3.new(0, 0, 0),
		luck = "+520%",
		power = "+82%",
		weight = "3 ~ 300kg",
	},
}

return RodData
