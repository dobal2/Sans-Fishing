-- Handles Pap NPC ProximityPrompt (Robux shop opener).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local openRobuxShop = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("OpenRobuxShop")

local function findPrompt(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			return d
		end
	end
end

local pap = workspace:FindFirstChild("Pap")
if pap then
	local prompt = findPrompt(pap)
	if prompt then
		prompt.Triggered:Connect(function(player)
			openRobuxShop:FireClient(player)
		end)
	end
end
