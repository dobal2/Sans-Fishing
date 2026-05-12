local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local noticeEvent = ReplicatedStorage:WaitForChild("TutorialEvent")
local sound = script.Parent:WaitForChild("Sound")

-- 튜토리얼 완료 리모트 이벤트 추가
local tutorialCompleteRemote = ReplicatedStorage:WaitForChild("TutorialCompleteRemote")

local tutorialBeam = ReplicatedStorage:WaitForChild("TutorialBeam")
local fishingPoint = game.Workspace:WaitForChild("TutorialWaterPoint")
local Seller = game.Workspace:WaitForChild("Sell Shop"):WaitForChild("Seller"):WaitForChild("HumanoidRootPart")
local upgradeNpc = game.Workspace:WaitForChild("Upgrade Shop"):WaitForChild("ShopSeller"):WaitForChild("HumanoidRootPart")

local textLabel = script.Parent
local player = Players.LocalPlayer

local currentTween = nil
local currentTask = nil
local currentStep = "" -- 현재 튜토리얼 단계
local stepCompleted = false -- 단계 완료 여부
local tutorialStarted = false -- 튜토리얼 시작 여부

-- 튜토리얼 빔 관련 변수
local currentBeam = nil
local playerAttachment = nil
local targetAttachment = nil

-- 돈 추적 변수
local initialMoney = 0
local currentMoney = 0
local tutorialCompleted = false -- 튜토리얼 완료 플래그 추가

-- 함수들을 미리 선언 (호출 순서 문제 해결)
local showText, checkStepCompletion, removeTutorialBeam, createTutorialBeam

-- 트윈 생성 함수
local function createTween(object, targetProps, duration)
	return TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), targetProps)
end

-- 플레이어 돈 확인 함수
local function getPlayerMoney()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins")
		if coins then
			return coins.Value
		end
	end
	return 0
end

-- 업그레이드된 낚싯대 확인 함수 (실버로드만)
local function checkUpgradedRod()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rods = leaderstats:FindFirstChild("Rods")
		if rods then
			local silverRod = rods:FindFirstChild("SliverRod")

			print("🔍 실버로드 확인:")
			if silverRod then
				print("  SliverRod 값:", silverRod.Value)
				if silverRod.Value == true then
					print("✅ 실버로드 감지!")
					return true
				end
			else
				print("  SliverRod를 찾을 수 없음")
			end
		else
			print("⚠️ Rods를 찾을 수 없음")
		end
	else
		print("⚠️ leaderstats를 찾을 수 없음")
	end
	print("❌ 실버로드 없음")
	return false
end



-- 튜토리얼 빔 제거 함수
removeTutorialBeam = function()
	if currentBeam then
		currentBeam:Destroy()
		currentBeam = nil
		print("🔆 튜토리얼 빔 제거됨!")
	end
	if playerAttachment then
		playerAttachment:Destroy()
		playerAttachment = nil
	end
	if targetAttachment then
		targetAttachment:Destroy()
		targetAttachment = nil
	end
end

-- 텍스트 숨기기 함수
local function hideText()
	if currentTween then
		currentTween:Cancel()
	end
	if currentTask then
		local success = pcall(function()
			task.cancel(currentTask)
		end)
		currentTask = nil
	end

	currentTween = createTween(textLabel, {TextTransparency = 1, TextStrokeTransparency = 1}, 0.3)
	currentTween:Play()
	currentTween.Completed:Wait()
	textLabel.Visible = false
	currentStep = ""
	stepCompleted = false
end

-- 돈 변화 감지 함수
local function checkMoneyIncrease()
	-- 이미 튜토리얼이 완료되었으면 함수 종료
	if tutorialCompleted then return false end

	local newMoney = getPlayerMoney()
	if newMoney > initialMoney then
		print("💰 돈이 증가했습니다:", initialMoney, "→", newMoney)

		-- 빔 제거
		removeTutorialBeam()
		if checkUpgradedRod() then
			--print("🎉 실버로드를 이미 보유 중! 업그레이드 단계 건너뛰고 바로 튜토리얼 완료")
			-- 튜토리얼 완료 플래그 설정
			tutorialCompleted = true

			task.spawn(function()
				task.wait(0.1)
				hideText()
				task.wait(0.5)
				showText("Congratulations! You've completed the tutorial!")

				-- 서버로 튜토리얼 완료 알림 전송
				tutorialCompleteRemote:FireServer()

				-- 클라이언트에서도 플래그 설정 (백업용)
				local isTutorialed = player:FindFirstChild("IsTutorialed")
				if isTutorialed then
					isTutorialed.Value = true
				end
			end)
		else
			-- 실버로드가 없으면 업그레이드 단계로 진행
			task.spawn(function()
				task.wait(0.1)
				hideText()
				task.wait(0.5)
				showText("Great! Now go to the upgrade shop and buy the Silver Rod!")
				-- 업그레이드 NPC로 빔 생성
				createTutorialBeam(upgradeNpc)
				-- 업그레이드 단계로 변경
				currentStep = "visit_upgrade"
			end)
		end
		return true
	end
	return false
