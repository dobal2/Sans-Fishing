local shopFrame = script.Parent:WaitForChild("BoatFrame")
local shopShadowFrame = script.Parent:WaitForChild("ShadowFrame")
local clickSound = script:WaitForChild("click")
local buySound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("Buy SFX")
local errorSound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("error")
local lighting = game:GetService("Lighting")
local blur = lighting:WaitForChild("ShopBlur")
local TweenService = game:GetService("TweenService")
local xButton = shopFrame:WaitForChild("XButton")
local camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("OpenBoatShop")
local buyBoatRemote = game:GetService("ReplicatedStorage"):WaitForChild("BuyBoat")
local spawnBoatRemote = game:GetService("ReplicatedStorage"):WaitForChild("SpawnBoat")
local boatFrame = shopFrame:WaitForChild("ScrollingFrame"):WaitForChild("BoatFrame")
local boatFrameButton = boatFrame:WaitForChild("Button")
local optionFrame = script.Parent:WaitForChild("Options")
local notice = script.Parent:WaitForChild("notice")

-- 🔍 옵션 프레임 내부 요소들 찾기
local yesButton = optionFrame:WaitForChild("Yes")
local noButton = optionFrame:WaitForChild("No")
local optionPrice = optionFrame:WaitForChild("Price")

-- 🚤 BoatData 모듈 가져오기
local BoatData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("BoatDataModule"))

-- 🔧 설정 - FOV 고정
local originalFOV = 70  -- 🎯 항상 70으로 고정
local expandedFOV = 60
local canClick = true

-- 📦 현재 선택된 보트 저장 변수
local currentSelectedBoat = nil

-- 🚫 트윈 중복 방지 변수
local isNoticeTweening = false

-- 📍 스폰 위치 번호 저장 변수 (NEW!)
local assignedSpawnIndex = 1

-- 💰 숫자 포맷팅 함수 (콤마 추가)
local function formatNumber(num)
	local str = tostring(num)
	local result = ""
	local len = #str

	for i = 1, len do
		local char = str:sub(i, i)
		result = result .. char

		-- 뒤에서부터 3자리마다 콤마 추가 (마지막 자리가 아닐 때)
		local remainingDigits = len - i
		if remainingDigits > 0 and remainingDigits % 3 == 0 then
			result = result .. ","
		end
	end

	return result
end

-- 🔍 상점 열림 상태 확인 함수
local function isShopOpen()
	return shopFrame.Visible
end

