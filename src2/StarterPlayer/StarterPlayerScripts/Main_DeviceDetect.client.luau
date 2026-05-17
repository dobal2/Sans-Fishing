local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local mainGui = player.PlayerGui:WaitForChild("Main")

local sellButton = mainGui:WaitForChild("Sell")
local upgradeButton = mainGui:WaitForChild("Upgrade")
local fishingButton = mainGui:WaitForChild("Fishing")
local freeRewardButton = mainGui:WaitForChild("Free Reward")

if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled then
	print("Mobile device")
elseif not UserInputService.TouchEnabled and UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
	print("Computer device")
end
