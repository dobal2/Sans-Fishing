-- 🆕 물고기 받기 전용 클라이언트 스크립트
-- LocalScript로 StarterGui에 넣으세요

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- 🆕 물고기 받기 전용 리모트 이벤트 대기
local FishReceiveNoticeEvent = ReplicatedStorage:WaitForChild("FishReceiveNoticeEvent")

-- UI 요소 (기존 FishNotice UI와 같은 구조 사용)
local textLabel = script.Parent -- TextLabel을 부모로 설정

local currentTween = nil
local currentTask = nil

-- 트윈 생성 함수
local function createTween(object, targetProps, duration)
	return TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), targetProps)
end

-- 메시지 출력 함수 (기존 표시 중단 후 새 메시지 즉시 출력)
local function showReceiveMessage(message)
	-- 진행 중이면 중단
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

	-- 페이드 인
	createTween(textLabel, {TextTransparency = 0, TextStrokeTransparency = 0}, 0.2):Play()

	-- 표시 후 페이드 아웃
	currentTask = task.spawn(function()
		task.wait(2) -- 물고기 받기는 2초간 표시 (낚시보다 조금 길게)
		currentTween = createTween(textLabel, {TextTransparency = 1, TextStrokeTransparency = 1}, 0.3)
		currentTween:Play()
		currentTween.Completed:Wait()
		textLabel.Visible = false
		currentTask = nil
	end)
end

-- 🆕 물고기 받기 전용 이벤트 연결
FishReceiveNoticeEvent.OnClientEvent:Connect(showReceiveMessage)