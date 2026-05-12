local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- Robux Fish Trap 게임패스 ID
local ROBUX_FISHTRAP_GAMEPASS_ID = 1423175879

-- 게임패스 구매 완료 처리를 위한 테이블
local pendingGamepassPurchases = {}

-- Fish Trap 데이터 (Robux Fish Trap 추가)
local FISH_TRAP_DATA = {
	["BasicFishTrap"] = 10000,
	["AdvancedFishTrap"] = 50000,
	["MasterFishTrap"] = 200000,
	["RobuxFishTrap"] = 0 -- 게임패스로만 구매 가능
}

-- BindableEvent 찾기/생성
local buyFishTrapBindable = ReplicatedStorage:FindFirstChild("BuyFishTrapBindable")
if not buyFishTrapBindable then
	buyFishTrapBindable = Instance.new("BindableEvent")
	buyFishTrapBindable.Name = "BuyFishTrapBindable"
	buyFishTrapBindable.Parent = ReplicatedStorage
end

-- 노티스 RemoteEvent 찾기 (없으면 생성)
local showNoticeEvent = ReplicatedStorage:FindFirstChild("ShowNoticeEvent")

-- 게임패스 소유 확인 함수
local function hasGamepass(player, gamepassId)
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	return success and result
end

-- Fish Trap 장착 함수
local function equipFishTrap(plr, fishTrapName)
	-- 기존 Fish Trap 제거
	for _, container in ipairs({ plr:FindFirstChild("Backpack"), plr:FindFirstChild("StarterGear"), plr.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool.Name:find("FishTrap") then
					tool:Destroy()
				end
			end
		end
	end

	-- 새 Fish Trap 장착
	local trapModel = ServerStorage:FindFirstChild(fishTrapName)
	if trapModel then
		local clonedTrap = trapModel:Clone()
		clonedTrap.Parent = plr:FindFirstChild("Backpack") or plr

		-- CurrentFishTrap 값 업데이트
		local leaderstats = plr:FindFirstChild("leaderstats")
		if leaderstats then
			local currentFishTrap = leaderstats:FindFirstChild("CurrentFishTrap")
			if currentFishTrap then
				local currentFishTrapValue = currentFishTrap:FindFirstChild("Value")
				if currentFishTrapValue then
					currentFishTrapValue.Value = fishTrapName
				end
			end
		end

		print("Fish Trap 장착 완료:", fishTrapName, "→", plr.Name)
		return true
	else
		warn("ServerStorage에 Fish Trap 없음:", fishTrapName)
		return false
	end
end

-- Robux Fish Trap 게임패스 구매 처리
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if gamePassId == ROBUX_FISHTRAP_GAMEPASS_ID and wasPurchased then
		print("게임패스 구매 완료:", player.Name)

		-- 구매 대기 목록에 있는지 확인
		if pendingGamepassPurchases[player.UserId] then
			pendingGamepassPurchases[player.UserId] = nil

			-- 즉시 Robux Fish Trap 지급
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local fishTrapsFolder = leaderstats:FindFirstChild("FishTraps")
				if fishTrapsFolder then
					local robuxFishTrap = fishTrapsFolder:FindFirstChild("RobuxFishTrap")
					if robuxFishTrap then
						robuxFishTrap.Value = true
						if equipFishTrap(player, "RobuxFishTrap") then
							print("게임패스 구매 후 Robux Fish Trap 지급 완료:", player.Name)
							showNoticeEvent:FireClient(player, "Robux Fish Trap purchased and equipped!")
						else
							showNoticeEvent:FireClient(player, "Robux Fish Trap purchased but failed to equip!")
						end
					end
				end
			end
		end
	end
end)

buyFishTrapBindable.Event:Connect(function(plr, fishTrapName)
	print("Fish Trap 처리 시작:", plr.Name, fishTrapName)

	-- Fish Trap 가격 확인
	local fishTrapPrice = FISH_TRAP_DATA[fishTrapName]
	if not fishTrapPrice then
		warn("알 수 없는 Fish Trap:", fishTrapName)
		showNoticeEvent:FireClient(plr, "Unknown Fish Trap!")
		return
	end

	local leaderstats = plr:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("leaderstats 없음:", plr.Name)
		return
	end

	local coins = leaderstats:FindFirstChild("Coins")
	local currentFishTrap = leaderstats:FindFirstChild("CurrentFishTrap")
	local fishTrapsFolder = leaderstats:FindFirstChild("FishTraps")

	if not (coins and currentFishTrap and fishTrapsFolder) then
		warn("필수 leaderstats 요소 없음:", plr.Name)
		return
	end

	local fishTrapBool = fishTrapsFolder:FindFirstChild(fishTrapName)
	if not fishTrapBool then
		warn("Fish Trap Bool 값 없음:", plr.Name, fishTrapName)
		return
	end

	-- Robux Fish Trap 특별 처리
	if fishTrapName == "RobuxFishTrap" then
		-- 이미 소유한 경우 → 장착
		if fishTrapBool.Value then
			print("이미 소유중인 Robux Fish Trap 장착:", plr.Name)
			if equipFishTrap(plr, fishTrapName) then
				showNoticeEvent:FireClient(plr, "Robux Fish Trap equipped!")
			else
				showNoticeEvent:FireClient(plr, "Failed to equip Robux Fish Trap!")
			end
			return
		end

		-- 게임패스 확인
		if not hasGamepass(plr, ROBUX_FISHTRAP_GAMEPASS_ID) then
			-- 게임패스 구매 대기 목록에 추가
			pendingGamepassPurchases[plr.UserId] = true

			showNoticeEvent:FireClient(plr, "Purchasing Robux Fish Trap gamepass...")
			print("Robux Fish Trap 게임패스 구매창 표시:", plr.Name)

			-- 게임패스 구매창 표시
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(plr, ROBUX_FISHTRAP_GAMEPASS_ID)
			end)
			return
		end

		-- 게임패스 소유자에게 무료 지급
		fishTrapBool.Value = true
		if equipFishTrap(plr, fishTrapName) then
			print("Robux Fish Trap 무료 지급 완료:", plr.Name)
			showNoticeEvent:FireClient(plr, "Robux Fish Trap obtained for free with gamepass!")
		else
			showNoticeEvent:FireClient(plr, "Robux Fish Trap obtained but failed to equip!")
		end
		return
	end

	-- 이미 소유한 경우 → 장착
	if fishTrapBool.Value then
		print("이미 소유중인 Fish Trap 장착:", fishTrapName, "→", plr.Name)
		if equipFishTrap(plr, fishTrapName) then
			showNoticeEvent:FireClient(plr, "Fish Trap equipped!")
		else
			showNoticeEvent:FireClient(plr, "Failed to equip Fish Trap!")
		end
		return
	end

	-- 코인 부족한 경우
	if coins.Value < fishTrapPrice then
		print("코인 부족:", plr.Name, "필요:", fishTrapPrice, "보유:", coins.Value)
		local message = string.format("Not enough coins! Need %s coins", fishTrapPrice)
		showNoticeEvent:FireClient(plr, message)
		return
	end

	-- 구매 처리
	coins.Value = coins.Value - fishTrapPrice
	fishTrapBool.Value = true

	-- Fish Trap 장착
	if equipFishTrap(plr, fishTrapName) then
		print("Fish Trap 구매 완료:", fishTrapName, "→", plr.Name, "| 남은 코인:", coins.Value)
		showNoticeEvent:FireClient(plr, "Fish Trap purchased successfully!")
	else
		-- 구매는 했지만 장착 실패한 경우
		print("Fish Trap 구매 완료하지만 장착 실패:", fishTrapName, "→", plr.Name)
		showNoticeEvent:FireClient(plr, "Fish Trap purchased but failed to equip!")
	end
end)

-- 플레이어 나갈 때 대기 목록에서 제거
game.Players.PlayerRemoving:Connect(function(player)
	pendingGamepassPurchases[player.UserId] = nil
end)
