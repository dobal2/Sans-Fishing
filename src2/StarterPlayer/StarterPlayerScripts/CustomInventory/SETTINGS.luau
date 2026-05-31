local module = {OBJECTS = {}, SETTINGS = {}, slotAmount = 9}
module.OBJECTS.HotBar = {}
module.OBJECTS.Inventory = {}

-- Fish inventory data (client-side mirror of server PlayerFishData)
module.FishList = {}           -- array of fishItem tables
module.equippedFishIndex = nil -- currently equipped fish index
module.HotBarFish = {}         -- [slotIndex] = fishIndex (fish pinned to hotbar slots)

-- SETTINGS
local SETTINGS = module.SETTINGS
SETTINGS.DEFAULT_COLOR = Color3.fromRGB(0, 0, 0)
SETTINGS.EQUIPPED_COLOR = Color3.fromRGB(128, 128, 128)
SETTINGS.DISABLED_COLOR = Color3.fromRGB(128, 64, 65)
SETTINGS.DEFAULT_IMAGEID = ""
SETTINGS.EQUIPPED_IMAGEID = ""
SETTINGS.DISABLED_IMAGEID = ""
SETTINGS.INVENTORY_KEYBIND = Enum.KeyCode.Backquote
SETTINGS.DRAG_OUTSIDE_TO_DROP = false
SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR = true
SETTINGS.SCROLL_HOTBAR_WITH_WHEEL = false
SETTINGS.EQUIP_TOUCH_SENSITIVITY = 60
SETTINGS.OPEN_BUTTON = true
SETTINGS.ALWAYS_SHOW_TOOL_NAME = true

