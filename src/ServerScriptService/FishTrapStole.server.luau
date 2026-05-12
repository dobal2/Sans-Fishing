-- 전역 FishTrap 구매 처리 스크립트 (ServerScriptService에 위치)
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- 💰 Developer Product 설정
local FISH_TRAP_HARVEST_PRODUCT_ID = 3381869322

print("🌐 전역 FishTrap 구매 시스템 시작")

-- 전역 구매 데이터 저장소
local purchaseStorage = ReplicatedStorage:FindFirstChild("FishTrapPurchases")
if not purchaseStorage then
	purchaseStorage = Instance.new("Folder")
	purchaseStorage.Name = "FishTrapPurchases"
	purchaseStorage.Parent = ReplicatedStorage
	print("📁 FishTrapPurchases 폴더 생성")
end

-- 전역 구매 처리 설정 (한 번만 실행)
MarketplaceService.ProcessReceipt = function(receiptInfo)
	if receiptInfo.ProductId == FISH_TRAP_HARVEST_PRODUCT_ID then
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			print("❌ 플레이어 없음:", receiptInfo.PlayerId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		print("💰 전역 구매 처리:", player.Name, "구매 ID:", receiptInfo.PurchaseId)

		-- 구매 정보를 찾아서 처리
		for _, purchaseData in pairs(purchaseStorage:GetChildren()) do
			if purchaseData:IsA("ObjectValue") and purchaseData.Value == player then
				local trapIdValue = purchaseData:FindFirstChild("TrapId")
				local fishDataValue = purchaseData:FindFirstChild("FishData")

				if trapIdValue and fishDataValue then
					print("✅ 구매 정보 발견:", player.Name, "통발:", trapIdValue.Value)

					-- 해당 통발에 구매 완료 신호 보내기
					local completeSignal = Instance.new("StringValue")
					completeSignal.Name = "PurchaseComplete_" .. trapIdValue.Value
					completeSignal.Value = player.Name
					completeSignal.Parent = ReplicatedStorage

					-- 신호 제거 (3초 후)
					game:GetService("Debris"):AddItem(completeSignal, 3)

					-- 구매 데이터 제거
					purchaseData:Destroy()

					print("📡 구매 완료 신호 발송:", player.Name, "→", trapIdValue.Value)
					return Enum.ProductPurchaseDecision.PurchaseGranted
				end
			end
		end

		print("❌ 구매 정보 없음:", player.Name)
		return Enum.ProductPurchaseDecision.PurchaseGranted -- 환불 방지
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

print("✅ 전역 FishTrap 구매 처리 시스템 초기화 완료!")

-- 디버깅: 구매 데이터 모니터링
purchaseStorage.ChildAdded:Connect(function(child)
	print("📝 새 구매 데이터 추가:", child.Name)
end)

purchaseStorage.ChildRemoved:Connect(function(child)
	print("🗑️ 구매 데이터 제거:", child.Name)
end)
