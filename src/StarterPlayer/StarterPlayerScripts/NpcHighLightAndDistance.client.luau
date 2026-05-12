local player = game.Players.LocalPlayer
local sellShop = workspace:WaitForChild("Sell Shop"):WaitForChild("Seller")
local gambler = workspace:WaitForChild("Gambler")
local updateShop = workspace:WaitForChild("Upgrade Shop"):WaitForChild("ShopSeller")
local robuxShop = workspace:WaitForChild("Pap")
local boatDealer1 = workspace:WaitForChild("BoatDealer1")
local boatDealer2 = workspace:WaitForChild("BoatDealer2")
local voidQuestGiver = workspace:WaitForChild("Void Quest Giver") -- Void Quest Giver 추가

local TweenService = game:GetService("TweenService")

-- Highlight 생성
local sellHighlight = sellShop:FindFirstChild("Highlight") or Instance.new("Highlight")
sellHighlight.Parent = sellShop

local gambleHighlight = gambler:FindFirstChild("Highlight") or Instance.new("Highlight")
gambleHighlight.Parent = gambler

local updateHighlight = updateShop:FindFirstChild("Highlight") or Instance.new("Highlight")
updateHighlight.Parent = updateShop

local robuxHighlight = robuxShop:FindFirstChild("Highlight") or Instance.new("Highlight")
robuxHighlight.Parent = robuxShop

local boatDealer1Highlight = boatDealer1:FindFirstChild("Highlight") or Instance.new("Highlight")
boatDealer1Highlight.Parent = boatDealer1

local boatDealer2Highlight = boatDealer2:FindFirstChild("Highlight") or Instance.new("Highlight")
boatDealer2Highlight.Parent = boatDealer2

-- Void Quest Giver Highlight 추가
local voidQuestHighlight = voidQuestGiver:FindFirstChild("Highlight") or Instance.new("Highlight")
voidQuestHighlight.Parent = voidQuestGiver

local RANGE = 10
local UPDATE_SHOP_RANGE = 15  -- 업그레이드 상점만 별도 거리
local VOID_QUEST_RANGE = 12   -- Void Quest Giver 거리
local CHECK_INTERVAL = 0.1
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sellChoiceEvent = ReplicatedStorage:WaitForChild("SellChoiceEvent")

-- Void Quest 관련 이벤트
local voidQuestEvents = ReplicatedStorage:WaitForChild("VoidQuestEvents")
local voidQuestChoiceEvent = voidQuestEvents:WaitForChild("VoidQuestChoiceEvent")

-- 캐릭터 로드 대기
repeat task.wait(0.1) until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

-- NPC 위치 찾기 함수
local function getNPCPosition(npc)
	if npc.PrimaryPart then
		return npc.PrimaryPart.Position
	end
	local part = npc:FindFirstChild("HumanoidRootPart", true) or
		npc:FindFirstChild("Torso", true) or
		npc:FindFirstChild("UpperTorso", true) or
		npc:FindFirstChild("Head", true) or
		npc:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or Vector3.new(0, 0, 0)
end

-- 하이라이트 애니메이션 함수
local function animateHighlight(highlight, targetTransparency)
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(highlight, tweenInfo, {OutlineTransparency = targetTransparency})
	tween:Play()
end

-- NPC 상호작용 가능 여부 체크
local function canInteractWithNPC(npc)
	local prompt = npc:FindFirstChild("ProximityPrompt")
	return prompt and prompt.Enabled
end

local wasNearby = {
	seller = false,
	gambler = false,
	questGiver = false,
	updateShop = false,
	robuxShop = false,
	boatDealer1 = false,
	boatDealer2 = false,
	voidQuestGiver = false  -- Void Quest Giver 추가
}

-- 거리 체크 함수 (NPC별 다른 거리 적용)
local function isPlayerNearby(npc, customRange)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	local playerPos = character.HumanoidRootPart.Position
	local npcPos = getNPCPosition(npc)
	local distance = (playerPos - npcPos).Magnitude
	local range = customRange or RANGE
	return distance <= range
end

-- 초기 상태
sellHighlight.Enabled = true
sellHighlight.OutlineTransparency = 1
gambleHighlight.Enabled = true
gambleHighlight.OutlineTransparency = 1
updateHighlight.Enabled = true
updateHighlight.OutlineTransparency = 1
robuxHighlight.Enabled = true
robuxHighlight.OutlineTransparency = 1
boatDealer1Highlight.Enabled = true
boatDealer1Highlight.OutlineTransparency = 1
boatDealer2Highlight.Enabled = true
boatDealer2Highlight.OutlineTransparency = 1
voidQuestHighlight.Enabled = true  -- Void Quest Giver 초기화
voidQuestHighlight.OutlineTransparency = 1

