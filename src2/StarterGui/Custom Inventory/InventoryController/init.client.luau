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
-- 🔧 수정: 올바른 변수명 (공백 제거)

local inventoryHandler = require(script.SETTINGS)

-- 🆕 물고기 잠금 변수들
local lastClickTime = {}
local doubleClickDelay = 0.3

-- 🐟 직접 백팩/캐릭터 뒤져서 물고기 세는 함수
local function updateFishCount()
	local fishCount = 0
	local player = game:GetService("Players").LocalPlayer

	-- 백팩에서 물고기 세기
	for _, tool in pairs(player.Backpack:GetChildren()) do
		if tool:IsA("Tool") and tool:FindFirstChild("FishValue") then
			local amount = tool:GetAttribute("amount") or 1
			fishCount = fishCount + amount
		end
	end

	-- 캐릭터에서 장착된 물고기 세기
	if player.Character then
		for _, tool in pairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") and tool:FindFirstChild("FishValue") then
				local amount = tool:GetAttribute("amount") or 1
				fishCount = fishCount + amount
			end
		end
	end

	-- UI 업데이트
	fishCountText.Text = "Fish Count: " .. fishCount
	--print("🐟 Fish Count:", fishCount)
end

-- 🆕 백팩/캐릭터 변화 감지해서 자동 업데이트
local function connectFishCountUpdates()
	local player = game:GetService("Players").LocalPlayer

	-- 백팩 변화 감지
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

	-- 캐릭터 리스폰 시 다시 연결
	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		updateFishCount()

		-- 새 캐릭터의 변화 감지
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

	-- 현재 캐릭터에도 연결
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

-- 🆕 모든 물고기 잠금 상태 UI 업데이트
local function updateAllFishLockUI()
	-- 핫바 업데이트
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

	-- 인벤토리 업데이트
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

-- 🆕 물고기 잠금 함수
local function toggleFishLock(tool)
	if not tool:IsA("Tool") then return end

	-- 물고기인지 확인 (FishValue가 있는지 체크)
	local fishValue = tool:FindFirstChild("FishValue")
	if not fishValue then return end

	-- 현재 잠금 상태 토글
	local currentLock = tool:GetAttribute("fishlock") or false
	tool:SetAttribute("fishlock", not currentLock)

	--print(currentLock and "🔓 물고기 잠금 해제:" or "🔒 물고기 잠금:", tool.Name)

	-- UI 즉시 업데이트
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

-- 🔧 개선된 인벤토리 토글 함수
local function toggleInventory()
	Inventory.Visible = not Inventory.Visible
	local currentState = Inventory.Visible

	inventoryHandler:removeCurrentDescription()

	if currentState then
		-- 인벤토리 열림
		showSlots()
		-- 🆕 인벤토리 열 때 잠금 상태 UI 업데이트 (에러 방지)
		task.spawn(function()
			task.wait(0.1)
			if updateAllFishLockUI then
				updateAllFishLockUI()
			end
		end)
		--print("📦 인벤토리 열림")
	else
		-- 인벤토리 닫힘
		if not inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
			removeEmptySlots()
		end
		--print("📦 인벤토리 닫힘")
	end
end

