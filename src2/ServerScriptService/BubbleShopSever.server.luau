local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- Bubble data (prices in coins)
local BUBBLE_DATA = {
	["Strength Bubble"] = 50000,
	["SizeBuff Bubble"] = 75000,
	["Luck Bubble"] = 100000
}

-- Inventory expansion gamepass ID
local INVENTORY_EXPANSION_GAMEPASS_ID = 1294285302

local buyBubbleBindable = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("BuyBubbleBindable")
local showNoticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("ShowNoticeEvent")

-- Check if item is a rod or trap
local function IsRod(itemName)
	itemName = itemName:lower()
	return itemName:match("rod$") ~= nil or itemName:match("trap$") ~= nil
end

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

-- Get inventory limit
local function getInventoryLimit(player)
	local baseLimit = 100
	local expandedLimit = 200

	if hasInventoryExpansionGamepass(player) then
		return expandedLimit
	else
		return baseLimit
	end
end

-- Check inventory space
local function checkInventorySpace(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return true end

	local itemCount = 0

	-- Count all tools excluding rods/traps
	for _, item in pairs(backpack:GetChildren()) do
		if item:IsA("Tool") and not IsRod(item.Name) then
			itemCount = itemCount + 1
		end
	end

	local inventoryLimit = getInventoryLimit(player)

	return itemCount < inventoryLimit
end

buyBubbleBindable.Event:Connect(function(plr, bubbleName)
	-- Check inventory space
	if not checkInventorySpace(plr) then
		local hasExpansion = hasInventoryExpansionGamepass(plr)
		local message = hasExpansion and
			"Expanded inventory full! Go sell fish (Max 200)" or
			"Inventory full! Go sell fish or buy expansion pass (Max 100)"

		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, message)
		end
		return
	end

	-- Check bubble price
	local bubblePrice = BUBBLE_DATA[bubbleName]
	if not bubblePrice then
		warn("Unknown Bubble:", bubbleName)
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Unknown Bubble!")
		end
		return
	end

	local leaderstats = plr:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("No leaderstats:", plr.Name)
		return
	end

	local coins = leaderstats:FindFirstChild("Coins")
	if not coins then
		warn("No Coins value:", plr.Name)
		return
	end

	-- Insufficient coins
	if coins.Value < bubblePrice then
		local message = string.format("Not enough coins! Need %s coins", bubblePrice)
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, message)
		end
		return
	end

	-- Find bubble tool in ServerStorage BubbleTools folder
	local bubbleToolsFolder = ServerStorage:FindFirstChild("BubbleTools")
	if not bubbleToolsFolder then
		warn("BubbleTools folder not found in ServerStorage")
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Bubble tools not found!")
		end
		return
	end

	local bubbleTool = bubbleToolsFolder:FindFirstChild(bubbleName)
	if not bubbleTool then
		warn("Bubble tool not found in BubbleTools folder:", bubbleName)
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Bubble tool not found!")
		end
		return
	end

	-- Re-check before purchase (prevent concurrent purchases)
	if not checkInventorySpace(plr) then
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Inventory became full!")
		end
		return
	end

	-- Process purchase
	coins.Value = coins.Value - bubblePrice

	-- Add bubble tool to backpack
	local playerBackpack = plr:FindFirstChild("Backpack")
	if playerBackpack then
		local clonedBubble = bubbleTool:Clone()
		clonedBubble.Parent = playerBackpack
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Bubble purchased successfully!")
		end
	else
		warn("Player backpack not found:", plr.Name)
		-- Refund coins
		coins.Value = coins.Value + bubblePrice
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Purchase failed - no backpack!")
		end
	end
end)
