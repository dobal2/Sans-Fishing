-- Fake buoyancy for player-owned boats.
-- When the local player's boat spawns, attaches a VectorForce to the VehicleSeat
-- to apply upward spring + angular stabilisation so the boat doesn't flip under load.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SPRING_K   = 35     -- upward spring strength
local VERT_DAMP  = 5      -- vertical damping
local STAB_TORQUE = 800   -- angular stabilisation torque (roll/pitch)
local FLOAT_Y_OFFSET = 0  -- studs above water surface the boat rests at

local player = Players.LocalPlayer

local currentBoatConn = nil
local currentCleanup = nil

local function applyBuoyancy(seat)
	if currentCleanup then currentCleanup() end

	local att = Instance.new("Attachment")
	att.Name = "BuoyancyAtt"
	att.Parent = seat

	local vForce = Instance.new("VectorForce")
	vForce.Name = "BuoyancyForce"
	vForce.Attachment0 = att
	vForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vForce.ApplyAtCenterOfMass = true
	vForce.Force = Vector3.zero
	vForce.Parent = seat

	local torque = Instance.new("Torque")
	torque.Name = "BuoyancyTorque"
	torque.Attachment0 = att
	torque.RelativeTo = Enum.ActuatorRelativeTo.World
	torque.Torque = Vector3.zero
	torque.Parent = seat

	local conn = RunService.Heartbeat:Connect(function()
		if not seat or not seat.Parent then return end

		local mass = seat.AssemblyMass
		local gravity = workspace.Gravity
		local pos = seat.Position
		local vel = seat.AssemblyLinearVelocity

		-- Simple flat water at Y=0 (adjust if your water has a height)
		local waterY = FLOAT_Y_OFFSET
		local depth = waterY - pos.Y
		local accY = gravity + depth * SPRING_K - vel.Y * VERT_DAMP
		vForce.Force = Vector3.new(0, mass * accY, 0)

		-- Angular stabilisation: counteract roll and pitch, preserve yaw
		local cf = seat.CFrame
		local up = cf.UpVector
		local rollErr  = Vector3.new(up.Z, 0, -up.X) -- cross(up, worldY) projected
		local angVel = seat.AssemblyAngularVelocity
		local stabX = -angVel.X * 60 + rollErr.X * STAB_TORQUE
		local stabZ = -angVel.Z * 60 + rollErr.Z * STAB_TORQUE
		torque.Torque = Vector3.new(stabX, 0, stabZ)
	end)

	currentCleanup = function()
		conn:Disconnect()
		if att.Parent then att:Destroy() end
		if vForce.Parent then vForce:Destroy() end
		if torque.Parent then torque:Destroy() end
		currentCleanup = nil
	end
end

local function watchWorkspace()
	local function checkBoat(obj)
		if not obj:IsA("Model") then return end
		if obj:GetAttribute("Owner") ~= player.UserId then return end
		-- Find VehicleSeat (assembly root)
		local seat = nil
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("VehicleSeat") then seat = d; break end
		end
		if not seat then return end
		applyBuoyancy(seat)
	end

	-- Check existing boats
	for _, obj in ipairs(workspace:GetChildren()) do
		checkBoat(obj)
	end

	-- Watch for new boats
	if currentBoatConn then currentBoatConn:Disconnect() end
	currentBoatConn = workspace.ChildAdded:Connect(checkBoat)
end

watchWorkspace()

-- Re-scan on character respawn (player.UserId stays constant, no issue)
player.CharacterAdded:Connect(function()
	if currentCleanup then currentCleanup() end
end)
