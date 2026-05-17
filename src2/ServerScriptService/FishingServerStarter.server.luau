local Players = game:GetService("Players")
local FServer = require(game.ReplicatedStorage.Modules.FishingServerModule)
local ServerScriptService = game:GetService("ServerScriptService")
local datamanager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))

-- Wait for user data to arrive
local function waitForData(player)
	local data = datamanager:GetData(player)
	while not data do
		if not player:IsDescendantOf(Players) then return nil end
		task.wait(0.5)
		data = datamanager:GetData(player)
	end
	return data
end

-- Check if tool name ends with "Rod"
local function isRodTool(toolName)
	return toolName:lower():match("rod$") ~= nil
end

-- Initialize fishing tool (only Tools ending in Rod without FishValue)
local function initFishingTool(tool)
	if not tool:IsA("Tool") then return end
	if not isRodTool(tool.Name) then return end
	if not tool:FindFirstChild("FishValue") then
		if not tool:GetAttribute("ServerInit") then
			tool:SetAttribute("ServerInit", true)
			FServer.init(tool)
		end
	end
end

-- Watch fishing tools in container repeatedly
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

-- Detect tool added immediately
local function connectToolWatcher(container)
	container.ChildAdded:Connect(function(child)
		initFishingTool(child)
	end)
end

-- Handle player join
Players.PlayerAdded:Connect(function(player)
	local data = waitForData(player)
	if not data then return end
	local backpack = player:WaitForChild("Backpack")
	connectToolWatcher(backpack)
	watchFishingTools(backpack)
	player.CharacterAdded:Connect(function(char)
		connectToolWatcher(char)
		watchFishingTools(char)
	end)
end)
