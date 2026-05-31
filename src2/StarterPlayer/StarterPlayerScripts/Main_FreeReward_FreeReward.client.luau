local player = game.Players.LocalPlayer
local MarketplaceService = game:GetService("MarketplaceService")
local GroupService = game:GetService("GroupService")

local GROUP_ID = 9744474

local mainGui = player.PlayerGui:WaitForChild("Main")
local freeRewardFrame = mainGui:WaitForChild("Free Reward")

-- 그룹 가입 여부 확인 → 가입했으면 Free Reward 버튼 숨김
local ok, isInGroup = pcall(function()
	return player:IsInGroup(GROUP_ID)
end)
if ok and isInGroup then
	freeRewardFrame.Visible = false
	return
end
