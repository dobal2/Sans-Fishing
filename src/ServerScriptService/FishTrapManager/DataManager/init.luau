local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ProfileService = require(script.ProfileService)

-- 🎣 통발 ID 생성 함수
local function generateTrapId()
	return "trap_" .. tick() .. "_" .. math.random(1000, 9999)
end

-- 🎯 통발 종류별 성능 설정 (서버와 동일하게)
local FISHTRAP_CONFIGS = {
	["BasicFishTrap"] = {
		catchInterval = 300,    -- 5분
		maxCapacity = 30,       -- 30마리
		rodType = "BasicRod"
	},
	["AdvancedFishTrap"] = {
		catchInterval = 240,    -- 4분
		maxCapacity = 40,       -- 40마리
		rodType = "SteelRod"
	},
	["MasterFishTrap"] = {
		catchInterval = 180,    -- 3분
		maxCapacity = 50,       -- 50마리
		rodType = "GoldRod"
	},
	["RobuxFishTrap"] = {
		catchInterval = 150,    -- 3분 (요청사항)
		maxCapacity = 80,      -- 100마리 (요청사항)
		rodType = "RobuxRod",   -- 최고 성능 (게임패스 로드 성능)aaaaaaaaaa
		displayName = "Robux Fish Trap"
	}
}

local ProfileStore = ProfileService.GetProfileStore("FishingGameStore", {})
local Profiles = {}

local function HandleLockedUpdate(globalUpdates, update)
	local id = update[1]
	local data = update[2]
	globalUpdates:ClearLockedUpdate(id)
end

local DataManager = {}

function DataManager.OnPlayerAdded(player)
	local profile = ProfileStore:LoadProfileAsync("Player_"..player.UserId, "ForceLoad")

	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick()
		end)

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

			-- 🎣 통발 복구 (오프라인 삭제 신호 먼저 처리)
			spawn(function()
				DataManager:CheckOfflineDeleteSignals(player)
				DataManager:RestorePlayerFishTraps(player)
			end)

		else
			profile:Release()
		end
	else
		player:Kick("Data loading failed")
	end
end

function DataManager.OnPlayerRemoving(player)
	local profile = Profiles[player]
	if profile then
		profile:Save()
		profile:Release()
	end
end

function DataManager:GetData(player)
	local profile = Profiles[player]
	return profile and profile.Data or nil
end

function DataManager:UpdateData(player, key, data)
	local profile = Profiles[player]
	if not profile then
		warn("❌ UpdateData 실패: 프로필 없음", player.Name, key)
		return
	end

	profile.Data[key] = data
	print("💾 데이터 업데이트:", player.Name, key, data and "저장" or "삭제")
end

function DataManager:CheckOfflineDeleteSignals(player)
	print("강화된 오프라인 삭제 신호 확인:", player.Name)

	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	-- 기존 삭제 신호들 처리
	for _, child in pairs(ReplicatedStorage:GetChildren()) do
		-- 개별 삭제
		if child.Name:find("DeleteTrapData_" .. player.Name .. "_") and child:IsA("StringValue") then
			local trapId = child.Name:match("DeleteTrapData_" .. player.Name .. "_(.+)")
			if trapId then
				self:UpdateData(player, "FishTrapData_" .. trapId, nil)
				print("개별 통발 삭제:", trapId)
				child:Destroy()
			end
		end

		-- 전체 삭제
		if child.Name == "DeleteAllTrapData_" .. player.Name and child:IsA("StringValue") then
			self:ClearAllPlayerTrapData(player)
			print("전체 통발 삭제 완료")
			child:Destroy()
		end

		-- ★ 새로운 강화된 삭제
		if child.Name == "ForceDeleteAllTrapData_" .. player.Name and child:IsA("StringValue") then
			print("강화된 삭제 신호 처리:", player.Name)

			-- 강제 전체 삭제
			local deletedCount = self:ClearAllPlayerTrapData(player)

			-- 추가로 모든 변형 키도 삭제
			local playerData = self:GetData(player)
			if playerData then
				local extraKeys = {}
				for key, value in pairs(playerData) do
					-- trap, Trap, TRAP 등 모든 변형 찾기
					if string.find(string.lower(key), "trap") or
						string.find(string.lower(key), "fish") then
						table.insert(extraKeys, key)
					end
				end

				for _, key in pairs(extraKeys) do
					self:UpdateData(player, key, nil)
					deletedCount = deletedCount + 1
					print("추가 삭제:", key)
				end
			end

			print("강화된 삭제 완료:", deletedCount, "개")
			child:Destroy()
		end
	end
end

