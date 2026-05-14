local module = {OBJECTS = {}, SETTINGS = {}, slotAmount = 9}
module.OBJECTS.HotBar = {}
module.OBJECTS.Inventory = {}

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

local EnumKeys = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local function updateInventorySize()
	local itemCount = 0
	for _, _ in pairs(module.OBJECTS.Inventory) do
		itemCount = itemCount + 1
	end

	local rows = math.max(5, math.ceil(itemCount / 10))
	local neededHeight = rows * 70 + 50

	if inventoryFrame and inventoryFrame.Frame then
		inventoryFrame.Frame.CanvasSize = UDim2.new(0, 0, 0, neededHeight)
	end
end

local toolObjectMetatable = {}
toolObjectMetatable.__index = toolObjectMetatable

function toolObjectMetatable:isEquipped()
	local character = player.Character
	if character then
		return self.Tool.Parent == player.Character
	else
		return false
	end
end

function toolObjectMetatable:DisconnectAll()
	for _, v in pairs(self.CONNECTIONS) do
		v:Disconnect()
	end

	self.didRemoval = true

	if (inventoryFrame.Visible or module.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR) and self.Frame.Parent ~= inventoryGui and self.Frame.Parent ~= inventoryFrame.Frame then
		local toolName = self.Frame:FindFirstChild("toolName")
		local toolAmount = self.Frame:FindFirstChild("toolAmount")
		local toolIcon = self.Frame:FindFirstChild("toolIcon")

		if toolName and toolIcon then
			toolName.Text = ""
			if toolAmount then toolAmount.Text = "" end
			toolIcon.Image = ""
		end
		local vp = self.Frame:FindFirstChild("toolViewport")
		if vp then vp:Destroy() end
		self.Frame.BackgroundColor3 = SETTINGS.DEFAULT_COLOR
		self.Frame.Image = SETTINGS.DEFAULT_IMAGEID
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

local VP_FOV   = 60
local VP_PITCH = -20
local VP_YAW   = 45
local VP_ZOOM  = 1.2

local VP_OVERRIDES = {
	["Unknown"]        = { pitch = -20, yaw = 45,  zoom = 3.5 },
	["Electric Fish"]  = { pitch = -10, yaw = 45,  zoom = 0.9 },
	["Nyan Cat"]       = { pitch = -10, yaw = 30,  zoom = 0.9 },
}

local function getFishBaseName(toolName)
	return toolName:match("^(.-)%s*%[") or toolName:match("^(.-)%s*%-") or toolName
end

function toolObjectMetatable:updateIcon()
	local tool = self.Tool
	local frame = self.Frame

	local isFish = tool:FindFirstChild("FishValue") ~= nil

	local hasMesh = isFish and (
		tool:FindFirstChildWhichIsA("BasePart", true)
		or tool:FindFirstChildWhichIsA("MeshPart", true)
		or tool:FindFirstChildWhichIsA("UnionOperation", true)
	)

	if hasMesh then
		frame.toolIcon.Visible = false
		frame.toolIcon.Image = ""
		frame.toolName.Visible = SETTINGS.ALWAYS_SHOW_TOOL_NAME
	elseif tool.TextureId ~= "" then
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
	local toolDescription = self.Tool.ToolTip
	local frame = self.Frame
	if toolDescription == "" then
		return
	end

	local descriptionFrame = Instance.new("TextLabel")
	descriptionFrame.Name = "descriptionFrame"
	descriptionFrame.AnchorPoint = Vector2.new(0.5, 0)
	descriptionFrame.FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
	descriptionFrame.TextColor = BrickColor.Black()
	descriptionFrame.TextSize = 14
	descriptionFrame.BorderSizePixel = 0
	descriptionFrame.BackgroundColor = BrickColor.White()
	descriptionFrame.ZIndex = 99
	descriptionFrame.TextWrapped = true
	descriptionFrame.Parent = inventoryGui

	local corner = Instance.new("UICorner")
	corner.Parent = descriptionFrame
	corner.CornerRadius = UDim.new(0.12, 0)

	local textBounds = TextService:GetTextSize(toolDescription, descriptionFrame.TextSize, descriptionFrame.Font, Vector2.new(400, 1000)) + Vector2.new(10, 4)
	descriptionFrame.Size = UDim2.new(0, textBounds.X, 0, textBounds.Y)
	descriptionFrame.Position = UDim2.new(0, frame.AbsolutePosition.X + (frame.AbsoluteSize.X / 2), 0, frame.AbsolutePosition.Y - textBounds.Y - 2 + 57)
	descriptionFrame.Text = toolDescription
	self.DescriptionFrame = descriptionFrame
	game:GetService("Debris"):AddItem(descriptionFrame, 15)
end

function toolObjectMetatable:removeDescription()
	if self.DescriptionFrame then
		self.DescriptionFrame:Destroy()
	end
end

function module:removeCurrentDescription()
	local descriptionFrame = inventoryGui:FindFirstChild("descriptionFrame")
	if descriptionFrame then
		descriptionFrame:Destroy()
	end
