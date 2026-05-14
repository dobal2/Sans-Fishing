-- Handles Sell Shop ProximityPrompt and sell choice logic.
-- Moved from workspace.Sell Shop.Seller.ProximityPrompt.Script

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")

local DOUBLE_SELL_GAMEPASS_ID = 1293430515
local GROUP_ID = 9744474
local SELL_COOLDOWN = 1.0

local sellCooldowns = {}

local soldNotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SoldNotification")
local sellGuiEvent          = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SellGuiEvent")
local sellChoiceEvent       = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SellChoiceEvent")
local greetEvent            = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("TalkEvent")
local enablePromptEvent     = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SetPromptEvent")

local function isFishLocked(tool)
	local fishLock = tool:FindFirstChild("FishLock")
	return fishLock and fishLock:IsA("BoolValue") and fishLock.Value == true
end

local function isSellableFish(tool)
	local fishValue = tool:FindFirstChild("FishValue")
	return tool:IsA("Tool") and fishValue and fishValue.Value > 0 and not isFishLocked(tool)
end

local function isPreviewableFish(tool)
	local fishValue = tool:FindFirstChild("FishValue")
	return tool:IsA("Tool") and fishValue and fishValue.Value > 0
end

local function getFriendsOnlineCount(player)
	local count = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWith(other.UserId)
			end)
			if ok and isFriend then
				count += 1
			end
		end
	end
	return count
end

local function calculateFinalValue(baseValue, player, hasDoubleGamepass)
	local additionalBonus = 0

	if player:IsInGroup(GROUP_ID) then
		additionalBonus += baseValue * 0.15
	end

	local friendsCount = getFriendsOnlineCount(player)
	if friendsCount > 0 then
		additionalBonus += baseValue * (friendsCount * 0.05)
	end

	local finalValue
	if hasDoubleGamepass then
		finalValue = baseValue * 2 + additionalBonus
	else
		finalValue = baseValue + additionalBonus
	end

	return math.floor(finalValue)
end

-- Wire ProximityPrompt
local function wireSellShop()
	local shop = workspace:WaitForChild("Sell Shop", 30)
	if not shop then return end
	local seller = shop:WaitForChild("Seller", 10)
	if not seller then return end
	local prompt = seller:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		for _, d in ipairs(seller:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				prompt = d
				break
			end
		end
	end
	-- Dialog is handled client-side via NpcDialogClient; no Triggered needed here
end

task.spawn(wireSellShop)

Players.PlayerRemoving:Connect(function(player)
	sellCooldowns[player] = nil
end)

sellChoiceEvent.OnServerEvent:Connect(function(player, choice)
	local now = tick()
	if sellCooldowns[player] and now - sellCooldowns[player] < SELL_COOLDOWN then return end
	sellCooldowns[player] = now

	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if not character or not coins then return end

	local totalEarned = 0
	local itemSold = false
	local hasDoubleGamepass = false

	pcall(function()
		hasDoubleGamepass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, DOUBLE_SELL_GAMEPASS_ID)
	end)

	if choice == "Option1" then
		local tools = {}
		local lockedCount = 0
		local zeroValueCount = 0

		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") and tool:FindFirstChild("FishValue") then
				if isFishLocked(tool) then
					lockedCount += 1
				elseif tool.FishValue.Value <= 0 then
					zeroValueCount += 1
				else
					totalEarned += tool.FishValue.Value
					table.insert(tools, tool)
					itemSold = true
				end
			end
		end

		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:FindFirstChild("FishValue") then
				if isFishLocked(tool) then
					lockedCount += 1
				elseif tool.FishValue.Value <= 0 then
					zeroValueCount += 1
				else
					totalEarned += tool.FishValue.Value
					table.insert(tools, tool)
					itemSold = true
				end
			end
		end

		for _, tool in ipairs(tools) do
			tool:Destroy()
		end

		if itemSold then
			totalEarned = calculateFinalValue(totalEarned, player, hasDoubleGamepass)
			coins.Value += totalEarned
			soldNotificationEvent:FireClient(player, totalEarned)
			pcall(function()
				AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, "Coins",
					totalEarned, coins.Value, "FishSell", "SellAll", nil)
			end)
		else
			soldNotificationEvent:FireClient(player, 0, true)
		end
		enablePromptEvent:FireClient(player, true)

	elseif choice == "Option2" then
		local toolSold = false
		for _, tool in ipairs(character:GetChildren()) do
			if isSellableFish(tool) then
				totalEarned += tool.FishValue.Value
				tool:Destroy()
				itemSold = true
				toolSold = true
				break
			end
		end

		if not toolSold then
			soldNotificationEvent:FireClient(player, 0, true)
		elseif totalEarned > 0 then
			totalEarned = calculateFinalValue(totalEarned, player, hasDoubleGamepass)
			coins.Value += totalEarned
			soldNotificationEvent:FireClient(player, totalEarned)
			pcall(function()
				AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, "Coins",
					totalEarned, coins.Value, "FishSell", "SellHeld", nil)
			end)
		end
		enablePromptEvent:FireClient(player, true)

	elseif choice == "Option3" then
		for _, tool in ipairs(character:GetChildren()) do
			if isPreviewableFish(tool) then
				local previewValue = calculateFinalValue(tool.FishValue.Value, player, hasDoubleGamepass)
				soldNotificationEvent:FireClient(player, previewValue, true)
				enablePromptEvent:FireClient(player, true)
				return
			end
		end
		soldNotificationEvent:FireClient(player, 0, true)
		enablePromptEvent:FireClient(player, true)

	elseif choice == "Option4" then
		soldNotificationEvent:FireClient(player, -1, true)
		enablePromptEvent:FireClient(player, true)
	end
end)
