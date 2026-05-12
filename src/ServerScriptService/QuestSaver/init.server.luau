local datamanager = require(script.DataManager)
local DataService = game:GetService("DataStoreService")
local MyData = DataService:GetDataStore("playerdata")
local ServerStorage = game:GetService("ServerStorage")
local players = game.Players

-- 데일리 퀘스트 관련 함수들
local function getCurrentDateString()
	local currentTime = os.time()
	local date = os.date("*t", currentTime)
	return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

local function createDailyPlaytimeQuest()
	return {
		id = "daily_playtime_15min",
		name = "Daily Playtime",
		description = "Play for 15 minutes today to earn daily reward!",
		targetFish = "",
		requiredProgress = 900,
		rewardCoins = 50000,
		isReceived = true,
		currentProgress = 0,
		questType = "daily_playtime"
	}
end

-- 보이드 퀘스트 백업 생성 함수
local function createVoidQuestBackup()
	return {
		id = "void_unknown_challenge",
		name = "Void Challenge: Unknown Hunt",
		description = "Catch 4 Unknown fish for the mysterious void collector",
		targetFish = "Unknown",
		requiredProgress = 4,
		rewardCoins = 1000000,
		isReceived = false,
		currentProgress = 0,
		questType = "void"
	}
end

-- 세션 시작 시간과 기준 플레이타임 저장
local playerSessionStartTime = {}
local playerBasePlaytime = {}  -- 세션 시작 시 저장된 플레이타임

