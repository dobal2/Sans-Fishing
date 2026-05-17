local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlaytimeStore = DataStoreService:GetOrderedDataStore("PlaytimeLeaderBoard")

local lb          = workspace:WaitForChild("PlayTimeLeaderboard")
local surfaceGui  = lb:WaitForChild("LeaderBoard"):WaitForChild("SurfaceGui")
local scrollFrame = surfaceGui:WaitForChild("ScrollFrame")
local uiList      = scrollFrame:FindFirstChildOfClass("UIListLayout")

local playtimeYourStatsEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Leaderboard"):WaitForChild("PlaytimeYourStats")

surfaceGui.MaxDistance = math.huge

-- Move template outside ScrollFrame so UIListLayout ignores it
local template = surfaceGui:FindFirstChild("Template") or scrollFrame:FindFirstChild("Template")
template.Parent = surfaceGui
template.Visible = false

-- Clear any leftover entries
for _, c in ipairs(scrollFrame:GetChildren()) do
	if c:IsA("Frame") then c:Destroy() end
end

-- Loading placeholder shown until first updateBoard() completes
local loadingFrame = Instance.new("Frame")
loadingFrame.Name = "_Loading"
loadingFrame.Size = UDim2.new(1, 0, 0, 60)
loadingFrame.BackgroundTransparency = 1
local loadingLabel = Instance.new("TextLabel", loadingFrame)
loadingLabel.Size = UDim2.fromScale(1, 1)
loadingLabel.BackgroundTransparency = 1
loadingLabel.Text = "Loading..."
loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
loadingLabel.TextScaled = true
loadingLabel.Font = Enum.Font.GothamBold
loadingFrame.Parent = scrollFrame

scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
local function updateCanvas()
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, uiList.AbsoluteContentSize.Y)
end
uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

local EXCLUDED = {
	bluehome79      = true,
	tallmo_bim      = true,
	mkdoingsu       = true,
	thatcoolgamedev = true,
	uiuiuioiuiuiu   = true,
}
local nameCache = {}

local function getName(userId)
	if nameCache[userId] then return nameCache[userId] end
	local ok, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	name = ok and name or ("User" .. userId)
	nameCache[userId] = name
	return name
end

local function formatTime(secs)
	local h = math.floor(secs / 3600)
	local m = math.floor((secs % 3600) / 60)
	if h > 0 then
		return string.format("%dh %dm", h, m)
	else
		return string.format("%dm", m)
	end
end

local lastEntries = {}

local function updateYourStats(player, entries)
	local rank, playtime = nil, 0
	for i, e in ipairs(entries) do
		if e.UserId == player.UserId then rank = i; playtime = e.Playtime; break end
	end
	playtimeYourStatsEvent:FireClient(player, rank, playtime, player.UserId, player.DisplayName, player.Name)
end

local function updateBoard()
	local ok, raw = pcall(function()
		local pages = PlaytimeStore:GetSortedAsync(false, 100)
		local t = {}
		for i, entry in ipairs(pages:GetCurrentPage()) do
			table.insert(t, {UserId = tonumber(entry.key), Playtime = entry.value, Rank = i})
		end
		return t
	end)
	if not ok or not raw then return end

	-- Pre-fetch all names in parallel
	local threads = {}
	for _, entry in ipairs(raw) do
		if not nameCache[entry.UserId] then
			table.insert(threads, task.spawn(function() getName(entry.UserId) end))
		end
	end
	for _ in ipairs(threads) do task.wait() end

	local filtered = {}
	for _, entry in ipairs(raw) do
		local name = getName(entry.UserId)
		if not EXCLUDED[string.lower(name)] then
			table.insert(filtered, entry)
			if #filtered >= 100 then break end
		end
	end
	lastEntries = filtered

	for _, c in ipairs(scrollFrame:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	for i, entry in ipairs(filtered) do
		local uname = getName(entry.UserId)
		local clone = template:Clone()
		clone.Name = "Entry_" .. i
		clone.LayoutOrder = i
		clone.Visible = true

		local pos  = clone:FindFirstChild("PositionText")
		local img  = clone:FindFirstChild("ImageLabel")
		local disp = clone:FindFirstChild("DisplayName")
		local amt  = clone:FindFirstChild("Amount")
		local user = clone:FindFirstChild("UserName")

		if pos  then pos.Text  = "#" .. i end
		if img  then img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. entry.UserId .. "&w=150&h=150" end
		if disp then disp.Text = uname end
		if amt  then amt.Text  = formatTime(entry.Playtime) end
		if user then user.Text = "@" .. uname end

		clone.Parent = scrollFrame
	end

	updateCanvas()

	for _, player in ipairs(Players:GetPlayers()) do
		updateYourStats(player, lastEntries)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.wait(3)
	if #lastEntries > 0 then updateYourStats(player, lastEntries) end
end)

updateBoard()
while task.wait(60) do
	updateBoard()
end
