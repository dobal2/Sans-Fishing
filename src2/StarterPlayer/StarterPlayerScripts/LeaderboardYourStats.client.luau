local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local leaderboardRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Leaderboard")

local NUMBER_SUFFIXES = {
	{1e63, "Vg"}, {1e60, "Nod"}, {1e57, "Ocd"}, {1e54, "Spd"}, {1e51, "Sxd"},
	{1e48, "Qid"}, {1e45, "Qad"}, {1e42, "Td"}, {1e39, "Dd"}, {1e36, "Ud"},
	{1e33, "Dc"}, {1e30, "No"}, {1e27, "Oc"}, {1e24, "Sp"}, {1e21, "Sx"},
	{1e18, "Qi"}, {1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"},
}

local function formatCoins(n)
	n = math.floor(tonumber(n) or 0)
	for _, unit in ipairs(NUMBER_SUFFIXES) do
		if n >= unit[1] then return string.format("%.1f%s", n / unit[1], unit[2]) end
	end
	return tostring(n)
end

local function formatTime(secs)
	local h = math.floor(secs / 3600)
	local m = math.floor((secs % 3600) / 60)
	if h > 0 then return string.format("%dh %dm", h, m)
	else return string.format("%dm", m) end
end

local function applyToFrame(frame, rank, userId, displayName, userName, amtText)
	if not frame then return end
	local pos  = frame:FindFirstChild("PositionText")
	local img  = frame:FindFirstChild("ImageLabel")
	local disp = frame:FindFirstChild("DisplayName")
	local amt  = frame:FindFirstChild("Amount")
	local user = frame:FindFirstChild("UserName")
	if pos  then pos.Text  = rank and ("#" .. rank) or "-" end
	if img  then img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150" end
	if disp then disp.Text = displayName end
	if amt  then amt.Text  = amtText end
	if user then user.Text = "@" .. userName end
end

-- Coin leaderboard YourStats
local coinEvent = leaderboardRemotes:WaitForChild("CoinYourStats")
coinEvent.OnClientEvent:Connect(function(rank, coins, userId, displayName, userName)
	local lb = workspace:FindFirstChild("CoinLeaderboard")
	if not lb then return end
	local ysp = lb:FindFirstChild("YourStatsPart")
	local sg  = ysp and ysp:FindFirstChild("SurfaceGui")
	local frame = sg and sg:FindFirstChild("Frame")
	applyToFrame(frame, rank, userId, displayName, userName, formatCoins(coins))
end)

-- Playtime leaderboard YourStats
local playtimeEvent = leaderboardRemotes:WaitForChild("PlaytimeYourStats")
playtimeEvent.OnClientEvent:Connect(function(rank, playtime, userId, displayName, userName)
	local lb = workspace:FindFirstChild("PlayTimeLeaderboard")
	if not lb then return end
	local ysp = lb:FindFirstChild("YourStatsPart")
	local sg  = ysp and ysp:FindFirstChild("SurfaceGui")
	local frame = sg and sg:FindFirstChild("Frame")
	applyToFrame(frame, rank, userId, displayName, userName, formatTime(playtime))
end)
