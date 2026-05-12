-- 🛍️ 개선된 상점 UI 스크립트

local shopButton = script.Parent:WaitForChild("Free Reward")
local shopFrame = script.Parent:WaitForChild("Free Reward Frame")
local shopShadowFrame = script.Parent:WaitForChild("ShadowFrame")
local clickSound = script:WaitForChild("click")
local lighting = game:GetService("Lighting")
local blur = lighting:WaitForChild("ShopBlur")
local TweenService = game:GetService("TweenService")
local xButton = shopFrame:WaitForChild("XButton")
local camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- 🔧 설정
local originalFOV = camera.FieldOfView or 70
local expandedFOV = 60
local canClick = true
local isShopOpen = false

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

-- 🛍️ 상점 열기/닫기 통합 함수
local function toggleShop()
	if not canClick then return end

	canClick = false
	clickSound:Play()

	-- 상태 토글
	isShopOpen = not isShopOpen
	shopFrame.Visible = isShopOpen
	shopShadowFrame.Visible = isShopOpen

	if isShopOpen then
		-- 🔓 상점 열림
		blur.Enabled = true
		tweenFOV(expandedFOV, 0.5)
		print("📷 상점 열림 - FOV:", expandedFOV)
	else
		-- 🔒 상점 닫힘
		blur.Enabled = false
		tweenFOV(originalFOV, 0.5)
		print("📷 상점 닫힘 - FOV:", originalFOV)
	end

	-- 🔧 task.wait 사용 (더 안전)
	task.wait(0.5)
	canClick = true
end

-- 🔘 버튼 이벤트 연결
shopButton.MouseButton1Click:Connect(toggleShop)
xButton.MouseButton1Click:Connect(function()
	-- X버튼은 항상 닫기만
	if isShopOpen then
		toggleShop()
	end
end)

-- ⌨️ ESC 키로 상점 닫기
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Escape and isShopOpen then
		toggleShop()
	end
end)

-- 📷 FOV 관리 개선
local function updateOriginalFOV()
	-- 상점이 닫혀있을 때만 원본 FOV 업데이트
	if not isShopOpen then
		originalFOV = camera.FieldOfView
		print("📷 원본 FOV 업데이트:", originalFOV)
	end
end

-- 🎮 캐릭터 스폰시 FOV 저장
game.Players.LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1) -- 캐릭터 로딩 대기
	updateOriginalFOV()
end)

-- 🔧 카메라 변경 감지 (플레이어가 설정에서 FOV를 바꿨을 때)
local lastFOV = camera.FieldOfView
RunService.Heartbeat:Connect(function()
	if not isShopOpen and camera.FieldOfView ~= lastFOV then
		lastFOV = camera.FieldOfView
		originalFOV = camera.FieldOfView
	end
end)

-- 🚪 게임 종료시 정리
game.Players.LocalPlayer.AncestryChanged:Connect(function()
	if isShopOpen then
		-- 강제로 상점 닫기
		blur.Enabled = false
		camera.FieldOfView = originalFOV
	end
end)


-- 🔧 초기 상태 설정
shopFrame.Visible = false
shopShadowFrame.Visible = false
isShopOpen = false
blur.Enabled = false
print("✅ 상점 UI 초기화 완료")