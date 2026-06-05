local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dataManager = require(script.Parent.leaderstats.DataManager)

local remote           = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("FishDiscoverReward")
local getClaimedRF     = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("GetDiscoveryClaimed")
local discoverNoticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("DiscoverNoticeEvent")
local soldNotification = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SoldNotification")

local FISH_RARITY = {
	["Small Carp"] = "Common", ["Gold Fish"] = "Common", ["Stone Fish"] = "Common",
	["Crab"] = "Uncommon", ["Crystal Bass"] = "Uncommon", ["Dust Fish"] = "Uncommon",
	["Bass"] = "Rare", ["Snow Fish"] = "Rare", ["Diri"] = "Rare",
	["Dragon Head Fish"] = "Epic", ["Reggigash"] = "Epic",
	["Golden Trout"] = "Legendary", ["Armor Fish"] = "Legendary",
	["Shark"] = "Mystic", ["Ray"] = "Mystic",
	["Undyine"] = "Fantasy", ["Sans"] = "Fantasy", ["Electric Fish"] = "Fantasy",
	["Unknown"] = "Unknown", ["Nyan Cat"] = "Unknown",
	["Determination"] = "Soul",
	["Patience"] = "Soul", ["Bravery"] = "Soul", ["Integrity"] = "Soul",
	["Perseverance"] = "Soul", ["Kindness"] = "Soul", ["Justice"] = "Soul",
}

-- 기본 보상 (기존의 반토막)
local DISCOVER_REWARDS = {
	Common = 25, Uncommon = 75, Rare = 200, Epic = 500,
	Legendary = 1500, Mystic = 4000, Fantasy = 12500, Unknown = 50000, Soul = 150000,
}

-- 변이 보상 (기본의 2배)
local VARIANT_MULTIPLIER = 2

local VARIANT_PREFIXES = { "Gold", "Frozen", "Festival", "Sans" }

local function stripPrefixes(name)
	local result = name
	for _, prefix in ipairs(VARIANT_PREFIXES) do
		result = result:gsub("^" .. prefix .. " ", "")
	end
	return result
end

-- Returns { claimed, variantClaimed, discovered, variantDiscovered }
getClaimedRF.OnServerInvoke = function(player)
	local data = dataManager:GetData(player)
	local claimed        = (data and data.DiscoveryClaimed) or {}
	local variantClaimed = (data and data.VariantDiscoveryClaimed) or {}

	local leaderstats = player:FindFirstChild("leaderstats")
	local fishFolder    = leaderstats and leaderstats:FindFirstChild("Fish")
	local variantFolder = leaderstats and leaderstats:FindFirstChild("FishVariant")

	local discovered = {}
	if fishFolder then
		for _, b in ipairs(fishFolder:GetChildren()) do
			if b:IsA("BoolValue") and b.Value then discovered[b.Name] = true end
		end
	end

	local variantDiscovered = {}
	if variantFolder then
		for _, b in ipairs(variantFolder:GetChildren()) do
			if b:IsA("BoolValue") and b.Value then variantDiscovered[b.Name] = true end
		end
	end

	return {
		claimed = claimed,
		variantClaimed = variantClaimed,
		discovered = discovered,
		variantDiscovered = variantDiscovered,
	}
end

-- fishName: 기본 물고기 이름 또는 "Gold Bass" 같은 변이 이름
remote.OnServerEvent:Connect(function(player, fishName)
	if type(fishName) ~= "string" then return end

	local data = dataManager:GetData(player)
	if not data then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	local coinsValue = leaderstats:FindFirstChild("Coins")
	if not coinsValue then return end

	-- 변이인지 판단 (prefix 제거 후 남은 이름이 실제 물고기여야 변이)
	local detectedPrefix = nil
	for _, prefix in ipairs(VARIANT_PREFIXES) do
		if fishName:sub(1, #prefix + 1) == prefix .. " " then
			local stripped = stripPrefixes(fishName)
			if FISH_RARITY[stripped] then
				detectedPrefix = prefix
			end
			break
		end
	end

	if detectedPrefix then
		-- 변이 도감 보상
		local baseName = stripPrefixes(fishName)
		local rarity = FISH_RARITY[baseName]
		if not rarity then
			warn("FishDiscoverReward: unknown base fish:", baseName, "from", player.Name)
			return
		end

		local variantFolder = leaderstats:FindFirstChild("FishVariant")
		if not variantFolder then return end
		local vBool = variantFolder:FindFirstChild(fishName)
		if not vBool or not vBool.Value then
			warn("FishDiscoverReward: variant not discovered:", fishName, player.Name)
			return
		end

		if not data.VariantDiscoveryClaimed then data.VariantDiscoveryClaimed = {} end
		if data.VariantDiscoveryClaimed[fishName] then return end

		local rewardCoins = (DISCOVER_REWARDS[rarity] or 0) * VARIANT_MULTIPLIER
		local newCoins = coinsValue.Value + rewardCoins
		coinsValue.Value = newCoins

		data.VariantDiscoveryClaimed[fishName] = true
		dataManager:UpdateData(player, "Coins", newCoins)
		dataManager:UpdateData(player, "VariantDiscoveryClaimed", data.VariantDiscoveryClaimed)

		discoverNoticeEvent:FireClient(player,
			string.format("Variant Discovered: %s! +%d coins", fishName, rewardCoins), "#FFD700")
		soldNotification:FireClient(player, rewardCoins, false)
	else
		-- 기본 도감 보상
		local rarity = FISH_RARITY[fishName]
		if not rarity then
			warn("FishDiscoverReward: unknown fish:", fishName, "from", player.Name)
			return
		end

		local fishFolder = leaderstats:FindFirstChild("Fish")
		if not fishFolder then return end
		local fishBool = fishFolder:FindFirstChild(fishName)
		if not fishBool or not fishBool.Value then
			warn("FishDiscoverReward: fish not discovered:", fishName, player.Name)
			return
		end

		if not data.DiscoveryClaimed then data.DiscoveryClaimed = {} end
		if data.DiscoveryClaimed[fishName] then return end

		local rewardCoins = DISCOVER_REWARDS[rarity] or 0
		local newCoins = coinsValue.Value + rewardCoins
		coinsValue.Value = newCoins

		data.DiscoveryClaimed[fishName] = true
		dataManager:UpdateData(player, "Coins", newCoins)
		dataManager:UpdateData(player, "DiscoveryClaimed", data.DiscoveryClaimed)

		discoverNoticeEvent:FireClient(player,
			string.format("New discovery: %s! +%d coins", fishName, rewardCoins), "#00FFCC")
		soldNotification:FireClient(player, rewardCoins, false)
	end
end)
