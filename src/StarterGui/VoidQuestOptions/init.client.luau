-- VoidQuestButtons.lua (LocalScript, 보이드 퀘스트 GUI 안에 넣기)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 보이드 퀘스트 이벤트들로 변경
local voidQuestEvents = ReplicatedStorage:WaitForChild("VoidQuestEvents")
local voidQuestChoiceEvent = voidQuestEvents:WaitForChild("VoidQuestChoiceEvent")

local gui = script.Parent
local buttons = {
	Option1 = gui:WaitForChild("Option1"):WaitForChild("TextButton"),
	Option2 = gui:WaitForChild("Option2"):WaitForChild("TextButton"),
}

for name, button in pairs(buttons) do
	button.MouseButton1Click:Connect(function()
		-- 보이드 퀘스트 이벤트로 전송
		voidQuestChoiceEvent:FireServer(name)
		gui.Enabled = false
	end)
end
