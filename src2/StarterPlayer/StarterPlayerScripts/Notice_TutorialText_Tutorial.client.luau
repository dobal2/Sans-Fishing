local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("Main")
local noticeFrame = mainGui:WaitForChild("NoticeFrame")
local template = noticeFrame:WaitForChild("ItemFrame")

local tutorialEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("TutorialEvent")
local tutorialCompleteRemote = ReplicatedStorage:WaitForChild("TutorialCompleteRemote")
local tutorialGoldRewardRemote = ReplicatedStorage:WaitForChild("TutorialGoldRewardRemote")
local tutorialBeam = ReplicatedStorage:WaitForChild("TutorialBeam")
local cursorLabelTemplate = ReplicatedStorage:WaitForChild("CurSorLabel")
local shopSellerDialogEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("ShopSellerDialog")

local fishingPoint = workspace:WaitForChild("TutorialWaterPoint")
local sellerPart   = workspace:WaitForChild("Sell Shop"):WaitForChild("Seller"):WaitForChild("HumanoidRootPart")
local upgradeNpc   = workspace:WaitForChild("Upgrade Shop"):WaitForChild("ShopSeller"):WaitForChild("HumanoidRootPart")

local TUTORIAL_COLOR = Color3.fromRGB(255, 220, 80)
local TWEEN_IN  = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local currentStep = ""
local tutorialCompleted = false
local startEquipStep
local persistentFrame = nil
local currentBeam = nil
local playerAttach = nil
local targetAttach = nil

-- ── CursorLabel ───────────────────────────────────────────────────────────────
local currentCursor = nil
local cursorConns = {}

local function hideCursor()
	if currentCursor and currentCursor.Parent then
		currentCursor:Destroy()
	end
	currentCursor = nil
	for _, c in ipairs(cursorConns) do
		pcall(function() c:Disconnect() end)
	end
	cursorConns = {}
end

local CURSOR_PULSE = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local function showCursorOn(target)
	if currentCursor and currentCursor.Parent then
		currentCursor:Destroy()
		currentCursor = nil
	end
	if not target or not target.Parent then return end
	local clone = cursorLabelTemplate:Clone()
	clone.Parent = target

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = clone

	TweenService:Create(uiScale, CURSOR_PULSE, {Scale = 0.82}):Play()

	currentCursor = clone
end

-- NPC 대화창 열리면 첫 번째 선택지에 커서 표시
local function watchDialogForCursor(guiName)
	task.spawn(function()
		local responseGui = playerGui:WaitForChild(guiName, 30)
		if not responseGui then return end
		local responseFrame = responseGui:WaitForChild("responseFrame", 10)
		if not responseFrame then return end

		local function tryShowBtn()
			local btn1 = responseFrame:FindFirstChild("1")
			if btn1 and btn1.Parent then showCursorOn(btn1) end
		end

		-- 이미 버튼이 있으면 바로 표시
		if responseFrame:FindFirstChild("1") then
			tryShowBtn()
		else
			local addedConn
			addedConn = responseFrame.ChildAdded:Connect(function(child)
				if child:IsA("TextButton") and child.Name == "1" then
					task.wait(0.05)
					tryShowBtn()
					addedConn:Disconnect()
				end
			end)
			table.insert(cursorConns, addedConn)
		end

		local enabledConn
		enabledConn = responseGui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if not responseGui.Enabled then
				if currentCursor and currentCursor.Parent then
					currentCursor:Destroy()
					currentCursor = nil
				end
			else
				-- 다시 열릴 때도 버튼에 커서 표시
				task.wait(0.05)
				tryShowBtn()
			end
		end)
		table.insert(cursorConns, enabledConn)
	end)
end

-- 스킬트리 열림/닫힘 상태에 따라 커서 위치 전환
local function setupSkillTreeCursor(nodeTargetName)
	local skillTreeGui = playerGui:FindFirstChild("SkillTree")
	if not skillTreeGui then return end

	local function updateCursor()
		if skillTreeGui.Enabled then
			local canvas = skillTreeGui:FindFirstChild("BackGround")
				and skillTreeGui.BackGround:FindFirstChild("Viewport")
				and skillTreeGui.BackGround.Viewport:FindFirstChild("Canvas")
			local node = canvas and canvas:FindFirstChild(nodeTargetName)
			showCursorOn(node)
		else
			local leftFrame = mainGui:FindFirstChild("Left")
			local stBtn = leftFrame and leftFrame:FindFirstChild("SkillTree")
			showCursorOn(stBtn)
		end
	end

	local conn = skillTreeGui:GetPropertyChangedSignal("Enabled"):Connect(updateCursor)
	table.insert(cursorConns, conn)
	updateCursor()
