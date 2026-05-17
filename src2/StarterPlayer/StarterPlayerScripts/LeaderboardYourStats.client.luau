local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local leaderboardRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Leaderboard")

local function formatCoins(n)
	if n >= 1000000000 then return string.format("%.1fB", n/1000000000)
	elseif n >= 1000000 then return string.format("%.1fM", n/1000000)
	elseif n >= 1000    then return string.format("%.1fK", n/1000)
	else return tostring(n) end
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
