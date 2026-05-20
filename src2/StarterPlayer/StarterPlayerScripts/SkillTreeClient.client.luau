local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local skillTreeGui = playerGui:WaitForChild("SkillTree")

local skillBuyEvent  = ReplicatedStorage:WaitForChild("SkillBuyEvent")
local getSkillData   = ReplicatedStorage:WaitForChild("GetSkillData")
local robuxBuySound  = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("RobuxBuySound")
local errorSound     = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("error")
local noticeEvent    = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("NoticeEventForClient")


local closePendingTask = nil

-- ── 숫자 단위 포맷 (유효숫자 3자리 고정) ────────────────────────────────────
-- 1,000→1.00K / 10,000→10.0K / 100,000→100K / 1,000,000→1.00M
local function formatNumber(n)
	local function fmt(val, suffix)
		if val >= 100 then
			return string.format("%d%s", math.floor(val), suffix)
		elseif val >= 10 then
			return string.format("%.1f%s", val, suffix)
		else
			return string.format("%.2f%s", val, suffix)
		end
	end

	if n >= 1000000 then
		return fmt(n / 1000000, "M")
	elseif n >= 1000 then
		return fmt(n / 1000, "K")
	else
		return tostring(n)
	end
end

-- ── 유틸 ─────────────────────────────────────────────────────────────────────
local function getCanvas()
	local bg = skillTreeGui:FindFirstChild("BackGround")
	local vp = bg and bg:FindFirstChild("Viewport")
	return vp and vp:FindFirstChild("Canvas")
end

local function parseNodeName(name)
	local skillName, stageStr = name:match("^SkillNode_(.+)_(%d+)$")
	return skillName, tonumber(stageStr)
end

-- ── UI 갱신 ──────────────────────────────────────────────────────────────────
local refreshToken = 0
local function refreshUI()
	refreshToken += 1
	local myToken = refreshToken
	local data = getSkillData:InvokeServer()
	if myToken ~= refreshToken then return end  -- newer call started, discard
	if not data then return end

	local canvas = getCanvas()
	if not canvas then return end

	local rootUnlocked = (data.levels["Root"] or 0) >= 1

	for _, btn in ipairs(canvas:GetDescendants()) do
		if not btn:IsA("ImageButton") then continue end
		local skillName, stage = parseNodeName(btn.Name)
		if not skillName or not stage then continue end

		local cfg      = data.skills[skillName]
		local curLevel = data.levels[skillName] or 0
		if not cfg then continue end

		local reqLabel = btn:FindFirstChild("Requirement")

		local function setAllVisible(visible)
			for _, desc in ipairs(btn:GetDescendants()) do
				if desc:IsA("GuiObject") then
					desc.Visible = visible
				end
			end
		end

		local function lockNode()
			btn.Image = "rbxassetid://102739874658337"
			btn.Active = false
			btn.ImageTransparency = 0
			setAllVisible(false)
		end

		-- FriendBonus는 LuckUp Lv2 필요
		if skillName == "FriendBonus" and (data.levels["LuckUp"] or 0) < 2 then
			lockNode()
			continue
		end

		-- FP 화폐 노드(HitZoneUp, WeightUp, PowerUp)는 FishingPoint Lv1 필요
		if (skillName == "HitZoneUp" or skillName == "WeightUp" or skillName == "PowerUp")
			and (data.levels["FishingPoint"] or 0) < 1 then
			lockNode()
			continue
		end

		-- HitZoneUp은 PowerUp Lv1 필요
		if skillName == "HitZoneUp" and (data.levels["PowerUp"] or 0) < 1 then
			lockNode()
			continue
		end

		-- AutoUp은 AutoFish Lv1 필요
		if skillName == "AutoUp" and (data.levels["AutoFish"] or 0) < 1 then
			lockNode()
			continue
		end

		-- QuickBite는 AutoFish Lv1 필요
		if skillName == "QuickBite" and (data.levels["AutoFish"] or 0) < 1 then
			lockNode()
			continue
		end

		-- PointBoost는 SellBonus Lv1 필요
		if skillName == "PointBoost" and (data.levels["SellBonus"] or 0) < 1 then
			lockNode()
			continue
		end

		-- Root 미해금 시 Root 외 전부 잠금
		if not rootUnlocked and skillName ~= "Root" then
			lockNode()
			continue
		end

		if stage <= curLevel then
			-- 이미 구매된 단계
			btn.Image = "rbxassetid://125922144537144"
			btn.Active = false
			setAllVisible(true)
			if reqLabel then reqLabel.Visible = false end
			local coinIcon = btn:FindFirstChild("CoinIcon")
			if coinIcon then coinIcon.Visible = false end
			local fishIcon = btn:FindFirstChild("FishIcon")
			if fishIcon then fishIcon.Visible = false end
		elseif stage == curLevel + 1 then
			-- 구매 가능한 다음 단계
			btn.Image = "rbxassetid://132014904422528"
			btn.Active = true
			setAllVisible(true)
			local cost    = cfg.costs[stage]
			local balance = cfg.currency == "Coins" and data.coins or data.fishingPoints
			if reqLabel then
				reqLabel.Visible = true
				reqLabel.Text    = formatNumber(cost)
				reqLabel.TextColor3 = balance < cost
					and Color3.fromRGB(255, 48, 51)
					or  Color3.fromRGB(255, 255, 255)
			end
		else
			-- 아직 잠긴 단계
			lockNode()
		end
	end

	-- CoinText / FishingPointText 업데이트
	local coinText  = skillTreeGui:FindFirstChild("CoinText", true)
	local fpText    = skillTreeGui:FindFirstChild("FishingPointText", true)
	if coinText then coinText.Text = formatNumber(data.coins) end
	if fpText   then fpText.Text   = formatNumber(data.fishingPoints) end