end

-- 업그레이드 단계 완료 체크 함수
local function checkUpgradeStepCompletion()
	print("🔧 업그레이드 단계 체크:", "currentStep =", currentStep, "tutorialCompleted =", tutorialCompleted)

	if currentStep == "visit_upgrade" and not tutorialCompleted then
		local hasUpgradedRod = checkUpgradedRod()
		if hasUpgradedRod then
			print("🎉 실버로드 업그레이드 완료! 튜토리얼 종료 시작")
			stepCompleted = true

			-- 튜토리얼 완료 플래그 설정
			tutorialCompleted = true

			-- 빔 제거
			removeTutorialBeam()

			-- 튜토리얼 완료 처리
			task.spawn(function()
				hideText()
				task.wait(0.5)
				showText("Congratulations! You've completed the tutorial!")

				-- 서버로 튜토리얼 완료 알림 전송
				tutorialCompleteRemote:FireServer()

				-- 클라이언트에서도 플래그 설정 (백업용)
				local isTutorialed = player:FindFirstChild("IsTutorialed")
				if isTutorialed then
					isTutorialed.Value = true
				end
			end)
			return true
		end
	end
	return false
end

-- 업그레이드된 낚싯대 변화 감지 (실버로드만)
local function setupRodTracking()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rods = leaderstats:FindFirstChild("Rods")
		if rods then
			local silverRod = rods:FindFirstChild("SliverRod")

			if silverRod then
				print("🔗 SliverRod 변화 감지 설정")
				silverRod.Changed:Connect(function()
					print("📡 SliverRod 값 변경됨:", silverRod.Value)
					if currentStep == "visit_upgrade" and not tutorialCompleted then
						checkUpgradeStepCompletion()
					end
				end)
			else
				print("⚠️ SliverRod를 찾을 수 없어서 감지 설정 불가")
			end
		else
			print("⚠️ Rods 폴더를 찾을 수 없음")
		end
	else
		print("⚠️ leaderstats를 찾을 수 없음")
	end
end

-- 튜토리얼 빔 생성 함수 (타겟 지정 가능)
createTutorialBeam = function(target)
	target = target or fishingPoint -- 기본값은 fishingPoint

	-- 기존 빔이 있다면 제거
	if currentBeam then
		currentBeam:Destroy()
		currentBeam = nil
	end
	if playerAttachment then
		playerAttachment:Destroy()
		playerAttachment = nil
	end
	if targetAttachment then
		targetAttachment:Destroy()
		targetAttachment = nil
	end

	-- 플레이어 RootPart 확인
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- 플레이어 RootPart에 Attachment 생성
	playerAttachment = Instance.new("Attachment")
	playerAttachment.Name = "TutorialPlayerAttachment"
	playerAttachment.Parent = rootPart

	-- 타겟에 Attachment 생성
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "TutorialTargetAttachment"
	targetAttachment.Parent = target

	-- 빔 클론 및 설정 (어태치먼트 순서 변경)
	currentBeam = tutorialBeam:Clone()
	currentBeam.Attachment0 = targetAttachment
	currentBeam.Attachment1 = playerAttachment
	currentBeam.Parent = rootPart

	print("🔆 튜토리얼 빔 생성됨! 타겟:", target.Name)
end

-- 🎣 낚싯대 장착 감지
local function checkRodEquipped()
	local character = player.Character
	if not character then return false end

	for _, tool in pairs(character:GetChildren()) do
		if tool:IsA("Tool") and string.sub(tool.Name, -3) == "Rod" then
			return true
		end
	end
	return false
end

-- 🐟 낚시 완료 감지 (더 이상 사용하지 않음 - 낚시 클라이언트에서 직접 알림)
local function checkFishCaught()
	-- 이 함수는 더 이상 사용되지 않지만 기존 코드 호환성을 위해 유지
	return false
