-- Server script (place in ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Create tutorial complete remote event if not found
local tutorialCompleteRemote = ReplicatedStorage:FindFirstChild("TutorialCompleteRemote")
if not tutorialCompleteRemote then
	tutorialCompleteRemote = Instance.new("RemoteEvent")
	tutorialCompleteRemote.Name = "TutorialCompleteRemote"
	tutorialCompleteRemote.Parent = ReplicatedStorage
end

-- Handle tutorial completion
tutorialCompleteRemote.OnServerEvent:Connect(function(player)
	-- Set IsTutorialed to true
	local isTutorialed = player:FindFirstChild("IsTutorialed")
	if isTutorialed then
		isTutorialed.Value = true
	end

	-- Additional processing if needed (e.g., save tutorial completion to DataStore)
end)