end

local lastClickedBtn = nil

-- ── 버튼 등록 ────────────────────────────────────────────────────────────────
local function setupSkillButton(btn)
	local skillName, stage = parseNodeName(btn.Name)
	if not skillName or not stage then return end
	btn.MouseButton1Click:Connect(function()
		local data = getSkillData:InvokeServer()
		if not btn.Active then
			if data then
				local cfg = data.skills[skillName]
				local curLevel = data.levels[skillName] or 0
				if cfg and stage == curLevel + 1 then
					local cost    = cfg.costs[stage]
					local balance = cfg.currency == "Coins" and data.coins or data.fishingPoints
					if balance < cost then
						errorSound:Play()
						noticeEvent:Fire("Not enough " .. cfg.currency .. "! Need " .. formatNumber(cost))
					end
				end
			end
			return
		end
		if data then
			local cfg = data.skills[skillName]
			if cfg then
				local cost    = cfg.costs[stage]
				local balance = cfg.currency == "Coins" and data.coins or data.fishingPoints
				if balance < cost then
					errorSound:Play()
					noticeEvent:Fire("Not enough " .. cfg.currency .. "! Need " .. formatNumber(cost))
					return
				end
			end
		end
		lastClickedBtn = btn
		skillBuyEvent:FireServer(skillName, stage)
	end)
end

local canvas = getCanvas()
if canvas then
	for _, btn in ipairs(canvas:GetDescendants()) do
		if btn:IsA("ImageButton") and btn.Name:match("^SkillNode_") then
			setupSkillButton(btn)
		end
	end
	canvas.DescendantAdded:Connect(function(obj)
		if obj:IsA("ImageButton") and obj.Name:match("^SkillNode_") then
			setupSkillButton(obj)
		end
	end)
end

local function playBuyTween(btn)
	local uiScale = btn:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = btn
	end
	uiScale.Scale = 1
	TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.3}):Play()
	task.delay(0.12, function()
		TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end)
end

-- ── 구매 결과 ────────────────────────────────────────────────────────────────
skillBuyEvent.OnClientEvent:Connect(function(result)
	if result == "success" then
		robuxBuySound:Play()
		if lastClickedBtn then playBuyTween(lastClickedBtn) end
		refreshUI()
	end
end)

