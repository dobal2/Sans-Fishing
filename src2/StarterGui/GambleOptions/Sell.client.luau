local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local sellGuiEvent = ReplicatedStorage:WaitForChild("GambleGuiEvent")

sellGuiEvent.OnClientEvent:Connect(function()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("GambleOptions")

	gui.Enabled = true
	--gui.Size = UDim2.new(0, 0, 0, 0) -- 초기 사이즈

	local finalSize = UDim2.new(0.5, 0, 0.5, 0) -- 최종 사이즈
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	--local guiTween = TweenService:Create(gui, tweenInfo, { Size = finalSize })
	--guiTween:Play()

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