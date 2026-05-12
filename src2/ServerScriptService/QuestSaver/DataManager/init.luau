local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ProfileService = require(script.ProfileService)

local DATA_TEMPLATE = { -- Data template
	Quests = {
		ActiveQuests = {};
		CompletedQuests = {};
	};
	LastQuestDate = nil;
	VoidQuestInitialized = false;
}

local function createVoidQuest()
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

local function forceInitializeVoidQuest(profile)
	local data = profile.Data


	-- Force create data structure
	if not data.Quests then
		data.Quests = {}
	end
	if not data.Quests.ActiveQuests then
		data.Quests.ActiveQuests = {}
	end
	if not data.Quests.CompletedQuests then
		data.Quests.CompletedQuests = {}
	end

	-- Check if void quest is already completed
	if data.Quests.CompletedQuests["void_unknown_challenge"] then
		data.VoidQuestInitialized = true
		return
	end

	-- Check if void quest is already in active quests
	if data.Quests.ActiveQuests["void_unknown_challenge"] then
		data.VoidQuestInitialized = true
		return
	end

	-- Force create void quest
	local voidQuest = createVoidQuest()
	data.Quests.ActiveQuests[voidQuest.id] = voidQuest
	data.VoidQuestInitialized = true


	-- Save immediately
	local success, err = pcall(function()
		profile:Save()
	end)

	if success then
	else
		warn("Failed to save void quest data:", err)
	end
end

local ProfileStore = ProfileService.GetProfileStore("QuestData4", DATA_TEMPLATE)

local Profiles = {}

local function HandleLockedUpdate(globalUpdates, update)
	local id = update[1]
	local data = update[2]
	globalUpdates:ClearLockedUpdate(id)
end

-- Called when a player joins
local function OnPlayerAdded(player)

	-- Load player profile data
	local profile = ProfileStore:LoadProfileAsync(
		"QuestPlayer_"..player.UserId,
		"ForceLoad"
	)

	-- If profile data exists
	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile() -- Auto-apply any new template fields

		-- Register release event handler
		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick()
		end)

		-- Cache data if player is still in game
		if player:IsDescendantOf(Players) then
			Profiles[player] = profile


			-- Force initialize void quest
			forceInitializeVoidQuest(profile)


			local globalUpdates = profile.GlobalUpdates

			for index, update in pairs(globalUpdates:GetActiveUpdates())do
				globalUpdates:LockActiveUpdate(update[1])
			end

			for index, update in pairs(globalUpdates:GetLockedUpdates())do
				HandleLockedUpdate(globalUpdates, update)
			end

			globalUpdates:ListenToNewActiveUpdate(function(id, data)
				globalUpdates:LockActiveUpdate(id)
			end)

			globalUpdates:ListenToNewLockedUpdate(function(id, data)
				HandleLockedUpdate(globalUpdates, {id, data})
			end)

		else
			--profile:Release()
		end
	else
		player:Kick("Quest data loading failed, Please try again")
	end
end
Players.PlayerAdded:Connect(OnPlayerAdded)

local function OnPlayerRemoving(player)
	local profile = Profiles[player]
	if profile then
		profile:Save()
		profile:Release()
	end
end
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-----------------------Module-------------------------

local DataManager = {}

-- Return player data
function DataManager:GetData(player)
	local profile = Profiles[player]

	if profile then
		-- Re-check void quest before returning data
		if not profile.Data.VoidQuestInitialized then
			forceInitializeVoidQuest(profile)
		end

		return profile.Data
	else
		return nil
	end
end

function DataManager:GetProfileStore()
	return ProfileStore
end

-- Update data
function DataManager:UpdateData(player, key, data)
	local profile = Profiles[player]

	-- Force load profile if not available
	if not profile then
		profile = ProfileStore:LoadProfileAsync("QuestPlayer_"..player.UserId, "ForceLoad")
		if profile then
			profile:Reconcile()
			Profiles[player] = profile
			forceInitializeVoidQuest(profile)  -- Initialize void quest
		else
			warn("UpdateData failed: quest profile load failed", player, key)
			return
		end
	end

	profile.Data[key] = data
end

local function getCurrentDateString()
	local currentTime = os.time()
	local date = os.date("*t", currentTime)
	return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

function DataManager:SafeSavePlayer(player)
	local profile = Profiles[player]
	if not profile then
		warn("Save failed - no quest profile:", player)
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local questsFolder = leaderstats:FindFirstChild("Quests")

	-- Save quest data
	local questsData = {
		ActiveQuests = {},
		CompletedQuests = {}
	}

	if questsFolder then
		local activeQuests = questsFolder:FindFirstChild("ActiveQuests")
		local completedQuests = questsFolder:FindFirstChild("CompletedQuests")

		-- Save active quests
		if activeQuests then
			for _, quest in ipairs(activeQuests:GetChildren()) do
				if quest:IsA("Folder") then
					local questName = quest:FindFirstChild("QuestName")
					local questDescription = quest:FindFirstChild("QuestDescription")
					local targetFish = quest:FindFirstChild("TargetFish")
					local currentProgress = quest:FindFirstChild("CurrentProgress")
					local requiredProgress = quest:FindFirstChild("RequiredProgress")
					local rewardCoins = quest:FindFirstChild("RewardCoins")
					local isReceived = quest:FindFirstChild("IsReceived")
					local questType = quest:FindFirstChild("QuestType")

					if questName and questDescription and currentProgress and requiredProgress and rewardCoins and isReceived then
						questsData.ActiveQuests[quest.Name] = {
							id = quest.Name,  -- Add ID
							name = questName.Value,
							description = questDescription.Value,
							targetFish = targetFish and targetFish.Value or "",
							currentProgress = currentProgress.Value,
							requiredProgress = requiredProgress.Value,
							rewardCoins = rewardCoins.Value,
							isReceived = isReceived.Value,
							questType = questType and questType.Value or "normal"
						}
					end
				end
			end
		end

		-- Save completed quests
		if completedQuests then
			for _, quest in ipairs(completedQuests:GetChildren()) do
				if quest:IsA("BoolValue") then
					questsData.CompletedQuests[quest.Name] = quest.Value
				end
			end
		end
	end

	-- Save LastQuestDate
	profile.Data.LastQuestDate = profile.Data.LastQuestDate or getCurrentDateString()
	profile.Data.Quests = questsData


	local success, err = pcall(function()
		profile:Save()
	end)
	if not success then
		warn("Quest save failed:", player.Name, err)
	else
	end
end

-- Save to DataStore
function DataManager:SaveData(player)
	Profiles[player]:Save()
end

-- Clear specific player data
local RunService = game:GetService("RunService")
function DataManager:ClearData(player)
	if RunService:IsStudio() and RunService:IsServer() then
		local profile = Profiles[player] or ProfileStore:LoadProfileAsync(
			"QuestPlayer_"..player.UserId,
			"ForceLoad"
		)
		profile["Data"] = DATA_TEMPLATE
		player:Kick("Quest Data Cleared")
	end
end

return DataManager
