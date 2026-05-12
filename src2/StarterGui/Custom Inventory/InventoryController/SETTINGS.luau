local module = {OBJECTS = {}, SETTINGS = {}, slotAmount = 9}
module.OBJECTS.HotBar = {}
module.OBJECTS.Inventory = {}

-- SETTINGS
local SETTINGS = module.SETTINGS
SETTINGS.DEFAULT_COLOR = Color3.fromRGB(0, 0, 0) -- ToolFrame background color when unequipped
SETTINGS.EQUIPPED_COLOR = Color3.fromRGB(128, 128, 128) -- ToolFrame background color when equipped
SETTINGS.DISABLED_COLOR = Color3.fromRGB(128, 64, 65) -- ToolFrame background color when the tool is disabled
SETTINGS.DEFAULT_IMAGEID = ""
SETTINGS.EQUIPPED_IMAGEID = ""
SETTINGS.DISABLED_IMAGEID = ""
SETTINGS.INVENTORY_KEYBIND = Enum.KeyCode.Backquote -- KeyCode to open the Inventory itself (set to nil to disable the Inventory or Backpack)
SETTINGS.DRAG_OUTSIDE_TO_DROP = false -- If set to true any tool you drag outside of the Inventory or HotBar will be dropped to the floor
SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR = false -- If set to true it will display all the tool frames in the HotBar even if they are empty and the Inventory closed
SETTINGS.SCROLL_HOTBAR_WITH_WHEEL = false -- If set to true it will enable you to scroll the HotBar with the mouse wheel
SETTINGS.EQUIP_TOUCH_SENSITIVITY = 60 -- The limit of how much you can drag a tool before it dosent equips/unequips it when you release it
SETTINGS.OPEN_BUTTON = true
SETTINGS.ALWAYS_SHOW_TOOL_NAME = true

