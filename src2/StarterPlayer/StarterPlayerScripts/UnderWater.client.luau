local RunService = game:GetService("RunService")
local lighting = game:GetService("Lighting")

local Camera = workspace:WaitForChild("Camera")
local Water = workspace:WaitForChild("Map"):WaitForChild("Water")
local UnderWaterBlur = lighting:WaitForChild("UnderWaterBlur")
local UnderWaterColor = lighting:WaitForChild("UnderWaterColor")

local replicatedStorage = game:GetService("ReplicatedStorage")

local rain = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("Rain"))


RunService.Stepped:Connect(function()
	local CameraV3 = Water.CFrame:PointToObjectSpace(Camera.CFrame.Position)
	local CameraUnderWater =
		math.abs(CameraV3.X) <= Water.Size.X / 2 and
		math.abs(CameraV3.Y) <= Water.Size.Y / 2 and
		math.abs(CameraV3.Z) <= Water.Size.Z / 2

	UnderWaterBlur.Enabled = CameraUnderWater
	UnderWaterColor.Enabled = CameraUnderWater
	if CameraUnderWater then
		rain:SetIntensityRatio(0)
	else
		rain:SetIntensityRatio(1)
	end
end)
