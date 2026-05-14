-- Handles all fish trap shop ProximityPrompts in Workspace.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local buyFishTrapBindable = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("BuyFishTrapBindable")

local TRAP_MODELS = {
	["Basic FishtrapMainModel"] = "BasicFishTrap",
	["T2 FishtrapMainModel"]    = "AdvancedFishTrap",
	["T3 FishtrapMainModel"]    = "MasterFishTrap",
	["Robux FishtrapMainModel"] = "RobuxFishTrap",
}

local function findPrompt(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			return d
		end
	end
end

for modelName, trapType in pairs(TRAP_MODELS) do
	local model = workspace:FindFirstChild(modelName)
	if model then
		local prompt = findPrompt(model)
		if prompt then
			local t = trapType
			prompt.Triggered:Connect(function(plr)
				buyFishTrapBindable:Fire(plr, t)
			end)
		end
	end
end
