local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local frame = script.Parent:WaitForChild("Frame")
local ScrollingFrame = frame:WaitForChild("ScrollingFrame")
local button = frame:WaitForChild("Button")
local questFrame = script:WaitForChild("Template")

local questEvents = ReplicatedStorage:WaitForChild("Quest Events")
local questGuiEvent = questEvents:WaitForChild("QuestGuiEvent")
local questReceiveEvent = questEvents:WaitForChild("QuestReceiveEvent")
local questCompleteEvent = questEvents:WaitForChild("QuestCompleteEvent")

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

local function createQuestFrame(questData)
	local newQuestFrame = questFrame:Clone()
	newQuestFrame.Name = questData.name
	newQuestFrame.Visible = true

	local titleLabel = newQuestFrame:FindFirstChild("Title")
	local descLabel = newQuestFrame:FindFirstChild("Desc")
	local rewardLabel = newQuestFrame:FindFirstChild("Rewards")

	if titleLabel then
		titleLabel.Text = questData.name
	end

	if descLabel then
		descLabel.Text = questData.description
	end

	if rewardLabel then
		rewardLabel.Text = "Rewards: ".. questData.rewardCoins .. " Coins"
	end

	local barFrame = newQuestFrame:FindFirstChild("Bar")
	if barFrame then
		local fillFrame = barFrame:FindFirstChild("Fill")
		if fillFrame then
			local progressRatio = questData.currentProgress / questData.requiredProgress
			progressRatio = math.min(progressRatio, 1)

			fillFrame.Size = UDim2.new(progressRatio, 0, 1, 0)

			local progressText = barFrame:FindFirstChild("ProgressText")
			if not progressText then
				progressText = Instance.new("TextLabel")
				progressText.Name = "ProgressText"
				progressText.Size = UDim2.new(1, 0, 1, 0)
				progressText.Position = UDim2.new(0, 0, 0, 0)
				progressText.BackgroundTransparency = 1
				progressText.TextScaled = true
				progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
				progressText.FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
				progressText.Parent = barFrame
			end

			if questData.questType == "daily_playtime" then
				local currentTime = formatTime(questData.currentProgress)
				local requiredTime = formatTime(questData.requiredProgress)
				progressText.Text = currentTime .. "/" .. requiredTime
			else
				progressText.Text = questData.currentProgress .. "/" .. questData.requiredProgress
			end

			if questData.currentProgress >= questData.requiredProgress then
				fillFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
			else
				fillFrame.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
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

	local questCount = 0

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
				questType = quest:FindFirstChild("QuestType") and quest.QuestType.Value or "normal"
			}

			if questData.isReceived then
				local newQuestFrame = createQuestFrame(questData)
				newQuestFrame.Parent = ScrollingFrame
				questCount = questCount + 1
			end
		end
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
		wait(0.1)
		updateQuestList()
	end)

	activeQuests.ChildRemoved:Connect(function()
		wait(0.1)
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
			wait(0.1)

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
		wait(0.5)
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
				wait(1)
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

spawn(function()
	wait(1)
	initialize()
end)