end

-- ── 빔 ────────────────────────────────────────────────────────────────────────
local function removeBeam()
	if currentBeam   then currentBeam:Destroy();   currentBeam   = nil end
	if playerAttach  then playerAttach:Destroy();  playerAttach  = nil end
	if targetAttach  then targetAttach:Destroy();  targetAttach  = nil end
end

local function createBeam(target)
	removeBeam()
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	playerAttach = Instance.new("Attachment")
	playerAttach.Parent = root

	targetAttach = Instance.new("Attachment")
	targetAttach.Parent = target

	currentBeam = tutorialBeam:Clone()
	currentBeam.Attachment0 = targetAttach
	currentBeam.Attachment1 = playerAttach
	currentBeam.Parent = root
end

-- ── 고정 알림 ─────────────────────────────────────────────────────────────────
local function hidePersistentNotice()
	if not (persistentFrame and persistentFrame.Parent) then return end
	local frame = persistentFrame
	persistentFrame = nil

	local textLabel = frame:FindFirstChild("Text")
	local shadow    = frame:FindFirstChild("Shadow")

	TweenService:Create(frame, TWEEN_OUT, {BackgroundTransparency = 1}):Play()
	if textLabel then
		TweenService:Create(textLabel, TWEEN_OUT, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	end
	for _, desc in ipairs(frame:GetDescendants()) do
		if desc:IsA("UIStroke") then
			TweenService:Create(desc, TWEEN_OUT, {Transparency = 1}):Play()
		end
	end
	if shadow then TweenService:Create(shadow, TWEEN_OUT, {ImageTransparency = 1}):Play() end
	task.delay(TWEEN_OUT.Time, function()
		if frame.Parent then frame:Destroy() end
	end)
end

local function showPersistentNotice(message)
	hidePersistentNotice()

	local frame = template:Clone()
	frame.Visible = true
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(template.Size.X.Scale, 0, 0, 0)
	frame.Position = UDim2.new(1.1, 0, 0, 0)
	frame.LayoutOrder = -999
	frame.Parent = noticeFrame
	persistentFrame = frame

	local textLabel = frame:FindFirstChild("Text")
	local shadow    = frame:FindFirstChild("Shadow")

	for _, desc in ipairs(frame:GetDescendants()) do
		if desc:IsA("UIStroke") then desc.Transparency = 1 end
	end
	if textLabel then
		textLabel.Text = message
		textLabel.TextTransparency = 1
		textLabel.TextStrokeTransparency = 1
		textLabel.TextColor3 = TUTORIAL_COLOR
	end
	if shadow then shadow.ImageTransparency = 1 end

	local expand = TweenService:Create(frame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = template.Size})
	expand:Play()
	expand.Completed:Connect(function()
		if not frame.Parent then return end
		TweenService:Create(frame, TWEEN_IN, {BackgroundTransparency = template.BackgroundTransparency, Position = UDim2.new(0,0,0,0)}):Play()
		for _, desc in ipairs(frame:GetDescendants()) do
			if desc:IsA("UIStroke") then TweenService:Create(desc, TWEEN_IN, {Transparency = 0}):Play() end
		end
		if textLabel then
			TweenService:Create(textLabel, TWEEN_IN, {TextTransparency = 0, TextStrokeTransparency = 0}):Play()
		end
		if shadow then TweenService:Create(shadow, TWEEN_IN, {ImageTransparency = 0.5}):Play() end
	end)
end

-- ── 헬퍼 ──────────────────────────────────────────────────────────────────────
local function hasRodEquipped()
	local char = player.Character
	if not char then return false end
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") and tool.Name:sub(-3) == "Rod" then return true end
	end
	return false
end

-- ── 튜토리얼 단계 ─────────────────────────────────────────────────────────────
local function completeTutorial()
	if tutorialCompleted then return end
	tutorialCompleted = true
	removeBeam()
	hideCursor()
	hidePersistentNotice()
	task.wait(0.2)
	showPersistentNotice("Congratulations! You have completed the tutorial!")
	tutorialCompleteRemote:FireServer()
	task.delay(4, hidePersistentNotice)
end

