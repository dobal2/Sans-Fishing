local Info = script.Parent:WaitForChild("Frame")
local image = script.Parent

image.MouseEnter:Connect(function()
	Info.Visible = true
end)

image.MouseLeave:Connect(function()
	Info.Visible = false
end)

--image.TouchTap:Connect(function()
--	Info.Visible = not Info.Visible
--end)

image.TouchLongPress:Connect(function()
	Info.Visible = true
end)
local UserInputService = game:GetService("UserInputService")
UserInputService.TouchEnded:Connect(function()
	Info.Visible = false
end)
