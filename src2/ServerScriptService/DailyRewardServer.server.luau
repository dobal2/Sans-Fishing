-- Server script for ServerScriptService
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- DataStore setup
local DailyRewardStore = DataStoreService:GetDataStore("DailyRewards")

local miscRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc")
local ClaimDailyReward = miscRemotes:WaitForChild("ClaimDailyReward")
local CheckDailyReward = miscRemotes:WaitForChild("CheckDailyReward")

-- Daily reward settings (different reward per day)
local DAILY_REWARDS = {
	[1] = {type = "Coins", amount = 2000, name = "2000 Coins"},
	[2] = {type = "Bubble", toolName = "Strength Bubble", name = "Strength Bubble"},
	[3] = {type = "Coins", amount = 10000, name = "10000 Coins"},
	[4] = {type = "Bubble", toolName = "SizeBuff Bubble", name = "SizeBuff Bubble"},
	[5] = {type = "Coins", amount = 30000, name = "30000 Coins"},
	[6] = {type = "Bubble", toolName = "Luck Bubble", name = "Luck Bubble"},
	[7] = {type = "Coins", amount = 200000, name = "200000 Coins"}
}

-- Request rate limiting to prevent exploits
local PlayerRequestTimes = {}
local REQUEST_COOLDOWN = 1 -- 1 second cooldown

-- Get current day (UTC)
local function getCurrentDay()
	return math.floor(os.time() / 86400) -- 86400 seconds = 1 day
end

-- Calculate consecutive days
local function getConsecutiveDays(lastClaimDay, currentDay)
	if lastClaimDay == nil then
		return 0
	elseif currentDay - lastClaimDay == 1 then
		return 1 -- Consecutive
	else
		return 0 -- Streak broken
	end
end

-- Load player data
local function loadPlayerData(player)
	local success, data = pcall(function()
		return DailyRewardStore:GetAsync(player.UserId)
	end)

	if success and data then
		return data
	else
		return {
			lastClaimDay = nil,
			consecutiveDays = 0
		}
	end
end

-- Save player data
local function savePlayerData(player, data)
	local success = pcall(function()
		DailyRewardStore:SetAsync(player.UserId, data)
	end)
	return success
end

-- Request rate limit check
local function canMakeRequest(player)
	local userId = player.UserId
	local currentTime = tick()

	if PlayerRequestTimes[userId] then
		if currentTime - PlayerRequestTimes[userId] < REQUEST_COOLDOWN then
			return false
		end
	end

	PlayerRequestTimes[userId] = currentTime
	return true
end

-- Give reward
local function giveReward(player, reward)
	if reward.type == "Coins" then
		-- Add coins to leaderstats
		local leaderstats = player:WaitForChild("leaderstats")
		if leaderstats then
			local money = leaderstats:WaitForChild("leaderstats")
			if money then
				money.Value = money.Value + reward.amount
				return true
			end
		end

	elseif reward.type == "Bubble" then
		-- Add tool to backpack
		local tool = ServerStorage:WaitForChild("Bubbles"):FindFirstChild(reward.toolName)
		if tool then
			local clonedTool = tool:Clone()
			clonedTool.Parent = player.Backpack
			return true
		end
	end

	return false
end

-- Check daily reward
CheckDailyReward.OnServerEvent:Connect(function(player)
	if not canMakeRequest(player) then
		return -- Spam prevention
	end

	local playerData = loadPlayerData(player)
	local currentDay = getCurrentDay()

	-- Check if already claimed today
	local canClaim = playerData.lastClaimDay ~= currentDay
	local consecutiveDays = playerData.consecutiveDays

	if playerData.lastClaimDay and currentDay - playerData.lastClaimDay == 1 then
		consecutiveDays = consecutiveDays + 1
	elseif playerData.lastClaimDay ~= currentDay then
		consecutiveDays = 1
	end

	-- Reset to day 1 after 7 days
	if consecutiveDays > 7 then
		consecutiveDays = 1
	end

	local nextReward = DAILY_REWARDS[consecutiveDays]

	CheckDailyReward:FireClient(player, {
		canClaim = canClaim,
		consecutiveDays = consecutiveDays,
		nextReward = nextReward
	})
end)

-- Claim daily reward
ClaimDailyReward.OnServerEvent:Connect(function(player)
	if not canMakeRequest(player) then
		return -- Spam prevention
	end

	local playerData = loadPlayerData(player)
	local currentDay = getCurrentDay()

	-- Prevent duplicate claims
	if playerData.lastClaimDay == currentDay then
		ClaimDailyReward:FireClient(player, {
			success = false,
			message = "You have already claimed your reward today!"
		})
		return
	end

	-- Calculate consecutive days
	local consecutiveDays = playerData.consecutiveDays
	if playerData.lastClaimDay and currentDay - playerData.lastClaimDay == 1 then
		consecutiveDays = consecutiveDays + 1
	else
		consecutiveDays = 1
	end

	-- Reset to day 1 after 7 days
	if consecutiveDays > 7 then
		consecutiveDays = 1
	end

	local reward = DAILY_REWARDS[consecutiveDays]

	-- Give reward
	local success = giveReward(player, reward)

	if success then
		-- Update data
		playerData.lastClaimDay = currentDay
		playerData.consecutiveDays = consecutiveDays

		local saveSuccess = savePlayerData(player, playerData)

		if saveSuccess then
			ClaimDailyReward:FireClient(player, {
				success = true,
				reward = reward,
				consecutiveDays = consecutiveDays
			})
		else
			ClaimDailyReward:FireClient(player, {
				success = false,
				message = "An error occurred while saving data."
			})
		end
	else
		ClaimDailyReward:FireClient(player, {
			success = false,
			message = "An error occurred while giving the reward."
		})
	end
end)

-- Clean up request records when player leaves
Players.PlayerRemoving:Connect(function(player)
	PlayerRequestTimes[player.UserId] = nil
end)
