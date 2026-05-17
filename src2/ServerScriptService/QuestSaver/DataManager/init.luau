local Players = game:GetService("Players")
local ProfileService = require(script.Parent.Parent.ProfileService)
local RunService = game:GetService("RunService")

local DATA_TEMPLATE = {
	Quests = {
		ActiveQuests = {};
		CompletedQuests = {};
	};
	LastQuestDate = nil;
	VoidQuestInitialized = false;
	SequentialQuestIndex = 0;
}

local function getCurrentDateString()
	local date = os.date("*t", os.time())
	return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

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
	if not data.Quests then data.Quests = {} end
	if not data.Quests.ActiveQuests then data.Quests.ActiveQuests = {} end
	if not data.Quests.CompletedQuests then data.Quests.CompletedQuests = {} end

	if data.Quests.CompletedQuests["void_unknown_challenge"] then
		data.VoidQuestInitialized = true
		return
	end
	if data.Quests.ActiveQuests["void_unknown_challenge"] then
		data.VoidQuestInitialized = true
		return
	end

	data.Quests.ActiveQuests["void_unknown_challenge"] = createVoidQuest()
	data.VoidQuestInitialized = true
end

local ProfileStore = ProfileService.New("QuestData4", DATA_TEMPLATE)
local Profiles = {}

local function OnPlayerAdded(player)
	local profile
	for attempt = 1, 3 do
		profile = ProfileStore:StartSessionAsync("QuestPlayer_" .. player.UserId, {Steal = true})
		if profile then break end
		if not player:IsDescendantOf(Players) then return end
		task.wait(3)
	end

	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			player:Kick()
		end)

		if player:IsDescendantOf(Players) then
			Profiles[player] = profile
			forceInitializeVoidQuest(profile)
		else
			profile:EndSession()
		end
	else
		player:Kick("Quest data loading failed, Please try again")
	end
end
Players.PlayerAdded:Connect(OnPlayerAdded)

local function OnPlayerRemoving(player)
	local profile = Profiles[player]
	if profile and profile:IsActive() then
		profile:EndSession()
	end
end
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-----------------------Module-------------------------

local DataManager = {}

function DataManager:GetData(player)
	local profile = Profiles[player]
	if profile then
		if not profile.Data.VoidQuestInitialized then
			forceInitializeVoidQuest(profile)
		end
		return profile.Data
	end
	return nil
end

function DataManager:GetProfileStore()
	return ProfileStore
end

function DataManager:UpdateData(player, key, data)
	local profile = Profiles[player]
	if not profile then
		profile = ProfileStore:StartSessionAsync("QuestPlayer_" .. player.UserId, {Steal = true})
		if profile then
			profile:Reconcile()
			Profiles[player] = profile
			forceInitializeVoidQuest(profile)
		else
			warn("UpdateData failed: quest profile load failed", player, key)
			return
		end
	end
	profile.Data[key] = data
end

function DataManager:SafeSavePlayer(player)
	local profile = Profiles[player]
	if not profile then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		if profile:IsActive() then profile:EndSession() end
		return
	end

	local questsFolder = leaderstats:FindFirstChild("Quests")
	local questsData = {ActiveQuests = {}, CompletedQuests = {}}

	if questsFolder then
		local activeQuests = questsFolder:FindFirstChild("ActiveQuests")
		local completedQuests = questsFolder:FindFirstChild("CompletedQuests")

		if activeQuests then
			for _, quest in ipairs(activeQuests:GetChildren()) do
				if quest:IsA("Folder") then
					local questName       = quest:FindFirstChild("QuestName")
					local questDescription = quest:FindFirstChild("QuestDescription")
					local targetFish      = quest:FindFirstChild("TargetFish")
					local currentProgress = quest:FindFirstChild("CurrentProgress")
					local requiredProgress = quest:FindFirstChild("RequiredProgress")
					local rewardCoins     = quest:FindFirstChild("RewardCoins")
					local isReceived      = quest:FindFirstChild("IsReceived")
					local questType       = quest:FindFirstChild("QuestType")

					if questName and currentProgress and requiredProgress and rewardCoins and isReceived then
						local rewardFP    = quest:FindFirstChild("RewardFP")
						local subType     = quest:FindFirstChild("SubType")
						local targetRarity = quest:FindFirstChild("TargetRarity")
						questsData.ActiveQuests[quest.Name] = {
							id = quest.Name,
							name = questName.Value,
							description = questDescription and questDescription.Value or "",
							targetFish = targetFish and targetFish.Value or "",
							currentProgress = currentProgress.Value,
							requiredProgress = requiredProgress.Value,
							rewardCoins = rewardCoins.Value,
							rewardFP = rewardFP and rewardFP.Value or 0,
							isReceived = isReceived.Value,
							questType = questType and questType.Value or "normal",
							subType = subType and subType.Value or "",
							targetRarity = targetRarity and targetRarity.Value or "",
						}
					end
				end
			end
		end

		if completedQuests then
			for _, quest in ipairs(completedQuests:GetChildren()) do
				if quest:IsA("BoolValue") then
					questsData.CompletedQuests[quest.Name] = quest.Value
				end
			end
		end
	end

	profile.Data.LastQuestDate = profile.Data.LastQuestDate or getCurrentDateString()
	profile.Data.Quests = questsData

	if profile:IsActive() then
		profile:EndSession()
	end
end

function DataManager:SaveData(player)
	local profile = Profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

function DataManager:ClearData(player)
	if RunService:IsStudio() and RunService:IsServer() then
		local profile = Profiles[player]
		if profile then
			profile.Data = DATA_TEMPLATE
			player:Kick("Quest Data Cleared")
		end
	end
end

return DataManager
