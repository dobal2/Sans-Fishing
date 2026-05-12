local btn = script.Parent

local isHovering = false
local UIS = game:GetService('UserInputService')
local enable = true

btn.MouseEnter:Connect(function()

	isHovering = true

	btn:TweenSize(UDim2.new(0.12, 0,0.6, 0), Enum.EasingDirection.InOut, Enum.EasingStyle.Quint, 0.2, true)
end)

btn.MouseLeave:Connect(function()

	isHovering = false

	btn:TweenSize(UDim2.new(0.102, 0,0.495, 0), Enum.EasingDirection.InOut, Enum.EasingStyle.Quint, 0.2, true)
end)

btn.MouseButton1Down:Connect(function()
	if enable then
		enable = false
		btn:TweenSize(UDim2.new(0.09, 0,0.4, 0), Enum.EasingDirection.InOut, Enum.EasingStyle.Quint, 0.2, true)
		script:WaitForChild("click"):Play()
		wait(0.5)
		enable = true
	end



end)

btn.MouseButton1Up:Connect(function()

	if not isHovering then
		btn:TweenSize(UDim2.new(0.102, 0,0.495, 0), Enum.EasingDirection.InOut, Enum.EasingStyle.Quint, 0.2, true)
	else
		btn:TweenSize(UDim2.new(0.12, 0,0.6, 0), Enum.EasingDirection.InOut, Enum.EasingStyle.Quint, 0.2, true)
	end
end)