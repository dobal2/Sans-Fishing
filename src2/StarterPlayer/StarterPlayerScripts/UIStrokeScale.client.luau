local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Base resolution width at which UIStroke thicknesses were authored.
-- All strokes scale proportionally relative to this.
local BASE_SIZE = 1920

local initialThicknesses = {}

local function trackStroke(stroke)
	if initialThicknesses[stroke] then return end
	initialThicknesses[stroke] = stroke.Thickness
	stroke.Destroying:Once(function()
		initialThicknesses[stroke] = nil
	end)
end

local function updateStroke(stroke)
	local base = initialThicknesses[stroke]
	if not base then return end
	stroke.Thickness = base * camera.ViewportSize.X / BASE_SIZE
end

local function updateAll()
	local scale = camera.ViewportSize.X / BASE_SIZE
	for stroke, base in pairs(initialThicknesses) do
		stroke.Thickness = base * scale
	end
end

-- Initial scan
for _, obj in ipairs(playerGui:GetDescendants()) do
	if obj:IsA("UIStroke") then
		trackStroke(obj)
	end
end
updateAll()

-- Watch for new UIStrokes added at runtime
playerGui.DescendantAdded:Connect(function(obj)
	if obj:IsA("UIStroke") then
		trackStroke(obj)
		updateStroke(obj)
	end
end)

-- Re-scale on window resize
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateAll)
