local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local inviteButton = player.PlayerGui:WaitForChild("Main"):WaitForChild("Invite")

local isInvitePromptOpen = false

local inviteRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Invite")
local inviteSentRemote     = inviteRemotes:WaitForChild("InviteSent")
local inviteProgressRemote = inviteRemotes:WaitForChild("InviteQuestProgress")

local INVITE_REQUIRED = 3

local function canSendGameInvite()
	local success, canSend = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	return success and canSend
end

local canInvite = canSendGameInvite()

-- 초대 창이 닫힐 때 카운트
-- recipientIds는 Roblox 버그로 항상 빈 배열을 반환하므로,
-- 창을 열었다가 닫은 것 자체를 1회 초대로 카운트
local invitePromptOpened = false

SocialService.GameInvitePromptClosed:Connect(function()
	if not invitePromptOpened then return end
	invitePromptOpened = false
	inviteSentRemote:FireServer(1)
end)

-- 서버에서 진행도 수신 → 버튼 툴팁/텍스트 업데이트
inviteProgressRemote.OnClientEvent:Connect(function(current, required)
	-- 버튼에 TextLabel이 있으면 진행도 표시
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
	if success then
		invitePromptOpened = true  -- 창이 성공적으로 열렸음을 표시
	else
		warn("Failed to open invite prompt:", result)
	end
	task.wait(1)
	isInvitePromptOpen = false
end)
