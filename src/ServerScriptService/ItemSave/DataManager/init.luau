local Players = game:GetService("Players")
local ProfileService = require(script.ProfileService)
local RunService = game:GetService("RunService")

local DATA_TEMPLATE = { -- 데이터 템플릿
	items = {};
}

--local ENV = RunService:IsStudio() and "TestData" or "AlphaData"
local ProfileStore = ProfileService.GetProfileStore("AlphaData3", DATA_TEMPLATE)

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
		player:Kick("Data loading failed, Please try again 데이터 로딩 실패")
	end
end
Players.PlayerAdded:Connect(OnPlayerAdded)


local function OnPlayerRemoving(player)
	local profile = Profiles[player]
	if profile then
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

--데이터 업데이트, 현재 세션에만 저장되며 데이터스토어 저장을 위해선 SaveData()를 불러야 함
function DataManager:UpdateData(player, key, data)
	local profile = Profiles[player]

	if key == "" then -- 특정 키의 경우 값이 내려가지 않게 할 수 있음
		if profile.Data[key] and profile.Data[key] > data then
			return
		end
	end

	profile.Data[key] = data
	print("UpdateData:" ,player, key, data)
end

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


