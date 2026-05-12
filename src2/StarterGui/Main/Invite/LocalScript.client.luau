local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local isInvitePromptOpen = false

local function canSendGameInvite(player)
	local success, canSend = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if success then
		return canSend
	end
	return false
end

local canInvite = canSendGameInvite(player)

script.Parent.MouseButton1Click:Connect(function()
	if isInvitePromptOpen then
		print("Invite dialog already open")
		return
	end

	if canInvite then
		isInvitePromptOpen = true
		print("Opening invite dialog")

		local success, result = pcall(function()
			SocialService:PromptGameInvite(player)
		end)

		if success then
			print("Invite dialog opened")
			task.wait(1)
			isInvitePromptOpen = false
		else
			warn("Failed to open invite dialog:", result)
			isInvitePromptOpen = false
		end
	else
		print("No invite permission")
	end
end)
