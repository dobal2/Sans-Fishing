local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sellChoiceEvent = ReplicatedStorage:WaitForChild("GambleChoiceEvent")

local gui = script.Parent
local buttons = {
	Option1 = gui:WaitForChild("Option1"):WaitForChild("TextButton"),
	Option2 = gui:WaitForChild("Option2"):WaitForChild("TextButton"),
}

for name, button in pairs(buttons) do
	button.MouseButton1Click:Connect(function()
		sellChoiceEvent:FireServer(name)
		gui.Enabled = false
	end)
end