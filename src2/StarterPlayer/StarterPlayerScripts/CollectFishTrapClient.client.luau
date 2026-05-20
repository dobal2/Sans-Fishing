local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Misc = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc")
local CollectFishTrapRemote = Misc:WaitForChild("CollectFishTrapRemote")

local PlayerGui = player:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("Main")
local CollectFrame = MainGui:WaitForChild("CollectFishTrap")
local Button = CollectFrame:WaitForChild("TextButton")

local FISH_TRAP_NAMES = {
	["BasicFishTrap"]    = true,
	["AdvancedFishTrap"] = true,
	["MasterFishTrap"]   = true,
	["RobuxFishTrap"]    = true,
}

local function getEquippedFishTrap()
	local char = player.Character
	if not char then return nil end
	local tool = char:FindFirstChildWhichIsA("Tool")
	if tool and FISH_TRAP_NAMES[tool.Name] then return tool end
	return nil
end

RunService.Heartbeat:Connect(function()
	CollectFrame.Visible = getEquippedFishTrap() ~= nil
end)

Button.MouseButton1Click:Connect(function()
	CollectFishTrapRemote:FireServer()
end)