local function startPressAutoButtonStep()
	currentStep = "press_auto_button"
	showPersistentNotice("Press the Auto button to start auto fishing!")

	local autoFrame = mainGui:FindFirstChild("AutoButton")
	local autoBtn = autoFrame and autoFrame:FindFirstChild("TextButton")
	if autoBtn then
		showCursorOn(autoBtn)
		local clickConn
		clickConn = autoBtn.MouseButton1Click:Connect(function()
			if currentStep ~= "press_auto_button" then return end
			clickConn:Disconnect()
			hideCursor()
			hidePersistentNotice()
			task.wait(0.3)
			completeTutorial()
		end)
		table.insert(cursorConns, clickConn)
	else
		completeTutorial()
	end
end

local function startEquipRodForAutoStep()
	currentStep = "equip_rod_for_auto"
	showPersistentNotice("Equip your fishing rod to use Auto Fishing!")

	if hasRodEquipped() then
		hidePersistentNotice()
		task.wait(0.3)
		startPressAutoButtonStep()
		return
	end

	task.spawn(function()
		local inv = playerGui:WaitForChild("Custom Inventory", 15)
		if not inv or currentStep ~= "equip_rod_for_auto" then return end
		local hotBar = inv:WaitForChild("hotBar", 10)
		if not hotBar or currentStep ~= "equip_rod_for_auto" then return end

		local slot = hotBar:FindFirstChild("1")
		if slot then
			if currentStep == "equip_rod_for_auto" then showCursorOn(slot) end
		else
			local addedConn
			addedConn = hotBar.ChildAdded:Connect(function(child)
				if child.Name == "1" and currentStep == "equip_rod_for_auto" then
					addedConn:Disconnect()
					showCursorOn(child)
				end
			end)
			table.insert(cursorConns, addedConn)
		end
	end)

	local function onEquipped(tool)
		if tool:IsA("Tool") and tool.Name:sub(-3) == "Rod" and currentStep == "equip_rod_for_auto" then
			hideCursor()
			hidePersistentNotice()
			task.wait(0.3)
			startPressAutoButtonStep()
		end
	end

	local function setupChar(char)
		char.ChildAdded:Connect(onEquipped)
	end

	if player.Character then setupChar(player.Character) end
	player.CharacterAdded:Connect(setupChar)
end

local function startAutoFishNodeStep()
	currentStep = "buy_autofish_node"
	removeBeam()
	showPersistentNotice("Now unlock the Auto Fish node in the Skill Tree!")

	local skills = player:WaitForChild("Skills", 10)
	if not skills then completeTutorial() return end

	local autoFishVal = skills:FindFirstChild("AutoFish")
	if autoFishVal and autoFishVal.Value >= 1 then
		startEquipRodForAutoStep()
		return
	end

	if not autoFishVal then
		autoFishVal = skills:WaitForChild("AutoFish", 10)
		if not autoFishVal then completeTutorial() return end
	end

	setupSkillTreeCursor("SkillNode_AutoFish_1")

	local conn
	conn = autoFishVal.Changed:Connect(function()
		if autoFishVal.Value >= 1 and currentStep == "buy_autofish_node" then
			conn:Disconnect()
			hideCursor()
			hidePersistentNotice()
			task.wait(0.3)
			startEquipRodForAutoStep()
		end
	end)
end

local function startSkillNodeStep()
	currentStep = "buy_skill_node"
	removeBeam()
	showPersistentNotice("Open the Skill Tree and unlock the Root node!")

	local skills = player:WaitForChild("Skills", 10)
	if not skills then completeTutorial() return end

	local rootVal = skills:FindFirstChild("Root")
	if rootVal and rootVal.Value >= 1 then
		startAutoFishNodeStep()
		return
	end

	if not rootVal then
		rootVal = skills:WaitForChild("Root", 10)
		if not rootVal then completeTutorial() return end
	end

	setupSkillTreeCursor("SkillNode_Root_1")

	local conn
	conn = rootVal.Changed:Connect(function()
		if rootVal.Value >= 1 and currentStep == "buy_skill_node" then
			conn:Disconnect()
			hideCursor()
			hidePersistentNotice()
			task.wait(0.3)
			startAutoFishNodeStep()
		end
	end)
end