function DataManager:ClearAllPlayerTrapData(player)
	local playerData = self:GetData(player)
	if not playerData then return 0 end

	local deletedCount = 0
	local keysToDelete = {}

	-- 모든 통발 관련 키 찾기 (더 포괄적으로)
	for key, value in pairs(playerData) do
		if string.find(key, "FishTrapData_") or
			string.find(key, "TrapData_") or
			string.find(key, "Trap_") or
			string.find(string.lower(key), "fishtrap") then
			table.insert(keysToDelete, key)
		end
	end

	-- 일괄 삭제
	for _, key in pairs(keysToDelete) do
		self:UpdateData(player, key, nil)
		deletedCount = deletedCount + 1
		print("완전 삭제:", key)
	end

	return deletedCount
end

-- 🎣 통발 설치 (종류별 지원)
function DataManager:PlaceFishTrap(player, trapName, position, rotation)
	local fishTrapsFolder = ServerStorage:FindFirstChild("FishTraps")
	local trapModel = fishTrapsFolder and fishTrapsFolder:FindFirstChild(trapName)
	if not trapModel then
		warn("⚠️ 통발 모델 없음: ServerStorage > FishTraps >", trapName)
		return nil
	end

	local newTrap = trapModel:Clone()
	local trapId = generateTrapId()

	local ownerValue = Instance.new("StringValue")
	ownerValue.Name = "Owner"
	ownerValue.Value = player.Name
	ownerValue.Parent = newTrap

	local trapIdValue = Instance.new("StringValue")
	trapIdValue.Name = "TrapId"
	trapIdValue.Value = trapId
	trapIdValue.Parent = newTrap

	local trapTypeValue = Instance.new("StringValue")
	trapTypeValue.Name = "TrapType"
	trapTypeValue.Value = trapName
	trapTypeValue.Parent = newTrap

	if position and rotation then
		newTrap:SetPrimaryPartCFrame(CFrame.new(position.X, position.Y, position.Z) *
			CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z)))
	end

	newTrap.Parent = workspace

	-- 종류별 성능 설정
	local config = FISHTRAP_CONFIGS[trapName] or FISHTRAP_CONFIGS["BasicFishTrap"]

	local trapData = {
		position = {
			x = newTrap.PrimaryPart.Position.X,
			y = newTrap.PrimaryPart.Position.Y,
			z = newTrap.PrimaryPart.Position.Z
		},
		rotation = {
			x = newTrap.PrimaryPart.Rotation.X,
			y = newTrap.PrimaryPart.Rotation.Y,
			z = newTrap.PrimaryPart.Rotation.Z
		},
		storedFish = {},
		nextCatchTime = tick() + config.catchInterval,
		lastSaveTime = tick(),
		trapId = trapId,
		trapType = trapName,
		isActive = true -- 활성 상태 플래그
	}

	self:UpdateData(player, "FishTrapData_" .. trapId, trapData)
	print("🎣 통발 설치:", player.Name, trapName, trapId)
	return trapId
end