-- services
local ContextActionService = game:GetService("ContextActionService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// PLAYER
local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

--// INVENTORY_SYSTEM \\--
local inventoryGui = script.Parent.Parent
local hotbar = inventoryGui.hotBar
local inventoryFrame = inventoryGui.Inventory
local toolButton = script.Parent.toolButton

-- RemoteEvent 연결 (서버에서 생성되어야 함)
local fishLockEvent = ReplicatedStorage:WaitForChild("FishLockEvent")

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

-- 인벤토리 크기 자동 조정 함수
local function updateInventorySize()
	local itemCount = 0
	for _, _ in pairs(module.OBJECTS.Inventory) do
		itemCount = itemCount + 1
	end

	-- 10개씩 한 행, 최소 5행 보장
	local rows = math.max(5, math.ceil(itemCount / 10))
	local neededHeight = rows * 70 + 50 -- 여유 공간 포함

	if inventoryFrame and inventoryFrame.Frame then
		inventoryFrame.Frame.CanvasSize = UDim2.new(0, 0, 0, neededHeight)
	end
end

-- tool object methods
local toolObjectMetatable = {}
toolObjectMetatable.__index = toolObjectMetatable

function toolObjectMetatable:isEquipped() -- Checks if the current object.Tool is equipped
	local character = player.Character

	if character then
		return self.Tool.Parent == player.Character
	else
		return false
	end
end

function toolObjectMetatable:DisconnectAll() -- Makes a cleanup of connections and binds as well as deletes object.Frame
	for _, v in pairs(self.CONNECTIONS) do
		v:Disconnect()
	end

	self.didRemoval = true

	if (inventoryFrame.Visible or module.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR) and self.Frame.Parent ~= inventoryGui and self.Frame.Parent ~= inventoryFrame.Frame then
		local toolName = self.Frame:FindFirstChild("toolName")
		local toolAmount = self.Frame:FindFirstChild("toolAmount")
		local toolIcon = self.Frame:FindFirstChild("toolIcon")

		if toolName and toolAmount and toolIcon then
			toolName.Text = ""
			toolAmount.Text = ""
			toolIcon.Image = ""
		end
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

	-- 인벤토리 크기 업데이트
	if self.Parent == "Inventory" then
		updateInventorySize()
	end

	self = nil
end

function toolObjectMetatable:updateIcon() -- Updates the tool Texture
	local tool = self.Tool
	local frame = self.Frame
	local textureId = tool.TextureId

	if textureId == "" or textureId == nil then
		frame.toolName.Visible = true
		frame.toolIcon.Visible = false
		frame.toolIcon.Image = ""
	else
		frame.toolName.Visible = SETTINGS.ALWAYS_SHOW_TOOL_NAME
		frame.toolIcon.Visible = true
		frame.toolIcon.Image = textureId
	end
end

function toolObjectMetatable:getParentInstance()
	return self.Parent == "Inventory" and inventoryFrame.Frame or hotbar
end

function toolObjectMetatable:showDescription() -- Shows the object.Tool.ToolTip
	local toolDescription = self.Tool.ToolTip
	local frame = self.Frame
	if toolDescription == "" then
		return
	end

	local descriptionFrame = Instance.new("TextLabel")
	descriptionFrame.Name = "descriptionFrame"
	descriptionFrame.AnchorPoint = Vector2.new(0.5, 0)
	descriptionFrame.Font = Enum.Font.SourceSansSemibold
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

function toolObjectMetatable:removeDescription() -- Destroys the object.DescriptionFrame created by object:showDescription()
	if self.DescriptionFrame then
		self.DescriptionFrame:Destroy()
	end
end

function module:removeCurrentDescription() -- Destroys any current active descriptionFrame
	local descriptionFrame = inventoryGui:FindFirstChild("descriptionFrame")
	if descriptionFrame then
		descriptionFrame:Destroy()
	end
end

function module:getObjectFromTool(tool: Tool) -- Returns the ToolObject of a Tool
	local function searchToolObject(toolParent)
		for _, toolObject in pairs(toolParent) do
			if toolObject.Tool == tool then
				return toolObject
			end
		end
	end

	return searchToolObject(self.OBJECTS.HotBar) or searchToolObject(self.OBJECTS.Inventory)
end

function module:getToolPosition(tool: Tool) -- Returns the tool position on the hotbar (if in inventory retuns nil)
	local toolObject = self:getObjectFromTool(tool)
	return toolObject and toolObject.Position
end

function module:searchTool() -- Handler for the tool search feature in the inventory
	local searchText = inventoryFrame.SearchBox.Text:lower():gsub("%s+", "") -- 공백 제거 및 소문자 변환

	-- 검색어가 비어있을 때
	if searchText == "" then
		for uniqueId, toolObject in pairs(self.OBJECTS.Inventory) do
			toolObject.Frame.Visible = true
			toolObject.Frame.LayoutOrder = 0 -- 기본 순서로 복원
		end
		updateInventorySize() -- 크기 업데이트
		return
	end

	-- 검색 결과를 우선순위별로 정렬하기 위한 테이블
	local searchResults = {}

	for uniqueId, toolObject in pairs(self.OBJECTS.Inventory) do
		local toolName = toolObject.Name:lower():gsub("%s+", "") -- 공백 제거 및 소문자 변환

		-- Frozen, 등급, 무게 정보 제거해서 순수 물고기 이름만 추출
		local cleanName = toolName
		cleanName = cleanName:gsub("frozen", "") -- frozen 제거
		cleanName = cleanName:gsub("%[.-%]", "") -- [등급] 제거
		cleanName = cleanName:gsub("%-[%d%.]+kg", "") -- -무게kg 제거
		cleanName = cleanName:gsub("^%s*", ""):gsub("%s*$", "") -- 앞뒤 공백 제거

		local priority = 0
		local matchFound = false

		-- 우선순위 1: 완전 일치 (최고 점수)
		if cleanName == searchText then
			priority = 1000
			matchFound = true
			-- 우선순위 2: 시작 문자 일치 (높은 점수)
		elseif cleanName:find("^" .. searchText) then
			priority = 500
			matchFound = true
			-- 우선순위 3: 포함 검색 (중간 점수)
		elseif cleanName:find(searchText) then
			priority = 300
			matchFound = true
			-- 우선순위 4: 부분 문자 일치 (낮은 점수)
		else
			-- 검색어의 각 문자가 순서대로 포함되어 있는지 확인
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
				priority = 100 + matchCount * 10 -- 일치하는 문자가 많을수록 높은 점수
				matchFound = true
			end
		end

		if matchFound then
			-- 이름이 짧을수록 추가 보너스 (관련성 높음)
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

	-- 우선순위별로 정렬 (높은 우선순위가 먼저)
	table.sort(searchResults, function(a, b)
		if a.priority == b.priority then
			return #a.cleanName < #b.cleanName -- 우선순위가 같으면 짧은 이름 우선
		end
		return a.priority > b.priority
	end)

	-- 정렬된 순서대로 LayoutOrder 설정
	for i, result in ipairs(searchResults) do
		result.toolObject.Frame.LayoutOrder = i
	end

	updateInventorySize() -- 크기 업데이트
end

function module:lockSlots(unequipCurrentTool: boolean) -- Locks the slots so they cant be equipped or unequipped
	self.slotsLocked = true

	if unequipCurrentTool then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
	end
end

function module:unlockSlots() -- Unlocks the slots so they can be equipped and unequipped again
	self.slotsLocked = false
end

function module:lockSlotsPosition() -- Locks the slots position so they cant be moved around
	self.slotsPositionLocked = true
end

function module:unlockSlotsPosition() -- Unlocks the slots positions so they can be moved again
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
	local amount = tool:GetAttribute("amount") or 1
	if amount > 1 then
		frame.toolAmount.Text = "x" .. amount
	end
	frame.toolName.Text = tool.Name
	frame.Parent = parent == "Inventory" and inventoryFrame.Frame or hotbar

	-- 고유 식별자 생성 (같은 이름 아이템 구분)
	local uniqueId = tool.Name .. "_" .. tick() .. "_" .. math.random(1000, 9999)
	tool:SetAttribute("uniqueId", uniqueId)

	if parent == "Inventory" then
		frame.Name = uniqueId -- 고유 ID 사용
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

	-- 저장 방식 개선
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

		if object:isEquipped() then -- if tool is equipped then unequip it
			humanoid:UnequipTools()
			frame.BackgroundColor3 = SETTINGS.DEFAULT_COLOR
			frame.Image = SETTINGS.DEFAULT_IMAGEID
			module.currentlyEquipped = nil
		elseif tool.Enabled then -- if tool isnt equipped then equip it
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
			frame.toolAmount.TextTransparency = 0

			frame.toolAmount.UIStroke.Transparency = 0
			frame.toolName.UIStroke.Transparency = 0
		else
			frame.Image = SETTINGS.DISABLED_IMAGEID
			frame.BackgroundColor3 = SETTINGS.DISABLED_COLOR
			frame.ImageTransparency = 0.35
			frame.toolIcon.ImageTransparency = 0.5
			frame.toolName.TextTransparency = 0.6
			frame.toolNumber.TextTransparency = 0.6
			frame.toolAmount.TextTransparency = 0.6

			frame.toolAmount.UIStroke.Transparency = 0.6
			frame.toolName.UIStroke.Transparency = 0.6
		end
	end

	-- 물고기 잠금 상태 UI 업데이트
	local function updateFishLockUI()
		local fishValue = tool:FindFirstChild("FishValue")
		local lockValue = tool:FindFirstChild("FishLock")
		local isLocked = lockValue and lockValue.Value or false

		if fishValue then
			local lockElement = frame:FindFirstChild("Lock") or
				frame:FindFirstChild("lock") or
				frame:WaitForChild("Lock", 1)

			if lockElement then
				lockElement.Visible = isLocked
			end
		end
	end

	updateEnabled()
	updateEquipped()
	updateFishLockUI()
	object:updateIcon()

	-- CONNECTIONS
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
		if amount > 1 then
			frame.toolAmount.Text = "x" .. amount
		else
			frame.toolAmount.Text = ""
		end
	end)

	-- 물고기 잠금 상태 변경 감지
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

	-- 우클릭 이벤트 (PC 전용) - 서버 동기화 포함
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
				fishLockEvent:FireServer(tool, lockValue.Value)
			end)
		end
	end)

	-- 개선된 드래그 시스템
	object.CONNECTIONS.GrabConn = frame.MouseButton1Down:Connect(function()
		local clickStartTime = tick()
		local clickStartPos = Vector2.new(mouse.X, mouse.Y)
		local isDragging = false
		local dragThreshold = 10 -- 10픽셀 이상 움직여야 드래그

		-- 모바일 전용 더블클릭 체크
		if UserInputService.TouchEnabled then
			local fishValue = tool:FindFirstChild("FishValue")
			if fishValue then
				local currentTime = tick()
				local lastTime = _G.lastClickTime and _G.lastClickTime[uniqueId] or 0

				if currentTime - lastTime <= (_G.doubleClickDelay or 0.3) then
					-- 더블클릭으로 물고기 잠금 처리
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
						fishLockEvent:FireServer(tool, lockValue.Value)
					end)

					return -- 드래그 시작하지 않음
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

			-- 드래그하지 않았으면 장착/해제
			if not isDragging then
				local clickDuration = tick() - clickStartTime
				if clickDuration < 0.5 then -- 0.5초 미만이면 클릭으로 간주
					manageTool()
					if newFrame then newFrame:Destroy() end
					return
				end
			end

			-- 드래그 종료 로직
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

					if newSlotObject then -- 도구 교체
						wasSwapped = true
						object:DisconnectAll()
						newSlotObject:DisconnectAll()
						self:addTool(newSlotObject.Tool, parent, position)
						self:addTool(tool, newSlotObject.Parent, newSlotObject.Position)
						if newFrame then newFrame:Destroy() end
					elseif newSlot.Parent == hotbar then -- 핫바로 이동
						wasSwapped = true
						object:DisconnectAll()
						self:addTool(tool, "HotBar", tonumber(newSlot.Name))
						if parent == "Inventory" and newFrame then newFrame:Destroy() end
						newSlot:Destroy()
					end

					if newSlotObject then newSlotObject:removeDescription() end
					if object then object:removeDescription() end
				elseif newSlot:IsA("ImageLabel") and newSlot == inventoryFrame and not wasSwapped and parent == "HotBar" then
					-- 인벤토리로 이동
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

			-- 드래그 임계값 확인
			if not isDragging and mouseDelta > dragThreshold then
				isDragging = true

				-- 드래그 시작 시에만 새 프레임 생성
				object.isGrabbed = true
				newFrame = toolButton:Clone()
				newFrame.toolName.Text = ""
				newFrame.toolAmount.Text = ""
				newFrame.toolNumber.Text = position or ""
				newFrame.Name = frame.Name
				newFrame.Size = frame.Size
				newFrame.Parent = object:getParentInstance()

				frame.Parent = inventoryGui
				frame.Size = UDim2.new(0.06, 0, 0.08, 0)
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

			-- 드래그 중일 때만 위치 업데이트
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

	-- 인벤토리에 추가된 경우 크기 업데이트
	if parent == "Inventory" then
		updateInventorySize()
	end
end

return module