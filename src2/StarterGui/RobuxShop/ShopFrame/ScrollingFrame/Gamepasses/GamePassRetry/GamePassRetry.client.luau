local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local image = script.Parent:WaitForChild("ImageLabel")
local button = script.Parent:WaitForChild("RobuxButton")
local buttonLabel = button:FindFirstChildOfClass("TextLabel")
local ownedFrame = script.Parent:WaitForChild("Owned")

local POWER_X2_GAMEPASS_ID = 1290056221

local function loadGamePassInfo(passId)
	local success, gamePassInfo = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)
	if success and gamePassInfo then
		image.Image = "rbxassetid://" .. gamePassInfo.IconImageAssetId
		if buttonLabel and gamePassInfo.PriceInRobux then
			buttonLabel.Text = "\xEE\x80\x82" .. gamePassInfo.PriceInRobux
		end
	else
		image.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	end
end

local function checkOwnership()
	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, POWER_X2_GAMEPASS_ID)
	end)
	if success then
		if hasPass then
			ownedFrame.Visible = true
			button.Active = false
			button.AutoButtonColor = false
		else
			ownedFrame.Visible = false
			button.Active = true
			button.AutoButtonColor = true
		end
	end
end

loadGamePassInfo(POWER_X2_GAMEPASS_ID)
checkOwnership()

button.MouseButton1Click:Connect(function()
	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, POWER_X2_GAMEPASS_ID)
	end)
	if success and hasPass then return end
	MarketplaceService:PromptGamePassPurchase(player, POWER_X2_GAMEPASS_ID)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(userId, assetId, wasPurchased)
	if userId == player.UserId and assetId == POWER_X2_GAMEPASS_ID and wasPurchased then
		ownedFrame.Visible = true
		button.Visible = false
	end
end)