local function startUpgradeStep()
	local ls   = player:FindFirstChild("leaderstats")
	local rods = ls and ls:FindFirstChild("Rods")
	local sr   = rods and rods:FindFirstChild("Silver Rod")

	-- Already owns Silver Rod — skip to skill steps
	if sr and sr.Value then
		startSkillNodeStep()
		return
	end

	currentStep = "buy_silver_rod"
	showPersistentNotice("Great! Now go to the Upgrade Shop and buy the Silver Rod!")
	createBeam(upgradeNpc)

	local upgradeFrame = mainGui:FindFirstChild("Upgrade")
	showCursorOn(upgradeFrame)

	-- HUD Upgrade button: just hide the upgrade button cursor
	local upgradeImgBtn = upgradeFrame and upgradeFrame:FindFirstChild("TextButton")
	if upgradeImgBtn then
		local clickConn
		clickConn = upgradeImgBtn.MouseButton1Click:Connect(function()
			if clickConn then clickConn:Disconnect() end
			hideCursor()
		end)
		table.insert(cursorConns, clickConn)
	end

	-- Listen for the server firing the Shop Keeper dialog open event.
	-- This fires regardless of whether player used HUD button or ProximityPrompt directly.
	local shopDialogConn
	shopDialogConn = shopSellerDialogEvent.OnClientEvent:Connect(function()
		if currentStep ~= "buy_silver_rod" then return end
		shopDialogConn:Disconnect()
		hideCursor()
		watchDialogForCursor("DialogResponses_Shop Keeper")
	end)
	table.insert(cursorConns, shopDialogConn)

	-- Watch ShopGui buybutton (Silver Rod 선택됐을 때만)
	task.spawn(function()
		local shopGuiInst = playerGui:WaitForChild("ShopGui", 60)
		if not shopGuiInst or currentStep ~= "buy_silver_rod" then return end
		local bFrame = shopGuiInst:FindFirstChild("buyframe")
		local bBtnFrame = bFrame and bFrame:FindFirstChild("buybutton")
		local buyBtn = bBtnFrame and bBtnFrame:FindFirstChild("TextButton")
		local nameText = bFrame and bFrame:FindFirstChild("Name")
		if not buyBtn or not nameText then return end

		local nameConn
		local function updateShopCursor()
			if currentStep ~= "buy_silver_rod" then return end
			if shopGuiInst.Enabled and nameText.Text == "Silver Rod" then
				if not currentCursor or not currentCursor.Parent then
					showCursorOn(buyBtn)
				end
			else
				if currentCursor and currentCursor.Parent then
					currentCursor:Destroy()
					currentCursor = nil
				end
			end
		end

		nameConn = nameText:GetPropertyChangedSignal("Text"):Connect(updateShopCursor)
		table.insert(cursorConns, nameConn)

		local shopConn
		shopConn = shopGuiInst:GetPropertyChangedSignal("Enabled"):Connect(function()
			updateShopCursor()
		end)
		table.insert(cursorConns, shopConn)

		updateShopCursor()
	end)

	if not sr then return end

	local conn
	conn = sr.Changed:Connect(function()
		if sr.Value and currentStep == "buy_silver_rod" then
			conn:Disconnect()
			removeBeam()
			hideCursor()
			hidePersistentNotice()
			task.wait(0.3)
			tutorialGoldRewardRemote:FireServer()
			showPersistentNotice("You received 3,000 Coins as a tutorial reward!")
			task.wait(2.5)
			hidePersistentNotice()
			task.wait(0.3)
			startSkillNodeStep()
		end
	end)
end

local function startSellStep()
	currentStep = "sell_fish"
	removeBeam()
	showPersistentNotice("Great catch! Now go to the shop and sell your fish!")
	createBeam(sellerPart)

	local sellFrame = mainGui:FindFirstChild("Sell")
	showCursorOn(sellFrame)

	local sellImgBtn = sellFrame and sellFrame:FindFirstChild("TextButton")
	if sellImgBtn then
		local clickConn
		clickConn = sellImgBtn.MouseButton1Click:Connect(function()
			if clickConn then clickConn:Disconnect() end
			hideCursor()
			watchDialogForCursor("DialogResponses_Seller")
		end)
		table.insert(cursorConns, clickConn)
	end

	local soldNotification = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SoldNotification")

	local conn
	conn = soldNotification.OnClientEvent:Connect(function()
		if currentStep ~= "sell_fish" then return end
		conn:Disconnect()
		hideCursor()
		hidePersistentNotice()
		task.wait(0.3)
		startUpgradeStep()
	end)
end

