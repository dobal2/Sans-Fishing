local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local DataManager = require(ServerScriptService.leaderstats.DataManager)
local surfaceGui = workspace:WaitForChild("LeaderBoard"):WaitForChild("LeadBoardPart"):WaitForChild("SurfaceGui")

-- Excluded user list (stored in lowercase for case-insensitive comparison)
local excludedUsernames = {
	["bluehome79"] = true,
	["tallmo_bim"] = true,
	["mkdoingsu"] = true,
	["thatcoolgamedev"] = true
}

-- Get username from UserId
local function getNameFromUserId(userId)
	local name = "Unknown"
	pcall(function()
		name = Players:GetNameFromUserIdAsync(userId)
	end)
	return name
end

-- Clear existing text
local function clearLeaderboard()
	for _, child in pairs(surfaceGui:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

-- Check if user should be excluded
local function shouldExcludeUser(userId)
	local name = getNameFromUserId(userId)
	-- Convert name to lowercase for comparison
	return excludedUsernames[string.lower(name)] == true
end

-- Update leaderboard display (with filtering)
local function updateLeaderboardGui()
	local rawLeaderboard = DataManager:GetTopCoinPlayers(20) -- Fetch more, filter down to 10
	if not rawLeaderboard then return end

	-- Filter out excluded users
	local filteredLeaderboard = {}
	for _, entry in ipairs(rawLeaderboard) do
		if not shouldExcludeUser(entry.UserId) then
			table.insert(filteredLeaderboard, entry)
			-- Stop once we have 10
			if #filteredLeaderboard >= 10 then
				break
			end
		end
	end

	clearLeaderboard()

	local lineHeight = 40
	local spacing = 4
	local startY = 0

	for i, entry in ipairs(filteredLeaderboard) do
		local name = getNameFromUserId(entry.UserId)
		local coins = entry.Coins

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, lineHeight)
		label.Position = UDim2.new(0, 0, 0, startY + (i - 1) * (lineHeight + spacing))
		label.BackgroundTransparency = 1
		label.FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
		label.TextScaled = true
		label.RichText = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.AutoLocalize = false
		label.Text = string.format(
			'<font color="rgb(255,255,255)">%d. %s - </font><font color="rgb(255, 221, 0)">%d Coins</font>',
			i, name, coins
		)

		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 40
		constraint.MinTextSize = 10
		constraint.Parent = label

		label.Parent = surfaceGui
	end
end

-- Periodic update
updateLeaderboardGui()
while true do
	task.wait(5)
	updateLeaderboardGui()
end
