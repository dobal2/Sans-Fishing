repeat wait() until game:IsLoaded()

local spawnLocation = workspace:WaitForChild("SpawnLocation")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Settings
local fallThresholdY = -500
local maxDistance = 6000

local function monitorFall(character)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then return end

	RunService.RenderStepped:Connect(function()
		if not root or not root.Parent then return end

		local distance = (root.Position - spawnLocation.Position).Magnitude

		if root.Position.Y < fallThresholdY or distance > maxDistance then
			-- Teleport back + reset velocity
			root.CFrame = spawnLocation.CFrame
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

-- Start monitoring immediately if character exists
if player.Character then
	monitorFall(player.Character)
end

-- Also monitor when character respawns
player.CharacterAdded:Connect(monitorFall)
