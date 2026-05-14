-- Handles Upgrade Shop ProximityPrompt.
-- Moved from workspace.Upgrade Shop.ShopSeller.ProximityPrompt.Script

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shopSellerDialog = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("ShopSellerDialog")
local setPromptEvent   = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SetPromptEvent")

local function findPrompt(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			return d
		end
	end
end

local upgradeShop = workspace:WaitForChild("Upgrade Shop", 30)
local shopSeller = upgradeShop and upgradeShop:FindFirstChild("ShopSeller")
local proximity = shopSeller and findPrompt(shopSeller)

if proximity then
	proximity.Triggered:Connect(function(player)
		shopSellerDialog:FireClient(player)
	end)

	setPromptEvent.OnServerEvent:Connect(function(player, enabled, target)
		if target == "shop_seller" then
			proximity.Enabled = enabled
		end
	end)
end
