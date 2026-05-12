local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local isInvitePromptOpen = false

local function canSendGameInvite()
	local success, canSend = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	return success and canSend
end

local canInvite = canSendGameInvite()

script.Parent.MouseButton1Click:Connect(function()
	if isInvitePromptOpen or not canInvite then return end
	isInvitePromptOpen = true
	local success, result = pcall(function()
		SocialService:PromptGameInvite(player)
	end)
	if not success then
		warn("Failed to open invite prompt:", result)
	end
	task.wait(1)
	isInvitePromptOpen = false
end)
