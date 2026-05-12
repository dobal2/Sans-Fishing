-- Global FishTrap purchase handler (place in ServerScriptService)
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Developer Product ID
local FISH_TRAP_HARVEST_PRODUCT_ID = 3381869322

-- Global purchase data storage
local purchaseStorage = ReplicatedStorage:FindFirstChild("FishTrapPurchases")
if not purchaseStorage then
	purchaseStorage = Instance.new("Folder")
	purchaseStorage.Name = "FishTrapPurchases"
	purchaseStorage.Parent = ReplicatedStorage
end

-- Global purchase handler setup (run once only)
MarketplaceService.ProcessReceipt = function(receiptInfo)
	if receiptInfo.ProductId == FISH_TRAP_HARVEST_PRODUCT_ID then
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Find purchase info and process
		for _, purchaseData in pairs(purchaseStorage:GetChildren()) do
			if purchaseData:IsA("ObjectValue") and purchaseData.Value == player then
				local trapIdValue = purchaseData:FindFirstChild("TrapId")
				local fishDataValue = purchaseData:FindFirstChild("FishData")

				if trapIdValue and fishDataValue then

					-- Send purchase complete signal to the fish trap
					local completeSignal = Instance.new("StringValue")
					completeSignal.Name = "PurchaseComplete_" .. trapIdValue.Value
					completeSignal.Value = player.Name
					completeSignal.Parent = ReplicatedStorage

					-- Remove signal after 3 seconds
					game:GetService("Debris"):AddItem(completeSignal, 3)

					-- Remove purchase data
					purchaseData:Destroy()

					return Enum.ProductPurchaseDecision.PurchaseGranted
				end
			end
		end

		return Enum.ProductPurchaseDecision.PurchaseGranted -- Prevent refund
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end
