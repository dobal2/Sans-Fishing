local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")
local DataManager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))
local FishDataModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDataModule"))

local RANDOM_FISH_1  = 3591644219
local RANDOM_FISH_3  = 0
local FISH_TRAP_HARVEST_PRODUCT_ID = 3381869322
local RECOVER_PRODUCT_ID = 3596255843

-- 서버 테이블로 관리 (클라이언트 Attribute 조작 방지)
local pendingRecoverData = {}

-- FishingServerModule이 실패 시 fire하는 BindableEvent
local setPendingRecover = Instance.new("BindableEvent")
setPendingRecover.Name = "SetPendingRecover"
setPendingRecover.Parent = ServerScriptService
setPendingRecover.Event:Connect(function(userId, fishName, fishRarity, fishWeight, fishMinW, fishMaxW)
	pendingRecoverData[userId] = {
		fishName   = fishName,
		fishRarity = fishRarity,
		fishWeight = fishWeight,
		fishMinW   = fishMinW,
		fishMaxW   = fishMaxW,
	}
end)

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
	{ name="Dragon Head Fish",rarity="Epic",      chance=28.5, value=490   },
	{ name="Reggigash",       rarity="Epic",      chance=28.5, value=476   },
	{ name="Golden Trout",    rarity="Legendary", chance=10,   value=1260  },
	{ name="Armor Fish",      rarity="Legendary", chance=10,   value=1750  },
	{ name="Shark",           rarity="Mystic",    chance=6,    value=3150  },
	{ name="Ray",             rarity="Mystic",    chance=6,    value=2940  },
	{ name="Undyine",         rarity="Fantasy",   chance=2,    value=6300  },
	{ name="Sans",            rarity="Fantasy",   chance=2,    value=7778  },
	{ name="Electric Fish",   rarity="Fantasy",   chance=2,    value=9333  },
	{ name="Unknown",         rarity="Unknown",   chance=1,    value=35000 },
	{ name="Nyan Cat",        rarity="Unknown",   chance=1,    value=39200 },
	{ name="Determination",   rarity="Soul",      chance=0.4,  value=84000 },
	{ name="Patience",        rarity="Soul",      chance=0.4,  value=84000 },
	{ name="Bravery",         rarity="Soul",      chance=0.4,  value=84000 },
	{ name="Integrity",       rarity="Soul",      chance=0.4,  value=84000 },
	{ name="Perseverance",    rarity="Soul",      chance=0.4,  value=84000 },
	{ name="Kindness",        rarity="Soul",      chance=0.4,  value=84000 },
	{ name="Justice",         rarity="Soul",      chance=0.4,  value=84000 },
}

