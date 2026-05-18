local module = {OBJECTS = {}, SETTINGS = {}, slotAmount = 9}
module.OBJECTS.HotBar = {}
module.OBJECTS.Inventory = {}

-- Fish inventory data (client-side mirror of server PlayerFishData)
module.FishList = {}           -- array of fishItem tables
module.equippedFishIndex = nil -- currently equipped fish index

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
SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR = false
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Fish slot rendering
-- ─────────────────────────────────────────────────────────────────────────────

local RARITY_COLORS = {
	Common    = Color3.fromRGB(200, 200, 200),
	Uncommon  = Color3.fromRGB(100, 200, 100),
	Rare      = Color3.fromRGB(100, 140, 220),
	Epic      = Color3.fromRGB(180, 100, 220),
	Legendary = Color3.fromRGB(255, 200, 50),
	Mythic    = Color3.fromRGB(255, 100, 50),
}

local function createFishSlotFrame(fishItem, index)
	local frame = toolButton:Clone()
	frame.Visible = true
	frame.Name = "fish_" .. index
	frame.LayoutOrder = index

	-- Name label
	local nameLabel = frame:FindFirstChild("toolName")
	if nameLabel then
		nameLabel.Text = fishItem.name
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

	-- Equipped highlight
	if index == module.equippedFishIndex then
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = Color3.new(1, 1, 1) end
		frame.Image = SETTINGS.EQUIPPED_IMAGEID
	end

	return frame
end

local function rebuildFishInventory()
	-- Clear existing fish frames from inventory
	if inventoryFrame and inventoryFrame.Frame then
		for _, child in ipairs(inventoryFrame.Frame:GetChildren()) do
			if typeof(child.Name) == "string" and child.Name:sub(1, 5) == "fish_" then
				child:Destroy()
			end
		end
	end

	for i, fishItem in ipairs(module.FishList) do
		local frame = createFishSlotFrame(fishItem, i)
		frame.Parent = inventoryFrame.Frame

		-- Click to equip/unequip
		frame.MouseButton1Click:Connect(function()
			if module.equippedFishIndex == i then
				-- Unequip
				module.equippedFishIndex = nil
				if unequipFishRemote then
					pcall(function() unequipFishRemote:FireServer() end)
				end
				-- Remove equipped highlight
				local stroke = frame:FindFirstChildOfClass("UIStroke")
				if stroke then stroke.Color = Color3.new(0, 0, 0) end
				frame.Image = SETTINGS.DEFAULT_IMAGEID
				-- Refresh to clear all highlights
				rebuildFishInventory()
			else
				-- Equip
				module.equippedFishIndex = i
				if equipFishRemote then
					pcall(function() equipFishRemote:FireServer(i) end)
				end
				-- Refresh to apply highlight
				rebuildFishInventory()
			end
		end)

		-- Right-click to toggle lock
		frame.MouseButton2Click:Connect(function()
			local fishItem = module.FishList[i]
			if not fishItem then return end
			fishItem.isLocked = not fishItem.isLocked
			-- fire server: (nil tool, isLocked, fishIndex)
			pcall(function()
				fishLockRemote:FireServer(nil, fishItem.isLocked, i)
			end)
			rebuildFishInventory()
		end)

		-- Hover tooltip
		frame.MouseEnter:Connect(function()
			showDescriptionForFrame(frame, fishItem.name)
		end)
		frame.MouseLeave:Connect(function()
			module:removeCurrentDescription()
		end)
	end

	updateInventorySize()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API: sync / add fish
-- ─────────────────────────────────────────────────────────────────────────────

function module:syncInventory(fishList)
	self.FishList = fishList or {}
	rebuildFishInventory()
end

