local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local CoinLeaderboard = DataStoreService:GetOrderedDataStore("CoinLeaderboard")
local DonationLeaderboard = DataStoreService:GetOrderedDataStore("DonationLeaderboard")
local PlaytimeLeaderboard = DataStoreService:GetOrderedDataStore("PlaytimeLeaderBoard")
local ProfileService = require(script.ProfileService)

local DATA_TEMPLATE = { -- 데이터 템플릿
	Coins = 2000;
	Donations = 0;
	CurrentRod = "FishingRod";
	CurrentFishTrap = "";
	IsTutorialed = false;
	Playtime = 0;
}

local sessionStartTimes = {}

local ProfileStore = ProfileService.GetProfileStore("StoreName", DATA_TEMPLATE)

local Profiles = {}

local function HandleLockedUpdate(globalUpdates, update)
	local id = update[1] --update[1]은 데이터 Id
	local data = update[2] --update[2]가 데이터 정보

	globalUpdates:ClearLockedUpdate(id)
end

-- 플레이어 접속 이벤트 발생 시 호출되는 함수
local function OnPlayerAdded(player)

	-- 플레이어 프로필 데이터를 불러옴
	local profile = ProfileStore:LoadProfileAsync(
		-- 키 값
		"Player_"..player.UserId,

		-- 프로필이 다른 서버에서 사용 중으로 인해 잠긴 경우 어떻게 할지에 대한 인자 부분
		-- 잠겨있는 상태에서 그냥 바로 가져와버리는 속성이 "ForceLoad" (사용 중이었던 다른 서버에서에서는 강제로 release됨)
		"ForceLoad"
	)
	-- 프로필 데이터가 있으면
	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile() -- 템플릿 추가항목 있으면 자동 적용
		-- release 이벤트 발생 시 실행될 코드 등록
		profile:ListenToRelease(function() -- 아래 profile:Release()에서 이어지는 부분
			Profiles[player] = nil --Profiles 테이블도 정리
			player:Kick() -- 확실한 플레이어 종료 보장
		end)

		-- 플레이어가 game.Players의 자식이면(플레이어가 게임에 접속 되었으면) true 반환, 데이터 캐싱.
		-- 로딩 도중 플레이어가 종료한 경우 대비
		if player:IsDescendantOf(Players) then
			Profiles[player] = profile

			local userId = tostring(player.UserId)
			local coins = profile.Data.Coins or 0
			pcall(function()
				CoinLeaderboard:SetAsync(userId, coins)
			end)

			local playtime = profile.Data.Playtime or 0
			sessionStartTimes[player.UserId] = tick() -- 세션 시작 시간 기록
			pcall(function()
				PlaytimeLeaderboard:SetAsync(userId, playtime)
			end)

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
			profile:Release()
			-- 플레이어 나간 경우 데이터 테이블 정리를 위해 release호출
			-- 위의 profile:ListenToRelease로 이어짐
		end
	else
		player:Kick("Data loading failed, Please try again")
	end
end
Players.PlayerAdded:Connect(OnPlayerAdded)

local function OnPlayerRemoving(player)
	local profile = Profiles[player]
	if profile then
		local sessionStart = sessionStartTimes[player.UserId]
		if sessionStart then
			local sessionTime = math.floor(tick() - sessionStart)
			local totalPlaytime = (profile.Data.Playtime or 0) + sessionTime
			profile.Data.Playtime = totalPlaytime

			-- 플레이타임 리더보드 업데이트
			local userId = tostring(player.UserId)
			pcall(function()
				PlaytimeLeaderboard:SetAsync(userId, totalPlaytime)
			end)
		end
		profile:Save()
		profile:Release()-- 플레이어 나간 경우 데이터 테이블 정리를 위해 release호출
	end
end
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-----------------------모듈-------------------------

local DataManager = {}

-- 플레이어 데이터 반환하는 함수
function DataManager:GetData(player)
	local profile = Profiles[player]

	if profile then
		return profile.Data
	else
		return nil
	end
end

function DataManager:GetProfileStore()
	return ProfileStore
end

-- 모듈 정의 후 맨 아래에 이동
game:GetService("ReplicatedStorage").ChildAdded:Connect(function(child)
	if child.Name:find("DeleteTrapData_") and child:IsA("StringValue") then
		local parts = string.split(child.Name, "_")
		if #parts >= 3 then
			local ownerName = parts[2]
			local trapId = parts[3]

			print("메인 DataManager - 통발 삭제 신호 감지:", ownerName, trapId)

			local player = Players:FindFirstChild(ownerName)
			if player then
				-- 온라인 플레이어: 직접 프로필에서 삭제
				local profile = Profiles[player]
				if profile then
					profile.Data["FishTrapData_" .. ownerName .. "_" .. trapId] = nil
					print("메인 DataManager에서 통발 데이터 삭제 완료:", ownerName, trapId)
				end
			else
				-- 오프라인 플레이어: 프로필을 로드해서 삭제
				local success, userId = pcall(function()
					return Players:GetUserIdFromNameAsync(ownerName)
				end)

				if success then
					local offlineProfile = ProfileStore:LoadProfileAsync("Player_" .. userId, "ForceLoad")
					if offlineProfile then
						offlineProfile.Data["FishTrapData_" .. ownerName .. "_" .. trapId] = nil
						offlineProfile:Save()
						offlineProfile:Release()
						print("오프라인 플레이어 통발 데이터 삭제 완료:", ownerName, trapId)
					else
						warn("오프라인 플레이어 프로필 로드 실패:", ownerName)
					end
				else
					warn("플레이어 이름을 UserId로 변환 실패:", ownerName)
				end
			end
		end
	end
end)

