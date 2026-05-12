local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- 초대창 상태 추적
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
	-- 이미 초대창이 열려있으면 무시
	if isInvitePromptOpen then
		print("초대창이 이미 열려있습니다")
		return
	end

	if canInvite then
		isInvitePromptOpen = true
		print("초대창 열기 시도")

		local success, result = pcall(function()
			SocialService:PromptGameInvite(player)
		end)

		if success then
			print("✅ 초대창 열림")
			-- 초대창이 닫힐 때까지 기다리기 (약간의 딜레이 후 리셋)
			task.wait(1) -- 1초 후 다시 사용 가능
			isInvitePromptOpen = false
		else
			warn("❌ 초대창 열기 실패:", result)
			isInvitePromptOpen = false
		end
	else
		print("❌ 초대 권한이 없습니다")
	end
end)