end

-- showText 함수에서 단계 설정 부분 수정
showText = function(message)
	sound:Play()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
	if currentTask then
		local success = pcall(function()
			task.cancel(currentTask)
		end)
		currentTask = nil
	end

	-- 현재 단계 설정 (수정된 부분)
	if string.find(message, "Welcome") then
		currentStep = "welcome"
	elseif string.find(message, "fishing rod") then
		currentStep = "equip_rod"
	elseif string.find(message, "Great") and string.find(message, "cast") then
		currentStep = "start_fishing"  -- "Great! Now go to the water and click to cast your bait!"
		-- 낚시하러 가라는 메시지가 표시될 때 빔 생성
		createTutorialBeam(fishingPoint)
	elseif string.find(message, "sell") then
		currentStep = "sell_fish"  -- "Now go to the shop and sell your fish!"
		-- 물고기 팔라는 메시지가 표시될 때 Seller로 빔 생성
		createTutorialBeam(Seller)
		-- 초기 돈 기록
		initialMoney = getPlayerMoney()
		print("💰 초기 돈:", initialMoney)
	elseif string.find(message, "upgrade") then
		currentStep = "visit_upgrade"  -- "Great! Now visit the upgrade shop to improve your fishing rod!"
	elseif string.find(message, "Wait for a fish") then
		-- "Wait for a fish to bite your bait!" - 단계 변경하지 않음
		-- currentStep = "wait_for_bite" 이미 이벤트에서 설정됨
	elseif string.find(message, "Hit the zones") then
		-- "Hit the zones to catch the fish!" - 단계 변경하지 않음
		-- currentStep = "minigame_active" 이미 이벤트에서 설정됨
	elseif string.find(message, "Try again") then
		currentStep = "start_fishing"  -- "Try again! Click to cast your bait in the water"
	elseif string.find(message, "Congratulations") then
		currentStep = "tutorial_complete"
	elseif string.find(message, "fishing") and not string.find(message, "Great") then
		currentStep = "start_fishing"
	elseif string.find(message, "Great") or string.find(message, "Nice") or string.find(message, "Well done") then
		-- 칭찬 메시지는 단계를 변경하지 않음
		-- currentStep = "praise"
	else
		-- currentStep = "normal" - 기타 메시지도 단계 변경하지 않음
	end

	stepCompleted = false

	textLabel.Text = message
	textLabel.Visible = true
	textLabel.TextTransparency = 1
	textLabel.TextStrokeTransparency = 1
	createTween(textLabel, {TextTransparency = 0, TextStrokeTransparency = 0}, 0.2):Play()

	-- Welcome 메시지는 자동으로 사라진 후 다음 단계 진행
	if currentStep == "welcome" then
		currentTask = task.spawn(function()
			task.wait(2)
			hideText()
			task.wait(0.5)
			showText("Equip your fishing rod from your backpack")
		end)
	elseif currentStep == "tutorial_complete" then
		currentTask = task.spawn(function()
			task.wait(3)
			hideText()
		end)
	end

	-- 조건이 이미 만족된 경우 즉시 체크 (낚싯대 장착만)
	if currentStep == "equip_rod" then
		task.spawn(function()
			task.wait(0.1) -- 텍스트가 표시된 후 체크
			if checkStepCompletion then
				checkStepCompletion()
			end
		end)
	end
end

-- 단계별 조건 체크
checkStepCompletion = function()
	if stepCompleted then return end

	if currentStep == "equip_rod" and checkRodEquipped() then
		--print("🎣 낚싯대 장착 완료!")
		stepCompleted = true
		hideText()
		-- 칭찬 메시지 표시 (수정된 부분)
		task.wait(0.5)
		showText("Great! Now go to the water and click to cast your bait!")
	end
	-- start_fishing 단계는 이제 이벤트에서 직접 처리
end

-- 캐릭터 변화 감지 (낚싯대 장착)
player.CharacterAdded:Connect(function(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and string.sub(child.Name, -3) == "Rod" then
			task.wait(0.1) -- 약간의 지연
			if checkStepCompletion then
				checkStepCompletion()
			end
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and string.sub(child.Name, -3) == "Rod" then
			task.wait(0.1)
			if checkStepCompletion then
				checkStepCompletion()
			end
		end
	end)
end)