--데이터 업데이트, 현재 세션에만 저장되며 데이터스토어 저장을 위해선 SaveData()를 불러야 함
function DataManager:UpdateData(player, key, data)
	local profile = Profiles[player]

	-- ✅ profile이 없으면 강제로 불러오기
	if not profile then
		profile = ProfileStore:LoadProfileAsync("Player_"..player.UserId, "ForceLoad")
		if profile then
			profile:Reconcile()
			Profiles[player] = profile
			print("⚠️ 프로필이 nil이어서 강제로 로드함", player)
		else
			warn("❌ UpdateData 실패: 프로필 로드 실패", player, key)
			return
		end
	end

	profile.Data[key] = data

	if key == "Coins" then
		local userId = tostring(player.UserId)
		local success, err = pcall(function()
			CoinLeaderboard:SetAsync(userId, data)
		end)

		if not success then
			warn("❌ [Leaderboard Save Failed] UserId:", userId, "Error:", err)
		end
	elseif key == "Donations" then -- 추가
		local userId = tostring(player.UserId)
		local success, err = pcall(function()
			DonationLeaderboard:SetAsync(userId, data)
		end)
		if not success then
			warn("Donation Leaderboard Save Failed:", err)
		end
	end

	print("✅ UpdateData 성공:", player.Name, key, data)
end

function DataManager:GetTopDonationPlayers(limit) -- 추가
	local top = {}
	limit = limit or 10

	local success, pages = pcall(function()
		return DonationLeaderboard:GetSortedAsync(false, limit)
	end)

	if not success then
		warn("DonationLeaderboard:GetSortedAsync failed")
		return {}
	end

	local data = pages:GetCurrentPage()
	for i, entry in ipairs(data) do
		local userId = tonumber(entry.key)
		local donations = entry.value
		table.insert(top, {
			UserId = userId,
			Donations = donations,
			Rank = i
		})
	end
	return top
end

-- 상위 코인 랭킹 N명 가져오기
function DataManager:GetTopCoinPlayers(limit)
	local top = {}
	limit = limit or 10 -- 기본 10명

	local success, pages = pcall(function()
		return CoinLeaderboard:GetSortedAsync(false, limit) -- false: 내림차순
	end)

	if not success then
		warn("⚠️ [Leaderboard] GetSortedAsync 실패")
		return {}
	end

	local data = pages:GetCurrentPage()
	for i, entry in ipairs(data) do
		local userId = tonumber(entry.key)
		local coins = entry.value
		table.insert(top, {
			UserId = userId,
			Coins = coins,
			Rank = i,
		})
	end

	return top
end

function DataManager:GetCurrentPlaytime(player)
	local profile = Profiles[player]
	if not profile then return 0 end

	local basePlaytime = profile.Data.Playtime or 0
	local sessionStart = sessionStartTimes[player.UserId]

	if sessionStart then
		local sessionTime = math.floor(tick() - sessionStart)
		return basePlaytime + sessionTime
	else
		return basePlaytime
	end
end

-- 상위 플레이타임 플레이어 가져오기
function DataManager:GetTopPlaytimePlayers(limit)
	local top = {}
	limit = limit or 10

	local success, pages = pcall(function()
		return PlaytimeLeaderboard:GetSortedAsync(false, limit)
	end)

	if not success then
		warn("PlaytimeLeaderboard:GetSortedAsync failed")
		return {}
	end

	local data = pages:GetCurrentPage()
	for i, entry in ipairs(data) do
		local userId = tonumber(entry.key)
		local playtime = entry.value
		table.insert(top, {
			UserId = userId,
			Playtime = playtime,
			Rank = i
		})
	end
	return top
end

-- 플레이타임 수동 업데이트 (5분마다 호출용)
function DataManager:UpdatePlaytime(player)
	local profile = Profiles[player]
	local sessionStart = sessionStartTimes[player.UserId]

	if profile and sessionStart then
		local sessionTime = math.floor(tick() - sessionStart)
		local totalPlaytime = (profile.Data.Playtime or 0) + sessionTime
		profile.Data.Playtime = totalPlaytime

		-- 리더보드 업데이트
		local userId = tostring(player.UserId)
		pcall(function()
			PlaytimeLeaderboard:SetAsync(userId, totalPlaytime)
		end)

		-- 세션 시작 시간 재설정
		sessionStartTimes[player.UserId] = tick()

		return totalPlaytime
	end
	return 0
