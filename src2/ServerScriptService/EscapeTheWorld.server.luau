local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local badgeEvent = ReplicatedStorage:WaitForChild("EscapeTheWorld")

local FALL_RECOVERY_BADGE_ID = 3105116633857431


local lastRequest = {}

badgeEvent.OnServerEvent:Connect(function(player)
	local now = tick()
	if lastRequest[player.UserId] and now - lastRequest[player.UserId] < 5 then
		warn("Too frequent badge request from: " .. player.Name)
		return
	end
	lastRequest[player.UserId] = now
	-- Continue normal processing
end)


