-- RodData Module (Smart Position 처리)
local RodData = {}

-- 🔧 스마트 Position 가져오기 함수
local function getSmartPosition(object)
	if not object then
		warn("오브젝트가 존재하지 않습니다")
		return Vector3.new(0, 0, 0)
	end

	-- Part인 경우: 직접 Position 사용
	if object:IsA("BasePart") then
		--print("✅ Part 감지:", object.Name, "→ Position 직접 사용")
		return object.Position
	end

	-- Model인 경우: PrimaryPart 사용
	if object:IsA("Model") then
		--print("✅ Model 감지:", object.Name)

		-- PrimaryPart가 설정되어 있는 경우
		if object.PrimaryPart then
			--print("✅ PrimaryPart 발견:", object.PrimaryPart.Name)
			return object.PrimaryPart.Position
		end

		-- PrimaryPart가 없으면 GetBoundingBox 사용
		local success, cframe, size = pcall(function()
			return object:GetBoundingBox()
		end)
		if success then
			--print("✅ GetBoundingBox 사용")
			return cframe.Position
		end

		-- 백업: 첫 번째 Part 찾기
		for _, child in pairs(object:GetChildren()) do
			if child:IsA("BasePart") then
				--print("✅ 첫 번째 Part 사용:", child.Name)
				return child.Position
			end
		end

		warn("❌ Model에서 Position을 찾을 수 없습니다:", object.Name)
		return Vector3.new(0, 0, 0)
	end

	-- 기타 오브젝트
	warn("❌ 지원하지 않는 오브젝트 타입:", object.ClassName)
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
		price = 5000,
		storageName = "GoldRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("GoldRodModel")),
		desc = "<font color=\"#FF0000\">+17.5%</font> Rod Power\n+<font color=\"#0080FF\">5%</font> <font color=\"#0080FF\">Rare</font> chance"
	},
	["CrystalRod"] = {
		price = 15000,
		storageName = "CrystalRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("CrystalRodModel")),
		desc = "<font color=\"#FF0000\">+20%</font> Rod Power\n+<font color=\"#800080\">4%</font> <font color=\"#800080\">Epic</font> chance"
	},
	["MagneticRod"] = {
		price = 35000,
		storageName = "MagneticRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("MagneticModel")),
		desc = "<font color=\"#FF0000\">+25%</font> Rod Power\n+<font color=\"#FFA500\">0.3%</font> <font color=\"#FFA500\">Mystic</font> chance\n+<font color=\"#FF69B4\">1%</font> <font color=\"#FF69B4\">Legendary</font> chance\n+<font color=\"#800080\">2%</font> <font color=\"#800080\">Epic</font> chance"
	},
	["BoneRod"] = {
		price = 77777,
		storageName = "BoneRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("BoneRodModel")),
		desc = "<font color=\"#FF0000\">+30%</font> Rod Power\n+<font color=\"#FFA500\">0.7%</font> <font color=\"#FFA500\">Mystic</font> chance\n+<font color=\"#FF69B4\">3%</font> <font color=\"#FF69B4\">Legendary</font> chance"
	},
	["CloverRod"] = {
		price = 150000,
		storageName = "CloverRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("CloverRodModel")),
		desc = "<font color=\"#FF0000\">+37.5%</font> Rod Power\n+<font color=\"#87CEEB\">0.2%</font> <font color=\"#87CEEB\">Fantasy</font> chance\n+<font color=\"#FFA500\">1%</font> <font color=\"#FFA500\">Mystic</font> chance\n+<font color=\"#FF69B4\">2%</font> <font color=\"#FF69B4\">Legendary</font> chance"
	},
	["RainbowRod"] = {
		price = 400000,
		storageName = "RainbowRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("RainbowRodModel")),
		desc = "<font color=\"#FF0000\">+45%</font> Rod Power\n+<font color=\"#87CEEB\">0.4%</font> <font color=\"#87CEEB\">Fantasy</font> chance\n+<font color=\"#FFA500\">2.5%</font> <font color=\"#FFA500\">Mystic</font> chance\n+<font color=\"#FF69B4\">3%</font> <font color=\"#FF69B4\">Legendary</font> chance"
	},
	["UnknownRod"] = {
		price = 800000,
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
		price = 1500000,
		storageName = "ElectricRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("ElectricRodModel")),
		desc = "<font color=\"#FF0000\">+65%</font> Rod Power\n+<font color=\"#800080\">0.25%</font> <font color=\"#800080\">Unknown</font> chance\n+<font color=\"#87CEEB\">0.8%</font> <font color=\"#87CEEB\">Fantasy</font> chance\n+<font color=\"#FFA500\">4%</font> <font color=\"#FFA500\">Mystic</font> chance"
	},
	["RealisticRod"] = {
		price = 3000000,
		storageName = "RealisticRod",
		position = getSmartPosition(workspace:WaitForChild("Upgrade Shop"):WaitForChild("RealisticRodModel")),
		desc = "<font color=\"#FF0000\">+80%</font> Rod Power\n+<font color=\"#800080\">0.5%</font> <font color=\"#800080\">Unknown</font> chance\n+<font color=\"#87CEEB\">1.3%</font> <font color=\"#87CEEB\">Fantasy</font> chance\n+<font color=\"#FFA500\">5%</font> <font color=\"#FFA500\">Mystic</font> chance"
	},
	["ArcaneRod"] = {
		price = 5000000,
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

-- 🔧 더 간단한 한 줄 버전 (확실할 때):
--[[
position = workspace["Upgrade Shop"]["RealisticRodModel"]:IsA("Model") and
          workspace["Upgrade Shop"]["RealisticRodModel"].PrimaryPart.Position or
          workspace["Upgrade Shop"]["RealisticRodModel"].Position
--]]
