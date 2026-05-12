-- Must run as a LocalScript (place in StarterPlayerScripts or StarterGui)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Require DistanceFade module (assumed to be in ReplicatedStorage)
local DistanceFade = require(game.ReplicatedStorage.DistanceFade) -- Adjust path as needed

-- Create DistanceFade instance
local distanceFade = DistanceFade.new()

-- Animation variables
local animationSpeed = 3 -- Movement speed (higher = faster)
local startTime = tick() -- Start time

-- Custom settings (optional)
local baseSettings = {
	["DistanceOuter"] = 30,     -- Distance at which effect starts
	["DistanceInner"] = 10,      -- Distance at which effect is fully visible
	["EffectRadius"] = 30,      -- Effect size
	["Texture"] = "rbxassetid://18838056070", -- Texture ID
	["TextureTransparency"] = 0.2,
	["TextureColor"] = Color3.fromRGB(255, 100, 100), -- Red tone
	["TextureSize"] = Vector2.new(8, 8), -- Texture size
}

-- Diagonal scroll animation function
local function getDiagonalOffset(time)
	-- Diagonal scroll upward-right
	local progress = time * animationSpeed
	local offsetX = progress % 16 -- Repeat every 16 studs
	local offsetY = progress % 16 -- Same speed upward
	return Vector2.new(offsetX, offsetY)
end

-- Apply settings
distanceFade:UpdateSettings(baseSettings)

-- Apply effect to all parts in Wall folder
local function applyEffectToWallParts()
	local wallFolder = workspace:FindFirstChild("Wall")

	if not wallFolder then
		warn("Wall folder not found!")
		return
	end

	-- Apply effect to all BaseParts in Wall folder
	for _, child in pairs(wallFolder:GetChildren()) do
		if child:IsA("BasePart") then
			distanceFade:AddFace(child, Enum.NormalId.Front)
			distanceFade:AddFace(child, Enum.NormalId.Back)
			distanceFade:AddFace(child, Enum.NormalId.Left)
			distanceFade:AddFace(child, Enum.NormalId.Right)
			distanceFade:AddFace(child, Enum.NormalId.Top)
			distanceFade:AddFace(child, Enum.NormalId.Bottom)
		end
	end

	-- Automatically apply effect to newly added parts
	wallFolder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			wait() -- Wait for part to fully load
			distanceFade:AddFace(child, Enum.NormalId.Front)
			distanceFade:AddFace(child, Enum.NormalId.Back)
			distanceFade:AddFace(child, Enum.NormalId.Left)
			distanceFade:AddFace(child, Enum.NormalId.Right)
			distanceFade:AddFace(child, Enum.NormalId.Top)
			distanceFade:AddFace(child, Enum.NormalId.Bottom)
		end
	end)

	-- Remove effect when part is removed
	wallFolder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			for _, normalId in pairs(Enum.NormalId:GetEnumItems()) do
				distanceFade:RemoveFace(child, normalId)
			end
		end
	end)
end

-- Update texture offset animation
local function updateTextureAnimation()
	local currentTime = tick() - startTime
	local newOffset = getDiagonalOffset(currentTime)

	local animatedSettings = {}
	for key, value in pairs(baseSettings) do
		animatedSettings[key] = value
	end
	animatedSettings["TextureOffset"] = newOffset

	distanceFade:UpdateSettings(animatedSettings)
end

-- Change animation speed
local function changeAnimationSpeed(newSpeed)
	animationSpeed = math.max(0.1, newSpeed) -- Minimum speed limit
end

-- Expose as global for console access
_G.changeAnimationSpeed = changeAnimationSpeed

-- Wait until player spawns
local player = Players.LocalPlayer
if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
	applyEffectToWallParts()
else
	player.CharacterAdded:Connect(function()
		applyEffectToWallParts()
	end)
end

-- Update every frame
RunService.Heartbeat:Connect(function()
	-- Update texture animation
	updateTextureAnimation()

	-- Update effect
	distanceFade:Step() -- Uses player position automatically
end)
