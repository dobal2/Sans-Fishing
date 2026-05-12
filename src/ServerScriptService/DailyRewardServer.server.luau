-- ServerScriptService에 넣을 서버 스크립트
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- 데이터스토어 설정
local DailyRewardStore = DataStoreService:GetDataStore("DailyRewards")

-- 리모트 이벤트 생성
local RemoteEvents = Instance.new("Folder")
RemoteEvents.Name = "RemoteEvents"
RemoteEvents.Parent = ReplicatedStorage

local ClaimDailyReward = Instance.new("RemoteEvent")
ClaimDailyReward.Name = "ClaimDailyReward"
ClaimDailyReward.Parent = RemoteEvents

local CheckDailyReward = Instance.new("RemoteEvent")
CheckDailyReward.Name = "CheckDailyReward"
CheckDailyReward.Parent = RemoteEvents

-- 일일 보상 설정 (날짜별로 다른 보상)
local DAILY_REWARDS = {
	[1] = {type = "Coins", amount = 2000, name = "2000 Coins"},
	[2] = {type = "Bubble", toolName = "Strength Bubble", name = "Strength Bubble"},
	[3] = {type = "Coins", amount = 10000, name = "10000 Coins"},
	[4] = {type = "Bubble", toolName = "SizeBuff Bubble", name = "SizeBuff Bubble"},
	[5] = {type = "Coins", amount = 30000, name = "30000 Coins"},
	[6] = {type = "Bubble", toolName = "Luck Bubble", name = "Luck Bubble"},
	[7] = {type = "Coins", amount = 200000, name = "200000 Coins"}
}

-- 해킹 방지를 위한 요청 제한
local PlayerRequestTimes = {}
local REQUEST_COOLDOWN = 1 -- 1초 쿨다운

-- 현재 날짜 가져오기 (UTC 기준)
local function getCurrentDay()
	return math.floor(os.time() / 86400) -- 86400초 = 하루
end

-- 연속 출석일 계산
local function getConsecutiveDays(lastClaimDay, currentDay)
	if lastClaimDay == nil then
		return 0
	elseif currentDay - lastClaimDay == 1 then
		return 1 -- 연속
	else
		return 0 -- 연속 끊김
	end
end

-- 플레이어 데이터 로드
local function loadPlayerData(player)
	local success, data = pcall(function()
		return DailyRewardStore:GetAsync(player.UserId)
	end)

	if success and data then
		return data
	else
		return {
			lastClaimDay = nil,
			consecutiveDays = 0
		}
	end
end

-- 플레이어 데이터 저장
local function savePlayerData(player, data)
	local success = pcall(function()
		DailyRewardStore:SetAsync(player.UserId, data)
	end)
	return success
end

-- 해킹 방지: 요청 제한 확인
local function canMakeRequest(player)
	local userId = player.UserId
	local currentTime = tick()

	if PlayerRequestTimes[userId] then
		if currentTime - PlayerRequestTimes[userId] < REQUEST_COOLDOWN then
			return false
		end
	end

	PlayerRequestTimes[userId] = currentTime
	return true
end

-- 보상 지급
local function giveReward(player, reward)
	if reward.type == "Coins" then
		-- 리더스탯에 돈 추가 (leaderstats가 있다고 가정)
		local leaderstats = player:WaitForChild("leaderstats")
		if leaderstats then
			local money = leaderstats:WaitForChild("leaderstats")
			if money then
				money.Value = money.Value + reward.amount
				return true
			end
		end

	elseif reward.type == "Bubble" then
		-- 백팩에 툴 추가
		local tool = game:GetService("ServerStorage"):WaitForChild("Bubbles"):FindFirstChild(reward.toolName)
		if tool then
			local clonedTool = tool:Clone()
			clonedTool.Parent = player.Backpack
			return true
		end
	end

	return false
end

-- 일일 보상 확인
CheckDailyReward.OnServerEvent:Connect(function(player)
	if not canMakeRequest(player) then
		return -- 스팸 방지
	end

	local playerData = loadPlayerData(player)
	local currentDay = getCurrentDay()

	-- 오늘 이미 받았는지 확인
	local canClaim = playerData.lastClaimDay ~= currentDay
	local consecutiveDays = playerData.consecutiveDays

	if playerData.lastClaimDay and currentDay - playerData.lastClaimDay == 1 then
		consecutiveDays = consecutiveDays + 1
	elseif playerData.lastClaimDay ~= currentDay then
		consecutiveDays = 1
	end

	-- 7일 넘으면 1일부터 다시 시작
	if consecutiveDays > 7 then
		consecutiveDays = 1
	end

	local nextReward = DAILY_REWARDS[consecutiveDays]

	CheckDailyReward:FireClient(player, {
		canClaim = canClaim,
		consecutiveDays = consecutiveDays,
		nextReward = nextReward
	})
end)

-- 일일 보상 수령
ClaimDailyReward.OnServerEvent:Connect(function(player)
	if not canMakeRequest(player) then
		return -- 스팸 방지
	end

	local playerData = loadPlayerData(player)
	local currentDay = getCurrentDay()

	-- 중복 수령 방지
	if playerData.lastClaimDay == currentDay then
		ClaimDailyReward:FireClient(player, {
			success = false,
			message = "오늘은 이미 보상을 받으셨습니다!"
		})
		return
	end

	-- 연속 출석일 계산
	local consecutiveDays = playerData.consecutiveDays
	if playerData.lastClaimDay and currentDay - playerData.lastClaimDay == 1 then
		consecutiveDays = consecutiveDays + 1
	else
		consecutiveDays = 1
	end

	-- 7일 넘으면 1일부터 다시 시작
	if consecutiveDays > 7 then
		consecutiveDays = 1
	end

	local reward = DAILY_REWARDS[consecutiveDays]

	-- 보상 지급
	local success = giveReward(player, reward)

	if success then
		-- 데이터 업데이트
		playerData.lastClaimDay = currentDay
		playerData.consecutiveDays = consecutiveDays

		local saveSuccess = savePlayerData(player, playerData)

		if saveSuccess then
			ClaimDailyReward:FireClient(player, {
				success = true,
				reward = reward,
				consecutiveDays = consecutiveDays
			})
		else
			ClaimDailyReward:FireClient(player, {
				success = false,
				message = "데이터 저장 오류가 발생했습니다."
			})
		end
	else
		ClaimDailyReward:FireClient(player, {
			success = false,
			message = "보상 지급 중 오류가 발생했습니다."
		})
	end
end)

-- 플레이어 퇴장 시 요청 기록 정리
Players.PlayerRemoving:Connect(function(player)
	PlayerRequestTimes[player.UserId] = nil
end)
