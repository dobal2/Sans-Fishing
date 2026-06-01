local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LeaderstatsDataManager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))

local DailyRewardStore = DataStoreService:GetDataStore("DailyRewards2")

local miscRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc")
local ClaimDailyReward = miscRemotes:WaitForChild("ClaimDailyReward")
local CheckDailyReward = miscRemotes:WaitForChild("CheckDailyReward")

-- FishCaughtBindable을 서버 시작 시 한 번만 resolve (핸들러 안에서 WaitForChild 하지 않음)
local FishCaughtBindable = ServerScriptService:WaitForChild("FishCaughtBindable", 30)

local DailyResetBindable = Instance.new("BindableEvent")
DailyResetBindable.Name = "DailyResetBindable"
DailyResetBindable.Parent = ServerScriptService

local DailySkipBindable = Instance.new("BindableEvent")
DailySkipBindable.Name = "DailySkipBindable"
DailySkipBindable.Parent = ServerScriptService

local DAILY_REWARDS = {
	[1] = { type = "Coins",  amount = 500 },
	[2] = { type = "Rod",    rodName = "EquinoxRod" },
	[3] = { type = "Fish",   fishName = "Sans" },
	[4] = { type = "Coins",  amount = 150000 },
	[5] = { type = "Fish",   fishName = "Nyan Cat" },
	[6] = { type = "Coins",  amount = 300000 },
	[7] = { type = "Rod",    rodName = "SilkRod" },
}

-- Check/Claim 쿨다운 분리
local CheckCooldowns = {}
local ClaimCooldowns = {}

-- 중복 클레임 방지 락
local claimInProgress = {}

local function getCurrentDay()
	return math.floor(os.time() / 86400)
end

local function loadData(player)
	local ok, data = pcall(function()
		return DailyRewardStore:GetAsync(tostring(player.UserId))
	end)
	if ok and data then return data end
	return { lastClaimDay = nil, streak = 0 }
end

-- 저장 실패 시 재시도 1회, 성공 여부 반환
local function saveData(player, data)
	for attempt = 1, 2 do
		local ok = pcall(function()
			DailyRewardStore:SetAsync(tostring(player.UserId), data)
		end)
		if ok then return true end
		if attempt < 2 then task.wait(1) end
	end
	return false
end

local function canRequest(cooldowns, player)
	local now = tick()
	local last = cooldowns[player.UserId]
	if last and now - last < 1 then return false end
	cooldowns[player.UserId] = now
	return true
end

local function computeDay(data)
	local today = getCurrentDay()
	local streak = data.streak or 0
	local last = data.lastClaimDay

	if last == nil then
		return 1
	elseif today - last == 1 then
		local next = streak + 1
		if next > 7 then next = 1 end
		return next
	elseif today == last then
		return streak
	else
		return 1
	end
end

local function giveReward(player, reward)
	if reward.type == "Coins" then
		local ls = player:FindFirstChild("leaderstats")
		local coins = ls and ls:FindFirstChild("Coins")
		if not coins then return false end
		local newVal = coins.Value + reward.amount
		coins.Value = newVal
		LeaderstatsDataManager:UpdateData(player, "Coins", newVal)
		local soldNotification = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SoldNotification")
		soldNotification:FireClient(player, reward.amount, false)
		return true

	elseif reward.type == "Rod" then
		local rodTool = ServerStorage:FindFirstChild(reward.rodName)
		if not rodTool then
			warn("[DailyReward] Rod not found in ServerStorage:", reward.rodName)
			return false
		end
		local ls = player:FindFirstChild("leaderstats")
		local rodsFolder = ls and ls:FindFirstChild("Rods")
		if rodsFolder then
			local bv = rodsFolder:FindFirstChild(reward.rodName)
			if not bv then
				bv = Instance.new("BoolValue")
				bv.Name = reward.rodName
				bv.Parent = rodsFolder
			end
			bv.Value = true
		end
		local data = LeaderstatsDataManager:GetData(player)
		if data then
			if not data.Rods then data.Rods = {} end
			data.Rods[reward.rodName] = true
			LeaderstatsDataManager:UpdateData(player, "Rods", data.Rods)
			data.CurrentRod = reward.rodName
			LeaderstatsDataManager:UpdateData(player, "CurrentRod", reward.rodName)
		end
		if ls then
			local currentRodVal = ls:FindFirstChild("CurrentRod")
			if currentRodVal then currentRodVal.Value = reward.rodName end
		end
		local starterGear = player:FindFirstChild("StarterGear")
		if starterGear then
			for _, tool in ipairs(starterGear:GetChildren()) do
				if tool:IsA("Tool") and tool:FindFirstChild("CastRod") then tool:Destroy() end
			end
			rodTool:Clone().Parent = starterGear
		end
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			for _, tool in ipairs(backpack:GetChildren()) do
				if tool:IsA("Tool") and tool:FindFirstChild("CastRod") then tool:Destroy() end
			end
			if player.Character then
				for _, tool in ipairs(player.Character:GetChildren()) do
					if tool:IsA("Tool") and tool:FindFirstChild("CastRod") then tool:Destroy() end
				end
			end
			rodTool:Clone().Parent = backpack
		end
		return true

	elseif reward.type == "Fish" then
		if not FishCaughtBindable then
			warn("[DailyReward] FishCaughtBindable not available")
			return false
		end
		local FishData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDataModule"))
		local fishInfo = nil
		for _, rarity in ipairs(FishData.Rarities or {}) do
			for _, fish in ipairs(rarity.fishes or {}) do
				if fish.fishName == reward.fishName then
					local minW = math.max(fish.minWeight or 1, 10)
					local maxW = math.min(fish.maxWeight or 100, 99)
					if minW > maxW then minW = maxW end
					local randWeight = math.floor((minW + math.random() * (maxW - minW)) * 10 + 0.5) / 10
					fishInfo = {
						fishName      = fish.fishName,
						name          = rarity.name,
						weight        = randWeight,
						minWeight     = fish.minWeight or 1,
						maxWeight     = fish.maxWeight or 100,
						value         = fish.value or 0,
						isFrozen      = false,
						isFestival    = false,
						isSansVariant = false,
						isGoldVariant = false,
					}
					break
				end
			end
			if fishInfo then break end
		end
		if not fishInfo then
			warn("[DailyReward] Fish not found in FishDataModule:", reward.fishName)
			return false
		end
		FishCaughtBindable:Fire(player, fishInfo)
		return true
	end

	return false
