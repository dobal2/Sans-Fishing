local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ProfileService = require(script.ProfileService)

local DATA_TEMPLATE = { -- 데이터 템플릿
	Quests = {
		ActiveQuests = {};
		CompletedQuests = {};
	};
	LastQuestDate = nil;
	VoidQuestInitialized = false;
}

local function createVoidQuest()
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

local function forceInitializeVoidQuest(profile)
	local data = profile.Data

	print("강제 보이드 퀘스트 초기화 시작")

	-- 데이터 구조 강제 생성
	if not data.Quests then
		data.Quests = {}
		print("Quests 폴더 강제 생성")
	end
	if not data.Quests.ActiveQuests then
		data.Quests.ActiveQuests = {}
		print("ActiveQuests 폴더 강제 생성")
	end
	if not data.Quests.CompletedQuests then
		data.Quests.CompletedQuests = {}
		print("CompletedQuests 폴더 강제 생성")
	end

	-- 보이드 퀘스트가 완료되었는지 확인
	if data.Quests.CompletedQuests["void_unknown_challenge"] then
		print("보이드 퀘스트 이미 완료됨 - 초기화 스킵")
		data.VoidQuestInitialized = true
		return
	end

	-- 활성 퀘스트에 보이드 퀘스트가 있는지 확인
	if data.Quests.ActiveQuests["void_unknown_challenge"] then
		print("보이드 퀘스트가 이미 존재함")
		local existingQuest = data.Quests.ActiveQuests["void_unknown_challenge"]
		if existingQuest.requiredProgress ~= 4 then
			existingQuest.requiredProgress = 4
			print("기존 보이드 퀘스트 requiredProgress를 4로 업데이트")
		end
		data.VoidQuestInitialized = true
		return
	end

	-- 보이드 퀘스트 강제 생성
	local voidQuest = createVoidQuest()
	data.Quests.ActiveQuests[voidQuest.id] = voidQuest
	data.VoidQuestInitialized = true

	print("보이드 퀘스트 강제 생성 완료:", voidQuest.id)

	-- 즉시 저장
	local success, err = pcall(function()
		profile:Save()
	end)

	if success then
		print("보이드 퀘스트 데이터 즉시 저장 성공")
	else
		warn("보이드 퀘스트 데이터 저장 실패:", err)
	end
end

local ProfileStore = ProfileService.GetProfileStore("QuestData4", DATA_TEMPLATE)

local Profiles = {}

local function HandleLockedUpdate(globalUpdates, update)
	local id = update[1]
	local data = update[2]
	globalUpdates:ClearLockedUpdate(id)
end

-- 플레이어 접속 이벤트 발생 시 호출되는 함수
local function OnPlayerAdded(player)
	print("프로필 로드 시작:", player.Name)

	-- 플레이어 프로필 데이터를 불러옴
	local profile = ProfileStore:LoadProfileAsync(
		"QuestPlayer_"..player.UserId,
		"ForceLoad"
	)

	-- 프로필 데이터가 있으면
	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile() -- 템플릿 추가항목 있으면 자동 적용

		-- release 이벤트 발생 시 실행될 코드 등록
		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick()
		end)

		-- 플레이어가 게임에 접속 되었으면 데이터 캐싱.
		if player:IsDescendantOf(Players) then
			Profiles[player] = profile

			print("프로필 로드 성공:", player.Name)
			print("기존 VoidQuestInitialized:", profile.Data.VoidQuestInitialized)

			-- 강제 보이드 퀘스트 초기화
			forceInitializeVoidQuest(profile)

			print("강제 초기화 후 VoidQuestInitialized:", profile.Data.VoidQuestInitialized)

			local globalUpdates = profile.GlobalUpdates

			for index, update in pairs(globalUpdates:GetActiveUpdates())do
				globalUpdates:LockActiveUpdate(update[1])
			end

			for index, update in pairs(globalUpdates:GetLockedUpdates())do
				HandleLockedUpdate(globalUpdates, update)
			end

			globalUpdates:ListenToNewActiveUpdate(function(id, data)
				globalUpdates:LockActiveUpdate(id)
			end)

			globalUpdates:ListenToNewLockedUpdate(function(id, data)
				HandleLockedUpdate(globalUpdates, {id, data})
			end)

		else
			--profile:Release()
		end
	else
		player:Kick("Quest data loading failed, Please try again")
	end
end
Players.PlayerAdded:Connect(OnPlayerAdded)

local function OnPlayerRemoving(player)
	local profile = Profiles[player]
	if profile then
		profile:Save()
		profile:Release()
	end
end
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-----------------------모듈-------------------------

local DataManager = {}

-- 플레이어 데이터 반환하는 함수
function DataManager:GetData(player)
	local profile = Profiles[player]

	if profile then
		-- 데이터 반환 전 보이드 퀘스트 재확인
		if not profile.Data.VoidQuestInitialized then
			print("데이터 반환 시 보이드 퀘스트 재확인:", player.Name)
			forceInitializeVoidQuest(profile)
		end

		return profile.Data
	else
		return nil
	end
end

function DataManager:GetProfileStore()
	return ProfileStore
end

