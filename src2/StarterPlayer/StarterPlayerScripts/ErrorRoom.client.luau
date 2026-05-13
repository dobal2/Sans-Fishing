local RunService = game:GetService("RunService")
local lighting = game:GetService("Lighting")
local Camera = workspace:WaitForChild("Camera")
local Water = workspace:FindFirstChild("ErrorRoomlightPart")
if not Water then return end

local bloom = lighting:WaitForChild("ErrorRoomBloom")
local blur = lighting:WaitForChild("ErrorRoomBlur")
-- ColorCorrectionEffect lives directly in Lighting (named ErrorRoomColor)
local colorCorrection = lighting:WaitForChild("ErrorRoomColor")

local isUnderWater = false

local function enableUnderwaterEffects()
	bloom.Enabled = true
	blur.Enabled = true
	colorCorrection.Enabled = true
end

local function disableUnderwaterEffects()
	bloom.Enabled = false
	blur.Enabled = false
	colorCorrection.Enabled = false
end

RunService.Stepped:Connect(function()
	-- Check if Camera is inside Water
	local localPos = Water.CFrame:PointToObjectSpace(Camera.CFrame.Position)
	local inWater =
		math.abs(localPos.X) <= Water.Size.X / 2 and
		math.abs(localPos.Y) <= Water.Size.Y / 2 and
		math.abs(localPos.Z) <= Water.Size.Z / 2

	-- Only process on state change (immediate response)
	if inWater and not isUnderWater then
		-- Entered water
		isUnderWater = true
		enableUnderwaterEffects()

	elseif not inWater and isUnderWater then
		-- Exited water
		isUnderWater = false
		disableUnderwaterEffects()
	end
end)
