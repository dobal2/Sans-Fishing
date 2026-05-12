local RunService = game:GetService("RunService")
local lighting = game:GetService("Lighting")
local Camera = workspace:WaitForChild("Camera")
local Water = workspace:WaitForChild("ErrorRoomlightPart")

-- Lighting effects
local atmosphere = nil  -- Created only when inside water
local bloom = lighting:WaitForChild("ErrorRoomBloom")
local blur = lighting:WaitForChild("ErrorRoomBlur")

-- ColorCorrection inside script
local colorcollection = script:WaitForChild("ErrorRoomBloomAtmosphere")

-- Track current state
local isUnderWater = false

-- ColorCorrection to be copied into Lighting
local lightingColorCollection = nil

-- Enable underwater effects
local function enableUnderwaterEffects()
	-- Clone if atmosphere doesn't exist
	if not atmosphere then
		atmosphere = colorcollection:Clone()
		atmosphere.Name = "ErrorRoomBloomAtmosphere"
		atmosphere.Parent = lighting
	end

	-- Enable effects (Atmosphere auto-applies when present)
	bloom.Enabled = true
	blur.Enabled = true
end

-- Disable underwater effects
local function disableUnderwaterEffects()
	-- Destroy atmosphere instead of disabling
	if atmosphere then
		atmosphere:Destroy()
		atmosphere = nil
	end

	-- Disable other effects
	bloom.Enabled = false
	blur.Enabled = false
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
