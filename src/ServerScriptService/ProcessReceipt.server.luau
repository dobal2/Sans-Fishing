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
		-- 도네이션 처리
		local data = DataManager:GetData(player)
		if data then
			local newDonationAmount = (data.Donations or 0) + donationValues[productId]

			-- ✅ UpdateData로 업데이트 (이미 리더보드 업데이트 포함됨)
			DataManager:UpdateData(player, "Donations", newDonationAmount)

			print(player.Name .. "님이 " .. donationValues[productId] .. " Robux 도네이션 하셨습니다! 총 도네이션: " .. newDonationAmount)

			-- ✅ 강제로 리더보드 업데이트 (추가 보장)
			local userId = tostring(player.UserId)
			pcall(function()
				local DataStoreService = game:GetService("DataStoreService")
				local DonationLeaderboard = DataStoreService:GetOrderedDataStore("DonationLeaderboard")
				DonationLeaderboard:SetAsync(userId, newDonationAmount)
				print("✅ 도네이션 리더보드 업데이트 완료:", player.Name, newDonationAmount)
			end)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted

	elseif coinPackages[productId] then
		-- 코인 패키지 처리 (기존과 동일)
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local coins = leaderstats:FindFirstChild("Coins")
			if coins then
				coins.Value = coins.Value + coinPackages[productId].coins
				-- ✅ DataManager로도 업데이트
				DataManager:UpdateData(player, "Coins", coins.Value)
				print(player.Name .. "님이 " .. coinPackages[productId].name .. " 코인 패키지를 구매했습니다.")
			end
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn("❌ Unknown product ID: " .. productId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

local function waitForDataAndReset(player)
	while true do
		local data = DataManager:GetData(player)
		if data then
			data.Donations = 0
			DataManager:UpdateData(player, "Donations", 0)
			print(player.Name .. "님의 도네이션이 0으로 초기화 되었습니다.")
			break
		else
			task.wait(1) -- 1초 대기 후 다시 시도
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
