local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local getSkillData          = ReplicatedStorage:WaitForChild("GetSkillData")
local getFriendsCountRemote = ReplicatedStorage:WaitForChild("GetFriendsCountRemote")
local BobberData            = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BobberDataModule"))

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

local RodData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RodDataModule"))

local function getRodLuckPercent()
	local function luckFromRodName(toolName)
		for _, data in pairs(RodData.Rods) do
			if data.storageName == toolName then
				local s = tostring(data.luck or "+0%")
				return tonumber(s:match("([%d%.]+)")) or 0
			end
		end
		return 0
	end

	local char = player.Character or player.CharacterAdded:Wait()
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			local pct = luckFromRodName(tool.Name)
			if pct > 0 then return pct end
		end
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local pct = luckFromRodName(tool.Name)
				if pct > 0 then return pct end
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

-- 스킬/이펙트 캐시 (getSkillData 서버 왕복 최소화)
local cachedSkillData = nil
local skillDataLastFetch = -999
local SKILL_CACHE_TTL = 10  -- 스킬은 직접 살 때만 바뀌므로 10초 캐시

local function getSkillDataCached()
	local now = tick()
	if not cachedSkillData or now - skillDataLastFetch >= SKILL_CACHE_TTL then
		local ok, data = pcall(function() return getSkillData:InvokeServer() end)
		if ok and data then
			cachedSkillData = data
			skillDataLastFetch = now
		end
	end
	return cachedSkillData
end

local function invalidateSkillCache()
	skillDataLastFetch = -999
end

local isUpdating = false
local pendingUpdate = false

local function updateLabels()
	if isUpdating then
		pendingUpdate = true
		return
	end
	isUpdating = true
	pendingUpdate = false

	task.spawn(function()
		local main = playerGui:FindFirstChild("Main")
		local luckLabel = main and main:FindFirstChild("LuckLabel", true)
		local coinLabel = main and main:FindFirstChild("CoinLabel", true)

		if luckLabel or coinLabel then
			local data = getSkillDataCached()
			if data then
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
				local eventLuckMult = player:GetAttribute("EventLuckMult") or 1
				local eventCoinMult = player:GetAttribute("EventCoinMult") or 1

				local ls = player:FindFirstChild("leaderstats")
				local equippedBobber = ls and ls:FindFirstChild("EquippedBobber") and ls.EquippedBobber.Value or "Basic Bobber"
				local bobberFx = BobberData.GetEffects(equippedBobber)
				local bobberLuckPct = math.floor((bobberFx.luckBonus or 0) * 100)
				local bobberSellPct = math.floor((bobberFx.sellBonus or 0) * 100)

				if luckLabel then
					local rodLuck       = getRodLuckPercent()
					local luckUpPct     = math.floor(getEffect("LuckUp") * 100)
					local friendLuckPct = math.floor(getEffect("FriendBonus") * friendsCount * 100)
					local baseLuck      = rodLuck + luckUpPct + friendLuckPct + bobberLuckPct
					local afterPass     = cachedLuckPass and (baseLuck * 2) or baseLuck
					local afterBoost    = afterPass * lastBoostMult * eventLuckMult
					local hasBubble     = player:GetAttribute("LuckBubbleBuff") == true
					local totalLuck     = math.floor(hasBubble and (afterBoost + 200) or afterBoost)
					luckLabel.Text = "+" .. totalLuck .. "%"
				end

				if coinLabel then
					local sellBonusPct  = math.floor(getEffect("SellBonus") * 100)
					local groupPct      = isInGroup() and 50 or 0
					local friendCoinPct = friendsCount * 5
					local baseCoin      = sellBonusPct + groupPct + friendCoinPct + bobberSellPct
					local afterPass     = cachedCoinPass and (baseCoin * 2) or baseCoin
					local totalCoin     = math.floor(afterPass * eventCoinMult)
					coinLabel.Text = "+" .. totalCoin .. "%"
				end
			end
		end

		isUpdating = false
		if pendingUpdate then
			updateLabels()
		end
	end)
end

-- 로드 장착/해제 시 즉시 갱신
local function watchCharacterTools(char)
	if not char then return end
	char.ChildAdded:Connect(function(obj)
		if obj:IsA("Tool") then updateLabels() end
	end)
	char.ChildRemoved:Connect(function(obj)
		if obj:IsA("Tool") then updateLabels() end
	end)
end

player.CharacterAdded:Connect(function(char)
	watchCharacterTools(char)
	updateLabels()
end)
if player.Character then
	watchCharacterTools(player.Character)
end

-- Attribute 변경 시 즉시 갱신 (버블버프, 이벤트 배율, 찌 장착 등)
player.AttributeChanged:Connect(function(attr)
	if attr == "LuckBubbleBuff" or attr == "EventLuckMult" or attr == "EventCoinMult" then
		updateLabels()
	end
end)

-- 찌(Bobber) 변경 시 즉시 갱신
task.spawn(function()
	local ls = player:WaitForChild("leaderstats", 30)
	if not ls then return end
	local bobberVal = ls:WaitForChild("EquippedBobber", 10)
	if bobberVal then
		bobberVal.Changed:Connect(function()
			updateLabels()
		end)
	end
	-- 스킬 구매 시 즉시 갱신 (Skills 폴더 내 IntValue 변경)
	local skillsFolder = player:WaitForChild("Skills", 10)
	if skillsFolder then
		for _, sv in ipairs(skillsFolder:GetChildren()) do
			if sv:IsA("IntValue") then
				sv.Changed:Connect(function()
					invalidateSkillCache()
					updateLabels()
				end)
			end
		end
		skillsFolder.ChildAdded:Connect(function(sv)
			if sv:IsA("IntValue") then
				sv.Changed:Connect(function()
					invalidateSkillCache()
					updateLabels()
				end)
			end
		end)
	end
end)

-- 서버 부스트: 배율이 실제로 바뀔 때만 갱신
local serverBoostRemote = ReplicatedStorage:WaitForChild("ServerBoostRemote")
serverBoostRemote.OnClientEvent:Connect(function(_, mult)
	local newMult = (type(mult) == "number") and mult or 1
	if newMult == lastBoostMult then return end
	lastBoostMult = newMult
	updateLabels()
end)

-- 1초 폴링 (친구수 등 이벤트로 감지 불가한 변화 대비)
task.spawn(function()
	while true do
		task.wait(1)
		updateLabels()
	end
end)

task.spawn(function()
	player:WaitForChild("DataReady", 30)
	task.wait(1)
	updateLabels()
end)
