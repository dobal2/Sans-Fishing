local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local DataManager = require(ServerScriptService.leaderstats.DataManager)
local surfaceGui = workspace:WaitForChild("PlayerTimeLeaderBoard"):WaitForChild("LeadBoardPart"):WaitForChild("SurfaceGui")

local excludedUsernames = {}
local nameCache = {}

local function getNameFromUserId(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local success, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = success and result or "Unknown"
	nameCache[userId] = name
	return name
end

local function clearLeaderboard()
	for _, child in pairs(surfaceGui:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

local function shouldExcludeUser(userId)
	local name = string.lower(getNameFromUserId(userId))
	return excludedUsernames[name] == true
end

local function formatPlaytime(seconds)
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	if days > 0 then
		return string.format("%dd %dh", days, hours)     -- 1+ days: "2d 5h"
	elseif hours > 0 then
		return string.format("%dh %dm", hours, minutes)  -- 1+ hours: "5h 30m"
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)   -- 1+ minutes: "25m 45s"
	else
		return string.format("%ds", secs)                -- Under 1 minute: "45s"
	end
end

-- Build mixed playtime data function
local function getMixedPlaytimeData()
	local playtimeData = {}

	-- 1. Fetch stored playtime data from DataStore
	local success, rawLeaderboard = pcall(function()
		return DataManager:GetTopPlaytimePlayers(50) -- Fetch more entries
	end)

	if success and rawLeaderboard then
		for _, entry in ipairs(rawLeaderboard) do
			playtimeData[entry.UserId] = entry.Playtime
		end
	end

	-- 2. Update/add with real-time playtime for online players
	for _, player in pairs(Players:GetPlayers()) do
		local userId = player.UserId
		local currentPlaytime = DataManager:GetCurrentPlaytime(player)

		-- Update if real-time playtime is larger or player is new
		if currentPlaytime > 0 and (not playtimeData[userId] or currentPlaytime > playtimeData[userId]) then
			playtimeData[userId] = currentPlaytime
		end
	end

	-- 3. Convert to sortable array
	local sortedList = {}
	for userId, playtime in pairs(playtimeData) do
		if playtime > 0 then
			table.insert(sortedList, {
				UserId = userId,
				Playtime = playtime
			})
		end
	end

	-- 4. Sort by playtime descending
	table.sort(sortedList, function(a, b)
		return a.Playtime > b.Playtime
	end)

	return sortedList
end

local function updateLeaderboardGui()
	-- Fetch mixed data
	local rawLeaderboard = getMixedPlaytimeData()
	if not rawLeaderboard then return end

	local filteredLeaderboard = {}
	for i, entry in ipairs(rawLeaderboard) do
		-- Add if playtime > 0 and not excluded
		if (entry.Playtime or 0) > 0 and not shouldExcludeUser(entry.UserId) then
			-- Add rank
			entry.Rank = #filteredLeaderboard + 1
			table.insert(filteredLeaderboard, entry)
			if #filteredLeaderboard >= 10 then break end
		end
	end

	clearLeaderboard()

	local lineHeight = 40
	local spacing = 4
	local startY = 0

	for i, entry in ipairs(filteredLeaderboard) do
		local name = getNameFromUserId(entry.UserId)
		local playtime = entry.Playtime

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, lineHeight)
		label.Position = UDim2.new(0, 0, 0, startY + (i - 1) * (lineHeight + spacing))
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Cartoon
		label.TextScaled = true
		label.RichText = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextStrokeTransparency = 0.8
		label.ZIndex = 2
		label.AutoLocalize = false
		label.Text = string.format(
			'<font color="rgb(255,255,255)">%d. %s - </font><font color="rgb(0, 255, 255)">%s</font>',
			i, name, formatPlaytime(playtime)
		)

		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 40
		constraint.MinTextSize = 10
		constraint.Parent = label

		label.Parent = surfaceGui
	end
end

updateLeaderboardGui()
while task.wait(10) do -- Update every 10 seconds
	updateLeaderboardGui()
end
