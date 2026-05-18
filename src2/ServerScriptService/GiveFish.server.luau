local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remote event for fish receiving
local FishReceiveNoticeEvent = Instance.new("RemoteEvent")
FishReceiveNoticeEvent.Name = "FishReceiveNoticeEvent"
FishReceiveNoticeEvent.Parent = ReplicatedStorage

-- Check if tool is a fish
local function isFish(tool)
	if not tool or not tool:IsA("Tool") then
		return false
	end
	local fishValue = tool:FindFirstChild("FishValue")
	if not fishValue then
		return false
	end
	-- Safely check IntValue with pcall
	local success, isIntValue = pcall(function()
		return fishValue:IsA("IntValue")
	end)
	return success and isIntValue
end

-- Attach prompt to character
local function addPromptToCharacter(char, owner)
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if not hrp then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ReceiveFishPrompt"
	prompt.ActionText = "Give My Fish"
	prompt.ObjectText = owner.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 1
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 6
	prompt.Parent = hrp

	prompt.Triggered:Connect(function(fromPlayer)
		if fromPlayer == owner then return end -- Ignore self

		local senderChar = fromPlayer.Character
		if not senderChar then return end

		-- Check if held tool is a fish and belongs to sender
		local tool = senderChar:FindFirstChildWhichIsA("Tool")
		if not isFish(tool) then
			FishReceiveNoticeEvent:FireClient(fromPlayer, "You need to hold a fish to give!")
			return
		end
		-- Ownership: tool must be in sender's character (not cloned/injected)
		if tool.Parent ~= senderChar then
			warn("Fish ownership mismatch:", fromPlayer.Name)
			return
		end

		local receiverBackpack = owner:FindFirstChild("Backpack")
		if receiverBackpack then
			-- Get fish info
			local fishName = tool.Name or "Unknown Fish"

			-- Transfer fish
			tool.Parent = receiverBackpack

			-- Success notifications
			FishReceiveNoticeEvent:FireClient(fromPlayer, "Fish given to " .. owner.Name .. "!")
			FishReceiveNoticeEvent:FireClient(owner, "Received fish from " .. fromPlayer.Name .. "!")
		else
			-- Backpack not found
			FishReceiveNoticeEvent:FireClient(fromPlayer, "Failed to give fish to " .. owner.Name)
		end
	end)
end

local function setupPlayer(player)
	if player.Character then
		addPromptToCharacter(player.Character, player)
	end
	player.CharacterAdded:Connect(function(char)
		task.wait(1)
		addPromptToCharacter(char, player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in pairs(Players:GetPlayers()) do
	setupPlayer(player)
end
