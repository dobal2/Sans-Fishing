local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

local fishingPoint = workspace:WaitForChild("TutorialWaterPoint")
local sellerPart   = workspace:WaitForChild("Sell Shop"):WaitForChild("Seller"):WaitForChild("HumanoidRootPart")
local upgradeNpc   = workspace:WaitForChild("Upgrade Shop"):WaitForChild("ShopSeller"):WaitForChild("HumanoidRootPart")

local TUTORIAL_COLOR = Color3.fromRGB(255, 220, 80)
local TWEEN_IN  = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FOCUS_OVERLAY_TRANSPARENCY = 0.5
local FOCUS_OVERLAY_PADDING = 12
local FOCUS_OVERLAY_MIN_PADDING = 8
local LOADING_GUI_NAME = "Loading"
local LOADING_FINISHED_ATTRIBUTE = "LoadingScreenFinished"

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
local focusOverlayGui = nil
local focusOverlayConn = nil

local function hideFocusOverlay()
	if focusOverlayConn then
		focusOverlayConn:Disconnect()
		focusOverlayConn = nil
	end
	if focusOverlayGui then
		focusOverlayGui:Destroy()
		focusOverlayGui = nil
	end
end

local function hideCursor()
	hideFocusOverlay()
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
local FOCUS_OVERLAY_TWEEN = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function showFocusOverlay(target)
	hideFocusOverlay()
	if not target or not target.Parent then return end

	local targetScreenGui = target:FindFirstAncestorOfClass("ScreenGui")
	if not targetScreenGui then return end

	local overlayGui = Instance.new("Frame")
	overlayGui.Name = "TutorialFocusOverlay"
	overlayGui.BackgroundTransparency = 1
	overlayGui.BorderSizePixel = 0
	overlayGui.Size = UDim2.fromScale(1, 1)
	overlayGui.Position = UDim2.fromScale(0, 0)
	overlayGui.Active = false
	overlayGui.ZIndex = 1000
	overlayGui.Parent = targetScreenGui

	local frames = {}
	for _, name in ipairs({"Top", "Bottom", "Left", "Right"}) do
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Active = false
		frame.ZIndex = 1000
		frame.Parent = overlayGui
		frames[name] = frame
		TweenService:Create(frame, FOCUS_OVERLAY_TWEEN, {BackgroundTransparency = FOCUS_OVERLAY_TRANSPARENCY}):Play()
	end

	local highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.BackgroundTransparency = 1
	highlight.BorderSizePixel = 0
	highlight.ZIndex = 1001
	highlight.Parent = overlayGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.14, 0)
	corner.Parent = highlight

	local stroke = Instance.new("UIStroke")
	stroke.Color = TUTORIAL_COLOR
	stroke.Thickness = 3
	stroke.Transparency = 1
	stroke.Parent = highlight
	TweenService:Create(stroke, FOCUS_OVERLAY_TWEEN, {Transparency = 0.05}):Play()

	local function updateOverlay()
		if not target.Parent or not workspace.CurrentCamera then
			hideFocusOverlay()
			return
		end

		local viewport = overlayGui.AbsoluteSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			viewport = workspace.CurrentCamera.ViewportSize
		end
		local containerPos = overlayGui.AbsolutePosition
		local pos = target.AbsolutePosition
		local size = target.AbsoluteSize
		local responsivePadding = math.max(FOCUS_OVERLAY_MIN_PADDING, math.min(FOCUS_OVERLAY_PADDING, math.floor(math.min(viewport.X, viewport.Y) * 0.015)))
		local desiredWidth = math.min(viewport.X, math.max(1, size.X + responsivePadding * 2))
		local desiredHeight = math.min(viewport.Y, math.max(1, size.Y + responsivePadding * 2))
		local targetCenterX = pos.X - containerPos.X + size.X * 0.5
		local targetCenterY = pos.Y - containerPos.Y + size.Y * 0.5
		local left = math.clamp(math.floor(targetCenterX - desiredWidth * 0.5), 0, math.max(0, viewport.X - desiredWidth))
		local top = math.clamp(math.floor(targetCenterY - desiredHeight * 0.5), 0, math.max(0, viewport.Y - desiredHeight))
		local right = math.min(viewport.X, math.ceil(left + desiredWidth))
		local bottom = math.min(viewport.Y, math.ceil(top + desiredHeight))

		frames.Top.Position = UDim2.fromOffset(0, 0)
		frames.Top.Size = UDim2.fromOffset(viewport.X, top)

		frames.Bottom.Position = UDim2.fromOffset(0, bottom)
		frames.Bottom.Size = UDim2.fromOffset(viewport.X, math.max(0, viewport.Y - bottom))

		frames.Left.Position = UDim2.fromOffset(0, top)
		frames.Left.Size = UDim2.fromOffset(left, math.max(0, bottom - top))

		frames.Right.Position = UDim2.fromOffset(right, top)
		frames.Right.Size = UDim2.fromOffset(math.max(0, viewport.X - right), math.max(0, bottom - top))

		highlight.Position = UDim2.fromOffset(left, top)
		highlight.Size = UDim2.fromOffset(math.max(0, right - left), math.max(0, bottom - top))
	end

	focusOverlayGui = overlayGui
	focusOverlayConn = RunService.RenderStepped:Connect(updateOverlay)
	updateOverlay()
