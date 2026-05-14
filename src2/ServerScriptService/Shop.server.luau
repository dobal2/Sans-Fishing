local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local AnalyticsService = game:GetService("AnalyticsService")

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("BuyFishingRod")
local RodData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RodDataModule"))
local setFavoriteRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("SetFavoriteRemote")

-- Robux rod gamepass ID
local ROBUX_ROD_GAMEPASS_ID = 1410895892

-- Check if void quest is completed
local function hasCompletedVoidQuest(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return false end

	local quests = leaderstats:FindFirstChild("Quests")
	if not quests then return false end

	local completedQuests = quests:FindFirstChild("CompletedQuests")
	if not completedQuests then return false end

	local voidQuestCompleted = completedQuests:FindFirstChild("void_unknown_challenge")
	return voidQuestCompleted and voidQuestCompleted.Value == true
end

remote.OnServerEvent:Connect(function(plr, itemname)
	local item = RodData.Rods[itemname]
	if not item then
		warn("Unauthorized item purchase attempt: " .. tostring(itemname))
		return
	end

	-- Void rod quest check
	if itemname == "VoidRod" then
		if not hasCompletedVoidQuest(plr) then
			warn("VoidRod purchase attempted without completing void quest: " .. plr.Name)
			plr:Kick("Unauthorized access attempt")
			return
		end
	end

	local leaderstats = plr:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("No leaderstats")
		return
	end

	local coins = leaderstats:FindFirstChild("Coins")
	local currentRod = leaderstats:FindFirstChild("CurrentRod")
	local rodsFolder = leaderstats:FindFirstChild("Rods")

	if not (coins and currentRod and rodsFolder) then
		warn("Missing required leaderstats elements")
		return
	end

	local rodBool = rodsFolder:FindFirstChild(item.storageName)
	local alreadyOwned = rodBool and rodBool.Value

	-- Robux rod processing
	if itemname == "RobuxRod" then
		local hasGamepass = false
		local success, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, ROBUX_ROD_GAMEPASS_ID)
		end)

		if success then
			hasGamepass = result
		end

		if not hasGamepass then
			warn("RobuxRod requested without owning gamepass: " .. plr.Name)
			return
		end

		-- Grant ownership only after validation
		if not alreadyOwned and rodBool then
			rodBool.Value = true
		end
	else
		-- Normal rod processing (including void rod)
		if not alreadyOwned then
			if coins.Value < item.price then
				warn("Insufficient balance for", plr.Name, "on", itemname)
				return
			end
			coins.Value -= item.price
			if rodBool then
				rodBool.Value = true
			end
			pcall(function()
				AnalyticsService:LogEconomyEvent(plr, Enum.AnalyticsEconomyFlowType.Sink, "Coins",
					item.price, coins.Value, "ShopPurchase", "Rod", itemname)
			end)

		end
	end

	-- Deactivate default rod (only on new purchase)
	if not alreadyOwned then
		local defaultRod = rodsFolder:FindFirstChild("FishingRod")
		if defaultRod then
			defaultRod.Value = false
		end
	end

	-- Remove existing equipped rods
	local function removeExistingRods(plr)
		for _, container in ipairs({ plr:FindFirstChild("Backpack"), plr:FindFirstChild("StarterGear"), plr.Character }) do
			if container then
				for _, tool in ipairs(container:GetChildren()) do
					if tool:IsA("Tool") and (RodData.Rods[tool.Name] or tool.Name == "FishingRod") then
						tool:Destroy()
					end
				end
			end
		end
	end

	removeExistingRods(plr)

	-- Equip rod
	currentRod.Value = item.storageName
	local storageItem = ServerStorage:FindFirstChild(item.storageName)
	local backpack = plr:FindFirstChild("Backpack")
	if storageItem and backpack then
		storageItem:Clone().Parent = backpack
	elseif not storageItem then
		warn("Item '" .. item.storageName .. "' not found in ServerStorage.")
	end

	if itemname == "GoldRod" then
		setFavoriteRemote:FireClient(plr)
	end
end)
