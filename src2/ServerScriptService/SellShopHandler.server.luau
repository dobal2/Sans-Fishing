-- Handles Sell Shop ProximityPrompt and sell choice logic.
-- Moved from workspace.Sell Shop.Seller.ProximityPrompt.Script

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local ServerScriptService = game:GetService("ServerScriptService")

local SkillServer = require(script.Parent.SkillHelper)
local datamanager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))
local FishDataModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDataModule"))
local EventState = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EventStateModule"))

-- BindableFunction from ItemSave for selling fish from data table
local SellFishBindable = ServerScriptService:WaitForChild("SellFishBindable")

local DOUBLE_SELL_GAMEPASS_ID = 1293430515
local GROUP_ID = 9744474
local SELL_COOLDOWN = 1.0

local sellCooldowns = {}
local doubleGamepassCache = {}

local soldNotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SoldNotification")
local sellGuiEvent          = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SellGuiEvent")
local sellChoiceEvent       = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SellChoiceEvent")
local greetEvent            = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("TalkEvent")
local enablePromptEvent     = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SetPromptEvent")

local MIN_WEIGHT = 1.0
local MAX_WEIGHT = 200

local VARIANT_PREFIXES_STRIP = { "Gold", "Sans", "Frozen", "Festival" }

local function stripAllFishPrefixes(name)
	local changed = true
	while changed do
		changed = false
		for _, prefix in ipairs(VARIANT_PREFIXES_STRIP) do
			local pattern = "^" .. prefix .. " "
			if name:find(pattern) then
				name = name:gsub(pattern, "", 1)
				changed = true
				break
			end
		end
	end
	return name
end

-- Recalculate fish value server-side from the tool name (used for Option3 preview)
local function calcTrueFishValue(tool)
	local nameStr = tool.Name
	local _, _, fishPart, weight = nameStr:find("(.+) %[.+%] %- (%.?%d+%.?%d*)kg")
	if not fishPart or not weight then return 0 end
	weight = tonumber(weight)
	if not weight then return 0 end

	local baseFishName = stripAllFishPrefixes(fishPart)
	local fishData = FishDataModule.GetFishByName(baseFishName)
	if not fishData then return 0 end

	-- Detect variants from prefix portion
	local prefixPart = fishPart:sub(1, #fishPart - #baseFishName)
	local hasFrozen   = prefixPart:find("Frozen")   ~= nil
	local hasFestival = prefixPart:find("Festival")  ~= nil
	local hasSans     = prefixPart:find("Sans")      ~= nil
	-- Gold variant: only if base fish name doesn't itself start with "Gold"
	local hasGold     = prefixPart:find("Gold") ~= nil and fishData.fishName:sub(1,4):lower() ~= "gold"

	local minW, maxW = fishData.minWeight or 1, fishData.maxWeight or 1
	local valueRatio = (minW == maxW) and 0 or math.clamp((weight - minW) / (maxW - minW), 0, 1)
	local adjusted = math.floor(fishData.value * (1.2 + math.pow(valueRatio, 0.8) * 7.0))

	if hasFrozen   then adjusted = math.floor(adjusted * 2.0) end
	if hasFestival then adjusted = math.floor(adjusted * 1.5) end
	if hasSans     then adjusted = math.floor(adjusted * 3.0) end
	if hasGold     then adjusted = math.floor(adjusted * 2.0) end

	return adjusted
end

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

local function isSoulFish(tool)
	local fishRarity = tool and tool:FindFirstChild("FishRarity")
	return fishRarity and fishRarity:IsA("StringValue") and fishRarity.Value == "Soul"
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
		additionalBonus += baseValue * 0.50
	end

	local friendsCount = getFriendsOnlineCount(player)
	if friendsCount > 0 then
		additionalBonus += baseValue * (friendsCount * 0.05)
	end

	additionalBonus += baseValue * SkillServer.GetSellBonus(player)

	local finalValue
	if hasDoubleGamepass then
		finalValue = baseValue * 2 + additionalBonus
	else
		finalValue = baseValue + additionalBonus
	end

	return math.floor(finalValue * EventState.CoinMultiplier)
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
	doubleGamepassCache[player.UserId] = nil
end)

sellChoiceEvent.OnServerEvent:Connect(function(player, choice)
	local now = tick()
	if sellCooldowns[player] and now - sellCooldowns[player] < SELL_COOLDOWN then return end
	sellCooldowns[player] = now

	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if not character or not coins or not backpack then return end

	local totalEarned = 0
	local itemSold = false
	local hasDoubleGamepass = false

	if doubleGamepassCache[player.UserId] ~= nil then
		hasDoubleGamepass = doubleGamepassCache[player.UserId]
	else
		pcall(function()
			hasDoubleGamepass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, DOUBLE_SELL_GAMEPASS_ID)
			doubleGamepassCache[player.UserId] = hasDoubleGamepass
		end)
	end

	if choice == "Option1" then
		-- Sell all unlocked fish from data table
		local baseValue, soldCount, soulCount, totalCount = SellFishBindable:Invoke(player, "all")
		if soldCount > 0 then
			totalEarned = calculateFinalValue(baseValue, player, hasDoubleGamepass)
			coins.Value += totalEarned
			datamanager:UpdateData(player, "Coins", coins.Value)
			soldNotificationEvent:FireClient(player, totalEarned)
			pcall(function()
				AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, "Coins",
					totalEarned, coins.Value, "FishSell", "SellAll")
			end)
		elseif totalCount <= 0 then
			soldNotificationEvent:FireClient(player, 0, true, "no_fish")
		elseif soulCount == totalCount then
			soldNotificationEvent:FireClient(player, 0, true, "soul_only")
		else
			soldNotificationEvent:FireClient(player, 0, true, "no_sellable_fish")
		end
		enablePromptEvent:FireClient(player, true)

	elseif choice == "Option2" or choice == "Option2Confirmed" then
		-- Sell currently equipped fish only
		local equippedTool = nil
		for _, tool in ipairs(character:GetChildren()) do
			if isPreviewableFish(tool) then
				equippedTool = tool
				break
			end
		end
		if choice ~= "Option2Confirmed" and isSoulFish(equippedTool) then
			soldNotificationEvent:FireClient(player, -2, true)
			enablePromptEvent:FireClient(player, true)
			return
		end

		local sellMode = (choice == "Option2Confirmed") and "equipped_soul_confirmed" or "equipped"
		local baseValue, soldCount = SellFishBindable:Invoke(player, sellMode)
		if soldCount > 0 then
			totalEarned = calculateFinalValue(baseValue, player, hasDoubleGamepass)
			coins.Value += totalEarned
			datamanager:UpdateData(player, "Coins", coins.Value)
			soldNotificationEvent:FireClient(player, totalEarned)
			pcall(function()
				AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, "Coins",
					totalEarned, coins.Value, "FishSell", "SellHeld")
			end)
		else
			soldNotificationEvent:FireClient(player, 0, true)
		end
		enablePromptEvent:FireClient(player, true)

	elseif choice == "Option3" then
		-- Preview value of currently equipped fish
		for _, tool in ipairs(character:GetChildren()) do
			if isPreviewableFish(tool) then
				local previewValue = calculateFinalValue(calcTrueFishValue(tool), player, hasDoubleGamepass)
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
