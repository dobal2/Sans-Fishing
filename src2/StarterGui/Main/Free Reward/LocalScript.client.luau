local player = game.Players.LocalPlayer
local MarketplaceService = game:GetService("MarketplaceService")
local GroupService = game:GetService("GroupService")

-- 🆕 그룹 ID 설정
local GROUP_ID = 9744474

-- 🆕 그룹 멤버 체크 및 UI 숨기기
local function checkGroupMembership()
	local success, isInGroup = pcall(function()
		return player:IsInGroup(GROUP_ID)
	end)

	if success and isInGroup then
		--print("🚫 그룹 멤버 감지 - UI 숨김")
		script.Parent.Visible = false
		return true
	end
	return false
end

if checkGroupMembership() then
	return -- 그룹 멤버면 스크립트 종료
end
