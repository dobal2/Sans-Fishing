-- 🚤 보트 구매 서버 코드
local remote = game:GetService("ReplicatedStorage"):WaitForChild("BuyBoat")
local BoatData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("BoatDataModule"))

remote.OnServerEvent:Connect(function(plr, boatName)
	local boat = BoatData.Boats[boatName]
	if not boat then
		warn("허용되지 않은 보트 구매 시도: " .. tostring(boatName))
		plr:Kick("ClientHacker - Invalid boat purchase attempt")
		return
	end

	-- 🔍 리더스탯 확인
	local leaderstats = plr:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("리더스탯 없음 - 플레이어:", plr.Name)
		return
	end

	local coins = leaderstats:FindFirstChild("Coins")
	local boatsFolder = leaderstats:FindFirstChild("Boats")

	if not (coins and boatsFolder) then
		warn("필수 leaderstats 요소 없음 - 플레이어:", plr.Name)
		return
	end

	-- 🔍 이미 소유 여부 확인
	local boatBool = boatsFolder:FindFirstChild(boat.storageName)
	local alreadyOwned = boatBool and boatBool.Value

	-- 🛒 구매 처리 (소유하지 않은 경우에만)
	if not alreadyOwned then
		-- 💰 잔액 확인
		if coins.Value < boat.price then
			warn("잔액 부족 - 플레이어:", plr.Name, "필요:", boat.price, "보유:", coins.Value)
			plr:Kick("ClientHacker - Insufficient funds")
			return
		end

		-- 💳 결제 처리
		coins.Value -= boat.price
		print("💰 결제 완료 - 플레이어:", plr.Name, "보트:", boatName, "가격:", boat.price)

		-- 🏷️ 소유권 등록
		if boatBool then
			boatBool.Value = true
		end

		-- 🚤 기본 보트 비활성화 (필요한 경우)
		local defaultBoat = boatsFolder:FindFirstChild("DefaultBoat")
		if defaultBoat then
			defaultBoat.Value = false
		end
	else
		print("🔄 이미 소유한 보트 장착 - 플레이어:", plr.Name, "보트:", boatName)
	end

	-- 🚤 보트 소유권만 설정 (Tool 아님)
	-- 다른 보트들 비활성화
	for _, otherBoat in pairs(boatsFolder:GetChildren()) do
		if otherBoat:IsA("BoolValue") and otherBoat.Name ~= boat.storageName then
			otherBoat.Value = false
		end
	end

	-- 선택한 보트 활성화
	if boatBool then
		boatBool.Value = true
	end

	print("✅ 보트 구매/장착 완료 - 플레이어:", plr.Name, "보트:", boatName)
end)
