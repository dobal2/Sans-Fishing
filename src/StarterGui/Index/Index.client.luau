-- 🛍️ 개선된 상점 UI 스크립트
local indexButton = script.Parent:WaitForChild("Frame"):WaitForChild("IndexButton")
local indexFrame = script.Parent:WaitForChild("IndexFrame")
local indexShadowFrame = script.Parent:WaitForChild("ShadowFrame")
local clickSound = script:WaitForChild("click")
local lighting = game:GetService("Lighting")
local blur = lighting:WaitForChild("ShopBlur")
local TweenService = game:GetService("TweenService")
local xButton = indexFrame:WaitForChild("XButton")
local camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local scrollFrame = indexFrame:WaitForChild("ScrollingFrame")
local indexUnit = script:WaitForChild("IndexUnit")
local Players = game:GetService("Players")

-- 🐟 물고기 관련 설정
local player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local fishesFolder = ReplicatedStorage:WaitForChild("Fishes")

-- 🐟 물고기 데이터 (직접 정의)
local FishRarities = {
	{
		name = "Common",
		chance = 44.4,
		fishes = {
			{ fishName = "Small Carp", value = 80, minWeight = 0.8, maxWeight = 100.0 },
			{ fishName = "Gold Fish", value = 100, minWeight = 0.8, maxWeight = 100.0 },
			{ fishName = "Stone Fish", value = 400, minWeight = 0.8, maxWeight = 100.0 }
		}
	},
	{
		name = "Uncommon",
		chance = 25,
		fishes = {
			{ fishName = "Crab", value = 160, minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Crystal Bass", value = 160, minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Dust Fish", value = 680, minWeight = 1.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Rare",
		chance = 17,
		fishes = {
			{ fishName = "Bass", value = 400, minWeight = 2.0, maxWeight = 100.0 },
			{ fishName = "Snow Fish", value = 400, minWeight = 2.0, maxWeight = 100.0 },
			{ fishName = "Diri", value = 680, minWeight = 1.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Epic",
		chance = 7,
		fishes = {
			{ fishName = "Dragon Head Fish", value = 700, minWeight = 3.5, maxWeight = 100.0 },
			{ fishName = "Reggigash", value = 680, minWeight = 1.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Legendary",
		chance = 4,
		fishes = {
			{ fishName = "Golden Trout", value = 1800, minWeight = 3.0, maxWeight = 100.0 },
			{ fishName = "Armor Fish", value = 2500, minWeight = 3.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Mystic",
		chance = 2,
		fishes = {
			{ fishName = "Shark", value = 4500, minWeight = 5.0, maxWeight = 100.0 },
			{ fishName = "Ray", value = 4200, minWeight = 5.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Fantasy",
		chance = 0.5,
		fishes = {
			{ fishName = "Undyine", value = 9000, minWeight = 3.0, maxWeight = 100.0 },
			{ fishName = "Sans", value = 11111, minWeight = 3.0, maxWeight = 100.0 },
			{ fishName = "Electric Fish", value = 13333, minWeight = 3.0, maxWeight = 100.0 }
		}
	},
	{
		name = "Unknown",
		chance = 0.1,
		fishes = {
			{ fishName = "Unknown", value = 50000, minWeight = 1.0, maxWeight = 100.0 },
			{ fishName = "Nyan Cat", value = 56000, minWeight = 1.0, maxWeight = 100.0 }
		}
	}
}

-- 🎨 등급별 테두리 색깔 (요청한 색상으로 변경)
local rarityColors = {
	Common = Color3.fromRGB(255, 255, 255),      -- 하양
	Uncommon = Color3.fromRGB(12, 255, 32),        -- 초록
	Rare = Color3.fromRGB(5, 188, 255),            -- 파랑
	Epic = Color3.fromRGB(162, 12, 255),          -- 보라
	Legendary = Color3.fromRGB(255, 0, 221),    -- 핑크
	Mystic = Color3.fromRGB(255, 217, 2),        -- 노랑
	Fantasy = Color3.fromRGB(64, 224, 208),      -- 민트
	Unknown = Color3.fromRGB(0, 0, 0)            -- 검정
}

-- 🔧 설정 - FOV 고정
local originalFOV = 70  -- 🎯 항상 70으로 고정
local expandedFOV = 60
local canClick = true

-- 🔍 인덱스 열림 상태 확인 함수
local function isIndexOpen()
	return indexFrame.Visible
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

-- 🎨 호버 효과 함수들 (카메라 줌만, 아무 투명도 변경 없음)
local function createHoverEffect(fishUnit, isDiscovered, viewportFrame)
	if not viewportFrame or not viewportFrame.CurrentCamera or not isDiscovered then return end

	local vpCamera = viewportFrame.CurrentCamera
	local originalCFrame = vpCamera.CFrame

	-- 🔧 확대 효과: 살짝만 가까이
	local originalPosition = originalCFrame.Position
	local targetPosition = Vector3.new(0, 0, 0)
	local direction = (targetPosition - originalPosition).Unit
	local zoomedPosition = originalPosition + direction * 1.0 -- 1.0 스터드만 가까이
	local zoomedCFrame = CFrame.lookAt(zoomedPosition, targetPosition)

	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	fishUnit.MouseEnter:Connect(function()
		-- 🔍 카메라 줌인만
		local zoomTween = TweenService:Create(vpCamera, tweenInfo, {CFrame = zoomedCFrame})
		zoomTween:Play()
	end)

	fishUnit.MouseLeave:Connect(function()
		-- 🔍 카메라 줌아웃
		local zoomTween = TweenService:Create(vpCamera, tweenInfo, {CFrame = originalCFrame})
		zoomTween:Play()
	end)
end

-- 🎯 모델 크기 표준화 및 위치 설정 함수 (회전 없음)
local function setupModelInViewport(handle, targetSize, fishName)
	if not handle or not handle:IsA("BasePart") then return end

	-- 1. Handle을 원점(0,0,0)으로 이동 (회전은 원본 유지)
	local originalRotation = handle.CFrame.Rotation
	handle.CFrame = CFrame.new(0, 0, 0) * originalRotation

	-- 2. Handle 크기 확인
	local currentSize = handle.Size
	local maxDimension = math.max(currentSize.X, currentSize.Y, currentSize.Z)

	-- 3. 스케일 계산 (목표 크기에 맞춤)
	local scale = targetSize / maxDimension

	-- 4. Handle 크기 조정
	handle.Size = handle.Size * scale

	-- 5. SpecialMesh가 있다면 스케일 조정
	local mesh = handle:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		mesh.Scale = mesh.Scale * scale
	end

	print("🎯 Handle 설정 완료:", fishName, "스케일:", scale, "회전 보존")
end

-- ❓ 발견되지 않은 물고기용 물음표 생성 함수
local function createQuestionMark(viewportFrame)
	-- 기존 물음표 제거
	local existingQuestion = viewportFrame:FindFirstChild("QuestionMark")
	if existingQuestion then
		existingQuestion:Destroy()
	end

	-- 물음표 텍스트라벨 생성
	local questionMark = Instance.new("TextLabel")
	questionMark.Name = "QuestionMark"
	questionMark.Size = UDim2.new(1, 0, 1, 0)
	questionMark.Position = UDim2.new(0, 0, 0, 0)
	questionMark.BackgroundTransparency = 1
	questionMark.Text = "?"
	questionMark.TextColor3 = Color3.new(0.5, 0.5, 0.5) -- 회색
	questionMark.TextScaled = true
	questionMark.Font = Enum.Font.SourceSansBold
	questionMark.Parent = viewportFrame

	print("❓ 물음표 생성 완료")
end

-- 🐟 물고기 도감 UI 생성 함수 (등급별 정렬)
local function createFishIndexUI()
	-- 기존 UI 정리
	for _, child in pairs(scrollFrame:GetChildren()) do
		if child:IsA("GuiObject") and not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	-- 플레이어 Fish 폴더 확인
	local leaderstats = player:WaitForChild("leaderstats")
	local fishFolder = leaderstats:WaitForChild("Fish")

	-- 🔍 Fishes 폴더 내용 확인 (Bass와 Golden Trout 특별 확인)
	print("🐟 === Fishes 폴더 내용 확인 ===")
	for _, model in pairs(fishesFolder:GetChildren()) do
		print("- 모델:", model.Name)
		if model.Name == "Bass" or model.Name == "Golden Trout" then
			print("  특별 확인:", model.Name, "클래스:", model.ClassName)
		end
	end
	print("================================")

	-- 🎯 등급별로 물고기 정렬해서 생성
	local layoutOrder = 1

	for rarityIndex, rarityData in ipairs(FishRarities) do
		print("🎣 등급 처리:", rarityData.name, "물고기 수:", #rarityData.fishes)

		for fishIndex, fishData in ipairs(rarityData.fishes) do
			local fishName = fishData.fishName
			print("🎣 처리 중인 물고기:", fishName, "등급:", rarityData.name)

			local fishUnit = indexUnit:Clone()
			fishUnit.Name = fishName
			fishUnit.LayoutOrder = layoutOrder -- 등급 순서대로 정렬
			fishUnit.Parent = scrollFrame

			-- 🎨 등급별 테두리 색깔 적용 (UIStroke만 추가, 다른 색상/투명도 변경 없음)
			local rarityColor = rarityColors[rarityData.name] or Color3.fromRGB(255, 255, 255)

			-- 물고기 발견 여부 확인
			local fishBool = fishFolder:FindFirstChild(fishName)
			local isDiscovered = fishBool and fishBool.Value or false

			print("🔍 물고기 확인:", fishName, "Fish폴더 존재:", fishBool and "있음" or "없음", "발견됨:", isDiscovered)

			-- 🎨 UIStroke만 추가 (기존 UI 색상/투명도는 건드리지 않음)
			local existingStroke = fishUnit:FindFirstChild("UIStroke")
			if existingStroke then existingStroke:Destroy() end

			local uiStroke = Instance.new("UIStroke")
			uiStroke.Color = rarityColor
			uiStroke.Thickness = 2

			if isDiscovered then
				-- 발견된 물고기: 선명한 테두리
				uiStroke.Transparency = 0
			else
				-- 발견되지 않은 물고기: 흐릿한 테두리
				uiStroke.Transparency = 0.7
			end

			uiStroke.Parent = fishUnit

			-- ViewportFrame 찾기
			local viewportFrame = fishUnit:FindFirstChild("ViewportFrame")
			if viewportFrame then
				-- 기존 Handle 제거
				local existingHandle = viewportFrame:FindFirstChild("Handle")
				if existingHandle then
					existingHandle:Destroy()
				end

				-- 물고기가 발견되었다면 실제 모델 표시
				if isDiscovered then
					local fishModel = fishesFolder:FindFirstChild(fishName)
					print("🔍 물고기 모델 찾기:", fishName, "모델 존재:", fishModel and "있음" or "없음")

					-- Bass와 Golden Trout 특별 확인
					if fishName == "Bass" or fishName == "Golden Trout" then
						print("🐟 === " .. fishName .. " 특별 디버그 ===")
						print("모델 경로:", fishesFolder)
						for _, child in pairs(fishesFolder:GetChildren()) do
							if string.find(child.Name:lower(), string.lower(fishName)) or
								child.Name == fishName or
								(fishName == "Bass" and string.find(child.Name:lower(), "bass")) or
								(fishName == "Golden Trout" and (string.find(child.Name:lower(), "golden") or string.find(child.Name:lower(), "trout"))) then
								print("매칭된 모델:", child.Name)
							end
						end
						print("============================")
					end

					if fishModel then
						local handle = fishModel:FindFirstChild("Handle")
						print("🔍 Handle 찾기:", fishName, "Handle 존재:", handle and "있음" or "없음")
						if handle then
							local clonedHandle = handle:Clone()
							clonedHandle.Parent = viewportFrame

							-- 🎯 모델 설정 (크기, 위치, 회전) - 확대된 크기가 기본
							setupModelInViewport(clonedHandle, 4, fishName) -- 기본 크기를 4로 증가

							-- 🎨 원본 재질 복원 (직접 처리)
							if clonedHandle.Material == Enum.Material.Neon then
								clonedHandle.Material = Enum.Material.Plastic
							end
							if clonedHandle.Transparency > 0 then
								clonedHandle.Transparency = 0
							end

							-- ViewportFrame 카메라 설정
							local vpCamera = Instance.new("Camera")
							vpCamera.Parent = viewportFrame
							viewportFrame.CurrentCamera = vpCamera

							-- 🔧 개선된 카메라 위치: 더 자연스러운 각도
							local distance = 6 -- 거리
							local height = 3 -- 높이
							local angle = math.rad(45) -- 45도 각도로 회전

							-- 카메라 위치 계산 (대각선에서 바라보기)
							local cameraPosition = Vector3.new(
								distance * math.cos(angle),
								height,
								distance * math.sin(angle)
							)
							local targetPosition = Vector3.new(0, 0, 0)

							-- 카메라가 중앙을 바라보도록 설정
							vpCamera.CFrame = CFrame.lookAt(cameraPosition, targetPosition)

							-- 🎨 호버 효과 추가 (카메라 줌)
							createHoverEffect(fishUnit, isDiscovered, viewportFrame)
						end
					end
				else
					-- ❓ 발견되지 않은 물고기는 물음표로 표시 (모델 없음)
					createQuestionMark(viewportFrame)
				end
			end

			-- 🐟 IndexUnit의 Name 텍스트라벨 사용 (발견 상태에 따라 다르게)
			local nameLabel = fishUnit:FindFirstChild("Name")
			if nameLabel then
				if isDiscovered then
					nameLabel.Text = fishName
					nameLabel.TextColor3 = Color3.new(1, 1, 1) -- 발견된 물고기: 하양색
					nameLabel.TextTransparency = 0
				else
					nameLabel.Text = "???"
					nameLabel.TextColor3 = Color3.new(0.5, 0.5, 0.5) -- 미발견 물고기: 회색
					nameLabel.TextTransparency = 0.3
				end
			end

			layoutOrder = layoutOrder + 1
		end
	end

	print("🐟 물고기 도감 UI 업데이트 완료! (등급별 정렬)")
end

-- 🛍️ 인덱스 열기/닫기 통합 함수
local function toggleIndex()
	if not canClick then return end
	canClick = false
	clickSound:Play()

	-- 현재 상태 확인 후 토글
	local currentlyOpen = isIndexOpen()
	local newState = not currentlyOpen

	indexFrame.Visible = newState
	indexShadowFrame.Visible = newState

	local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	local boatShop = playerGui:FindFirstChild("BoatShop")
	local robuxShop = playerGui:FindFirstChild("RobuxShop")

	if newState then
		-- 🔓 인덱스 열림
		blur.Enabled = true
		tweenFOV(expandedFOV, 0.5)
		print("📷 인덱스 열림 - FOV:", expandedFOV)

		-- 🚫 다른 상점들 숨기기
		if boatShop then
			local boatShadowFrame = boatShop:FindFirstChild("ShadowFrame")
			local boatShopFrame = boatShop:FindFirstChild("BoatFrame")
			if boatShadowFrame then boatShadowFrame.Visible = false end
			if boatShopFrame then boatShopFrame.Visible = false end
		end

		if robuxShop then
			local robuxShadowFrame = robuxShop:FindFirstChild("ShadowFrame")
			local robuxShopFrame = robuxShop:FindFirstChild("ShopFrame")
			if robuxShadowFrame then robuxShadowFrame.Visible = false end
			if robuxShopFrame then robuxShopFrame.Visible = false end
		end

		-- 🐟 물고기 도감 UI 생성/업데이트
		createFishIndexUI()
	else
		-- 🔒 인덱스 닫힘
		blur.Enabled = false
		tweenFOV(originalFOV, 0.5)
		print("📷 인덱스 닫힘 - FOV 70으로 복구")
	end

	-- 🔧 task.wait 사용 (더 안전)
	task.wait(0.5)
	canClick = true
end

-- 🔍 인덱스 상태에 맞게 UI 동기화 함수
local function syncIndexState()
	if isIndexOpen() then
		-- 인덱스가 열려있으면 관련 효과 활성화 (FOV는 건드리지 않음)
		--blur.Enabled = true
		indexShadowFrame.Visible = true
		-- 도감 UI 업데이트
		createFishIndexUI()
		--print("🔄 인덱스 동기화 - 열림 상태로 설정 (FOV 제외)")
	else
		-- 인덱스가 닫혀있으면 관련 효과 비활성화 (FOV는 건드리지 않음)
		--blur.Enabled = false
		indexShadowFrame.Visible = false
		--print("🔄 인덱스 동기화 - 닫힘 상태로 설정 (FOV 제외)")
	end
end

-- 🔘 버튼 이벤트 연결
indexButton.MouseButton1Click:Connect(toggleIndex)
xButton.MouseButton1Click:Connect(function()
	if isIndexOpen() then
		toggleIndex()
	end
end)

-- ⌨️ ESC 키로 인덱스 닫기
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isIndexOpen() then
		toggleIndex()
	end
end)

-- 👁️ indexFrame.Visible 변화 감지 (다른 스크립트에서 변경시 대응)
indexFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	print("🔍 인덱스 Visible 변화 감지:", indexFrame.Visible)
	syncIndexState()
end)

-- 🔄 물고기 데이터 변경 감지 (실시간 업데이트)
local function setupFishDataListener()
	local leaderstats = player:WaitForChild("leaderstats")
	local fishFolder = leaderstats:WaitForChild("Fish")

	-- FishRarities에서 모든 물고기 이름 가져와서 감지
	for _, rarityData in ipairs(FishRarities) do
		for _, fishData in ipairs(rarityData.fishes) do
			local fishName = fishData.fishName
			-- Fish 폴더에 해당 물고기가 있는지 확인 후 감지 설정
			local fishBool = fishFolder:FindFirstChild(fishName)
			if fishBool then
				fishBool.Changed:Connect(function()
					if isIndexOpen() then
						createFishIndexUI() -- 도감이 열려있으면 즉시 업데이트
						print("🔄 물고기 도감 업데이트:", fishName)
					end
				end)
			else
				warn("⚠️ Fish 폴더에서 찾을 수 없음:", fishName)
			end
		end
	end
end

-- 🔧 초기 상태 설정
indexFrame.Visible = false
indexShadowFrame.Visible = false
blur.Enabled = false
print("✅ 인덱스 UI 초기화 완료 - FOV 고정값 70 사용")

-- 데이터 리스너 설정
player.CharacterAdded:Connect(setupFishDataListener)
if player.Character then
	setupFishDataListener()
end