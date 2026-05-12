local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataManager = require(game:GetService("ServerScriptService"):WaitForChild("leaderstats"):WaitForChild("DataManager"))

local Players = game:GetService("Players")

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

			-- Force leaderboard update (extra guarantee)
			local userId = tostring(player.UserId)
			pcall(function()
				local DataStoreService = game:GetService("DataStoreService")
				local DonationLeaderboard = DataStoreService:GetOrderedDataStore("DonationLeaderboard")
				DonationLeaderboard:SetAsync(userId, newDonationAmount)
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
				-- Also update via DataManager
				DataManager:UpdateData(player, "Coins", coins.Value)
			end
		end
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
