local datamanager = require(script.DataManager)
local DataService = game:GetService("DataStoreService")
local MyData = DataService:GetDataStore("playerdata")
local ServerStorage = game:GetService("ServerStorage")
local players = game.Players

-- Daily quest related functions
local function getCurrentDateString()
	local currentTime = os.time()
	local date = os.date("*t", currentTime)
	return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

local function createDailyPlaytimeQuest()
	return {
		id = "daily_playtime_15min",
		name = "Daily Playtime",
		description = "Play for 15 minutes today to earn daily reward!",
		targetFish = "",
		requiredProgress = 900,
		rewardCoins = 50000,
		isReceived = true,
		currentProgress = 0,
		questType = "daily_playtime"
	}
end

-- Create void quest backup
local function createVoidQuestBackup()
	return {
		id = "void_unknown_challenge",
		name = "Void Challenge: Unknown Hunt",
		description = "Catch 10 Unknown fish for the mysterious void collector",
		targetFish = "Unknown",
		requiredProgress = 10,
		rewardCoins = 1000000,
		isReceived = false,
		currentProgress = 0,
		questType = "void"
	}
end

-- Store session start time and base playtime per player
local playerSessionStartTime = {}
local playerBasePlaytime = {}  -- Playtime saved at session start

players.PlayerAdded:Connect(function(plr)
	wait(2)

	repeat task.wait()
		local dataReady = plr:FindFirstChild("DataReady")
	until dataReady and dataReady.Value == true

	-- Create quest folder
	local leaderstats = plr:FindFirstChild("leaderstats")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = plr

	local Quests = Instance.new("Folder")
	Quests.Name = "Quests"

	local ActiveQuests = Instance.new("Folder")
	ActiveQuests.Name = "ActiveQuests"
	ActiveQuests.Parent = Quests

	local CompletedQuests = Instance.new("Folder")
	CompletedQuests.Name = "CompletedQuests"
	CompletedQuests.Parent = Quests

	-- Quest creation function
	local function createQuest(questData, questId)
		if not questData then
			warn("questData is nil")
			return nil
		end

		local id = questData.id or questId
		if not id then
			warn("Quest ID not found:", questData)
			return nil
		end

		local questFolder = Instance.new("Folder")
		questFolder.Name = id

		local questName = Instance.new("StringValue")
		questName.Name = "QuestName"
		questName.Value = questData.name or "Unknown Quest"
		questName.Parent = questFolder

		local questDescription = Instance.new("StringValue")
		questDescription.Name = "QuestDescription"
		questDescription.Value = questData.description or "No description"
		questDescription.Parent = questFolder

		local targetFish = Instance.new("StringValue")
		targetFish.Name = "TargetFish"
		targetFish.Value = questData.targetFish or ""
		targetFish.Parent = questFolder

		local currentProgress = Instance.new("IntValue")
		currentProgress.Name = "CurrentProgress"
		currentProgress.Value = questData.currentProgress or 0
		currentProgress.Parent = questFolder

		local requiredProgress = Instance.new("IntValue")
		requiredProgress.Name = "RequiredProgress"
		requiredProgress.Value = questData.requiredProgress or 1
		requiredProgress.Parent = questFolder

		local rewardCoins = Instance.new("IntValue")
		rewardCoins.Name = "RewardCoins"
		rewardCoins.Value = questData.rewardCoins or 0
		rewardCoins.Parent = questFolder

		local isReceived = Instance.new("BoolValue")
		isReceived.Name = "IsReceived"
		isReceived.Value = questData.isReceived or false
		isReceived.Parent = questFolder

		local questType = Instance.new("StringValue")
		questType.Name = "QuestType"
		questType.Value = questData.questType or "normal"
		questType.Parent = questFolder

		return questFolder
	end

	-- Add quest folder to leaderstats
	Quests.Parent = leaderstats

	-- Load data
	local Data
	repeat
		task.wait()
		Data = datamanager:GetData(plr)
	until Data


	-- Check daily quest
	local currentDate = getCurrentDateString()
	local lastQuestDate = Data.LastQuestDate


	-- If a new day, remove old daily quests
	if lastQuestDate ~= currentDate then
		Data.LastQuestDate = currentDate

		-- Remove existing daily quests
		if Data.Quests and Data.Quests.ActiveQuests then
			for questId, questData in pairs(Data.Quests.ActiveQuests) do
				if questData.questType == "daily_playtime" then
					Data.Quests.ActiveQuests[questId] = nil
				end
			end
		end

		-- Create new daily quest
		if not Data.Quests then Data.Quests = {} end
		if not Data.Quests.ActiveQuests then Data.Quests.ActiveQuests = {} end

		local dailyQuest = createDailyPlaytimeQuest()
		Data.Quests.ActiveQuests[dailyQuest.id] = dailyQuest

		datamanager:SafeSavePlayer(plr)
	end

	-- Force check and create void quest

	-- Verify data initialization
	if not Data.Quests then Data.Quests = {} end
	if not Data.Quests.ActiveQuests then Data.Quests.ActiveQuests = {} end
	if not Data.Quests.CompletedQuests then Data.Quests.CompletedQuests = {} end

	-- Check void quest status
	local hasVoidQuest = Data.Quests.ActiveQuests["void_unknown_challenge"] ~= nil
	local voidQuestCompleted = Data.Quests.CompletedQuests["void_unknown_challenge"] == true


	-- Force create void quest if missing
	if not hasVoidQuest and not voidQuestCompleted then
		local voidQuest = createVoidQuestBackup()
		Data.Quests.ActiveQuests[voidQuest.id] = voidQuest
		Data.VoidQuestInitialized = true
		datamanager:SafeSavePlayer(plr)
	end

	-- Apply quest data
	if Data and Data.Quests then
		-- Load active quests
		for questId, questData in pairs(Data.Quests.ActiveQuests or {}) do
			local questFolder = createQuest(questData, questId)
			if questFolder then
				questFolder.Parent = ActiveQuests

				-- Save base playtime for playtime quests
				if questData.questType == "daily_playtime" then
					playerBasePlaytime[plr.UserId] = questData.currentProgress or 0
					playerSessionStartTime[plr.UserId] = tick()
				end
			else
				warn("Quest creation failed:", questId)
			end
		end

		-- Load completed quests
		for questId, isCompleted in pairs(Data.Quests.CompletedQuests or {}) do
			if isCompleted then
				local completedQuest = Instance.new("BoolValue")
				completedQuest.Name = questId
				completedQuest.Value = true
				completedQuest.Parent = CompletedQuests
			end
		end
	end

	-- Create daily quest if missing (fallback)
	local hasDailyQuest = false
	for _, quest in pairs(ActiveQuests:GetChildren()) do
		if quest:IsA("Folder") then
			local questType = quest:FindFirstChild("QuestType")
			if questType and questType.Value == "daily_playtime" then
				hasDailyQuest = true
				break
			end
		end
	end

	if not hasDailyQuest then
		local dailyQuest = createDailyPlaytimeQuest()
		local questFolder = createQuest(dailyQuest, dailyQuest.id)
		if questFolder then
			questFolder.Parent = ActiveQuests
			playerBasePlaytime[plr.UserId] = 0
			playerSessionStartTime[plr.UserId] = tick()
		end
	end

	-- Set session start time if no playtime quest existed
	if not playerSessionStartTime[plr.UserId] then
		playerSessionStartTime[plr.UserId] = tick()
		playerBasePlaytime[plr.UserId] = 0
	end

	-- Print final quest status (for reference)
	for _, quest in pairs(ActiveQuests:GetChildren()) do
		if quest:IsA("Folder") then
			local questType = quest:FindFirstChild("QuestType")
			local isReceived = quest:FindFirstChild("IsReceived")
		end
	end

	-- Playtime update function (revised)
	local function updatePlaytimeQuest()
		if not playerSessionStartTime[plr.UserId] or not playerBasePlaytime[plr.UserId] then return end

		local leaderstats = plr:FindFirstChild("leaderstats")
		if not leaderstats then return end

		local quests = leaderstats:FindFirstChild("Quests")
		if not quests then return end

		local activeQuests = quests:FindFirstChild("ActiveQuests")
		if not activeQuests then return end

		-- Find daily playtime quest
		for _, quest in pairs(activeQuests:GetChildren()) do
			if quest:IsA("Folder") then
				local questType = quest:FindFirstChild("QuestType")
				if questType and questType.Value == "daily_playtime" then
					local currentProgress = quest:FindFirstChild("CurrentProgress")
					local requiredProgress = quest:FindFirstChild("RequiredProgress")
					local rewardCoins = quest:FindFirstChild("RewardCoins")

					if currentProgress and requiredProgress and rewardCoins then
						-- Calculate current session time
						local sessionTime = tick() - playerSessionStartTime[plr.UserId]
						-- Base playtime + current session time
						local totalPlaytime = playerBasePlaytime[plr.UserId] + sessionTime

						-- Auto-complete and reward at 15 minutes
						if totalPlaytime >= requiredProgress.Value then
							-- Give coins
							local coins = leaderstats:FindFirstChild("Coins")
							if coins then
								coins.Value = coins.Value + rewardCoins.Value
							end

							-- Remove quest
							quest:Destroy()

							-- Clean up tracking data
							playerSessionStartTime[plr.UserId] = nil
							playerBasePlaytime[plr.UserId] = nil
							return
						else
							-- Update for display only (not saved)
							local displayProgress = math.min(math.floor(totalPlaytime), requiredProgress.Value)
							currentProgress.Value = displayProgress
						end
					end
				end
			end
		end
	end

	-- Check playtime every second
	spawn(function()
		while plr.Parent and playerSessionStartTime[plr.UserId] do
			wait(1)
			updatePlaytimeQuest()
		end
	end)

	-- Fish catch detection system
	local function updateQuestProgress(fishName)
		local leaderstats = plr:FindFirstChild("leaderstats")
		if not leaderstats then return end

		local quests = leaderstats:FindFirstChild("Quests")
		if not quests then return end

		local activeQuests = quests:FindFirstChild("ActiveQuests")
		if not activeQuests then return end

		-- Check all active quests (excluding playtime quests)
		for _, quest in pairs(activeQuests:GetChildren()) do
			if quest:IsA("Folder") then
				local targetFish = quest:FindFirstChild("TargetFish")
				local currentProgress = quest:FindFirstChild("CurrentProgress")
				local requiredProgress = quest:FindFirstChild("RequiredProgress")
				local isReceived = quest:FindFirstChild("IsReceived")
				local questName = quest:FindFirstChild("QuestName")
				local questType = quest:FindFirstChild("QuestType")

				-- Only process non-playtime quests
				if questType and questType.Value ~= "daily_playtime" and
					targetFish and currentProgress and requiredProgress and isReceived and questName then

					if isReceived.Value and targetFish.Value == fishName and currentProgress.Value < requiredProgress.Value then
						currentProgress.Value = currentProgress.Value + 1

						if currentProgress.Value >= requiredProgress.Value then
						end
					end
				end
			end
		end
	end

	-- Set up backpack detection on character spawn
	plr.CharacterAdded:Connect(function(character)
		local backpack = plr:FindFirstChild("Backpack")
		if not backpack then return end

		backpack.ChildAdded:Connect(function(item)
			if item:IsA("Tool") and item:FindFirstChild("FishValue") then
				updateQuestProgress(item.Name)
			end
		end)
	end)

	-- Set up immediately if character already exists
	if plr.Character then
		local backpack = plr:FindFirstChild("Backpack")
		if backpack then
			backpack.ChildAdded:Connect(function(item)
				if item:IsA("Tool") and item:FindFirstChild("FishValue") then
					updateQuestProgress(item.Name)
				end
			end)
		end
	end
end)

players.PlayerRemoving:Connect(function(plr)
	-- Save playtime to database
	if playerSessionStartTime[plr.UserId] and playerBasePlaytime[plr.UserId] then
		local leaderstats = plr:FindFirstChild("leaderstats")
		if leaderstats then
			local quests = leaderstats:FindFirstChild("Quests")
			if quests then
				local activeQuests = quests:FindFirstChild("ActiveQuests")
				if activeQuests then
					for _, quest in pairs(activeQuests:GetChildren()) do
						if quest:IsA("Folder") then
							local questType = quest:FindFirstChild("QuestType")
							if questType and questType.Value == "daily_playtime" then
								local currentProgress = quest:FindFirstChild("CurrentProgress")
								if currentProgress then
									-- Add current session time and save
									local sessionTime = tick() - playerSessionStartTime[plr.UserId]
									local finalPlaytime = playerBasePlaytime[plr.UserId] + sessionTime
									currentProgress.Value = finalPlaytime
								end
							end
						end
					end
				end
			end
		end
	end

	-- Clean up session data
	playerSessionStartTime[plr.UserId] = nil
	playerBasePlaytime[plr.UserId] = nil

	datamanager:SafeSavePlayer(plr)
end)
