local Players = game:GetService("Players")
local FClient = require(game.ReplicatedStorage.Modules.FishingClientModule)
local player = Players.LocalPlayer

repeat task.wait() until game:IsLoaded()

local dataReady
repeat
	task.wait()
	dataReady = player:FindFirstChild("DataReady")
until dataReady and dataReady.Value == true

local function isRodTool(toolName)
	return toolName:lower():match("rod$") ~= nil
end

local function initFishingTool(tool)
	if not tool:IsA("Tool") then return end
	if not isRodTool(tool.Name) then return end
	if tool:FindFirstChild("FishValue") then return end
	if tool:GetAttribute("ClientInit") then return end
	tool:SetAttribute("ClientInit", true)
	FClient.init(tool)
end

local function resetClientInit(container)
	for _, tool in ipairs(container:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("ClientInit") then
			tool:SetAttribute("ClientInit", nil)
		end
	end
end

local function watchContainer(container)
	container.ChildAdded:Connect(initFishingTool)
	for _, tool in ipairs(container:GetChildren()) do
		initFishingTool(tool)
	end
end

resetClientInit(player.Backpack)
watchContainer(player.Backpack)
if player.Character then
	watchContainer(player.Character)
end

player.CharacterAdded:Connect(function(char)
	resetClientInit(player.Backpack)
	watchContainer(char)
end)
