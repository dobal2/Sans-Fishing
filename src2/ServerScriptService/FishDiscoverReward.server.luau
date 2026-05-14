local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dataManager = require(script.Parent.leaderstats.DataManager)

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("FishDiscoverReward")
local discoverNoticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("DiscoverNoticeEvent")

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
	if type(fishName) ~= "string" or not VALID_FISHES[fishName] then
		warn("FishDiscoverReward: invalid fishName from", player.Name, tostring(fishName))
		return
	end

	rewardCoins = math.floor(tonumber(rewardCoins) or 0)
	if rewardCoins <= 0 or rewardCoins > MAX_REWARD then
		warn("FishDiscoverReward: invalid rewardCoins from", player.Name, rewardCoins)
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	local fishFolder = leaderstats:FindFirstChild("Fish")
	if not fishFolder then return end

	local fishBool = fishFolder:FindFirstChild(fishName)
	if not fishBool or not fishBool.Value then
		warn("FishDiscoverReward: fish not actually discovered for", player.Name, fishName)
		return
	end

	local coinsValue = leaderstats:FindFirstChild("Coins")
	if not coinsValue then return end

	local newCoins = coinsValue.Value + rewardCoins
	coinsValue.Value = newCoins

	local data = dataManager:GetData(player)
	if data then
		dataManager:UpdateData(player, "Coins", newCoins)
	end

	local message = string.format("New discovery: %s! +%d coins", fishName, rewardCoins)
	discoverNoticeEvent:FireClient(player, message, "#00FFCC")
end)
