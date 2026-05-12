-- 📦 Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- 🎯 GUI 요소들
local player = Players.LocalPlayer
local frame = script.Parent:WaitForChild("Frame")
local ScrollingFrame = frame:WaitForChild("ScrollingFrame")
local button = frame:WaitForChild("Button")
local questFrame = script:WaitForChild("Quest")

-- 🎯 퀘스트 이벤트들
local questEvents = ReplicatedStorage:WaitForChild("Quest Events")
local questGuiEvent = questEvents:WaitForChild("QuestGuiEvent")
local questReceiveEvent = questEvents:WaitForChild("QuestReceiveEvent")
local questCompleteEvent = questEvents:WaitForChild("QuestCompleteEvent")

-- 🔧 프레임 위치 상태 변수
local isFrameExpanded = false

-- 시간 포맷 함수 추가
local function formatTime(seconds)
	if seconds >= 60 then
		local minutes = math.floor(seconds / 60)
		local remainingSeconds = seconds % 60
		if remainingSeconds > 0 then
			return string.format("%dm %ds", minutes, remainingSeconds)
		else
			return string.format("%dm", minutes)
		end
	else
		return string.format("%ds", seconds)
	end
end

-- 🔧 프레임 위치 트윈 함수
local function animateFramePosition()
	local targetPosition

	if not isFrameExpanded then
		-- 첫 번째 클릭: {1, 0},{0.306, 0}로 이동
		targetPosition = UDim2.new(0.98, 0, 0.306, 0)
		button.Text = "<"
		isFrameExpanded = true
	else
		-- 두 번째 클릭: {0.791, 0},{0.306, 0}로 이동
		targetPosition = UDim2.new(0.791, 0, 0.306, 0)
		button.Text = ">"
		isFrameExpanded = false
	end

	local frameTween = TweenService:Create(
		frame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{Position = targetPosition}
	)

	frameTween:Play()
end

-- 🔧 퀘스트 프레임 생성 함수
local function createQuestFrame(questData)
	local newQuestFrame = questFrame:Clone()
	newQuestFrame.Name = questData.name
	newQuestFrame.Visible = true

	-- 텍스트 업데이트
	local titleLabel = newQuestFrame:FindFirstChild("Title")
	local descLabel = newQuestFrame:FindFirstChild("Desc")
	local rewardLabel = newQuestFrame:FindFirstChild("Rewards")

	if titleLabel then
		titleLabel.Text = questData.name
	end

	if descLabel then
		descLabel.Text = questData.description
	end

	if rewardLabel then
		rewardLabel.Text = "Rewards: ".. questData.rewardCoins .. " Coins"
	end

	-- 진행도 바 업데이트
	local barFrame = newQuestFrame:FindFirstChild("Bar")
	if barFrame then
		local fillFrame = barFrame:FindFirstChild("Fill")
		if fillFrame then
			local progressRatio = questData.currentProgress / questData.requiredProgress
			progressRatio = math.min(progressRatio, 1) -- 최대 1로 제한

			-- 진행도에 따라 Fill 크기 조정
			fillFrame.Size = UDim2.new(progressRatio, 0, 1, 0)

			-- 진행도 텍스트 추가 (플레이타임 퀘스트인지 확인)
			local progressText = barFrame:FindFirstChild("ProgressText")
			if not progressText then
				progressText = Instance.new("TextLabel")
				progressText.Name = "ProgressText"
				progressText.Size = UDim2.new(1, 0, 1, 0)
				progressText.Position = UDim2.new(0, 0, 0, 0)
				progressText.BackgroundTransparency = 1
				progressText.TextScaled = true
				progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
				progressText.Font = Enum.Font.SourceSansBold
				progressText.Parent = barFrame
			end

			-- 플레이타임 퀘스트인지 확인하여 시간 포맷 적용
			if questData.questType == "daily_playtime" then
				-- 플레이타임 퀘스트: 시간 단위로 표시
				local currentTime = formatTime(questData.currentProgress)
				local requiredTime = formatTime(questData.requiredProgress)
				progressText.Text = currentTime .. "/" .. requiredTime
			else
				-- 일반 퀘스트: 숫자로 표시
				progressText.Text = questData.currentProgress .. "/" .. questData.requiredProgress
			end

			-- 완료 상태에 따른 색상 변경
			if questData.currentProgress >= questData.requiredProgress then
				fillFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- 초록색 (완료)
			else
				fillFrame.BackgroundColor3 = Color3.fromRGB(0, 162, 255) -- 파란색 (진행중)
			end
		end
	end

	return newQuestFrame
end

