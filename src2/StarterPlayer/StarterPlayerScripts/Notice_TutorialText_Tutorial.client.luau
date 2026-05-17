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
local tutorialBeam = ReplicatedStorage:WaitForChild("TutorialBeam")

local fishingPoint = workspace:WaitForChild("TutorialWaterPoint")
local sellerPart   = workspace:WaitForChild("Sell Shop"):WaitForChild("Seller"):WaitForChild("HumanoidRootPart")
local upgradeNpc   = workspace:WaitForChild("Upgrade Shop"):WaitForChild("ShopSeller"):WaitForChild("HumanoidRootPart")

local TUTORIAL_COLOR = Color3.fromRGB(255, 220, 80)
local TWEEN_IN  = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local currentStep = ""
local tutorialCompleted = false
local persistentFrame = nil
local currentBeam = nil
local playerAttach = nil
local targetAttach = nil
local initialMoney = 0

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
local function getCoins()
	local ls = player:FindFirstChild("leaderstats")
	local c  = ls and ls:FindFirstChild("Coins")
	return c and c.Value or 0
end

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
	hidePersistentNotice()
	task.wait(0.2)
	showPersistentNotice("Congratulations! You have completed the tutorial!")
	tutorialCompleteRemote:FireServer()
	task.delay(4, hidePersistentNotice)
end

local function startSkillTreeStep()
	currentStep = "open_skill_tree"
	removeBeam()
	showPersistentNotice("Almost done! Open the Skill Tree from the toolbar to upgrade your skills!")

	local skillTreeGui = playerGui:WaitForChild("SkillTree")
	local conn
	conn = skillTreeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if skillTreeGui.Enabled and currentStep == "open_skill_tree" then
			conn:Disconnect()
			hidePersistentNotice()
			task.wait(0.3)
			completeTutorial()
		end
	end)
end

local function startUpgradeStep()
	local ls   = player:FindFirstChild("leaderstats")
	local rods = ls and ls:FindFirstChild("Rods")
	local sr   = rods and rods:FindFirstChild("SliverRod")

	-- Already owns Silver Rod — skip straight to skill tree
	if sr and sr.Value then
		startSkillTreeStep()
		return
	end

	currentStep = "buy_silver_rod"
	showPersistentNotice("Great! Now go to the Upgrade Shop and buy the Silver Rod!")
	createBeam(upgradeNpc)

	if not sr then return end

	local conn
	conn = sr.Changed:Connect(function()
		if sr.Value and currentStep == "buy_silver_rod" then
			conn:Disconnect()
			hidePersistentNotice()
			task.wait(0.3)
			startSkillTreeStep()
		end
	end)
end

local function startSellStep()
	currentStep = "sell_fish"
	removeBeam()
	showPersistentNotice("Great catch! Now go to the shop and sell your fish!")
	createBeam(sellerPart)

	local soldNotification = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SoldNotification")

	local conn
	conn = soldNotification.OnClientEvent:Connect(function()
		if currentStep ~= "sell_fish" then return end
		conn:Disconnect()
		hidePersistentNotice()
		task.wait(0.3)
		startUpgradeStep()
	end)
end

local function startCastStep()
	currentStep = "cast_rod"
	showPersistentNotice("Great! Now go to the water and click to cast your bait!")
	createBeam(fishingPoint)
end

local function startEquipStep()
	currentStep = "equip_rod"
	showPersistentNotice("Equip your fishing rod from your backpack!")

	if hasRodEquipped() then
		hidePersistentNotice()
		task.wait(0.3)
		startCastStep()
		return
	end

	local function onToolAdded(tool)
		if tool:IsA("Tool") and tool.Name:sub(-3) == "Rod" and currentStep == "equip_rod" then
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
		createBeam(fishingPoint)
	end
end)

-- ── 진입점 ────────────────────────────────────────────────────────────────────
task.spawn(function()
	local isTutorialed = player:WaitForChild("IsTutorialed", 30)
	if not isTutorialed or isTutorialed.Value then return end
	task.wait(2)
	startTutorial()
end)
