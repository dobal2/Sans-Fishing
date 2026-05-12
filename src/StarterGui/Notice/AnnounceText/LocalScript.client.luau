-- 📢 공지 전용 클라이언트 스크립트
-- LocalScript로 StarterGui에 넣으세요

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- 📢 공지 전용 리모트 이벤트 대기
local announceRemote = ReplicatedStorage:WaitForChild("AnnounceRemote")

-- UI 요소 (기존 FishNotice UI와 같은 구조 사용)
local textLabel = script.Parent -- TextLabel을 부모로 설정

local currentTween = nil
local currentTask = nil

-- 트윈 생성 함수
local function createTween(object, targetProps, duration)
	return TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), targetProps)
end

-- 📢 공지 메시지 출력 함수
local function showAnnouncement(message, senderName, senderRank)
	-- 진행 중이면 중단
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
	if currentTask then
		task.cancel(currentTask)
		currentTask = nil
	end

	local formattedMessage = string.format("%s: %s", senderName, message)

	textLabel.Text = formattedMessage
	textLabel.Visible = true
	textLabel.TextTransparency = 1
	textLabel.TextStrokeTransparency = 1

	---- 📢 공지는 특별한 색상으로 (금색/노란색)
	--textLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- 금색
	--textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0) -- 검은색 테두리

	-- 페이드 인
	createTween(textLabel, {TextTransparency = 0, TextStrokeTransparency = 0}, 0.3):Play()

	-- 공지는 더 오래 표시 (5초)
	currentTask = task.spawn(function()
		task.wait(5) -- 공지는 5초간 표시
		currentTween = createTween(textLabel, {TextTransparency = 1, TextStrokeTransparency = 1}, 0.5)
		currentTween:Play()
		currentTween.Completed:Wait()
		textLabel.Visible = false
		currentTask = nil

		-- 원래 색상으로 복원
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- 하얀색
		textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0) -- 검은색 테두리
	end)

	print("📢 공지 수신:", formattedMessage)
end

-- 📢 공지 이벤트 연결
announceRemote.OnClientEvent:Connect(showAnnouncement)

print("✅ Announcement Client Script initialized")