-- ── 노드 UIScale 수집 헬퍼 ──────────────────────────────────────────────────
local function getNodeScales()
	local canvas = getCanvas()
	if not canvas then return {} end
	local scales = {}
	for _, btn in ipairs(canvas:GetChildren()) do
		if btn:IsA("ImageButton") and btn.Name:match("^SkillNode_") then
			local uiScale = btn:FindFirstChildOfClass("UIScale")
			if not uiScale then
				uiScale = Instance.new("UIScale")
				uiScale.Parent = btn
			end
			table.insert(scales, uiScale)
		end
	end
	return scales
end

-- ── 열릴 때 팝인 트윈 (동시) ─────────────────────────────────────────────────
local function playOpenTween()
	for _, uiScale in ipairs(getNodeScales()) do
		uiScale.Scale = 0
		TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end
end

-- ── 닫기: 축소 트윈 후 Enabled=false ─────────────────────────────────────────
local function closeSkillTree()
	local scales = getNodeScales()
	for _, uiScale in ipairs(scales) do
		TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0}):Play()
	end
	if closePendingTask then task.cancel(closePendingTask) end
	closePendingTask = task.delay(0.2, function()
		closePendingTask = nil
		skillTreeGui.Enabled = false
	end)
end

-- ── 닫기 버튼 연결 ───────────────────────────────────────────────────────────
local closeBtn = skillTreeGui:FindFirstChild("Close") and skillTreeGui.Close:FindFirstChild("TextButton")
if closeBtn then
	closeBtn.MouseButton1Click:Connect(closeSkillTree)
end

-- ── 모바일 드래그 + 핀치줌 ──────────────────────────────────────────────────
local function getViewport()
	local bg = skillTreeGui:FindFirstChild("BackGround")
	return bg and bg:FindFirstChild("Viewport")
end

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

if isMobile then
	local activeTouches = {}  -- input object → true
	local dragTouch = nil
	local dragTouchStartPos = nil  -- Vector2 snapshot of touch start position
	local pinchTouch1, pinchTouch2 = nil, nil
	local pinchStartDist = 0
	local canvasStartPos = nil
	local pinchStartScale = 1
	local MIN_SCALE, MAX_SCALE = 0.25, 2.0

	local function getCanvasScale()
		local canvas = getCanvas()
		if not canvas then return 1 end
		local us = canvas:FindFirstChildOfClass("UIScale")
		return us and us.Scale or 1
	end

	local function setCanvasScale(s)
		local canvas = getCanvas()
		if not canvas then return end
		local us = canvas:FindFirstChildOfClass("UIScale")
		if not us then
			us = Instance.new("UIScale")
			us.Parent = canvas
		end
		us.Scale = math.clamp(s, MIN_SCALE, MAX_SCALE)
	end

	local function getTouchCount()
		local n = 0
		for _ in pairs(activeTouches) do n += 1 end
		return n
	end

	local function getTouchList()
		local list = {}
		for t in pairs(activeTouches) do table.insert(list, t) end
		return list
	end

	local vp = getViewport()
	if vp then
		vp.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then return end
			activeTouches[input] = true
			local count = getTouchCount()
			if count == 1 then
				dragTouch = input
				dragTouchStartPos = Vector2.new(input.Position.X, input.Position.Y)
				local c = getCanvas()
				canvasStartPos = c and c.Position
			elseif count == 2 then
				dragTouch = nil
				local list = getTouchList()
				pinchTouch1 = list[1]
				pinchTouch2 = list[2]
				pinchStartDist = (pinchTouch1.Position - pinchTouch2.Position).Magnitude
				pinchStartScale = getCanvasScale()
			end
		end)

		vp.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then return end
			local count = getTouchCount()
			if count >= 2 and pinchTouch1 and pinchTouch2 then
				local d = (pinchTouch1.Position - pinchTouch2.Position).Magnitude
				if pinchStartDist > 0 then
					setCanvasScale(pinchStartScale * (d / pinchStartDist))
				end
			elseif count == 1 and dragTouch and dragTouchStartPos then
				local canvas = getCanvas()
				if canvas and canvasStartPos then
					local delta = Vector2.new(input.Position.X, input.Position.Y) - dragTouchStartPos
					canvas.Position = UDim2.new(
						canvasStartPos.X.Scale,
						canvasStartPos.X.Offset + delta.X,
						canvasStartPos.Y.Scale,
						canvasStartPos.Y.Offset + delta.Y
					)
				end
			end
		end)

		vp.InputEnded:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then return end
			activeTouches[input] = nil
			local count = getTouchCount()
			if count < 2 then
				pinchTouch1, pinchTouch2 = nil, nil
			end
			if count == 0 then
				dragTouch = nil
			end
		end)
	end
