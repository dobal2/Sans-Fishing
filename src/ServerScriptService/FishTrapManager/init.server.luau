-- 🎣 메인 서버 스크립트 (ServerScriptService에 위치) - 통발 1개 제한
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DataManager = require(script:WaitForChild("DataManager"))

-- 🎣 플레이어 이벤트 연결
Players.PlayerAdded:Connect(DataManager.OnPlayerAdded)
Players.PlayerRemoving:Connect(DataManager.OnPlayerRemoving)

local FishTrapManager = {}

-- 🎣 통발 설치 함수 (DataManager의 기능 사용)
function FishTrapManager.PlaceFishTrap(player, trapName, position, rotation)
	-- 🔍 통발 개수 제한 확인 (1개로 변경)
	if not FishTrapManager.CanPlaceTrap(player) then
		local ShowNoticeEvent = ReplicatedStorage:FindFirstChild("ShowNoticeEvent")
		if ShowNoticeEvent then
			ShowNoticeEvent:FireClient(player, "You already have a FishTrap! You can only place 1 trap total.")
		end
		print("❌ 통발 설치 실패 - 제한 초과:", player.Name)
		return nil
	end

	local trapId = DataManager:PlaceFishTrap(player, trapName, position, rotation)

	if trapId then
		print("✅ 통발 설치 성공:", player.Name, trapName, trapId)
	else
		print("❌ 통발 설치 실패:", player.Name, trapName)
	end

	return trapId
end

-- 🎣 통발 복구 함수 (DataManager의 기능 사용)
function FishTrapManager.RestorePlayerFishTraps(player)
	return DataManager:RestorePlayerFishTraps(player)
end



-- 🎣 플레이어별 통발 개수 제한 확인 (활성화된 통발만 카운트)
function FishTrapManager.GetPlayerTrapCount(player)
	local playerData = DataManager:GetData(player)
	if not playerData then return 0 end

	local trapCount = 0
	for key, trapData in pairs(playerData) do
		if string.find(key, "FishTrapData_") and trapData and type(trapData) == "table" then
			-- isActive가 true인 통발만 카운트
			if trapData.isActive == true then
				trapCount = trapCount + 1
			end
		end
	end

	print("🔍 [DEBUG] 플레이어 활성 통발 개수:", player.Name, trapCount)
	return trapCount
end

-- 🎣 통발 개수 제한 체크 (최대 1개로 변경)
function FishTrapManager.CanPlaceTrap(player)
	local maxTraps = 1 -- 플레이어당 최대 통발 개수를 1개로 변경
	local currentTraps = FishTrapManager.GetPlayerTrapCount(player)

	print("🔍 [DEBUG] 통발 제한 체크:", player.Name, "현재:", currentTraps, "최대:", maxTraps)
	return currentTraps < maxTraps
end

-- 🎣 플레이어의 모든 통발 제거
function FishTrapManager.RemoveAllPlayerTraps(player)
	local playerData = DataManager:GetData(player)
	if not playerData then return end

	local removedCount = 0

	-- 월드에서 통발 제거
	for _, obj in pairs(workspace:GetChildren()) do
		local ownerValue = obj:FindFirstChild("Owner")
		if ownerValue and ownerValue.Value == player.Name then
			local trapIdValue = obj:FindFirstChild("TrapId")
			if trapIdValue then
				-- 데이터에서도 제거
				DataManager:UpdateData(player, "FishTrapData_" .. trapIdValue.Value, nil)
				obj:Destroy()
				removedCount = removedCount + 1
			end
		end
	end

	print("🗑️ 플레이어의 모든 통발 제거:", player.Name, removedCount, "개")
	return removedCount
end



-- 🎣 서버 시작 시 초기화
local function initialize()
	print("🎣 FishTrap Manager 시작 중...")

	-- 서버 종료 시 모든 통발 데이터 저장
	game:BindToClose(function()
		print("🎣 서버 종료 - 모든 통발 데이터 저장 중...")

		for _, player in pairs(Players:GetPlayers()) do
			-- 각 플레이어의 통발 데이터 강제 저장
			for _, obj in pairs(workspace:GetChildren()) do
				local ownerValue = obj:FindFirstChild("Owner")
				local trapIdValue = obj:FindFirstChild("TrapId")
				local trapTypeValue = obj:FindFirstChild("TrapType")

				if ownerValue and ownerValue.Value == player.Name and trapIdValue and trapTypeValue then
					local trapData = {
						position = {
							x = obj.PrimaryPart.Position.X,
							y = obj.PrimaryPart.Position.Y,
							z = obj.PrimaryPart.Position.Z
						},
						rotation = {
							x = obj.PrimaryPart.Rotation.X,
							y = obj.PrimaryPart.Rotation.Y,
							z = obj.PrimaryPart.Rotation.Z
						},
						lastSaveTime = tick(),
						trapId = trapIdValue.Value,
						trapType = trapTypeValue.Value,
						isActive = true
					}

					DataManager:UpdateData(player, "FishTrapData_" .. trapIdValue.Value, trapData)
				end
			end
		end

		wait(3) -- 저장 시간 확보
	end)

	print("✅ FishTrap Manager 초기화 완료! (통발 제한: 1개)")
end

-- 🎣 초기화 실행
initialize()

-- 🎣 모듈 반환 (다른 스크립트에서 사용 가능)
return FishTrapManager
