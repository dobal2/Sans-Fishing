-- VoidQuestGuiOpener.lua (LocalScript in StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- 보이드 퀘스트 이벤트들로 변경
local voidQuestEvents = ReplicatedStorage:WaitForChild("VoidQuestEvents")
local voidQuestGuiEvent = voidQuestEvents:WaitForChild("VoidQuestGuiEvent")

voidQuestGuiEvent.OnClientEvent:Connect(function()
	-- 보이드 퀘스트 전용 GUI 사용 (기존 QuestOptions 복사해서 VoidQuestOptions로 이름 변경)
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("VoidQuestOptions")
	gui.Enabled = true

	local finalSize = UDim2.new(0.5, 0, 0.5, 0)
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	for _, obj in ipairs(gui:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			obj.TextTransparency = 1
			local textTween = TweenService:Create(obj, tweenInfo, { TextTransparency = 0 })
			textTween:Play()
		elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
			obj.ImageTransparency = 1
			local imageTween = TweenService:Create(obj, tweenInfo, { ImageTransparency = 0 })
			imageTween:Play()
		end
	end
end)