end

function DataManager:SafeSavePlayer(player)
	local profile = Profiles[player]
	if not profile then
		warn("❌ Save 실패 - 프로필 없음:", player)
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local isTutorialed = player:FindFirstChild("IsTutorialed")
	if not leaderstats then return end

	local coins = leaderstats:FindFirstChild("Coins")
	local currentRod = leaderstats:FindFirstChild("CurrentRod")
	local rodsFolder = leaderstats:FindFirstChild("Rods")
	local FishFolder = leaderstats:FindFirstChild("Fish")
	local boatFolder = leaderstats:FindFirstChild("Boats")

	-- 🔮 인첸트 관련 추가
	local enchantsFolder = leaderstats:FindFirstChild("Enchants")
	local rodEnchantsFolder = leaderstats:FindFirstChild("RodEnchants")  -- 이 줄 추가

	local fishTrapFolder = leaderstats:FindFirstChild("FishTraps")

	local currentFishTrap = leaderstats:FindFirstChild("CurrentFishTrap")
	if currentFishTrap and currentFishTrap:FindFirstChild("Value") then
		profile.Data.CurrentFishTrap = currentFishTrap.Value.Value
	end

	-- 🔮 로드별 인첸트 데이터 저장
	local RodEnchantsData = {}
	if rodEnchantsFolder then
		for _, rodEnchant in ipairs(rodEnchantsFolder:GetChildren()) do
			if rodEnchant:IsA("StringValue") then
				RodEnchantsData[rodEnchant.Name] = rodEnchant.Value
			end
		end
	end
	profile.Data.RodEnchants = RodEnchantsData

	-- 🔮 인첸트 데이터 저장
	local EnchantsData = {}
	if enchantsFolder then
		for _, enchant in ipairs(enchantsFolder:GetChildren()) do
			if enchant:IsA("BoolValue") then
				EnchantsData[enchant.Name] = enchant.Value
			end
		end
	end
	profile.Data.Enchants = EnchantsData

	-- 기존 FishTraps 저장
	local FishTrapsData = {}
	if fishTrapFolder then
		for _, fishTrap in ipairs(fishTrapFolder:GetChildren()) do
			if fishTrap:IsA("BoolValue") then
				FishTrapsData[fishTrap.Name] = fishTrap.Value
			end
		end
	end
	profile.Data.FishTraps = FishTrapsData

	if coins then
		profile.Data.Coins = coins.Value

		-- ✅ 리더보드도 업데이트
		local userId = tostring(player.UserId)
		local success, err = pcall(function()
			CoinLeaderboard:SetAsync(userId, coins.Value)
		end)
		if not success then
			warn("❌ [Leaderboard Save Failed] UserId:", userId, "Error:", err)
		end
	end

	if currentRod then
		profile.Data.CurrentRod = currentRod.Value
	end

	if isTutorialed then
		profile.Data.IsTutorialed = isTutorialed.Value
	end

	local rodsData = {}
	if rodsFolder then
		for _, rod in ipairs(rodsFolder:GetChildren()) do
			if rod:IsA("BoolValue") then
				rodsData[rod.Name] = rod.Value
			end
		end
	end
	profile.Data.Rods = rodsData

	local FishData = {}
	if FishFolder then
		for _, fish in ipairs(FishFolder:GetChildren()) do
			if fish:IsA("BoolValue") then
				FishData[fish.Name] = fish.Value
			end
		end
	end
	profile.Data.Fish = FishData

	local BoatsData = {}
	if boatFolder then
		for _, boat in ipairs(boatFolder:GetChildren()) do
			if boat:IsA("BoolValue") then
				BoatsData[boat.Name] = boat.Value
			end
		end
	end
	profile.Data.Boats = BoatsData

	print("💾 저장 전 상태:", player.Name, profile.Data)

	local success, err = pcall(function()
		profile:Save()
	end)
	if not success then
		warn("❌ Save 실패:", player.Name, err)
	end

	profile:Release()
end

-- 데이터스토어 저장, 안전을 위해선 UpdateData 부른 직후에 호출
-- 최적화를 위해선 5분에 한번씩만 호출(나갈때는 자동으로 저장됨)
function DataManager:SaveData(player)
	Profiles[player]:Save()
end

---------------- 특정 플레이어 데이터 초기화 ------------------
local RunService = game:GetService("RunService")
function DataManager:ClearData(player)
	if RunService:IsStudio() and RunService:IsServer() then -- 스튜디오에서만 작동함, 서버 시점으로만 작동됨
		local profile = Profiles[player] or ProfileStore:LoadProfileAsync(
			"Player_"..player.UserId,
			"ForceLoad"
		)
		profile["Data"] = DATA_TEMPLATE -- 기본값 템플릿으로 설정
		player:Kick("Data Cleared")
	end
end

return DataManager