-- 🎥 FOV 애니메이션 함수 개선
local function tweenFOV(targetFOV, duration)
	local tweenInfo = TweenInfo.new(
		duration or 0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	local tween = TweenService:Create(camera, tweenInfo, {
		FieldOfView = targetFOV
	})
	tween:Play()
	return tween
end

-- 🚫 돈 부족 알림 표시 함수
local function showInsufficientFundsNotice()
	if isNoticeTweening then
		return -- 이미 트윈 중이면 무시
	end

	isNoticeTweening = true
	errorSound:Play() -- 에러 사운드 재생
	notice.Visible = true

	-- 텍스트 투명도를 1로 설정 (완전 투명)
	notice.TextTransparency = 1

	-- 알림 표시 트윈 (텍스트 투명도만)
	local showTween = TweenService:Create(notice,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{TextTransparency = 0}
	)

	showTween:Play()
	showTween.Completed:Connect(function()
		-- 2초 후 자동으로 숨기기
		task.wait(2)

		local hideTween = TweenService:Create(notice,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{TextTransparency = 1}
		)

		hideTween:Play()
		hideTween.Completed:Connect(function()
			notice.Visible = false
			isNoticeTweening = false
		end)
	end)
end

-- 💰 가격 표시 업데이트 함수
local function updatePriceDisplay()
	local player = game.Players.LocalPlayer
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		warn("리더스탯이 없습니다")
		return
	end

	local boats = leaderstats:FindFirstChild("Boats")
	if not boats then
		warn("보트 폴더가 없습니다")
		return
	end

	-- Price 텍스트 찾기
	local priceText = boatFrame:FindFirstChild("Price")
	if not priceText then
		warn("Price 텍스트를 찾을 수 없습니다")
		return
	end

	-- BasicBoat 소유 여부 확인
	local basicBoat = boats:FindFirstChild("BasicBoat")
	local isOwned = basicBoat and basicBoat.Value

	if isOwned then
		priceText.Text = "Spawn"
		print("✅ 보트 소유 중 - 'Spawn' 표시")
	else
		local boatData = BoatData.Boats["BasicBoat"]
		if boatData then
			priceText.Text = "[¢ " .. formatNumber(boatData.price) .. "]"
			print("💰 보트 미소유 - 가격 표시:", boatData.price)
		else
			priceText.Text = "Error"
			warn("보트 데이터를 찾을 수 없습니다")
		end
	end
end

-- 🎯 옵션 프레임 가격 업데이트 함수
local function updateOptionPrice(boatName)
	local player = game.Players.LocalPlayer
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		warn("리더스탯이 없습니다")
		return
	end

	local boats = leaderstats:FindFirstChild("Boats")
	if not boats then
		warn("보트 폴더가 없습니다")
		return
	end

	-- 보트 소유 여부 확인
	local boatBool = boats:FindFirstChild(boatName)
	local isOwned = boatBool and boatBool.Value

	if isOwned then
		optionPrice.Text = "Spawn"
		print("✅ 옵션 프레임 - 보트 소유 중, 'Spawn' 표시")
	else
		local boatData = BoatData.Boats[boatName]
		if boatData then
			optionPrice.Text = "[¢ " .. formatNumber(boatData.price) .. "]"
			print("💰 옵션 프레임 - 보트 미소유, 가격 표시:", boatData.price)
		else
			optionPrice.Text = "Error"
			warn("보트 데이터를 찾을 수 없습니다")
		end
	end
end

-- 🔍 상점 상태에 맞게 UI 동기화 함수
local function syncShopState()
	if isShopOpen() then
		-- 상점이 열려있으면 관련 효과 활성화 (FOV는 건드리지 않음)
		shopShadowFrame.Visible = true
	else
		-- 상점이 닫혀있으면 관련 효과 비활성화 (FOV는 건드리지 않음)
		shopShadowFrame.Visible = false
	end
end

-- 🛍️ 상점 열기/닫기 통합 함수
local function toggleShop()
	if not canClick then return end
	canClick = false
	clickSound:Play()

	-- 현재 상태 확인 후 토글
	local currentlyOpen = isShopOpen()
	local newState = not currentlyOpen

	shopFrame.Visible = newState
	shopShadowFrame.Visible = newState

	local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	local robuxShop = playerGui:FindFirstChild("RobuxShop")
	local index = playerGui:FindFirstChild("Index")

	if newState then
		-- 🔓 상점 열림
		blur.Enabled = true
		tweenFOV(expandedFOV, 0.5)
		print("📷 상점 열림 - FOV:", expandedFOV)

		-- 🚫 다른 상점들 숨기기
		if robuxShop then
			local robuxShadowFrame = robuxShop:FindFirstChild("ShadowFrame")
			local robuxShopFrame = robuxShop:FindFirstChild("ShopFrame")
			if robuxShadowFrame then robuxShadowFrame.Visible = false end
			if robuxShopFrame then robuxShopFrame.Visible = false end
		end

		if index then
			local indexShadowFrame = index:FindFirstChild("ShadowFrame")
			local indexFrame = index:FindFirstChild("IndexFrame")
			if indexShadowFrame then indexShadowFrame.Visible = false end
			if indexFrame then indexFrame.Visible = false end
		end

		-- 🏷️ 상점 열릴 때 가격 표시 업데이트
		updatePriceDisplay()
	else
		-- 🔒 상점 닫힘
		blur.Enabled = false
		tweenFOV(originalFOV, 0.5)
		print("📷 상점 닫힘 - FOV 70으로 복구")

		-- 🚫 옵션 프레임도 함께 닫기
		optionFrame.Visible = false
	end

	-- 🔧 task.wait 사용 (더 안전)
	task.wait(0.5)
	canClick = true
end

-- 🎯 옵션 프레임 표시 함수
local function showOptionFrame(boatName)
	currentSelectedBoat = boatName
	updateOptionPrice(boatName)
	optionFrame.Visible = true
	print("🎯 옵션 프레임 표시:", boatName)
end

-- 🚫 옵션 프레임 숨기기 함수
local function hideOptionFrame()
	optionFrame.Visible = false
	currentSelectedBoat = nil
	print("🚫 옵션 프레임 숨기기")
end

-- 🚤 보트 구매/스폰 함수 (수정됨)
local function buyOrSpawnBoat(boatName)
	local boatData = BoatData.Boats[boatName]
	if not boatData then
		warn("존재하지 않는 보트:", boatName)
		return
	end

	local player = game.Players.LocalPlayer
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("리더스탯이 없습니다")
		return
	end

	local boats = leaderstats:FindFirstChild("Boats")
	local coins = leaderstats:FindFirstChild("Coins")

	if not boats or not coins then
		warn("보트 또는 코인 정보가 없습니다")
		return
	end

	-- 🔍 소유 여부 확인
	local boatBool = boats:FindFirstChild(boatName)
	local isOwned = boatBool and boatBool.Value

	if isOwned then
		-- 🚤 이미 소유한 보트 → 스폰 요청 (스폰 위치 번호 포함)
		print("🚤 보트 스폰 요청:", boatName, "위치:", assignedSpawnIndex)
		spawnBoatRemote:FireServer(boatName, assignedSpawnIndex)
		hideOptionFrame() -- 옵션 프레임 숨기기
		toggleShop() -- 상점 닫기
	else
		-- 💰 미소유 보트 → 구매 요청
		if coins.Value < boatData.price then
			warn("잔액이 부족합니다. 필요 금액:", boatData.price, "보유 금액:", coins.Value)
			showInsufficientFundsNotice() -- 돈 부족 알림 표시
			return
		end

		print("🚤 보트 구매 요청:", boatName, "가격:", boatData.price)
		buySound:Play() -- 구매 사운드 재생
		buyBoatRemote:FireServer(boatName)
		hideOptionFrame() -- 옵션 프레임 숨기기
	end
end

-- 🚤 보트 프레임 클릭 이벤트 연결 (수정됨)
boatFrameButton.MouseButton1Click:Connect(function()
	print("🚤 보트 프레임 클릭됨!")

	local player = game.Players.LocalPlayer
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		warn("리더스탯이 없습니다")
		return
	end

	local boats = leaderstats:FindFirstChild("Boats")
	if not boats then
		warn("보트 폴더가 없습니다")
		return
	end

	-- BasicBoat 소유 여부 확인
	local basicBoat = boats:FindFirstChild("BasicBoat")
	local isOwned = basicBoat and basicBoat.Value

	if isOwned then
		-- 🚤 이미 소유한 보트 → 바로 스폰 (스폰 위치 번호 포함)
		print("🚤 보트 스폰 요청:", "BasicBoat", "위치:", assignedSpawnIndex)
		spawnBoatRemote:FireServer("BasicBoat", assignedSpawnIndex)
		toggleShop() -- 상점 닫기
	else
		-- 💰 미소유 보트 → 옵션 프레임 표시
		print("💰 미소유 보트 - 옵션 프레임 표시")
		showOptionFrame("BasicBoat")
	end
end)

-- ✅ Yes 버튼 클릭 이벤트
yesButton:WaitForChild("Button").MouseButton1Click:Connect(function()
	print("✅ Yes 버튼 클릭됨!")
	if currentSelectedBoat then
		buyOrSpawnBoat(currentSelectedBoat)
	end
end)

-- ❌ No 버튼 클릭 이벤트
noButton:WaitForChild("Button").MouseButton1Click:Connect(function()
	print("❌ No 버튼 클릭됨!")
	hideOptionFrame()
end)

-- 🔄 서버에서 구매 완료 응답 받았을 때 가격 표시 업데이트
buyBoatRemote.OnClientEvent:Connect(function(success, boatName)
	if success then
		print("✅ 보트 구매 완료:", boatName)
		-- 가격 표시 업데이트
		updatePriceDisplay()
	else
		warn("❌ 보트 구매 실패:", boatName)
	end
end)

-- 🎮 leaderstats 변화 감지 (다른 방법으로 보트를 얻었을 때도 업데이트)
local player = game.Players.LocalPlayer
player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		-- leaderstats가 생성되면 Boats 폴더 변화 감지
		local boats = child:WaitForChild("Boats")
		boats.ChildAdded:Connect(updatePriceDisplay)
		boats.ChildRemoved:Connect(updatePriceDisplay)

		-- 기존 보트들의 Value 변화도 감지
		for _, boat in pairs(boats:GetChildren()) do
			if boat:IsA("BoolValue") then
				boat.Changed:Connect(updatePriceDisplay)
			end
		end
	end
end)

