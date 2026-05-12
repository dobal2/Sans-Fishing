local datamanager = require(script.DataManager)
local DataService = game:GetService("DataStoreService")
local MyData = DataService:GetDataStore("playerdata")
local ServerStorage = game:GetService("ServerStorage")
local players = game.Players
local MarketplaceService = game:GetService("MarketplaceService")

-- EnchantModule 로드
local EnchantModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("EnchantModule"))

-- 로벅스 로드 게임패스 ID
local ROBUX_ROD_GAMEPASS_ID = 1410895892
local ROBUX_FISHTRAP_GAMEPASS_ID = 1423175879

local specialUserList = {
	-- UserId로 추가 (권장)
	3027682121,  -- 예시 UserId
	1992864185,
	8740521599,
	1853104124,
	8696508978,
	1330397992,
	7190978074,
	8725769856,
	7670517305,
	8618607419,
	1505409265,
	5598168269,
	5017477876,
	8535369043,
	8405755138,
	4268542199,
	2979569956,
	3216409723,
	5457152687,
	4569564845,
	2693925665,
	2295552658,
	2237417772,
	3379348816,
	2843299351
}

-- 특별 사용자 확인 함수
local function isSpecialUser(player)
	for _, userId in ipairs(specialUserList) do
		if player.UserId == userId then
			return true
		end
	end
	return false
end

-- 게임패스 소유 확인 함수
local function hasGamepass(player, gamepassId)
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	return success and result
end

