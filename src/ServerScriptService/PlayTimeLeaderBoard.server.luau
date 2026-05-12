local DataManager = require(game.ServerScriptService.leaderstats.DataManager)
local Players = game:GetService("Players")
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
		return string.format("%dd %dh", days, hours)     -- 1일 이상: "2d 5h"
	elseif hours > 0 then
		return string.format("%dh %dm", hours, minutes)  -- 1시간 이상: "5h 30m"
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)   -- 1분 이상: "25m 45s"
	else
		return string.format("%ds", secs)                -- 1분 미만: "45s"
	end
end

-- 🆕 혼합 플레이타임 데이터 생성 함수
local function getMixedPlaytimeData()
	local playtimeData = {}

	-- 1. DataStore에서 저장된 플레이타임 데이터 가져오기
	local success, rawLeaderboard = pcall(function()
		return DataManager:GetTopPlaytimePlayers(50) -- 더 많이 가져오기
	end)

	if success and rawLeaderboard then
		for _, entry in ipairs(rawLeaderboard) do
			playtimeData[entry.UserId] = entry.Playtime
		end
	end

	-- 2. 온라인 플레이어들의 실시간 플레이타임으로 업데이트/추가
	for _, player in pairs(Players:GetPlayers()) do
		local userId = player.UserId
		local currentPlaytime = DataManager:GetCurrentPlaytime(player)

		-- 실시간 플레이타임이 더 크거나 새 플레이어면 업데이트
		if currentPlaytime > 0 and (not playtimeData[userId] or currentPlaytime > playtimeData[userId]) then
			playtimeData[userId] = currentPlaytime
		end
	end

	-- 3. 정렬 가능한 배열로 변환
	local sortedList = {}
	for userId, playtime in pairs(playtimeData) do
		if playtime > 0 then
			table.insert(sortedList, {
				UserId = userId,
				Playtime = playtime
			})
		end
	end

	-- 4. 플레이타임 기준으로 정렬 (높은 순)
	table.sort(sortedList, function(a, b)
		return a.Playtime > b.Playtime
	end)

	return sortedList
end

local function updateLeaderboardGui()
	-- 🆕 혼합 데이터 가져오기
	local rawLeaderboard = getMixedPlaytimeData()
	if not rawLeaderboard then return end

	local filteredLeaderboard = {}
	for i, entry in ipairs(rawLeaderboard) do
		-- 플레이타임 0 이상이고 제외 대상이 아니면 추가
		if (entry.Playtime or 0) > 0 and not shouldExcludeUser(entry.UserId) then
			-- 랭크 추가
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
while task.wait(10) do -- 10초마다 업데이트
	updateLeaderboardGui()
end
