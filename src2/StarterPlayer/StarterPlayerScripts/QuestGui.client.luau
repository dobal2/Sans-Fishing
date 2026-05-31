-- NOTE: requires child: Template (ModuleScript or Frame)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local questGui = player.PlayerGui:WaitForChild("QuestGui")
local frame = questGui:WaitForChild("Frame")
local ScrollingFrame = frame:WaitForChild("ScrollingFrame")
local button = frame:WaitForChild("Button")
-- Template은 Studio에서 QuestGui 루트 바로 아래로 옮겨야 함
local questFrame = questGui:FindFirstChild("Template") or questGui:FindFirstChildOfClass("LocalScript") and questGui:FindFirstChildOfClass("LocalScript"):FindFirstChild("Template")

local questRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Quest")
local questGuiEvent = questRemotes:WaitForChild("QuestGuiEvent")
local questReceiveEvent = questRemotes:WaitForChild("QuestReceiveEvent")
local questCompleteEvent = questRemotes:WaitForChild("QuestCompleteEvent")

local isFrameExpanded = false

local function formatTime(seconds)
	if seconds >= 60 then
		local minutes = math.floor(seconds / 60)
		local remainingSeconds = seconds % 60
		if remainingSeconds > 0 then
			return string.format("%dm %ds", minutes, remainingSeconds)
		else
			return string.format("%dm", minutes)
		end
	else
		return string.format("%ds", seconds)
	end
end

local function animateFramePosition()
	local targetPosition

	if not isFrameExpanded then
		targetPosition = UDim2.new(0.98, 0, 0.306, 0)
		button.Text = "<"
		isFrameExpanded = true
	else
		targetPosition = UDim2.new(0.791, 0, 0.306, 0)
		button.Text = ">"
		isFrameExpanded = false
	end

	local frameTween = TweenService:Create(
		frame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{Position = targetPosition}
	)

	frameTween:Play()
end

local function formatNumber(n)
	local s = tostring(math.floor(n))
	local result = ""
	local len = #s
	for i = 1, len do
		if i > 1 and (len - i + 1) % 3 == 0 then
			result = result .. ","
		end
		result = result .. s:sub(i, i)
	end
	return result
end

local function createQuestFrame(questData)
	local newQuestFrame = questFrame:Clone()
	newQuestFrame.Name = questData.name
	newQuestFrame.Visible = true

	local titleLabel = newQuestFrame:FindFirstChild("Title")
	local descLabel = newQuestFrame:FindFirstChild("Desc")

	if titleLabel then
		titleLabel.Text = questData.name
	end

	if descLabel then
		descLabel.Text = questData.description
	end

	local rewardText = newQuestFrame:FindFirstChild("RewardText")
	if rewardText then
		if questData.rewardBubble and questData.rewardBubble ~= "" then
			rewardText.Text = "Reward: " .. questData.rewardBubble
		elseif questData.questType == "invite" then
			rewardText.Text = "Reward: Invite Rod"
		elseif questData.rewardFP and questData.rewardFP > 0 then
			rewardText.Text = "Reward: " .. formatNumber(questData.rewardFP) .. " FishingPoints"
		elseif questData.rewardCoins and questData.rewardCoins > 0 then
			rewardText.Text = "Reward: " .. formatNumber(questData.rewardCoins) .. " Coins"
		else
			rewardText.Text = "Reward: ?"
		end
	end

	local barFrame = newQuestFrame:FindFirstChild("ProgressBar")
	if barFrame then
		local main = barFrame:FindFirstChild("Main")
		local fillFrame = main and main:FindFirstChild("Filler")
		if fillFrame then
			local progressRatio = questData.currentProgress / questData.requiredProgress
			progressRatio = math.min(progressRatio, 1)

			fillFrame.Size = UDim2.new(progressRatio, 0, 1, 0)

			local progressText = barFrame:FindFirstChild("ProgressText")
			if not progressText then
				progressText = Instance.new("TextLabel")
				progressText.Name = "ProgressText"
				progressText.Size = UDim2.new(1, 0, 1, 0)
				progressText.BackgroundTransparency = 1
				progressText.TextScaled = true
				progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
				progressText.Parent = barFrame
			end

			if questData.questType == "daily_playtime" then
				progressText.Text = questData.currentProgress .. "m / " .. questData.requiredProgress .. "m"
			else
				progressText.Text = questData.currentProgress .. "/" .. questData.requiredProgress
			end

			if questData.currentProgress >= questData.requiredProgress then
				fillFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
			end
		end
	end

	return newQuestFrame
end

