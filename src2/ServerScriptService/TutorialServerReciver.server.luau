-- Server script (place in ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")

-- Create tutorial complete remote event if not found
local tutorialCompleteRemote = ReplicatedStorage:FindFirstChild("TutorialCompleteRemote")
if not tutorialCompleteRemote then
	tutorialCompleteRemote = Instance.new("RemoteEvent")
	tutorialCompleteRemote.Name = "TutorialCompleteRemote"
	tutorialCompleteRemote.Parent = ReplicatedStorage
end

-- Funnel step 1: player joined (tutorial started)
Players.PlayerAdded:Connect(function(player)
	pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, "Tutorial", 1, "Joined")
	end)
end)

-- Handle tutorial completion
tutorialCompleteRemote.OnServerEvent:Connect(function(player)
	-- Set IsTutorialed to true
	local isTutorialed = player:FindFirstChild("IsTutorialed")
	if isTutorialed then
		isTutorialed.Value = true
	end

	-- Funnel step 2: tutorial completed
	pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, "Tutorial", 2, "Completed")
	end)
end)
