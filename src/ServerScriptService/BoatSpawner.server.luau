-- 🚤 보트 스폰 서버 코드 (개인 보트 관리 수정 버전)
local spawnBoatRemote = game:GetService("ReplicatedStorage"):WaitForChild("SpawnBoat")
local BoatData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("BoatDataModule"))

-- 🌍 보트 전용 스폰 구역 설정
local BOAT_SPAWN_AREA = {
	CFrame.new(workspace:WaitForChild("BoatSpawnPoses"):WaitForChild("BoatSpawnPos1").Position),
	CFrame.new(workspace:WaitForChild("BoatSpawnPoses"):WaitForChild("BoatSpawnPos2").Position)
}

local BOAT_MODEL_FOLDER = game:GetService("ReplicatedStorage"):WaitForChild("Boats")
local occupiedSpots = {} -- 사용중인 스폰 위치 추적 (플레이어별)

-- 🎯 특정 스폰 위치 할당 함수 (수정됨 - 다른 플레이어 보트 제거 안 함)
local function getAssignedSpawnSpot(spawnIndex, playerUserId)
	-- 🔍 요청된 스폰 위치가 유효한지 확인
	if not BOAT_SPAWN_AREA[spawnIndex] then
		warn("⚠️ 잘못된 스폰 위치 번호:", spawnIndex)
		spawnIndex = 1 -- 기본값으로 1번 사용
	end

	-- 🚫 해당 위치가 이미 다른 플레이어가 사용 중인지 확인만 하고 제거하지 않음
	if occupiedSpots[spawnIndex] and occupiedSpots[spawnIndex] ~= playerUserId then
		print("⚠️ 스폰 위치", spawnIndex, "이미 다른 플레이어가 사용 중이지만 그대로 진행")
		-- 다른 플레이어 보트는 제거하지 않고 그냥 덮어씀
	end

	-- 📍 해당 위치를 현재 플레이어가 점유
	occupiedSpots[spawnIndex] = playerUserId

	print("🎯 지정된 스폰 위치 할당:", spawnIndex, "플레이어:", playerUserId)
	return BOAT_SPAWN_AREA[spawnIndex], spawnIndex
end

-- 🗑️ 특정 플레이어의 기존 보트만 제거 함수 (수정됨)
local function removePlayerBoats(player)
	for _, obj in pairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("Owner") == player.UserId then
			-- 해당 플레이어의 스폰 위치만 해제
			local spawnIndex = obj:GetAttribute("SpawnIndex")
			if spawnIndex and occupiedSpots[spawnIndex] == player.UserId then
				occupiedSpots[spawnIndex] = nil
			end
			obj:Destroy()
			print("🗑️ 플레이어 보트 제거:", obj.Name, "소유자:", player.Name)
		end
	end
end

-- 🗑️ 특정 스폰 위치의 특정 플레이어 보트만 제거 (새로 추가)
local function removePlayerBoatAtSpawnIndex(playerUserId, spawnIndex)
	for _, obj in pairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("Owner") == playerUserId and obj:GetAttribute("SpawnIndex") == spawnIndex then
			obj:Destroy()
			print("🗑️ 특정 위치 보트 제거:", obj.Name, "위치:", spawnIndex)
			break
		end
	end
end

-- 🔐 보트 보안 설정 함수 (동일)
local function setupBoatSecurity(boat, ownerUserId, ownerName)
	-- 🚗 VehicleSeat 찾기 및 보안 설정
	local function secureVehicleSeat(obj)
		if obj:IsA("VehicleSeat") then
			-- 새로운 보안 연결
			obj:GetPropertyChangedSignal("Occupant"):Connect(function()
				local occupant = obj.Occupant
				if occupant then
					local character = occupant.Parent
					local player = game.Players:GetPlayerFromCharacter(character)

					if player and player.UserId ~= ownerUserId then
						-- 다른 플레이어가 탔을 때 강제로 내리기
						obj.Occupant = nil
						print("🚫 접근 거부:", player.Name, "→", ownerName, "의 보트")

						-- 플레이어에게 알림 (선택사항)
						local message = Instance.new("Message")
						message.Text = "This boat belongs to " .. ownerName
						message.Parent = player:FindFirstChild("PlayerGui") or workspace
						game:GetService("Debris"):AddItem(message, 3)
					end
				end
			end)
		end
	end

	-- 모든 VehicleSeat에 보안 적용
	for _, obj in pairs(boat:GetDescendants()) do
		secureVehicleSeat(obj)
	end

	-- 새로 추가되는 VehicleSeat에도 보안 적용
	boat.DescendantAdded:Connect(function(obj)
		if obj:IsA("VehicleSeat") then
			wait(0.1) -- 약간의 지연
			secureVehicleSeat(obj)
		end
	end)
