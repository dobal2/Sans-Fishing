local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(game:GetService("ServerScriptService"):WaitForChild("leaderstats"):WaitForChild("DataManager"))

local RANDOM_FISH_1  = 3591644219
local RANDOM_FISH_3  = 0

local SERVER_BOOST_PRODUCTS = {
	[3591613623] = true,
	[3591613620] = true,
	[3591613622] = true,
	[3591613619] = true,
}

local boostPurchaseBE = nil
task.spawn(function()
	local api = game:GetService("ServerScriptService"):WaitForChild("ServerBoostManager"):WaitForChild("ServerBoostAPI", 10)
	if api then boostPurchaseBE = api:WaitForChild("BoostPurchased", 10) end
end)

local FISH_POOL = {
	-- Common/Uncommon/Rare excluded from gacha pool
	-- Epic: 57%, Legendary: 20%, Mystic: 12%, Fantasy: 6%, Unknown: 2%  (total 97% + rounding = ~100%)
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
if not randomFishResult then
	randomFishResult = Instance.new("RemoteEvent")
	randomFishResult.Name = "RandomFishResult"
	randomFishResult.Parent = ReplicatedStorage
end

local REVEAL_DELAY = 4.5  -- seconds to wait before granting fish (matches client animation)

local function processRandomFish(player, count)
	for _ = 1, count do
		-- Check for forced random fish rarity (admin command)
		local forcedName = player:GetAttribute("ForcedRandomFish")
		if forcedName then
			player:SetAttribute("ForcedRandomFish", nil)
		end
		local fish
		if forcedName then
			for _, f in ipairs(FISH_POOL) do
				if f.rarity == forcedName then fish = f break end
			end
		end
		fish = fish or rollFish()
		-- Fire reveal immediately, grant fish after animation plays
		if randomFishResult then
			randomFishResult:FireClient(player, fish.name, fish.rarity)
		end
		task.delay(REVEAL_DELAY, function()
			if player and player.Parent then
				grantFish(player, fish)
			end
		end)
	end
end

-- 5% free gacha trigger from fishing success
local triggerRandomFish = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("TriggerRandomFish")
triggerRandomFish.Event:Connect(function(player)
	processRandomFish(player, 1)
end)

local noticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("ShowNoticeEvent")
local donationRefreshEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("DonationRefresh")

-- DonationLeaderBoard 서버에 갱신 신호 보내는 BindableEvent
local donationForceRefresh = Instance.new("BindableEvent")
donationForceRefresh.Name = "DonationForceRefresh"
donationForceRefresh.Parent = ReplicatedStorage

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
		local data = DataManager:GetData(player)
		if data then
			local amount = donationValues[productId]
			local newDonationAmount = (data.Donations or 0) + amount
			DataManager:UpdateData(player, "Donations", newDonationAmount)
			local userId = tostring(player.UserId)
			pcall(function()
				DataStoreService:GetOrderedDataStore("DonationLeaderboard"):SetAsync(userId, newDonationAmount)
			end)
			-- 알림 + 리더보드 갱신
			noticeEvent:FireClient(player, "감사합니다! " .. amount .. " R$ 도네이션해주셨습니다!")
			task.delay(1, function()
				donationForceRefresh:Fire(player)
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

	elseif SERVER_BOOST_PRODUCTS[productId] then
		if boostPurchaseBE then boostPurchaseBE:Fire(productId) end
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
