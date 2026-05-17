local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local datamanager = require(script.DataManager)
local leaderstatsDataManager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))

-- ── Sequential quest definitions ──────────────────────────────────────────────

local SEQUENTIAL_QUESTS = {
	{ id="seq_01", name="First Catch",        description="Catch 3 Common fish",                  questType="rarity",      targetRarity="Common",    requiredProgress=3,  rewardCoins=300    },
	{ id="seq_02", name="Getting Started",     description="Catch 10 fish",                        questType="count",                                  requiredProgress=10, rewardCoins=500    },
	{ id="seq_03", name="Upgrade Your Rod",    description="Buy the Silver Rod",                   questType="rod",         targetRod="SliverRod",    requiredProgress=1,  rewardCoins=800    },
	{ id="seq_04", name="Better Fish",         description="Catch 3 Uncommon fish",                questType="rarity",      targetRarity="Uncommon",  requiredProgress=3,  rewardCoins=1500   },
	{ id="seq_05", name="Common Collector",    description="Register all 3 Common species",        questType="all_species", targetRarity="Common",    requiredProgress=3,  rewardCoins=2000   },
	{ id="seq_06", name="Gold Standard",       description="Buy the Gold Rod",                     questType="rod",         targetRod="GoldRod",      requiredProgress=1,  rewardCoins=2000   },
	{ id="seq_07", name="Keep Fishing",        description="Catch 30 fish",                        questType="count",                                  requiredProgress=30, rewardCoins=3000   },
	{ id="seq_08", name="Rare Hunter",         description="Catch 2 Rare fish",                    questType="rarity",      targetRarity="Rare",      requiredProgress=2,  rewardCoins=4000   },
	{ id="seq_09", name="Uncommon Collector",  description="Register all 3 Uncommon species",      questType="all_species", targetRarity="Uncommon",  requiredProgress=3,  rewardCoins=5000   },
	{ id="seq_10", name="Crystal Clear",       description="Buy the Crystal Rod",                  questType="rod",         targetRod="CrystalRod",   requiredProgress=1,  rewardCoins=6000   },
	{ id="seq_11", name="Epic Encounter",      description="Catch 1 Epic fish",                    questType="rarity",      targetRarity="Epic",      requiredProgress=1,  rewardCoins=10000  },
	{ id="seq_12", name="Rare Collector",      description="Register all 3 Rare species",          questType="all_species", targetRarity="Rare",      requiredProgress=3,  rewardCoins=12000  },
	{ id="seq_13", name="Magnetic Pull",       description="Buy the Magnetic Rod",                 questType="rod",         targetRod="MagneticRod",  requiredProgress=1,  rewardCoins=12000  },
	{ id="seq_14", name="Legendary Fisher",    description="Catch 1 Legendary fish",               questType="rarity",      targetRarity="Legendary", requiredProgress=1,  rewardCoins=20000  },
	{ id="seq_15", name="Epic Collector",      description="Register all 2 Epic species",          questType="all_species", targetRarity="Epic",      requiredProgress=2,  rewardCoins=25000  },
	{ id="seq_16", name="Bone Collector",      description="Buy the Bone Rod",                     questType="rod",         targetRod="BoneRod",      requiredProgress=1,  rewardCoins=25000  },
	{ id="seq_17", name="Mystic Depths",       description="Catch 1 Mystic fish",                  questType="rarity",      targetRarity="Mystic",    requiredProgress=1,  rewardCoins=40000  },
	{ id="seq_18", name="Legendary Collector", description="Register all 2 Legendary species",     questType="all_species", targetRarity="Legendary", requiredProgress=2,  rewardCoins=45000  },
	{ id="seq_19", name="Four Leaf Luck",      description="Buy the Clover Rod",                   questType="rod",         targetRod="CloverRod",    requiredProgress=1,  rewardCoins=50000  },
	{ id="seq_20", name="Heavy Hitter",        description="Catch a fish weighing 30kg or more",   questType="weight",      targetWeight=30,           requiredProgress=1,  rewardCoins=55000  },
	{ id="seq_21", name="Mystic Collector",    description="Register all 2 Mystic species",        questType="all_species", targetRarity="Mystic",    requiredProgress=2,  rewardCoins=70000  },
	{ id="seq_22", name="Over the Rainbow",    description="Buy the Rainbow Rod",                  questType="rod",         targetRod="RainbowRod",   requiredProgress=1,  rewardCoins=80000  },
	{ id="seq_23", name="Fantasy Fisher",      description="Catch 1 Fantasy fish",                 questType="rarity",      targetRarity="Fantasy",   requiredProgress=1,  rewardCoins=120000 },
	{ id="seq_24", name="Fantasy Collector",   description="Register all 3 Fantasy species",       questType="all_species", targetRarity="Fantasy",   requiredProgress=3,  rewardCoins=200000 },
	{ id="seq_25", name="The Unknown",         description="Catch 1 Unknown fish",                 questType="rarity",      targetRarity="Unknown",   requiredProgress=1,  rewardCoins=400000 },
}