end

-- 🚤 보트 스폰 함수 (수정됨)
local function spawnBoat(player, boatName, assignedSpawnIndex)
	-- 🔍 보트 데이터 확인
	local boatData = BoatData.Boats[boatName]
	if not boatData then
		warn("허용되지 않은 보트 스폰 시도: " .. tostring(boatName))
		return
	end

	-- 🔍 소유권 확인
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("리더스탯 없음 - 플레이어:", player.Name)
		return
	end

	local boats = leaderstats:FindFirstChild("Boats")
	if not boats then
		warn("보트 폴더 없음 - 플레이어:", player.Name)
		return
	end

	local boatBool = boats:FindFirstChild(boatData.storageName)
	if not boatBool or not boatBool.Value then
		warn("보트 미소유 - 플레이어:", player.Name, "보트:", boatName)
		player:Kick("ClientHacker - Unauthorized boat spawn")
		return
	end

	-- 🗑️ 해당 플레이어의 기존 보트만 제거
	removePlayerBoats(player)

	-- 🚤 보트 모델 찾기
	local boatModel = BOAT_MODEL_FOLDER:FindFirstChild(boatData.storageName)
	if not boatModel then
		warn("보트 모델을 찾을 수 없습니다:", boatData.storageName)
		return
	end

	-- 🎯 지정된 스폰 위치 할당 (플레이어 ID 포함)
	local spawnCFrame, spawnIndex = getAssignedSpawnSpot(assignedSpawnIndex, player.UserId)

	-- 🚤 보트 복사 및 스폰
	local newBoat = boatModel:Clone()
	newBoat.Name = boatData.storageName .. "_" .. player.Name

	-- 🏷️ 소유자 정보 설정
	newBoat:SetAttribute("Owner", player.UserId)
	newBoat:SetAttribute("OwnerName", player.Name)
	newBoat:SetAttribute("SpawnIndex", spawnIndex)

	-- 🔧 보트 위치 설정
	if newBoat.PrimaryPart then
		newBoat:SetPrimaryPartCFrame(spawnCFrame)
	else
		-- PrimaryPart가 없는 경우 첫 번째 Part 사용
		for _, part in pairs(newBoat:GetChildren()) do
			if part:IsA("BasePart") then
				part.CFrame = spawnCFrame
				break
			end
		end
	end

	-- 🔐 보트 보안 설정
	setupBoatSecurity(newBoat, player.UserId, player.Name)

	-- 🌍 월드에 추가
	newBoat.Parent = workspace

	print("✅ 보트 스폰 완료 - 플레이어:", player.Name, "보트:", boatName, "스폰 위치:", spawnIndex)
end

-- 🔌 리모트 이벤트 연결 (동일)
spawnBoatRemote.OnServerEvent:Connect(function(player, boatName, assignedSpawnIndex)
	-- 📍 스폰 위치가 전달되지 않으면 기본값 1 사용
	assignedSpawnIndex = assignedSpawnIndex or 1

	print("🚤 보트 스폰 요청 받음 - 플레이어:", player.Name, "보트:", boatName, "지정 위치:", assignedSpawnIndex)
	spawnBoat(player, boatName, assignedSpawnIndex)
end)

-- 🚪 플레이어 나갈 때 해당 플레이어 보트만 정리 (수정됨)
game.Players.PlayerRemoving:Connect(function(player)
	removePlayerBoats(player)
	print("🧹 플레이어 보트 정리 완료:", player.Name)
end)