-- 🔧 이미 leaderstats가 있는 경우 처리
if player:FindFirstChild("leaderstats") then
	local boats = player.leaderstats:FindFirstChild("Boats")
	if boats then
		boats.ChildAdded:Connect(updatePriceDisplay)
		boats.ChildRemoved:Connect(updatePriceDisplay)

		for _, boat in pairs(boats:GetChildren()) do
			if boat:IsA("BoolValue") then
				boat.Changed:Connect(updatePriceDisplay)
			end
		end
	end
end

-- 👁️ shopFrame.Visible 변화 감지 (다른 스크립트에서 변경시 대응)
shopFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	print("🔍 상점 Visible 변화 감지:", shopFrame.Visible)
	syncShopState()
end)

xButton.MouseButton1Click:Connect(function()
	-- X버튼은 항상 닫기만
	if isShopOpen() then
		toggleShop()
	end
end)

-- 🚤 NPC 트리거에서 스폰 위치 번호 받기 (수정됨)
remote.OnClientEvent:Connect(function(spawnIndex)
	-- 📍 NPC에서 전달받은 스폰 위치 번호 저장
	if spawnIndex then
		assignedSpawnIndex = spawnIndex
		print("📍 스폰 위치 할당됨:", assignedSpawnIndex)
	end
	toggleShop()
end)

-- 🔧 초기 상태 설정
shopFrame.Visible = false
shopShadowFrame.Visible = false
optionFrame.Visible = false  -- 옵션 프레임도 초기에 숨김
notice.Visible = false  -- notice도 초기에 숨김
notice.TextTransparency = 1  -- notice 텍스트도 초기에 투명하게
blur.Enabled = false
print("✅ 보트 상점 UI 초기화 완료 - 스폰 위치 시스템 적용")