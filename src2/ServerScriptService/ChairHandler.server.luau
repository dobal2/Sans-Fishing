-- Handles all chair ProximityPrompts in Workspace.
-- Finds every Seat under workspace that has a ProximityPrompt and wires sit/unsit logic.

local function wireChair(seat)
	local prompt = seat:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(player)
		if not seat.Occupant then
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					seat:Sit(humanoid)
				end
			end
		elseif player.Character and seat.Occupant == player.Character:FindFirstChildOfClass("Humanoid") then
			local seatWeld = seat:FindFirstChild("SeatWeld")
			if seatWeld then
				seatWeld:Destroy()
			end
		end
	end)
end

local function scanForChairs(obj)
	for _, child in ipairs(obj:GetDescendants()) do
		if child:IsA("Seat") and child:FindFirstChildOfClass("ProximityPrompt") then
			wireChair(child)
		end
	end
end

-- Wire existing chairs
scanForChairs(workspace)

-- Wire chairs added later (e.g., placed at runtime)
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Seat") and desc:FindFirstChildOfClass("ProximityPrompt") then
		wireChair(desc)
	end
end)
