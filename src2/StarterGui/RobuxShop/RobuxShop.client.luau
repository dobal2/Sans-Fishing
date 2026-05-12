-- 🛍️ 개선된 상점 UI 스크립트
local shopButton = script.Parent:WaitForChild("Frame"):WaitForChild("ShopButton")
local shopFrame = script.Parent:WaitForChild("ShopFrame")
local shopShadowFrame = script.Parent:WaitForChild("ShadowFrame")
local clickSound = script:WaitForChild("click")
local lighting = game:GetService("Lighting")
local blur = lighting:WaitForChild("ShopBlur")
local TweenService = game:GetService("TweenService")
local xButton = shopFrame:WaitForChild("XButton")
local camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("OpenRobuxShop")

-- 🔧 설정 - FOV 고정
local originalFOV = 70  -- 🎯 항상 70으로 고정
local expandedFOV = 60
local canClick = true

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

-- 🔍 상점 열림 상태 확인 함수
local function isShopOpen()
	return shopFrame.Visible
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
	local boatShop = playerGui:FindFirstChild("BoatShop")
	local index = playerGui:FindFirstChild("Index")

	if newState then
		-- 🔓 상점 열림
		blur.Enabled = true
		tweenFOV(expandedFOV, 0.5)
		print("📷 상점 열림 - FOV:", expandedFOV)

		-- 🚫 다른 상점들 숨기기
		if boatShop then
			local boatShadowFrame = boatShop:FindFirstChild("ShadowFrame")
			local boatShopFrame = boatShop:FindFirstChild("BoatFrame")
			if boatShadowFrame then boatShadowFrame.Visible = false end
			if boatShopFrame then boatShopFrame.Visible = false end
		end

		if index then
			local indexShadowFrame = index:FindFirstChild("ShadowFrame")
			local indexFrame = index:FindFirstChild("IndexFrame")
			if indexShadowFrame then indexShadowFrame.Visible = false end
			if indexFrame then indexFrame.Visible = false end
		end
	else
		-- 🔒 상점 닫힘
		blur.Enabled = false
		tweenFOV(originalFOV, 0.5)
		print("📷 상점 닫힘 - FOV 70으로 복구")
	end

	-- 🔧 task.wait 사용 (더 안전)
	task.wait(0.5)
	canClick = true
end

-- 🔍 상점 상태에 맞게 UI 동기화 함수
local function syncShopState()
	if isShopOpen() then
		-- 상점이 열려있으면 관련 효과 활성화 (FOV는 건드리지 않음)
		--blur.Enabled = true
		shopShadowFrame.Visible = true
		print("🔄 상점 동기화 - 열림 상태로 설정 (FOV 제외)")
	else
		-- 상점이 닫혀있으면 관련 효과 비활성화 (FOV는 건드리지 않음)
		--blur.Enabled = false
		shopShadowFrame.Visible = false
		print("🔄 상점 동기화 - 닫힘 상태로 설정 (FOV 제외)")
	end
end

-- 🔘 버튼 이벤트 연결
shopButton.MouseButton1Click:Connect(toggleShop)
xButton.MouseButton1Click:Connect(function()
	-- X버튼은 항상 닫기만
	if isShopOpen() then
		toggleShop()
	end
end)

-- ⌨️ ESC 키로 상점 닫기
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isShopOpen() then
		toggleShop()
	end
end)

-- 👁️ shopFrame.Visible 변화 감지 (다른 스크립트에서 변경시 대응)
shopFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	print("🔍 상점 Visible 변화 감지:", shopFrame.Visible)
	syncShopState()
end)

remote.OnClientEvent:Connect(function()
	toggleShop()
end)

-- 🔧 초기 상태 설정
shopFrame.Visible = false
shopShadowFrame.Visible = false
blur.Enabled = false
print("✅ 상점 UI 초기화 완료 - FOV 고정값 70 사용")