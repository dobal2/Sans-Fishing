local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dataManager = require(script.Parent.leaderstats.DataManager)

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("FishDiscoverReward")
local getClaimedRF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("GetDiscoveryClaimed")
local discoverNoticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("DiscoverNoticeEvent")

local FISH_RARITY = {
	["Small Carp"] = "Common", ["Gold Fish"] = "Common", ["Stone Fish"] = "Common",
	["Crab"] = "Uncommon", ["Crystal Bass"] = "Uncommon", ["Dust Fish"] = "Uncommon",
	["Bass"] = "Rare", ["Snow Fish"] = "Rare", ["Diri"] = "Rare",
	["Dragon Head Fish"] = "Epic", ["Reggigash"] = "Epic",
	["Golden Trout"] = "Legendary", ["Armor Fish"] = "Legendary",
	["Shark"] = "Mystic", ["Ray"] = "Mystic",
	["Undyine"] = "Fantasy", ["Sans"] = "Fantasy", ["Electric Fish"] = "Fantasy",
	["Unknown"] = "Unknown", ["Nyan Cat"] = "Unknown",
}

local DISCOVER_REWARDS = {
	Common = 50, Uncommon = 150, Rare = 400, Epic = 1000,
	Legendary = 3000, Mystic = 8000, Fantasy = 25000, Unknown = 100000,
}

-- Returns table of fishName → true for already-claimed rewards
getClaimedRF.OnServerInvoke = function(player)
	local data = dataManager:GetData(player)
	if not data then return {} end
	return data.DiscoveryClaimed or {}
end

remote.OnServerEvent:Connect(function(player, fishName)
	if type(fishName) ~= "string" then
		warn("FishDiscoverReward: invalid fishName from", player.Name)
		return
	end

	local rarity = FISH_RARITY[fishName]
	if not rarity then
		warn("FishDiscoverReward: unknown fish from", player.Name, tostring(fishName))
		return
	end

	local data = dataManager:GetData(player)
	if not data then return end

	-- Persistent duplicate prevention via DataStore
	if not data.DiscoveryClaimed then data.DiscoveryClaimed = {} end
	if data.DiscoveryClaimed[fishName] then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	local fishFolder = leaderstats:FindFirstChild("Fish")
	if not fishFolder then return end

	-- Verify the fish is actually discovered server-side
	local fishBool = fishFolder:FindFirstChild(fishName)
	if not fishBool or not fishBool.Value then
		warn("FishDiscoverReward: fish not actually discovered for", player.Name, fishName)
		return
	end

	local coinsValue = leaderstats:FindFirstChild("Coins")
	if not coinsValue then return end

	local rewardCoins = DISCOVER_REWARDS[rarity] or 0
	local newCoins = coinsValue.Value + rewardCoins
	coinsValue.Value = newCoins

	-- Mark as claimed in persistent data
	data.DiscoveryClaimed[fishName] = true
	dataManager:UpdateData(player, "Coins", newCoins)

	local message = string.format("New discovery: %s! +%d coins", fishName, rewardCoins)
	discoverNoticeEvent:FireClient(player, message, "#00FFCC")
end)