function DataManager:RestorePlayerFishTraps(player)
	task.wait(1) -- 더 긴 대기시간으로 안정성 확보

	local playerData = self:GetData(player)
	if not playerData then
		print("플레이어 데이터 없음 - FishTrapReady 설정:", player.Name)
		local fishTrapReady = Instance.new("BoolValue")
		fishTrapReady.Name = "FishTrapReady"
		fishTrapReady.Value = true
		fishTrapReady.Parent = player
		return
	end

	print("=== 통발 복구 시작 ===")
	print("플레이어:", player.Name)

	-- 먼저 월드에서 기존 통발 확인
	local existingTrapsInWorld = {}
	for _, obj in pairs(workspace:GetChildren()) do
		local ownerValue = obj:FindFirstChild("Owner")
		local trapIdValue = obj:FindFirstChild("TrapId")
		if ownerValue and ownerValue.Value == player.Name and trapIdValue then
			existingTrapsInWorld[trapIdValue.Value] = obj
		end
	end
	print("월드에 기존 통발 개수:", #existingTrapsInWorld)

	-- 모든 통발 데이터 찾기
	local trapDataList = {}
	for key, trapData in pairs(playerData) do
		if string.find(key, "FishTrapData_") and trapData and type(trapData) == "table" then
			-- isActive가 false가 아닌 경우만 (nil도 복구 대상)
			if trapData.isActive ~= false then
				table.insert(trapDataList, {
					key = key,
					data = trapData,
					saveTime = trapData.lastSaveTime or 0
				})
				print("복구 대상 통발 발견:", key, "저장시간:", trapData.lastSaveTime or "없음")
			else
				print("비활성 통발 데이터 건너뜀:", key)
			end
		end
	end

	-- 저장시간 기준으로 정렬 (최신순)
	table.sort(trapDataList, function(a, b)
		return a.saveTime > b.saveTime
	end)

	-- 최신 통발 1개만 복구
	if #trapDataList > 0 then
		local latestTrap = trapDataList[1]
		local trapData = latestTrap.data
		local trapId = string.sub(latestTrap.key, 14) -- "FishTrapData_" 제거

		print("복구할 통발:", trapId, "타입:", trapData.trapType or "BasicFishTrap")

		-- 이미 월드에 존재하는지 확인
		if existingTrapsInWorld[trapId] then
			print("통발", trapId, "이미 월드에 존재 - 복구 건너뜀")
		else
			-- 통발 복구 실행
			local trapType = trapData.trapType or "BasicFishTrap"
			local config = FISHTRAP_CONFIGS[trapType] or FISHTRAP_CONFIGS["BasicFishTrap"]

			local fishTrapsFolder = ServerStorage:FindFirstChild("FishTraps")
			local trapModel = fishTrapsFolder and fishTrapsFolder:FindFirstChild(trapType)

			if trapModel and trapData.position then
				print("통발 월드에 복구 시작:", trapType)

				-- 오프라인 물고기 계산
				local lastSaveTime = trapData.lastSaveTime or tick()
				local currentTime = tick()
				local timeOffline = currentTime - lastSaveTime

				local currentFishCount = trapData.storedFish and #trapData.storedFish or 0
				local fishToCatch = math.floor(timeOffline / config.catchInterval)
				local maxPossibleCatch = config.maxCapacity - currentFishCount
				fishToCatch = math.min(fishToCatch, maxPossibleCatch)

				print("오프라인 계산:")
				print("  - 오프라인 시간:", math.floor(timeOffline), "초")
				print("  - 기존 물고기:", currentFishCount, "마리")
				print("  - 추가 가능:", fishToCatch, "마리")

				-- 오프라인 물고기 추가
				if fishToCatch > 0 then
					local success, FishData = pcall(function()
						return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("FishDataModule"))
					end)

					if success and FishData then
						local storedFish = trapData.storedFish or {}
						for i = 1, fishToCatch do
							local fishInfo = FishData.GetRandomFish(config.rodType, nil)
							if fishInfo then
								table.insert(storedFish, fishInfo)
							end
						end
						trapData.storedFish = storedFish
						print("오프라인 물고기", fishToCatch, "마리 추가 완료")
					else
						warn("FishData 모듈 로드 실패")
					end
				end

				-- 통발 월드에 복구
				local newTrap = trapModel:Clone()
				newTrap.Name = (config.displayName or trapType) .. "_" .. trapId

				-- 소유자 정보 설정
				local ownerValue = Instance.new("StringValue")
				ownerValue.Name = "Owner"
				ownerValue.Value = player.Name
				ownerValue.Parent = newTrap

				local trapIdValue = Instance.new("StringValue")
				trapIdValue.Name = "TrapId"
				trapIdValue.Value = trapId
				trapIdValue.Parent = newTrap

				local trapTypeValue = Instance.new("StringValue")
				trapTypeValue.Name = "TrapType"
				trapTypeValue.Value = trapType
				trapTypeValue.Parent = newTrap

				-- 위치 설정
				local pos = trapData.position
				local rot = trapData.rotation or {x = 0, y = 0, z = 0}

				newTrap:SetPrimaryPartCFrame(CFrame.new(
					pos.x, pos.y, pos.z
					) * CFrame.Angles(
						math.rad(rot.x), math.rad(rot.y), math.rad(rot.z)
					))

				newTrap.Parent = workspace

				-- 업데이트된 데이터 저장
				trapData.lastSaveTime = currentTime
				trapData.nextCatchTime = currentTime + config.catchInterval
				trapData.isActive = true
				self:UpdateData(player, latestTrap.key, trapData)

				print("통발 복구 성공:", player.Name, trapType, trapId)
				print("  - 위치: (", pos.x, pos.y, pos.z, ")")
				print("  - 물고기:", #(trapData.storedFish or {}), "마리")

			elseif not trapModel then
				-- 모델이 없으면 데이터 삭제
				self:UpdateData(player, latestTrap.key, nil)
				warn("모델 없는 통발 데이터 삭제:", trapType, trapId)
			elseif not trapData.position then
				-- 위치 정보 없으면 데이터 삭제
				self:UpdateData(player, latestTrap.key, nil)
				warn("위치 없는 통발 데이터 삭제:", trapId)
			end
		end

		-- 오래된 통발 데이터들 삭제 (최신 1개 제외)
		for i = 2, #trapDataList do
			local oldTrap = trapDataList[i]
			self:UpdateData(player, oldTrap.key, nil)
			print("오래된 통발 데이터 삭제:", oldTrap.key)
		end

	else
		print("복구할 통발 데이터 없음")
	end

	-- FishTrapReady 플래그 설정
	local fishTrapReady = Instance.new("BoolValue")
	fishTrapReady.Name = "FishTrapReady"
	fishTrapReady.Value = true
	fishTrapReady.Parent = player

	print("=== 통발 복구 완료 ===")
end

return DataManager
