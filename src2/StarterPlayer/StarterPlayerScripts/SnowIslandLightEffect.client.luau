local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local lighting = game:GetService("Lighting")

local Camera = workspace:WaitForChild("Camera")
local Water = workspace:WaitForChild("SnowIslandPart")
local atmosphere = lighting:WaitForChild("Atmosphere")

-- Save original values
local originalGlare = atmosphere.Glare
local originalHaze = atmosphere.Haze

-- Target values
local targetGlare = 0.3
local targetHaze = 7


-- Track current state
local isUnderWater = false

-- Tween creation function
local function tweenAtmosphere(glareValue, hazeValue, duration)
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local goals = {Glare = glareValue, Haze = hazeValue}
	local tween = TweenService:Create(atmosphere, tweenInfo, goals)
	tween:Play()
end

RunService.Stepped:Connect(function()
	-- Check if Camera is inside the snow island area
	local localPos = Water.CFrame:PointToObjectSpace(Camera.CFrame.Position)
	local inWater =
		math.abs(localPos.X) <= Water.Size.X / 2 and
		math.abs(localPos.Y) <= Water.Size.Y / 2 and
		math.abs(localPos.Z) <= Water.Size.Z / 2

	if inWater and not isUnderWater then
		isUnderWater = true
		tweenAtmosphere(targetGlare, targetHaze, 1) -- Gradually change over 1 second
	elseif not inWater and isUnderWater then
		isUnderWater = false
		tweenAtmosphere(originalGlare, originalHaze, 1) -- Restore original values over 1 second
	end
end)
