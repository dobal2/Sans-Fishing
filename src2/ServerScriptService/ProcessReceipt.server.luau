local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(game:GetService("ServerScriptService"):WaitForChild("leaderstats"):WaitForChild("DataManager"))

-- RandomFish product IDs (replace 0 with real product IDs from Roblox dashboard)
local RANDOM_FISH_1  = 0
local RANDOM_FISH_3  = 0

local FISH_POOL = {
	{ name="Small Carp",      rarity="Common",    chance=44.4 / 3, value=80    },
	{ name="Gold Fish",       rarity="Common",    chance=44.4 / 3, value=100   },
	{ name="Stone Fish",      rarity="Common",    chance=44.4 / 3, value=400   },
	{ name="Crab",            rarity="Uncommon",  chance=25   / 3, value=160   },
	{ name="Crystal Bass",    rarity="Uncommon",  chance=25   / 3, value=160   },
	{ name="Dust Fish",       rarity="Uncommon",  chance=25   / 3, value=680   },
	{ name="Bass",            rarity="Rare",      chance=17   / 3, value=400   },
	{ name="Snow Fish",       rarity="Rare",      chance=17   / 3, value=400   },
	{ name="Diri",            rarity="Rare",      chance=17   / 3, value=680   },
	{ name="Dragon Head Fish",rarity="Epic",      chance=7    / 2, value=700   },
	{ name="Reggigash",       rarity="Epic",      chance=7    / 2, value=680   },
	{ name="Golden Trout",    rarity="Legendary", chance=4    / 2, value=1800  },
	{ name="Armor Fish",      rarity="Legendary", chance=4    / 2, value=2500  },
	{ name="Shark",           rarity="Mystic",    chance=2    / 2, value=4500  },
	{ name="Ray",             rarity="Mystic",    chance=2    / 2, value=4200  },
	{ name="Undyine",         rarity="Fantasy",   chance=0.5  / 3, value=9000  },
	{ name="Sans",            rarity="Fantasy",   chance=0.5  / 3, value=11111 },
	{ name="Electric Fish",   rarity="Fantasy",   chance=0.5  / 3, value=13333 },
	{ name="Unknown",         rarity="Unknown",   chance=0.1  / 2, value=50000 },
	{ name="Nyan Cat",        rarity="Unknown",   chance=0.1  / 2, value=56000 },
}

local function rollFish()
	local roll = math.random() * 100
	local cumulative = 0
	for _, fish in ipairs(FISH_POOL) do
		cumulative += fish.chance
		if roll <= cumulative then
			return fish
		end
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
		end
	end
	-- Add coins equal to fish value
	local coins = leaderstats:FindFirstChild("Coins")
	if coins then
		coins.Value = coins.Value + fish.value
		DataManager:UpdateData(player, "Coins", coins.Value)
	end
end

local randomFishResult = ReplicatedStorage:FindFirstChild("RandomFishResult")

local function processRandomFish(player, count)
	local results = {}
	for i = 1, count do
		local fish = rollFish()
		grantFish(player, fish)
		table.insert(results, { name = fish.name, rarity = fish.rarity, value = fish.value })
	end
	if randomFishResult then
		randomFishResult:FireClient(player, results)
	end
end

local donationValues = {
	[3364008117] = 2,
	[3364050876] = 5,
	[3364051385] = 10,
	[3364051789] = 50,
	[3364052354] = 100,
	[3364066503] = 500,
	[3364067189] = 1000,
	[3364067188] = 5000,
}

local coinPackages = {
	[3345059961] = {name="Starter", coins=1000, price=49},
	[3345107291] = {name="Basic", coins=5000, price=199},
	[3345108517] = {name="Standard", coins=15000, price=499},
	[3345109745] = {name="Premium", coins=40000, price=999},
	[3345110069] = {name="Deluxe", coins=100000, price=1999},
}

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId

	if donationValues[productId] then
		-- Process donation
		local data = DataManager:GetData(player)
		if data then
			local newDonationAmount = (data.Donations or 0) + donationValues[productId]

			-- Update via UpdateData (includes leaderboard update)
			DataManager:UpdateData(player, "Donations", newDonationAmount)

			-- Force leaderboard update
			local userId = tostring(player.UserId)
			pcall(function()
				DataStoreService:GetOrderedDataStore("DonationLeaderboard"):SetAsync(userId, newDonationAmount)
			end)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted

	elseif coinPackages[productId] then
		-- Process coin package
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local coins = leaderstats:FindFirstChild("Coins")
			if coins then
				coins.Value = coins.Value + coinPackages[productId].coins
				DataManager:UpdateData(player, "Coins", coins.Value)
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
		warn("Unknown product ID: " .. productId)
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
		else
			task.wait(1) -- Wait 1 second and retry
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	if player.Name == "tallmo_bim" then
		task.spawn(function()
			waitForDataAndReset(player)
		end)
	end
end)
