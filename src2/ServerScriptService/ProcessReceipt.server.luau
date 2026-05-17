local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local DataManager = require(game:GetService("ServerScriptService"):WaitForChild("leaderstats"):WaitForChild("DataManager"))

local RANDOM_FISH_1  = 3591644219
local RANDOM_FISH_3  = 0
local FISH_TRAP_HARVEST_PRODUCT_ID = 3381869322

local SERVER_BOOST_PRODUCTS = {
	[3591613623] = true,
	[3591613620] = true,
	[3591613622] = true,
	[3591613619] = true,
}

-- Wait synchronously so boostPurchaseBE is always ready before any receipt fires
local boostPurchaseBE = (function()
	local api = game:GetService("ServerScriptService"):WaitForChild("ServerBoostManager"):WaitForChild("ServerBoostAPI", 30)
	return api and api:WaitForChild("BoostPurchased", 30) or nil
end)()

local FISH_POOL = {
	{ name="Dragon Head Fish",rarity="Epic",      chance=28.5, value=700   },
	{ name="Reggigash",       rarity="Epic",      chance=28.5, value=680   },
	{ name="Golden Trout",    rarity="Legendary", chance=10,   value=1800  },
	{ name="Armor Fish",      rarity="Legendary", chance=10,   value=2500  },
	{ name="Shark",           rarity="Mystic",    chance=6,    value=4500  },
	{ name="Ray",             rarity="Mystic",    chance=6,    value=4200  },
	{ name="Undyine",         rarity="Fantasy",   chance=2,    value=9000  },
	{ name="Sans",            rarity="Fantasy",   chance=2,    value=11111 },
	{ name="Electric Fish",   rarity="Fantasy",   chance=2,    value=13333 },
	{ name="Unknown",         rarity="Unknown",   chance=1,    value=50000 },
	{ name="Nyan Cat",        rarity="Unknown",   chance=1,    value=56000 },
}

local GACHA_RARITY_SCALE = {
	Epic      = 1.0,
	Legendary = 1.5,
	Mystic    = 2.0,
	Fantasy   = 2.5,
	Unknown   = 0.6,
}

local GACHA_BASE_LUCK = 20

local function rollFish()
	local pool = {}
	local total = 0
	for _, fish in ipairs(FISH_POOL) do
		local scale = GACHA_RARITY_SCALE[fish.rarity] or 1.0
		local adjusted = fish.chance * (1 + GACHA_BASE_LUCK * scale)
		table.insert(pool, {fish = fish, adjusted = adjusted})
		total += adjusted
	end
	local roll = math.random() * total
	local cumulative = 0
	for _, entry in ipairs(pool) do
		cumulative += entry.adjusted
		if roll <= cumulative then return entry.fish end
	end
	return FISH_POOL[1]
end

local function grantFish(player, fish)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	local fishFolder = leaderstats:FindFirstChild("Fish")
	if fishFolder then
		local fishBool = fishFolder:FindFirstChild(fish.name)
		if fishBool and not fishBool.Value then
			fishBool.Value = true
			local fishData = {}
			for _, bv in ipairs(fishFolder:GetChildren()) do
				if bv:IsA("BoolValue") then fishData[bv.Name] = bv.Value end
			end
			DataManager:UpdateData(player, "Fish", fishData)
		end
	end
	local coins = leaderstats:FindFirstChild("Coins")
	if coins then
		coins.Value = coins.Value + fish.value
		DataManager:UpdateData(player, "Coins", coins.Value)
	end
end

local randomFishResult = ReplicatedStorage:FindFirstChild("RandomFishResult")
if not randomFishResult then
	randomFishResult = Instance.new("RemoteEvent")
	randomFishResult.Name = "RandomFishResult"
	randomFishResult.Parent = ReplicatedStorage
end

local REVEAL_DELAY = 4.5

local function processRandomFish(player, count)
	for _ = 1, count do
		local forcedName = player:GetAttribute("ForcedRandomFish")
		if forcedName then player:SetAttribute("ForcedRandomFish", nil) end
		local fish
		if forcedName then
			for _, f in ipairs(FISH_POOL) do
				if f.rarity == forcedName then fish = f; break end
			end
		end
		fish = fish or rollFish()
		if randomFishResult then
			randomFishResult:FireClient(player, fish.name, fish.rarity)
		end
		task.delay(REVEAL_DELAY, function()
			if player and player.Parent then grantFish(player, fish) end
		end)
	end
end

local triggerRandomFish = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("TriggerRandomFish")
triggerRandomFish.Event:Connect(function(player)
	processRandomFish(player, 1)
end)

local noticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("ShowNoticeEvent")
local donationRefreshEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("DonationRefresh")
-- DonationForceRefresh is created by RemoteInit; wait for it here
local donationForceRefresh = ReplicatedStorage:WaitForChild("DonationForceRefresh", 30)

local donationValues = {
	[3364008117] = 2,
	[3364050876] = 5,
	[3364051385] = 10,
	[3364051789] = 50,
	[3364052354] = 100,
	[3364066503] = 500,
	[3364067189] = 1000,
	[3364067188] = 5000,
	[3591658074] = 10000,
	[3591658073] = 100000,
}


MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId

	if donationValues[productId] then
		local data = DataManager:GetData(player)
		if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local amount = donationValues[productId]
		local newAmount = (data.Donations or 0) + amount
		DataManager:UpdateData(player, "Donations", newAmount)
		pcall(function()
			DataStoreService:GetOrderedDataStore("DonationLeaderboard"):SetAsync(tostring(player.UserId), newAmount)
		end)
		noticeEvent:FireClient(player, "Thank you for donating " .. amount .. " R$!")
		if donationForceRefresh then
			task.delay(1, function() donationForceRefresh:Fire(player) end)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted

	elseif SERVER_BOOST_PRODUCTS[productId] then
		if not boostPurchaseBE then return Enum.ProductPurchaseDecision.NotProcessedYet end
		boostPurchaseBE:Fire(productId)
		return Enum.ProductPurchaseDecision.PurchaseGranted

	elseif productId == FISH_TRAP_HARVEST_PRODUCT_ID then
		local storage = ReplicatedStorage:FindFirstChild("FishTrapPurchases")
		if storage then
			for _, purchaseData in pairs(storage:GetChildren()) do
				if purchaseData:IsA("ObjectValue") and purchaseData.Value == player then
					local trapIdValue = purchaseData:FindFirstChild("TrapId")
					if trapIdValue then
						local signal = Instance.new("StringValue")
						signal.Name = "PurchaseComplete_" .. trapIdValue.Value
						signal.Value = player.Name
						signal.Parent = ReplicatedStorage
						Debris:AddItem(signal, 3)
						purchaseData:Destroy()
					end
					break
				end
			end
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted

	elseif productId == RANDOM_FISH_1 and RANDOM_FISH_1 ~= 0 then
		processRandomFish(player, 1)
		return Enum.ProductPurchaseDecision.PurchaseGranted

	elseif productId == RANDOM_FISH_3 and RANDOM_FISH_3 ~= 0 then
		processRandomFish(player, 3)
		return Enum.ProductPurchaseDecision.PurchaseGranted

	else
		warn("Unknown product ID:", productId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

local function waitForDataAndReset(player)
	while true do
		local data = DataManager:GetData(player)
		if data then
			data.Donations = 0
			DataManager:UpdateData(player, "Donations", 0)
			break
		end
		task.wait(1)
	end
end

Players.PlayerAdded:Connect(function(player)
	if player.Name == "tallmo_bim" then
		task.spawn(function() waitForDataAndReset(player) end)
	end
end)
