local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(ServerScriptService.leaderstats.DataManager)
local donationRefreshEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("DonationRefresh")

local excludedUsernames = {}
local nameCache = {}

local function getNameFromUserId(userId)
	if nameCache[userId] then return nameCache[userId] end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = ok and result or "Unknown"
	nameCache[userId] = name
	return name
end

local function shouldExcludeUser(userId)
	local name = string.lower(getNameFromUserId(userId))
	return excludedUsernames[name] == true
end

local cachedList = {}

local function buildDonationList()
	local raw = DataManager:GetTopDonationPlayers(120)
	local result = {}
	for _, entry in ipairs(raw) do
		if (entry.Donations or 0) > 0 and not shouldExcludeUser(entry.UserId) then
			local name = getNameFromUserId(entry.UserId)
			table.insert(result, {
				userId    = entry.UserId,
				name      = name,
				donations = entry.Donations,
				rank      = #result + 1,
			})
			if #result >= 100 then break end
		end
	end
	return result
end

local function sendToPlayer(player)
	local myData = nil
	for _, entry in ipairs(cachedList) do
		if entry.userId == player.UserId then
			myData = entry
			break
		end
	end
	if not myData then
		local profile = DataManager:GetData(player)
		local donations = profile and profile.Donations or 0
		myData = {
			userId    = player.UserId,
			name      = player.Name,
			donations = donations,
			rank      = nil,
		}
	end
	donationRefreshEvent:FireClient(player, cachedList, myData)
end

local function refreshAll()
	cachedList = buildDonationList()
	for _, player in ipairs(Players:GetPlayers()) do
		sendToPlayer(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.wait(3)
	sendToPlayer(player)
end)

-- Client can request a refresh (e.g. after donating)
donationRefreshEvent.OnServerEvent:Connect(function(player)
	sendToPlayer(player)
end)

refreshAll()
while task.wait(30) do
	refreshAll()
end
