local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FishNoticeEvent = ReplicatedStorage:WaitForChild("FishNoticeEvent")
local ShowNoticeEvent = ReplicatedStorage:WaitForChild("ShowNoticeEvent")
local noticeEvent = ReplicatedStorage:WaitForChild("NoticeEventForClient")
local textLabel = script.Parent

local currentTween = nil
local currentTask = nil

local function createTween(object, targetProps, duration)
	return TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), targetProps)
end

local function showMessage(message)
	if currentTween then currentTween:Cancel(); currentTween = nil end
	if currentTask then task.cancel(currentTask); currentTask = nil end

	local stroke = textLabel:FindFirstChildOfClass("UIStroke")

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

FishNoticeEvent.OnClientEvent:Connect(showMessage)
ShowNoticeEvent.OnClientEvent:Connect(showMessage)
noticeEvent.Event:Connect(showMessage)
