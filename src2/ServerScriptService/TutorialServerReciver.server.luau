-- Server script (place in ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")
local ServerScriptService = game:GetService("ServerScriptService")

local datamanager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))
local soldNotification = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SoldNotification")

-- Create tutorial complete remote event if not found
local tutorialCompleteRemote = ReplicatedStorage:FindFirstChild("TutorialCompleteRemote")
if not tutorialCompleteRemote then
	tutorialCompleteRemote = Instance.new("RemoteEvent")
	tutorialCompleteRemote.Name = "TutorialCompleteRemote"
	tutorialCompleteRemote.Parent = ReplicatedStorage
end

local tutorialGoldRewardRemote = ReplicatedStorage:FindFirstChild("TutorialGoldRewardRemote")
if not tutorialGoldRewardRemote then
	tutorialGoldRewardRemote = Instance.new("RemoteEvent")
	tutorialGoldRewardRemote.Name = "TutorialGoldRewardRemote"
	tutorialGoldRewardRemote.Parent = ReplicatedStorage
end

local goldRewardGiven = {}

Players.PlayerRemoving:Connect(function(player)
	goldRewardGiven[player.UserId] = nil
end)

-- Give 3,000 coins when Silver Rod is purchased.
-- Server validates actual rod ownership so client can't exploit this by firing early.
tutorialGoldRewardRemote.OnServerEvent:Connect(function(player)
	if goldRewardGiven[player.UserId] then return end

	-- Verify player actually owns the Silver Rod server-side
	local ls = player:FindFirstChild("leaderstats")
	local rods = ls and ls:FindFirstChild("Rods")
	local silverRod = rods and rods:FindFirstChild("Silver Rod")
	if not silverRod or not silverRod.Value then return end

	goldRewardGiven[player.UserId] = true
	local coinsVal = ls:FindFirstChild("Coins")
	if coinsVal then
		coinsVal.Value = coinsVal.Value + 3000
		datamanager:UpdateData(player, "Coins", coinsVal.Value)
		soldNotification:FireClient(player, 3000, false)
	end
end)

-- Funnel step 1: player joined (tutorial started)
Players.PlayerAdded:Connect(function(player)
	pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, "Tutorial", nil, 1, "Joined")
	end)
end)

-- Handle tutorial completion
tutorialCompleteRemote.OnServerEvent:Connect(function(player)
	local isTutorialed = player:FindFirstChild("IsTutorialed")
	if isTutorialed and isTutorialed.Value then return end

	if isTutorialed then
		isTutorialed.Value = true
	end
	datamanager:UpdateData(player, "IsTutorialed", true)

	pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, "Tutorial", nil, 2, "Completed")
	end)
end)
