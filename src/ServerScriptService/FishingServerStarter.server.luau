local Players = game:GetService("Players")
local FServer = require(game.ReplicatedStorage.Modules.FishingServerModule)
local ServerScriptService = game:GetService("ServerScriptService")
local datamanager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))

-- 유저 데이터 도착 대기
local function waitForData(player)
	local data = datamanager:GetData(player)
	while not data do
		task.wait()
		data = datamanager:GetData(player)
	end
	return data
end

-- Rod로 끝나는 도구인지 확인
local function isRodTool(toolName)
	return toolName:lower():match("rod$") ~= nil
end

-- 낚싯대 초기화 함수 (Rod로 끝나고 FishValue 없는 Tool만)
local function initFishingTool(tool)
	if not tool:IsA("Tool") then return end
	if not isRodTool(tool.Name) then return end
	if not tool:FindFirstChild("FishValue") then
		if not tool:GetAttribute("ServerInit") then
			tool:SetAttribute("ServerInit", true)
			print("✅ 서버 낚싯대 초기화:", tool:GetFullName())
			FServer.init(tool)
		end
	end
end

-- 컨테이너에 있는 낚싯대 반복 감시
local function watchFishingTools(container)
	task.spawn(function()
		while container and container:IsDescendantOf(game) do
			for _, tool in ipairs(container:GetChildren()) do
				initFishingTool(tool)
			end
			task.wait(1)
		end
	end)
end

-- Tool 추가 즉시 감지
local function connectToolWatcher(container)
	container.ChildAdded:Connect(function(child)
		initFishingTool(child)
	end)
end

-- 플레이어 접속 시 처리
Players.PlayerAdded:Connect(function(player)
	local data = waitForData(player)
	print("🟢 Fishing Server Loaded for", player.Name)
	local backpack = player:WaitForChild("Backpack")
	connectToolWatcher(backpack)
	watchFishingTools(backpack)
	player.CharacterAdded:Connect(function(char)
		connectToolWatcher(char)
		watchFishingTools(char)
	end)
end)
