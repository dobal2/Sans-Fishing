local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local getSkillData          = ReplicatedStorage:WaitForChild("GetSkillData")
local getFriendsCountRemote = ReplicatedStorage:WaitForChild("GetFriendsCountRemote")

local GROUP_ID             = 9744474
local LUCK_X2_PASS         = 1289569606
local COIN_X2_PASS         = 1293430515

local cachedLuckPass  = nil
local cachedCoinPass  = nil
local passLastFetch   = -999
local lastBoostMult   = 1

local function checkPasses()
	local now = tick()
	if now - passLastFetch < 60 then return end
	passLastFetch = now
	pcall(function()
		cachedLuckPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, LUCK_X2_PASS)
	end)
	pcall(function()
		cachedCoinPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, COIN_X2_PASS)
	end)
end

local LUCK_BY_ROD = {
	FishingRod  = 0,
	SliverRod   = 15,
	GoldRod     = 30,
	CrystalRod  = 50,
	MagneticRod = 70,
	BoneRod     = 100,
	CloverRod   = 140,
	RainbowRod  = 190,
	UnknownRod  = 250,
	RobuxRod    = 320,
	ElectricRod = 400,
	BlockyRod   = 500,
	ArcaneRod   = 600,
	VoidRod     = 800,
}

local function getRodLuckPercent()
	local char = player.Character or player.CharacterAdded:Wait()
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			local pct = LUCK_BY_ROD[tool.Name]
			if pct then return pct end
		end
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local pct = LUCK_BY_ROD[tool.Name]
				if pct then return pct end
			end
		end
	end
	return 0
end

local lastFriendsCount = 0
local lastFriendsFetch = -30

local function getFriendsCount()
	local now = tick()
	if now - lastFriendsFetch >= 30 then
		lastFriendsFetch = now
		local ok, count = pcall(function()
			return getFriendsCountRemote:InvokeServer()
		end)
		if ok and count then
			lastFriendsCount = count
		end
	end
	return lastFriendsCount
end

local function isInGroup()
	local ok, result = pcall(function()
		return player:IsInGroup(GROUP_ID)
	end)
	return ok and result
end

local function updateLabels()
	local main = playerGui:FindFirstChild("Main")
	if not main then return end
	local luckLabel = main:FindFirstChild("LuckLabel", true)
	local coinLabel = main:FindFirstChild("CoinLabel", true)
	if not luckLabel and not coinLabel then return end

	local data = getSkillData:InvokeServer()
	if not data then return end

	local levels = data.levels or {}
	local skills = data.skills or {}

	local function getEffect(skillName)
		local level = levels[skillName] or 0
		if level == 0 then return 0 end
		local cfg = skills[skillName]
		return cfg and cfg.effects and (cfg.effects[level] or 0) or 0
	end

	checkPasses()
	local friendsCount = getFriendsCount()

	-- LuckLabel: 낚싯대 + LuckUp 스킬 + FriendBonus×친구수, Luck x2 패스면 2배, 서버부스트 배율 추가
	if luckLabel then
		local rodLuck       = getRodLuckPercent()
		local luckUpPct     = math.floor(getEffect("LuckUp") * 100)
		local friendLuckPct = math.floor(getEffect("FriendBonus") * friendsCount * 100)
		local baseLuck      = rodLuck + luckUpPct + friendLuckPct
		local afterPass     = cachedLuckPass and (baseLuck * 2) or baseLuck

		local afterBoost = afterPass * lastBoostMult
		local hasBubble = player:GetAttribute("LuckBubbleBuff") == true
		local totalLuck = math.floor(hasBubble and (afterBoost + 200) or afterBoost)
		luckLabel.Text = "+" .. totalLuck .. "%"
	end

	-- CoinLabel: SellBonus 스킬 + 그룹 15% + 친구수×5%, Coin x2 패스면 전체 2배
	if coinLabel then
		local sellBonusPct  = math.floor(getEffect("SellBonus") * 100)
		local groupPct      = isInGroup() and 15 or 0
		local friendCoinPct = friendsCount * 5
		local baseCoin      = sellBonusPct + groupPct + friendCoinPct
		local totalCoin     = cachedCoinPass and (baseCoin * 2) or baseCoin
		coinLabel.Text = "+" .. totalCoin .. "%"
	end
end

local lastUpdate = 0
local isUpdating = false
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastUpdate >= 5 and not isUpdating then
		lastUpdate = now
		task.spawn(function()
			isUpdating = true
			updateLabels()
			isUpdating = false
		end)
	end
end)

-- 서버 부스트: 배율이 실제로 바뀔 때만 갱신 (1초마다 브로드캐스트되므로 값 비교 필요)
local serverBoostRemote = ReplicatedStorage:WaitForChild("ServerBoostRemote")
serverBoostRemote.OnClientEvent:Connect(function(_, mult)
	local newMult = (type(mult) == "number") and mult or 1
	if newMult == lastBoostMult then return end
	lastBoostMult = newMult
	if not isUpdating then
		task.spawn(function()
			isUpdating = true
			updateLabels()
			isUpdating = false
		end)
	end
end)

task.spawn(function()
	player:WaitForChild("DataReady", 30)
	task.wait(1)
	updateLabels()
end)
