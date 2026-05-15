local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local player = game:GetService("Players").LocalPlayer
local backpack = player:WaitForChild("Backpack")
local camera = workspace.CurrentCamera

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local CustomInventoryGUI = player.PlayerGui:WaitForChild("Custom Inventory")
local hotBar = CustomInventoryGUI:WaitForChild("hotBar")
local Inventory = CustomInventoryGUI:WaitForChild("Inventory")
local toolButton = CustomInventoryGUI:WaitForChild("toolButton")
local fishCountText = CustomInventoryGUI:WaitForChild("FishCount")

local inventoryHandler = require(script.SETTINGS)

local lastClickTime = {}
local doubleClickDelay = 0.3

local function updateFishCount()
	local fishCount = 0

	for _, tool in pairs(player.Backpack:GetChildren()) do
		if tool:IsA("Tool") and tool:FindFirstChild("FishValue") then
			local amount = tool:GetAttribute("amount") or 1
			fishCount = fishCount + amount
		end
	end

	if player.Character then
		for _, tool in pairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") and tool:FindFirstChild("FishValue") then
				local amount = tool:GetAttribute("amount") or 1
				fishCount = fishCount + amount
			end
		end
	end

	fishCountText.Text = "Fish Count: " .. fishCount
end

local function connectFishCountUpdates()
	player.Backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:FindFirstChild("FishValue") then
			task.wait(0.1)
			updateFishCount()
		end
	end)

	player.Backpack.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child:FindFirstChild("FishValue") then
			task.wait(0.1)
			updateFishCount()
		end
	end)

	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		updateFishCount()

		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child:FindFirstChild("FishValue") then
				task.wait(0.1)
				updateFishCount()
			end
		end)

		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child:FindFirstChild("FishValue") then
				task.wait(0.1)
				updateFishCount()
			end
		end)
	end)

	if player.Character then
		player.Character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child:FindFirstChild("FishValue") then
				task.wait(0.1)
				updateFishCount()
			end
		end)

		player.Character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child:FindFirstChild("FishValue") then
				task.wait(0.1)
				updateFishCount()
			end
		end)
	end
end

local function updateAllFishLockUI()
	for index = 1, inventoryHandler.slotAmount do
		local toolObject = inventoryHandler.OBJECTS.HotBar[index]
		if toolObject and toolObject.Tool then
			local tool = toolObject.Tool
			local fishValue = tool:FindFirstChild("FishValue")
			local isLocked = tool:GetAttribute("fishlock") or false

			if fishValue then
				local frame = hotBar:FindFirstChild(tostring(index))
				if frame and frame:FindFirstChild("lock") then
					frame.lock.Visible = isLocked
				end
			end
		end
	end

	if inventoryHandler.OBJECTS.Inventory then
		for index = 1, 100 do
			local toolObject = inventoryHandler.OBJECTS.Inventory[index]
			if toolObject and toolObject.Tool then
				local tool = toolObject.Tool
				local fishValue = tool:FindFirstChild("FishValue")
				local isLocked = tool:GetAttribute("fishlock") or false

				if fishValue then
					local frame = Inventory.Frame:FindFirstChild(tostring(index))
					if frame and frame:FindFirstChild("lock") then
						frame.lock.Visible = isLocked
					end
				end
			end
		end
	end
end

local function toggleFishLock(tool)
	if not tool:IsA("Tool") then return end

	local fishValue = tool:FindFirstChild("FishValue")
	if not fishValue then return end

	local currentLock = tool:GetAttribute("fishlock") or false
	tool:SetAttribute("fishlock", not currentLock)

	updateAllFishLockUI()
end

local function showSlots()
	for index = 1, inventoryHandler.slotAmount do
		local toolObject = inventoryHandler.OBJECTS.HotBar[index]
		if not toolObject and not hotBar:FindFirstChild(index) and index <= inventoryHandler.slotAmount then
			local frame = toolButton:Clone()
			frame.Visible = true
			frame.toolName.Text = ""
			local ta = frame:FindFirstChild("toolAmount")
			if ta then ta.Text = "" end
			frame.toolNumber.Text = index
			frame.Name = index
			frame.Parent = hotBar
		end
	end
end

local function removeEmptySlots()
	for index = 1, 9 do
		local toolObject = inventoryHandler.OBJECTS.HotBar[index]
		local toolFrame = hotBar:FindFirstChild(index)
		if not toolObject and toolFrame then
			toolFrame:Destroy()
			if hotBar:FindFirstChild(index) then
				removeEmptySlots()
			end
		end
	end
end

local function toggleInventory()
	Inventory.Visible = not Inventory.Visible
	local currentState = Inventory.Visible

	inventoryHandler:removeCurrentDescription()

	if currentState then
		showSlots()
		task.spawn(function()
			task.wait(0.1)
			updateAllFishLockUI()
		end)
	else
		if not inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
			removeEmptySlots()
		end
	end
