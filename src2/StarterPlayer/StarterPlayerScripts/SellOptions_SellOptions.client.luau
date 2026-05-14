local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sellChoiceEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SellChoiceEvent")

local player = game.Players.LocalPlayer
local gui = player.PlayerGui:WaitForChild("SellOptions")
local buttons = {
	Option1 = gui:WaitForChild("Option1"):WaitForChild("TextButton"),
	Option2 = gui:WaitForChild("Option2"):WaitForChild("TextButton"),
	Option3 = gui:WaitForChild("Option3"):WaitForChild("TextButton"),
	Option4 = gui:WaitForChild("Option4"):WaitForChild("TextButton")
}

for name, button in pairs(buttons) do
	button.MouseButton1Click:Connect(function()
		sellChoiceEvent:FireServer(name)
		gui.Enabled = false
	end)
end