players.PlayerAdded:Connect(function(plr)
	wait(2)

	repeat task.wait()
		local dataReady = plr:FindFirstChild("DataReady")
	until dataReady and dataReady.Value == true
	print("DataReady")

	-- 퀘스트 폴더 생성
	local leaderstats = plr:FindFirstChild("leaderstats")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = plr

	local Quests = Instance.new("Folder")
	Quests.Name = "Quests"

	local ActiveQuests = Instance.new("Folder")
	ActiveQuests.Name = "ActiveQuests"
	ActiveQuests.Parent = Quests

	local CompletedQuests = Instance.new("Folder")
	CompletedQuests.Name = "CompletedQuests"
	CompletedQuests.Parent = Quests

	-- 퀘스트 생성 함수
	local function createQuest(questData, questId)
		if not questData then
			warn("questData가 nil입니다")
			return nil
		end

		local id = questData.id or questId
		if not id then
			warn("퀘스트 ID를 찾을 수 없습니다:", questData)
			return nil
		end

		local questFolder = Instance.new("Folder")
		questFolder.Name = id

		local questName = Instance.new("StringValue")
		questName.Name = "QuestName"
		questName.Value = questData.name or "Unknown Quest"
		questName.Parent = questFolder

		local questDescription = Instance.new("StringValue")
		questDescription.Name = "QuestDescription"
		questDescription.Value = questData.description or "No description"
		questDescription.Parent = questFolder

		local targetFish = Instance.new("StringValue")
		targetFish.Name = "TargetFish"
		targetFish.Value = questData.targetFish or ""
		targetFish.Parent = questFolder

		local currentProgress = Instance.new("IntValue")
		currentProgress.Name = "CurrentProgress"
		currentProgress.Value = questData.currentProgress or 0
		currentProgress.Parent = questFolder

		local requiredProgress = Instance.new("IntValue")
		requiredProgress.Name = "RequiredProgress"
		requiredProgress.Value = questData.requiredProgress or 1
		requiredProgress.Parent = questFolder

		local rewardCoins = Instance.new("IntValue")
		rewardCoins.Name = "RewardCoins"
		rewardCoins.Value = questData.rewardCoins or 0
		rewardCoins.Parent = questFolder

		local isReceived = Instance.new("BoolValue")
		isReceived.Name = "IsReceived"
		isReceived.Value = questData.isReceived or false
		isReceived.Parent = questFolder

		local questType = Instance.new("StringValue")
		questType.Name = "QuestType"
		questType.Value = questData.questType or "normal"
		questType.Parent = questFolder

		return questFolder
	end

	-- 퀘스트 폴더를 leaderstats에 추가
	Quests.Parent = leaderstats

	-- 데이터 로드
	local Data
	repeat
		task.wait()
		Data = datamanager:GetData(plr)
	until Data

	print("데이터 로드 완료:", plr.Name)

	-- 🔧 중요: 보이드 퀘스트 먼저 백업 (데일리 리셋 전에)
	local voidQuestBackup = nil
	if Data.Quests and Data.Quests.ActiveQuests and Data.Quests.ActiveQuests["void_unknown_challenge"] then
		voidQuestBackup = Data.Quests.ActiveQuests["void_unknown_challenge"]
		print("🔧 기존 보이드 퀘스트 백업:", plr.Name, "진행도:", voidQuestBackup.currentProgress or 0)
	end

	-- 데일리 퀘스트 체크
	local currentDate = getCurrentDateString()
	local lastQuestDate = Data.LastQuestDate

	print("데일리 퀘스트 체크:", plr.Name, "마지막:", lastQuestDate, "현재:", currentDate)

	-- 하루가 지났으면 데일리 퀘스트만 삭제하고 새로 생성
	if lastQuestDate ~= currentDate then
		print("데일리 퀘스트 리셋:", plr.Name)
		Data.LastQuestDate = currentDate

		-- 🔧 수정: 매우 안전한 데일리 퀘스트 제거 (보이드 퀘스트는 절대 건드리지 않음)
		if Data.Quests and Data.Quests.ActiveQuests then
			local questsToKeep = {}

			for questId, questData in pairs(Data.Quests.ActiveQuests) do
				if questData.questType ~= "daily_playtime" and questId ~= "void_unknown_challenge" then
					questsToKeep[questId] = questData
					print("보존할 퀘스트:", questId, "타입:", questData.questType or "알수없음")
				elseif questId == "void_unknown_challenge" then
					-- 보이드 퀘스트는 무조건 보존
					questsToKeep[questId] = questData
					print("보이드 퀘스트 강제 보존:", questId)
				else
					print("제거할 데일리 퀘스트:", questId, "타입:", questData.questType)
				end
			end

			-- 안전하게 보존할 퀘스트만 남기기
			Data.Quests.ActiveQuests = questsToKeep
		end

		-- 🔧 수정: 완료된 데일리 퀘스트만 제거 (보이드 퀘스트는 절대 제거하지 않음)
		if Data.Quests and Data.Quests.CompletedQuests then
			local completedToKeep = {}

			for questId, isCompleted in pairs(Data.Quests.CompletedQuests) do
				-- "daily_"로 시작하는 것만 제거, 나머지는 모두 보존
				if not questId:find("daily_") then
					completedToKeep[questId] = isCompleted
					print("보존할 완료된 퀘스트:", questId)
				else
					print("제거할 완료된 데일리 퀘스트:", questId)
				end
			end

			Data.Quests.CompletedQuests = completedToKeep
		end

		-- 새로운 데일리 퀘스트 생성
		if not Data.Quests then Data.Quests = {} end
		if not Data.Quests.ActiveQuests then Data.Quests.ActiveQuests = {} end
		if not Data.Quests.CompletedQuests then Data.Quests.CompletedQuests = {} end

		local todayDailyId = "daily_playtime_15min_" .. currentDate
		local todayDailyCompleted = Data.Quests.CompletedQuests[todayDailyId]

		if not todayDailyCompleted then
			local dailyQuest = createDailyPlaytimeQuest()
			dailyQuest.id = todayDailyId
			Data.Quests.ActiveQuests[todayDailyId] = dailyQuest
			print("새 데일리 퀘스트 생성:", todayDailyId)
		else
			print("오늘 데일리 퀘스트 이미 완료됨, 새로 생성하지 않음")
		end

		datamanager:SafeSavePlayer(plr)
	end

	-- 🔧 강제: 보이드 퀘스트 복원/생성 (절대 사라지지 않도록)
	print("🔧 보이드 퀘스트 최종 확인 및 복원:", plr.Name)

	-- 데이터 초기화 확인
	if not Data.Quests then Data.Quests = {} end
	if not Data.Quests.ActiveQuests then Data.Quests.ActiveQuests = {} end
	if not Data.Quests.CompletedQuests then Data.Quests.CompletedQuests = {} end

	local hasVoidQuest = Data.Quests.ActiveQuests["void_unknown_challenge"] ~= nil
	local voidQuestCompleted = Data.Quests.CompletedQuests["void_unknown_challenge"] == true

	print("🔧 보이드 퀘스트 상태:", plr.Name, "활성:", hasVoidQuest, "완료:", voidQuestCompleted)

	-- 보이드 퀘스트가 없고 완료도 안 되었으면 생성/복원
	if not hasVoidQuest and not voidQuestCompleted then
		local voidQuest

		if voidQuestBackup then
			-- 백업된 데이터가 있으면 복원
			voidQuest = voidQuestBackup
			print("🔧 보이드 퀘스트 백업 데이터 복원:", plr.Name, "진행도:", voidQuest.currentProgress)
		else
			-- 새로 생성
			voidQuest = createVoidQuestBackup()
			print("🔧 보이드 퀘스트 새로 생성:", plr.Name)
		end

		Data.Quests.ActiveQuests[voidQuest.id] = voidQuest
		Data.VoidQuestInitialized = true
		datamanager:SafeSavePlayer(plr)
		print("🔧 보이드 퀘스트 확실히 저장 완료")
	end

	-- 🔧 수정: 퀘스트 데이터 적용 - 플레이타임 복원 포함
	if Data and Data.Quests then
		-- 활성 퀘스트 로드
		for questId, questData in pairs(Data.Quests.ActiveQuests or {}) do
			local questFolder = createQuest(questData, questId)
			if questFolder then
				questFolder.Parent = ActiveQuests
				print("활성 퀘스트 로드:", questId, "→", plr.Name)

				-- 🔧 수정: 플레이타임 퀘스트면 저장된 진행도를 기준 플레이타임으로 설정
				if questData.questType == "daily_playtime" then
					-- 저장된 진행도를 기준으로 설정 (새 세션 시작점)
					playerBasePlaytime[plr.UserId] = questData.currentProgress or 0
					playerSessionStartTime[plr.UserId] = tick()
					print("🔧 저장된 플레이타임 복원:", plr.Name, playerBasePlaytime[plr.UserId], "초")
				end
			else
				warn("퀘스트 생성 실패:", questId)
			end
		end

		-- 완료된 퀘스트 로드
		for questId, isCompleted in pairs(Data.Quests.CompletedQuests or {}) do
			if isCompleted then
				local completedQuest = Instance.new("BoolValue")
				completedQuest.Name = questId
				completedQuest.Value = true
				completedQuest.Parent = CompletedQuests
				print("완료된 퀘스트 로드:", questId, "→", plr.Name)
			end
		end
	end

	-- 🔧 완전 수정: 데일리 퀘스트 백업 생성 (중복 방지)
	local todayDailyId = "daily_playtime_15min_" .. currentDate

	-- 1. 활성 데일리 퀘스트 있는지 확인
	local hasDailyQuest = false
	local existingDailyProgress = 0  -- 🔧 추가: 기존 진행도 저장용
	for _, quest in pairs(ActiveQuests:GetChildren()) do
		if quest:IsA("Folder") then
			local questType = quest:FindFirstChild("QuestType")
			if questType and questType.Value == "daily_playtime" then
				hasDailyQuest = true
				-- 🔧 추가: 기존 진행도 가져오기
				local currentProgress = quest:FindFirstChild("CurrentProgress")
				if currentProgress then
					existingDailyProgress = currentProgress.Value
				end
				break
			end
		end
	end

	-- 2. 데이터베이스에서 오늘 완료 기록 확인
	local todayDailyCompletedInData = Data.Quests.CompletedQuests[todayDailyId] == true

	-- 3. 클라이언트 폴더에서도 완료 기록 확인
	local todayDailyCompletedInClient = false
	for _, quest in pairs(CompletedQuests:GetChildren()) do
		if quest:IsA("BoolValue") and quest.Name == todayDailyId then
			todayDailyCompletedInClient = true
			break
		end
	end

	print("🔧 데일리 퀘스트 백업 체크:", plr.Name)
	print("  - 활성 퀘스트:", hasDailyQuest, "진행도:", existingDailyProgress)
	print("  - 데이터베이스 완료:", todayDailyCompletedInData)
	print("  - 클라이언트 완료:", todayDailyCompletedInClient)

	-- 4. 활성도 없고 완료도 안 된 경우에만 백업 생성
	if not hasDailyQuest and not todayDailyCompletedInData and not todayDailyCompletedInClient then
		print("🔧 데일리 퀘스트 백업 생성:", plr.Name)
		local dailyQuest = createDailyPlaytimeQuest()
		dailyQuest.id = todayDailyId

		-- 데이터베이스에도 추가
		Data.Quests.ActiveQuests[todayDailyId] = dailyQuest
		datamanager:SafeSavePlayer(plr)

		-- 클라이언트 폴더에도 추가
		local questFolder = createQuest(dailyQuest, dailyQuest.id)
		if questFolder then
			questFolder.Parent = ActiveQuests
			playerBasePlaytime[plr.UserId] = 0  -- 새로 생성된 퀘스트는 0부터 시작
			playerSessionStartTime[plr.UserId] = tick()
			print("🔧 백업 데일리 퀘스트 생성 완료:", todayDailyId)
		end
	else
		print("🔧 데일리 퀘스트 백업 생성 스킵 - 이미 존재하거나 완료됨")

		-- 🔧 추가: 이미 활성 퀘스트가 있는 경우 진행도 복원
		if hasDailyQuest and existingDailyProgress > 0 then
			if not playerBasePlaytime[plr.UserId] then
				playerBasePlaytime[plr.UserId] = existingDailyProgress
				playerSessionStartTime[plr.UserId] = tick()
				print("🔧 기존 데일리 퀘스트 진행도 복원:", plr.Name, existingDailyProgress, "초")
			end
		end
	end

	-- 🔧 수정: 세션 시작 시간 설정 (플레이타임 퀘스트가 없었던 경우만)
	if not playerSessionStartTime[plr.UserId] then
		playerSessionStartTime[plr.UserId] = tick()
		-- 🔧 수정: 저장된 데이터가 있으면 그것을 사용, 없으면 0
		if not playerBasePlaytime[plr.UserId] then
			playerBasePlaytime[plr.UserId] = 0
		end
		print("🔧 세션 데이터 초기화:", plr.Name, "기준 플레이타임:", playerBasePlaytime[plr.UserId])
	end

	-- 🔧 추가: 최종 퀘스트 상태 로깅
	print("🔧 최종 퀘스트 상태:", plr.Name)
	print("  데이터베이스 활성 퀘스트:")
	for questId, questData in pairs(Data.Quests.ActiveQuests or {}) do
		print("    -", questId, "타입:", questData.questType, "진행:", questData.currentProgress .. "/" .. questData.requiredProgress)
	end
	print("  데이터베이스 완료 퀘스트:")
	for questId, _ in pairs(Data.Quests.CompletedQuests or {}) do
		print("    - 완료:", questId)
	end
	print("  클라이언트 활성 퀘스트:")
	for _, quest in pairs(ActiveQuests:GetChildren()) do
		if quest:IsA("Folder") then
			local questType = quest:FindFirstChild("QuestType")
			local isReceived = quest:FindFirstChild("IsReceived")
			print("    -", quest.Name, "타입:", questType and questType.Value or "없음", "받음:", isReceived and isReceived.Value or "없음")
		end
	end

	-- 🔧 수정: 플레이타임 업데이트 함수 (quest.Name을 미리 저장)
	local function updatePlaytimeQuest()
		if not playerSessionStartTime[plr.UserId] or not playerBasePlaytime[plr.UserId] then return end

		local leaderstats = plr:FindFirstChild("leaderstats")
		if not leaderstats then return end

		local quests = leaderstats:FindFirstChild("Quests")
		if not quests then return end

		local activeQuests = quests:FindFirstChild("ActiveQuests")
		if not activeQuests then return end

		-- 데일리 플레이타임 퀘스트 찾기
		for _, quest in pairs(activeQuests:GetChildren()) do
			if quest:IsA("Folder") then
				local questType = quest:FindFirstChild("QuestType")
				if questType and questType.Value == "daily_playtime" then
					local currentProgress = quest:FindFirstChild("CurrentProgress")
					local requiredProgress = quest:FindFirstChild("RequiredProgress")
					local rewardCoins = quest:FindFirstChild("RewardCoins")

					if currentProgress and requiredProgress and rewardCoins then
						-- 현재 세션 시간 계산
						local sessionTime = tick() - playerSessionStartTime[plr.UserId]
						-- 기준 플레이타임 + 현재 세션 시간
						local totalPlaytime = playerBasePlaytime[plr.UserId] + sessionTime

						-- 15분 달성시 자동 완료 및 보상
						if totalPlaytime >= requiredProgress.Value then
							-- 🔧 수정: quest.Name을 미리 저장 (삭제 전에)
							local questName = quest.Name

							-- 코인 지급
							local coins = leaderstats:FindFirstChild("Coins")
							if coins then
								coins.Value = coins.Value + rewardCoins.Value
								print("데일리 퀘스트 완료 - 보상 지급:", plr.Name, rewardCoins.Value)
							end

							-- 완료 기록을 CompletedQuests에 저장
							local completedQuests = quests:FindFirstChild("CompletedQuests")
							if completedQuests then
								local completedQuest = Instance.new("BoolValue")
								completedQuest.Name = questName
								completedQuest.Value = true
								completedQuest.Parent = completedQuests
								print("데일리 퀘스트 완료 기록 저장:", questName)
							end

							-- 퀘스트 삭제
							quest:Destroy()
							print("데일리 퀘스트 자동 완료 및 삭제:", plr.Name)

							-- 데이터베이스에서도 완료 기록 저장
							spawn(function()
								local Data = datamanager:GetData(plr)
								if Data then
									if not Data.Quests then Data.Quests = {} end
									if not Data.Quests.ActiveQuests then Data.Quests.ActiveQuests = {} end
									if not Data.Quests.CompletedQuests then Data.Quests.CompletedQuests = {} end

									-- 활성 퀘스트에서 제거
									Data.Quests.ActiveQuests[questName] = nil
									-- 완료 기록에 추가
									Data.Quests.CompletedQuests[questName] = true
									datamanager:SafeSavePlayer(plr)
									print("데이터베이스에 데일리 퀘스트 완료 기록 저장:", questName)
								end
							end)

							-- 추적 데이터 정리
							playerSessionStartTime[plr.UserId] = nil
							playerBasePlaytime[plr.UserId] = nil
							return
						else
							-- GUI 표시용 업데이트 (저장되지 않는 표시용)
							local displayProgress = math.min(math.floor(totalPlaytime), requiredProgress.Value)
							currentProgress.Value = displayProgress
						end
					end
				end
			end
		end
	end

	-- 1초마다 플레이타임 체크
	spawn(function()
		while plr.Parent and playerSessionStartTime[plr.UserId] do
			wait(1)
			updatePlaytimeQuest()
		end
	end)

	-- 물고기 잡기 감지 시스템
	local function updateQuestProgress(fishName)
		local leaderstats = plr:FindFirstChild("leaderstats")
		if not leaderstats then return end

		local quests = leaderstats:FindFirstChild("Quests")
		if not quests then return end

		local activeQuests = quests:FindFirstChild("ActiveQuests")
		if not activeQuests then return end

		-- 모든 활성 퀘스트 확인 (플레이타임 퀘스트 제외)
		for _, quest in pairs(activeQuests:GetChildren()) do
			if quest:IsA("Folder") then
				local targetFish = quest:FindFirstChild("TargetFish")
				local currentProgress = quest:FindFirstChild("CurrentProgress")
				local requiredProgress = quest:FindFirstChild("RequiredProgress")
				local isReceived = quest:FindFirstChild("IsReceived")
				local questName = quest:FindFirstChild("QuestName")
				local questType = quest:FindFirstChild("QuestType")

				-- 플레이타임 퀘스트가 아닌 경우만 처리
				if questType and questType.Value ~= "daily_playtime" and
					targetFish and currentProgress and requiredProgress and isReceived and questName then

					if isReceived.Value and targetFish.Value == fishName and currentProgress.Value < requiredProgress.Value then
						currentProgress.Value = currentProgress.Value + 1
						print("퀘스트 진행:", plr.Name, "→", questName.Value, currentProgress.Value .. "/" .. requiredProgress.Value)

						-- 데이터베이스에도 진행도 저장
						spawn(function()
							local Data = datamanager:GetData(plr)
							if Data and Data.Quests and Data.Quests.ActiveQuests then
								local questData = Data.Quests.ActiveQuests[quest.Name]
								if questData then
									questData.currentProgress = currentProgress.Value
									datamanager:SafeSavePlayer(plr)
								end
							end
						end)

						if currentProgress.Value >= requiredProgress.Value then
							print("퀘스트 달성:", plr.Name, "→", questName.Value)
						end
					end
				end
			end
		end
	end

	-- 캐릭터 스폰 시 백팩 감지 설정
	plr.CharacterAdded:Connect(function(character)
		local backpack = plr:FindFirstChild("Backpack")
		if not backpack then return end

		backpack.ChildAdded:Connect(function(item)
			if item:IsA("Tool") and item:FindFirstChild("FishValue") then
				updateQuestProgress(item.Name)
			end
		end)
	end)

	-- 이미 캐릭터가 있다면 즉시 설정
	if plr.Character then
		local backpack = plr:FindFirstChild("Backpack")
		if backpack then
			backpack.ChildAdded:Connect(function(item)
				if item:IsA("Tool") and item:FindFirstChild("FishValue") then
					updateQuestProgress(item.Name)
				end
			end)
		end
	end
end)

