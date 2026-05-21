local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ROD_PURCHASE_WEBHOOK = "https://discord.com/api/webhooks/1505558036843069541/vKgtfZIbv0BXYdx9m1kg3t9xSo3jfCBuVAdMKIcYg-pFEtUdz93M4WbwCCO8XH5FhLML"

local function sendRodPurchaseWebhook(playerName, rodName, price)
	local data = {
		username = "Shop Logger",
		embeds = {{
			title = "Rod Purchased",
			description = string.format("**%s** bought **%s**%s",
				playerName,
				rodName,
				price > 0 and string.format(" for **%d coins**", price) or " (Robux/Free)"
			),
			color = 3447003,
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
		}}
	}
	pcall(function()
		HttpService:PostAsync(ROD_PURCHASE_WEBHOOK, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson)
	end)
end

-- RodProgression funnel: each rod = one milestone step
local ROD_FUNNEL_STEP = {
	["FishingRod"]  = 1,
	["SliverRod"]   = 2,
	["GoldRod"]     = 3,
	["CrystalRod"]  = 4,
	["MagneticRod"] = 5,
	["BoneRod"]     = 6,
	["CloverRod"]   = 7,
	["RainbowRod"]  = 8,
	["UnknownRod"]  = 9,
	["RobuxRod"]    = 10,
	["ElectricRod"] = 11,
	["RealisticRod"]= 12,
	["ArcaneRod"]   = 13,
	["VoidRod"]     = 14,
}

local ServerScriptService = game:GetService("ServerScriptService")
local datamanager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))

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
	if type(itemname) ~= "string" then return end

	-- FriendRod: special rod not in RodData, handled separately
	if itemname == "FriendRod" then
		local ls = plr:FindFirstChild("leaderstats")
		if not ls then return end
		local rodsFolder2 = ls:FindFirstChild("Rods")
		local friendBool = rodsFolder2 and rodsFolder2:FindFirstChild("FriendRod")
		if not (friendBool and friendBool.Value) then return end
		for _, container in ipairs({ plr:FindFirstChild("Backpack"), plr:FindFirstChild("StarterGear"), plr.Character }) do
			if container then
				for _, tool in ipairs(container:GetChildren()) do
					if tool:IsA("Tool") and (RodData.Rods[tool.Name] or tool.Name == "FriendRod") then
						tool:Destroy()
					end
				end
			end
		end
		local currentRod2 = ls:FindFirstChild("CurrentRod")
		if currentRod2 then currentRod2.Value = "FriendRod" end
		local storageItem = ServerStorage:FindFirstChild("FriendRod")
		local backpack = plr:FindFirstChild("Backpack")
		if storageItem and backpack then storageItem:Clone().Parent = backpack end
		if currentRod2 then datamanager:UpdateData(plr, "CurrentRod", currentRod2.Value) end
		return
	end

	local item = RodData.Rods[itemname]
	if not item then
		warn("Unauthorized item purchase attempt: " .. tostring(itemname))
		return
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
			pcall(function()
				local funnelStep = ROD_FUNNEL_STEP["RobuxRod"]
				if funnelStep then
					AnalyticsService:LogFunnelStepEvent(plr, "RodProgression", nil, funnelStep, "RobuxRod")
				end
			end)
		end
	else
		-- Normal rod processing (including void rod)
		if not alreadyOwned then
			if coins.Value < item.price then
				warn("Insufficient balance for", plr.Name, "on", itemname)
				return
			end
			coins.Value -= item.price
			datamanager:UpdateData(plr, "Coins", coins.Value)
			if rodBool then
				rodBool.Value = true
			end
			pcall(function()
				AnalyticsService:LogEconomyEvent(plr, Enum.AnalyticsEconomyFlowType.Sink, "Coins",
					item.price, coins.Value, "ShopPurchase", itemname)
			end)
			local funnelStep = ROD_FUNNEL_STEP[itemname]
			if funnelStep then
				pcall(function()
					AnalyticsService:LogFunnelStepEvent(plr, "RodProgression", nil, funnelStep, itemname)
				end)
			end

		end
	end

	-- Deactivate default rod (only on new purchase)
	if not alreadyOwned then
		local defaultRod = rodsFolder:FindFirstChild("FishingRod")
		if defaultRod then
			defaultRod.Value = false
		end
		local displayName = item.displayName or itemname
		local price = item.price or 0
		task.spawn(sendRodPurchaseWebhook, plr.Name, displayName, price)
	end

	-- storageName 기준 rod 이름 set (FriendRod 포함)
	local rodStorageNames = { ["FishingRod"] = true, ["FriendRod"] = true }
	for _, data in pairs(RodData.Rods) do
		if data.storageName then
			rodStorageNames[data.storageName] = true
		end
	end

	-- Remove existing equipped rods
	local function removeExistingRods(plr)
		for _, container in ipairs({ plr:FindFirstChild("Backpack"), plr:FindFirstChild("StarterGear"), plr.Character }) do
			if container then
				for _, tool in ipairs(container:GetChildren()) do
					if tool:IsA("Tool") and (RodData.Rods[tool.Name] or rodStorageNames[tool.Name]) then
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

	-- profile.Data 즉시 반영
	datamanager:UpdateData(plr, "CurrentRod", currentRod.Value)
	local rodsData = {}
	if rodsFolder then
		for _, rod in ipairs(rodsFolder:GetChildren()) do
			if rod:IsA("BoolValue") then rodsData[rod.Name] = rod.Value end
		end
	end
	datamanager:UpdateData(plr, "Rods", rodsData)

	if itemname == "GoldRod" then
		setFavoriteRemote:FireClient(plr)
	end
end)
