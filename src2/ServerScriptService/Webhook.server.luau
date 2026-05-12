local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WELCOME_WEBHOOK_URL = "https://discord.com/api/webhooks/1388518770913579070/MZg73UKZvkinV_rqZnLJ8bd5T-DyWApeGhpL7x9gyW0Ax2scmSvy9CYOEWK9mWhmnMNv"
local LEFT_WEBHOOK_URL = "https://discord.com/api/webhooks/1388522238403149854/8mYc0S2Ug3EdItf1e8U_WOew4pnste1byBvK6nMinWXVm5D2XfUgBftE64TUBEpwgpIR"

local playerJoinTimes = {}

local function formatPlayTime(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)

	if hours > 0 then
		return string.format("%dh %dm %ds", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	else
		return string.format("%ds", secs)
	end
end

local function sendWebhook(url, title, message, color)
	if RunService:IsStudio() then return end

	local data = {
		["username"] = "Game Logger",
		["embeds"] = {{
			["title"] = title,
			["description"] = message,
			["color"] = color,
			["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
		}}
	}

	local jsonData = HttpService:JSONEncode(data)

	pcall(function()
		HttpService:PostAsync(url, jsonData, Enum.HttpContentType.ApplicationJson)
	end)
end

Players.PlayerAdded:Connect(function(player)
	playerJoinTimes[player.UserId] = tick()

	local message = string.format("**%s** joined the game!", player.Name)
	sendWebhook(WELCOME_WEBHOOK_URL, "Player Joined", message, 65280)
end)

Players.PlayerRemoving:Connect(function(player)
	local joinTime = playerJoinTimes[player.UserId]
	local message

	if joinTime then
		local playTime = tick() - joinTime
		local formattedTime = formatPlayTime(playTime)
		message = string.format("**%s** left the game.\nPlay time: %s", player.Name, formattedTime)
		playerJoinTimes[player.UserId] = nil
	else
		message = string.format("**%s** left the game.", player.Name)
	end

	sendWebhook(LEFT_WEBHOOK_URL, "Player Left", message, 16711680)
end)

-- Record join time for players already in server on script start
for _, player in pairs(Players:GetPlayers()) do
	if not playerJoinTimes[player.UserId] then
		playerJoinTimes[player.UserId] = tick()
	end
end
