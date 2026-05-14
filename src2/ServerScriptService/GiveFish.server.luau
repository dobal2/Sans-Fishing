local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remote event for fish receiving
local FishReceiveNoticeEvent = Instance.new("RemoteEvent")
FishReceiveNoticeEvent.Name = "FishReceiveNoticeEvent"
FishReceiveNoticeEvent.Parent = ReplicatedStorage

-- Inventory expansion gamepass ID (same as FishingServerModule)
local INVENTORY_EXPANSION_GAMEPASS_ID = 1294285302

-- Cache gamepass results per player (cleared on leave)
local gamepassCache = {}
Players.PlayerRemoving:Connect(function(p) gamepassCache[p.UserId] = nil end)

local function hasInventoryExpansionGamepass(player)
	if gamepassCache[player.UserId] ~= nil then return gamepassCache[player.UserId] end
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, INVENTORY_EXPANSION_GAMEPASS_ID)
	end)
	local has = success and result or false
	gamepassCache[player.UserId] = has
	return has
end

local function getInventoryLimit(player)
	return hasInventoryExpansionGamepass(player) and 200 or 100
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

	local hasExpansion = hasInventoryExpansionGamepass(player)
	local inventoryLimit = hasExpansion and 200 or 100

	if fishCount >= inventoryLimit then
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
