local TweenService = game:GetService("TweenService")

game.ReplicatedStorage.SellGuiEvent.OnClientEvent:Connect(function()
	local button = script.Parent  -- Your Frame or ImageButton

	-- Play sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://6895079853"
	sound.Volume = 10
	sound.Parent = button
	sound.Looped = false
	sound:Play()

	-- Make visible
	button.Visible = true

	-- OPTIONAL: Reset transparency / size before animating
	button.Size = UDim2.new(0, 0, 0, 0)  -- Start tiny at center

	-- Tween to target size (example size, adjust as needed)
	local targetSize = UDim2.new(0.274, 0, 0.043, 0)  -- Example 30% screen size
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(button, tweenInfo, {Size = targetSize})
	tween:Play()
end)