local function startCastStep()
	currentStep = "cast_rod"
	showPersistentNotice("Great! Now go to the water and click to cast your bait!")

	local anchor = Instance.new("Frame")
	anchor.Name = "CastHintAnchor"
	anchor.Size = UDim2.new(0.1, 0, 0.15, 0)
	anchor.Position = UDim2.new(0.6, 0, 0.45, 0)
	anchor.AnchorPoint = Vector2.new(0.5, 0.5)
	anchor.BackgroundTransparency = 1
	anchor.ZIndex = 10
	anchor.Parent = mainGui
	showCursorOn(anchor)

	table.insert(cursorConns, {Disconnect = function()
		if anchor and anchor.Parent then anchor:Destroy() end
	end})

	-- 낚싯대를 내려놓으면 (cast 전에만) 장착 단계로 복귀
	local function onRodRemoved(child)
		if not (child:IsA("Tool") and child.Name:sub(-3) == "Rod") then return end
		if currentStep ~= "cast_rod" then return end
		hideCursor()
		hidePersistentNotice()
		task.wait(0.3)
		startEquipStep()
	end

	local charConn
	local function watchChar(char)
		char.ChildRemoved:Connect(onRodRemoved)
	end

	if player.Character then watchChar(player.Character) end
	charConn = player.CharacterAdded:Connect(watchChar)
	table.insert(cursorConns, charConn)
end

startEquipStep = function()
	currentStep = "equip_rod"
	showPersistentNotice("Equip your fishing rod from your backpack!")

	if hasRodEquipped() then
		hidePersistentNotice()
		task.wait(0.3)
		startCastStep()
		return
	end

	-- 핫바 슬롯 1번에 커서 표시 (비동기 대기)
	task.spawn(function()
		local inv = playerGui:WaitForChild("Custom Inventory", 15)
		if not inv or currentStep ~= "equip_rod" then return end
		local hotBar = inv:WaitForChild("hotBar", 10)
		if not hotBar or currentStep ~= "equip_rod" then return end

		local slot = hotBar:FindFirstChild("1")
		if slot then
			if currentStep == "equip_rod" then showCursorOn(slot) end
		else
			local addedConn
			addedConn = hotBar.ChildAdded:Connect(function(child)
				if child.Name == "1" and currentStep == "equip_rod" then
					addedConn:Disconnect()
					showCursorOn(child)
				end
			end)
			table.insert(cursorConns, addedConn)
		end
	end)

	local function onToolAdded(tool)
		if tool:IsA("Tool") and tool.Name:sub(-3) == "Rod" and currentStep == "equip_rod" then
			hideCursor()
			hidePersistentNotice()
			task.wait(0.3)
			startCastStep()
		end
	end

	local function setupChar(char)
		char.ChildAdded:Connect(onToolAdded)
	end

	if player.Character then setupChar(player.Character) end
	player.CharacterAdded:Connect(setupChar)

	if player:FindFirstChild("Backpack") then
		player.Backpack.ChildAdded:Connect(function(item)
			if item:IsA("Tool") and item.Name:sub(-3) == "Rod" and currentStep == "equip_rod" then
				hideCursor()
				hidePersistentNotice()
				task.wait(0.3)
				startCastStep()
			end
		end)
	end
end

local function startTutorial()
	currentStep = "welcome"
	showPersistentNotice("Welcome to Sans Fishing!")
	task.wait(2.5)
	hidePersistentNotice()
	task.wait(0.4)
	startEquipStep()
end

-- ── 낚시 이벤트 수신 ──────────────────────────────────────────────────────────
tutorialEvent.Event:Connect(function(eventType)
	if tutorialCompleted then return end

	if eventType == "baitThrow_success" and currentStep == "cast_rod" then
		currentStep = "wait_for_bite"
		removeBeam()
		hideCursor()
		showPersistentNotice("Wait for a fish to bite your bait!")

	elseif eventType == "minigame_started" and currentStep == "wait_for_bite" then
		currentStep = "minigame_active"
		showPersistentNotice("Hit the zones to catch the fish!")

	elseif eventType == "fishing_success"
		and (currentStep == "cast_rod" or currentStep == "wait_for_bite" or currentStep == "minigame_active") then
		hidePersistentNotice()
		task.wait(0.3)
		startSellStep()

	elseif eventType == "fishing_failed"
		and (currentStep == "cast_rod" or currentStep == "wait_for_bite" or currentStep == "minigame_active") then
		currentStep = "cast_rod"
		showPersistentNotice("Try again! Click to cast your bait in the water!")
	end
end)

-- ── 진입점 ────────────────────────────────────────────────────────────────────
task.spawn(function()
	local dataReady = player:WaitForChild("DataReady", 30)
	if dataReady then
		repeat task.wait() until dataReady.Value == true
	end
	local isTutorialed = player:WaitForChild("IsTutorialed", 30)
	if not isTutorialed or isTutorialed.Value then return end
	task.wait(2)
	startTutorial()
end)
