local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local inviteButton = player.PlayerGui:WaitForChild("Main"):WaitForChild("Invite")

local isInvitePromptOpen = false

local inviteProgressRemote = ReplicatedStorage:WaitForChild("Remotes")
	:WaitForChild("Invite"):WaitForChild("InviteQuestProgress")

local function canSendGameInvite()
	local success, canSend = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	return success and canSend
end

local canInvite = canSendGameInvite()

-- 서버에서 진행도 수신 → 버튼 텍스트 업데이트
inviteProgressRemote.OnClientEvent:Connect(function(current, required)
	local label = inviteButton:FindFirstChildOfClass("TextLabel")
		or inviteButton:FindFirstChildOfClass("TextButton")
	if label then
		if current >= required then
			label.Text = "Invite ✓"
		else
			label.Text = "Invite (" .. current .. "/" .. required .. ")"
		end
	end
end)

inviteButton.MouseButton1Click:Connect(function()
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
