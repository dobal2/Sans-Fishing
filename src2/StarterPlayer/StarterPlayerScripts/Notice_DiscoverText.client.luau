local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
-- script.Parent was a TextLabel inside Notice > DiscoverText ScreenGui
local discoverGui = player.PlayerGui:WaitForChild("Notice"):WaitForChild("DiscoverText")
local textLabel = discoverGui:WaitForChild("TextLabel")

local noticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("DiscoverNoticeEvent")

local currentTween = nil
local currentTask = nil

local function createTween(object, targetProps, duration)
	return TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), targetProps)
end

local stroke = textLabel:FindFirstChildOfClass("UIStroke")

local function showMessage(message)
	if currentTween then currentTween:Cancel(); currentTween = nil end
	if currentTask then task.cancel(currentTask); currentTask = nil end

	textLabel.Text = message
	textLabel.Visible = true
	textLabel.TextTransparency = 1
	textLabel.TextStrokeTransparency = 1
	if stroke then stroke.Transparency = 1 end

	createTween(textLabel, {TextTransparency = 0, TextStrokeTransparency = 0}, 0.2):Play()
	if stroke then createTween(stroke, {Transparency = 0}, 0.2):Play() end

	currentTask = task.spawn(function()
		task.wait(1.5)
		currentTween = createTween(textLabel, {TextTransparency = 1, TextStrokeTransparency = 1}, 0.3)
		currentTween:Play()
		if stroke then createTween(stroke, {Transparency = 1}, 0.3):Play() end
		currentTween.Completed:Wait()
		textLabel.Visible = false
		currentTask = nil
	end)
end

noticeEvent.OnClientEvent:Connect(showMessage)
