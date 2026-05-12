local ReplicatedStorage = game:GetService("ReplicatedStorage")

local voidQuestEvents = ReplicatedStorage:WaitForChild("VoidQuestEvents")
local voidQuestChoiceEvent = voidQuestEvents:WaitForChild("VoidQuestChoiceEvent")

local gui = script.Parent
local buttons = {
	Option1 = gui:WaitForChild("Option1"):WaitForChild("TextButton"),
	Option2 = gui:WaitForChild("Option2"):WaitForChild("TextButton"),
}

for name, button in pairs(buttons) do
	button.MouseButton1Click:Connect(function()
		voidQuestChoiceEvent:FireServer(name)
		gui.Enabled = false
	end)
end
