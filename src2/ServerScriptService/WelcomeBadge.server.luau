local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

local BADGE_ID = 1623226186341777

-- Badge award function
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

-- Award badge when player joins
Players.PlayerAdded:Connect(function(player)
	awardBadge(player)
end)
