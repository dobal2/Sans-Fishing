-- Main server script (place in ServerScriptService) - 1 trap limit per player
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DataManager = require(script:WaitForChild("DataManager"))

-- Connect player events
Players.PlayerAdded:Connect(DataManager.OnPlayerAdded)
Players.PlayerRemoving:Connect(DataManager.OnPlayerRemoving)

local FishTrapManager = {}

-- Place fish trap function (uses DataManager)
function FishTrapManager.PlaceFishTrap(player, trapName, position, rotation)
	-- Check trap count limit (max 1)
	if not FishTrapManager.CanPlaceTrap(player) then
		local ShowNoticeEvent = ReplicatedStorage:FindFirstChild("ShowNoticeEvent")
		if ShowNoticeEvent then
			ShowNoticeEvent:FireClient(player, "You already have a FishTrap! You can only place 1 trap total.")
		end
		return nil
	end

	local trapId = DataManager:PlaceFishTrap(player, trapName, position, rotation)

	if trapId then
	else
	end

	return trapId
end

-- Restore fish traps function (uses DataManager)
function FishTrapManager.RestorePlayerFishTraps(player)
	return DataManager:RestorePlayerFishTraps(player)
end



-- Check trap count per player (only count active traps)
function FishTrapManager.GetPlayerTrapCount(player)
	local playerData = DataManager:GetData(player)
	if not playerData then return 0 end

	local trapCount = 0
	for key, trapData in pairs(playerData) do
		if string.find(key, "FishTrapData_") and trapData and type(trapData) == "table" then
			-- Only count active traps
			if trapData.isActive == true then
				trapCount = trapCount + 1
			end
		end
	end

	return trapCount
end

-- Check trap count limit (max 1 per player)
function FishTrapManager.CanPlaceTrap(player)
	local maxTraps = 1 -- Max traps per player
	local currentTraps = FishTrapManager.GetPlayerTrapCount(player)

	return currentTraps < maxTraps
end

-- Remove all traps for a player
function FishTrapManager.RemoveAllPlayerTraps(player)
	local playerData = DataManager:GetData(player)
	if not playerData then return end

	local removedCount = 0

	-- Remove traps from world
	for _, obj in pairs(workspace:GetChildren()) do
		local ownerValue = obj:FindFirstChild("Owner")
		if ownerValue and ownerValue.Value == player.Name then
			local trapIdValue = obj:FindFirstChild("TrapId")
			if trapIdValue then
				-- Also remove from data
				DataManager:UpdateData(player, "FishTrapData_" .. trapIdValue.Value, nil)
				obj:Destroy()
				removedCount = removedCount + 1
			end
		end
	end

	return removedCount
end



-- Initialize on server start
local function initialize()

	-- Save all trap data on server close
	game:BindToClose(function()

		for _, player in pairs(Players:GetPlayers()) do
			-- Force save each player's trap data
			for _, obj in pairs(workspace:GetChildren()) do
				local ownerValue = obj:FindFirstChild("Owner")
				local trapIdValue = obj:FindFirstChild("TrapId")
				local trapTypeValue = obj:FindFirstChild("TrapType")

				if ownerValue and ownerValue.Value == player.Name and trapIdValue and trapTypeValue then
					local trapData = {
						position = {
							x = obj.PrimaryPart.Position.X,
							y = obj.PrimaryPart.Position.Y,
							z = obj.PrimaryPart.Position.Z
						},
						rotation = {
							x = obj.PrimaryPart.Rotation.X,
							y = obj.PrimaryPart.Rotation.Y,
							z = obj.PrimaryPart.Rotation.Z
						},
						lastSaveTime = tick(),
						trapId = trapIdValue.Value,
						trapType = trapTypeValue.Value,
						isActive = true
					}

					DataManager:UpdateData(player, "FishTrapData_" .. trapIdValue.Value, trapData)
				end
			end
		end

		wait(3) -- Allow time to save
	end)

end

-- Run initialization
initialize()

-- Return module (usable from other scripts)
return FishTrapManager
