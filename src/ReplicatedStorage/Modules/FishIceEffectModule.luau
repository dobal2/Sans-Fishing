-- FishIceEffectModule.lua
-- 눈 날씨 시 물고기에 간단한 얼음 블록 추가하는 모듈

local FishIceEffect = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 🧊 얼음 효과 설정 (간단하게)
local ICE_SETTINGS = {
	material = Enum.Material.Plastic,
	transparency = 0.3,
	color = Color3.fromRGB(200, 240, 255),
	size_multiplier = 1,
	glow_intensity = 0.5    -- 적당한 빛
}

-- 🧊 FishIceEffectModule.lua의 createIceBlock 함수 교체
local function createIceBlock(fishModel, fishInfo)
	if not fishModel then
		warn("❌ 물고기 모델이 없습니다")
		return nil
	end

	local targetPart = fishModel.PrimaryPart or fishModel:FindFirstChild("Handle")
	if not targetPart then
		warn("❌ 물고기 모델에 PrimaryPart 또는 Handle이 없습니다:", fishModel.Name)
		return nil
	end

	-- 🆕 무게에 따른 크기 배율 계산
	local fishWeight = fishInfo and fishInfo.weight
	local sizeMultiplier = ICE_SETTINGS.size_multiplier or 1.15

	if fishWeight then
		-- 무게 1kg당 2% 증가
		local weightMultiplier = 1.0 + (fishWeight - 1) * 0.02
		weightMultiplier = math.max(0.8, math.min(2.5, weightMultiplier))
		sizeMultiplier = sizeMultiplier * weightMultiplier

		--print("⚖️ 무게:", fishWeight .. "kg → 최종 크기 배율:", sizeMultiplier)
	end

	--print("🎯 대상 파트:", targetPart.Name, "기본 크기:", targetPart.Size)

	local iceBlock = Instance.new("Part")
	iceBlock.Name = "IceBlock"
	iceBlock.Anchored = false
	iceBlock.CanCollide = false
	iceBlock.Massless = true

	-- 🆕 무게 기반 크기 적용
	iceBlock.Size = targetPart.Size * sizeMultiplier
	iceBlock.CFrame = targetPart.CFrame

	-- 모양 강제 고정 (Block)
	iceBlock.Shape = Enum.PartType.Block
	for _, obj in pairs(iceBlock:GetChildren()) do
		if obj:IsA("SpecialMesh") or obj:IsA("Mesh") then
			obj:Destroy()
		end
	end

	-- 재질 및 외형 설정
	iceBlock.Material = ICE_SETTINGS.material or Enum.Material.Plastic
	iceBlock.Transparency = ICE_SETTINGS.transparency
	iceBlock.Color = ICE_SETTINGS.color

	-- 같은 부모 밑으로 두기
	iceBlock.Parent = targetPart.Parent

	-- WeldConstraint로 고정
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = targetPart
	weld.Part1 = iceBlock
	weld.Parent = iceBlock

	--print("🧊 무게 기반 얼음 블록 생성 완료:", iceBlock.Name, "최종 크기:", iceBlock.Size)
	return iceBlock
end

-- 🧊 FishIceEffectModule.lua의 ApplyIceEffect 함수 교체
function FishIceEffect.ApplyIceEffect(fishModel, fishInfo)
	if not fishModel then
		warn("❌ 물고기 모델이 없습니다")
		return false
	end

	-- 이미 얼음 효과가 있는지 확인
	if fishModel:FindFirstChild("IceBlock") then
		print("⚠️ 이미 얼음 효과가 적용되어 있습니다:", fishModel.Name)
		return false
	end

	-- Frozen 접두사가 있는지 확인
	if not fishInfo or not fishInfo.fishName or not string.find(fishInfo.fishName, "Frozen") then
		--print("❌ Frozen 접두사가 없는 물고기:", fishInfo and fishInfo.fishName or "Unknown")
		return false
	end

	--print("🧊 얼음 효과 적용 시작:", fishInfo.fishName)
	if fishInfo.weight then
		print("⚖️ 물고기 무게:", fishInfo.weight .. "kg")
	end

	-- 🆕 fishInfo에 무게 정보 포함해서 얼음 블록 생성
	local iceBlock = createIceBlock(fishModel, fishInfo)
	if not iceBlock then
		warn("❌ 얼음 블록 생성 실패")
		return false
	end

	-- 물고기 모델에 얼음 태그 추가
	fishModel:SetAttribute("HasIceEffect", true)
	fishModel:SetAttribute("IceAppliedTime", tick())

	--print("✅ 얼음 효과 적용 완료:", fishInfo.fishName)
	return true
end