local ContextActionService = game:GetService("ContextActionService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local inventoryGui = playerGui:WaitForChild("Custom Inventory")
local hotbar = inventoryGui:WaitForChild("hotBar")
local inventoryFrame = inventoryGui:WaitForChild("Inventory")
local toolButton = inventoryGui:WaitForChild("toolButton")

local fishLockRemote = ReplicatedStorage:WaitForChild("FishLockEvent")

-- Forward declarations for cross-referencing fish UI functions
local rebuildFishInventory
local rebuildHotBarFish

-- Equip/unequip remotes (wired lazily)
local equipFishRemote = nil
local unequipFishRemote = nil

task.spawn(function()
	local Misc = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc")
	equipFishRemote   = Misc:WaitForChild("EquipFishRequest")
	unequipFishRemote = Misc:WaitForChild("UnequipFishRequest")
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Inventory size helper
-- ─────────────────────────────────────────────────────────────────────────────

local function updateInventorySize()
	local itemCount = #module.FishList
	for _ in pairs(module.OBJECTS.Inventory) do
		-- non-fish tool objects also count
		itemCount = itemCount + 0 -- already counted in FishList; tool objects are rods/bubbles
	end
	-- Count actual frames in inventory
	local frameCount = 0
	if inventoryFrame and inventoryFrame.Frame then
		for _ in pairs(inventoryFrame.Frame:GetChildren()) do
			frameCount = frameCount + 1
		end
	end
	local rows = math.max(5, math.ceil(frameCount / 10))
	local neededHeight = rows * 52 + 6
	if inventoryFrame and inventoryFrame.Frame then
		inventoryFrame.Frame.CanvasSize = UDim2.new(0, 0, 0, neededHeight)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Fish count
-- ─────────────────────────────────────────────────────────────────────────────

function module:getFishCount()
	return #self.FishList
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Description tooltip (shared)
-- ─────────────────────────────────────────────────────────────────────────────

function module:removeCurrentDescription()
	local descriptionFrame = inventoryGui:FindFirstChild("descriptionFrame")
	if descriptionFrame then
		descriptionFrame:Destroy()
	end
end

local function showDescriptionForFrame(frame, text)
	local existing = inventoryGui:FindFirstChild("descriptionFrame")
	if existing then existing:Destroy() end

	local FONT = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
	local TEXT_SIZE = 13
	local PAD_X, PAD_Y = 10, 6

	local bg = Instance.new("Frame")
	bg.Name = "descriptionFrame"
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bg.BackgroundTransparency = 0.15
	bg.BorderSizePixel = 0
	bg.AutomaticSize = Enum.AutomaticSize.XY
	bg.Size = UDim2.new(0, 0, 0, 0)
	bg.ZIndex = 200
	bg.Parent = inventoryGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bg

	local uipad = Instance.new("UIPadding")
	uipad.PaddingLeft   = UDim.new(0, PAD_X)
	uipad.PaddingRight  = UDim.new(0, PAD_X)
	uipad.PaddingTop    = UDim.new(0, PAD_Y)
	uipad.PaddingBottom = UDim.new(0, PAD_Y)
	uipad.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.7
	stroke.Thickness = 1
	stroke.Parent = bg

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.6
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.FontFace = FONT
	label.TextSize = TEXT_SIZE
	label.TextWrapped = false
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Text = text
	label.ZIndex = 201
	label.Size = UDim2.new(0, 0, 0, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Parent = bg

	task.spawn(function()
		RunService.RenderStepped:Wait()
		if not bg.Parent then return end
		local realW = bg.AbsoluteSize.X
		local realH = bg.AbsoluteSize.Y
		local guiOrigin = inventoryGui.AbsolutePosition
		local frameAbsX = frame.AbsolutePosition.X
		local frameAbsY = frame.AbsolutePosition.Y
		local ax = (frameAbsX - guiOrigin.X) + frame.AbsoluteSize.X / 2 - realW / 2
		local ay = (frameAbsY - guiOrigin.Y) - realH - 4
		local vpSize = inventoryGui.AbsoluteSize
		ax = math.clamp(ax, 4, vpSize.X - realW - 4)
		if ay < 4 then ay = (frameAbsY - guiOrigin.Y) + frame.AbsoluteSize.Y + 4 end
		bg.Position = UDim2.new(0, ax, 0, ay)
	end)

	game:GetService("Debris"):AddItem(bg, 10)
end

-- Fish slot rendering
-- ─────────────────────────────────────────────────────────────────────────────

local MAX_NAME_LEN = 18

local function truncateName(name)
	if #name > MAX_NAME_LEN then
		return name:sub(1, MAX_NAME_LEN - 1) .. "…"
	end
	return name
end

local RARITY_COLORS = {
	Common    = Color3.fromRGB(200, 200, 200),
	Uncommon  = Color3.fromRGB(100, 200, 100),
	Rare      = Color3.fromRGB(100, 140, 220),
	Epic      = Color3.fromRGB(180, 100, 220),
	Legendary = Color3.fromRGB(255, 200, 50),
	Mystic    = Color3.fromRGB(255, 100, 50),
	Fantasy   = Color3.fromRGB(135, 206, 235),
	Unknown   = Color3.fromRGB(10, 10, 10),
}

local function createFishSlotFrame(fishItem, index)
	local frame = toolButton:Clone()

	frame.Visible = true
	frame.Name = "fish_" .. index
	frame.LayoutOrder = index

	-- Name label
	local nameLabel = frame:FindFirstChild("toolName")
	if nameLabel then
		nameLabel.Text = truncateName(fishItem.name)
		nameLabel.Visible = true
		-- Rarity color tint
		local rarityColor = RARITY_COLORS[fishItem.rarity]
		if rarityColor then
			nameLabel.TextColor3 = rarityColor
		end
	end

	-- Number (show index)
	local numLabel = frame:FindFirstChild("toolNumber")
	if numLabel then numLabel.Text = "" end

	local amtLabel = frame:FindFirstChild("toolAmount")
	if amtLabel then amtLabel.Text = "" end

	-- Clear icon
	local iconLabel = frame:FindFirstChild("toolIcon")
	if iconLabel then
		iconLabel.Image = ""
		iconLabel.Visible = false
	end

	-- Lock icon
	if fishItem.isLocked then
		local lockIcon = Instance.new("ImageLabel")
		lockIcon.Name = "FishLockIcon"
		lockIcon.Size = UDim2.new(0.35, 0, 0.35, 0)
		lockIcon.Position = UDim2.new(0.65, 0, 0, 0)
		lockIcon.BackgroundTransparency = 1
		lockIcon.Image = "rbxassetid://10333789558"
		lockIcon.ScaleType = Enum.ScaleType.Fit
		lockIcon.ZIndex = 10
		lockIcon.Parent = frame
	end

	-- UIStroke 확정 (두께 보장 + rarity 테두리)
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then stroke:Destroy() end
	stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 2
	if index == module.equippedFishIndex then
		stroke.Color = Color3.new(1, 1, 1)
		frame.Image = SETTINGS.EQUIPPED_IMAGEID
	else
		local rarityColor = RARITY_COLORS[fishItem.rarity]
		stroke.Color = rarityColor and rarityColor or Color3.fromRGB(80, 80, 80)
	end
	stroke.Parent = frame

	return frame
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Drag drop helper: GUI 계층을 올라가며 hotbar/inventoryFrame 직계 ImageButton 찾기
-- ─────────────────────────────────────────────────────────────────────────────

local function resolveDropTarget(guiObject)
	local cur = guiObject
	for _ = 1, 8 do
		if cur == nil then break end
		if cur:IsA("ImageButton") then
			local p = cur.Parent
			if p == hotbar or p == inventoryFrame.Frame then
				return cur
			end
		end
		cur = cur.Parent
	end
	return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- HotBar fish slots
-- ─────────────────────────────────────────────────────────────────────────────

local EnumKeys = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
	Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
	Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}

-- fish 연결 정보를 슬롯 frame에 직접 저장/읽기 (attribute 사용)
local hotBarFishConnections = {}  -- [slotIndex] = {conn1, conn2, ...}

local function disconnectHotBarFishSlot(slotIndex)
	if not slotIndex then return end
	ContextActionService:UnbindAction(slotIndex .. "hotBar")
	if hotBarFishConnections[slotIndex] then
		for _, c in ipairs(hotBarFishConnections[slotIndex]) do c:Disconnect() end
		hotBarFishConnections[slotIndex] = nil
	end
end

local function clearHotBarFishSlot(slotIndex)
	disconnectHotBarFishSlot(slotIndex)
	module.HotBarFish[slotIndex] = nil

	local slotFrame = hotbar:FindFirstChild(tostring(slotIndex))
	if not slotFrame then
		local newFrame = toolButton:Clone()
		newFrame.Visible = true
		newFrame.Name = tostring(slotIndex)
		local nameLabel = newFrame:FindFirstChild("toolName")
		if nameLabel then nameLabel.Text = "" end
		local numLabel = newFrame:FindFirstChild("toolNumber")
		if numLabel then numLabel.Text = tostring(slotIndex) end
		local ta = newFrame:FindFirstChild("toolAmount")
		if ta then ta.Text = "" end
		newFrame.Parent = hotbar
		if _G.saveFishHotBarPins then _G.saveFishHotBarPins() end
		return
	end

	local nameLabel = slotFrame:FindFirstChild("toolName")
	if nameLabel then
		nameLabel.Text = ""
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
	end
	local iconLabel = slotFrame:FindFirstChild("toolIcon")
	if iconLabel then iconLabel.Image = "" end
	local lockIcon = slotFrame:FindFirstChild("FishLockIcon")
	if lockIcon then lockIcon:Destroy() end
	local stroke = slotFrame:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = Color3.new(0, 0, 0) end
	slotFrame.Image = SETTINGS.DEFAULT_IMAGEID

	if _G.saveFishHotBarPins then _G.saveFishHotBarPins() end
end

local function setHotBarFishSlot(slotIndex, fishIndex)
	if not slotIndex then return end
	disconnectHotBarFishSlot(slotIndex)

	local fishItem = module.FishList[fishIndex]
	if not fishItem then
		module.HotBarFish[slotIndex] = nil
		return
	end

	-- 슬롯 frame 확보 (없으면 생성)
	local slotFrame = hotbar:FindFirstChild(tostring(slotIndex))
	if not slotFrame then
		slotFrame = toolButton:Clone()
		slotFrame.Visible = true
		slotFrame.Name = tostring(slotIndex)
		local nl = slotFrame:FindFirstChild("toolNumber"); if nl then nl.Text = tostring(slotIndex) end
		slotFrame.Parent = hotbar
	end

	module.HotBarFish[slotIndex] = fishIndex

	local nameLabel = slotFrame:FindFirstChild("toolName")
	if nameLabel then
		nameLabel.Text = truncateName(fishItem.name)
		nameLabel.Visible = true
		local rarityColor = RARITY_COLORS[fishItem.rarity]
		nameLabel.TextColor3 = rarityColor or Color3.new(1, 1, 1)
	end
	local iconLabel = slotFrame:FindFirstChild("toolIcon")
	if iconLabel then iconLabel.Image = ""; iconLabel.Visible = false end

	-- UIStroke 확보: 항상 새로 생성해서 두께/모드 확정
	local stroke = slotFrame:FindFirstChildOfClass("UIStroke")
	if stroke then stroke:Destroy() end
	stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 2
	stroke.Parent = slotFrame  -- Parent 설정 후 UIStrokeScale이 trackStroke

	-- Equip highlight
	if fishIndex == module.equippedFishIndex then
		stroke.Color = Color3.new(1, 1, 1)
		slotFrame.Image = SETTINGS.EQUIPPED_IMAGEID
	else
		local rarityColor = RARITY_COLORS[fishItem.rarity]
		stroke.Color = rarityColor and rarityColor or Color3.fromRGB(80, 80, 80)
		slotFrame.Image = SETTINGS.DEFAULT_IMAGEID
	end

	-- Lock icon
	local lockIcon = slotFrame:FindFirstChild("FishLockIcon")
	if fishItem.isLocked then
		if not lockIcon then
			lockIcon = Instance.new("ImageLabel")
			lockIcon.Name = "FishLockIcon"
			lockIcon.Size = UDim2.new(0.35, 0, 0.35, 0)
			lockIcon.Position = UDim2.new(0.65, 0, 0, 0)
			lockIcon.BackgroundTransparency = 1
			lockIcon.Image = "rbxassetid://10333789558"
			lockIcon.ScaleType = Enum.ScaleType.Fit
			lockIcon.ZIndex = 10
			lockIcon.Parent = slotFrame
		end
	else
		if lockIcon then lockIcon:Destroy() end
	end

	-- Bind number key for this hotbar slot
	ContextActionService:BindAction(slotIndex .. "hotBar", function(_, inputState, inputObject)
		if inputObject and inputObject.UserInputType ~= Enum.UserInputType.Keyboard and inputObject.UserInputType ~= Enum.UserInputType.Touch then return end
		if inputState ~= Enum.UserInputState.Begin then return end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end
		local currentFishIndex = module.HotBarFish[slotIndex]
		if not currentFishIndex then return end
		if module.equippedFishIndex == currentFishIndex then
			module.equippedFishIndex = nil
			if unequipFishRemote then pcall(function() unequipFishRemote:FireServer() end) end
		else
			module.equippedFishIndex = currentFishIndex
			if equipFishRemote then pcall(function() equipFishRemote:FireServer(currentFishIndex) end) end
		end
		rebuildHotBarFish()
		rebuildFishInventory()
	end, false, EnumKeys[slotIndex])

	local conns = {}
	local isDraggingHB = false

	table.insert(conns, slotFrame.MouseButton1Down:Connect(function()
		local clickStartPos = Vector2.new(mouse.X, mouse.Y)
		isDraggingHB = false
		local dragThreshold = 10
		local ghostFrame = nil
		local mouseConn, mouseEnd

		local function endDragHB()
			if mouseConn then mouseConn:Disconnect() end
			if mouseEnd then mouseEnd:Disconnect() end

			if not isDraggingHB then
				if ghostFrame then ghostFrame:Destroy() end
				-- short click → equip/unequip
				if module.equippedFishIndex == fishIndex then
					module.equippedFishIndex = nil
					if unequipFishRemote then pcall(function() unequipFishRemote:FireServer() end) end
				else
					module.equippedFishIndex = fishIndex
					if equipFishRemote then pcall(function() equipFishRemote:FireServer(fishIndex) end) end
				end
				rebuildHotBarFish()
				rebuildFishInventory()
				return
			end

			-- ghost 제거 후 한 프레임 대기해야 GetGuiObjectsAtPosition이 올바르게 동작함
			if ghostFrame then ghostFrame:Destroy(); ghostFrame = nil end
			local dropX, dropY = mouse.X, mouse.Y
			task.defer(function()

			-- Drop detection
			local droppedGuis = playerGui:GetGuiObjectsAtPosition(dropX, dropY)
			local handled = false
			for _, rawTarget in pairs(droppedGuis) do
				if handled then break end
				local target = resolveDropTarget(rawTarget)
				if not target then continue end

				-- 핫바 다른 슬롯으로 이동
				if target.Parent == hotbar and target ~= slotFrame then
					local targetSlot = tonumber(target.Name)
					if targetSlot then
						local rodObj = module.OBJECTS.HotBar[targetSlot]
						local prevFish = module.HotBarFish[targetSlot]
						if rodObj then
							-- rod 슬롯과 스왑: rod를 현재 fish 슬롯으로, fish를 rod 슬롯으로
							local rodTool = rodObj.Tool
							clearHotBarFishSlot(slotIndex)
							rodObj:DisconnectAll()
							-- DisconnectAll이 targetSlot frame을 Destroy했을 수 있으므로 복원 후 fish 설정
							if not hotbar:FindFirstChild(tostring(targetSlot)) then
								local f = toolButton:Clone()
								f.Visible = true
								f.Name = tostring(targetSlot)
								local nl = f:FindFirstChild("toolNumber"); if nl then nl.Text = tostring(targetSlot) end
								f.Parent = hotbar
							end
							module:addTool(rodTool, "HotBar", slotIndex)
							setHotBarFishSlot(targetSlot, fishIndex)
						else
							-- 빈 슬롯 또는 fish 슬롯
							clearHotBarFishSlot(slotIndex)
							if prevFish then
								setHotBarFishSlot(slotIndex, prevFish)
							end
							setHotBarFishSlot(targetSlot, fishIndex)
						end
						handled = true
					end
				end

				-- 인벤 아이템으로 드롭
				if not handled and target.Parent == inventoryFrame.Frame then
					local targetFishIdx = tonumber(target.Name:match("^fish_(%d+)$"))
					if targetFishIdx then
						-- 인벤 fish↔핫바 fish 스왑
						clearHotBarFishSlot(slotIndex)
						setHotBarFishSlot(slotIndex, targetFishIdx)
					else
						-- 인벤 rod: rod를 핫바로, 핫바 fish를 인벤으로
						local rodObj = module.OBJECTS.Inventory[target.Name]
						if rodObj then
							rodObj:DisconnectAll()
							clearHotBarFishSlot(slotIndex)
							module:addTool(rodObj.Tool, "HotBar", slotIndex)
						else
							clearHotBarFishSlot(slotIndex)
						end
					end
					handled = true
				end
			end
			-- 핫바 fish를 인벤 빈 공간에 드롭 → 핀 해제 (인벤으로 이동)
			if not handled then
				local invAbsPos = inventoryFrame.AbsolutePosition
				local invAbsSize = inventoryFrame.AbsoluteSize
				if dropX >= invAbsPos.X and dropX <= invAbsPos.X + invAbsSize.X
					and dropY >= invAbsPos.Y and dropY <= invAbsPos.Y + invAbsSize.Y then
					clearHotBarFishSlot(slotIndex)
				end
			end
			rebuildFishInventory()
			end) -- task.defer
		end

		mouseEnd = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or
				input.UserInputType == Enum.UserInputType.Touch then
				endDragHB()
			end
		end)

		mouseConn = mouse.Move:Connect(function()
			local currentPos = Vector2.new(mouse.X, mouse.Y)
			if not isDraggingHB and (currentPos - clickStartPos).Magnitude > dragThreshold then
				isDraggingHB = true
				ghostFrame = toolButton:Clone()
				ghostFrame.Visible = true
				local gfName = ghostFrame:FindFirstChild("toolName")
				if gfName then
					gfName.Text = truncateName(fishItem.name)
					local rarityColor = RARITY_COLORS[fishItem.rarity]
					if rarityColor then gfName.TextColor3 = rarityColor end
				end
				ghostFrame.Size = slotFrame.Size
				ghostFrame.AnchorPoint = Vector2.new(0.5, 0.5)
				ghostFrame.ZIndex = 50
				ghostFrame.Parent = inventoryGui
			end
			if isDraggingHB and ghostFrame then
				local guiPos = Vector2.new(mouse.X, mouse.Y) - inventoryGui.AbsolutePosition
				ghostFrame.Position = UDim2.new(0, guiPos.X, 0, guiPos.Y)
			end
		end)
	end))

	-- 우클릭 잠금
	table.insert(conns, slotFrame.MouseButton2Click:Connect(function()
		local fi = module.FishList[fishIndex]
		if not fi then return end
		fi.isLocked = not fi.isLocked
		pcall(function()
			fishLockRemote:FireServer(nil, fi.isLocked, fishIndex)
		end)
		-- 잠금 아이콘 업데이트
		local lockIcon = slotFrame:FindFirstChild("FishLockIcon")
		if fi.isLocked then
			if not lockIcon then
				lockIcon = Instance.new("ImageLabel")
				lockIcon.Name = "FishLockIcon"
				lockIcon.Size = UDim2.new(0.35, 0, 0.35, 0)
				lockIcon.Position = UDim2.new(0.65, 0, 0, 0)
				lockIcon.BackgroundTransparency = 1
				lockIcon.Image = "rbxassetid://10333789558"
				lockIcon.ScaleType = Enum.ScaleType.Fit
				lockIcon.ZIndex = 10
				lockIcon.Parent = slotFrame
			end
		else
			if lockIcon then lockIcon:Destroy() end
		end
		rebuildFishInventory()
	end))

	table.insert(conns, slotFrame.MouseEnter:Connect(function()
		showDescriptionForFrame(slotFrame, fishItem.name)
	end))
	table.insert(conns, slotFrame.MouseLeave:Connect(function()
		module:removeCurrentDescription()
	end))
	hotBarFishConnections[slotIndex] = conns

	-- 핀 변경 시 서버에 저장
	if _G.saveFishHotBarPins then _G.saveFishHotBarPins() end
end

-- Fill empty hotbar slots with random fish from FishList
local function autoFillHotBarFish()
	if #module.FishList == 0 then return end

	-- Collect which fishIndexes are already pinned
	local usedFishIndexes = {}
	for _, fi in pairs(module.HotBarFish) do
		usedFishIndexes[fi] = true
	end

	-- Build pool of available fish indexes (not yet pinned to hotbar)
	local pool = {}
	for i = 1, #module.FishList do
		if not usedFishIndexes[i] then
			table.insert(pool, i)
		end
	end

	local poolIdx = 1
	for slotIndex = 1, module.slotAmount do
		-- Only fill slots that are completely empty (no rod/bubble and no fish pin)
		if module.OBJECTS.HotBar[slotIndex] then continue end
		if module.HotBarFish[slotIndex] then continue end
		if poolIdx > #pool then break end
		setHotBarFishSlot(slotIndex, pool[poolIdx])
		poolIdx += 1
	end
end

function rebuildHotBarFish()
	-- Remove stale fish frames
	for slotIndex, fishIndex in pairs(module.HotBarFish) do
		if not module.FishList[fishIndex] then
			clearHotBarFishSlot(slotIndex)
		end
	end
	-- Re-render existing pinned slots
	for slotIndex, fishIndex in pairs(module.HotBarFish) do
		setHotBarFishSlot(slotIndex, fishIndex)
	end
end

rebuildFishInventory = function()
	-- Clear existing fish frames from inventory
	if inventoryFrame and inventoryFrame.Frame then
		for _, child in ipairs(inventoryFrame.Frame:GetChildren()) do
			if typeof(child.Name) == "string" and child.Name:sub(1, 5) == "fish_" then
				child:Destroy()
			end
		end
	end

	-- 핫바에 핀된 fishIndex 목록
	local pinnedInHotBar = {}
	for _, fi in pairs(module.HotBarFish) do
		pinnedInHotBar[fi] = true
	end

	for i, fishItem in ipairs(module.FishList) do
		-- 핫바에 핀된 fish는 인벤에서 제외 (핫바가 인벤 역할 겸함)
		if pinnedInHotBar[i] then continue end
		local frame = createFishSlotFrame(fishItem, i)
		frame.Visible = true
		frame.Parent = inventoryFrame.Frame

		-- 더블탭/더블클릭으로 잠금 토글 (모바일 포함)
		local lastTapTime = 0
		local DOUBLE_TAP_DELAY = 0.35

		local function toggleLock()
			local fi = module.FishList[i]
			if not fi then return end
			fi.isLocked = not fi.isLocked
			pcall(function()
				fishLockRemote:FireServer(nil, fi.isLocked, i)
			end)
			rebuildFishInventory()
		end

		-- Click to equip/unequip (싱글탭), 더블탭은 잠금
		frame.MouseButton1Click:Connect(function()
			local now = tick()
			if now - lastTapTime < DOUBLE_TAP_DELAY then
				-- 더블클릭/탭 → 잠금
				lastTapTime = 0
				toggleLock()
				return
			end
			lastTapTime = now
			-- 싱글클릭 처리는 DOUBLE_TAP_DELAY 후 실행 (더블탭 판별 후)
			task.delay(DOUBLE_TAP_DELAY, function()
				if lastTapTime ~= now then return end  -- 더블탭이 발생하면 취소
				if module.equippedFishIndex == i then
					module.equippedFishIndex = nil
					if unequipFishRemote then
						pcall(function() unequipFishRemote:FireServer() end)
					end
					rebuildFishInventory()
				else
					module.equippedFishIndex = i
					if equipFishRemote then
						pcall(function() equipFishRemote:FireServer(i) end)
					end
					rebuildFishInventory()
				end
			end)
		end)

		-- Right-click to toggle lock (PC)
		frame.MouseButton2Click:Connect(toggleLock)

		-- Hover tooltip
		frame.MouseEnter:Connect(function()
			showDescriptionForFrame(frame, fishItem.name)
		end)
		frame.MouseLeave:Connect(function()
			module:removeCurrentDescription()
		end)

		-- Drag to reorder fish slots
		frame.MouseButton1Down:Connect(function()
			local clickStartTime = tick()
			local clickStartPos = Vector2.new(mouse.X, mouse.Y)
			local isDragging = false
			local dragThreshold = 10
			local ghostFrame = nil
			local mouseConn, mouseEnd

			local function endDrag()
				if mouseConn then mouseConn:Disconnect() end
				if mouseEnd then mouseEnd:Disconnect() end

				if not isDragging then
					-- short click: handled by MouseButton1Click above
					if ghostFrame then ghostFrame:Destroy() end
					return
				end

				-- ghost 제거 후 한 프레임 대기해야 GetGuiObjectsAtPosition이 올바르게 동작함
				if ghostFrame then ghostFrame:Destroy(); ghostFrame = nil end
				local dropX, dropY = mouse.X, mouse.Y
				task.defer(function()

				-- Find which slot we dropped onto
				local droppedGuis = playerGui:GetGuiObjectsAtPosition(dropX, dropY)
				local handled = false
				for _, rawTarget in pairs(droppedGuis) do
					if handled then break end
					local target = resolveDropTarget(rawTarget)
					if not target then continue end

					-- 핫바 슬롯으로 드롭
					if target.Parent == hotbar then
						local slotIndex = tonumber(target.Name)
						if slotIndex then
							local rodObj = module.OBJECTS.HotBar[slotIndex]
							if rodObj then
								-- rod 슬롯 → rod를 인벤으로, fish를 그 슬롯에 핀
								local mySlot = nil
								for s, fi in pairs(module.HotBarFish) do
									if fi == i then mySlot = s; break end
								end
								rodObj:DisconnectAll()
								module:addTool(rodObj.Tool, "Inventory")
								if mySlot then clearHotBarFishSlot(mySlot) end
								setHotBarFishSlot(slotIndex, i)
								handled = true
							else
								-- 빈 슬롯 또는 fish 슬롯 → 기존 로직
								local prevFish = module.HotBarFish[slotIndex]
								local mySlot = nil
								for s, fi in pairs(module.HotBarFish) do
									if fi == i then mySlot = s; break end
								end
								if mySlot then
									clearHotBarFishSlot(mySlot)
									if prevFish then setHotBarFishSlot(mySlot, prevFish) end
								end
								setHotBarFishSlot(slotIndex, i)
								handled = true
							end
						end
					end

					-- 인벤 아이템으로 드롭
					if not handled and target.Parent == inventoryFrame.Frame then
						local targetFishIdx = tonumber(target.Name:match("^fish_(%d+)$"))
						if targetFishIdx and targetFishIdx ~= i then
							-- 인벤 fish↔인벤 fish: FishList 인덱스 교환
							module.FishList[i], module.FishList[targetFishIdx] = module.FishList[targetFishIdx], module.FishList[i]
							-- 핫바 핀 업데이트: 루프 중 값 오염 방지를 위해 먼저 수집 후 적용
							local slotA, slotB = nil, nil
							for s, fi in pairs(module.HotBarFish) do
								if fi == targetFishIdx then slotA = s
								elseif fi == i then slotB = s end
							end
							if slotA then module.HotBarFish[slotA] = i; setHotBarFishSlot(slotA, i) end
							if slotB then module.HotBarFish[slotB] = targetFishIdx; setHotBarFishSlot(slotB, targetFishIdx) end
							handled = true
						-- fish→rod 드롭은 무시 (타입 혼합 스왑 미지원)
						end
					end
				end
				rebuildFishInventory()
				end) -- task.defer
			end

			mouseEnd = UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or
					input.UserInputType == Enum.UserInputType.Touch then
					endDrag()
				end
			end)

			mouseConn = mouse.Move:Connect(function()
				local currentPos = Vector2.new(mouse.X, mouse.Y)
				if not isDragging and (currentPos - clickStartPos).Magnitude > dragThreshold then
					isDragging = true
					ghostFrame = toolButton:Clone()
					ghostFrame.Visible = true
					local gfName = ghostFrame:FindFirstChild("toolName")
					if gfName then
						gfName.Text = truncateName(fishItem.name)
						local rarityColor = RARITY_COLORS[fishItem.rarity]
						if rarityColor then gfName.TextColor3 = rarityColor end
					end
					ghostFrame.Size = frame.Size
					ghostFrame.AnchorPoint = Vector2.new(0.5, 0.5)
					ghostFrame.ZIndex = 50
					ghostFrame.Parent = inventoryGui
				end
				if isDragging and ghostFrame then
					local guiPos = Vector2.new(mouse.X, mouse.Y) - inventoryGui.AbsolutePosition
					ghostFrame.Position = UDim2.new(0, guiPos.X, 0, guiPos.Y)
				end
			end)
		end)
	end

	updateInventorySize()

	-- 검색 텍스트가 있으면 rebuild 후 필터 재적용
	if inventoryFrame and inventoryFrame.SearchBox and inventoryFrame.SearchBox.Text ~= "" then
		local raw = inventoryFrame.SearchBox.Text:lower():gsub("%s+", "")
		if raw ~= "" then
			-- 검색 함수를 직접 인라인 호출 (module:searchTool()은 순환 참조 위험)
			local weightMin, weightMax = nil, nil
			local rangeA, rangeB = raw:match("^(%d+%.?%d*)%-(%d+%.?%d*)$")
			if rangeA and rangeB then
				weightMin, weightMax = tonumber(rangeA), tonumber(rangeB)
			else
				local numPlus = raw:match("^(%d+%.?%d*)%+$")
				if numPlus then
					weightMin = tonumber(numPlus); weightMax = math.huge
				else
					local numOnly = raw:match("^(%d+%.?%d*)$")
					if numOnly then
						local v = tonumber(numOnly); weightMin = v - 2; weightMax = v + 2
					end
				end
			end
			for i, fishItem in ipairs(module.FishList) do
				local frame = inventoryFrame.Frame:FindFirstChild("fish_" .. i)
				if not frame then continue end
				local matchFound = false
				if weightMin then
					local w = fishItem.weight or 0
					matchFound = w >= weightMin and w <= weightMax
				else
					local cleanName = fishItem.name:lower():gsub("%s+", "")
					cleanName = cleanName:gsub("%[.-%]", ""):gsub("%-[%d%.]+kg", "")
					cleanName = cleanName:gsub("^%s*", ""):gsub("%s*$", "")
					local rarityLower = (fishItem.rarity or ""):lower()
					matchFound = cleanName:find(raw, 1, true) ~= nil or rarityLower:find(raw, 1, true) ~= nil
				end
				frame.Visible = matchFound
			end
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API: sync / add fish
-- ─────────────────────────────────────────────────────────────────────────────