end

function module:getObjectFromTool(tool: Tool)
	local function searchToolObject(toolParent)
		for _, toolObject in pairs(toolParent) do
			if toolObject.Tool == tool then
				return toolObject
			end
		end
	end

	return searchToolObject(self.OBJECTS.HotBar) or searchToolObject(self.OBJECTS.Inventory)
end

function module:getToolPosition(tool: Tool)
	local toolObject = self:getObjectFromTool(tool)
	return toolObject and toolObject.Position
end

function module:searchTool()
	local searchText = inventoryFrame.SearchBox.Text:lower():gsub("%s+", "")

	if searchText == "" then
		for uniqueId, toolObject in pairs(self.OBJECTS.Inventory) do
			toolObject.Frame.Visible = true
			toolObject.Frame.LayoutOrder = 0
		end
		updateInventorySize()
		return
	end

	local searchResults = {}

	for uniqueId, toolObject in pairs(self.OBJECTS.Inventory) do
		local toolName = toolObject.Name:lower():gsub("%s+", "")

		local cleanName = toolName
		cleanName = cleanName:gsub("frozen", "")
		cleanName = cleanName:gsub("%[.-%]", "")
		cleanName = cleanName:gsub("%-[%d%.]+kg", "")
		cleanName = cleanName:gsub("^%s*", ""):gsub("%s*$", "")

		local priority = 0
		local matchFound = false

		if cleanName == searchText then
			priority = 1000
			matchFound = true
		elseif cleanName:find("^" .. searchText) then
			priority = 500
			matchFound = true
		elseif cleanName:find(searchText) then
			priority = 300
			matchFound = true
		else
			local pos = 1
			local matchCount = 0
			for i = 1, #searchText do
				local char = searchText:sub(i, i)
				local found = cleanName:find(char, pos)
				if found then
					pos = found + 1
					matchCount = matchCount + 1
				end
			end

			if matchCount == #searchText then
				priority = 100 + matchCount * 10
				matchFound = true
			end
		end

		if matchFound then
			local lengthBonus = math.max(0, 50 - #cleanName)
			priority = priority + lengthBonus

			table.insert(searchResults, {
				toolObject = toolObject,
				priority = priority,
				name = toolObject.Name,
				cleanName = cleanName,
				uniqueId = uniqueId
			})
			toolObject.Frame.Visible = true
		else
			toolObject.Frame.Visible = false
		end
	end

	table.sort(searchResults, function(a, b)
		if a.priority == b.priority then
			return #a.cleanName < #b.cleanName
		end
		return a.priority > b.priority
	end)

	for i, result in ipairs(searchResults) do
		result.toolObject.Frame.LayoutOrder = i
	end

	updateInventorySize()
end

function module:lockSlots(unequipCurrentTool: boolean)
	self.slotsLocked = true

	if unequipCurrentTool then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
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

function module:newTool(tool: Tool)
	if tool:GetAttribute("toolAdded") or not tool:IsA("Tool") then
		return
	end

	local length = 0
	for _, _ in pairs(module.OBJECTS.HotBar) do
		length += 1
	end

	module:addTool(tool, length == self.slotAmount and "Inventory" or "HotBar", tool:GetAttribute("position"))
end

function module:addTool(tool: Tool, parent: string, position: number)
	tool:SetAttribute("position", nil)
	if position == -1 then
		parent = "Inventory"
		position = nil
	end

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
		if
			not humanoid
			or humanoid.Health <= 0
			or not tool.Parent
			or inputState == Enum.UserInputState.End
			or self.slotsLocked
		then
			return
		end

		if object:isEquipped() then
			humanoid:UnequipTools()
			frame.BackgroundColor3 = SETTINGS.DEFAULT_COLOR
			frame.Image = SETTINGS.DEFAULT_IMAGEID
			module.currentlyEquipped = nil
		elseif tool.Enabled then
			humanoid:EquipTool(tool)
			if module.currentlyEquipped and module.currentlyEquipped.Parent then
				module.currentlyEquipped.BackgroundColor3 = SETTINGS.DEFAULT_COLOR
				module.currentlyEquipped.Image = SETTINGS.DEFAULT_IMAGEID
			end
			module.currentlyEquipped = frame
			frame.BackgroundColor3 = SETTINGS.EQUIPPED_COLOR
			frame.Image = SETTINGS.EQUIPPED_IMAGEID
		end
	end

	local function updateEquipped()
		if object:isEquipped() and tool.Enabled then
			if module.currentlyEquipped and module.currentlyEquipped.Parent then
				module.currentlyEquipped.BackgroundColor3 = SETTINGS.DEFAULT_COLOR
				module.currentlyEquipped.Image = SETTINGS.DEFAULT_IMAGEID
			end
			module.currentlyEquipped = frame
			frame.BackgroundColor3 = SETTINGS.EQUIPPED_COLOR
			frame.Image = SETTINGS.EQUIPPED_IMAGEID
		else
			frame.BackgroundColor3 = SETTINGS.DEFAULT_COLOR
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

	local function updateFishLockUI()
		local fishValue = tool:FindFirstChild("FishValue")
		local lockValue = tool:FindFirstChild("FishLock")
		local isLocked = lockValue and lockValue.Value or false

		if fishValue then
			local lockElement = frame:FindFirstChild("Lock") or frame:FindFirstChild("lock")
			if lockElement then
				lockElement.Visible = isLocked
			end
		end
	end

	updateEnabled()
	updateEquipped()
	updateFishLockUI()
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
		if ta2 then
			ta2.Text = amount > 1 and ("x" .. amount) or ""
		end
	end)

	object.CONNECTIONS.FishLockChildAdded = tool.ChildAdded:Connect(function(child)
		if child.Name == "FishLock" and child:IsA("BoolValue") then
			child:GetPropertyChangedSignal("Value"):Connect(updateFishLockUI)
			updateFishLockUI()
		end
	end)

	local existingLock = tool:FindFirstChild("FishLock")
	if existingLock and existingLock:IsA("BoolValue") then
		object.CONNECTIONS.FishLockChanged = existingLock:GetPropertyChangedSignal("Value"):Connect(updateFishLockUI)
	end

	object.CONNECTIONS.MouseEnter = frame.MouseEnter:Connect(function()
		if object.isGrabbed then
			return
		end
		object:showDescription()
	end)
	object.CONNECTIONS.MouseLeave = frame.MouseLeave:Connect(function()
		object:removeDescription()
	end)

	object.CONNECTIONS.RightClick = frame.MouseButton2Click:Connect(function()
		local fishValue = tool:FindFirstChild("FishValue")
		if fishValue then
			local lockValue = tool:FindFirstChild("FishLock")
			if not lockValue then
				lockValue = Instance.new("BoolValue")
				lockValue.Name = "FishLock"
				lockValue.Value = false
				lockValue.Parent = tool
				object.CONNECTIONS.FishLockChanged = lockValue:GetPropertyChangedSignal("Value"):Connect(updateFishLockUI)
			end

			lockValue.Value = not lockValue.Value

			pcall(function()
				fishLockRemote:FireServer(tool, lockValue.Value)
			end)
		end
	end)

	object.CONNECTIONS.GrabConn = frame.MouseButton1Down:Connect(function()
		local clickStartTime = tick()
		local clickStartPos = Vector2.new(mouse.X, mouse.Y)
		local isDragging = false
		local dragThreshold = 10

		if UserInputService.TouchEnabled then
			local fishValue = tool:FindFirstChild("FishValue")
			if fishValue then
				local currentTime = tick()
				local lastTime = _G.lastClickTime and _G.lastClickTime[uniqueId] or 0

				if currentTime - lastTime <= (_G.doubleClickDelay or 0.3) then
					local lockValue = tool:FindFirstChild("FishLock")
					if not lockValue then
						lockValue = Instance.new("BoolValue")
						lockValue.Name = "FishLock"
						lockValue.Value = false
						lockValue.Parent = tool
						object.CONNECTIONS.FishLockChanged = lockValue:GetPropertyChangedSignal("Value"):Connect(updateFishLockUI)
					end

					lockValue.Value = not lockValue.Value
					pcall(function()
						fishLockRemote:FireServer(tool, lockValue.Value)
					end)

					return
				end

				if not _G.lastClickTime then
					_G.lastClickTime = {}
				end
				_G.lastClickTime[uniqueId] = currentTime
			end
		end

		if self.slotsPositionLocked then
			return
		end

		local mouseEnd
		local mouseConn
		local newFrame
		local frameStartPosition = frame.AbsolutePosition
		object:removeDescription()

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
			local dropTool = true

			for _, newSlot in pairs(droppedGuis) do
				if newSlot:IsA("ImageButton") and (newSlot.Parent == hotbar or newSlot.Parent == inventoryFrame.Frame) then
					local newSlotObject = self.OBJECTS[newSlot.Parent == hotbar and "HotBar" or "Inventory"][newSlot.Parent == hotbar and tonumber(newSlot.Name) or newSlot.Name]
					if newSlotObject == object then
						dropTool = false
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

					if newSlotObject then newSlotObject:removeDescription() end
					if object then object:removeDescription() end
				elseif newSlot:IsA("ImageLabel") and newSlot == inventoryFrame and not wasSwapped and parent == "HotBar" then
					wasSwapped = true
					object:DisconnectAll()
					self:addTool(tool, "Inventory")
					self:searchTool()
					updateInventorySize()
					break
				end
			end

			if not wasSwapped then
				if newFrame then newFrame:Destroy() end
				frame.Parent = object:getParentInstance()

				if SETTINGS.DRAG_OUTSIDE_TO_DROP and dropTool and tool.CanBeDropped then
					local character = player.Character
					if character then
						tool.Parent = character
						RunService.RenderStepped:Wait()
						tool.Parent = workspace
					end
				end
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
				frame.Size = UDim2.new(0.06, 0, 0.08, 0)
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