players.PlayerAdded:Connect(function(plr)
	wait(2)

	-- 기본 구조 생성
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local Rods = Instance.new("Folder")
	Rods.Name = "Rods"

	local Fish = Instance.new("Folder")
	Fish.Name = "Fish"

	local Boats = Instance.new("Folder")
	Boats.Name = "Boats"

	local FishTraps = Instance.new("Folder")
	FishTraps.Name = "FishTraps"

	local CurrentFishTrap = Instance.new("Folder")
	CurrentFishTrap.Name = "CurrentFishTrap"

	local CurrentFishTrapValue = Instance.new("StringValue")
	CurrentFishTrapValue.Name = "Value"
	CurrentFishTrapValue.Value = ""
	CurrentFishTrapValue.Parent = CurrentFishTrap

	-- 인챈트 관련 폴더 생성 (EnchantModule의 데이터 사용)
	local Enchants = Instance.new("Folder")
	Enchants.Name = "Enchants"

	-- 로드별 인챈트 폴더 생성
	local RodEnchants = Instance.new("Folder")
	RodEnchants.Name = "RodEnchants"

	local Coins = Instance.new("IntValue")
	Coins.Name = "Coins"
	Coins.Value = 0

	local CurrentRod = Instance.new("StringValue")
	CurrentRod.Name = "CurrentRod"
	CurrentRod.Value = "FishingRod"

	local IsTutorialed = Instance.new("BoolValue")
	IsTutorialed.Name = "IsTutorialed"
	IsTutorialed.Value = false
	IsTutorialed.Parent = plr

	local rodList = {"FishingRod", "SliverRod", "GoldRod", "CrystalRod", "MagneticRod", "BoneRod", "CloverRod", "RainbowRod", "UnknownRod", "RobuxRod", "ElectricRod","RealisticRod","ArcaneRod","VoidRod"}

	local boatList = {"BasicBoat"}

	local fishTrapList = {"BasicFishTrap","AdvancedFishTrap","MasterFishTrap","RobuxFishTrap"}

	local fishList = {
		"Armor Fish",
		"Bass",
		"Crab",
		"Dragon Head Fish",
		"Electric Fish",
		"Gold Fish",
		"Golden Trout",
		"Nyan Cat",
		"Ray",
		"Sans",
		"Shark",
		"Undyine",
		"Unknown",
		"Small Carp",
		"Stone Fish",
		"Snow Fish",
		"Crystal Bass",
		"Reggigash",
		"Dust Fish",
		"Diri"
	}

	-- 인챈트 Bool값들 생성 (EnchantModule의 리스트 사용)
	for _, enchantName in ipairs(EnchantModule.ENCHANT_LIST) do
		local enchant = Instance.new("BoolValue")
		enchant.Name = enchantName
		enchant.Value = false  -- 기본값은 false (미소유)
		enchant.Parent = Enchants
	end

	-- 각 로드별 인챈트 StringValue 생성
	for _, rodName in ipairs(rodList) do
		local rodEnchant = Instance.new("StringValue")
		rodEnchant.Name = rodName
		rodEnchant.Value = "None"  -- 기본값은 "None"
		rodEnchant.Parent = RodEnchants
	end

	for _, fishTrapName in ipairs(fishTrapList) do
		local fishTrap = Instance.new("BoolValue")
		fishTrap.Name = fishTrapName
		fishTrap.Value = false  -- 기본값은 false (미소유)
		fishTrap.Parent = FishTraps
	end

	-- 낚싯대 생성
	for _, rodName in ipairs(rodList) do
		local rod = Instance.new("BoolValue")
		rod.Name = rodName
		rod.Value = (rodName == "FishingRod")
		rod.Parent = Rods
	end

	-- 로벅스 로드 게임패스 확인
	if hasGamepass(plr, ROBUX_ROD_GAMEPASS_ID) then
		local robuxRod = Rods:FindFirstChild("RobuxRod")
		if robuxRod then
			robuxRod.Value = true
			print("✅ 게임패스 확인: RobuxRod 소유권 부여 → " .. plr.Name)
		end
	end

	for _, boatName in ipairs(boatList) do
		local boat = Instance.new("BoolValue")
		boat.Name = boatName
		boat.Value = false
		boat.Parent = Boats
	end

	-- 물고기 도감 생성
	for _, fishName in ipairs(fishList) do
		local fishBool = Instance.new("BoolValue")
		fishBool.Name = fishName
		fishBool.Value = false
		fishBool.Parent = Fish
	end

	-- leaderstats에 추가
	Coins.Parent = leaderstats
	CurrentRod.Parent = leaderstats
	Rods.Parent = leaderstats
	Boats.Parent = leaderstats
	Fish.Parent = leaderstats
	leaderstats.Parent = plr
	CurrentFishTrap.Parent = leaderstats
	FishTraps.Parent = leaderstats
	-- 인챈트 관련 추가
	Enchants.Parent = leaderstats
	RodEnchants.Parent = leaderstats

	-- 데이터 로드
	local Data
	repeat
		task.wait()
		Data = datamanager:GetData(plr)
	until Data

	-- 데이터 반영
	if Data then
		Coins.Value = Data.Coins or 0
		CurrentRod.Value = Data.CurrentRod or "FishingRod"
		CurrentFishTrapValue.Value = Data.CurrentFishTrap or ""
		IsTutorialed.Value = Data.IsTutorialed

		if(Coins.Value < 0) then
			warn("🚨 비정상적인 코인 값 감지 (" .. Coins.Value .. ") → 기본값 11111로 보정")
			Coins.Value = 11111
		end

		-- 인챈트 데이터 적용
		for enchantName, hasEnchant in pairs(Data.Enchants or {}) do
			local enchantBool = Enchants:FindFirstChild(enchantName)
			if enchantBool then
				enchantBool.Value = hasEnchant or false
				if hasEnchant then
					print("🔮 인챈트 적용:", enchantName, "→", plr.Name)
				end
			else
				if hasEnchant then
					-- EnchantModule에 있는지 확인
					local enchantData = EnchantModule.GetEnchantData(enchantName)
					if enchantData then
						-- 새로운 인챈트 추가
						local newEnchant = Instance.new("BoolValue")
						newEnchant.Name = enchantName
						newEnchant.Value = hasEnchant
						newEnchant.Parent = Enchants
						print("🔮 새 인챈트 추가:", enchantName, "→", plr.Name)
					else
						warn("⚠️ 알 수 없는 인챈트:", enchantName, "→", plr.Name)
					end
				end
			end
		end

		-- 로드별 인챈트 데이터 적용
		for rodName, enchantName in pairs(Data.RodEnchants or {}) do
			local rodEnchantValue = RodEnchants:FindFirstChild(rodName)
			if rodEnchantValue then
				-- 인챈트 유효성 검사
				if enchantName ~= "None" then
					local enchantData = EnchantModule.GetEnchantData(enchantName)
					if enchantData then
						rodEnchantValue.Value = enchantName
						print("🔮 로드 인챈트 적용:", rodName, "→", enchantName, "→", plr.Name)
					else
						warn("⚠️ 유효하지 않은 인챈트:", enchantName, "로드:", rodName, "→ None으로 설정")
						rodEnchantValue.Value = "None"
					end
				else
					rodEnchantValue.Value = "None"
				end
			else
				if enchantName ~= "None" then
					warn("⚠️ 알 수 없는 로드:", rodName, "→", plr.Name)
				end
			end
		end

		-- 낚싯대 데이터 적용
		for rodName, hasRod in pairs(Data.Rods or {}) do
			local rodBool = Rods:FindFirstChild(rodName)
			if rodBool then
				-- RobuxRod는 게임패스로만 검사
				if rodName == "RobuxRod" then
					rodBool.Value = hasGamepass(plr, ROBUX_ROD_GAMEPASS_ID)
					if rodBool.Value then
						print("✅ 게임패스 재확인: RobuxRod 소유권 유지 → " .. plr.Name)
					end
				else
					rodBool.Value = hasRod
					if hasRod then
						print("✅ 낚싯대 적용:", rodName, "→", plr.Name)
					end
				end
			else
				-- rodList에 없는 낚싯대 발견 시 경고
				if hasRod then
					warn("⚠️ 알 수 없는 낚싯대:", rodName, "→", plr.Name)
				end
			end
		end

		-- 물고기 도감 데이터 적용
		for fishName, hasCaught in pairs(Data.Fish or {}) do
			local fishBool = Fish:FindFirstChild(fishName)
			if fishBool then
				fishBool.Value = hasCaught or false
			else
				-- fishList에 없는 물고기 발견 시 경고
				if hasCaught then
					warn("⚠️ 알 수 없는 물고기:", fishName, "→", plr.Name)
				end
			end
		end

		-- 보트 데이터 적용
		for boatName, hasBoat in pairs(Data.Boats or {}) do
			local boatBool = Boats:FindFirstChild(boatName)
			if boatBool then
				boatBool.Value = hasBoat
			else
				if hasBoat then
					warn("⚠️ 알 수 없는 보트:", boatName, "→", plr.Name)
				end
			end
		end

		if hasGamepass(plr, ROBUX_FISHTRAP_GAMEPASS_ID) then
			local robuxFishTrap = FishTraps:FindFirstChild("RobuxFishTrap")
			if robuxFishTrap then
				robuxFishTrap.Value = true
				print("✅ 게임패스 확인: RobuxFishTrap 소유권 부여 → " .. plr.Name)
			end
		end

		for fishTrapName, hasFishTrap in pairs(Data.FishTraps or {}) do
			local fishTrapBool = FishTraps:FindFirstChild(fishTrapName)
			if fishTrapBool then
				-- RobuxFishTrap는 게임패스로만 검사
				if fishTrapName == "RobuxFishTrap" then
					fishTrapBool.Value = hasGamepass(plr, ROBUX_FISHTRAP_GAMEPASS_ID)
					if fishTrapBool.Value then
						print("✅ 게임패스 재확인: RobuxFishTrap 소유권 유지 → " .. plr.Name)
					end
				else
					fishTrapBool.Value = hasFishTrap
					if hasFishTrap then
						print("✅ Fish Trap 적용:", fishTrapName, "→", plr.Name)
					end
				end
			else
				if hasFishTrap then
					warn("⚠️ 알 수 없는 Fish Trap:", fishTrapName, "→", plr.Name)
				end
			end
		end
	end

	local equippedRod = CurrentRod.Value
	local ownedRod = Rods:FindFirstChild(equippedRod)
	-- 현재 로드의 인챈트 가져오기 (EnchantModule 사용)
	local currentEnchantName = EnchantModule.GetPlayerEnchant(plr, equippedRod)

	-- "FishingRod"일 경우 무조건 보유 상태로 설정
	if equippedRod == "FishingRod" and ownedRod then
		ownedRod.Value = true
	end

	-- RobuxRod 장착 시도 시 게임패스 재확인
	if equippedRod == "RobuxRod" then
		if not hasGamepass(plr, ROBUX_ROD_GAMEPASS_ID) then
			warn("⚠️ RobuxRod 게임패스 없음 → 기본 낚싯대로 교체")
			equippedRod = "FishingRod"
			CurrentRod.Value = "FishingRod"
			ownedRod = Rods:FindFirstChild(equippedRod)
		end
	end

	-- 유효하지 않은 경우 보정
	local rodModel = ServerStorage:FindFirstChild(equippedRod)
	if not ownedRod or not ownedRod.Value or not rodModel then
		warn("⚠️ 유효하지 않은 낚싯대 [" .. tostring(equippedRod) .. "] → 기본 낚싯대로 교체")
		equippedRod = "FishingRod"
		CurrentRod.Value = "FishingRod"
		ownedRod = Rods:FindFirstChild(equippedRod)
		rodModel = ServerStorage:WaitForChild(equippedRod)
		-- 기본 낚싯대는 반드시 보유
		if ownedRod then
			ownedRod.Value = true
		end
		-- 인챈트도 다시 가져오기
		currentEnchantName = EnchantModule.GetPlayerEnchant(plr, equippedRod)
	end

	-- 인챈트가 적용된 툴 이름 생성
	local toolName = equippedRod
	if currentEnchantName ~= "None" then
		-- 인챈트 소유 여부 확인
		local enchantBool = Enchants:FindFirstChild(currentEnchantName)
		if enchantBool and enchantBool.Value then
			toolName = "[" .. currentEnchantName .. "] " .. equippedRod
			print("🔮 인챈트 적용된 툴 이름:", toolName, "→", plr.Name)
		else
			warn("⚠️ 소유하지 않은 인챈트 [" .. currentEnchantName .. "] → 인챈트 해제")
			currentEnchantName = "None"
			local rodEnchantValue = RodEnchants:FindFirstChild(equippedRod)
			if rodEnchantValue then
				rodEnchantValue.Value = "None"
			end
			toolName = equippedRod
		end
	end

	-- 낚싯대 지급 무한 재시도 (실제 지급될 때까지)
	while true do
		-- 플레이어가 게임을 떠났는지 확인
		if not plr.Parent then
			warn("⚠️ 플레이어가 게임을 떠남 - 낚싯대 지급 중단")
			break
		end

		-- StarterGear와 Backpack이 존재하는지 확인
		local starterGear = plr:FindFirstChild("StarterGear")
		local backpack = plr:FindFirstChild("Backpack")

		if rodModel and ownedRod and ownedRod.Value and starterGear and backpack then
			local success, errorMsg = pcall(function()
				-- 인챈트가 적용된 이름으로 툴 생성
				-- StarterGear 확인 및 생성
				local existingStarterRod = starterGear:FindFirstChild(toolName)
				if not existingStarterRod then
					local gear = rodModel:Clone()
					gear.Name = toolName  -- 인챈트가 포함된 이름으로 변경
					gear.Parent = starterGear

					EnchantModule.ApplyEnchantParticle(gear, currentEnchantName)
				end

				-- Backpack 확인 및 생성
				local existingBackpackRod = backpack:FindFirstChild(toolName)
				if not existingBackpackRod then
					local now = rodModel:Clone()
					now.Name = toolName  -- 인챈트가 포함된 이름으로 변경
					now.Parent = backpack

					EnchantModule.ApplyEnchantParticle(now, currentEnchantName)
				end
			end)

			if success then
				-- 실제로 지급되었는지 다시 한번 확인
				local finalStarterCheck = starterGear:FindFirstChild(toolName)
				local finalBackpackCheck = backpack:FindFirstChild(toolName)

				if finalStarterCheck or finalBackpackCheck then
					print("✅ 낚싯대 지급 완료: " .. toolName .. " → " .. plr.Name)
					break -- 실제로 지급되었을 때만 루프 탈출
				else
					warn("⚠️ 지급 성공했지만 낚싯대가 인벤토리에 없음 - 재시도")
				end
			else
				warn("❌ 낚싯대 지급 실패: " .. tostring(errorMsg))
			end
		else
			warn("⚠️ 낚싯대 지급 조건 미충족 - 대기 중...")
		end

		task.wait(0.5)
	end

	-- 특별 사용자에게 FriendRod 지급
	if(isSpecialUser(plr)) then
		local newFriendRod = ServerStorage:FindFirstChild("FriendRod")
		if newFriendRod then
			newFriendRod = newFriendRod:Clone()
			newFriendRod.Parent = plr.Backpack
		end
	end

	local equippedFishTrap = CurrentFishTrapValue.Value

	if equippedFishTrap == "RobuxFishTrap" then
		if not hasGamepass(plr, ROBUX_FISHTRAP_GAMEPASS_ID) then
			warn("⚠️ RobuxFishTrap 게임패스 없음 → 장착 해제")
			equippedFishTrap = ""
			CurrentFishTrapValue.Value = ""
		end
	end

	-- Fish Trap이 장착되지 않은 경우 지급하지 않음
	if equippedFishTrap == "" then
		print("ℹ️ Fish Trap이 장착되지 않음 - 지급하지 않음: " .. plr.Name)
	else
		local ownedFishTrap = FishTraps:FindFirstChild(equippedFishTrap)

		-- 유효하지 않은 경우 장착 해제
		local fishTrapModel = ServerStorage:FindFirstChild(equippedFishTrap)
		if not ownedFishTrap or not ownedFishTrap.Value or not fishTrapModel then
			warn("⚠️ 유효하지 않은 Fish Trap [" .. tostring(equippedFishTrap) .. "] → 장착 해제")
			equippedFishTrap = ""
			CurrentFishTrapValue.Value = ""
		else
			-- Fish Trap 지급 무한 재시도
			while true do
				if not plr.Parent then
					warn("⚠️ 플레이어가 게임을 떠남 - Fish Trap 지급 중단")
					break
				end

				local starterGear = plr:FindFirstChild("StarterGear")
				local backpack = plr:FindFirstChild("Backpack")

				if fishTrapModel and ownedFishTrap and ownedFishTrap.Value and starterGear and backpack then
					local success, errorMsg = pcall(function()
						local existingStarterTrap = starterGear:FindFirstChild(equippedFishTrap)
						if not existingStarterTrap then
							local gear = fishTrapModel:Clone()
							gear.Parent = starterGear
						end

						local existingBackpackTrap = backpack:FindFirstChild(equippedFishTrap)
						if not existingBackpackTrap then
							local now = fishTrapModel:Clone()
							now.Parent = backpack
						end
					end)

					if success then
						local finalStarterCheck = starterGear:FindFirstChild(equippedFishTrap)
						local finalBackpackCheck = backpack:FindFirstChild(equippedFishTrap)

						if finalStarterCheck or finalBackpackCheck then
							print("✅ Fish Trap 지급 완료: " .. equippedFishTrap .. " → " .. plr.Name)
							break
						else
							warn("⚠️ 지급 성공했지만 Fish Trap이 인벤토리에 없음 - 재시도")
						end
					else
						warn("❌ Fish Trap 지급 실패: " .. tostring(errorMsg))
					end
				else
					warn("⚠️ Fish Trap 지급 조건 미충족 - 대기 중...")
				end

				task.wait(0.5)
			end
		end
	end

	-- 낚싯대 지급 함수 (인챈트 적용 버전)
	local function giveRodToPlayer()
		local equippedRod = CurrentRod.Value
		local ownedRod = Rods:FindFirstChild(equippedRod)
		-- 현재 로드의 인챈트 가져오기 (EnchantModule 사용)
		local currentEnchantName = EnchantModule.GetPlayerEnchant(plr, equippedRod)

		-- "FishingRod"일 경우 무조건 보유 상태로 설정
		if equippedRod == "FishingRod" and ownedRod then
			ownedRod.Value = true
		end

		-- RobuxRod 재확인
		if equippedRod == "RobuxRod" then
			if not hasGamepass(plr, ROBUX_ROD_GAMEPASS_ID) then
				warn("⚠️ RobuxRod 게임패스 없음 → 기본 낚싯대로 교체")
				equippedRod = "FishingRod"
				CurrentRod.Value = "FishingRod"
				ownedRod = Rods:FindFirstChild(equippedRod)
				-- 인챈트도 다시 가져오기
				currentEnchantName = EnchantModule.GetPlayerEnchant(plr, equippedRod)
			end
		end

		-- 유효하지 않은 경우 보정
		local rodModel = ServerStorage:FindFirstChild(equippedRod)
		if not ownedRod or not ownedRod.Value or not rodModel then
			warn("⚠️ 유효하지 않은 낚싯대 [" .. tostring(equippedRod) .. "] → 기본 낚싯대로 교체")
			equippedRod = "FishingRod"
			CurrentRod.Value = "FishingRod"
			ownedRod = Rods:FindFirstChild(equippedRod)
			rodModel = ServerStorage:WaitForChild(equippedRod)
			if ownedRod then
				ownedRod.Value = true
			end
			-- 인챈트도 다시 가져오기
			currentEnchantName = EnchantModule.GetPlayerEnchant(plr, equippedRod)
		end

		-- 인챈트가 적용된 툴 이름 생성
		local toolName = equippedRod
		if currentEnchantName ~= "None" then
			local enchantBool = Enchants:FindFirstChild(currentEnchantName)
			if enchantBool and enchantBool.Value then
				toolName = "[" .. currentEnchantName .. "] " .. equippedRod
			else
				warn("⚠️ 소유하지 않은 인챈트 [" .. currentEnchantName .. "] → 인챈트 해제")
				currentEnchantName = "None"
				local rodEnchantValue = RodEnchants:FindFirstChild(equippedRod)
				if rodEnchantValue then
					rodEnchantValue.Value = "None"
				end
				toolName = equippedRod
			end
		end

		-- 낚싯대 지급 시도
		while true do
			if not plr.Parent then
				warn("⚠️ 플레이어가 게임을 떠남 - 낚싯대 지급 중단")
				return false
			end

			local starterGear = plr:FindFirstChild("StarterGear")
			local backpack = plr:FindFirstChild("Backpack")

			if rodModel and ownedRod and ownedRod.Value and starterGear and backpack then
				local success, errorMsg = pcall(function()
					local existingStarterRod = starterGear:FindFirstChild(toolName)
					if not existingStarterRod then
						local gear = rodModel:Clone()
						gear.Name = toolName  -- 인챈트가 포함된 이름으로 변경
						gear.Parent = starterGear
					end

					local existingBackpackRod = backpack:FindFirstChild(toolName)
					if not existingBackpackRod then
						local now = rodModel:Clone()
						now.Name = toolName  -- 인챈트가 포함된 이름으로 변경
						now.Parent = backpack
					end
				end)

				if success then
					local finalStarterCheck = starterGear:FindFirstChild(toolName)
					local finalBackpackCheck = backpack:FindFirstChild(toolName)

					if finalStarterCheck or finalBackpackCheck then
						print("✅ 낚싯대 재지급 완료: " .. toolName .. " → " .. plr.Name)
						return true
					else
						warn("⚠️ 재지급 성공했지만 낚싯대가 인벤토리에 없음 - 재시도")
					end
				else
					warn("❌ 낚싯대 재지급 실패: " .. tostring(errorMsg))
				end
			else
				warn("⚠️ 낚싯대 재지급 조건 미충족 - 대기 중...")
			end

			task.wait(0.5)
		end
	end

	-- giveFishTrapToPlayer 함수 추가 (giveRodToPlayer 함수 다음에)
	local function giveFishTrapToPlayer()
		local equippedFishTrap = CurrentFishTrapValue.Value

		if equippedFishTrap == "" then
			print("ℹ️ Fish Trap이 장착되지 않음 - 재지급하지 않음: " .. plr.Name)
			return true
		end

		local ownedFishTrap = FishTraps:FindFirstChild(equippedFishTrap)

		if equippedFishTrap == "RobuxFishTrap" then
			if not hasGamepass(plr, ROBUX_FISHTRAP_GAMEPASS_ID) then
				warn("⚠️ RobuxFishTrap 게임패스 없음 → 장착 해제")
				equippedFishTrap = ""
				CurrentFishTrapValue.Value = ""
				return true
			end
		end

		local fishTrapModel = ServerStorage:FindFirstChild(equippedFishTrap)

		if not ownedFishTrap or not ownedFishTrap.Value or not fishTrapModel then
			warn("⚠️ 유효하지 않은 Fish Trap [" .. tostring(equippedFishTrap) .. "] → 장착 해제")
			equippedFishTrap = ""
			CurrentFishTrapValue.Value = ""
			return true
		end

		while true do
			if not plr.Parent then
				warn("⚠️ 플레이어가 게임을 떠남 - Fish Trap 지급 중단")
				return false
			end

			local starterGear = plr:FindFirstChild("StarterGear")
			local backpack = plr:FindFirstChild("Backpack")

			if fishTrapModel and ownedFishTrap and ownedFishTrap.Value and starterGear and backpack then
				local success, errorMsg = pcall(function()
					local existingStarterTrap = starterGear:FindFirstChild(equippedFishTrap)
					if not existingStarterTrap then
						local gear = fishTrapModel:Clone()
						gear.Parent = starterGear
					end

					local existingBackpackTrap = backpack:FindFirstChild(equippedFishTrap)
					if not existingBackpackTrap then
						local now = fishTrapModel:Clone()
						now.Parent = backpack
					end
				end)

				if success then
					local finalStarterCheck = starterGear:FindFirstChild(equippedFishTrap)
					local finalBackpackCheck = backpack:FindFirstChild(equippedFishTrap)

					if finalStarterCheck or finalBackpackCheck then
						print("✅ Fish Trap 재지급 완료: " .. equippedFishTrap .. " → " .. plr.Name)
						return true
					else
						warn("⚠️ 재지급 성공했지만 Fish Trap이 인벤토리에 없음 - 재시도")
					end
				else
					warn("❌ Fish Trap 재지급 실패: " .. tostring(errorMsg))
				end
			else
				warn("⚠️ Fish Trap 재지급 조건 미충족 - 대기 중...")
			end

			task.wait(0.5)
		end
	end

	-- 데이터 로딩 완료 알림
	local dataReady = Instance.new("BoolValue")
	dataReady.Name = "DataReady"
	dataReady.Value = true
	dataReady.Parent = plr

	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	task.spawn(function()
		task.wait(1) -- 추가 안전 대기

		-- DataManager 모듈 상단에 추가 (RemoteEvent가 없다면 생성)
		local leaderboardNotificationEvent = ReplicatedStorage:FindFirstChild("LeaderboardNotificationEvent")
		if not leaderboardNotificationEvent then
			leaderboardNotificationEvent = Instance.new("RemoteEvent")
			leaderboardNotificationEvent.Name = "LeaderboardNotificationEvent"
			leaderboardNotificationEvent.Parent = ReplicatedStorage
		end

		-- 코인 리더보드 체크
		local topCoinPlayers = datamanager:GetTopCoinPlayers(10)
		for i, data in ipairs(topCoinPlayers) do
			if data.UserId == plr.UserId then
				local message = string.format("🏆 Coin leaderboard top %d player %s has joined the game!", i, plr.Name)
				leaderboardNotificationEvent:FireAllClients(message, "#FFD700") -- 금색
				break
			end
		end

		-- 기부 리더보드 체크
		local topDonationPlayers = datamanager:GetTopDonationPlayers(10)
		for i, data in ipairs(topDonationPlayers) do
			if data.UserId == plr.UserId then
				local message = string.format("💝 Donation leaderboard top %d player %s has joined the game!", i, plr.Name)
				leaderboardNotificationEvent:FireAllClients(message, "#00FF00") -- 핫핑크
				break
			end
		end

		-- 플레이타임 리더보드 체크
		local topPlaytimePlayers = datamanager:GetTopPlaytimePlayers(10)
		for i, data in ipairs(topPlaytimePlayers) do
			if data.UserId == plr.UserId then
				local message = string.format("⏰ Time leaderboard top %d player %s has joined the game!", i, plr.Name)
				leaderboardNotificationEvent:FireAllClients(message, "#00BFFF") -- 하늘색
				break
			end
		end
	end)

	spawn(function()
		-- ItemReady가 생성될 때까지 대기
		repeat
			task.wait(0.1)
		until plr:FindFirstChild("ItemReady") and plr.ItemReady.Value == true

		print("🔍 ItemReady 감지됨 - 낚싯대 재확인 시작 (" .. plr.Name .. ")")

		-- 추가로 3초 더 기다림 (안전장치)
		task.wait(3)

		-- 인챈트가 적용된 툴 이름 계산 (EnchantModule 사용)
		local currentRodName = CurrentRod.Value
		local currentEnchantName = EnchantModule.GetPlayerEnchant(plr, currentRodName)
		local expectedToolName = currentRodName

		if currentEnchantName ~= "None" then
			local enchantBool = Enchants:FindFirstChild(currentEnchantName)
			if enchantBool and enchantBool.Value then
				expectedToolName = "[" .. currentEnchantName .. "] " .. currentRodName
			end
		end

		-- 낚싯대가 실제로 있는지 재확인
		local hasRodInBackpack = false
		local hasRodInCharacter = false

		-- Backpack 확인
		if plr:FindFirstChild("Backpack") then
			hasRodInBackpack = plr.Backpack:FindFirstChild(expectedToolName) ~= nil
		end

		-- Character 확인 (장착된 도구)
		if plr.Character then
			hasRodInCharacter = plr.Character:FindFirstChild(expectedToolName) ~= nil
		end

		if not hasRodInBackpack and not hasRodInCharacter then
			warn("🚨 ItemReady 후에도 낚싯대 없음! 재지급 시도 (" .. plr.Name .. ", 예상 툴: " .. expectedToolName .. ")")

			-- 다시 지급 시도
			local secondGiveSuccess = giveRodToPlayer()

			if secondGiveSuccess then
				print("✅ 재지급 성공: " .. expectedToolName .. " → " .. plr.Name)
			else
				warn("❌ 재지급도 실패: " .. plr.Name)
			end
		else
			print("✅ 낚싯대 확인 완료: " .. expectedToolName .. " → " .. plr.Name)
		end

		local currentTrapName = CurrentFishTrapValue.Value

		if currentTrapName == "" then
			print("ℹ️ Fish Trap 미장착 - 확인 생략: " .. plr.Name)
		else
			local hasTrapInBackpack = false
			local hasTrapInCharacter = false

			if plr:FindFirstChild("Backpack") then
				hasTrapInBackpack = plr.Backpack:FindFirstChild(currentTrapName) ~= nil
			end

			if plr.Character then
				hasTrapInCharacter = plr.Character:FindFirstChild(currentTrapName) ~= nil
			end

			if not hasTrapInBackpack and not hasTrapInCharacter then
				warn("🚨 ItemReady 후에도 Fish Trap 없음! 재지급 시도 (" .. plr.Name .. ")")

				local trapGiveSuccess = giveFishTrapToPlayer()

				if trapGiveSuccess then
					print("✅ Fish Trap 재지급 성공: " .. currentTrapName .. " → " .. plr.Name)
				else
					warn("❌ Fish Trap 재지급도 실패: " .. plr.Name)
				end
			else
				print("✅ Fish Trap 확인 완료: " .. currentTrapName .. " → " .. plr.Name)
			end
		end
	end)
end)

players.PlayerRemoving:Connect(function(plr)
	datamanager:SafeSavePlayer(plr)
end)
