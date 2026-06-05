-- Handles all fish trap shop ProximityPrompts in Workspace.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shopRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop")
local openFishTrapShop = shopRemotes:WaitForChild("OpenFishTrapShop")

local TRAP_MODELS = {
	["Basic FishtrapMainModel"] = "BasicFishTrap",
	["T2 FishtrapMainModel"]    = "AdvancedFishTrap",
	["T3 FishtrapMainModel"]    = "MasterFishTrap",
	["Robux FishtrapMainModel"] = "RobuxFishTrap",
}

local TRAP_OBJECT_TEXT = {
	BasicFishTrap = "Basic Fish Trap",
	AdvancedFishTrap = "Advanced Fish Trap",
	MasterFishTrap = "Master Fish Trap",
	RobuxFishTrap = "Robux Fish Trap",
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
			prompt.ActionText = "View"
			prompt.ObjectText = TRAP_OBJECT_TEXT[trapType] or "Fish Trap"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10

			local t = trapType
			prompt.Triggered:Connect(function(plr)
				openFishTrapShop:FireClient(plr, t)
			end)
		end
	end
end
