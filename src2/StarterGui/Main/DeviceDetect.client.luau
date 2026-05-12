local UserInputService = game:GetService("UserInputService")

local sellButton = script.Parent:WaitForChild("Sell")
local upgradeButton = script.Parent:WaitForChild("Upgrade")
local fishingButton = script.Parent:WaitForChild("Fishing")
local freeRewardButton = script.Parent:WaitForChild("Free Reward")

if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled then
	print("Mobile device")
	sellButton.Position = UDim2.new(sellButton.Position.X.Scale, sellButton.Position.X.Offset, 0.2, sellButton.Position.Y.Offset)
	upgradeButton.Position = UDim2.new(upgradeButton.Position.X.Scale, upgradeButton.Position.X.Offset, 0.2, upgradeButton.Position.Y.Offset)
	fishingButton.Position = UDim2.new(fishingButton.Position.X.Scale, fishingButton.Position.X.Offset, 0.2, fishingButton.Position.Y.Offset)
	freeRewardButton.Position = UDim2.new(freeRewardButton.Position.X.Scale, freeRewardButton.Position.X.Offset, 0.15, freeRewardButton.Position.Y.Offset)
elseif not UserInputService.TouchEnabled and UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
	print("Computer device")
end

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
