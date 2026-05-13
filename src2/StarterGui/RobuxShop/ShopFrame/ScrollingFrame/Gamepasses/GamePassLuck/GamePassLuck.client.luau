local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local image = script.Parent:WaitForChild("ImageLabel")
local button = script.Parent:WaitForChild("RobuxButton")
local buttonLabel = button:FindFirstChildOfClass("TextLabel")
local ownedFrame = script.Parent:WaitForChild("Owned")

local gamePassId = 1289569606

local function loadGamePassInfo(passId)
	local success, gamePassInfo = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)
	if success and gamePassInfo then
		image.Image = "rbxassetid://" .. gamePassInfo.IconImageAssetId
		if buttonLabel and gamePassInfo.PriceInRobux then
			buttonLabel.Text = "\xEE\x80\x82" .. gamePassInfo.PriceInRobux
		end
		return gamePassInfo
	else
		image.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
		return nil
	end
end

-- 🧠 게임패스 소유 여부 확인
local function checkOwnership()
	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
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

-- 초기 로드
loadGamePassInfo(gamePassId)
checkOwnership()

-- ▶ 버튼 클릭 시 구매 프롬프트 열기
button.MouseButton1Click:Connect(function()
	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
	end)

	if success and hasPass then
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, gamePassId)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(userId, assetId, wasPurchased)
	if userId == player.UserId and assetId == gamePassId and wasPurchased then
		ownedFrame.Visible = true
		button.Visible = false
	end
end)