-- Attach sequential index for runtime convenience
for i, q in ipairs(SEQUENTIAL_QUESTS) do
	q.index = i
end

local RARITY_SPECIES = {
	Common    = {"Small Carp", "Gold Fish", "Stone Fish"},
	Uncommon  = {"Crab", "Crystal Bass", "Dust Fish"},
	Rare      = {"Bass", "Snow Fish", "Diri"},
	Epic      = {"Dragon Head Fish", "Reggigash"},
	Legendary = {"Golden Trout", "Armor Fish"},
	Mystic    = {"Shark", "Ray"},
	Fantasy   = {"Undyine", "Sans", "Electric Fish"},
	Unknown   = {"Unknown", "Nyan Cat"},
}

-- ── Daily quest helpers ────────────────────────────────────────────────────────

local DAILY_QUEST_POOL = {
	{ name="Daily Catch",     description="Catch 20 fish today",          questType="daily_random", subType="count",  requiredProgress=20, rewardFP=15 },
	{ name="Common Day",      description="Catch 5 Common fish today",     questType="daily_random", subType="rarity", targetRarity="Common",    requiredProgress=5,  rewardFP=15 },
	{ name="Uncommon Day",    description="Catch 5 Uncommon fish today",   questType="daily_random", subType="rarity", targetRarity="Uncommon",  requiredProgress=5,  rewardFP=18 },
	{ name="Rare Day",        description="Catch 3 Rare fish today",       questType="daily_random", subType="rarity", targetRarity="Rare",      requiredProgress=3,  rewardFP=20 },
	{ name="Epic Day",        description="Catch 2 Epic fish today",       questType="daily_random", subType="rarity", targetRarity="Epic",      requiredProgress=2,  rewardFP=23 },
	{ name="Legendary Day",   description="Catch 1 Legendary fish today",  questType="daily_random", subType="rarity", targetRarity="Legendary", requiredProgress=1,  rewardFP=25 },
	{ name="Mystic Day",      description="Catch 1 Mystic fish today",     questType="daily_random", subType="rarity", targetRarity="Mystic",    requiredProgress=1,  rewardFP=28 },
	{ name="Fantasy Day",     description="Catch 1 Fantasy fish today",    questType="daily_random", subType="rarity", targetRarity="Fantasy",   requiredProgress=1,  rewardFP=30 },
}

local function getCurrentDateString()
	local currentTime = os.time()
	local date = os.date("*t", currentTime)
	return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

