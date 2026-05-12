-- services
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

-- references
local player = game:GetService("Players").LocalPlayer
local backpack = player:WaitForChild("Backpack")
local camera = workspace.CurrentCamera

-- DISABLE BASIC ROBLOX HOTBAR
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local CustomInventoryGUI = script.Parent
local hotBar = CustomInventoryGUI:WaitForChild("hotBar")
local Inventory = CustomInventoryGUI:WaitForChild("Inventory")
local toolButton = script:WaitForChild("toolButton")
local fishCountText = script.Parent:WaitForChild("FishCount")

local inventoryHandler = require(script.SETTINGS)

local lastClickTime = {}
local doubleClickDelay = 0.3

local function updateFishCount()
	local fishCount = 0
	local player = game:GetService("Players").LocalPlayer

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
	local player = game:GetService("Players").LocalPlayer

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
			frame.toolName.Text = ""
			frame.toolAmount.Text = ""
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
			if updateAllFishLockUI then
				updateAllFishLockUI()
			end
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
			if updateAllFishLockUI then
				updateAllFishLockUI()
			end
			updateFishCount()
		end)
	end
end

local function reloadInventory(character)
	inventoryHandler.currentlyEquipped = nil
	backpack = player:WaitForChild("Backpack")

	for _, tool in pairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			newTool(tool)
		end
	end
	backpack.ChildAdded:Connect(newTool)
	character.ChildAdded:Connect(newTool)

	task.spawn(function()
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

for _, child in pairs(CustomInventoryGUI:GetChildren()) do
	print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
end

local inventoryButtonAlternatives = {
	CustomInventoryGUI:FindFirstChild("openButton"),
	CustomInventoryGUI:FindFirstChild("OpenButton"),
	CustomInventoryGUI:FindFirstChild("InventoryButton"),
	CustomInventoryGUI:FindFirstChild("Button"),
	CustomInventoryGUI:FindFirstChild("inventoryButton")
}

local actualButton = nil
for i, button in pairs(inventoryButtonAlternatives) do
	if button then
		actualButton = button
		break
	end
end

if inventoryHandler.SETTINGS.OPEN_BUTTON then
	if actualButton then
		pcall(function()
			actualButton.MouseButton1Click:Connect(function()
				print("MouseButton1Click fired!")
				toggleInventory()
			end)
		end)

		pcall(function()
			actualButton.MouseButton1Down:Connect(function()
				print("MouseButton1Down fired!")
				toggleInventory()
			end)
		end)

		pcall(function()
			actualButton.Activated:Connect(function()
				print("Activated event fired!")
				toggleInventory()
			end)
		end)

		if actualButton:IsA("GuiButton") then
			pcall(function()
				actualButton.MouseButton1Up:Connect(function()
					print("MouseButton1Up fired!")
					toggleInventory()
				end)
			end)
		end

		print("All events connected!")

	else
		warn("Inventory button not found by any method!")
		warn("Available GUI elements:")
		for _, child in pairs(CustomInventoryGUI:GetChildren()) do
			if child:IsA("GuiObject") then
				warn("  - " .. child.Name .. " (" .. child.ClassName .. ")")
			end
		end
	end
else
	warn("OPEN_BUTTON setting is false!")
	print("inventoryHandler.SETTINGS.OPEN_BUTTON =", inventoryHandler.SETTINGS.OPEN_BUTTON)
end

print("Fallback: adding events to all buttons")
for _, child in pairs(CustomInventoryGUI:GetDescendants()) do
	if child:IsA("GuiButton") or child:IsA("TextButton") or child:IsA("ImageButton") then
		print("Button found:", child.Name, "path:", child:GetFullName())

		pcall(function()
			child.MouseButton1Click:Connect(function()
				print("Button clicked:", child.Name)
				if child.Name:lower():find("open") or child.Name:lower():find("inventory") or child.Name:lower():find("button") then
					print("Inventory-related button detected, toggling")
					toggleInventory()
				end
			end)
		end)
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

print("Inventory system initialized!")