end

local function waitForLoadingScreenClosed()
	if player:GetAttribute(LOADING_FINISHED_ATTRIBUTE) == true then
		task.wait(0.2)
		return
	end

	local loadingGui = playerGui:FindFirstChild(LOADING_GUI_NAME) or playerGui:WaitForChild(LOADING_GUI_NAME, 10)
	while loadingGui and loadingGui.Parent do
		task.wait()
	end

	local deadline = os.clock() + 2
	while player:GetAttribute(LOADING_FINISHED_ATTRIBUTE) ~= true and os.clock() < deadline do
		task.wait()
	end

	task.wait(0.2)
end

local function showCursorOn(target, scale)
	if currentCursor and currentCursor.Parent then
		currentCursor:Destroy()
		currentCursor = nil
	end
	if not target or not target.Parent then return end
	local clone = cursorLabelTemplate:Clone()
	clone.Parent = target

	local uiScale = Instance.new("UIScale")
	local cursorScale = scale or 1
	uiScale.Scale = cursorScale
	uiScale.Parent = clone

	TweenService:Create(uiScale, CURSOR_PULSE, {Scale = cursorScale * 0.82}):Play()

	currentCursor = clone
end

-- NPC 대화창 열리면 첫 번째 선택지에 커서 표시
local function showCursorOver(target, scale)
	if currentCursor and currentCursor.Parent then
		currentCursor:Destroy()
		currentCursor = nil
	end
	if not target or not target.Parent then return end

	local clone = Instance.new("ImageLabel")
	clone.Name = "TutorialCursorOverlay"
	clone.BackgroundTransparency = 1
	clone.BorderSizePixel = 0
	clone.Image = cursorLabelTemplate.Image
	clone.ImageColor3 = cursorLabelTemplate.ImageColor3
	clone.ImageTransparency = cursorLabelTemplate.ImageTransparency
	clone.AnchorPoint = Vector2.new(0.5, 0.5)
	clone.Visible = true
	clone.Parent = mainGui
	clone.ZIndex = 1000

	local uiScale = Instance.new("UIScale")
	local cursorScale = scale or 1
	uiScale.Scale = cursorScale
	uiScale.Parent = clone

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = clone

	local function updateCursor()
		if not target.Parent or not clone.Parent then return end
		local pos = target.AbsolutePosition
		local size = target.AbsoluteSize
		local cursorSize = math.clamp(math.max(size.X, size.Y) * 0.9, 42, 92)
		clone.Size = UDim2.fromOffset(cursorSize, cursorSize)
		clone.Position = UDim2.fromOffset(
			pos.X + size.X * 0.72,
			pos.Y + size.Y * 0.38
		)
	end

	updateCursor()
	local updateConn = RunService.RenderStepped:Connect(updateCursor)
	table.insert(cursorConns, updateConn)

	TweenService:Create(uiScale, CURSOR_PULSE, {Scale = cursorScale * 0.82}):Play()

	currentCursor = clone
end

