local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Check if there is a FishValue tool in my character
local function hasFishTool()
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return tool and tool:FindFirstChild("FishValue") ~= nil
end

-- Disable my own character's Prompt (always off)
local function onMyCharacterAdded(character)
	local hrp = character:WaitForChild("HumanoidRootPart")
	local prompt = hrp:WaitForChild("ReceiveFishPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end
end

-- Update other players' Prompt state
local function updateOtherPlayerPrompt(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local prompt = hrp:FindFirstChild("ReceiveFishPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then return end

	-- Other players' Prompt is only enabled when I have a FishTool equipped
	prompt.Enabled = hasFishTool()
end

-- Update all other players' Prompts
local function updateAllOtherPrompts()
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			updateOtherPlayerPrompt(otherPlayer.Character)
		end
	end
end

-- Detect my character's Tool changes
local function connectToolEvents(char)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.wait(0.05)
			updateAllOtherPrompts()
		end
	end)

	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			task.wait(0.05)
			updateAllOtherPrompts()
		end
	end)
end

-- Handle other player character added
local function onOtherPlayerCharacterAdded(character)
	-- Wait for ProximityPrompt to be created then update state
	task.spawn(function()
		local hrp = character:WaitForChild("HumanoidRootPart")
		hrp:WaitForChild("ReceiveFishPrompt")
		task.wait(0.1)
		updateOtherPlayerPrompt(character)
	end)
end

-- Handle existing players
for _, existingPlayer in ipairs(Players:GetPlayers()) do
	if existingPlayer == player then
		-- Handle my character
		if existingPlayer.Character then
			onMyCharacterAdded(existingPlayer.Character)
			connectToolEvents(existingPlayer.Character)
		end
	else
		-- Handle other players
		if existingPlayer.Character then
			onOtherPlayerCharacterAdded(existingPlayer.Character)
		end
		existingPlayer.CharacterAdded:Connect(onOtherPlayerCharacterAdded)
	end
end

-- Handle new players joining
Players.PlayerAdded:Connect(function(newPlayer)
	if newPlayer ~= player then
		newPlayer.CharacterAdded:Connect(onOtherPlayerCharacterAdded)
	end
end)

-- Connect my character events
player.CharacterAdded:Connect(function(char)
	onMyCharacterAdded(char)
	connectToolEvents(char)
	-- Update other players' Prompts when I respawn
	updateAllOtherPrompts()
end)