local function updateQuestList()
	for _, child in pairs(ScrollingFrame:GetChildren()) do
		if child:IsA("Frame") and child ~= questFrame then
			child:Destroy()
		end
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		print("leaderstats not found")
		return
	end

	local quests = leaderstats:FindFirstChild("Quests")
	if not quests then
		print("Quests not found")
		return
	end

	local activeQuests = quests:FindFirstChild("ActiveQuests")
	if not activeQuests then
		print("ActiveQuests not found")
		return
	end

	-- 순서: 1=daily_playtime, 2=normal(sequential), 3=invite, 4=daily_give
	local ORDER = {
		daily_playtime = 1,
		normal         = 2,
		sequential     = 2,
		invite         = 3,
		daily_give     = 4,
		daily_random   = 2,
	}

	local questList = {}
	for _, quest in pairs(activeQuests:GetChildren()) do
		if quest:IsA("Folder") then
			local questData = {
				id = quest.Name,
				name = quest:FindFirstChild("QuestName") and quest.QuestName.Value or "Unknown Quest",
				description = quest:FindFirstChild("QuestDescription") and quest.QuestDescription.Value or "No description",
				currentProgress = quest:FindFirstChild("CurrentProgress") and quest.CurrentProgress.Value or 0,
				requiredProgress = quest:FindFirstChild("RequiredProgress") and quest.RequiredProgress.Value or 1,
				isReceived = quest:FindFirstChild("IsReceived") and quest.IsReceived.Value or false,
				rewardCoins = quest:FindFirstChild("RewardCoins") and quest.RewardCoins.Value or 0,
				rewardFP = quest:FindFirstChild("RewardFP") and quest.RewardFP.Value or 0,
				rewardBubble = quest:FindFirstChild("RewardBubble") and quest.RewardBubble.Value or "",
				questType = quest:FindFirstChild("QuestType") and quest.QuestType.Value or "normal"
			}
			if questData.isReceived then
				table.insert(questList, questData)
			end
		end
	end

	-- 순서 정렬
	table.sort(questList, function(a, b)
		local oa = ORDER[a.questType] or 99
		local ob = ORDER[b.questType] or 99
		return oa < ob
	end)

	local questCount = 0
	for i, questData in ipairs(questList) do
		local newQuestFrame = createQuestFrame(questData)
		newQuestFrame.LayoutOrder = i
		newQuestFrame.Parent = ScrollingFrame
		questCount = questCount + 1
	end

	if questCount == 0 then
		frame.Visible = false
	else
		frame.Visible = true
	end
end

local function setupQuestChangeDetection()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		print("leaderstats not found - change detection setup failed")
		return
	end

	local quests = leaderstats:FindFirstChild("Quests")
	if not quests then
		print("Quests not found - change detection setup failed")
		return
	end

	local activeQuests = quests:FindFirstChild("ActiveQuests")
	if not activeQuests then
		print("ActiveQuests not found - change detection setup failed")
		return
	end

	activeQuests.ChildAdded:Connect(function()
		task.wait(0.1)
		updateQuestList()
	end)

	activeQuests.ChildRemoved:Connect(function()
		task.wait(0.1)
		updateQuestList()
	end)

	for _, quest in pairs(activeQuests:GetChildren()) do
		if quest:IsA("Folder") then
			local currentProgress = quest:FindFirstChild("CurrentProgress")
			local isReceived = quest:FindFirstChild("IsReceived")

			if currentProgress then
				currentProgress.Changed:Connect(function()
					updateQuestList()
				end)
			end

			if isReceived then
				isReceived.Changed:Connect(function()
					updateQuestList()
				end)
			end
		end
	end

	activeQuests.ChildAdded:Connect(function(quest)
		if quest:IsA("Folder") then
			task.wait(0.1)

			local currentProgress = quest:FindFirstChild("CurrentProgress")
			local isReceived = quest:FindFirstChild("IsReceived")

			if currentProgress then
				currentProgress.Changed:Connect(function()
					updateQuestList()
				end)
			end

			if isReceived then
				isReceived.Changed:Connect(function()
					updateQuestList()
				end)
			end
		end
	end)
end

local function waitForQuestData()
	local maxAttempts = 9999999
	local attempts = 0

	while attempts < maxAttempts do
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local quests = leaderstats:FindFirstChild("Quests")
			if quests then
				local activeQuests = quests:FindFirstChild("ActiveQuests")
				if activeQuests then
					return true
				end
			end
		end

		attempts = attempts + 1
		task.wait(0.5)
	end

	return false
end

local function initialize()
	if waitForQuestData() then
		setupQuestChangeDetection()
		updateQuestList()
	else
		player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				task.wait(1)
				initialize()
			end
		end)
	end
end

questGuiEvent.OnClientEvent:Connect(function()
	frame.Visible = true
	updateQuestList()
end)

button.MouseButton1Click:Connect(function()
	animateFramePosition()
	updateQuestList()
end)

task.spawn(function()
	task.wait(1)
	initialize()
end)