end

-- ── PC 드래그 + 스크롤 줌 ───────────────────────────────────────────────────
if not isMobile then
	local PC_MIN_SCALE, PC_MAX_SCALE = 0.4, 2.0
	local isDragging = false
	local dragStartMouse = nil
	local dragStartCanvasPos = nil

	local function getPCCanvas()
		return getCanvas()
	end

	local function getPCCanvasScale()
		local c = getPCCanvas()
		if not c then return 1 end
		local us = c:FindFirstChildOfClass("UIScale")
		return us and us.Scale or 1
	end

	local function setPCCanvasScale(s)
		local c = getPCCanvas()
		if not c then return end
		local us = c:FindFirstChildOfClass("UIScale")
		if not us then
			us = Instance.new("UIScale")
			us.Parent = c
		end
		us.Scale = math.clamp(s, PC_MIN_SCALE, PC_MAX_SCALE)
	end

	local vp = getViewport()
	if vp then
		vp.InputBegan:Connect(function(input)
			if not skillTreeGui.Enabled then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2 then
				isDragging = true
				dragStartMouse = Vector2.new(input.Position.X, input.Position.Y)
				local c = getPCCanvas()
				dragStartCanvasPos = c and c.Position
			end
		end)

		vp.InputChanged:Connect(function(input)
			if not skillTreeGui.Enabled then return end
			if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local c = getPCCanvas()
				if c and dragStartCanvasPos and dragStartMouse then
					local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStartMouse
					c.Position = UDim2.new(
						dragStartCanvasPos.X.Scale,
						dragStartCanvasPos.X.Offset + delta.X,
						dragStartCanvasPos.Y.Scale,
						dragStartCanvasPos.Y.Offset + delta.Y
					)
				end
			elseif input.UserInputType == Enum.UserInputType.MouseWheel then
				local cur = getPCCanvasScale()
				setPCCanvasScale(cur + input.Position.Z * 0.1)
			end
		end)

		vp.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2 then
				isDragging = false
			end
		end)
	end
end

-- ── 열릴 때 Canvas 초기 스케일 설정 ────────────────────────────────────────
local CANVAS_DEFAULT_POSITION = UDim2.new(0.5, 0, 0.5, 0)

local function applyInitialCanvasScale()
	local c = getCanvas()
	if not c then return end
	local us = c:FindFirstChildOfClass("UIScale")
	if not us then
		us = Instance.new("UIScale")
		us.Parent = c
	end
	local vp = workspace.CurrentCamera.ViewportSize
	local shortSide = math.min(vp.X, vp.Y)
	local scale
	if isMobile then
		scale = math.clamp(shortSide / 900, 0.25, 0.55)
	else
		scale = math.clamp(shortSide / 800, 0.45, 1.0)
	end
	us.Scale = scale
	c.Position = CANVAS_DEFAULT_POSITION
end

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	if skillTreeGui.Enabled then applyInitialCanvasScale() end
end)

-- ── 스킬트리 열기/닫기 감지 ──────────────────────────────────────────────────
skillTreeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if skillTreeGui.Enabled then
		if closePendingTask then
			task.cancel(closePendingTask)
			closePendingTask = nil
		end
		player.PlayerGui:SetAttribute("ActiveLargeUI", "SkillTree")
		applyInitialCanvasScale()
		refreshUI()
		playOpenTween()
	else
		player.PlayerGui:SetAttribute("ActiveLargeUI", nil)
	end
end)

-- ── 초기 로드 ────────────────────────────────────────────────────────────────
task.spawn(function()
	player:WaitForChild("DataReady", 30)
	task.wait(0.5)
	refreshUI()
end)