-- 🔧 퀘스트 목록 업데이트 함수
local function updateQuestList()
	--print("🔍 updateQuestList 시작")

	-- 기존 퀘스트 프레임들 제거
	for _, child in pairs(ScrollingFrame:GetChildren()) do
		if child:IsA("Frame") and child ~= questFrame then
			child:Destroy()
		end
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		print("❌ leaderstats 없음")
		return
	end

	local quests = leaderstats:FindFirstChild("Quests")
	if not quests then
		print("❌ Quests 없음")
		return
	end

	local activeQuests = quests:FindFirstChild("ActiveQuests")
	if not activeQuests then
		print("❌ ActiveQuests 없음")
		return
	end

	local questCount = 0

	-- 활성 퀘스트들을 GUI에 추가
	for _, quest in pairs(activeQuests:GetChildren()) do
		if quest:IsA("Folder") then
			local questData = {
				id = quest.Name,
				name = quest:FindFirstChild("QuestName") and quest.QuestName.Value or "Unknown Quest",
				description = quest:FindFirstChild("QuestDescription") and quest.QuestDescription.Value or "No description",
				currentProgress = quest:FindFirstChild("CurrentProgress") and quest.CurrentProgress.Value or 0,
				requiredProgress = quest:FindFirstChild("RequiredProgress") and quest.RequiredProgress.Value or 1,
				isReceived = quest:FindFirstChild("IsReceived") and quest.IsReceived.Value or false,
				rewardCoins = quest:FindFirstChild("RewardCoins") and quest.RewardCoins.Value or 0,
				questType = quest:FindFirstChild("QuestType") and quest.QuestType.Value or "normal"
			}

			--print("📝 퀘스트:", questData.name, "받음:", questData.isReceived, "타입:", questData.questType)

			-- 🔧 퀘스트를 받은 경우에만 GUI에 표시
			if questData.isReceived then
				local newQuestFrame = createQuestFrame(questData)
				newQuestFrame.Parent = ScrollingFrame
				questCount = questCount + 1
				--print("✅ 퀘스트 프레임 추가:", questData.name)
			end
		end
	end

	-- 🔧 퀘스트가 없으면 frame 숨기기
	if questCount == 0 then
		frame.Visible = false
		--print("🔒 프레임 숨김 (퀘스트 없음)")
	else
		frame.Visible = true
		--print("👁️ 프레임 표시 (퀘스트", questCount, "개)")
	end

	--print("🎯 퀘스트 목록 업데이트 완료:", questCount, "개 퀘스트 (받은 퀘스트만)")
end

-- 🔧 퀘스트 데이터 변경 감지
local function setupQuestChangeDetection()
	--print("🔧 퀘스트 변경 감지 설정 시작")

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		print("❌ leaderstats 없음 - 변경 감지 설정 실패")
		return
	end

	local quests = leaderstats:FindFirstChild("Quests")
	if not quests then
		print("❌ Quests 없음 - 변경 감지 설정 실패")
		return
	end

	local activeQuests = quests:FindFirstChild("ActiveQuests")
	if not activeQuests then
		print("❌ ActiveQuests 없음 - 변경 감지 설정 실패")
		return
	end

	-- 퀘스트 추가/제거 감지
	activeQuests.ChildAdded:Connect(function()
		wait(0.1) -- 약간의 지연 후 업데이트
		--print("➕ 퀘스트 추가됨")
		updateQuestList()
	end)

	activeQuests.ChildRemoved:Connect(function()
		wait(0.1)
		--print("➖ 퀘스트 제거됨")
		updateQuestList()
	end)

	-- 기존 퀘스트들의 변경사항 감지
	for _, quest in pairs(activeQuests:GetChildren()) do
		if quest:IsA("Folder") then
			local currentProgress = quest:FindFirstChild("CurrentProgress")
			local isReceived = quest:FindFirstChild("IsReceived")

			if currentProgress then
				currentProgress.Changed:Connect(function()
					--print("📈 퀘스트 진행도 변경:", quest.Name)
					updateQuestList()
				end)
			end

			if isReceived then
				isReceived.Changed:Connect(function()
					--print("📋 퀘스트 받음 상태 변경:", quest.Name, isReceived.Value)
					updateQuestList()
				end)
			end
		end
	end

	-- 새로 추가되는 퀘스트들에 대한 감지 설정
	activeQuests.ChildAdded:Connect(function(quest)
		if quest:IsA("Folder") then
			wait(0.1) -- 퀘스트 데이터가 완전히 로드될 때까지 대기

			local currentProgress = quest:FindFirstChild("CurrentProgress")
			local isReceived = quest:FindFirstChild("IsReceived")

			if currentProgress then
				currentProgress.Changed:Connect(function()
					--print("📈 새 퀘스트 진행도 변경:", quest.Name)
					updateQuestList()
				end)
			end

			if isReceived then
				isReceived.Changed:Connect(function()
					--print("📋 새 퀘스트 받음 상태 변경:", quest.Name, isReceived.Value)
					updateQuestList()
				end)
			end
		end
	end)

	--print("✅ 퀘스트 변경 감지 설정 완료")
end

-- 🚀 퀘스트 데이터 로딩 대기 함수
local function waitForQuestData()
	local maxAttempts = 9999999
	local attempts = 0

	while attempts < maxAttempts do
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local quests = leaderstats:FindFirstChild("Quests")
			if quests then
				local activeQuests = quests:FindFirstChild("ActiveQuests")
				if activeQuests then
					--print("✅ 퀘스트 데이터 로드 완료")
					return true
				end
			end
		end

		attempts = attempts + 1
		wait(0.5)
	end

	--print("❌ 퀘스트 데이터 로드 실패")
	return false
end

-- 🚀 초기화 함수
local function initialize()
	--print("🚀 초기화 시작")

	-- 퀘스트 데이터가 로드될 때까지 기다림
	if waitForQuestData() then
		setupQuestChangeDetection()
		updateQuestList()
		--print("✅ 초기화 완료")
	else
		-- 실패 시 leaderstats 추가를 기다림
		player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				--print("📋 leaderstats 추가됨, 재시도 중...")
				wait(1)
				initialize()
			end
		end)
	end
end

-- 🎯 GUI 이벤트 처리
questGuiEvent.OnClientEvent:Connect(function()
	frame.Visible = true
	updateQuestList()
end)

-- 🎯 메인 버튼 클릭 이벤트
button.MouseButton1Click:Connect(function()
	animateFramePosition()
	updateQuestList()
end)

-- 🚀 초기화 실행
spawn(function()
	wait(1) -- 기본 대기
	initialize()
end)