function module:addFishItem(fishItem, index)
	self.FishList[index] = fishItem
	-- Append new frame to inventory
	if inventoryFrame and inventoryFrame.Frame then
		local frame = createFishSlotFrame(fishItem, index)
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
	local searchText = inventoryFrame.SearchBox.Text:lower():gsub("%s+", "")

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

	-- Fish frames
	for i, fishItem in ipairs(module.FishList) do
		local frame = inventoryFrame.Frame:FindFirstChild("fish_" .. i)
		if not frame then continue end

		local toolName = fishItem.name:lower():gsub("%s+", "")
		local cleanName = toolName
		cleanName = cleanName:gsub("frozen", "")
		cleanName = cleanName:gsub("%[.-%]", "")
		cleanName = cleanName:gsub("%-[%d%.]+kg", "")
		cleanName = cleanName:gsub("^%s*", ""):gsub("%s*$", "")

		local priority = 0
		local matchFound = false

		if cleanName == searchText then
			priority = 1000; matchFound = true
		elseif cleanName:find("^" .. searchText) then
			priority = 500; matchFound = true
		elseif cleanName:find(searchText) then
			priority = 300; matchFound = true
		end

		frame.Visible = matchFound
	end

	-- Non-fish tool objects
	for uniqueId, toolObject in pairs(self.OBJECTS.Inventory) do
		local toolName = toolObject.Name:lower():gsub("%s+", "")
		local frame_ref = toolObject.Frame
		if frame_ref then
			frame_ref.Visible = toolName:find(searchText) ~= nil
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

local EnumKeys = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
	Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
	Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}

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

	local length = 0
	for _ in pairs(module.OBJECTS.HotBar) do length += 1 end

	module:addTool(tool, length == self.slotAmount and "Inventory" or "HotBar", tool:GetAttribute("position"))
end

function module:addTool(tool, parent, position)
	tool:SetAttribute("position", nil)
	if position == -1 then parent = "Inventory"; position = nil end

	if not position and parent == "HotBar" then
		for index = 1, self.slotAmount do
			if self.OBJECTS.HotBar[index] == nil then
				position = index
				break
			end
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

	frame.toolNumber.Text = parent == "Inventory" and "" or position

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
		elseif tool.Enabled then
			humanoid:EquipTool(tool)
			if module.currentlyEquipped and module.currentlyEquipped.Parent then
				local prevStroke = module.currentlyEquipped:FindFirstChildOfClass("UIStroke")
				if prevStroke then prevStroke.Color = Color3.new(0, 0, 0) end
				module.currentlyEquipped.Image = SETTINGS.DEFAULT_IMAGEID
			end
			module.currentlyEquipped = frame
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Color = Color3.new(1, 1, 1) end
			frame.Image = SETTINGS.EQUIPPED_IMAGEID
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
			module.currentlyEquipped = nil
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

			local droppedGuis = playerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
			local wasSwapped = false

			for _, newSlot in pairs(droppedGuis) do
				if newSlot:IsA("ImageButton") and (newSlot.Parent == hotbar or newSlot.Parent == inventoryFrame.Frame) then
					local newSlotObject = self.OBJECTS[newSlot.Parent == hotbar and "HotBar" or "Inventory"][newSlot.Parent == hotbar and tonumber(newSlot.Name) or newSlot.Name]
					if newSlotObject == object then
						if newFrame then newFrame:Destroy() end
						continue
					end
					if newSlotObject then
						wasSwapped = true
						object:DisconnectAll()
						newSlotObject:DisconnectAll()
						self:addTool(newSlotObject.Tool, parent, position)
						self:addTool(tool, newSlotObject.Parent, newSlotObject.Position)
						if newFrame then newFrame:Destroy() end
					elseif newSlot.Parent == hotbar then
						wasSwapped = true
						object:DisconnectAll()
						self:addTool(tool, "HotBar", tonumber(newSlot.Name))
						if parent == "Inventory" and newFrame then newFrame:Destroy() end
						newSlot:Destroy()
					end
				end
			end

			if not wasSwapped then
				if newFrame then newFrame:Destroy() end
				frame.Parent = object:getParentInstance()
			end
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
end

return module
