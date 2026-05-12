local UserInputService = game:GetService("UserInputService")
local Info = script.Parent:WaitForChild("Frame")
local image = script.Parent

image.MouseEnter:Connect(function() Info.Visible = true end)
image.MouseLeave:Connect(function() Info.Visible = false end)
image.TouchLongPress:Connect(function() Info.Visible = true end)

UserInputService.TouchEnded:Connect(function()
	Info.Visible = false
end)
