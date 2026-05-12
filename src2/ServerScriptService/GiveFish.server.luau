local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remote event for fish receiving
local FishReceiveNoticeEvent = Instance.new("RemoteEvent")
FishReceiveNoticeEvent.Name = "FishReceiveNoticeEvent"
FishReceiveNoticeEvent.Parent = ReplicatedStorage

-- Inventory expansion gamepass ID (same as FishingServerModule)
local INVENTORY_EXPANSION_GAMEPASS_ID = 1294285302

-- Check inventory expansion gamepass
local function hasInventoryExpansionGamepass(player)
	local success, hasGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, INVENTORY_EXPANSION_GAMEPASS_ID)
	end)

	if success then
		return hasGamepass
	else
		warn("Failed to check inventory expansion gamepass:", player.Name)
		return false
	end
end

-- Get inventory limit function
local function getInventoryLimit(player)
	local baseLimit = 100
	local expandedLimit = 200

	if hasInventoryExpansionGamepass(player) then
		return expandedLimit
	else
		return baseLimit
	end
end

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

-- Check inventory limit including held fish
local function checkInventoryLimit(player)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	local fishCount = 0

	-- Count fish in backpack
	if backpack then
		for _, item in pairs(backpack:GetChildren()) do
			if item:IsA("Tool") and item:FindFirstChild("FishValue") then
				fishCount = fishCount + 1
			end
		end
	end

	-- Count currently held fish (important)
	if character then
		for _, item in pairs(character:GetChildren()) do
			if item:IsA("Tool") and item:FindFirstChild("FishValue") then
				fishCount = fishCount + 1
			end
		end
	end

	local inventoryLimit = getInventoryLimit(player)

	if fishCount >= inventoryLimit then
		local hasExpansion = hasInventoryExpansionGamepass(player)
		local message = hasExpansion and
			string.format("Expanded inventory full! (%d/200) Go sell fish", fishCount) or
			string.format("Inventory full! (%d/100) Go sell fish or buy expansion pass", fishCount)
		FishReceiveNoticeEvent:FireClient(player, message)
		return false
	end
	return true
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

		-- Check if held tool is a fish
		local tool = senderChar:FindFirstChildWhichIsA("Tool")
		if not isFish(tool) then
			-- Notify sender if not a fish
			FishReceiveNoticeEvent:FireClient(fromPlayer, "You need to hold a fish to give!")
			return
		end

		-- Check receiver's inventory limit
		if not checkInventoryLimit(owner) then
			-- Notify both if inventory is full
			FishReceiveNoticeEvent:FireClient(fromPlayer, owner.Name .. "'s inventory is full!")
			-- checkInventoryLimit already notifies the receiver
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

-- Attach prompt when player joins
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		task.wait(1)
		addPromptToCharacter(char, player)
	end)
end)

-- Also handle already connected players
for _, player in pairs(Players:GetPlayers()) do
	if player.Character then
		addPromptToCharacter(player.Character, player)
	end
	player.CharacterAdded:Connect(function(char)
		task.wait(1)
		addPromptToCharacter(char, player)
	end)
end
