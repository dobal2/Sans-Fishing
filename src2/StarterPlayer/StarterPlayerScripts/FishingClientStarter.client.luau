local Players = game:GetService("Players")
local FClient = require(game.ReplicatedStorage.Modules.FishingClientModule)
local player = Players.LocalPlayer

repeat wait() until game:IsLoaded()

-- Wait for data to be ready
local dataReady
repeat
	task.wait()
	dataReady = player:FindFirstChild("DataReady")
until dataReady and dataReady.Value == true


-- Check if tool name ends with "Rod"
local function isRodTool(toolName)
	return toolName:lower():match("rod$") ~= nil
end

-- Initialize fishing tool (only tools ending with Rod that have no FishValue)
local function initFishingTool(tool)
	if not tool:IsA("Tool") then return end
	if not isRodTool(tool.Name) then return end
	if not tool:FindFirstChild("FishValue") then
		if not tool:GetAttribute("ClientInit") then
			tool:SetAttribute("ClientInit", true)
			FClient.init(tool)
		end
	end
end

-- Initialize multiple tools
local function initFishingTools(container)
	for _, tool in ipairs(container:GetChildren()) do
		initFishingTool(tool)
	end
end

-- Detect newly added rods
local function connectToolWatcher(container)
	container.ChildAdded:Connect(function(child)
		initFishingTool(child)
	end)
end

-- Continuous watch loop (prevents missed tools)
task.spawn(function()
	while true do
		initFishingTools(player.Backpack)
		if player.Character then
			initFishingTools(player.Character)
		end
		task.wait(1)
	end
end)

-- Initial run
connectToolWatcher(player.Backpack)
initFishingTools(player.Backpack)
if player.Character then
	connectToolWatcher(player.Character)
	initFishingTools(player.Character)
end

-- On character respawn
player.CharacterAdded:Connect(function(char)
	connectToolWatcher(char)
	initFishingTools(char)
end)