function module:syncInventory(fishList, doAutoFill)
	self.FishList = fishList or {}
	self.equippedFishIndex = nil
	-- 각 핀 슬롯을 clearHotBarFishSlot으로 정리 (UI 초기화 포함)
	for slotIndex in pairs(self.HotBarFish) do
		clearHotBarFishSlot(slotIndex)
	end
	self.HotBarFish = {}
	if doAutoFill then
		autoFillHotBarFish()
	end
	rebuildFishInventory()
end

function module:autoFillPublic()
	autoFillHotBarFish()
end

function module:setHotBarFishSlotPublic(slotIndex, fishIndex)
	setHotBarFishSlot(slotIndex, fishIndex)
end

function module:rebuildFishInventoryPublic()
	rebuildFishInventory()
end

function module:addFishItem(fishItem, index)
	self.FishList[index] = fishItem
	-- 빈 핫바 슬롯이 있으면 자동 핀
	local freeHotBarSlot = nil
	for s = 1, self.slotAmount do
		if not module.OBJECTS.HotBar[s] and not module.HotBarFish[s] then
			freeHotBarSlot = s; break
		end
	end
	if freeHotBarSlot then
		setHotBarFishSlot(freeHotBarSlot, index)
		updateInventorySize()
		return
	end
	-- Append new frame to inventory
	if inventoryFrame and inventoryFrame.Frame then
		-- 핫바에 이미 핀된 fish는 인벤에 추가하지 않음
		local isPinned = false
		for _, fi in pairs(module.HotBarFish) do
			if fi == index then isPinned = true; break end
		end
		if isPinned then
			updateInventorySize()
			return
		end
		local frame = createFishSlotFrame(fishItem, index)
		frame.Visible = true
		frame.Parent = inventoryFrame.Frame

		frame.MouseButton1Click:Connect(function()
			if module.equippedFishIndex == index then
				module.equippedFishIndex = nil
				if unequipFishRemote then pcall(function() unequipFishRemote:FireServer() end) end
				rebuildFishInventory()
			else
				module.equippedFishIndex = index
				if equipFishRemote then pcall(function() equipFishRemote:FireServer(index) end) end
				rebuildFishInventory()
			end
		end)

		frame.MouseButton2Click:Connect(function()
			local fishItem = self.FishList[index]
			if not fishItem then return end
			fishItem.isLocked = not fishItem.isLocked
			pcall(function()
				fishLockRemote:FireServer(nil, fishItem.isLocked, index)
			end)
			rebuildFishInventory()
		end)

		frame.MouseEnter:Connect(function()
			showDescriptionForFrame(frame, fishItem.name)
		end)
		frame.MouseLeave:Connect(function()
			module:removeCurrentDescription()
		end)
	end
	updateInventorySize()
