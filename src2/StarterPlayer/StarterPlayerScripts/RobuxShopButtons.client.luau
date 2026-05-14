local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local scroll = player.PlayerGui:WaitForChild("RobuxShop")
	:WaitForChild("Shop")
	:WaitForChild("Main")
	:WaitForChild("ScrollingFrame")

local passes = scroll:WaitForChild("Passes")

local GAMEPASSES = {
	{ passes:WaitForChild("Coin x2"),  1293430515 },
	{ passes:WaitForChild("Luck x2"),  1289569606 },
	{ passes:WaitForChild("Power x2"), 1290056221 },
}

local function setupGamePass(frame, gamePassId)
	local button = frame:FindFirstChild("BuyButton")
	if not button then return end

	local function refreshOwnership()
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
		end)
		if not ok then return end
		button.Active = not has
		button.AutoButtonColor = not has
		local ownedLabel = frame:FindFirstChild("Owned") or frame:FindFirstChild("OwnedLabel")
		if ownedLabel then ownedLabel.Visible = has end
	end

	refreshOwnership()

	button.MouseButton1Click:Connect(function()
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
		end)
		if ok and has then return end
		MarketplaceService:PromptGamePassPurchase(player, gamePassId)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(userId, assetId, wasPurchased)
		if userId == player.UserId and assetId == gamePassId and wasPurchased then
			button.Active = false
			button.AutoButtonColor = false
			local ownedLabel = frame:FindFirstChild("Owned") or frame:FindFirstChild("OwnedLabel")
			if ownedLabel then ownedLabel.Visible = true end
		end
	end)
end

for _, entry in ipairs(GAMEPASSES) do
	task.spawn(setupGamePass, entry[1], entry[2])
end
