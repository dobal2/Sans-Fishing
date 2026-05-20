local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script:WaitForChild("DataManager"))

local ShowNoticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("ShowNoticeEvent")
local PlaceFishTrapRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("PlaceFishTrapRemote")

local WATER_SURFACE_Y = -1.5
local TRAP_PLACE_Y    = -3.9
local VALID_TRAPS = { BasicFishTrap=true, AdvancedFishTrap=true, MasterFishTrap=true, RobuxFishTrap=true }

local FishTrapManager = {}

function FishTrapManager.GetPlayerTrapCount(player)
	local playerData = DataManager:GetData(player)
	if not playerData then return 0 end
	local count = 0
	for key, trapData in pairs(playerData) do
		if key:find("FishTrapData_") and type(trapData) == "table" and trapData.isActive == true then
			count = count + 1
		end
	end
	return count
end

function FishTrapManager.CanPlaceTrap(player)
	return FishTrapManager.GetPlayerTrapCount(player) < 1
end

function FishTrapManager.PlaceFishTrap(player, trapName, position, rotation)
	local trapId = DataManager:PlaceFishTrap(player, trapName, position, rotation)
	if not trapId then
		warn("PlaceFishTrap failed for player:", player.Name)
	end
	return trapId
end

function FishTrapManager.RestorePlayerFishTraps(player)
	return DataManager:RestorePlayerFishTraps(player)
end

function FishTrapManager.RemoveAllPlayerTraps(player)
	local playerData = DataManager:GetData(player)
	if not playerData then return 0 end
	local count = 0
	for _, obj in pairs(workspace:GetChildren()) do
		local ownerValue = obj:FindFirstChild("Owner")
		if ownerValue and ownerValue.Value == player.Name then
			local trapIdValue = obj:FindFirstChild("TrapId")
			if trapIdValue then
				DataManager:UpdateData(player, "FishTrapData_" .. trapIdValue.Value, nil)
				obj:Destroy()
				count = count + 1
			end
		end
	end
	return count
end

-- Connect player events
Players.PlayerAdded:Connect(DataManager.OnPlayerAdded)
Players.PlayerRemoving:Connect(DataManager.OnPlayerRemoving)

-- Placement remote handler
PlaceFishTrapRemote.OnServerEvent:Connect(function(player, trapName, position, rotation)
	if not VALID_TRAPS[trapName] then return end
	if typeof(position) ~= "Vector3" then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	local fishTrapsFolder = leaderstats and leaderstats:FindFirstChild("FishTraps")
	local trapBool = fishTrapsFolder and fishTrapsFolder:FindFirstChild(trapName)
	if not trapBool or not trapBool.Value then
		ShowNoticeEvent:FireClient(player, "You don't own this fish trap!")
		return
	end

	if position.Y >= WATER_SURFACE_Y then
		ShowNoticeEvent:FireClient(player, "Place the fish trap in the water!")
		return
	end

	if not FishTrapManager.CanPlaceTrap(player) then
		ShowNoticeEvent:FireClient(player, "You already have a Fish Trap placed! Collect it first.")
		return
	end

	local rot = rotation or Vector3.new(0, 0, 0)
	local snappedPosition = Vector3.new(position.X, TRAP_PLACE_Y, position.Z)
	local trapId = FishTrapManager.PlaceFishTrap(player, trapName, snappedPosition, rot)
	if trapId then
		ShowNoticeEvent:FireClient(player, "Fish Trap placed!")
	else
		ShowNoticeEvent:FireClient(player, "Failed to place Fish Trap!")
	end
end)

game:BindToClose(function()
	for _, player in pairs(Players:GetPlayers()) do
		for _, obj in pairs(workspace:GetChildren()) do
			local ownerValue = obj:FindFirstChild("Owner")
			local trapIdValue = obj:FindFirstChild("TrapId")
			local trapTypeValue = obj:FindFirstChild("TrapType")
			if ownerValue and ownerValue.Value == player.Name and trapIdValue and trapTypeValue and obj.PrimaryPart then
				DataManager:UpdateData(player, "FishTrapData_" .. trapIdValue.Value, {
					position = { x = obj.PrimaryPart.Position.X, y = obj.PrimaryPart.Position.Y, z = obj.PrimaryPart.Position.Z },
					rotation = { x = obj.PrimaryPart.Rotation.X, y = obj.PrimaryPart.Rotation.Y, z = obj.PrimaryPart.Rotation.Z },
					lastSaveTime = tick(),
					trapId = trapIdValue.Value,
					trapType = trapTypeValue.Value,
					isActive = true,
				})
			end
		end
	end
	task.wait(3)
end)

return FishTrapManager
