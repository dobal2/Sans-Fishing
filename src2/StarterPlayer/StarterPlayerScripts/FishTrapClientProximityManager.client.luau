local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")
local player = Players.LocalPlayer

-- Robux Fish Trap gamepass ID
local ROBUX_FISHTRAP_GAMEPASS_ID = 1423175879

-- Check gamepass ownership
local function hasGamepass(player, gamepassId)
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	return success and result
end

-- Find ProximityPrompts
local basicProximity = workspace:WaitForChild("Basic FishtrapMainModel"):WaitForChild("ProximityPrompt")
local advancedProximity = workspace:WaitForChild("T2 FishtrapMainModel"):WaitForChild("ProximityPrompt")
local masterProximity = workspace:WaitForChild("T3 FishtrapMainModel"):WaitForChild("ProximityPrompt")
local robuxProximity = workspace:WaitForChild("Robux FishtrapMainModel"):WaitForChild("ProximityPrompt")

-- Fish Trap mapping (ProximityPrompt -> Fish Trap name)
local proximityToFishTrap = {
	[basicProximity] = "BasicFishTrap",
	[advancedProximity] = "AdvancedFishTrap",
	[masterProximity] = "MasterFishTrap",
	[robuxProximity] = "RobuxFishTrap"
}

-- Update ActionText for a ProximityPrompt
local function updateProximityText(proximity, fishTrapName)
	local leaderstats = player:WaitForChild("leaderstats")
	if not leaderstats then return end

	local fishTrapsFolder = leaderstats:WaitForChild("FishTraps")
	local currentFishTrap = leaderstats:WaitForChild("CurrentFishTrap")
	if not (fishTrapsFolder and currentFishTrap) then return end

	local fishTrapBool = fishTrapsFolder:WaitForChild(fishTrapName)
	local currentFishTrapValue = currentFishTrap:WaitForChild("Value")
	if not (fishTrapBool and currentFishTrapValue) then return end

	-- Special handling for RobuxFishTrap
	if fishTrapName == "RobuxFishTrap" then
		local hasRobuxGamepass = hasGamepass(player, ROBUX_FISHTRAP_GAMEPASS_ID)

		if not hasRobuxGamepass then
			-- No gamepass
			return
		elseif fishTrapBool.Value then
			-- Has gamepass and owns trap
			if currentFishTrapValue.Value == fishTrapName then
				proximity.ActionText = "Equipped"
			else
				proximity.ActionText = "Equip"
			end
		else
			-- Has gamepass but not yet received
		end
		return
	end

	-- Normal Fish Trap handling
	if fishTrapBool.Value then
		-- Owned
		if currentFishTrapValue.Value == fishTrapName then
			-- Currently equipped
			proximity.ActionText = "Equipped"
		else
			-- Owned but not equipped
			proximity.ActionText = "Equip"
		end
	else
		-- Not owned
	end
end

-- Update all ProximityPrompts
local function updateAllProximityTexts()
	for proximity, fishTrapName in pairs(proximityToFishTrap) do
		updateProximityText(proximity, fishTrapName)
	end
end

-- Wait for leaderstats to load
local function waitForLeaderstats()
	local leaderstats = player:WaitForChild("leaderstats")
	if not leaderstats then
		warn("leaderstats failed to load")
		return
	end

	local fishTrapsFolder = leaderstats:WaitForChild("FishTraps")
	local currentFishTrap = leaderstats:WaitForChild("CurrentFishTrap")
	if not (fishTrapsFolder and currentFishTrap) then
		warn("FishTraps or CurrentFishTrap failed to load")
		return
	end

	-- Wait for each Fish Trap BoolValue
	local basicBool = fishTrapsFolder:WaitForChild("BasicFishTrap")
	local advancedBool = fishTrapsFolder:WaitForChild("AdvancedFishTrap")
	local masterBool = fishTrapsFolder:WaitForChild("MasterFishTrap")
	local robuxBool = fishTrapsFolder:WaitForChild("RobuxFishTrap")
	local currentValue = currentFishTrap:WaitForChild("Value")

	if not (basicBool and advancedBool and masterBool and robuxBool and currentValue) then
		warn("Fish Trap data failed to load")
		return
	end

	-- Set initial text
	updateAllProximityTexts()

	-- Connect change listeners
	basicBool.Changed:Connect(function()
		updateProximityText(basicProximity, "BasicFishTrap")
	end)

	advancedBool.Changed:Connect(function()
		updateProximityText(advancedProximity, "AdvancedFishTrap")
	end)

	masterBool.Changed:Connect(function()
		updateProximityText(masterProximity, "MasterFishTrap")
	end)

	robuxBool.Changed:Connect(function()
		updateProximityText(robuxProximity, "RobuxFishTrap")
	end)

	currentValue.Changed:Connect(function()
		updateAllProximityTexts() -- Update all texts when equipped fish trap changes
	end)

	-- Periodically check gamepass status changes
	task.spawn(function()
		local lastGamepassStatus = hasGamepass(player, ROBUX_FISHTRAP_GAMEPASS_ID)
		while true do
			task.wait(5) -- Check every 5 seconds
			local currentGamepassStatus = hasGamepass(player, ROBUX_FISHTRAP_GAMEPASS_ID)
			if currentGamepassStatus ~= lastGamepassStatus then
				updateProximityText(robuxProximity, "RobuxFishTrap")
				lastGamepassStatus = currentGamepassStatus
			end
		end
	end)

end

-- Wait for leaderstats and initialize
waitForLeaderstats()
