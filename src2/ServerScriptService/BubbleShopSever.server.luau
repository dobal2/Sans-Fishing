local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")

local datamanager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))

-- Bubble data (prices in coins)
local BUBBLE_DATA = {
	["Strength Bubble"] = 50000,
	["SizeBuff Bubble"] = 75000,
	["Luck Bubble"] = 100000
}

local buyBubbleBindable = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("BuyBubbleBindable")
local showNoticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("ShowNoticeEvent")

buyBubbleBindable.Event:Connect(function(plr, bubbleName)

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

	-- Process purchase
	coins.Value = coins.Value - bubblePrice
	datamanager:UpdateData(plr, "Coins", coins.Value)

	-- Add bubble tool to backpack
	local playerBackpack = plr:FindFirstChild("Backpack")
	if playerBackpack then
		local clonedBubble = bubbleTool:Clone()
		clonedBubble.Parent = playerBackpack
		-- Save to DataStore
		local Data = datamanager:GetData(plr)
		if Data then
			local bubbles = Data.Bubbles or {}
			table.insert(bubbles, bubbleName)
			datamanager:UpdateData(plr, "Bubbles", bubbles)
		end
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Bubble purchased successfully!")
		end
	else
		warn("Player backpack not found:", plr.Name)
		coins.Value = coins.Value + bubblePrice
		if showNoticeEvent then
			showNoticeEvent:FireClient(plr, "Purchase failed - no backpack!")
		end
	end
end)

-- Remove bubble from saved data when it's used/lost
local Players = game:GetService("Players")
Players.PlayerAdded:Connect(function(plr)
	local char = plr.Character or plr.CharacterAdded:Wait()
	local function trackBubbleLoss(child)
		if not child:IsA("Tool") then return end
		if not child.Name:lower():match("bubble$") then return end
		if child.Parent == plr.Character or child.Parent == plr.Backpack then return end
		-- bubble lost: remove one instance from saved data
		local Data = datamanager:GetData(plr)
		if not Data then return end
		local bubbles = Data.Bubbles or {}
		for i = #bubbles, 1, -1 do
			if bubbles[i] == child.Name then
				table.remove(bubbles, i)
				datamanager:UpdateData(plr, "Bubbles", bubbles)
				break
			end
		end
	end
	char.ChildRemoved:Connect(trackBubbleLoss)
	plr.Backpack.ChildRemoved:Connect(trackBubbleLoss)
	plr.CharacterAdded:Connect(function(newChar)
		newChar.ChildRemoved:Connect(trackBubbleLoss)
	end)
end)
