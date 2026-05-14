local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local weatherImage = player.PlayerGui:WaitForChild("Main"):WaitForChild("WeatherInfo")
local infoFrame = weatherImage:WaitForChild("Frame")

weatherImage.MouseEnter:Connect(function() infoFrame.Visible = true end)
weatherImage.MouseLeave:Connect(function() infoFrame.Visible = false end)
weatherImage.TouchLongPress:Connect(function() infoFrame.Visible = true end)

UserInputService.TouchEnded:Connect(function()
	infoFrame.Visible = false
end)
