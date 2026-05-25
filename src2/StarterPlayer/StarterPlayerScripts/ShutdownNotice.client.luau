-- ShutdownNotice.client.luau
-- Persistent red notice in NoticeFrame counting down to server shutdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mainGui = player.PlayerGui:WaitForChild("Main")
local noticeFrame = mainGui:WaitForChild("NoticeFrame")
local template = noticeFrame:WaitForChild("ItemFrame")

local SHUTDOWN_COLOR = Color3.fromRGB(255, 80, 80)

local TWEEN_IN  = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local shutdownFrame = nil
local shutdownEndTime = nil
local shutdownReason = nil
local updateThread = nil

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

local function buildText()
	local remaining = shutdownEndTime and math.max(0, shutdownEndTime - os.clock()) or 0
	local base = string.format("[SHUTDOWN] Server closing in %s", formatTime(remaining))
	if shutdownReason and shutdownReason ~= "" then
		base = base .. "  (" .. shutdownReason .. ")"
	end
	return base
end

local function removeFrame()
	if not shutdownFrame then return end
	local f = shutdownFrame
	shutdownFrame = nil

	local textLabel = f:FindFirstChild("Text")
	local shadow    = f:FindFirstChild("Shadow")

	TweenService:Create(f, TWEEN_OUT, {BackgroundTransparency = 1}):Play()
	if textLabel then
		TweenService:Create(textLabel, TWEEN_OUT, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		local stroke = textLabel:FindFirstChildOfClass("UIStroke")
		if stroke then TweenService:Create(stroke, TWEEN_OUT, {Transparency = 1}):Play() end
	end
	if shadow then TweenService:Create(shadow, TWEEN_OUT, {ImageTransparency = 1}):Play() end

	task.delay(TWEEN_OUT.Time, function()
		if f.Parent then f:Destroy() end
	end)
end

local function stopUpdate()
	if updateThread then
		task.cancel(updateThread)
		updateThread = nil
	end
end

local function showFrame()
	if shutdownFrame then return end

	local f = template:Clone()
	f.Name = "ShutdownNoticeFrame"
	f.Visible = true
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(template.Size.X.Scale, 0, 0, 0)
	f.Position = UDim2.new(1.1, 0, 0, 0)
	f.LayoutOrder = -998
	f.Parent = noticeFrame
	shutdownFrame = f

	local textLabel = f:FindFirstChild("Text")
	local shadow    = f:FindFirstChild("Shadow")

	for _, desc in ipairs(f:GetDescendants()) do
		if desc:IsA("UIStroke") then desc.Transparency = 1 end
	end

	if textLabel then
		textLabel.Text = buildText()
		textLabel.TextTransparency = 1
		textLabel.TextStrokeTransparency = 1
		textLabel.TextColor3 = SHUTDOWN_COLOR
	end
	if shadow then shadow.ImageTransparency = 1 end

	local expandTween = TweenService:Create(f, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = template.Size,
	})
	expandTween:Play()
	expandTween.Completed:Connect(function()
		TweenService:Create(f, TWEEN_IN, {
			BackgroundTransparency = template.BackgroundTransparency,
			Position = UDim2.new(0, 0, 0, 0),
		}):Play()
		for _, desc in ipairs(f:GetDescendants()) do
			if desc:IsA("UIStroke") then
				TweenService:Create(desc, TWEEN_IN, {Transparency = 0}):Play()
			end
		end
		if textLabel then
			TweenService:Create(textLabel, TWEEN_IN, {TextTransparency = 0, TextStrokeTransparency = 0}):Play()
		end
		if shadow then
			TweenService:Create(shadow, TWEEN_IN, {ImageTransparency = 0.5}):Play()
		end
	end)
end

local function startUpdate()
	stopUpdate()
	updateThread = task.spawn(function()
		while shutdownFrame do
			local remaining = shutdownEndTime and math.max(0, shutdownEndTime - os.clock()) or 0
			if remaining <= 0 then
				stopUpdate()
				removeFrame()
				shutdownEndTime = nil
				break
			end

			local textLabel = shutdownFrame:FindFirstChild("Text")
			if textLabel then
				textLabel.Text = buildText()
			end

			task.wait(1)
		end
	end)
end

local shutdownTimerEvent = ReplicatedStorage:WaitForChild("ShutdownTimerEvent", 60)
if not shutdownTimerEvent then return end

shutdownTimerEvent.OnClientEvent:Connect(function(remainSecs, reason)
	if not remainSecs then
		stopUpdate()
		removeFrame()
		shutdownEndTime = nil
		shutdownReason = nil
	else
		shutdownEndTime = os.clock() + remainSecs
		shutdownReason = reason or ""
		showFrame()
		startUpdate()
	end
end)
