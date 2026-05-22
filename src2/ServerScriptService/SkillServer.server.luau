local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local datamanager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))

local CURRENCY_COIN         = "Coins"
local CURRENCY_FISHINGPOINT = "FishingPoint"

--[[
	costs[i]   = Lv(i-1) → Lv(i) 비용
	effects[i] = Lv i 효과값
]]
local SKILLS = {
	-- 루트 (모든 스킬트리 잠금 해제)
	Root = {
		currency = CURRENCY_COIN,
		maxLevel = 1,
		costs    = { 1000 },
		effects  = { 1 },
	},
	AutoFish = {
		currency = CURRENCY_COIN,
		maxLevel = 1,
		costs    = { 2000 },
		effects  = { 1 },
	},
	-- 코인 전용
	LuckUp = {
		currency = CURRENCY_COIN,
		maxLevel = 7,
		costs    = { 2000, 10000, 100000, 500000, 2500000, 7500000, 22500000 },
		effects  = { 0.10,  0.30,   0.60,   1.00,     1.50,    2.00,      2.50 },
	},
	SellBonus = {
		currency = CURRENCY_COIN,
		maxLevel = 6,
		costs    = { 10000, 80000, 500000, 2500000, 5000000, 15000000 },
		effects  = { 0.10,   0.20,   0.30,     0.40,    0.50,      0.65 },
	},
	FriendBonus = {
		currency = CURRENCY_COIN,
		maxLevel = 3,
		costs    = { 10000, 50000, 200000 },
		-- 친구 1명당 럭 보너스 추가값
		effects  = { 0.15, 0.30, 0.50 },
	},
	-- 피싱포인트 전용
	FishingPoint = {
		currency = CURRENCY_FISHINGPOINT,
		maxLevel = 1,
		costs    = { 10 },
		effects  = { 1 },
	},
	HitZoneUp = {
		currency = CURRENCY_FISHINGPOINT,
		maxLevel = 3,
		costs    = { 20, 100, 400 },
		effects  = { 0.06, 0.10, 0.15 },
	},
	WeightUp = {
		currency = CURRENCY_FISHINGPOINT,
		maxLevel = 4,
		costs    = { 40, 200, 800, 3000 },
		effects  = { 0.04, 0.10, 0.18, 0.28 },
	},
	PowerUp = {
		currency = CURRENCY_FISHINGPOINT,
		maxLevel = 3,
		costs    = { 40, 200, 800 },
		effects  = { 0.05, 0.10, 0.20 },
	},
	QuickBite = {
		currency = CURRENCY_COIN,
		maxLevel = 3,
		costs    = { 50000, 300000, 1500000 },
		effects  = { 0.5, 1.5, 2.5 },
	},
	AutoUp = {
		currency = CURRENCY_COIN,
		maxLevel = 3,
		costs    = { 100000, 1000000, 5000000 },
		effects  = { 0.1, 0.4, 0.8 },
	},
	PointBoost = {
		currency = CURRENCY_COIN,
		maxLevel = 3,
		costs    = { 5000000, 20000000, 100000000 },
		effects  = { 1, 2, 3 },
	},
}

-- 리모트 생성
local skillBuyEvent = Instance.new("RemoteEvent")
skillBuyEvent.Name = "SkillBuyEvent"
skillBuyEvent.Parent = ReplicatedStorage

local getSkillData = Instance.new("RemoteFunction")
getSkillData.Name = "GetSkillData"
getSkillData.Parent = ReplicatedStorage

local function getCurrencyValue(player, currencyType)
	if currencyType == CURRENCY_COIN then
		local ls = player:FindFirstChild("leaderstats")
		local c  = ls and ls:FindFirstChild("Coins")
		return c and c.Value or 0, c
	elseif currencyType == CURRENCY_FISHINGPOINT then
		local sp = player:FindFirstChild("SkillPoints")
		return sp and sp.Value or 0, sp
	end
	return 0, nil
end

local function getSkillLevel(player, skillName)
	local folder = player:FindFirstChild("Skills")
	local sv     = folder and folder:FindFirstChild(skillName)
	return sv and sv.Value or 0
end

-- 클라이언트 데이터 조회
getSkillData.OnServerInvoke = function(player)
	local folder   = player:FindFirstChild("Skills")
	local spVal    = player:FindFirstChild("SkillPoints")
	local ls       = player:FindFirstChild("leaderstats")
	local coinsVal = ls and ls:FindFirstChild("Coins")
	if not folder then return nil end

	local levels = {}
	for _, sv in ipairs(folder:GetChildren()) do
		if sv:IsA("IntValue") then
			levels[sv.Name] = sv.Value
		end
	end

	return {
		fishingPoints = spVal and spVal.Value or 0,
		coins         = coinsVal and coinsVal.Value or 0,
		levels        = levels,
		skills        = SKILLS,
	}
