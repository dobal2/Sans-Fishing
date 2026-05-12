local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

local BADGE_ID = 1623226186341777

-- 뱃지 지급 함수
local function awardBadge(player)
	local success, hasBadge = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, BADGE_ID)
	end)

	if success and not hasBadge then
		pcall(function()
			BadgeService:AwardBadge(player.UserId, BADGE_ID)
		end)
	end
end

-- 플레이어 입장 시 지급
Players.PlayerAdded:Connect(function(player)
	awardBadge(player)
end)
