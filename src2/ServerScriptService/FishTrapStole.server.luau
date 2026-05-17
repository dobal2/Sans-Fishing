local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- FishTrapPurchases folder: purchase data written here, read by ProcessReceipt.server.luau
local purchaseStorage = ReplicatedStorage:FindFirstChild("FishTrapPurchases")
if not purchaseStorage then
	purchaseStorage = Instance.new("Folder")
	purchaseStorage.Name = "FishTrapPurchases"
	purchaseStorage.Parent = ReplicatedStorage
end
