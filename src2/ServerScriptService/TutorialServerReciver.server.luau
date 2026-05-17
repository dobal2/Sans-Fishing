-- Server script (place in ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")
local ServerScriptService = game:GetService("ServerScriptService")

local datamanager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))

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
		AnalyticsService:LogFunnelStepEvent(player, "Tutorial", nil, 1, "Joined")
	end)
end)

-- Handle tutorial completion
tutorialCompleteRemote.OnServerEvent:Connect(function(player)
	local isTutorialed = player:FindFirstChild("IsTutorialed")
	if isTutorialed then
		isTutorialed.Value = true
	end

	-- ProfileService에도 즉시 저장
	datamanager:UpdateData(player, "IsTutorialed", true)

	pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, "Tutorial", nil, 2, "Completed")
	end)
end)
