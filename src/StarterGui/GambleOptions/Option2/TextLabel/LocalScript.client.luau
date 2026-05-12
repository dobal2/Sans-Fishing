local TweenService = game:GetService("TweenService")
local soundId = 6895079853  -- Sound ID

local textLabel = script.Parent  -- Assuming this script is a child of the TextLabel

-- 기준 위치를 저장
local originalPosition = textLabel.Position

-- Create a sound instance
local sound = Instance.new("Sound")
sound.SoundId = "rbxassetid://" .. soundId
sound.Parent = textLabel
sound.Volume = 10

-- Tween info
local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- 마우스 오버 시: 오른쪽으로 이동
textLabel.MouseEnter:Connect(function()
	sound:Play()

	local goal = {Position = originalPosition + UDim2.new(0, 10, 0, 0)}
	local moveTween = TweenService:Create(textLabel, tweenInfo, goal)
	moveTween:Play()
end)

-- 마우스 나감 시: 원래 위치로 복귀
textLabel.MouseLeave:Connect(function()
	local resetTween = TweenService:Create(textLabel, tweenInfo, {Position = originalPosition})
	resetTween:Play()
end)