end

function module:refreshAllLockUI(hotBarGui, inventoryGui2)
	-- Lock UI is already reflected in rebuildFishInventory; force a rebuild.
	rebuildFishInventory()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Search
-- ─────────────────────────────────────────────────────────────────────────────

function module:searchTool()
	local raw = inventoryFrame.SearchBox.Text:lower()
	local searchText = raw:gsub("%s+", "")

	if not inventoryFrame or not inventoryFrame.Frame then return end

	if searchText == "" then
		for _, child in ipairs(inventoryFrame.Frame:GetChildren()) do
			if child:IsA("Frame") or child:IsA("ImageButton") then
				child.Visible = true
				child.LayoutOrder = 0
			end
		end
		updateInventorySize()
		return
	end

	-- 숫자 입력이면 무게 검색 (예: "30" → 30kg 근처, "30+" → 30kg 이상, "30-50" → 범위)
	local weightMin, weightMax = nil, nil
	local rangeA, rangeB = searchText:match("^(%d+%.?%d*)%-(%d+%.?%d*)$")
	if rangeA and rangeB then
		weightMin, weightMax = tonumber(rangeA), tonumber(rangeB)
	else
		local numPlus = searchText:match("^(%d+%.?%d*)%+$")
		if numPlus then
			weightMin = tonumber(numPlus)
			weightMax = math.huge
		else
			local numOnly = searchText:match("^(%d+%.?%d*)$")
			if numOnly then
				local v = tonumber(numOnly)
				weightMin = v - 2
				weightMax = v + 2
			end
		end
	end

	-- Fish frames
	for i, fishItem in ipairs(module.FishList) do
		local frame = inventoryFrame.Frame:FindFirstChild("fish_" .. i)
		if not frame then continue end

		local matchFound = false

		if weightMin then
			-- 무게 검색
			local w = fishItem.weight or 0
			matchFound = w >= weightMin and w <= weightMax
		else
			-- 이름 검색
			local cleanName = fishItem.name:lower():gsub("%s+", "")
			cleanName = cleanName:gsub("%[.-%]", "")
			cleanName = cleanName:gsub("%-[%d%.]+kg", "")
			cleanName = cleanName:gsub("^%s*", ""):gsub("%s*$", "")

			-- rarity 검색도 지원
			local rarityLower = (fishItem.rarity or ""):lower()

			matchFound = cleanName:find(searchText, 1, true) ~= nil
				or rarityLower:find(searchText, 1, true) ~= nil
		end

		frame.Visible = matchFound
	end

	-- Non-fish tool objects
	for uniqueId, toolObject in pairs(self.OBJECTS.Inventory) do
		local toolName = toolObject.Name:lower():gsub("%s+", "")
		local frame_ref = toolObject.Frame
		if frame_ref then
			frame_ref.Visible = toolName:find(searchText, 1, true) ~= nil
		end
	end

	updateInventorySize()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Slot lock helpers