-- Void Quest Giver 특별 색상 설정 (보라색)
voidQuestHighlight.OutlineColor = Color3.fromRGB(150, 100, 255)
voidQuestHighlight.FillColor = Color3.fromRGB(150, 100, 255)
voidQuestHighlight.FillTransparency = 0.8

-- 메인 루프
while true do
	task.wait(CHECK_INTERVAL)
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		continue
	end

	-- Seller
	local sellNearby = isPlayerNearby(sellShop)
	local canInteractSeller = canInteractWithNPC(sellShop)
	local shouldShowSellerHighlight = sellNearby and canInteractSeller

	if shouldShowSellerHighlight ~= wasNearby.seller then
		animateHighlight(sellHighlight, shouldShowSellerHighlight and 0 or 1)
	end

	if not sellNearby and wasNearby.seller then
		sellChoiceEvent:FireServer("Option4")  -- 조건 제거
		local gui = player.PlayerGui:FindFirstChild("SellOptions")
		if gui then gui.Enabled = false end
	end

	wasNearby.seller = shouldShowSellerHighlight

	-- Gambler
	local gambleNearby = isPlayerNearby(gambler)
	local canInteractGambler = canInteractWithNPC(gambler)
	local shouldShowGamblerHighlight = gambleNearby and canInteractGambler

	if shouldShowGamblerHighlight ~= wasNearby.gambler then
		animateHighlight(gambleHighlight, shouldShowGamblerHighlight and 0 or 1)
	end

	if not gambleNearby and wasNearby.gambler then
		local gambleChoiceEvent = ReplicatedStorage:WaitForChild("GambleChoiceEvent")
		gambleChoiceEvent:FireServer("Option2")  -- 조건 제거
		local gui = player.PlayerGui:FindFirstChild("GambleOptions")
		if gui then gui.Enabled = false end
	end
	wasNearby.gambler = shouldShowGamblerHighlight

	-- Update Shop (15 거리 적용)
	local updateNearby = isPlayerNearby(updateShop, UPDATE_SHOP_RANGE)
	local canInteractUpdate = canInteractWithNPC(updateShop)
	local shouldShowUpdateHighlight = updateNearby and canInteractUpdate

	if shouldShowUpdateHighlight ~= wasNearby.updateShop then
		animateHighlight(updateHighlight, shouldShowUpdateHighlight and 0 or 1)
	end
	wasNearby.updateShop = shouldShowUpdateHighlight

	-- Robux Shop
	local robuxNearby = isPlayerNearby(robuxShop)
	local canInteractRobux = canInteractWithNPC(robuxShop)
	local shouldShowRobuxHighlight = robuxNearby and canInteractRobux

	if shouldShowRobuxHighlight ~= wasNearby.robuxShop then
		animateHighlight(robuxHighlight, shouldShowRobuxHighlight and 0 or 1)
	end
	wasNearby.robuxShop = shouldShowRobuxHighlight

	-- Boat Dealer 1
	local boatDealer1Nearby = isPlayerNearby(boatDealer1)
	local canInteractBoatDealer1 = canInteractWithNPC(boatDealer1)
	local shouldShowBoatDealer1Highlight = boatDealer1Nearby and canInteractBoatDealer1

	if shouldShowBoatDealer1Highlight ~= wasNearby.boatDealer1 then
		animateHighlight(boatDealer1Highlight, shouldShowBoatDealer1Highlight and 0 or 1)
	end
	wasNearby.boatDealer1 = shouldShowBoatDealer1Highlight

	-- Boat Dealer 2
	local boatDealer2Nearby = isPlayerNearby(boatDealer2)
	local canInteractBoatDealer2 = canInteractWithNPC(boatDealer2)
	local shouldShowBoatDealer2Highlight = boatDealer2Nearby and canInteractBoatDealer2

	if shouldShowBoatDealer2Highlight ~= wasNearby.boatDealer2 then
		animateHighlight(boatDealer2Highlight, shouldShowBoatDealer2Highlight and 0 or 1)
	end
	wasNearby.boatDealer2 = shouldShowBoatDealer2Highlight

	-- Void Quest Giver 추가
	local voidQuestNearby = isPlayerNearby(voidQuestGiver, VOID_QUEST_RANGE)
	local canInteractVoidQuest = canInteractWithNPC(voidQuestGiver)
	local shouldShowVoidQuestHighlight = voidQuestNearby and canInteractVoidQuest

	if shouldShowVoidQuestHighlight ~= wasNearby.voidQuestGiver then
		animateHighlight(voidQuestHighlight, shouldShowVoidQuestHighlight and 0 or 1)
	end

	if not voidQuestNearby and wasNearby.voidQuestGiver then
		voidQuestChoiceEvent:FireServer("Option2")  -- 조건 제거
		local gui = player.PlayerGui:FindFirstChild("VoidQuestOptions")
		if gui then gui.Enabled = false end
	end
	wasNearby.voidQuestGiver = shouldShowVoidQuestHighlight
end
