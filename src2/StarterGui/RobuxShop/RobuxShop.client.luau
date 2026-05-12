local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local lighting = game:GetService("Lighting")

local shopFrame = script.Parent:WaitForChild("Shop")
local uiScale   = shopFrame:WaitForChild("UIScale")
local closeBtn  = shopFrame:WaitForChild("Close"):WaitForChild("TextButton")
local blur      = lighting:WaitForChild("ShopBlur")
local camera    = workspace.CurrentCamera

local OPEN_TWEEN  = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.2,  Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FOV_TWEEN   = TweenInfo.new(0.5,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function isOpen()
	return shopFrame.Visible
end

local function openShop()
	shopFrame.Visible = true
	uiScale.Scale = 0
	TweenService:Create(uiScale, OPEN_TWEEN, {Scale = 1}):Play()
	blur.Enabled = true
	TweenService:Create(camera, FOV_TWEEN, {FieldOfView = 60}):Play()
end

local function closeShop()
	TweenService:Create(uiScale, CLOSE_TWEEN, {Scale = 0}):Play()
	task.delay(0.2, function() shopFrame.Visible = false end)
	blur.Enabled = false
	TweenService:Create(camera, FOV_TWEEN, {FieldOfView = 70}):Play()
end

closeBtn.MouseButton1Click:Connect(function()
	if isOpen() then closeShop() end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isOpen() then closeShop() end
end)

local remote = ReplicatedStorage:FindFirstChild("OpenRobuxShop")
if remote then
	remote.OnClientEvent:Connect(function()
		if isOpen() then closeShop() else openShop() end
	end)
end

shopFrame.Visible = false
uiScale.Scale = 0
