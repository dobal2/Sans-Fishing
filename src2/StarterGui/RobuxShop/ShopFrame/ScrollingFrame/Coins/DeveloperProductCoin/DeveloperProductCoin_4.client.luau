local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- UI 요소들
local image = script.Parent:WaitForChild("ImageLabel")
local button = script.Parent:WaitForChild("RobuxButton")

-- 🛍️ 개발자 제품 ID 설정
local developerProductId = 3345109745

-- RemoteEvent 연결
--local purchaseEvent = ReplicatedStorage:WaitForChild("PurchaseCompleted")
local successSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Success")

-- 🔄 개발자 제품 정보 가져오기 함수
local function loadProductInfo(productId)
	local success, productInfo = pcall(function()
		return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	end)

	if success and productInfo then
		print("Product info loaded:", productInfo.Name)
		image.Image = "rbxassetid://" .. (productInfo.IconImageAssetId or "0")
		return productInfo
	else
		warn("Failed to load developer product info:", productInfo)
		image.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
		return nil
	end
end

-- 초기 로드
loadProductInfo(developerProductId)

-- ▶ 버튼 클릭 시 구매 프롬프트 열기
button.MouseButton1Click:Connect(function()
	print("Buy button clicked")
	MarketplaceService:PromptProductPurchase(player, developerProductId)
end)

---- 🎉 구매 완료 처리
--MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
--	if userId == player.UserId and productId == developerProductId then
--		if wasPurchased then
--			successSound:Play()

--			-- 서버에 구매 완료 알림
--			purchaseEvent:FireServer(productId)

--		end
--	end
--end)

print("Developer product client loaded. ID:", developerProductId)
