local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local DataManager = require(ServerScriptService.leaderstats.DataManager)
local surfaceGui = workspace:WaitForChild("DonationBoard"):WaitForChild("LeadBoardPart"):WaitForChild("SurfaceGui")
--local NextUpdateGui = workspace:WaitForChild("DonationBoard"):WaitForChild("NextUpdateValue"):WaitForChild("SurfaceGui")

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

local function formatDonationsAmount(amount)
	if amount < 1000 then
		return tostring(amount)
	else
		return string.format("%.1fK", amount / 1000)
	end
end

local function updateLeaderboardGui()
	-- Fetch top 20 donation players
	local success, rawLeaderboard = pcall(function()
		return DataManager:GetTopDonationPlayers(20)
	end)
	if not success or not rawLeaderboard then return end

	-- Sum all donations
	local successTotal, totalDonations = pcall(function()
		return DataManager:GetTotalDonations()
	end)
	if not successTotal or not totalDonations then
		totalDonations = 0
	end

	local filteredLeaderboard = {}
	for _, entry in ipairs(rawLeaderboard) do
		-- Add if donation > 0 and not excluded
		if (entry.Donations or 0) > 0 and not shouldExcludeUser(entry.UserId) then
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
		local donations = entry.Donations

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
			'<font color="rgb(255,255,255)">%d. %s - </font><font color="rgb(0, 255, 0)">%s Robux</font>',
			i, name, formatDonationsAmount(donations)
		)

		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 40
		constraint.MinTextSize = 10
		constraint.Parent = label

		label.Parent = surfaceGui
	end

	-- Goal example (1000K = 1,000,000 Robux)
	--local GOAL = 1500

	--NextUpdateGui:ClearAllChildren()

	--local totalLabel = Instance.new("TextLabel")
	--totalLabel.Size = UDim2.new(1, 0, 0.3, 0)
	--totalLabel.BackgroundTransparency = 1
	--totalLabel.Font = Enum.Font.Cartoon
	--totalLabel.TextScaled = true
	--totalLabel.RichText = true
	--totalLabel.TextXAlignment = Enum.TextXAlignment.Center
	--totalLabel.TextYAlignment = Enum.TextYAlignment.Center
	--totalLabel.TextStrokeTransparency = 0.8
	--totalLabel.ZIndex = 2
	--totalLabel.Text = string.format(
	--	'<font color="rgb(255,255,255)">Total Donations: </font><font color="rgb(0, 255, 0)">%s Robux</font>',
	--	formatDonationsAmount(totalDonations)
	--)
	--totalLabel.Parent = NextUpdateGui

	---- Progress bar background
	--local barBackground = Instance.new("Frame")
	--barBackground.Size = UDim2.new(0.8, 0, 0.2, 0)
	--barBackground.Position = UDim2.new(0.1, 0, 0.6, 0)
	--barBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	--barBackground.BorderSizePixel = 0
	--barBackground.ZIndex = 2
	--barBackground.Parent = NextUpdateGui

	---- Progress bar foreground (filled part)
	--local progressBar = Instance.new("Frame")
	--progressBar.Size = UDim2.new(math.clamp(totalDonations / GOAL, 0, 1), 0, 1, 0)
	--progressBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	--progressBar.BorderSizePixel = 0
	--progressBar.ZIndex = 3
	--progressBar.Parent = barBackground

	---- Progress percentage text (above bar)
	--local progressText = Instance.new("TextLabel")
	--progressText.Size = UDim2.new(1, 0, 1, 0)
	--progressText.BackgroundTransparency = 1
	--progressText.Font = Enum.Font.Cartoon
	--progressText.TextScaled = true
	--progressText.TextColor3 = Color3.new(1, 1, 1)
	--progressText.TextStrokeTransparency = 0.8
	--progressText.ZIndex = 4
	--progressText.Text = string.format("%.1f%%", math.clamp(totalDonations / GOAL * 100, 0, 100))
	--progressText.Parent = barBackground
end

updateLeaderboardGui()
while task.wait(3) do
	updateLeaderboardGui()
end