local GACHA_RARITY_SCALE = {
	Epic      = 1.0,
	Legendary = 1.5,
	Mystic    = 2.0,
	Fantasy   = 2.5,
	Unknown   = 0.6,
	Soul      = 0.2,
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

local FishCaughtBindable = nil
task.spawn(function()
	FishCaughtBindable = ServerScriptService:WaitForChild("FishCaughtBindable", 30)
end)

local function grantFish(player, fish)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	-- Find fish data from FishDataModule for weight/model info
	local fishModuleData = nil
	for _, rarityGroup in ipairs(FishDataModule.Rarities) do
		for _, f in ipairs(rarityGroup.fishes) do
			if f.fishName == fish.name then
				fishModuleData = f
				break
			end
		end
		if fishModuleData then break end
	end

	-- Calculate weight
	local minW = fishModuleData and fishModuleData.minWeight or 1
	local maxW = fishModuleData and fishModuleData.maxWeight or 10
	local weight = math.floor((minW + math.random() * (maxW - minW)) * 10) / 10

	-- Calculate value based on weight
	local baseValue = fish.value
	local valueRatio = math.clamp((weight - minW) / math.max(maxW - minW, 0.001), 0, 1)
	local adjustedValue = math.floor(baseValue * (1.2 + math.pow(valueRatio, 0.8) * 7.0))

	-- Route through FishCaughtBindable so ItemSave handles inventory storage
	-- fishInfo structure must match what buildFishItemData expects:
	--   fishName = plain fish name, name = rarity string, value = base value,
	--   weight, minWeight, maxWeight
	if FishCaughtBindable then
		local fishInfo = {
			fishName  = fish.name,
			name      = fish.rarity,
			value     = baseValue,
			weight    = weight,
			minWeight = minW,
			maxWeight = maxW,
		}
		FishCaughtBindable:Fire(player, fishInfo)
	else
		-- Fallback: grant directly to Backpack (legacy path)
		local model = fishModuleData and fishModuleData.model
		if model then
			local toolName = string.format("%s [%s] - %.1fkg", fish.name, fish.rarity, weight)
			local toolClone = model:Clone()
			toolClone.Name = toolName
			local valueObj = Instance.new("IntValue")
			valueObj.Name = "FishValue"
			valueObj.Value = adjustedValue
			valueObj.Parent = toolClone
			local weightObj = Instance.new("NumberValue")
			weightObj.Name = "FishWeight"
			weightObj.Value = weight
			weightObj.Parent = toolClone
			local rarityObj = Instance.new("StringValue")
			rarityObj.Name = "FishRarity"
			rarityObj.Value = fish.rarity
			rarityObj.Parent = toolClone
			local backpack = player:FindFirstChild("Backpack")
			if backpack then toolClone.Parent = backpack end
		end
	end

	-- Update fish discovery catalog
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

	-- Notify player
	local noticeRemote = ReplicatedStorage:FindFirstChild("Remotes")
		and ReplicatedStorage.Remotes:FindFirstChild("Notice")
		and ReplicatedStorage.Remotes.Notice:FindFirstChild("ShowNoticeEvent")
	if noticeRemote then
		noticeRemote:FireClient(player, string.format("You got %s [%s] - %.1fkg!", fish.name, fish.rarity, weight))
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

local purchaseLogEvent = ServerScriptService:WaitForChild("PurchaseLogEvent", 10)

-- Expose processRandomFish to other server scripts (e.g. Commands)
local GiveRandomFishBindable = Instance.new("BindableFunction")
GiveRandomFishBindable.Name = "GiveRandomFishBindable"
GiveRandomFishBindable.Parent = ServerScriptService
GiveRandomFishBindable.OnInvoke = function(player, count, forcedRarity)
	if forcedRarity then player:SetAttribute("ForcedRandomFish", forcedRarity) end
	processRandomFish(player, count or 1)
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

	local function logPurchase()
		if purchaseLogEvent then
			purchaseLogEvent:Fire(player.Name, productId)
		end
	end

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
		logPurchase()
		return Enum.ProductPurchaseDecision.PurchaseGranted

	elseif SERVER_BOOST_PRODUCTS[productId] then
		if not boostPurchaseBE then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local ok, err = pcall(function() boostPurchaseBE:Fire(productId) end)
		if not ok then
			warn("ServerBoost fire failed:", err)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		logPurchase()
		return Enum.ProductPurchaseDecision.PurchaseGranted

	elseif productId == FISH_TRAP_HARVEST_PRODUCT_ID then
		local storage = ReplicatedStorage:FindFirstChild("FishTrapPurchases")
		local found = false
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
						found = true
					end
					break
				end
			end
		end
		if not found then return Enum.ProductPurchaseDecision.NotProcessedYet end
		logPurchase()
		return Enum.ProductPurchaseDecision.PurchaseGranted

	elseif productId == RECOVER_PRODUCT_ID then
		local pending = pendingRecoverData[player.UserId]
		pendingRecoverData[player.UserId] = nil
		local fishName   = pending and pending.fishName
		local fishRarity = pending and pending.fishRarity
		local fishWeight = pending and pending.fishWeight
		local fishMinW   = pending and pending.fishMinW
		local fishMaxW   = pending and pending.fishMaxW
		if fishName and fishName ~= "" then
			local fishInfo = {
				fishName  = fishName,
				name      = fishRarity or "Common",
				value     = 0,
				weight    = fishWeight or 1,
				minWeight = fishMinW or 1,
				maxWeight = fishMaxW or 1,
			}
			-- Resolve base value from FishDataModule
			for _, rg in ipairs(FishDataModule.Rarities) do
				for _, f in ipairs(rg.fishes) do
					if f.fishName == fishName then
						fishInfo.value = f.value or 0
						break
					end
				end
			end
			if FishCaughtBindable then
				FishCaughtBindable:Fire(player, fishInfo)
			end
			local recoverNotice = ReplicatedStorage:FindFirstChild("Remotes")
				and ReplicatedStorage.Remotes:FindFirstChild("Fishing")
				and ReplicatedStorage.Remotes.Fishing:FindFirstChild("RecoverEvent")
			if recoverNotice then
				recoverNotice:FireClient(player, "granted")
			end
			noticeEvent:FireClient(player, string.format("Recovered: %s [%s] - %.1fkg!", fishName, fishRarity or "Common", fishWeight or 1))
		end
		logPurchase()
		return Enum.ProductPurchaseDecision.PurchaseGranted

	elseif productId == RANDOM_FISH_1 and RANDOM_FISH_1 ~= 0 then
		processRandomFish(player, 1)
		logPurchase()
		return Enum.ProductPurchaseDecision.PurchaseGranted

	elseif productId == RANDOM_FISH_3 and RANDOM_FISH_3 ~= 0 then
		processRandomFish(player, 3)
		logPurchase()
		return Enum.ProductPurchaseDecision.PurchaseGranted

	else
		warn("Unknown product ID:", productId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

Players.PlayerRemoving:Connect(function(player)
	pendingRecoverData[player.UserId] = nil
end)

local function waitForDataAndReset(player)
	while player:IsDescendantOf(Players) do
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
	if player.UserId == 1853104124 then
		task.spawn(function() waitForDataAndReset(player) end)
	end
end)
