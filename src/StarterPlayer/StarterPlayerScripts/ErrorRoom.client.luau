local RunService = game:GetService("RunService")
local lighting = game:GetService("Lighting")
local Camera = workspace:WaitForChild("Camera")
local Water = workspace:WaitForChild("ErrorRoomlightPart")

-- Lighting 효과들
local atmosphere = nil  -- 물 안에서만 생성
local bloom = lighting:WaitForChild("ErrorRoomBloom")
local blur = lighting:WaitForChild("ErrorRoomBlur")

-- Script 안의 ColorCorrection
local colorcollection = script:WaitForChild("ErrorRoomBloomAtmosphere")

-- 현재 상태 추적
local isUnderWater = false

-- Lighting에 복사될 ColorCorrection
local lightingColorCollection = nil

-- 수중 효과 활성화
local function enableUnderwaterEffects()
	-- Atmosphere가 없으면 복사
	if not atmosphere then
		atmosphere = colorcollection:Clone()
		atmosphere.Name = "ErrorRoomBloomAtmosphere"
		atmosphere.Parent = lighting
		print("🌊 Atmosphere 복사됨")
	end

	-- 효과 활성화 (Atmosphere는 존재하면 자동 적용)
	bloom.Enabled = true
	blur.Enabled = true

	print("🌊 수중 효과 활성화")
end

-- 수중 효과 비활성화
local function disableUnderwaterEffects()
	-- Atmosphere 제거 (비활성화 대신)
	if atmosphere then
		atmosphere:Destroy()
		atmosphere = nil
		print("🌊 Atmosphere 제거됨")
	end

	-- 다른 효과들 비활성화
	bloom.Enabled = false
	blur.Enabled = false

	print("🏖️ 수중 효과 비활성화")
end

RunService.Stepped:Connect(function()
	-- Camera가 Water 안에 있는지 확인
	local localPos = Water.CFrame:PointToObjectSpace(Camera.CFrame.Position)
	local inWater =
		math.abs(localPos.X) <= Water.Size.X / 2 and
		math.abs(localPos.Y) <= Water.Size.Y / 2 and
		math.abs(localPos.Z) <= Water.Size.Z / 2

	-- 상태 변화가 있을 때만 처리 (즉시 반응)
	if inWater and not isUnderWater then
		-- 물 속으로 들어감
		isUnderWater = true
		enableUnderwaterEffects()

	elseif not inWater and isUnderWater then
		-- 물 밖으로 나감
		isUnderWater = false
		disableUnderwaterEffects()
	end
end)
