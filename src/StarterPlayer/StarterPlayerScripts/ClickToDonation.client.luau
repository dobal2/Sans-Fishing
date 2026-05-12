local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local player = Players.LocalPlayer

local surfaceGui = workspace:WaitForChild("ClicktoDonation"):WaitForChild("LeadBoardPart"):WaitForChild("SurfaceGui")
local buttonTemplate = script:WaitForChild("TextButton")

local productIds = {
	3364008117,
	3364050876,
	3364051385,
	3364051789,
	3364052354,
	3364066503,
	3364067189,
	3364067188,
}

local productNames = {
	"2 Robux",
	"5 Robux",
	"10 Robux",
	"50 Robux",
	"100 Robux",
	"500 Robux",
	"1000 Robux",
	"5000 Robux",
}

for i, productId in ipairs(productIds) do
	local btn = buttonTemplate:Clone()
	btn.Position = UDim2.new(0, 0, 0, (i - 1) * 60)
	btn.Text = productNames[i]
	btn.Parent = surfaceGui

	btn.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
end

-- **아래 코드는 삭제!**
-- MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
-- 	if wasPurchased and userId == player.UserId then
-- 		DonationEvent:FireServer(productId)
-- 	end
-- end)
