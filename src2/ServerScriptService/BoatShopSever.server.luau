local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:WaitForChild("BuyBoat")
local BoatData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BoatDataModule"))

remote.OnServerEvent:Connect(function(plr, boatName)
	local boat = BoatData.Boats[boatName]
	if not boat then
		warn("Unauthorized boat purchase attempt: " .. tostring(boatName))
		plr:Kick("ClientHacker - Invalid boat purchase attempt")
		return
	end

	-- Check leaderstats
	local leaderstats = plr:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("No leaderstats - player:", plr.Name)
		return
	end

	local coins = leaderstats:FindFirstChild("Coins")
	local boatsFolder = leaderstats:FindFirstChild("Boats")

	if not (coins and boatsFolder) then
		warn("Missing required leaderstats elements - player:", plr.Name)
		return
	end

	-- Check ownership
	local boatBool = boatsFolder:FindFirstChild(boat.storageName)
	local alreadyOwned = boatBool and boatBool.Value

	-- Process purchase (only if not already owned)
	if not alreadyOwned then
		-- Check balance
		if coins.Value < boat.price then
			warn("Insufficient balance - player:", plr.Name, "required:", boat.price, "has:", coins.Value)
			plr:Kick("ClientHacker - Insufficient funds")
			return
		end

		-- Deduct payment
		coins.Value -= boat.price

		-- Register ownership
		if boatBool then
			boatBool.Value = true
		end

		-- Deactivate default boat if needed
		local defaultBoat = boatsFolder:FindFirstChild("DefaultBoat")
		if defaultBoat then
			defaultBoat.Value = false
		end
	end

	-- Set boat ownership only (not a Tool)
	-- Deactivate other boats
	for _, otherBoat in pairs(boatsFolder:GetChildren()) do
		if otherBoat:IsA("BoolValue") and otherBoat.Name ~= boat.storageName then
			otherBoat.Value = false
		end
	end

	-- Activate selected boat
	if boatBool then
		boatBool.Value = true
	end

end)