-- 🔧 기존 manageInventory 함수 수정 (키보드 입력용)
local function manageInventory(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		--print("⌨️ 키보드로 인벤토리 토글 실행")
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

-- 🆕 강제 인벤토리 토글 함수 (테스트용)
local function forceToggleInventory()
	--print("🚀 강제 인벤토리 토글 실행")
	toggleInventory()
end

-- 🆕 전역 함수로 등록 (외부에서 호출 가능하게)
_G.forceToggleInventory = forceToggleInventory
_G.toggleInventory = toggleInventory
_G.updateFishCount = updateFishCount

local function searchTool()
	inventoryHandler:searchTool()
end

-- 🔧 기존 newTool 함수 수정 (간단하게)
local function newTool(tool)
	if tool:IsA("Tool") then
		inventoryHandler:newTool(tool)
		-- 🆕 새 툴 추가 시 잠금 상태 UI 업데이트 (에러 방지)
		task.spawn(function()
			task.wait(0.1)
			if updateAllFishLockUI then
				updateAllFishLockUI()
			end
			-- 🐟 물고기 카운트 업데이트
			updateFishCount()
		end)
	end
end

-- 🔧 기존 reloadInventory 함수 수정 (간단하게)
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

	-- 🐟 초기 물고기 카운트 업데이트
	task.spawn(function()
		task.wait(0.5)
		updateFishCount()
	end)
end

-- 🔧 UI 사이즈 조정 부분 제거됨 (원래 updateHudPosition 함수)

local function getToolEquipped()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Tool")
end

-- 🆕 전역 변수로 내보내기 (SETTINGS 모듈에서 사용)
_G.toggleFishLock = toggleFishLock
_G.lastClickTime = lastClickTime
_G.doubleClickDelay = doubleClickDelay

-- 🚀 초기화 시 연결 (강화된 모니터링)
connectFishCountUpdates()

-- 🆕 추가 감지 시스템 (인벤토리 시스템과 연동)
task.spawn(function()
	while true do
		task.wait(0.5) -- 0.5초마다 체크

		-- 🔍 백팩 변화 감지 (이전 카운트와 비교)
		local currentBackpackTools = {}
		for _, tool in pairs(player.Backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:FindFirstChild("FishValue") then
				table.insert(currentBackpackTools, tool.Name)
			end
		end

		-- 캐릭터 도구도 포함
		if player.Character then
			for _, tool in pairs(player.Character:GetChildren()) do
				if tool:IsA("Tool") and tool:FindFirstChild("FishValue") then
					table.insert(currentBackpackTools, tool.Name)
				end
			end
		end

		-- 🔄 변화가 있으면 즉시 업데이트
		if #currentBackpackTools ~= (_G.lastToolCount or 0) then
			--print("🔄 도구 개수 변화 감지:", (_G.lastToolCount or 0), "→", #currentBackpackTools)
			_G.lastToolCount = #currentBackpackTools
			updateFishCount()
		end
	end
end)

-- 🔧 초기화 (UI 사이즈 업데이트 제거)
reloadInventory(player.Character or player.CharacterAdded:Wait())

-- 🔧 이벤트 연결 (ViewportSize 변경 이벤트 제거)
player.CharacterAdded:Connect(reloadInventory)
Inventory.SearchBox:GetPropertyChangedSignal("Text"):Connect(searchTool)

-- 🔧 설정에 따른 기능 활성화
if inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
	showSlots()
end

-- 🔧 키보드 바인딩 (백틱 키 등)
if inventoryHandler.SETTINGS.INVENTORY_KEYBIND then
	ContextActionService:BindAction("manageInventory", manageInventory, false, inventoryHandler.SETTINGS.INVENTORY_KEYBIND)
end

-- 🔍 디버깅: GUI 구조 확인

for _, child in pairs(CustomInventoryGUI:GetChildren()) do
	print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
end

-- 🔍 여러 방법으로 버튼 찾기 시도
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
		--print("✅ 버튼 발견:", button.Name, "방법", i)
		break
	end
end

-- 🆕 인벤토리 버튼 클릭 이벤트 (개선된 버전)
if inventoryHandler.SETTINGS.OPEN_BUTTON then
	if actualButton then
		--print("🔧 버튼 연결 시도:", actualButton.Name)
		--print("버튼 위치:", actualButton.Position)
		--print("버튼 크기:", actualButton.Size)
		--print("버튼 보임:", actualButton.Visible)
		--print("버튼 활성:", actualButton.Active)

		-- 🔧 다양한 이벤트 시도
		pcall(function()
			actualButton.MouseButton1Click:Connect(function()
				print("🖱️ MouseButton1Click 작동!")
				toggleInventory()
			end)
		end)

		pcall(function()
			actualButton.MouseButton1Down:Connect(function()
				print("🖱️ MouseButton1Down 작동!")
				toggleInventory()
			end)
		end)

		pcall(function()
			actualButton.Activated:Connect(function()
				print("🖱️ Activated 이벤트 작동!")
				toggleInventory()
			end)
		end)

		-- 🆕 GuiButton 전용 이벤트도 시도
		if actualButton:IsA("GuiButton") then
			pcall(function()
				actualButton.MouseButton1Up:Connect(function()
					print("🖱️ MouseButton1Up 작동!")
					toggleInventory()
				end)
			end)
		end

		print("✅ 모든 이벤트 연결 완료!")

	else
		warn("❌ 어떤 방법으로도 인벤토리 버튼을 찾을 수 없습니다!")
		warn("사용 가능한 GUI 요소들:")
		for _, child in pairs(CustomInventoryGUI:GetChildren()) do
			if child:IsA("GuiObject") then
				warn("  - " .. child.Name .. " (" .. child.ClassName .. ")")
			end
		end
	end
else
	warn("⚠️ OPEN_BUTTON 설정이 false입니다!")
	print("inventoryHandler.SETTINGS.OPEN_BUTTON =", inventoryHandler.SETTINGS.OPEN_BUTTON)
end

-- 🔧 임시 해결책: 모든 GuiButton에 이벤트 추가
print("🔧 임시 해결책: 모든 버튼에 이벤트 추가")
for _, child in pairs(CustomInventoryGUI:GetDescendants()) do
	if child:IsA("GuiButton") or child:IsA("TextButton") or child:IsA("ImageButton") then
		print("버튼 발견:", child.Name, "경로:", child:GetFullName())

		pcall(function()
			child.MouseButton1Click:Connect(function()
				print("🎯 버튼 클릭됨:", child.Name)
				if child.Name:lower():find("open") or child.Name:lower():find("inventory") or child.Name:lower():find("button") then
					print("📦 인벤토리 관련 버튼으로 판단, 토글 실행")
					toggleInventory()
				end
			end)
		end)
	end
end

-- 🔧 마우스 휠 스크롤 기능
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

-- 🔧 초기 카운트 (스크립트 로드 완료 후)
task.spawn(function()
	task.wait(2)
	updateFishCount()
end)

print("🎮 인벤토리 시스템 초기화 완료!")