-- ─────────────────────────────────────────────────────────────────────────────

function module:lockSlots(unequipCurrentTool)
	self.slotsLocked = true
	if unequipCurrentTool then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:UnequipTools() end
	end
end

function module:unlockSlots()
	self.slotsLocked = false
end

function module:lockSlotsPosition()
	self.slotsPositionLocked = true
end

function module:unlockSlotsPosition()
	self.slotsPositionLocked = false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Tool metatable (for rods / bubble tools still in Backpack)
-- ─────────────────────────────────────────────────────────────────────────────

local toolObjectMetatable = {}
toolObjectMetatable.__index = toolObjectMetatable

function toolObjectMetatable:isEquipped()
	local character = player.Character
	return character and self.Tool.Parent == character or false
end

function toolObjectMetatable:DisconnectAll()
	for _, v in pairs(self.CONNECTIONS) do
		v:Disconnect()
	end
	self.didRemoval = true

	if (inventoryFrame.Visible or module.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR) and self.Frame.Parent ~= inventoryGui and self.Frame.Parent ~= inventoryFrame.Frame then
		local toolName  = self.Frame:FindFirstChild("toolName")
		local toolAmount = self.Frame:FindFirstChild("toolAmount")
		local toolIcon  = self.Frame:FindFirstChild("toolIcon")
		if toolName and toolIcon then
			toolName.Text = ""
			if toolAmount then toolAmount.Text = "" end
			toolIcon.Image = ""
		end
		local vp = self.Frame:FindFirstChild("toolViewport")
		if vp then vp:Destroy() end
		self.Frame.BackgroundColor3 = SETTINGS.DEFAULT_COLOR
		self.Frame.Image = SETTINGS.DEFAULT_IMAGEID
		local s = self.Frame:FindFirstChildOfClass("UIStroke")
		if s then s.Color = Color3.new(0, 0, 0) end
	else
		self.Frame:Destroy()
	end

	if self.Parent == "HotBar" and self.Position then
		ContextActionService:UnbindAction(self.Position .. "hotBar")
		module.OBJECTS.HotBar[self.Position] = nil
	elseif self.Parent == "Inventory" then
		module.OBJECTS.Inventory[self.UniqueId or self.Tool.Name] = nil
	end

	if self.Parent == "Inventory" then
		updateInventorySize()
	end
	self = nil