--데이터 업데이트
function DataManager:UpdateData(player, key, data)
	local profile = Profiles[player]

	-- profile이 없으면 강제로 불러오기
	if not profile then
		profile = ProfileStore:LoadProfileAsync("QuestPlayer_"..player.UserId, "ForceLoad")
		if profile then
			profile:Reconcile()
			Profiles[player] = profile
			forceInitializeVoidQuest(profile)  -- 보이드 퀘스트 초기화
			print("퀘스트 프로필이 nil이어서 강제로 로드함", player)
		else
			warn("UpdateData 실패: 퀘스트 프로필 로드 실패", player, key)
			return
		end
	end

	profile.Data[key] = data
	print("UpdateData 성공:", player.Name, key, data)
end

local function getCurrentDateString()
	local currentTime = os.time()
	local date = os.date("*t", currentTime)
	return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

function DataManager:SafeSavePlayer(player)
	local profile = Profiles[player]
	if not profile then
		warn("Save 실패 - 퀘스트 프로필 없음:", player)
		return
	end

	-- 🔧 추가: 기존 void quest 백업
	local existingVoidQuest = nil
	if profile.Data.Quests and profile.Data.Quests.ActiveQuests then
		existingVoidQuest = profile.Data.Quests.ActiveQuests["void_unknown_challenge"]
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local questsFolder = leaderstats:FindFirstChild("Quests")

	-- 퀘스트 데이터 저장
	local questsData = {
		ActiveQuests = {},
		CompletedQuests = {}
	}

	if questsFolder then
		local activeQuests = questsFolder:FindFirstChild("ActiveQuests")
		local completedQuests = questsFolder:FindFirstChild("CompletedQuests")

		-- 활성 퀘스트 저장
		if activeQuests then
			for _, quest in ipairs(activeQuests:GetChildren()) do
				if quest:IsA("Folder") then
					local questName = quest:FindFirstChild("QuestName")
					local questDescription = quest:FindFirstChild("QuestDescription")
					local targetFish = quest:FindFirstChild("TargetFish")
					local currentProgress = quest:FindFirstChild("CurrentProgress")
					local requiredProgress = quest:FindFirstChild("RequiredProgress")
					local rewardCoins = quest:FindFirstChild("RewardCoins")
					local isReceived = quest:FindFirstChild("IsReceived")
					local questType = quest:FindFirstChild("QuestType")

					if questName and questDescription and currentProgress and requiredProgress and rewardCoins and isReceived then
						questsData.ActiveQuests[quest.Name] = {
							id = quest.Name,
							name = questName.Value,
							description = questDescription.Value,
							targetFish = targetFish and targetFish.Value or "",
							currentProgress = currentProgress.Value,
							requiredProgress = requiredProgress.Value,
							rewardCoins = rewardCoins.Value,
							isReceived = isReceived.Value,
							questType = questType and questType.Value or "normal"
						}
						print("퀘스트 저장:", quest.Name, "타입:", questType and questType.Value or "normal")
					end
				end
			end
		end

		-- 🔧 추가: void quest 강제 보존
		if existingVoidQuest and not questsData.ActiveQuests["void_unknown_challenge"] then
			questsData.ActiveQuests["void_unknown_challenge"] = existingVoidQuest
			print("🔧 void quest 강제 보존:", existingVoidQuest.currentProgress or 0)
		end

		-- 완료된 퀘스트 저장
		if completedQuests then
			for questId, isCompleted in pairs(profile.Data.Quests.CompletedQuests or {}) do
				questsData.CompletedQuests[questId] = isCompleted
			end

			for _, quest in ipairs(completedQuests:GetChildren()) do
				if quest:IsA("BoolValue") then
					questsData.CompletedQuests[quest.Name] = quest.Value
					print("완료된 퀘스트 저장:", quest.Name, quest.Value)
				end
			end
		else
			questsData.CompletedQuests = profile.Data.Quests.CompletedQuests or {}
		end
	end

	profile.Data.LastQuestDate = profile.Data.LastQuestDate or getCurrentDateString()
	profile.Data.Quests = questsData

	-- 🔧 추가: void quest 최종 확인 및 복원
	if not profile.Data.Quests.ActiveQuests["void_unknown_challenge"] and
		not profile.Data.Quests.CompletedQuests["void_unknown_challenge"] then

		local voidQuest = createVoidQuest()
		if existingVoidQuest then
			voidQuest.currentProgress = existingVoidQuest.currentProgress or 0
		end

		profile.Data.Quests.ActiveQuests["void_unknown_challenge"] = voidQuest
		print("🔧 SafeSavePlayer에서 void quest 강제 생성/복원")
	end

	print("퀘스트 저장 완료:", player.Name)

	local success, err = pcall(function()
		profile:Save()
	end)
	if not success then
		warn("퀘스트 Save 실패:", player.Name, err)
	else
		print("퀘스트 데이터 저장 성공:", player.Name)
	end
end

-- 데이터스토어 저장
function DataManager:SaveData(player)
	Profiles[player]:Save()
end

-- 특정 플레이어 데이터 초기화
local RunService = game:GetService("RunService")
function DataManager:ClearData(player)
	if RunService:IsStudio() and RunService:IsServer() then
		local profile = Profiles[player] or ProfileStore:LoadProfileAsync(
			"QuestPlayer_"..player.UserId,
			"ForceLoad"
		)
		profile["Data"] = DATA_TEMPLATE
		player:Kick("Quest Data Cleared")
	end
end

return DataManager
