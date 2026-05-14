-- Handles BoatDealer ProximityPrompts in Workspace.
-- Each dealer NPC sends spawn position index to the client via OpenBoatShop remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local openBoatShop = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("OpenBoatShop")

local DEALERS = {
	{ name = "BoatDealer1", spawnPos = 1 },
	{ name = "BoatDealer2", spawnPos = 2 },
	{ name = "BoatDealer3", spawnPos = 3 },
}

local function findPrompt(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			return d
		end
	end
end

for _, dealer in ipairs(DEALERS) do
	local model = workspace:FindFirstChild(dealer.name)
	if model then
		local prompt = findPrompt(model)
		if prompt then
			local spawnPos = dealer.spawnPos
			prompt.Triggered:Connect(function(plr)
				openBoatShop:FireClient(plr, spawnPos)
			end)
		end
	end
end
