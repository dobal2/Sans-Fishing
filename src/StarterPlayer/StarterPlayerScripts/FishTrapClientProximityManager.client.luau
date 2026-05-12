local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")
local player = Players.LocalPlayer

-- 💎 Robux Fish Trap 게임패스 ID
local ROBUX_FISHTRAP_GAMEPASS_ID = 1423175879

-- 🔍 게임패스 소유 확인 함수
local function hasGamepass(player, gamepassId)
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	return success and result
end

-- ProximityPrompt 찾기
local basicProximity = workspace:WaitForChild("Basic FishtrapMainModel"):WaitForChild("ProximityPrompt")
local advancedProximity = workspace:WaitForChild("T2 FishtrapMainModel"):WaitForChild("ProximityPrompt")
local masterProximity = workspace:WaitForChild("T3 FishtrapMainModel"):WaitForChild("ProximityPrompt")
local robuxProximity = workspace:WaitForChild("Robux FishtrapMainModel"):WaitForChild("ProximityPrompt")

-- Fish Trap 매핑 (ProximityPrompt → Fish Trap 이름)
local proximityToFishTrap = {
	[basicProximity] = "BasicFishTrap",
	[advancedProximity] = "AdvancedFishTrap",
	[masterProximity] = "MasterFishTrap",
	[robuxProximity] = "RobuxFishTrap"
}

-- ActionText 업데이트 함수
local function updateProximityText(proximity, fishTrapName)
	local leaderstats = player:WaitForChild("leaderstats")
	if not leaderstats then return end

	local fishTrapsFolder = leaderstats:WaitForChild("FishTraps")
	local currentFishTrap = leaderstats:WaitForChild("CurrentFishTrap")
	if not (fishTrapsFolder and currentFishTrap) then return end

	local fishTrapBool = fishTrapsFolder:WaitForChild(fishTrapName)
	local currentFishTrapValue = currentFishTrap:WaitForChild("Value")
	if not (fishTrapBool and currentFishTrapValue) then return end

	-- 💎 RobuxFishTrap 특별 처리
	if fishTrapName == "RobuxFishTrap" then
		local hasRobuxGamepass = hasGamepass(player, ROBUX_FISHTRAP_GAMEPASS_ID)

		if not hasRobuxGamepass then
			-- 게임패스 없음
			--proximity.ActionText = "Need Gamepass"
			return
		elseif fishTrapBool.Value then
			-- 게임패스 있고 보유중
			if currentFishTrapValue.Value == fishTrapName then
				proximity.ActionText = "Equipped"
			else
				proximity.ActionText = "Equip"
			end
		else
			-- 게임패스 있지만 아직 받지 않음
			--proximity.ActionText = "Get Free"
		end
		return
	end

	-- 일반 Fish Trap 처리
	if fishTrapBool.Value then
		-- 보유중인 경우
		if currentFishTrapValue.Value == fishTrapName then
			-- 현재 장착중
			proximity.ActionText = "Equipped"
		else
			-- 보유중이지만 장착하지 않음
			proximity.ActionText = "Equip"
		end
	else
		-- 보유하지 않음
		--proximity.ActionText = "Buy"
	end
end

-- 모든 ProximityPrompt 업데이트
local function updateAllProximityTexts()
	for proximity, fishTrapName in pairs(proximityToFishTrap) do
		updateProximityText(proximity, fishTrapName)
	end
end

-- leaderstats 로딩 대기
local function waitForLeaderstats()
	local leaderstats = player:WaitForChild("leaderstats")
	if not leaderstats then
		warn("❌ leaderstats 로딩 실패")
		return
	end

	local fishTrapsFolder = leaderstats:WaitForChild("FishTraps")
	local currentFishTrap = leaderstats:WaitForChild("CurrentFishTrap")
	if not (fishTrapsFolder and currentFishTrap) then
		warn("❌ FishTraps 또는 CurrentFishTrap 로딩 실패")
		return
	end

	-- 각 Fish Trap Bool값 대기
	local basicBool = fishTrapsFolder:WaitForChild("BasicFishTrap")
	local advancedBool = fishTrapsFolder:WaitForChild("AdvancedFishTrap")
	local masterBool = fishTrapsFolder:WaitForChild("MasterFishTrap")
	local robuxBool = fishTrapsFolder:WaitForChild("RobuxFishTrap")
	local currentValue = currentFishTrap:WaitForChild("Value")

	if not (basicBool and advancedBool and masterBool and robuxBool and currentValue) then
		warn("❌ Fish Trap 데이터 로딩 실패")
		return
	end

	-- 초기 텍스트 설정
	updateAllProximityTexts()

	-- 변경 감지 연결
	basicBool.Changed:Connect(function()
		updateProximityText(basicProximity, "BasicFishTrap")
	end)

	advancedBool.Changed:Connect(function()
		updateProximityText(advancedProximity, "AdvancedFishTrap")
	end)

	masterBool.Changed:Connect(function()
		updateProximityText(masterProximity, "MasterFishTrap")
	end)

	robuxBool.Changed:Connect(function()
		updateProximityText(robuxProximity, "RobuxFishTrap")
	end)

	currentValue.Changed:Connect(function()
		updateAllProximityTexts() -- 현재 장착 Fish Trap 변경시 모든 텍스트 업데이트
	end)

	-- 💎 게임패스 상태 변경 감지 (주기적 체크)
	spawn(function()
		local lastGamepassStatus = hasGamepass(player, ROBUX_FISHTRAP_GAMEPASS_ID)
		while true do
			wait(5) -- 5초마다 체크
			local currentGamepassStatus = hasGamepass(player, ROBUX_FISHTRAP_GAMEPASS_ID)
			if currentGamepassStatus ~= lastGamepassStatus then
				updateProximityText(robuxProximity, "RobuxFishTrap")
				lastGamepassStatus = currentGamepassStatus
				print("🔄 Robux Fish Trap 게임패스 상태 변경 감지")
			end
		end
	end)

	print("✅ Fish Trap ProximityPrompt 텍스트 시스템 초기화 완료 (RobuxFishTrap 포함)")
end

-- leaderstats 로딩 대기 및 초기화
waitForLeaderstats()
