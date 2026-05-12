-- ServerScript (ServerScriptService에 넣기)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RemoteFunction 생성
local getFriendsCountRemote = Instance.new("RemoteFunction")
getFriendsCountRemote.Name = "GetFriendsCountRemote"
getFriendsCountRemote.Parent = ReplicatedStorage

-- 🛡️ 레이트 리미팅 시스템
local playerCooldowns = {}
local COOLDOWN_TIME = 3  -- 3초 쿨다운
local MAX_REQUESTS_PER_MINUTE = 20  -- 1분에 최대 20번
local playerRequestCounts = {}

-- 친구 수 계산 함수
local function getFriendsOnlineCount(player)
	local friendsCount = 0

	-- 현재 서버에 있는 모든 플레이어 확인
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			-- 친구인지 확인
			local success, isFriend = pcall(function()
				return player:IsFriendsWith(otherPlayer.UserId)
			end)

			if success and isFriend then
				friendsCount = friendsCount + 1
			end
		end
	end

	return friendsCount
end

-- 🛡️ 레이트 리미팅 체크 함수
local function isRateLimited(player)
	local userId = player.UserId
	local currentTime = tick()

	-- 쿨다운 체크
	if playerCooldowns[userId] and currentTime - playerCooldowns[userId] < COOLDOWN_TIME then
		local remainingTime = COOLDOWN_TIME - (currentTime - playerCooldowns[userId])
		--warn("🛡️ " .. player.Name .. " 쿨다운 중 (남은 시간: " .. math.ceil(remainingTime) .. "초)")
		return true
	end

	-- 1분간 요청 횟수 체크
	if not playerRequestCounts[userId] then
		playerRequestCounts[userId] = {requests = {}, count = 0}
	end

	local requests = playerRequestCounts[userId].requests

	-- 1분 이전 요청들 제거
	for i = #requests, 1, -1 do
		if currentTime - requests[i] > 60 then
			table.remove(requests, i)
		end
	end

	-- 요청 횟수 체크
	if #requests >= MAX_REQUESTS_PER_MINUTE then
		warn("🛡️ " .. player.Name .. " 1분간 최대 요청 횟수 초과 (" .. #requests .. "/" .. MAX_REQUESTS_PER_MINUTE .. ")")
		return true
	end

	return false
end

-- 🛡️ 요청 기록 함수
local function recordRequest(player)
	local userId = player.UserId
	local currentTime = tick()

	playerCooldowns[userId] = currentTime

	if not playerRequestCounts[userId] then
		playerRequestCounts[userId] = {requests = {}}
	end

	table.insert(playerRequestCounts[userId].requests, currentTime)
end

-- 클라이언트 요청 처리
getFriendsCountRemote.OnServerInvoke = function(player)
	-- 🛡️ 레이트 리미팅 체크
	if isRateLimited(player) then
		return 0  -- 제한된 경우 0 반환
	end

	-- 🛡️ 요청 기록
	recordRequest(player)

	-- 친구 수 계산
	local friendsCount = getFriendsOnlineCount(player)
	--print(player.Name .. "의 온라인 친구 수:", friendsCount, "(보너스: " .. (friendsCount * 5) .. "%)")
	return friendsCount
end

-- 🧹 플레이어 나갈 때 데이터 정리
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	playerCooldowns[userId] = nil
	playerRequestCounts[userId] = nil
	--print(player.Name .. " 데이터 정리 완료")
end)