-- 백팩 변화 감지 (낚싯대 장착/해제만 체크)
if player:FindFirstChild("Backpack") then
	player.Backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and string.sub(child.Name, -3) == "Rod" then
			task.wait(0.1)
			if checkStepCompletion then
				checkStepCompletion()
			end
		end
	end)

	player.Backpack.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and string.sub(child.Name, -3) == "Rod" then
			task.wait(0.1)
			if checkStepCompletion then
				checkStepCompletion()
			end
		end
	end)
end

player.ChildAdded:Connect(function(child)
	if child.Name == "Backpack" then
		child.ChildAdded:Connect(function(item)
			if item:IsA("Tool") and string.sub(item.Name, -3) == "Rod" then
				task.wait(0.1)
				if checkStepCompletion then
					checkStepCompletion()
				end
			end
		end)

		child.ChildRemoved:Connect(function(item)
			if item:IsA("Tool") and string.sub(item.Name, -3) == "Rod" then
				task.wait(0.1)
				if checkStepCompletion then
					checkStepCompletion()
				end
			end
		end)
	end
end)

-- 정기적으로 조건 체크
game:GetService("RunService").Heartbeat:Connect(function()
	if currentStep == "equip_rod" then
		if checkStepCompletion then
			checkStepCompletion()
		end
	end
	-- 물고기 팔기 단계에서 돈 증가 체크 (튜토리얼 완료되지 않은 경우만)
	if currentStep == "sell_fish" and not tutorialCompleted then
		checkMoneyIncrease()
	end
	-- 업그레이드 단계 체크 추가
	if currentStep == "visit_upgrade" and not tutorialCompleted then
		checkUpgradeStepCompletion()
	end
end)

-- 돈 변화 감지 (leaderstats 변경 감지)
local function setupMoneyTracking()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins")
		if coins then
			coins.Changed:Connect(function()
				if currentStep == "sell_fish" and not tutorialCompleted then
					checkMoneyIncrease()
				end
			end)
		end
	end
end

-- 플레이어 로드 시 추적 설정
if player:FindFirstChild("leaderstats") then
	setupMoneyTracking()
	setupRodTracking()
else
	player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			setupMoneyTracking()
			setupRodTracking()
		end
	end)
end

noticeEvent.Event:Connect(function(eventType)
	-- 🎓 튜토리얼 시작
	if not eventType and not tutorialStarted then
		tutorialStarted = true
		print("🎓 튜토리얼 자동 시작!")
		if showText then
			showText("Welcome to Sans Fishing!")
		end
	end

	-- 🎣 미끼 던지기 성공 처리 (새로 추가)
	if eventType == "baitThrow_success" and currentStep == "start_fishing" then
		print("🎣 미끼 던지기 성공!")
		-- 빔 제거
		removeTutorialBeam()
		hideText()
		-- 대기 메시지 표시
		task.wait(0.5)
		showText("Wait for a fish to bite your bait!")
		-- 대기 단계로 변경
		currentStep = "wait_for_bite"
	end

	-- 🎮 미니게임 시작 처리 (새로 추가)
	if eventType == "minigame_started" and currentStep == "wait_for_bite" then
		print("🎮 미니게임 시작!")
		hideText()
		task.wait(0.3)
		showText("Hit the zones to catch the fish!")
		-- 미니게임 단계로 변경
		currentStep = "minigame_active"
	end

	-- 🐟 낚시 성공 처리
	if eventType == "fishing_success" and (currentStep == "start_fishing" or currentStep == "wait_for_bite" or currentStep == "minigame_active") then
		print("🐟 낚시 성공 감지!")
		stepCompleted = true
		-- 빔 제거
		removeTutorialBeam()
		hideText()
		-- 물고기 팔라는 메시지 표시
		task.wait(0.5)
		showText("Great! Now go to the shop and sell your fish!")
	end

	-- ❌ 낚시 실패 처리
	if eventType == "fishing_failed" and (currentStep == "start_fishing" or currentStep == "wait_for_bite" or currentStep == "minigame_active") then
		print("❌ 낚시 실패 감지!")
		-- 빔 제거
		removeTutorialBeam()
		-- 기존 텍스트 숨기고 재시도 메시지 표시
		hideText()
		task.wait(0.5)
		showText("Try again! Click to cast your bait in the water")
		-- 재시도 메시지 표시 후 다시 빔 생성
		createTutorialBeam(fishingPoint)
		-- 다시 낚시 시작 단계로 변경
		currentStep = "start_fishing"
	end
end)