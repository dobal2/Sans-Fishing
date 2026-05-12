local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:FindFirstChildOfClass("Animator")

-- Load all animations from ReplicatedStorage/Animations folder
local animationsFolder = ReplicatedStorage:WaitForChild("Animations")
for _, anim in ipairs(animationsFolder:GetChildren()) do
	if anim:IsA("Animation") then
		local track = animator:LoadAnimation(anim)
		track:Play()
		track:Stop()
	else
		warn("Not an animation:", anim.Name)
	end
end