-- 🔧 완전 수정된 PlayerRemoving 이벤트
players.PlayerRemoving:Connect(function(plr)
	print("🔧 플레이어 나가기 시작:", plr.Name)

	-- 플레이타임을 데이터베이스에 저장
	if playerSessionStartTime[plr.UserId] and playerBasePlaytime[plr.UserId] then
		print("🔧 플레이타임 저장 시작:", plr.Name)

		-- 현재 총 플레이타임 계산
		local sessionTime = tick() - playerSessionStartTime[plr.UserId]
		local finalPlaytime = playerBasePlaytime[plr.UserId] + sessionTime

		print("🔧 플레이타임 계산:", plr.Name, "기준:", playerBasePlaytime[plr.UserId], "세션:", sessionTime, "최종:", finalPlaytime)

		-- 데이터베이스에 즉시 저장
		local Data = datamanager:GetData(plr)
		if Data and Data.Quests and Data.Quests.ActiveQuests then
			-- 데일리 플레이타임 퀘스트 찾아서 업데이트
			for questId, questData in pairs(Data.Quests.ActiveQuests) do
				if questData.questType == "daily_playtime" then
					questData.currentProgress = math.floor(finalPlaytime)
					print("🔧 데이터베이스에 플레이타임 저장:", plr.Name, questId, questData.currentProgress, "초")
					break
				end
			end

			-- 보이드 퀘스트 최종 저장 확인
			local voidQuest = Data.Quests.ActiveQuests["void_unknown_challenge"]
			if voidQuest then
				print("🔧 플레이어 퇴장 시 보이드 퀘스트 저장:", plr.Name, "진행도:", voidQuest.currentProgress)
			end

			-- 최종 저장 실행
			datamanager:SafeSavePlayer(plr)
			print("🔧 최종 데이터 저장 완료:", plr.Name)
		else
			warn("🔧 데이터 저장 실패 - 데이터 없음:", plr.Name)
		end

		-- 클라이언트 폴더에서도 업데이트 (혹시 남아있다면)
		local leaderstats = plr:FindFirstChild("leaderstats")
		if leaderstats then
			local quests = leaderstats:FindFirstChild("Quests")
			if quests then
				local activeQuests = quests:FindFirstChild("ActiveQuests")
				if activeQuests then
					for _, quest in pairs(activeQuests:GetChildren()) do
						if quest:IsA("Folder") then
							local questType = quest:FindFirstChild("QuestType")
							if questType and questType.Value == "daily_playtime" then
								local currentProgress = quest:FindFirstChild("CurrentProgress")
								if currentProgress then
									currentProgress.Value = math.floor(finalPlaytime)
									print("🔧 클라이언트 폴더 플레이타임 업데이트:", plr.Name, currentProgress.Value)
								end
								break
							end
						end
					end
				end
			end
		end
	else
		print("🔧 플레이타임 저장 스킵 - 세션 데이터 없음:", plr.Name)
	end

	-- 🔧 추가: 보이드 퀘스트 최종 저장 확인
	local Data = datamanager:GetData(plr)
	if Data and Data.Quests and Data.Quests.ActiveQuests then
		local voidQuest = Data.Quests.ActiveQuests["void_unknown_challenge"]
		if voidQuest then
			print("🔧 플레이어 퇴장 시 보이드 퀘스트 저장:", plr.Name, "진행도:", voidQuest.currentProgress)
			-- 추가 저장 보장
			datamanager:SafeSavePlayer(plr)
		end
	end

	-- 세션 데이터 정리
	playerSessionStartTime[plr.UserId] = nil
	playerBasePlaytime[plr.UserId] = nil
	print("🔧 플레이어 나가기 완료:", plr.Name)
end)
