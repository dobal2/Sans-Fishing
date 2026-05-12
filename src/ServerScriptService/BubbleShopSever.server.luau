local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- Bubble 데이터 (모두 10만 코인)
local BUBBLE_DATA = {
	["Strength Bubble"] = 50000,
	["SizeBuff Bubble"] = 75000,
	["Luck Bubble"] = 100000
}

-- 인벤토리 확장 게임패스 ID
local INVENTORY_EXPANSION_GAMEPASS_ID = 1294285302

-- BindableEvent 찾기/생성
local buyBubbleBindable = ReplicatedStorage:FindFirstChild("BuyBubbleBindable")
if not buyBubbleBindable then
	buyBubbleBindable = Instance.new("BindableEvent")
	buyBubbleBindable.Name = "BuyBubbleBindable"
	buyBubbleBindable.Parent = ReplicatedStorage
end

-- 노티스 RemoteEvent 찾기
local showNoticeEvent = ReplicatedStorage:FindFirstChild("ShowNoticeEvent")

-- 낚싯대 확인 함수
local function IsRod(itemName)
	itemName = itemName:lower()
	return itemName:match("rod$") ~= nil or itemName:match("trap$") ~= nil
end

-- 인벤토리 확장 게임패스 확인 함수
local function hasInventoryExpansionGamepass(player)
	local success, hasGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, INVENTORY_EXPANSION_GAMEPASS_ID)
	end)

	if success then
		return hasGamepass
	else
		warn("인벤토리 확장 게임패스 확인 실패:", player.Name)
		return false
	end
end

-- 인벤토리 한도 확인 함수
local function getInventoryLimit(player)
	local baseLimit = 100
	local expandedLimit = 200

	if hasInventoryExpansionGamepass(player) then
		return expandedLimit
	else
		return baseLimit
	end
end

-- 인벤토리 체크 함수
local function checkInventorySpace(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return true end

	local itemCount = 0

	-- 모든 도구 카운트 (낚싯대 제외)
	for _, item in pairs(backpack:GetChildren()) do
		if item:IsA("Tool") and not IsRod(item.Name) then
			itemCount = itemCount + 1
		end
	end

	local inventoryLimit = getInventoryLimit(player)

	print("인벤토리 체크:", player.Name, "아이템 수:", itemCount, "한도:", inventoryLimit)

	return itemCount < inventoryLimit
end

buyBubbleBindable.Event:Connect(function(plr, bubbleName)
	print("Bubble 구매 처리 시작:", plr.Name, bubbleName)

	-- 인벤토리 공간 확인
	if not checkInventorySpace(plr) then
		print("인벤토리 가득참:", plr.Name)
		local hasExpansion = hasInventoryExpansionGamepass(plr)
		local message = hasExpansion and
			"Expanded inventory full! Go sell fish (Max 200)" or
			"Inventory full! Go sell fish or buy expansion pass (Max 100)"

		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, message)
		end
		return
	end

	-- Bubble 가격 확인
	local bubblePrice = BUBBLE_DATA[bubbleName]
	if not bubblePrice then
		warn("알 수 없는 Bubble:", bubbleName)
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Unknown Bubble!")
		end
		return
	end

	local leaderstats = plr:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("leaderstats 없음:", plr.Name)
		return
	end

	local coins = leaderstats:FindFirstChild("Coins")
	if not coins then
		warn("Coins 없음:", plr.Name)
		return
	end

	-- 코인 부족한 경우
	if coins.Value < bubblePrice then
		print("코인 부족:", plr.Name, "필요:", bubblePrice, "보유:", coins.Value)
		local message = string.format("Not enough coins! Need %s coins", bubblePrice)
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, message)
		end
		return
	end

	-- ServerStorage의 BubbleTools 폴더에서 버블 툴 찾기
	local bubbleToolsFolder = ServerStorage:FindFirstChild("BubbleTools")
	if not bubbleToolsFolder then
		warn("BubbleTools 폴더가 ServerStorage에 없음")
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Bubble tools not found!")
		end
		return
	end

	local bubbleTool = bubbleToolsFolder:FindFirstChild(bubbleName)
	if not bubbleTool then
		warn("BubbleTools 폴더에 버블 툴 없음:", bubbleName)
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Bubble tool not found!")
		end
		return
	end

	-- 구매 처리 직전 재확인 (동시 구매 방지)
	if not checkInventorySpace(plr) then
		print("구매 직전 인벤토리 재확인 실패:", plr.Name)
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Inventory became full!")
		end
		return
	end

	-- 구매 처리
	coins.Value = coins.Value - bubblePrice

	-- 백팩에 버블 툴 추가
	local playerBackpack = plr:FindFirstChild("Backpack")
	if playerBackpack then
		local clonedBubble = bubbleTool:Clone()
		clonedBubble.Parent = playerBackpack
		print("Bubble 구매 완료:", bubbleName, "→", plr.Name, "| 남은 코인:", coins.Value)
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Bubble purchased successfully!")
		end
	else
		warn("플레이어 백팩 없음:", plr.Name)
		-- 코인 환불
		coins.Value = coins.Value + bubblePrice
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Purchase failed - no backpack!")
		end
	end
end)