end

function toolObjectMetatable:updateIcon()
	local tool = self.Tool
	local frame = self.Frame

	if tool.TextureId ~= "" then
		local vp = frame:FindFirstChild("toolViewport")
		if vp then vp:Destroy() end
		frame.toolName.Visible = SETTINGS.ALWAYS_SHOW_TOOL_NAME
		frame.toolIcon.Visible = true
		frame.toolIcon.Image = tool.TextureId
	else
		local vp = frame:FindFirstChild("toolViewport")
		if vp then vp:Destroy() end
		frame.toolName.Visible = true
		frame.toolIcon.Visible = false
		frame.toolIcon.Image = ""
	end
end

function toolObjectMetatable:getParentInstance()
	return self.Parent == "Inventory" and inventoryFrame.Frame or hotbar
end

function toolObjectMetatable:showDescription()
	showDescriptionForFrame(self.Frame, self.Tool.Name)
	self.DescriptionFrame = inventoryGui:FindFirstChild("descriptionFrame")
end

function toolObjectMetatable:removeDescription()
	if self.DescriptionFrame then
		self.DescriptionFrame:Destroy()
		self.DescriptionFrame = nil
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- getObjectFromTool / getToolPosition
-- ─────────────────────────────────────────────────────────────────────────────

function module:getObjectFromTool(tool)
	local function searchToolObject(toolParent)
		for _, toolObject in pairs(toolParent) do
			if toolObject.Tool == tool then return toolObject end
		end
	end
	return searchToolObject(self.OBJECTS.HotBar) or searchToolObject(self.OBJECTS.Inventory)
end

function module:getToolPosition(tool)
	if not tool then return nil end
	local toolObject = self:getObjectFromTool(tool)
	return toolObject and toolObject.Position
end

-- ─────────────────────────────────────────────────────────────────────────────
-- newTool / addTool (for rods / bubble tools)
-- ─────────────────────────────────────────────────────────────────────────────

function module:newTool(tool)
	if tool:GetAttribute("toolAdded") or not tool:IsA("Tool") then return end
	if tool:FindFirstChild("FishValue") then return end  -- fish handled separately

	local isRod = tool:FindFirstChild("CastRod") ~= nil
	local freeSlot = nil

	if isRod then
		-- 로드는 슬롯1 우선. 슬롯1에 버블이 있으면 버블을 다음 빈 슬롯으로 밀어냄
		if not module.OBJECTS.HotBar[1] and not module.HotBarFish[1] then
			freeSlot = 1
		elseif module.OBJECTS.HotBar[1] then
			local existingTool = module.OBJECTS.HotBar[1]
			local isBubble = existingTool.Tool and not existingTool.Tool:FindFirstChild("CastRod")
			if isBubble then
				-- 버블을 다음 빈 슬롯으로 이동
				local nextSlot = nil
				for s = 2, self.slotAmount do
					if not module.OBJECTS.HotBar[s] and not module.HotBarFish[s] then
						nextSlot = s; break
					end
				end
				if nextSlot then
					existingTool:DisconnectAll()
					module:addTool(existingTool.Tool, "HotBar", nextSlot)
				else
					existingTool:DisconnectAll()
					module:addTool(existingTool.Tool, "Inventory")
				end
				freeSlot = 1
			else
				-- 슬롯1에 다른 로드가 있으면 다음 빈 슬롯
				for s = 2, self.slotAmount do
					if not module.OBJECTS.HotBar[s] and not module.HotBarFish[s] then
						freeSlot = s; break
					end
				end
			end
		end
	else
		-- 버블 등 비로드 도구: 슬롯1은 로드 예약이므로 2번부터 탐색
		local startSlot = 2
		for s = startSlot, self.slotAmount do
			if not module.OBJECTS.HotBar[s] and not module.HotBarFish[s] then
				freeSlot = s; break
			end
		end
		-- 슬롯1이 비어있고 2번 이후도 없을 때만 슬롯1 허용
		if not freeSlot and not module.OBJECTS.HotBar[1] and not module.HotBarFish[1] then
			freeSlot = 1
		end
	end

	local savedPosition = tool:GetAttribute("position")
	if savedPosition and not module.OBJECTS.HotBar[savedPosition] and not module.HotBarFish[savedPosition] then
		freeSlot = savedPosition
	end

	module:addTool(tool, freeSlot and "HotBar" or "Inventory", freeSlot)
