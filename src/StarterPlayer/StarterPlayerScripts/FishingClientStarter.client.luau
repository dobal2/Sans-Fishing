local Players = game:GetService("Players")
local FClient = require(game.ReplicatedStorage.Modules.FishingClientModule)
local player = Players.LocalPlayer

repeat wait() until game:IsLoaded()

-- 데이터 준비 기다리기
local dataReady
repeat
	task.wait()
	dataReady = player:FindFirstChild("DataReady")
until dataReady and dataReady.Value == true

print("🎣 Fishing clientLoaded")

-- Rod로 끝나는 도구인지 확인
local function isRodTool(toolName)
	return toolName:lower():match("rod$") ~= nil
end

-- 낚싯대 초기화 함수 (Rod로 끝나고 FishValue 없는 Tool만)
local function initFishingTool(tool)
	if not tool:IsA("Tool") then return end
	if not isRodTool(tool.Name) then return end
	if not tool:FindFirstChild("FishValue") then
		if not tool:GetAttribute("ClientInit") then
			tool:SetAttribute("ClientInit", true)
			print("✅ 클라 낚싯대 초기화:", tool:GetFullName())
			FClient.init(tool)
		end
	end
end

-- 여러 도구 초기화
local function initFishingTools(container)
	for _, tool in ipairs(container:GetChildren()) do
		initFishingTool(tool)
	end
end

-- 새로 추가되는 낚싯대 감지
local function connectToolWatcher(container)
	container.ChildAdded:Connect(function(child)
		initFishingTool(child)
	end)
end

-- 지속 감시 루프 (놓침 방지)
task.spawn(function()
	while true do
		initFishingTools(player.Backpack)
		if player.Character then
			initFishingTools(player.Character)
		end
		task.wait(1)
	end
end)

-- 첫 실행 시
connectToolWatcher(player.Backpack)
initFishingTools(player.Backpack)
if player.Character then
	connectToolWatcher(player.Character)
	initFishingTools(player.Character)
end

-- 캐릭터 재생성 시
player.CharacterAdded:Connect(function(char)
	connectToolWatcher(char)
	initFishingTools(char)
end)
