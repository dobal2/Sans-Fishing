local TweenService = game:GetService("TweenService")
game.ReplicatedStorage.SellGuiEvent.OnClientEvent:Connect(function()
	local button = script.Parent

	-- 원래 크기 저장
	local originalSize = button.Size

	-- Play sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://6895079853"
	sound.Volume = 10
	sound.Parent = button
	sound.Looped = false
	sound:Play()

	-- Make visible
	button.Visible = true

	-- Start tiny at center
	button.Size = UDim2.new(0, 0, 0, 0)

	-- Tween to original size
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(button, tweenInfo, {Size = originalSize})
	tween:Play()
end)