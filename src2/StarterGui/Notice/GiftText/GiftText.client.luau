local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FishReceiveNoticeEvent = ReplicatedStorage:WaitForChild("FishReceiveNoticeEvent")

local textLabel = script.Parent

local currentTween = nil
local currentTask = nil

local function createTween(object, targetProps, duration)
	return TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), targetProps)
end

local function showReceiveMessage(message)
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
	if currentTask then
		task.cancel(currentTask)
		currentTask = nil
	end

	textLabel.Text = message
	textLabel.Visible = true
	textLabel.TextTransparency = 1
	textLabel.TextStrokeTransparency = 1

	createTween(textLabel, {TextTransparency = 0, TextStrokeTransparency = 0}, 0.2):Play()

	currentTask = task.spawn(function()
		task.wait(2)
		currentTween = createTween(textLabel, {TextTransparency = 1, TextStrokeTransparency = 1}, 0.3)
		currentTween:Play()
		currentTween.Completed:Wait()
		textLabel.Visible = false
		currentTask = nil
	end)
end

FishReceiveNoticeEvent.OnClientEvent:Connect(showReceiveMessage)
