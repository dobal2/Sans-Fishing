local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local lighting = game:GetService("Lighting")

local Camera = workspace:WaitForChild("Camera")
local Water = workspace:WaitForChild("SnowIslandPart")
local atmosphere = lighting:WaitForChild("Atmosphere")

-- 원래 값 저장
local originalGlare = atmosphere.Glare
local originalHaze = atmosphere.Haze

-- 목표 값
local targetGlare = 0.3
local targetHaze = 7


-- 현재 상태 추적
local isUnderWater = false

-- Tween 생성 함수
local function tweenAtmosphere(glareValue, hazeValue, duration)
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local goals = {Glare = glareValue, Haze = hazeValue}
	local tween = TweenService:Create(atmosphere, tweenInfo, goals)
	tween:Play()
end

RunService.Stepped:Connect(function()
	-- Camera가 Water 안에 있는지 확인
	local localPos = Water.CFrame:PointToObjectSpace(Camera.CFrame.Position)
	local inWater =
		math.abs(localPos.X) <= Water.Size.X / 2 and
		math.abs(localPos.Y) <= Water.Size.Y / 2 and
		math.abs(localPos.Z) <= Water.Size.Z / 2

	if inWater and not isUnderWater then
		isUnderWater = true
		tweenAtmosphere(targetGlare, targetHaze, 1) -- 1초 동안 서서히 변경
	elseif not inWater and isUnderWater then
		isUnderWater = false
		tweenAtmosphere(originalGlare, originalHaze, 1) -- 1초 동안 원래 값으로 복원
	end
end)
