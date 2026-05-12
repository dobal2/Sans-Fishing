local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- 타입1: 일반 알림
local NoticeEvent = ReplicatedStorage:WaitForChild("NoticeEventForClient")
local FishNoticeEvent = ReplicatedStorage:WaitForChild("FishNoticeEvent")
local ShowNoticeEvent = ReplicatedStorage:WaitForChild("ShowNoticeEvent")

-- 타입2: 인첸트 알림
local EnchantNoticeEvent = ReplicatedStorage:WaitForChild("EnchantNoticeEvent")

local textLabel = script.Parent
local currentTween = nil
local currentTask = nil

-- 트윈 생성 함수
local function createTween(object, targetProps, duration)
	return TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), targetProps)
end

-- 일반 알림 표시
local function showMessage(message)
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
		task.wait(1.5) -- 일반 알림은 1.5초만 표시
		currentTween = createTween(textLabel, {TextTransparency = 1, TextStrokeTransparency = 1}, 0.3)
		currentTween:Play()
		currentTween.Completed:Wait()
		textLabel.Visible = false
		currentTask = nil
	end)
end

local function showEnchantMessage(rarity, enchantName, statsTable)
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
	if currentTask then
		task.cancel(currentTask)
		currentTask = nil
	end

	-- 메시지 생성: 이름 + 등급 + 능력
	local message = string.format("[%s] %s", rarity, enchantName)
	if statsTable and next(statsTable) then
		local statsStr = {}
		for stat, value in pairs(statsTable) do
			if stat:find("Mutation") then
				table.insert(statsStr, stat .. " +" .. value .. "%")
			else
				table.insert(statsStr, stat .. " " .. (value >= 0 and "+" or "") .. value .. "%")
			end
		end
		message = message .. "\n" .. table.concat(statsStr, ", ")
	end

	textLabel.Text = message
	textLabel.Visible = true
	textLabel.TextTransparency = 1
	textLabel.TextStrokeTransparency = 1

	createTween(textLabel, {TextTransparency = 0, TextStrokeTransparency = 0}, 0.2):Play()

	currentTask = task.spawn(function()
		task.wait(5)  -- 5초 동안 표시
		currentTween = createTween(textLabel, {TextTransparency = 1, TextStrokeTransparency = 1}, 0.3)
		currentTween:Play()
		currentTween.Completed:Wait()
		textLabel.Visible = false
		currentTask = nil
	end)
end

-- 이벤트 연결
FishNoticeEvent.OnClientEvent:Connect(showMessage)
ShowNoticeEvent.OnClientEvent:Connect(showMessage)
NoticeEvent.Event:Connect(showMessage)

EnchantNoticeEvent.OnClientEvent:Connect(showEnchantMessage)