end

CheckDailyReward.OnServerEvent:Connect(function(player)
	if not canRequest(CheckCooldowns, player) then return end
	local data = loadData(player)
	local today = getCurrentDay()
	local canClaim = data.lastClaimDay ~= today
	local day = computeDay(data)
	CheckDailyReward:FireClient(player, {
		canClaim = canClaim,
		day = day,
		streak = data.streak or 0,
	})
end)

ClaimDailyReward.OnServerEvent:Connect(function(player)
	if not canRequest(ClaimCooldowns, player) then return end

	-- Race condition 방지 락
	if claimInProgress[player.UserId] then return end
	claimInProgress[player.UserId] = true

	local ok_outer = pcall(function()
		local data = loadData(player)
		local today = getCurrentDay()

		if data.lastClaimDay == today then
			ClaimDailyReward:FireClient(player, { success = false, reason = "already_claimed" })
			return
		end

		local day = computeDay(data)
		local reward = DAILY_REWARDS[day]
		if not reward then
			ClaimDailyReward:FireClient(player, { success = false, reason = "no_reward" })
			return
		end

		local ok = giveReward(player, reward)
		if not ok then
			ClaimDailyReward:FireClient(player, { success = false, reason = "give_failed" })
			return
		end

		-- 보상 지급 성공 → 저장 (실패 시 클라이언트에 알림)
		data.lastClaimDay = today
		data.streak = day
		local saved = saveData(player, data)
		if not saved then
			-- 저장 실패: 클라이언트에는 성공으로 표시하되 warn (보상은 이미 줬으므로)
			warn("[DailyReward] DataStore save failed for", player.Name, "day", day)
		end

		ClaimDailyReward:FireClient(player, {
			success = true,
			day = day,
			reward = reward,
			equippedRod  = (reward.type == "Rod")  and reward.rodName  or nil,
			equippedFish = (reward.type == "Fish") and reward.fishName or nil,
		})
	end)

	if not ok_outer then
		warn("[DailyReward] Claim handler error for", player.Name)
	end

	claimInProgress[player.UserId] = nil
end)

DailyResetBindable.Event:Connect(function(player)
	local data = { lastClaimDay = nil, streak = 0 }
	saveData(player, data)
	ClaimDailyReward:FireClient(player, { success = false, reason = "reset" })
	CheckDailyReward:FireClient(player, { canClaim = true, day = 1, streak = 0 })
end)

DailySkipBindable.Event:Connect(function(player)
	local data = loadData(player)
	local today = getCurrentDay()
	local day = computeDay(data)
	local nextDay = day < 7 and day + 1 or 1
	data.lastClaimDay = today - 1
	data.streak = nextDay - 1  -- computeDay가 streak+1을 반환하므로 nextDay-1로 저장
	saveData(player, data)
	CheckDailyReward:FireClient(player, {
		canClaim = true,
		day = nextDay,
		streak = data.streak,
		openGui = true,
	})
end)

Players.PlayerRemoving:Connect(function(player)
	CheckCooldowns[player.UserId] = nil
	ClaimCooldowns[player.UserId] = nil
	claimInProgress[player.UserId] = nil
end)
