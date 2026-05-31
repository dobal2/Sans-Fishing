local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mainGui = player.PlayerGui:WaitForChild("Main")
local noticeFrame = mainGui:WaitForChild("NoticeFrame")
local template = noticeFrame:WaitForChild("ItemFrame")

local MAX_NOTICES = 5
local DISPLAY_TIME = 3.5

local notificationSound = nil
task.spawn(function()
	local sounds = ReplicatedStorage:WaitForChild("Sounds", 10)
	if sounds then
		notificationSound = sounds:WaitForChild("GetSound", 5)
	end
end)

-- Slide in from right, pop with Back easing
local TWEEN_IN  = TweenInfo.new(0.35, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
-- Fade + shrink out
local TWEEN_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)

local activeNotices = {}

local function removeNotice(frame)
	for i, v in ipairs(activeNotices) do
		if v == frame then table.remove(activeNotices, i); break end
	end

	local textLabel = frame:FindFirstChild("Text")
	local shadow    = frame:FindFirstChild("Shadow")

	TweenService:Create(frame, TWEEN_OUT, {BackgroundTransparency = 1}):Play()
	if textLabel then
		TweenService:Create(textLabel, TWEEN_OUT, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		local stroke = textLabel:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TWEEN_OUT, {Transparency = 1}):Play()
		end
	end
	for _, desc in ipairs(frame:GetDescendants()) do
		if desc:IsA("UIStroke") and desc.Parent ~= textLabel then
			TweenService:Create(desc, TWEEN_OUT, {Transparency = 1}):Play()
		end
	end
	if shadow then
		TweenService:Create(shadow, TWEEN_OUT, {ImageTransparency = 1}):Play()
	end
	task.delay(TWEEN_OUT.Time, function()
		if frame.Parent then frame:Destroy() end
	end)
end

local function showNotice(message, color)
	if not message or message == "" then return end

	while #activeNotices >= MAX_NOTICES do
		local oldest = table.remove(activeNotices, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end

	local frame = template:Clone()
	frame.Visible = true
	frame.BackgroundTransparency = 1
	-- Start off-screen to the right, collapsed height
	frame.Size = UDim2.new(template.Size.X.Scale, 0, 0, 0)
	frame.Position = UDim2.new(1.1, 0, 0, 0)
	frame.Parent = noticeFrame

	local textLabel = frame:FindFirstChild("Text")
	local shadow    = frame:FindFirstChild("Shadow")

	-- 모든 UIStroke 초기 투명도 1로 설정
	for _, desc in ipairs(frame:GetDescendants()) do
		if desc:IsA("UIStroke") then
			desc.Transparency = 1
		end
	end

	if textLabel then
		textLabel.Text = message
		textLabel.TextTransparency = 1
		textLabel.TextStrokeTransparency = 1
		if color then textLabel.TextColor3 = color end
	end
	if shadow then
		shadow.ImageTransparency = 1
	end

	table.insert(activeNotices, frame)

	if notificationSound then
		notificationSound:Play()
	end

	-- Expand height first (makes room in the list), then slide in
	local expandTween = TweenService:Create(frame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = template.Size,
	})
	expandTween:Play()
	expandTween.Completed:Connect(function()
		-- Slide in from right
		TweenService:Create(frame, TWEEN_IN, {
			BackgroundTransparency = template.BackgroundTransparency,
			Position = UDim2.new(0, 0, 0, 0),
		}):Play()
		-- UIStroke fade in
		for _, desc in ipairs(frame:GetDescendants()) do
			if desc:IsA("UIStroke") then
				TweenService:Create(desc, TWEEN_IN, {Transparency = 0}):Play()
			end
		end
		if textLabel then
			TweenService:Create(textLabel, TWEEN_IN, {
				TextTransparency = 0,
				TextStrokeTransparency = 0,
			}):Play()
		end
		if shadow then
			TweenService:Create(shadow, TWEEN_IN, {ImageTransparency = 0.5}):Play()
		end
	end)

	task.delay(DISPLAY_TIME, function()
		if frame and frame.Parent then
			removeNotice(frame)
		end
	end)
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RemotesNotice = Remotes:WaitForChild("Notice")

local function connectEvent(container, eventName, handler)
	task.spawn(function()
		local ev = container:WaitForChild(eventName, 10)
		if not ev then return end
		if ev:IsA("RemoteEvent") then ev.OnClientEvent:Connect(handler)
		elseif ev:IsA("BindableEvent") then ev.Event:Connect(handler) end
	end)
end

connectEvent(RemotesNotice, "FishNoticeEvent",        function(msg) showNotice(msg) end)
connectEvent(RemotesNotice, "ShowNoticeEvent",        function(msg) showNotice(msg) end)
connectEvent(RemotesNotice, "NoticeEventForClient",   function(msg) showNotice(msg) end)
connectEvent(RemotesNotice, "DiscoverNoticeEvent",    function(msg) showNotice(msg, Color3.fromRGB(255, 220, 50)) end)
connectEvent(ReplicatedStorage, "FishReceiveNoticeEvent", function(msg) showNotice(msg, Color3.fromRGB(100, 220, 255)) end)
connectEvent(ReplicatedStorage, "AnnounceRemote",     function(msg, sender)
	local text = sender and (sender .. ": " .. msg) or msg
	showNotice(text, Color3.fromRGB(100, 220, 100))
end)
