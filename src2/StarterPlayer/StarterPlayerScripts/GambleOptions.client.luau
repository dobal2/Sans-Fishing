local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gambleChoiceEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("GambleChoiceEvent")

local player = game.Players.LocalPlayer
local gui = player.PlayerGui:WaitForChild("GambleOptions")
local buttons = {
	Option1 = gui:WaitForChild("Option1"):WaitForChild("TextButton"),
	Option2 = gui:WaitForChild("Option2"):WaitForChild("TextButton"),
}

for name, button in pairs(buttons) do
	button.MouseButton1Click:Connect(function()
		gambleChoiceEvent:FireServer(name)
		gui.Enabled = false
	end)
end