end

local function manageInventory(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		toggleInventory()
	elseif not inputState then
		for index = inventoryHandler.slotAmount + 1, inventoryHandler.slotAmount do
			local toolObject = inventoryHandler.OBJECTS.HotBar[index]
			local toolFrame = hotBar:FindFirstChild(index)
			if toolObject then
				local tool = toolObject.Tool
				toolObject:DisconnectAll()
				tool:SetAttribute("toolAdded", nil)
				inventoryHandler:newTool(tool)
			elseif toolFrame then
				toolFrame:Destroy()
			end
		end
	end
end

local function forceToggleInventory()
	toggleInventory()
end

_G.forceToggleInventory = forceToggleInventory
_G.toggleInventory = toggleInventory
_G.updateFishCount = updateFishCount

local function searchTool()
	inventoryHandler:searchTool()
end

local function newTool(tool)
	if tool:IsA("Tool") then
		inventoryHandler:newTool(tool)
		task.spawn(function()
			task.wait(0.1)
			updateAllFishLockUI()
			updateFishCount()
		end)
	end
end

local function reloadInventory(character)
	inventoryHandler.currentlyEquipped = nil
	backpack = player:WaitForChild("Backpack")

	-- 이후 추가되는 툴은 바로 처리 (저장 레이아웃 무관)
	backpack.ChildAdded:Connect(newTool)
	character.ChildAdded:Connect(newTool)

	task.spawn(function()
		-- 저장된 핫바 레이아웃 비동기 로드 (첫 캐릭터 로드 시 1회)
		local nameToSlot = {}
		if not _G.hotBarLayoutLoaded then
			_G.hotBarLayoutLoaded = true
			local ok, result = pcall(function()
				local RS = game:GetService("ReplicatedStorage")
				local getRemote = RS:WaitForChild("Remotes", 10)
					and RS.Remotes:WaitForChild("Misc", 10)
					and RS.Remotes.Misc:WaitForChild("GetHotBarLayout", 10)
				if not getRemote then return {} end
				return getRemote:InvokeServer()
			end)
			if ok and typeof(result) == "table" then
				for slot, toolName in pairs(result) do
					nameToSlot[toolName] = slot
				end
			end
		end

		-- 이미 백팩에 있는 툴 배치 (저장 슬롯 있으면 적용, 없으면 빈 슬롯에 그냥 넣음)
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and not tool:GetAttribute("toolAdded") then
				local slot = nameToSlot[tool.Name]
				if slot then
					tool:SetAttribute("position", slot)
					nameToSlot[tool.Name] = nil
				end
				newTool(tool)
			end
		end

		task.wait(0.5)
		updateFishCount()
	end)
end

local function getToolEquipped()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Tool")
end

_G.toggleFishLock = toggleFishLock
_G.lastClickTime = lastClickTime
_G.doubleClickDelay = doubleClickDelay

connectFishCountUpdates()

task.spawn(function()
	while true do
		task.wait(0.5)

		local currentBackpackTools = {}
		for _, tool in pairs(player.Backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:FindFirstChild("FishValue") then
				table.insert(currentBackpackTools, tool.Name)
			end
		end

		if player.Character then
			for _, tool in pairs(player.Character:GetChildren()) do
				if tool:IsA("Tool") and tool:FindFirstChild("FishValue") then
					table.insert(currentBackpackTools, tool.Name)
				end
			end
		end

		if #currentBackpackTools ~= (_G.lastToolCount or 0) then
			_G.lastToolCount = #currentBackpackTools
			updateFishCount()
		end
	end
end)

reloadInventory(player.Character or player.CharacterAdded:Wait())

player.CharacterAdded:Connect(reloadInventory)
Inventory.SearchBox:GetPropertyChangedSignal("Text"):Connect(searchTool)

if inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
	showSlots()
end

if inventoryHandler.SETTINGS.INVENTORY_KEYBIND then
	ContextActionService:BindAction("manageInventory", manageInventory, false, inventoryHandler.SETTINGS.INVENTORY_KEYBIND)
end

if inventoryHandler.SETTINGS.OPEN_BUTTON then
	local openBtn = CustomInventoryGUI:FindFirstChild("openButton")
	if openBtn then
		openBtn.Activated:Connect(toggleInventory)
	end
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel and inventoryHandler.SETTINGS.SCROLL_HOTBAR_WITH_WHEEL then
		local direction = input.Position.Z
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		local toolEquipped = getToolEquipped()
		local toolPosition = inventoryHandler:getToolPosition(toolEquipped) or 0

		for i=toolPosition + direction, direction < 0 and 1 or inventoryHandler.slotAmount, direction do
			local toolObject = inventoryHandler.OBJECTS.HotBar[i]
			if toolObject and humanoid then
				humanoid:EquipTool(toolObject.Tool)
				break
			end
		end
	end
end)

task.spawn(function()
	task.wait(2)
	updateFishCount()
end)
