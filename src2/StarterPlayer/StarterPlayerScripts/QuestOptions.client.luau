local ReplicatedStorage = game:GetService("ReplicatedStorage")
local questEvents = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Quest")
local questChoiceEvent = questEvents:WaitForChild("QuestChoiceEvent")

local player = game.Players.LocalPlayer
local gui = player.PlayerGui:WaitForChild("QuestOptions")
local buttons = {
	Option1 = gui:WaitForChild("Option1"):WaitForChild("TextButton"),
	Option2 = gui:WaitForChild("Option2"):WaitForChild("TextButton"),
}
for name, button in pairs(buttons) do
	button.MouseButton1Click:Connect(function()
		questChoiceEvent:FireServer(name)
		gui.Enabled = false
	end)
end