end

function module:addTool(tool, parent, position)
	tool:SetAttribute("position", nil)
	if position == -1 then parent = "Inventory"; position = nil end

	if not position and parent == "HotBar" then
		for index = 1, self.slotAmount do
			-- fish가 핀된 슬롯은 건너뜀 (rod/bubble 전용 슬롯 찾기)
			if self.OBJECTS.HotBar[index] == nil and not module.HotBarFish[index] then
				position = index
				break
			end
		end
		-- all hotbar slots occupied by fish — send to inventory instead of displacing fish
		if not position then
			parent = "Inventory"
		end
	end

	if position and hotbar:FindFirstChild(position) then
		hotbar:FindFirstChild(position):Destroy()
	end

	local frame = toolButton:Clone()

	frame.Visible = true
	local amount = tool:GetAttribute("amount") or 1
	local toolAmountLabel = frame:FindFirstChild("toolAmount")
	if toolAmountLabel and amount > 1 then
		toolAmountLabel.Text = "x" .. amount
	end
	frame.toolName.Text = tool.Name
	frame.Parent = parent == "Inventory" and inventoryFrame.Frame or hotbar

	local uniqueId = tool.Name .. "_" .. tick() .. "_" .. math.random(1000, 9999)
	tool:SetAttribute("uniqueId", uniqueId)

	if parent == "Inventory" then
		frame.Name = uniqueId
	else
		frame.Name = position
	end

	frame.toolNumber.Text = parent == "Inventory" and "" or tostring(position or "")

	local object = {}
	setmetatable(object, toolObjectMetatable)

	object.Tool = tool
	object.Frame = frame
	object.Parent = parent
	object.Position = position
	object.Name = tool.Name
	object.UniqueId = uniqueId

	if parent == "Inventory" then
		self.OBJECTS[parent][uniqueId] = object
	else
		self.OBJECTS[parent][position] = object
	end

	local function manageTool(_, inputState, inputObject)
		if inputObject and inputObject.UserInputType ~= Enum.UserInputType.Keyboard and inputObject.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or not tool.Parent
			or inputState == Enum.UserInputState.End or self.slotsLocked then
			return
		end

		if object:isEquipped() then
			humanoid:UnequipTools()
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Color = Color3.new(0, 0, 0) end
			frame.Image = SETTINGS.DEFAULT_IMAGEID
			module.currentlyEquipped = nil
		else
			-- Unequip any held fish before equipping a rod/bubble
			if module.equippedFishIndex then
				module.equippedFishIndex = nil
				if unequipFishRemote then pcall(function() unequipFishRemote:FireServer() end) end
				task.defer(function() rebuildHotBarFish(); rebuildFishInventory() end)
			end
			-- updateEquipped가 EquipTool 도중 간섭하지 못하도록 미리 상태 설정
			if module.currentlyEquipped and module.currentlyEquipped.Parent then
				local prevStroke = module.currentlyEquipped:FindFirstChildOfClass("UIStroke")
				if prevStroke then prevStroke.Color = Color3.new(0, 0, 0) end
				module.currentlyEquipped.Image = SETTINGS.DEFAULT_IMAGEID
			end
			module.currentlyEquipped = frame
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Color = Color3.new(1, 1, 1) end
			frame.Image = SETTINGS.EQUIPPED_IMAGEID
			humanoid:EquipTool(tool)
		end
	end

	local function updateEquipped()
		if object:isEquipped() and tool.Enabled then
			if module.currentlyEquipped and module.currentlyEquipped.Parent then
				local prevStroke = module.currentlyEquipped:FindFirstChildOfClass("UIStroke")
				if prevStroke then prevStroke.Color = Color3.new(0, 0, 0) end
				module.currentlyEquipped.Image = SETTINGS.DEFAULT_IMAGEID
			end
			module.currentlyEquipped = frame
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Color = Color3.new(1, 1, 1) end
			frame.Image = SETTINGS.EQUIPPED_IMAGEID
		else
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Color = Color3.new(0, 0, 0) end
			frame.Image = SETTINGS.DEFAULT_IMAGEID
			-- 이 frame이 currentlyEquipped일 때만 초기화 (다른 rod 장착 중에는 건드리지 않음)
			if module.currentlyEquipped == frame then
				module.currentlyEquipped = nil
			end
		end
	end

	local function updateEnabled()
		if tool.Enabled then
			frame.Image = SETTINGS.DEFAULT_IMAGEID
			frame.BackgroundColor3 = SETTINGS.DEFAULT_COLOR
			frame.ImageTransparency = 0
			frame.toolIcon.ImageTransparency = 0
			frame.toolName.TextTransparency = 0
			frame.toolNumber.TextTransparency = 0
			local ta = frame:FindFirstChild("toolAmount")
			if ta then
				ta.TextTransparency = 0
				local s = ta:FindFirstChildOfClass("UIStroke")
				if s then s.Transparency = 0 end
			end
			local ns = frame.toolName:FindFirstChildOfClass("UIStroke")
			if ns then ns.Transparency = 0 end
		else
			frame.Image = SETTINGS.DISABLED_IMAGEID
			frame.BackgroundColor3 = SETTINGS.DISABLED_COLOR
			frame.ImageTransparency = 0.35
			frame.toolIcon.ImageTransparency = 0.5
			frame.toolName.TextTransparency = 0.6
			frame.toolNumber.TextTransparency = 0.6
			local ta = frame:FindFirstChild("toolAmount")
			if ta then
				ta.TextTransparency = 0.6
				local s = ta:FindFirstChildOfClass("UIStroke")
				if s then s.Transparency = 0.6 end
			end
			local ns = frame.toolName:FindFirstChildOfClass("UIStroke")
			if ns then ns.Transparency = 0.6 end
		end
	end

	updateEnabled()
	updateEquipped()
	object:updateIcon()

	object.CONNECTIONS = {}
	object.CONNECTIONS.EnabledConn = tool:GetPropertyChangedSignal("Enabled"):Connect(updateEnabled)
	object.CONNECTIONS.ToolRemoved = tool.AncestryChanged:Connect(function(_, newParent)
		if player and (newParent == nil or (newParent ~= player.Backpack and newParent ~= player.Character)) then
			object:DisconnectAll()
			tool:SetAttribute("toolAdded", false)
		end
		updateEquipped()
	end)
	object.CONNECTIONS.NameChanged = tool:GetPropertyChangedSignal("Name"):Connect(function()
		frame.toolName.Text = tool.Name
		object.Name = tool.Name
	end)
	object.CONNECTIONS.TextureIdChanged = tool:GetPropertyChangedSignal("TextureId"):Connect(function()
		object:updateIcon()
	end)
	object.CONNECTIONS.AmountChanged = tool:GetAttributeChangedSignal("amount"):Connect(function()
		amount = tool:GetAttribute("amount") or 1
		local ta2 = frame:FindFirstChild("toolAmount")
		if ta2 then ta2.Text = amount > 1 and ("x" .. amount) or "" end
	end)
	object.CONNECTIONS.MouseEnter = frame.MouseEnter:Connect(function()
		if object.isGrabbed then return end
		object:showDescription()
	end)
	object.CONNECTIONS.MouseLeave = frame.MouseLeave:Connect(function()
		object:removeDescription()
	end)

	object.CONNECTIONS.GrabConn = frame.MouseButton1Down:Connect(function()
		local clickStartTime = tick()
		local clickStartPos = Vector2.new(mouse.X, mouse.Y)
		local isDragging = false
		local dragThreshold = 10

		if self.slotsPositionLocked then return end

		local mouseEnd, mouseConn, newFrame

		local function endGrab()
			if mouseEnd then mouseEnd:Disconnect() end
			if mouseConn then mouseConn:Disconnect() end
			object.isGrabbed = false

			if not isDragging then
				local clickDuration = tick() - clickStartTime
				if clickDuration < 0.5 then
					manageTool()
					if newFrame then newFrame:Destroy() end
					return
				end
			end

			-- ghost/원본 frame 숨기고 한 프레임 후 GetGuiObjectsAtPosition 호출
			if newFrame then newFrame:Destroy(); newFrame = nil end
			frame.Visible = false
			local dropX, dropY = mouse.X, mouse.Y
			task.defer(function()
			frame.Visible = true
			local droppedGuis = playerGui:GetGuiObjectsAtPosition(dropX, dropY)
			local wasSwapped = false

			for _, rawSlot in pairs(droppedGuis) do
				if wasSwapped then break end
				local newSlot = resolveDropTarget(rawSlot)
				if newSlot then
					local targetSlotNum = newSlot.Parent == hotbar and tonumber(newSlot.Name) or nil
					-- fish 슬롯으로 드롭: fish와 rod 스왑
					if targetSlotNum and module.HotBarFish[targetSlotNum] then
						local fishIdx = module.HotBarFish[targetSlotNum]
						clearHotBarFishSlot(targetSlotNum)
						object:DisconnectAll()
						self:addTool(tool, "HotBar", targetSlotNum)
						-- position이 nil이면 (인벤→핫바 드롭) fish는 인벤에 남김
						if position then
							-- DisconnectAll이 position 슬롯 frame을 Destroy했을 수 있으므로 복원
							if not hotbar:FindFirstChild(tostring(position)) then
								local f = toolButton:Clone()
								f.Visible = true
								f.Name = tostring(position)
								local nl = f:FindFirstChild("toolNumber"); if nl then nl.Text = tostring(position) end
								f.Parent = hotbar
							end
							setHotBarFishSlot(position, fishIdx)
						end
						rebuildFishInventory()
						wasSwapped = true
						if newFrame then newFrame:Destroy() end
					else
						-- 인벤 fish로 드롭: rod↔fish 스왑 미지원, 무시
						local invFishIdx = newSlot.Parent == inventoryFrame.Frame
							and tonumber(newSlot.Name:match("^fish_(%d+)$"))
							or nil
						if invFishIdx then
							-- 아무것도 안 함
						else
							local newSlotObject = self.OBJECTS[newSlot.Parent == hotbar and "HotBar" or "Inventory"][targetSlotNum or newSlot.Name]
							if newSlotObject == object then
								if newFrame then newFrame:Destroy() end
								continue
							end
							if newSlotObject then
								wasSwapped = true
								-- 인벤↔인벤 스왑 시 LayoutOrder 교환을 위해 미리 기록
								local myOrder  = object.Frame and object.Frame.LayoutOrder
								local hisOrder = newSlotObject.Frame and newSlotObject.Frame.LayoutOrder
								object:DisconnectAll()
								newSlotObject:DisconnectAll()
								local myNewObj  = self:addTool(newSlotObject.Tool, parent, position)
								local hisNewObj = self:addTool(tool, newSlotObject.Parent, newSlotObject.Position)
								-- 인벤토리끼리 스왑이면 LayoutOrder 교환
								if parent == "Inventory" and newSlotObject.Parent == "Inventory" then
									if myNewObj  and myNewObj.Frame  and myOrder  then myNewObj.Frame.LayoutOrder  = myOrder  end
									if hisNewObj and hisNewObj.Frame and hisOrder then hisNewObj.Frame.LayoutOrder = hisOrder end
								end
							elseif newSlot.Parent == hotbar then
								wasSwapped = true
								object:DisconnectAll()
								self:addTool(tool, "HotBar", tonumber(newSlot.Name))
								-- restore original position slot as empty frame
								if position and not hotbar:FindFirstChild(tostring(position)) then
									local f = toolButton:Clone()
									f.Visible = true
									f.Name = tostring(position)
									local nl = f:FindFirstChild("toolNumber"); if nl then nl.Text = tostring(position) end
									local ta = f:FindFirstChild("toolAmount"); if ta then ta.Text = "" end
									local tn = f:FindFirstChild("toolName"); if tn then tn.Text = "" end
									f.Parent = hotbar
								end
								if newFrame then newFrame:Destroy() end
								newSlot:Destroy()
							end
						end
					end
				end
			end

			if not wasSwapped then
				-- 인벤토리 영역 빈 곳에 드롭 → 핫바 아이템이면 인벤으로 이동
				local invAbsPos = inventoryFrame.AbsolutePosition
				local invAbsSize = inventoryFrame.AbsoluteSize
				local isOverInv = dropX >= invAbsPos.X and dropX <= invAbsPos.X + invAbsSize.X
					and dropY >= invAbsPos.Y and dropY <= invAbsPos.Y + invAbsSize.Y
				if isOverInv and parent == "HotBar" then
					object:DisconnectAll()
					self:addTool(tool, "Inventory")
				else
					frame.Parent = object:getParentInstance()
				end
			end
			end) -- task.defer
		end

		mouseEnd = UserInputService.InputEnded:Connect(function(inputObject)
			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or
				inputObject.UserInputType == Enum.UserInputType.Touch then
				endGrab()
			end
		end)

		local function updateFramePos()
			local currentMousePos = Vector2.new(mouse.X, mouse.Y)
			local mouseDelta = (currentMousePos - clickStartPos).Magnitude

			if not isDragging and mouseDelta > dragThreshold then
				isDragging = true
				object.isGrabbed = true
				newFrame = toolButton:Clone()
				newFrame.Visible = true
				newFrame.toolName.Text = ""
				local nfta = newFrame:FindFirstChild("toolAmount")
				if nfta then nfta.Text = "" end
				newFrame.toolNumber.Text = position or ""
				newFrame.Name = frame.Name
				newFrame.Size = frame.Size
				newFrame.Parent = object:getParentInstance()
				frame.Parent = inventoryGui
				frame.Size = UDim2.new(0, frame.AbsoluteSize.X, 0, frame.AbsoluteSize.Y)
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

			if isDragging then
				local mousePos = Vector2.new(mouse.X, mouse.Y)
				local guiPos = mousePos - inventoryGui.AbsolutePosition
				frame.Position = UDim2.new(0, guiPos.X, 0, guiPos.Y)
			end
		end

		mouseConn = mouse.Move:Connect(updateFramePos)
	end)

	tool:SetAttribute("toolAdded", true)

	if parent == "HotBar" and position then
		ContextActionService:BindAction(position .. "hotBar", manageTool, false, EnumKeys[position])
	end

	if parent == "Inventory" then
		updateInventorySize()
	end
	return object
end

return module