local function pickDailyQuest(seed)
	math.randomseed(seed or os.time())
	local pick = DAILY_QUEST_POOL[math.random(1, #DAILY_QUEST_POOL)]
	return {
		id            = "daily_random_quest",
		name          = pick.name,
		description   = pick.description,
		targetFish    = pick.targetRarity or "",
		requiredProgress = pick.requiredProgress,
		rewardCoins   = 0,
		rewardFP      = pick.rewardFP,
		isReceived    = true,
		currentProgress = 0,
		questType     = "daily_random",
		subType       = pick.subType,
		targetRarity  = pick.targetRarity or "",
	}
end

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

-- ── Parse fish tool name ───────────────────────────────────────────────────────

local function parseFishTool(toolName)
	-- toolName format: "Small Carp [Common] - 1.2kg" or "Frozen Small Carp [Common] - 1.2kg"
	local rarity = toolName:match("%[(.-)%]")
	local weight = tonumber(toolName:match("(%d+%.?%d*)kg"))
	local baseName = toolName:match("^(.-)%s+%[") or toolName
	baseName = baseName:gsub("^Frozen ", ""):gsub("^Festival ", "")
	return baseName, rarity, weight
end

-- ── Sequential quest helpers ───────────────────────────────────────────────────

local function getNoticeEvent()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return nil end
	local notice = remotes:FindFirstChild("Notice")
	if not notice then return nil end
	return notice:FindFirstChild("ShowNoticeEvent")
end

local function getActiveQuestsFolder(plr)
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then return nil end
	local quests = ls:FindFirstChild("Quests")
	if not quests then return nil end
	return quests:FindFirstChild("ActiveQuests")
end

local function getSeqFolder(plr)
	local aq = getActiveQuestsFolder(plr)
	if not aq then return nil end
	return aq:FindFirstChild("sequential_current")
end

local function updateAllSpeciesProgress(plr, folder, questData)
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then return end
	local fishFolder = ls:FindFirstChild("Fish")
	if not fishFolder then return end

	local speciesList = RARITY_SPECIES[questData.targetRarity]
	if not speciesList then return end

	local count = 0
	for _, speciesName in ipairs(speciesList) do
		local bv = fishFolder:FindFirstChild(speciesName)
		if bv and bv.Value then
			count = count + 1
		end
	end

	local cp = folder:FindFirstChild("CurrentProgress")
	if cp then
		cp.Value = count
	end
end

-- Forward declaration
local checkSequentialQuestComplete
local giveSequentialQuest

checkSequentialQuestComplete = function(plr, questFolder, questData)
	local progress = questFolder:FindFirstChild("CurrentProgress")
	local required = questFolder:FindFirstChild("RequiredProgress")
	if not progress or not required then return end
	if progress.Value < required.Value then return end

	-- Give reward coins
	local ls = plr:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if coins then
		coins.Value = coins.Value + questData.rewardCoins
		leaderstatsDataManager:UpdateData(plr, "Coins", coins.Value)
	end

	-- Advance index in data
	local newIndex = questData.index + 1
	datamanager:UpdateData(plr, "SequentialQuestIndex", newIndex)

	-- Remove current quest folder
	questFolder:Destroy()

	-- Show completion notice
	local noticeEvent = getNoticeEvent()
	if noticeEvent then
		noticeEvent:FireClient(plr, "Quest complete: " .. questData.name .. "! +" .. questData.rewardCoins .. " coins")
	end

	-- Give next quest if available
	if SEQUENTIAL_QUESTS[newIndex] then
		task.spawn(function()
			task.wait(0.2)
			giveSequentialQuest(plr, newIndex)
		end)
	end
end

giveSequentialQuest = function(plr, index, savedProgress)
	local questData = SEQUENTIAL_QUESTS[index]
	if not questData then return end

	local activeQuests = getActiveQuestsFolder(plr)
	if not activeQuests then return end

	-- Remove old sequential quest if any
	local old = activeQuests:FindFirstChild("sequential_current")
	if old then old:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name = "sequential_current"

	local function sv(name, val)
		local v = Instance.new("StringValue")
		v.Name = name
		v.Value = val
		v.Parent = folder
	end

	local function iv(name, val)
		local v = Instance.new("IntValue")
		v.Name = name
		v.Value = val
		v.Parent = folder
	end

	local function bv(name, val)
		local v = Instance.new("BoolValue")
		v.Name = name
		v.Value = val
		v.Parent = folder
	end

	sv("QuestName",        questData.name)
	sv("QuestDescription", questData.description)
	sv("TargetFish",       "")
	iv("CurrentProgress",  savedProgress or 0)
	iv("RequiredProgress", questData.requiredProgress)
	iv("RewardCoins",      questData.rewardCoins)
	bv("IsReceived",       true)
	sv("QuestType",        questData.questType)

	-- Type-specific values
	if questData.targetRarity then sv("TargetRarity", questData.targetRarity) end
	if questData.targetRod    then sv("TargetRod",    questData.targetRod)    end
	if questData.targetWeight then iv("TargetWeight", questData.targetWeight)  end

	folder.Parent = activeQuests

	-- For rod quests: check immediately if already owned
	if questData.questType == "rod" then
		local ls = plr:FindFirstChild("leaderstats")
		local rods = ls and ls:FindFirstChild("Rods")
		local rodVal = rods and rods:FindFirstChild(questData.targetRod)
		if rodVal and rodVal.Value then
			local cp = folder:FindFirstChild("CurrentProgress")
			if cp then cp.Value = 1 end
			checkSequentialQuestComplete(plr, folder, questData)
			return
		end
	end

	-- For all_species: check immediately
	if questData.questType == "all_species" then
		updateAllSpeciesProgress(plr, folder, questData)
		checkSequentialQuestComplete(plr, folder, questData)
	end
end

-- ── Per-player sequential quest event handlers ─────────────────────────────────

local function handleFishCaughtForSequential(plr, baseName, rarity, weight)
	local seqFolder = getSeqFolder(plr)
	if not seqFolder then return end

	local questTypeVal = seqFolder:FindFirstChild("QuestType")
	if not questTypeVal then return end
	local questType = questTypeVal.Value

	local cp = seqFolder:FindFirstChild("CurrentProgress")
	local rq = seqFolder:FindFirstChild("RequiredProgress")
	if not cp or not rq then return end
	if cp.Value >= rq.Value then return end

	-- Find which quest data this folder represents
	local seqIndex = datamanager:GetData(plr) and datamanager:GetData(plr).SequentialQuestIndex or 0
	local questData = SEQUENTIAL_QUESTS[seqIndex]
	if not questData then return end

	if questType == "rarity" then
		local targetRarity = seqFolder:FindFirstChild("TargetRarity")
		if targetRarity and rarity == targetRarity.Value then
			cp.Value = cp.Value + 1
		end
	elseif questType == "count" then
		cp.Value = cp.Value + 1
	elseif questType == "weight" then
		local targetWeight = seqFolder:FindFirstChild("TargetWeight")
		if targetWeight and weight and weight >= targetWeight.Value then
			cp.Value = cp.Value + 1
		end
	elseif questType == "all_species" then
		updateAllSpeciesProgress(plr, seqFolder, questData)
	end

	checkSequentialQuestComplete(plr, seqFolder, questData)
end

-- ── Legacy quest progress (normal/void quests matching TargetFish) ─────────────

local function updateQuestProgress(plr, fishName)
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then return end
	local quests = ls:FindFirstChild("Quests")
	if not quests then return end
	local activeQuests = quests:FindFirstChild("ActiveQuests")
	if not activeQuests then return end

	for _, quest in pairs(activeQuests:GetChildren()) do
		if quest:IsA("Folder") then
			local targetFish      = quest:FindFirstChild("TargetFish")
			local currentProgress = quest:FindFirstChild("CurrentProgress")
			local requiredProgress = quest:FindFirstChild("RequiredProgress")
			local isReceived      = quest:FindFirstChild("IsReceived")
			local questType       = quest:FindFirstChild("QuestType")

			if questType and questType.Value ~= "daily_random" and questType.Value ~= "sequential" and
				targetFish and currentProgress and requiredProgress and isReceived then

				if isReceived.Value and targetFish.Value == fishName and currentProgress.Value < requiredProgress.Value then
					currentProgress.Value = currentProgress.Value + 1
				end
			end
		end
	end
end

-- ── Standard quest creation ────────────────────────────────────────────────────

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

	local rewardFP = Instance.new("IntValue")
	rewardFP.Name = "RewardFP"
	rewardFP.Value = questData.rewardFP or 0
	rewardFP.Parent = questFolder

	if questData.subType and questData.subType ~= "" then
		local subType = Instance.new("StringValue")
		subType.Name = "SubType"
		subType.Value = questData.subType
		subType.Parent = questFolder
	end

	if questData.targetRarity and questData.targetRarity ~= "" then
		local targetRarity = Instance.new("StringValue")
		targetRarity.Name = "TargetRarity"
		targetRarity.Value = questData.targetRarity
		targetRarity.Parent = questFolder
	end

	return questFolder
end

-- ── PlayerAdded ────────────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(plr)
	task.wait(2)

	repeat task.wait()
		local dataReady = plr:FindFirstChild("DataReady")
	until dataReady and dataReady.Value == true

	local leaderstats = plr:FindFirstChild("leaderstats")
	local Quests = Instance.new("Folder")
	Quests.Name = "Quests"

	local ActiveQuests = Instance.new("Folder")
	ActiveQuests.Name = "ActiveQuests"
	ActiveQuests.Parent = Quests

	local CompletedQuests = Instance.new("Folder")
	CompletedQuests.Name = "CompletedQuests"
	CompletedQuests.Parent = Quests

	Quests.Parent = leaderstats

	-- Load data
	local Data
	repeat
		task.wait()
		Data = datamanager:GetData(plr)
	until Data

	-- Daily quest reset
	local currentDate = getCurrentDateString()
	local lastQuestDate = Data.LastQuestDate

	if lastQuestDate ~= currentDate then
		Data.LastQuestDate = currentDate

		if Data.Quests and Data.Quests.ActiveQuests then
			for questId, questData in pairs(Data.Quests.ActiveQuests) do
				if questData.questType == "daily_playtime" or questData.questType == "daily_random" then
					Data.Quests.ActiveQuests[questId] = nil
				end
			end
		end

		if not Data.Quests then Data.Quests = {} end
		if not Data.Quests.ActiveQuests then Data.Quests.ActiveQuests = {} end

		-- Use date as seed so all players get same quest that day
		local dateSeed = tonumber(currentDate:gsub("-", "")) or os.time()
		local dailyQuest = pickDailyQuest(dateSeed)
		Data.Quests.ActiveQuests[dailyQuest.id] = dailyQuest

		datamanager:SaveData(plr)
	end

	-- Ensure data structures
	if not Data.Quests then Data.Quests = {} end
	if not Data.Quests.ActiveQuests then Data.Quests.ActiveQuests = {} end
	if not Data.Quests.CompletedQuests then Data.Quests.CompletedQuests = {} end

	-- Void quest check
	local hasVoidQuest = Data.Quests.ActiveQuests["void_unknown_challenge"] ~= nil
	local voidQuestCompleted = Data.Quests.CompletedQuests["void_unknown_challenge"] == true

	if not hasVoidQuest and not voidQuestCompleted then
		local voidQuest = createVoidQuestBackup()
		Data.Quests.ActiveQuests[voidQuest.id] = voidQuest
		Data.VoidQuestInitialized = true
		datamanager:SaveData(plr)
	end

	-- Load active quests (skip sequential_current — handled separately below)
	if Data and Data.Quests then
		for questId, questData in pairs(Data.Quests.ActiveQuests or {}) do
			-- Skip sequential_current; it is rebuilt from SequentialQuestIndex
			if questId == "sequential_current" then continue end

			local questFolder = createQuest(questData, questId)
			if questFolder then
				questFolder.Parent = ActiveQuests

				-- (daily_random has no session tracking needed)
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

	-- Daily quest fallback: 오늘 날짜인데 퀘스트가 없을 때만 생성
	-- (이미 오늘 완료해서 ActiveQuests에서 지워진 경우는 생성하지 않음)
	local hasDailyQuest = false
	for _, quest in pairs(ActiveQuests:GetChildren()) do
		if quest:IsA("Folder") then
			local questType = quest:FindFirstChild("QuestType")
			if questType and (questType.Value == "daily_random" or questType.Value == "daily_playtime") then
				hasDailyQuest = true
				break
			end
		end
	end

	-- lastQuestDate == currentDate이고 Data에도 daily_random_quest가 없으면 오늘 이미 완료한 것
	local dailyAlreadyCompleted = (lastQuestDate == currentDate)
		and (not Data.Quests.ActiveQuests or not Data.Quests.ActiveQuests["daily_random_quest"])

	if not hasDailyQuest and not dailyAlreadyCompleted then
		local dateSeed = tonumber(currentDate:gsub("-", "")) or os.time()
		local dailyQuest = pickDailyQuest(dateSeed)
		local questFolder = createQuest(dailyQuest, dailyQuest.id)
		if questFolder then
			questFolder.Parent = ActiveQuests
		end
	end

	-- ── Sequential quest initialization ──────────────────────────────────────

	local seqIndex = Data.SequentialQuestIndex or 0
	if seqIndex == 0 then
		seqIndex = 1
		datamanager:UpdateData(plr, "SequentialQuestIndex", 1)
	end
	if seqIndex <= #SEQUENTIAL_QUESTS then
		-- 저장된 진행도 복원
		local savedSeqProgress = 0
		local savedSeqData = Data.Quests and Data.Quests.ActiveQuests and Data.Quests.ActiveQuests["sequential_current"]
		if savedSeqData and savedSeqData.currentProgress then
			savedSeqProgress = savedSeqData.currentProgress
		end
		task.spawn(function()
			task.wait(0.5)
			giveSequentialQuest(plr, seqIndex, savedSeqProgress)
		end)
	end

	-- ── Rod ownership listener for rod quests ─────────────────────────────────

	task.spawn(function()
		local ls = plr:FindFirstChild("leaderstats")
		if not ls then return end
		local rodsFolder = ls:FindFirstChild("Rods")
		if not rodsFolder then return end

		local function connectRodValue(rodValue)
			rodValue.Changed:Connect(function(newVal)
				if not newVal then return end
				local seqFolder = getSeqFolder(plr)
				if not seqFolder then return end
				local qtVal = seqFolder:FindFirstChild("QuestType")
				if not qtVal or qtVal.Value ~= "rod" then return end
				local targetRodVal = seqFolder:FindFirstChild("TargetRod")
				if not targetRodVal or targetRodVal.Value ~= rodValue.Name then return end

				local data = datamanager:GetData(plr)
				local idx = data and data.SequentialQuestIndex or 0
				local qd = SEQUENTIAL_QUESTS[idx]
				if not qd then return end

				local cp = seqFolder:FindFirstChild("CurrentProgress")
				if cp then cp.Value = 1 end
				checkSequentialQuestComplete(plr, seqFolder, qd)
			end)
		end

		-- Connect existing rod values
		for _, child in ipairs(rodsFolder:GetChildren()) do
			if child:IsA("BoolValue") then
				connectRodValue(child)
			end
		end

		-- Connect future rod values
		rodsFolder.ChildAdded:Connect(function(child)
			if child:IsA("BoolValue") then
				connectRodValue(child)
			end
		end)
	end)

	-- ── Backpack / fish catch detection ───────────────────────────────────────

	local dataReady = false
	task.spawn(function()
		plr:WaitForChild("DataReady", 60)
		task.wait(3)
		dataReady = true
	end)

	local function handleDailyRandomQuest(rarity)
		local aq = getActiveQuestsFolder(plr)
		if not aq then return end
		local folder = aq:FindFirstChild("daily_random_quest")
		if not folder then return end
		local qtVal = folder:FindFirstChild("QuestType")
		if not qtVal or qtVal.Value ~= "daily_random" then return end

		local cp = folder:FindFirstChild("CurrentProgress")
		local rp = folder:FindFirstChild("RequiredProgress")
		if not cp or not rp or cp.Value >= rp.Value then return end

		local subTypeVal = folder:FindFirstChild("SubType")
		local subType = subTypeVal and subTypeVal.Value or "count"

		local progressed = false
		if subType == "count" then
			cp.Value = cp.Value + 1
			progressed = true
		elseif subType == "rarity" then
			local targetRarityVal = folder:FindFirstChild("TargetRarity")
			if targetRarityVal and rarity == targetRarityVal.Value then
				cp.Value = cp.Value + 1
				progressed = true
			end
		end

		if progressed and cp.Value >= rp.Value then
			-- Give FP reward
			local fpVal = folder:FindFirstChild("RewardFP")
			local rewardFP = fpVal and fpVal.Value or 15
			local sp = plr:FindFirstChild("SkillPoints")
			if sp then
				sp.Value = sp.Value + rewardFP
				leaderstatsDataManager:UpdateData(plr, "SkillPoints", sp.Value)
			end

			-- Save completion
			local saveData = datamanager:GetData(plr)
			if saveData and saveData.Quests and saveData.Quests.ActiveQuests then
				saveData.Quests.ActiveQuests["daily_random_quest"] = nil
				datamanager:UpdateData(plr, "Quests", saveData.Quests)
			end

			-- Notify
			local noticeEvent = getNoticeEvent()
			if noticeEvent then
				noticeEvent:FireClient(plr, "Daily quest complete! +" .. rewardFP .. " Fishing Points")
			end

			folder:Destroy()
		end
	end

	local function connectBackpack(backpack)
		backpack.ChildAdded:Connect(function(item)
			if not dataReady then return end
			if item:GetAttribute("FromFishTrap") then return end
			if item:IsA("Tool") and item:FindFirstChild("FishValue") then
				-- Legacy quest progress (void / normal quests with TargetFish)
				local baseName = item.Name:match("^(.-)%s+%[") or item.Name
				baseName = baseName:gsub("^Frozen ", ""):gsub("^Festival ", "")
				updateQuestProgress(plr, baseName)

				-- Parse for typed quests
				local fishBaseName, rarity, weight = parseFishTool(item.Name)

				-- Sequential quest progress
				task.spawn(function()
					handleFishCaughtForSequential(plr, fishBaseName, rarity, weight)
				end)

				-- Daily random quest progress
				task.spawn(function()
					handleDailyRandomQuest(rarity)
				end)
			end
		end)
	end

	plr.CharacterAdded:Connect(function()
		local backpack = plr:FindFirstChild("Backpack")
		if backpack then connectBackpack(backpack) end
	end)

	if plr.Character then
		local backpack = plr:FindFirstChild("Backpack")
		if backpack then connectBackpack(backpack) end
	end
end)

-- ── PlayerRemoving ─────────────────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(plr)
	datamanager:SafeSavePlayer(plr)
end)
