local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
-- script.Parent was a TextLabel inside Notice > AnnounceText ScreenGui
local announceGui = player.PlayerGui:WaitForChild("Notice"):WaitForChild("AnnounceText")
local textLabel = announceGui:WaitForChild("TextLabel")

local announceRemote = ReplicatedStorage:WaitForChild("AnnounceRemote")

local currentTween = nil
local currentTask = nil

local function createTween(object, targetProps, duration)
	return TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), targetProps)
end

local function showAnnouncement(message, senderName)
	if currentTween then currentTween:Cancel(); currentTween = nil end
	if currentTask then task.cancel(currentTask); currentTask = nil end

	textLabel.Text = string.format("%s: %s", senderName, message)
	textLabel.Visible = true
	textLabel.TextTransparency = 1
	textLabel.TextStrokeTransparency = 1

	createTween(textLabel, {TextTransparency = 0, TextStrokeTransparency = 0}, 0.3):Play()

	currentTask = task.spawn(function()
		task.wait(5)
		currentTween = createTween(textLabel, {TextTransparency = 1, TextStrokeTransparency = 1}, 0.5)
		currentTween:Play()
		currentTween.Completed:Wait()
		textLabel.Visible = false
		currentTask = nil
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	end)
end

announceRemote.OnClientEvent:Connect(showAnnouncement)
