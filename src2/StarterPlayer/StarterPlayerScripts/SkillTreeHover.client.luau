local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local skillTreeGui = playerGui:WaitForChild("SkillTree")
local mouse = player:GetMouse()

local template = skillTreeGui:WaitForChild("SkillNodeDescTemplate")

template.Visible = false

local SCALE_UP   = 1.12
local SCALE_DOWN = 1.0
local TWEEN_IN   = TweenInfo.new(0.15, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local TWEEN_OUT  = TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function getDesc(skillName, stage)
	local descs = {
		LuckUp = {
			"Increases rare fish chance by 10%.",
			"Increases rare fish chance by 30%.",
			"Increases rare fish chance by 60%.",
			"Increases rare fish chance by 100%.",
			"Increases rare fish chance by 150%.",
			"Increases rare fish chance by 200%.",
			"Increases rare fish chance by 250%.",
		},
		SellBonus = {
			"Increases fish sell value by 10%.",
			"Increases fish sell value by 20%.",
			"Increases fish sell value by 30%.",
			"Increases fish sell value by 40%.",
			"Increases fish sell value by 50%.",
			"Increases fish sell value by 65%.",
		},
		FriendBonus = {
			"Increases luck by 15% per online friend.",
			"Increases luck by 30% per online friend.",
			"Increases luck by 50% per online friend.",
		},
		HitZoneUp = {
			"Increases minigame hit zone size by 6%.",
			"Increases minigame hit zone size by 10%.",
			"Increases minigame hit zone size by 15%.",
			"Increases minigame hit zone size by 21%.",
			"Increases minigame hit zone size by 28%.",
		},
		WeightUp = {
			"Heavy fish chance +4%.",
			"Heavy fish chance +10%.",
			"Heavy fish chance +18%.",
			"Heavy fish chance +28%.",
		},
		PowerUp = {
			"Increases rod power by 5%.",
			"Increases rod power by 10%.",
			"Increases rod power by 20%.",
		},
		AutoUp = {
			"Auto fishing click speed +0.1s.",
			"Auto fishing click speed +0.4s.",
			"Auto fishing click speed +0.8s.",
		},
		QuickBite = {
			"Fish bite wait -0.5s.",
			"Fish bite wait -1.5s.",
			"Fish bite wait -2.5s.",
		},
		PointBoost = {
			"Earn +1 extra Fishing Point per catch.",
			"Earn +2 extra Fishing Points per catch.",
			"Earn +3 extra Fishing Points per catch.",
		},
		Root         = {"Unlocks the skill tree."},
		AutoFish     = {"Enables the auto fishing button."},
		FishingPoint = {"Unlocks Fishing Point skill tree (HitZoneUp, WeightUp, PowerUp)."},
	}

	local list = descs[skillName]
	return (list and list[stage]) or ""
end

local currentDesc = nil
local hoveredButton = nil

local function removeDesc()
	if currentDesc then
		currentDesc:Destroy()
		currentDesc = nil
	end
end

local function isNodeLocked(button)
	local nodeName = button:FindFirstChild("NodeName")
	return nodeName and not nodeName.Visible
end

local function wrapText(text, charsPerLine)
	local result = {}
	for _, line in ipairs(text:split("\n")) do
		if #line <= charsPerLine then
			table.insert(result, line)
		else
			local pos = 1
			while pos <= #line do
				local chunk = line:sub(pos, pos + charsPerLine - 1)
				-- 단어 중간 자르지 않도록 마지막 공백 기준으로 자르기
				if pos + charsPerLine - 1 < #line then
					local lastSpace = chunk:match(".*()%s")
					if lastSpace and lastSpace > charsPerLine * 0.5 then
						chunk = line:sub(pos, pos + lastSpace - 2)
						pos = pos + lastSpace - 1
					else
						pos = pos + charsPerLine
					end
				else
					pos = #line + 1
				end
				table.insert(result, chunk)
			end
		end
	end
	return table.concat(result, "\n")
end

local function showDesc(button, skillName, stage)
	removeDesc()

	local clone = template:Clone()
	clone.Visible = true
	clone.AnchorPoint = Vector2.new(0.5, 0.5)
	clone.ZIndex = 30
	clone.Parent = skillTreeGui

	-- UIAspectRatioConstraint 제거 — 크기를 직접 제어
	local arc = clone:FindFirstChildOfClass("UIAspectRatioConstraint")
	if arc then arc:Destroy() end

	local vp = workspace.CurrentCamera.ViewportSize
	local shortSide = math.min(vp.X, vp.Y)

	-- 해상도 비례 크기: 짧은 쪽 기준 (모바일/PC 모두 대응)
	local w = math.clamp(shortSide * 0.42, 180, 340)
	local titleSize = math.clamp(shortSide * 0.034, 14, 26)
	local descSize  = math.clamp(shortSide * 0.026, 11, 20)
	local charsPerLine = math.floor(w / (descSize * 0.55))

	local titleLabel = clone:FindFirstChild("Title")
	local descLabel  = clone:FindFirstChild("Desc")

	local nodeNameLabel = button:FindFirstChild("NodeName")
	if titleLabel and nodeNameLabel then
		titleLabel.Text = nodeNameLabel.Text
		titleLabel.TextScaled = false
		titleLabel.TextSize = titleSize
	end

	local descText = ""
	if descLabel then
		descText = wrapText(getDesc(skillName, stage), charsPerLine)
		descLabel.Text = descText
		descLabel.TextScaled = false
		descLabel.TextSize = descSize
		descLabel.TextWrapped = false
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
	end

	-- 줄 수 기반 높이 계산
	local lineCount = select(2, descText:gsub("\n", "\n")) + 1
	local h = titleSize * 1.8 + descSize * 1.5 * lineCount + 28

	clone.Size = UDim2.fromOffset(w, h)

	-- 노드 오른쪽 중앙에 배치 (AnchorPoint 0.5,0.5 기준 — Position = 프레임 중심)
	local nodePos  = button.AbsolutePosition
	local nodeSize = button.AbsoluteSize

	-- Canvas UIScale 직접 읽어 노드 렌더 크기 보정 (AbsoluteSize가 0 반환 시 대비)
	local canvas = skillTreeGui:FindFirstChild("BackGround")
		and skillTreeGui.BackGround:FindFirstChild("Viewport")
		and skillTreeGui.BackGround.Viewport:FindFirstChild("Canvas")
	local canvasScale = canvas and canvas:FindFirstChildOfClass("UIScale") and canvas:FindFirstChildOfClass("UIScale").Scale or 1
	local NODE_BASE_SIZE = 160
	local nodeW = nodeSize.X > 1 and nodeSize.X or (NODE_BASE_SIZE * canvasScale)
	local nodeH = nodeSize.Y > 1 and nodeSize.Y or (NODE_BASE_SIZE * canvasScale)

	local cx = nodePos.X + nodeW + 12 + w / 2
	local cy = nodePos.Y + nodeH / 2 + nodeH * 0.35

	if cx + w / 2 > vp.X - 8 then
		cx = nodePos.X - 12 - w / 2
	end
	cy = math.clamp(cy, h / 2 + 8, vp.Y - h / 2 - 8)

	clone.Position = UDim2.fromOffset(cx, cy)

	local uiScale = clone:FindFirstChildOfClass("UIScale")
	if uiScale then
		uiScale.Scale = 0.85
		TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end

	currentDesc = clone
end

local function isMouseOver(gui)
	local pos  = gui.AbsolutePosition
	local size = gui.AbsoluteSize
	local mx, my = mouse.X, mouse.Y
	return mx >= pos.X and mx <= pos.X + size.X and my >= pos.Y and my <= pos.Y + size.Y
end

local function getNodeUIScale(button)
	local uiScale = button:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = button
	end
	return uiScale
end

local nodes = {}

local function refreshNodes()
	nodes = {}
	for _, obj in ipairs(skillTreeGui:GetDescendants()) do
		if obj:IsA("GuiButton") and obj.Name:match("^SkillNode_") then
			local skillName, stageStr = obj.Name:match("^SkillNode_(.+)_(%d+)$")
			table.insert(nodes, {button = obj, skillName = skillName, stage = tonumber(stageStr)})
			getNodeUIScale(obj)
		end
	end
end

skillTreeGui.DescendantAdded:Connect(function(obj)
	if obj:IsA("GuiButton") and obj.Name:match("^SkillNode_") then
		task.defer(refreshNodes)
	end
end)

refreshNodes()

RunService.Heartbeat:Connect(function()
	if not skillTreeGui.Enabled then
		if hoveredButton then
			TweenService:Create(getNodeUIScale(hoveredButton), TWEEN_OUT, {Scale = SCALE_DOWN}):Play()
			hoveredButton = nil
			removeDesc()
		end
		return
	end

	local found = nil
	for _, entry in ipairs(nodes) do
		if entry.button and entry.button.Parent and isMouseOver(entry.button) then
			found = entry
			break
		end
	end

	if found then
		if hoveredButton ~= found.button then
			if hoveredButton then
				TweenService:Create(getNodeUIScale(hoveredButton), TWEEN_OUT, {Scale = SCALE_DOWN}):Play()
			end
			hoveredButton = found.button
			TweenService:Create(getNodeUIScale(hoveredButton), TWEEN_IN, {Scale = SCALE_UP}):Play()

			if not isNodeLocked(found.button) then
				showDesc(found.button, found.skillName, found.stage)
			end
		end
	else
		if hoveredButton then
			TweenService:Create(getNodeUIScale(hoveredButton), TWEEN_OUT, {Scale = SCALE_DOWN}):Play()
			hoveredButton = nil
			removeDesc()
		end
	end
end)

skillTreeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not skillTreeGui.Enabled then
		hoveredButton = nil
		removeDesc()
	end
end)
