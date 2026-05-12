-- Beam manager LocalScript (place in StarterGui)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ShowBeamEvent = ReplicatedStorage:WaitForChild("ShowBeamEvent")
local tutorialBeam = ReplicatedStorage:WaitForChild("TutorialBeam")

-- Beam management variables
local currentBeam = nil
local playerAttachment = nil
local targetAttachment = nil

-- Beam creation function
local function createBeam(targetTrap)
	-- Check if the tool is equipped
	local character = player.Character
	if not character then
		warn("No character - beam creation failed")
		return
	end

	-- Check if tool is equipped
	local isToolEquipped = false
	for _, tool in pairs(character:GetChildren()) do
		if tool:IsA("Tool") and (tool.Name == "BasicFishTrap" or tool.Name == "AdvancedFishTrap" or
			tool.Name == "MasterFishTrap" or tool.Name == "RobuxFishTrap") then
			isToolEquipped = true
			break
		end
	end

	-- Do not create beam if tool is not equipped
	if not isToolEquipped then
		return
	end

	-- Remove existing beam
	if currentBeam then
		currentBeam:Destroy()
		currentBeam = nil
	end
	if playerAttachment then
		playerAttachment:Destroy()
		playerAttachment = nil
	end
	if targetAttachment then
		targetAttachment:Destroy()
		targetAttachment = nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		warn("HumanoidRootPart not found - beam creation failed")
		return
	end

	-- Create player attachment
	playerAttachment = Instance.new("Attachment")
	playerAttachment.Name = "TutorialPlayerAttachment"
	playerAttachment.Parent = rootPart

	-- Create target attachment
	local targetPart = targetTrap.PrimaryPart or targetTrap:FindFirstChildWhichIsA("BasePart")
	if not targetPart then
		warn("Target part not found - beam creation failed")
		playerAttachment:Destroy()
		playerAttachment = nil
		return
	end

	targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "TutorialTargetAttachment"
	targetAttachment.Parent = targetPart

	-- Create beam
	currentBeam = tutorialBeam:Clone()
	currentBeam.Name = "TutorialBeamClone"
	currentBeam.Attachment0 = targetAttachment
	currentBeam.Attachment1 = playerAttachment
	currentBeam.Parent = rootPart
end

-- Beam removal function
local function removeBeam()
	if currentBeam then
		currentBeam:Destroy()
		currentBeam = nil
	end
	if playerAttachment then
		playerAttachment:Destroy()
		playerAttachment = nil
	end
	if targetAttachment then
		targetAttachment:Destroy()
		targetAttachment = nil
	end
end

-- Handle show/hide beam requests from server
ShowBeamEvent.OnClientEvent:Connect(function(action, targetTrap)
	if action == "show" and targetTrap then
		createBeam(targetTrap)
	elseif action == "hide" then
		removeBeam()
	end
end)

-- Clean up beam on character respawn
player.CharacterAdded:Connect(function(character)
	removeBeam()
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		removeBeam()
	end
end)
