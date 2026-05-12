local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dataManager = require(script.Parent.leaderstats.DataManager)

-- Create the RemoteEvent if it doesn't exist yet
local remote = ReplicatedStorage:FindFirstChild("FishDiscoverReward")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "FishDiscoverReward"
	remote.Parent = ReplicatedStorage
end

-- Notification RemoteEvent (reuse existing or create)
local function getNotifyRemote()
	local r = ReplicatedStorage:FindFirstChild("LeaderboardNotificationEvent")
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = "LeaderboardNotificationEvent"
		r.Parent = ReplicatedStorage
	end
	return r
end

local VALID_FISHES = {
	["Small Carp"] = true, ["Gold Fish"] = true, ["Stone Fish"] = true,
	["Crab"] = true, ["Crystal Bass"] = true, ["Dust Fish"] = true,
	["Bass"] = true, ["Snow Fish"] = true, ["Diri"] = true,
	["Dragon Head Fish"] = true, ["Reggigash"] = true,
	["Golden Trout"] = true, ["Armor Fish"] = true,
	["Shark"] = true, ["Ray"] = true,
	["Undyine"] = true, ["Sans"] = true, ["Electric Fish"] = true,
	["Unknown"] = true, ["Nyan Cat"] = true,
}

local MAX_REWARD = 100000

remote.OnServerEvent:Connect(function(player, fishName, rewardCoins)
	-- Validate inputs
	if type(fishName) ~= "string" or not VALID_FISHES[fishName] then
		warn("FishDiscoverReward: invalid fishName from", player.Name, tostring(fishName))
		return
	end

	rewardCoins = math.floor(tonumber(rewardCoins) or 0)
	if rewardCoins <= 0 or rewardCoins > MAX_REWARD then
		warn("FishDiscoverReward: invalid rewardCoins from", player.Name, rewardCoins)
		return
	end

	-- Verify the fish is actually discovered in leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	local fishFolder = leaderstats:FindFirstChild("Fish")
	if not fishFolder then return end

	local fishBool = fishFolder:FindFirstChild(fishName)
	if not fishBool or not fishBool.Value then
		warn("FishDiscoverReward: fish not actually discovered for", player.Name, fishName)
		return
	end

	-- Give coins
	local coinsValue = leaderstats:FindFirstChild("Coins")
	if not coinsValue then return end

	local newCoins = coinsValue.Value + rewardCoins
	coinsValue.Value = newCoins

	local data = dataManager:GetData(player)
	if data then
		dataManager:UpdateData(player, "Coins", newCoins)
	end

	-- Notify the discovering player
	local notifyRemote = getNotifyRemote()
	local message = string.format("New discovery: %s! +" .. rewardCoins .. " coins", fishName)
	notifyRemote:FireClient(player, message, "#00FFCC")
end)
