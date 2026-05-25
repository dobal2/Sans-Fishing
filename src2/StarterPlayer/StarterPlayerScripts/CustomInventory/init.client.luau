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
		local fishPinned = inventoryHandler.HotBarFish[index]
		-- 이미 rod/bubble 슬롯이거나 fish가 핀된 슬롯은 건드리지 않음
		if toolObject or fishPinned then continue end
		if hotBar:FindFirstChild(tostring(index)) then continue end
		local frame = toolButton:Clone()
		frame.Visible = true
		frame.toolName.Text = ""
		local ta = frame:FindFirstChild("toolAmount")
		if ta then ta.Text = "" end
		frame.toolNumber.Text = index
		frame.Name = tostring(index)
		frame.Parent = hotBar
	end
end

local function removeEmptySlots()
	for index = 1, 9 do
		local toolObject = inventoryHandler.OBJECTS.HotBar[index]
		local fishPinned = inventoryHandler.HotBarFish[index]
		local toolFrame = hotBar:FindFirstChild(tostring(index))
		if not toolObject and not fishPinned and toolFrame then
			toolFrame:Destroy()
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
		-- Fish tools: auto-equip when server puts them in Backpack
		if tool:FindFirstChild("FishValue") then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				task.defer(function()
					-- equippedFishIndex nil = 의도적 unequip (로드 장착 등), 자동장착 안 함
					if tool.Parent == backpack and inventoryHandler.equippedFishIndex ~= nil then
						humanoid:EquipTool(tool)
					end
				end)
			end
			return
		end
		inventoryHandler:newTool(tool)
	end
end

local backpackConn = nil
local characterConn = nil

local function reloadInventory(character)
	inventoryHandler.currentlyEquipped = nil
	backpack = player:WaitForChild("Backpack")

	if backpackConn then backpackConn:Disconnect() end
	if characterConn then characterConn:Disconnect() end
	backpackConn = backpack.ChildAdded:Connect(newTool)
	characterConn = character.ChildAdded:Connect(newTool)

	task.spawn(function()
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and not tool:GetAttribute("toolAdded") and not tool:FindFirstChild("FishValue") then
				newTool(tool)
			end
		end

		task.wait(0.5)
		updateFishCount()
		showSlots()
	end)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Server data sync listeners
-- ──────────────────────────────────────────────────────────────────────────────

task.spawn(function()
	local Misc = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc")

	local inventoryDataSync   = Misc:WaitForChild("InventoryDataSync")
	local fishDataAdded       = Misc:WaitForChild("FishDataAdded")
	local getInventoryData    = Misc:WaitForChild("GetInventoryData")
	local getFishHotBarPins   = Misc:WaitForChild("GetFishHotBarPins")
	local saveFishHotBarPins  = Misc:WaitForChild("SaveFishHotBarPins")

	-- 초기 로드 완료 전에는 핀 저장을 막는 플래그
	_G.hotBarPinsReady = false

	-- 핀 저장: 초기 로드 완료 후에만 서버에 전송 (slot → fishIndex 숫자로 저장)
	_G.saveFishHotBarPins = function()
		if not _G.hotBarPinsReady then return end
		local pins = {}
		for slot, fishIdx in pairs(inventoryHandler.HotBarFish) do
			if inventoryHandler.FishList[fishIdx] then
				pins[slot] = fishIdx
			end
		end
		saveFishHotBarPins:FireServer(pins)
	end

	local function restorePins(savedPins, fishList)
		local didRestore = false
		if savedPins and next(savedPins) then
			for slot, fishIdx in pairs(savedPins) do
				local s = tonumber(slot)
				local idx = tonumber(fishIdx)
				if not s or not idx then continue end
				if fishList[idx] then
					inventoryHandler:setHotBarFishSlotPublic(s, idx)
					didRestore = true
				end
			end
		end
		return didRestore
	end

	-- 초기 로드: 인벤 + 핀 순서대로 가져오기
	local ok1, fishList = pcall(function() return getInventoryData:InvokeServer() end)
	local ok2, savedPins = pcall(function() return getFishHotBarPins:InvokeServer() end)

	-- Cache pins for use if initial fish list arrives late (via InventoryDataSync)
	local pendingInitialPins = ok2 and savedPins or nil

	if ok1 and fishList then
		inventoryHandler:syncInventory(fishList, false)
		updateFishCount()
	end

	-- 저장된 핀 복원 후 남은 빈 슬롯 자동 채우기
	local pinsRestored = restorePins(pendingInitialPins, inventoryHandler.FishList)
	if pinsRestored then pendingInitialPins = nil end
	inventoryHandler:autoFillPublic()
	inventoryHandler:rebuildFishInventoryPublic()

	-- 초기 로드 완료: 이제부터 핀 변경 시 서버에 저장
	_G.hotBarPinsReady = true

	-- 판매/리셋 후 전체 동기화: 서버에서 핀을 다시 불러와 복원
	inventoryDataSync.OnClientEvent:Connect(function(fishList2)
		_G.hotBarPinsReady = false

		-- If initial pins weren't restored yet (server sent fish data late), restore now
		if pendingInitialPins then
			inventoryHandler:syncInventory(fishList2, false)
			updateFishCount()
			restorePins(pendingInitialPins, inventoryHandler.FishList)
			pendingInitialPins = nil
			inventoryHandler:autoFillPublic()
			inventoryHandler:rebuildFishInventoryPublic()
			_G.hotBarPinsReady = true
			task.spawn(function() task.wait(0.1); updateAllFishLockUI() end)
			return
		end

		-- Normal sync after sell/give: restore pins by fish identity (indices may shift)
		local savedPinsBySlot = {}
		for slot, fishIdx in pairs(inventoryHandler.HotBarFish) do
			local fi = inventoryHandler.FishList[fishIdx]
			if fi then
				savedPinsBySlot[slot] = {name = fi.name, weight = fi.weight}
			end
		end
		inventoryHandler:syncInventory(fishList2, false)
		updateFishCount()
		local used = {}
		for slot, saved in pairs(savedPinsBySlot) do
			for newIdx, fi in ipairs(inventoryHandler.FishList) do
				if not used[newIdx] and fi.name == saved.name
					and math.abs((fi.weight or 0) - (saved.weight or 0)) < 0.001 then
					inventoryHandler:setHotBarFishSlotPublic(slot, newIdx)
					used[newIdx] = true
					break
				end
			end
		end
		inventoryHandler:rebuildFishInventoryPublic()
		_G.hotBarPinsReady = true
		task.spawn(function()
			task.wait(0.1)
			updateAllFishLockUI()
		end)
	end)

	-- 새 물고기 추가
	fishDataAdded.OnClientEvent:Connect(function(fishItem, index)
		inventoryHandler:addFishItem(fishItem, index)
		updateFishCount()
	end)
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