end

local skillBuyCooldowns = {}
Players.PlayerRemoving:Connect(function(player) skillBuyCooldowns[player] = nil end)

-- 스킬 구매: client → FireServer(skillName, targetStage)
-- targetStage 는 구매하려는 단계 번호 (currentLevel + 1 이어야 함)
skillBuyEvent.OnServerEvent:Connect(function(player, skillName, targetStage)
	local now = tick()
	-- 스킬별 쿨다운 (동시 다른 스킬 요청으로 잔액 음수 방지)
	if not skillBuyCooldowns[player] then skillBuyCooldowns[player] = {} end
	if skillBuyCooldowns[player][skillName] and now - skillBuyCooldowns[player][skillName] < 0.5 then return end
	skillBuyCooldowns[player][skillName] = now
	local cfg = SKILLS[skillName]
	if not cfg then
		warn("SkillServer: 알 수 없는 스킬:", skillName, player.Name)
		return
	end

	if type(targetStage) ~= "number" then
		warn("SkillServer: 잘못된 stage 형식:", tostring(targetStage), player.Name)
		return
	end

	local currentLevel = getSkillLevel(player, skillName)

	-- Root 미해금 시 다른 스킬 구매 불가
	if skillName ~= "Root" and getSkillLevel(player, "Root") == 0 then
		skillBuyEvent:FireClient(player, "fail", "ROOT_LOCKED", skillName)
		return
	end

	-- FriendBonus는 LuckUp Lv2 이상 필요
	if skillName == "FriendBonus" and getSkillLevel(player, "LuckUp") < 2 then
		skillBuyEvent:FireClient(player, "fail", "REQUIREMENT_NOT_MET", skillName)
		return
	end

	-- FP 화폐 사용 노드(HitZoneUp, WeightUp, PowerUp)는 FishingPoint Lv1 이상 필요
	if (skillName == "HitZoneUp" or skillName == "WeightUp" or skillName == "PowerUp")
		and getSkillLevel(player, "FishingPoint") < 1 then
		skillBuyEvent:FireClient(player, "fail", "REQUIREMENT_NOT_MET", skillName)
		return
	end

	-- HitZoneUp은 PowerUp Lv1 이상 필요
	if skillName == "HitZoneUp" and getSkillLevel(player, "PowerUp") < 1 then
		skillBuyEvent:FireClient(player, "fail", "REQUIREMENT_NOT_MET", skillName)
		return
	end

	-- AutoUp은 AutoFish Lv1 이상 필요
	if skillName == "AutoUp" and getSkillLevel(player, "AutoFish") < 1 then
		skillBuyEvent:FireClient(player, "fail", "REQUIREMENT_NOT_MET", skillName)
		return
	end

	-- QuickBite는 AutoFish Lv1 이상 필요
	if skillName == "QuickBite" and getSkillLevel(player, "AutoFish") < 1 then
		skillBuyEvent:FireClient(player, "fail", "REQUIREMENT_NOT_MET", skillName)
		return
	end

	-- PointBoost는 SellBonus Lv1 이상 필요
	if skillName == "PointBoost" and getSkillLevel(player, "SellBonus") < 1 then
		skillBuyEvent:FireClient(player, "fail", "REQUIREMENT_NOT_MET", skillName)
		return
	end

	-- 반드시 다음 단계만 구매 가능 (건너뛰기 방지)
	if targetStage ~= currentLevel + 1 then
		skillBuyEvent:FireClient(player, "fail", "WRONG_STAGE", skillName)
		return
	end

	if currentLevel >= cfg.maxLevel then
		skillBuyEvent:FireClient(player, "fail", "MAX_LEVEL", skillName)
		return
	end

	local cost = cfg.costs[targetStage]
	local balance, valueObj = getCurrencyValue(player, cfg.currency)

	if balance < cost then
		skillBuyEvent:FireClient(player, "fail", "NOT_ENOUGH", skillName, cfg.currency)
		return
	end

	local folder = player:FindFirstChild("Skills")
	local sv     = folder and folder:FindFirstChild(skillName)
	if not sv then return end

	valueObj.Value = valueObj.Value - cost
	sv.Value = targetStage

	-- profile.Data에 즉시 반영 (SafeSavePlayer 전 서버 종료 대비)
	local skillsData = {}
	for _, s in ipairs(folder:GetChildren()) do
		if s:IsA("IntValue") then
			skillsData[s.Name] = s.Value
		end
	end
	datamanager:UpdateData(player, "Skills", skillsData)

	if cfg.currency == CURRENCY_COIN then
		datamanager:UpdateData(player, "Coins", valueObj.Value)
	else
		datamanager:UpdateData(player, "SkillPoints", valueObj.Value)
	end

	skillBuyEvent:FireClient(player, "success", skillName, targetStage)
end)
