local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ROD_SET = {
	FishingRod=true, SliverRod=true, GoldRod=true, CrystalRod=true, MagneticRod=true,
	BoneRod=true, CloverRod=true, RainbowRod=true, UnknownRod=true, RobuxRod=true,
	ElectricRod=true, RealisticRod=true, BlockyRod=true, ArcaneRod=true, VoidRod=true,
	FriendRod=true,
}

local function removeBackRod(character)
	local existing = character:FindFirstChild("BackRodVisual")
	if existing then existing:Destroy() end
end

local function showBackRod(character, toolName)
	removeBackRod(character)

	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then return end

	local rodTemplate = ServerStorage:FindFirstChild(toolName)
	if not rodTemplate then return end
	local srcHandle = rodTemplate:FindFirstChild("Handle")
	if not srcHandle then return end

	local clone = srcHandle:Clone()
	clone.Name = "BackRodVisual"
	clone.Anchored = false
	clone.CanCollide = false
	clone.CastShadow = false
	clone.Massless = true

	for _, v in ipairs(clone:GetDescendants()) do
		if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Sound") then
			v:Destroy()
		end
	end

	clone.Parent = character

	local ROD_OFFSETS = {
		FishingRod = CFrame.new(1, 1.5, 0.55) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(-30)),
		FriendRod  = CFrame.new(0, 0.5, 0.55) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(-30)),
	}

	local weld = Instance.new("Weld")
	weld.Name = "BackRodWeld"
	weld.Part0 = torso
	weld.Part1 = clone
	weld.C0 = ROD_OFFSETS[toolName] or (CFrame.new(-1, -1.5, 0.55) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(-30)))
	weld.C1 = CFrame.new(0, 0, 0)
	weld.Parent = clone
end

local function getBackpackRod(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return nil end
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and ROD_SET[tool.Name] then
			return tool.Name
		end
	end
	return nil
end

local function getEquippedRod(character)
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") and ROD_SET[tool.Name] then
			return tool.Name
		end
	end
	return nil
end

local function setupCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid")

	-- Tool equipped (rod moved from Backpack → Character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and ROD_SET[child.Name] then
			removeBackRod(character)
		end
	end)

	-- Tool unequipped (rod moved back to Backpack)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and ROD_SET[child.Name] then
			task.wait(0.1)
			local inBackpack = getBackpackRod(player)
			if inBackpack and not getEquippedRod(character) then
				showBackRod(character, inBackpack)
			end
		end
	end)

	-- Show rod on spawn if already in backpack
	task.wait(1)
	local inBackpack = getBackpackRod(player)
	if inBackpack and not getEquippedRod(character) then
		showBackRod(character, inBackpack)
	end

	-- Also watch for tools added to backpack (e.g. given via shop mid-session)
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and ROD_SET[child.Name] then
			task.wait(0.1)
			if not getEquippedRod(character) then
				showBackRod(character, child.Name)
			end
		end
	end)
	backpack.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and ROD_SET[child.Name] then
			-- If the removed rod was the one on the back, clean up
			-- (ToolEquipped handles this, but belt-and-suspenders)
			local existing = character:FindFirstChild("BackRodVisual")
			if existing and not getEquippedRod(character) then
				local stillInBackpack = getBackpackRod(player)
				if stillInBackpack then
					showBackRod(character, stillInBackpack)
				else
					removeBackRod(character)
				end
			end
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		setupCharacter(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
end
