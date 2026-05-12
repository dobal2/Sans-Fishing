local remote = game:GetService("ReplicatedStorage"):WaitForChild("BuyFishingRod")
local RodData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("RodDataModule"))
local setFavoriteRemote = game:GetService("ReplicatedStorage"):WaitForChild("SetFavoriteRemote")
local MarketplaceService = game:GetService("MarketplaceService")

-- 로벅스 로드 게임패스 ID
local ROBUX_ROD_GAMEPASS_ID = 1410895892

-- 보이드 퀘스트 완료 확인 함수
local function hasCompletedVoidQuest(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return false end
	local quests = leaderstats:FindFirstChild("Quests")
	if not quests then return false end
	local completedQuests = quests:FindFirstChild("CompletedQuests")
	if not completedQuests then return false end
	local voidQuestCompleted = completedQuests:FindFirstChild("void_unknown_challenge")
	return voidQuestCompleted and voidQuestCompleted.Value == true
end

-- 인첸트가 적용된 낚싯대 지급 함수
local function giveEnchantedRod(player, rodName)
	local leaderstats = player:WaitForChild("leaderstats")
	if not leaderstats then return end

	local rodEnchants = leaderstats:FindFirstChild("RodEnchants")
	if not rodEnchants then return end

	-- 해당 로드의 인첸트 확인
	local rodEnchantValue = rodEnchants:FindFirstChild(rodName)
	local enchantName = rodEnchantValue and rodEnchantValue.Value or "None"

	-- 새 낚싯대 생성
	local storageItem = game.ServerStorage:FindFirstChild(rodName)
	if storageItem then
		local newRod = storageItem:Clone()

		-- 인첸트가 적용된 이름으로 변경
		if enchantName ~= "None" then
			newRod.Name = "[" .. enchantName .. "] " .. rodName
			print("인첸트 적용된 낚싯대 지급:", newRod.Name, "→", player.Name)
		else
			newRod.Name = rodName
			print("기본 낚싯대 지급:", newRod.Name, "→", player.Name)
		end

		-- Backpack에 지급
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			newRod.Parent = backpack
		else
			newRod.Parent = player
		end

		-- ✨ 여기서 인챈트 이펙트 적용
		if enchantName ~= "None" then
			local EnchantModule = require(game.ReplicatedStorage.Modules.EnchantModule)
			EnchantModule.ApplyEnchantParticle(newRod, enchantName)
			print("🔮 인챈트 이펙트 적용:", enchantName, "→", player.Name)
		end
	else
		error("ServerStorage에 '" .. rodName .. "' 아이템이 존재하지 않습니다.")
	end
end


remote.OnServerEvent:Connect(function(plr, itemname)
	local item = RodData.Rods[itemname]
	if not item then
		warn("허용되지 않은 아이템 구매 시도: " .. tostring(itemname))
		return
	end

	-- 보이드 로드 퀘스트 확인
	if itemname == "VoidRod" then
		if not hasCompletedVoidQuest(plr) then
			warn("보이드 퀘스트 미완료 상태에서 VoidRod 구매 시도: " .. plr.Name)
			plr:Kick("Unauthorized access attempt")
			return
		end
		print("보이드 퀘스트 완료 확인됨:", plr.Name)
	end

	local leaderstats = plr:WaitForChild("leaderstats")
	if not leaderstats then
		warn("leaderstats 타임아웃")
		return
	end

	local coins = leaderstats:WaitForChild("Coins")
	local currentRod = leaderstats:WaitForChild("CurrentRod")
	local rodsFolder = leaderstats:WaitForChild("Rods")

	if not (coins and currentRod and rodsFolder) then
		warn("필수 leaderstats 요소 타임아웃")
		return
	end

	local rodBool = rodsFolder:FindFirstChild(item.storageName)
	local alreadyOwned = rodBool and rodBool.Value

	-- 로벅스 로드 처리
	if itemname == "RobuxRod" then
		local hasGamepass = false
		local success, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, ROBUX_ROD_GAMEPASS_ID)
		end)
		if success then
			hasGamepass = result
		end

		if not hasGamepass then
			warn("게임패스 미소유 상태에서 RobuxRod 요청: " .. plr.Name)
			return
		end

		-- 검증 통과한 경우에만 소유권 부여
		if not alreadyOwned and rodBool then
			rodBool.Value = true
			print("RobuxRod 소유권 부여 완료 - 검증됨")
		end
	else
		-- 일반 로드 처리 (보이드 로드 포함)
		if not alreadyOwned then
			if coins.Value < item.price then
				warn("잔액 부족")
				plr:Kick("ClientHacker")
				return
			end
			coins.Value -= item.price
			if rodBool then
				rodBool.Value = true
			end

			-- 보이드 로드 구매 로그
			if itemname == "VoidRod" then
				print("VoidRod 구매 완료:", plr.Name, "가격:", item.price)
			end
		end
	end

	-- 기본 낚싯대 비활성화 (새로 구매한 경우에만)
	if not alreadyOwned then
		local defaultRod = rodsFolder:FindFirstChild("FishingRod")
		if defaultRod then
			defaultRod.Value = false
		end
	end

	-- 기존 장착 도구 제거 (인첸트가 적용된 이름도 포함)
	local function removeExistingRods(plr)
		for _, container in ipairs({ plr:FindFirstChild("Backpack"), plr:FindFirstChild("StarterGear"), plr.Character }) do
			if container then
				for _, tool in ipairs(container:GetChildren()) do
					if tool:IsA("Tool") then
						-- 기본 로드 이름 또는 인첸트가 적용된 이름 확인
						local toolBaseName = tool.Name
						if tool.Name:find("^%[.*%] ") then
							-- 인첸트가 적용된 경우: "[인첸트명] 로드명"에서 로드명만 추출
							toolBaseName = tool.Name:match("^%[.*%] (.+)")
						end

						if RodData.Rods[toolBaseName] or toolBaseName == "FishingRod" then
							tool:Destroy()
						end
					end
				end
			end
		end
	end

	removeExistingRods(plr)

	-- 장착
	currentRod.Value = item.storageName

	-- 인첸트가 적용된 낚싯대 지급
	giveEnchantedRod(plr, item.storageName)

	if itemname == "GoldRod" then
		setFavoriteRemote:FireClient(plr)
	end
end)