local function watchDialogForCursor(guiName)
	task.spawn(function()
		local responseGui = playerGui:WaitForChild(guiName, 30)
		if not responseGui then return end
		local responseFrame = responseGui:WaitForChild("responseFrame", 10)
		if not responseFrame then return end

		local function tryShowBtn()
			if not responseGui.Enabled then return end
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

local function startAutoFishNodeStep()
	currentStep = "buy_autofish_node"
	removeBeam()
	showPersistentNotice("Now unlock the Auto Fish node in the Skill Tree!")

	local skills = player:WaitForChild("Skills", 10)
	if not skills then completeTutorial() return end

	local autoFishVal = skills:FindFirstChild("AutoFish")
	if autoFishVal and autoFishVal.Value >= 1 then
		completeTutorial()
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
			completeTutorial()
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
	watchDialogForCursor("DialogResponses_Shop Keeper")

	local upgradeFrame = mainGui:FindFirstChild("Upgrade")
	local upgradeImgBtn = upgradeFrame and upgradeFrame:FindFirstChild("TextButton")
	local upgradeButtonClicked = false
	showCursorOn(upgradeFrame)

	task.spawn(function()
		while currentStep == "buy_silver_rod" and not upgradeButtonClicked do
			local shopGuiInst = playerGui:FindFirstChild("ShopGui")
			local dialogGui = playerGui:FindFirstChild("DialogResponses_Shop Keeper")
			local shopOpen = shopGuiInst and shopGuiInst.Enabled
			local dialogOpen = dialogGui and dialogGui.Enabled
			local bFrame = shopGuiInst and shopGuiInst:FindFirstChild("buyframe")
			local nameText = bFrame and bFrame:FindFirstChild("Name")
			if dialogOpen or (shopOpen and nameText and nameText.Text == "Silver Rod") then
				break
			end
			if upgradeFrame and upgradeFrame.Parent and (not currentCursor or currentCursor.Parent ~= upgradeFrame) then
				showCursorOn(upgradeFrame)
			end
			task.wait(0.2)
		end
	end)

	if upgradeImgBtn then
		local clickConn
		clickConn = upgradeImgBtn.MouseButton1Click:Connect(function()
			if clickConn then clickConn:Disconnect() end
			upgradeButtonClicked = true
			hideCursor()
			watchDialogForCursor("DialogResponses_Shop Keeper")
		end)
		table.insert(cursorConns, clickConn)
	end

	-- Watch ShopGui buybutton (Silver Rod 선택됐을 때만)
	task.spawn(function()
		local shopGuiInst = playerGui:WaitForChild("ShopGui", 60)
		if not shopGuiInst or currentStep ~= "buy_silver_rod" then return end
		local bFrame = shopGuiInst:FindFirstChild("buyframe")
		local bBtnFrame = bFrame and bFrame:FindFirstChild("buybutton")
		local buyBtn = bBtnFrame and bBtnFrame:FindFirstChild("TextButton")
		local nameText = bFrame and bFrame:FindFirstChild("Name")
		if not buyBtn or not nameText then return end
		local buyCursorTarget = bBtnFrame or buyBtn

		local nameConn
		local function updateShopCursor()
			if currentStep ~= "buy_silver_rod" then return end
			if not shopGuiInst.Enabled then return end
			if bFrame and not bFrame.Visible then return end
			if nameText.Text == "Silver Rod" or nameText.Text == "name" or nameText.Text == "" then
				if not currentCursor or currentCursor.Parent ~= buyCursorTarget then
					showCursorOn(buyCursorTarget)
				end
			else
				if currentCursor and currentCursor.Parent == buyCursorTarget then
					currentCursor:Destroy()
					currentCursor = nil
				end
			end
		end

		nameConn = nameText:GetPropertyChangedSignal("Text"):Connect(updateShopCursor)
		table.insert(cursorConns, nameConn)

		local visibleConn
		visibleConn = bFrame:GetPropertyChangedSignal("Visible"):Connect(updateShopCursor)
		table.insert(cursorConns, visibleConn)

		local shopConn
		shopConn = shopGuiInst:GetPropertyChangedSignal("Enabled"):Connect(function()
			updateShopCursor()
		end)
		table.insert(cursorConns, shopConn)

		updateShopCursor()

		task.spawn(function()
			while currentStep == "buy_silver_rod" and shopGuiInst.Parent and bFrame.Parent do
				updateShopCursor()
				task.wait(0.15)
			end
		end)
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
	watchDialogForCursor("DialogResponses_Seller")

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

	if player:GetAttribute("IsFishing") == true then
		currentStep = "wait_for_bite"
		removeBeam()
		hideCursor()
		showPersistentNotice("Wait for a fish to bite your bait!")
		return
	end

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
			if currentStep == "equip_rod" then
				showFocusOverlay(slot)
				showCursorOn(slot, 1.6)
			end
		else
			local addedConn
			addedConn = hotBar.ChildAdded:Connect(function(child)
				if child.Name == "1" and currentStep == "equip_rod" then
					addedConn:Disconnect()
					showFocusOverlay(child)
					showCursorOn(child, 1.6)
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
	waitForLoadingScreenClosed()
	task.wait(0.2)
	startTutorial()
end)
