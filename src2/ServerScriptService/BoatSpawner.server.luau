-- Boat spawn server code (personal boat management revised)
local spawnBoatRemote = game:GetService("ReplicatedStorage"):WaitForChild("SpawnBoat")
local BoatData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("BoatDataModule"))

-- Boat spawn area setup
local boatSpawnPoses = workspace:WaitForChild("BoatSpawnPoses")
local BOAT_SPAWN_AREA = {}
for i = 1, 10 do
	local part = boatSpawnPoses:FindFirstChild("BoatSpawnPos" .. i)
	if part then
		BOAT_SPAWN_AREA[i] = CFrame.new(part.Position)
	end
end
if #BOAT_SPAWN_AREA == 0 then
	warn("BoatSpawner: No BoatSpawnPos parts found in BoatSpawnPoses")
end

local BOAT_MODEL_FOLDER = game:GetService("ReplicatedStorage"):WaitForChild("Boats")
local occupiedSpots = {} -- Track occupied spawn positions (per player)

-- Get assigned spawn spot (revised - does not remove other players' boats)
local function getAssignedSpawnSpot(spawnIndex, playerUserId)
	-- Validate requested spawn position
	if not BOAT_SPAWN_AREA[spawnIndex] then
		warn("Invalid spawn position index:", spawnIndex)
		spawnIndex = 1 -- Use default position 1
	end

	-- Only check if position is occupied by another player, do not remove their boat
	if occupiedSpots[spawnIndex] and occupiedSpots[spawnIndex] ~= playerUserId then
		-- Another player's boat is here; overwrite the slot without removing it
	end

	-- Assign this position to current player
	occupiedSpots[spawnIndex] = playerUserId

	return BOAT_SPAWN_AREA[spawnIndex], spawnIndex
end

-- Remove only the given player's boats (revised)
local function removePlayerBoats(player)
	for _, obj in pairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("Owner") == player.UserId then
			-- Release only this player's spawn position
			local spawnIndex = obj:GetAttribute("SpawnIndex")
			if spawnIndex and occupiedSpots[spawnIndex] == player.UserId then
				occupiedSpots[spawnIndex] = nil
			end
			obj:Destroy()
		end
	end
end

-- Remove a specific player's boat at a given spawn index
local function removePlayerBoatAtSpawnIndex(playerUserId, spawnIndex)
	for _, obj in pairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("Owner") == playerUserId and obj:GetAttribute("SpawnIndex") == spawnIndex then
			obj:Destroy()
			break
		end
	end
end

-- Boat security setup
local function setupBoatSecurity(boat, ownerUserId, ownerName)
	-- Find VehicleSeat and apply security
	local function secureVehicleSeat(obj)
		if obj:IsA("VehicleSeat") then
			-- New security connection
			obj:GetPropertyChangedSignal("Occupant"):Connect(function()
				local occupant = obj.Occupant
				if occupant then
					local character = occupant.Parent
					local player = game.Players:GetPlayerFromCharacter(character)

					if player and player.UserId ~= ownerUserId then
						-- Eject other players
						obj.Occupant = nil

						-- Notify player (optional)
						local message = Instance.new("Message")
						message.Text = "This boat belongs to " .. ownerName
						message.Parent = player:FindFirstChild("PlayerGui") or workspace
						game:GetService("Debris"):AddItem(message, 3)
					end
				end
			end)
		end
	end

	-- Apply security to all VehicleSeats
	for _, obj in pairs(boat:GetDescendants()) do
		secureVehicleSeat(obj)
	end

	-- Apply security to newly added VehicleSeats
	boat.DescendantAdded:Connect(function(obj)
		if obj:IsA("VehicleSeat") then
			task.wait(0.1)
			secureVehicleSeat(obj)
		end
	end)
end

-- Boat spawn function (revised)
local function spawnBoat(player, boatName, assignedSpawnIndex)
	-- Validate boat data
	local boatData = BoatData.Boats[boatName]
	if not boatData then
		warn("Unauthorized boat spawn attempt: " .. tostring(boatName))
		return
	end

	-- Verify ownership
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("No leaderstats - player:", player.Name)
		return
	end

	local boats = leaderstats:FindFirstChild("Boats")
	if not boats then
		warn("No boats folder - player:", player.Name)
		return
	end

	local boatBool = boats:FindFirstChild(boatData.storageName)
	if not boatBool or not boatBool.Value then
		warn("Player does not own boat - player:", player.Name, "boat:", boatName)
		player:Kick("ClientHacker - Unauthorized boat spawn")
		return
	end

	-- Remove this player's existing boats
	removePlayerBoats(player)

	-- Find boat model
	local boatModel = BOAT_MODEL_FOLDER:FindFirstChild(boatData.storageName)
	if not boatModel then
		warn("Boat model not found:", boatData.storageName)
		return
	end

	-- Assign spawn position (with player ID)
	local spawnCFrame, spawnIndex = getAssignedSpawnSpot(assignedSpawnIndex, player.UserId)

	-- Clone and spawn boat
	local newBoat = boatModel:Clone()
	newBoat.Name = boatData.storageName .. "_" .. player.Name

	-- Set owner attributes
	newBoat:SetAttribute("Owner", player.UserId)
	newBoat:SetAttribute("OwnerName", player.Name)
	newBoat:SetAttribute("SpawnIndex", spawnIndex)

	-- Set boat position
	if newBoat.PrimaryPart then
		newBoat:SetPrimaryPartCFrame(spawnCFrame)
	else
		-- Use first Part if no PrimaryPart
		for _, part in pairs(newBoat:GetChildren()) do
			if part:IsA("BasePart") then
				part.CFrame = spawnCFrame
				break
			end
		end
	end

	-- Apply boat security
	setupBoatSecurity(newBoat, player.UserId, player.Name)

	-- Add to world
	newBoat.Parent = workspace
end

-- Connect remote event
spawnBoatRemote.OnServerEvent:Connect(function(player, boatName, assignedSpawnIndex)
	-- Use default spawn position 1 if not provided
	assignedSpawnIndex = assignedSpawnIndex or 1

	spawnBoat(player, boatName, assignedSpawnIndex)
end)

-- Clean up only this player's boats when they leave (revised)
game.Players.PlayerRemoving:Connect(function(player)
	removePlayerBoats(player)
end)
