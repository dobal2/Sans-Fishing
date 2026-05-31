local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService     = game:GetService("SocialService")

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("RequestFeedbackPrompt")

remote.OnServerEvent:Connect(function(player)
	local ok, err = pcall(function()
		SocialService:PromptPlayerFeedbackAsync(player)
	end)
	if not ok then
		warn("FeedbackHandler: PromptPlayerFeedbackAsync failed:", err)
	end
end)
