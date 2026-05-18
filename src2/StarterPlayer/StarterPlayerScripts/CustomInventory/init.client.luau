-- CustomInventory/init.client.luau
-- Fish inventory is now server-side data. This script listens to InventoryDataSync
-- and FishDataAdded to maintain a local copy, then renders slots from that data.
-- Clicking a fish slot sends EquipFishRequest/UnequipFishRequest to the server.
-- Rods and bubble tools still appear in Backpack as Tools; those are handled
-- by the original newTool() path (unchanged).

local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- ──────────────────────────────────────────────────────────────────────────────
-- Fish count display (based on server data table)
-- ──────────────────────────────────────────────────────────────────────────────

local function updateFishCount()
	local count = inventoryHandler:getFishCount()
	fishCountText.Text = "Fish Count: " .. count
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Lock UI sync
-- ──────────────────────────────────────────────────────────────────────────────

local function updateAllFishLockUI()
	inventoryHandler:refreshAllLockUI(hotBar, Inventory)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Slot display helpers
-- ──────────────────────────────────────────────────────────────────────────────

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

local function closeInventory()
	Inventory.Visible = false
	player.PlayerGui:SetAttribute("ActiveLargeUI", nil)
	inventoryHandler:removeCurrentDescription()
	if not inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
		removeEmptySlots()
	end
end

local function toggleInventory()
	if Inventory.Visible then
		closeInventory()
		return
	end

	local active = player.PlayerGui:GetAttribute("ActiveLargeUI")
	if active then
		player.PlayerGui:SetAttribute("ActiveLargeUI", nil)
		task.wait(0.1)
	end

	Inventory.Visible = true
	player.PlayerGui:SetAttribute("ActiveLargeUI", "Inventory")
	inventoryHandler:removeCurrentDescription()
	showSlots()
	task.spawn(function()
		task.wait(0.1)
		updateAllFishLockUI()
	end)
end

player.PlayerGui:GetAttributeChangedSignal("ActiveLargeUI"):Connect(function()
	if player.PlayerGui:GetAttribute("ActiveLargeUI") ~= "Inventory" and Inventory.Visible then
		Inventory.Visible = false
		inventoryHandler:removeCurrentDescription()
		if not inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
			removeEmptySlots()
		end
	end
end)

local function manageInventory(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		toggleInventory()
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

-- ──────────────────────────────────────────────────────────────────────────────
-- Rod / bubble tools in Backpack (unchanged path)
-- ──────────────────────────────────────────────────────────────────────────────

local function newTool(tool)
	if tool:IsA("Tool") then
		-- Only handle non-fish tools via the old path (rods, bubbles)
		if tool:FindFirstChild("FishValue") then return end
		inventoryHandler:newTool(tool)
	end
end

local function reloadInventory(character)
	inventoryHandler.currentlyEquipped = nil
	backpack = player:WaitForChild("Backpack")

	backpack.ChildAdded:Connect(newTool)
	character.ChildAdded:Connect(newTool)

	task.spawn(function()
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and not tool:GetAttribute("toolAdded") and not tool:FindFirstChild("FishValue") then
				newTool(tool)
			end
		end

		task.wait(0.5)
		updateFishCount()
	end)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Server data sync listeners
-- ──────────────────────────────────────────────────────────────────────────────

task.spawn(function()
	local Misc = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc")

	-- Full inventory sync (on join or after sell)
	local inventoryDataSync = Misc:WaitForChild("InventoryDataSync")
	inventoryDataSync.OnClientEvent:Connect(function(fishList)
		inventoryHandler:syncInventory(fishList)
		updateFishCount()
		task.spawn(function()
			task.wait(0.1)
			updateAllFishLockUI()
		end)
	end)

	-- New fish added (after successful catch)
	local fishDataAdded = Misc:WaitForChild("FishDataAdded")
	fishDataAdded.OnClientEvent:Connect(function(fishItem, index)
		inventoryHandler:addFishItem(fishItem, index)
		updateFishCount()
	end)

	-- Request initial data in case sync fired before listeners were ready
	local getInventoryData = Misc:WaitForChild("GetInventoryData")
	local ok, result = pcall(function()
		return getInventoryData:InvokeServer()
	end)
	if ok and result then
		inventoryHandler:syncInventory(result)
		updateFishCount()
	end
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- Global helpers
-- ──────────────────────────────────────────────────────────────────────────────

_G.lastClickTime = lastClickTime
_G.doubleClickDelay = doubleClickDelay

-- ──────────────────────────────────────────────────────────────────────────────
-- Bootstrap
-- ──────────────────────────────────────────────────────────────────────────────

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

		local toolEquipped = character and character:FindFirstChildOfClass("Tool")
		local toolPosition = inventoryHandler:getToolPosition(toolEquipped) or 0

		for i = toolPosition + direction, direction < 0 and 1 or inventoryHandler.slotAmount, direction do
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