-- 🔥 얼음 효과 제거 (간단하게)
function FishIceEffect.RemoveIceEffect(fishModel)
	if not fishModel then
		warn("❌ 물고기 모델이 없습니다")
		return false
	end

	local iceBlock = fishModel:FindFirstChild("IceBlock")
	if not iceBlock then
		print("⚠️ 제거할 얼음 효과가 없습니다:", fishModel.Name)
		return false
	end

	print("🔥 얼음 효과 제거 시작:", fishModel.Name)

	-- 얼음 블록만 제거
	iceBlock:Destroy()

	-- 태그 제거
	fishModel:SetAttribute("HasIceEffect", nil)
	fishModel:SetAttribute("IceAppliedTime", nil)

	print("✅ 얼음 효과 제거 완료:", fishModel.Name)
	return true
end

-- 🌡️ 모든 얼음 효과 제거 (날씨 변경 시)
function FishIceEffect.RemoveAllIceEffects()
	local workspace = game:GetService("Workspace")
	local removedCount = 0

	-- 모든 물고기 모델에서 얼음 효과 찾기
	local function searchForIceEffects(parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:GetAttribute("HasIceEffect") then
				FishIceEffect.RemoveIceEffect(child)
				removedCount = removedCount + 1
			end

			-- 재귀적으로 하위 오브젝트 검사
			if #child:GetChildren() > 0 then
				searchForIceEffects(child)
			end
		end
	end

	searchForIceEffects(workspace)

	print("🌡️ 모든 얼음 효과 제거 완료. 제거된 개수:", removedCount)
	return removedCount
end

-- 🔍 얼음 효과 상태 확인
function FishIceEffect.HasIceEffect(fishModel)
	if not fishModel then return false end
	return fishModel:GetAttribute("HasIceEffect") == true
end

-- 🧊 물고기 생성 시 자동 얼음 효과 적용 (FishingSystem에서 호출)
function FishIceEffect.CheckAndApplyIceEffect(fishModel, fishInfo)
	if not fishModel or not fishInfo then
		return false
	end

	-- 현재 날씨 확인
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	if not modules then
		warn("❌ Modules 폴더를 찾을 수 없습니다")
		return false
	end

	local weatherModule = modules:FindFirstChild("WeatherSystemModule")
	if not weatherModule then
		warn("❌ WeatherSystemModule을 찾을 수 없습니다")
		return false
	end

	local success, WeatherSystem = pcall(function()
		return require(weatherModule)
	end)

	if not success then
		warn("❌ WeatherSystem 로드 실패:", WeatherSystem)
		return false
	end

	local weatherInfo = WeatherSystem.GetCurrentWeatherInfo()

	-- 눈 날씨이고 Frozen 접두사가 있는 경우에만 적용
	if weatherInfo and weatherInfo.isActive and weatherInfo.currentWeather == "Snow" then
		if fishInfo.fishName and string.find(fishInfo.fishName, "Frozen") then
			return FishIceEffect.ApplyIceEffect(fishModel, fishInfo)
		end
	end

	return false
end

-- 🔄 설정 업데이트 함수
function FishIceEffect.UpdateSettings(newSettings)
	if newSettings.material then ICE_SETTINGS.material = newSettings.material end
	if newSettings.transparency then ICE_SETTINGS.transparency = newSettings.transparency end
	if newSettings.color then ICE_SETTINGS.color = newSettings.color end
	if newSettings.size_multiplier then ICE_SETTINGS.size_multiplier = newSettings.size_multiplier end
	if newSettings.glow_intensity then ICE_SETTINGS.glow_intensity = newSettings.glow_intensity end

	print("🔄 얼음 효과 설정 업데이트 완료")
end

-- 🧪 테스트 함수
function FishIceEffect.TestIceEffect(fishModel)
	if not fishModel then
		warn("❌ 테스트할 물고기 모델이 없습니다")
		return false
	end

	local testFishInfo = {
		fishName = "Frozen Test Fish",
		currentWeather = "Snow"
	}

	return FishIceEffect.ApplyIceEffect(fishModel, testFishInfo)
end

-- 🧪 현재 워크스페이스의 모든 물고기에 강제 얼음 효과 (테스트용)
function FishIceEffect.ForceIceEffectOnAll()
	local workspace = game:GetService("Workspace")
	local appliedCount = 0

	local function searchAndApplyIce(parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:IsA("Model") and child.Name and not FishIceEffect.HasIceEffect(child) then
				-- 모든 물고기에 강제로 Frozen 접두사 추가해서 테스트
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

	print("🧪 강제 얼음 효과 적용 완료. 적용된 개수:", appliedCount)
	return appliedCount
end

-- 📊 얼음 효과 통계
function FishIceEffect.GetIceEffectStats()
	local workspace = game:GetService("Workspace")
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