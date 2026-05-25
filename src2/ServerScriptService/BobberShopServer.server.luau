local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BobberData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BobberDataModule"))
local DataManager = require(script.Parent.leaderstats.DataManager)

local SHOP_DS_KEY = "BobberShopData_v1"
local RESTOCK_INTERVAL = 600
local SLOT_COUNT = 3
local MESSAGING_TOPIC = "BobberShopSync"
local ROBUX_BOBBER_GAMEPASS_ID = 1853589181

local shopStore = DataStoreService:GetDataStore("BobberShopMeta")

local currentSlots = {}
local nextRestockTime = 0
local placedParts = {}

local function formatCoins(n)
	local s = tostring(math.floor(n))
	local result = ""
	local len = #s
	for i = 1, len do
		if i > 1 and (len - i + 1) % 3 == 0 then
			result = result .. ","
		end
		result = result .. s:sub(i, i)
	end
	return result
end

local function clearSlot(i)
	if placedParts[i] then
		placedParts[i]:Destroy()
		placedParts[i] = nil
	end
end

local equipBobberRemote = Instance.new("RemoteEvent")
equipBobberRemote.Name = "EquipBobberRemote"
equipBobberRemote.Parent = ReplicatedStorage

local buyBobberRemote = Instance.new("RemoteEvent")
buyBobberRemote.Name = "BuyBobberRemote"
buyBobberRemote.Parent = ReplicatedStorage

local openBobberShopRemote = Instance.new("RemoteEvent")
openBobberShopRemote.Name = "OpenBobberShopRemote"
openBobberShopRemote.Parent = ReplicatedStorage

local noticeRemote = nil
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	noticeRemote = remotes:WaitForChild("Notice"):WaitForChild("ShowNoticeEvent")
end)

local function grantRobuxBobber(player)
	local data = DataManager:GetData(player)
	if not data then return end

	local owned = data.OwnedBobbers or {}
	for _, n in ipairs(owned) do
		if n == "Robux Bobber" then return end
	end

	local newOwned = {}
	for _, n in ipairs(owned) do table.insert(newOwned, n) end
	table.insert(newOwned, "Robux Bobber")
	DataManager:UpdateData(player, "OwnedBobbers", newOwned)

	local ls = player:FindFirstChild("leaderstats")
	local ownedFolder = ls and ls:FindFirstChild("OwnedBobbers")
	if ownedFolder then
		local bv = ownedFolder:FindFirstChild("Robux Bobber")
		if bv then bv.Value = true end
	end

	if noticeRemote then
		noticeRemote:FireClient(player, "Robux Bobber unlocked!")
	end
end

equipBobberRemote.OnServerEvent:Connect(function(player, bobberName)
	if type(bobberName) ~= "string" then return end
	local data = DataManager:GetData(player)
	if not data then return end

	local owned = data.OwnedBobbers or {"Basic Bobber"}
	local hasIt = false
	for _, n in ipairs(owned) do
		if n == bobberName then hasIt = true; break end
	end
	if not hasIt and bobberName == "Robux Bobber" then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, ROBUX_BOBBER_GAMEPASS_ID)
		end)
		if ok and owns then
			hasIt = true
			task.spawn(grantRobuxBobber, player)
		end
	end
	if not hasIt then return end

	DataManager:UpdateData(player, "EquippedBobber", bobberName)

	local ls = player:FindFirstChild("leaderstats")
	local ev = ls and ls:FindFirstChild("EquippedBobber")
	if ev then ev.Value = bobberName end
end)

buyBobberRemote.OnServerEvent:Connect(function(player, _, slotIndex)
	if type(slotIndex) ~= "number" then return end
	slotIndex = math.clamp(math.floor(slotIndex), 1, SLOT_COUNT)

	local slot = currentSlots[slotIndex]
	if not slot then return end
	if not slot.available then return end

	local bobberName = slot.bobberName

	local data = DataManager:GetData(player)
	if not data then return end

	local owned = data.OwnedBobbers or {}
	for _, n in ipairs(owned) do
		if n == bobberName then return end
	end

	local price = (BobberData.Bobbers[bobberName] or {}).price or 0
	if (data.Coins or 0) < price then return end

	local bought = false
	if game:GetService("RunService"):IsStudio() then
		local s = currentSlots[slotIndex]
		if s and s.available then bought = true end
	else
		pcall(function()
			shopStore:UpdateAsync(SHOP_DS_KEY, function(stored)
				if not stored then return nil end
				local s = stored.slots[slotIndex]
				if not s or not s.available then return nil end
				stored.slots[slotIndex].available = false
				bought = true
				return stored
			end)
		end)
	end
	if not bought then return end

	DataManager:UpdateData(player, "Coins", data.Coins - price)

	local newOwned = {}
	for _, n in ipairs(owned) do table.insert(newOwned, n) end
	table.insert(newOwned, bobberName)
	DataManager:UpdateData(player, "OwnedBobbers", newOwned)

	-- Mark sold locally but keep the part visible
	currentSlots[slotIndex].available = false

	local ls = player:FindFirstChild("leaderstats")
	local ownedFolder = ls and ls:FindFirstChild("OwnedBobbers")
	if ownedFolder then
		local bv = ownedFolder:FindFirstChild(bobberName)
		if bv then bv.Value = true end
	end

	openBobberShopRemote:FireClient(player, bobberName, slotIndex, true)

	if noticeRemote then
		noticeRemote:FireClient(player, "Purchased: " .. bobberName .. "!")
	end

	pcall(function()
		MessagingService:PublishAsync(MESSAGING_TOPIC, { type = "slotBought", slotIndex = slotIndex })
	end)
end)

local shop = workspace:WaitForChild("BobberShop")
local gui = shop:WaitForChild("gui")
local nameLabel = gui:WaitForChild("name")
local bobberModels = ReplicatedStorage:WaitForChild("Bobbers")

local slotParts = {
	shop:WaitForChild("BobberPos1"),
	shop:WaitForChild("BobberPos2"),
	shop:WaitForChild("BobberPos3"),
}

local function placeSlot(i, bobberName)
	clearSlot(i)

	local template = bobberModels:FindFirstChild(bobberName)
	if not template then return end

	local part = template:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Position = slotParts[i].Position
	part.Parent = workspace

	local price = (BobberData.Bobbers[bobberName] or {}).price or 0

	local pp = Instance.new("ProximityPrompt")
	pp.ObjectText = formatCoins(price) .. " Coins"
	pp.ActionText = "View"
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 10
	pp:SetAttribute("IsBobberShop", true)
	pp:SetAttribute("BobberName", bobberName)
	pp:SetAttribute("SlotIndex", i)
	pp.Parent = part

	-- Always open popup; client handles "Already Owned" display
	pp.Triggered:Connect(function(player)
		openBobberShopRemote:FireClient(player, bobberName, i)
	end)

	placedParts[i] = part
end

local function placeRobuxBobberSlot()
	local pos4 = shop:FindFirstChild("BobberPos4")
	if not pos4 then return end

	local template = bobberModels:FindFirstChild("Robux Bobber")
	if not template then return end

	local part = template:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Position = pos4.Position
	part.Parent = workspace

	local pp = Instance.new("ProximityPrompt")
	pp.ObjectText = "Robux"
	pp.ActionText = "View"
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 10
	pp.Parent = part

	pp.Triggered:Connect(function(player)
		openBobberShopRemote:FireClient(player, "Robux Bobber", 0)
	end)
end

local function applyState(slots, restockTime)
	currentSlots = slots
	nextRestockTime = restockTime
	for i = 1, SLOT_COUNT do
		local slot = slots[i]
		if slot then
			placeSlot(i, slot.bobberName)
		else
			clearSlot(i)
		end
	end
end

local function pickRandomBobbers()
	local slots = {}
	local picked = {}

	for i = 1, SLOT_COUNT do
		local totalWeight = 0
		for _, entry in ipairs(BobberData.ShopList) do
			if not picked[entry.name] then
				totalWeight = totalWeight + entry.weight
			end
		end

		local roll = math.random() * totalWeight
		local chosen = BobberData.ShopList[1].name
		local cumulative = 0
		for _, entry in ipairs(BobberData.ShopList) do
			if not picked[entry.name] then
				cumulative = cumulative + entry.weight
				if roll <= cumulative then
					chosen = entry.name
					break
				end
			end
		end

		picked[chosen] = true
		slots[i] = { bobberName = chosen, available = true }
	end

	return slots
end

local function doRestock(force)
	local newSlots = pickRandomBobbers()
	local now = os.time()

	if game:GetService("RunService"):IsStudio() then
		applyState(newSlots, now + RESTOCK_INTERVAL)
		return
	end
	local written = false

	pcall(function()
		shopStore:UpdateAsync(SHOP_DS_KEY, function(stored)
			if not force and stored and (now - (stored.lastRestock or 0)) < RESTOCK_INTERVAL - 5 then
				return nil
			end
			written = true
			return { slots = newSlots, lastRestock = now }
		end)
	end)

	if written then
		applyState(newSlots, now + RESTOCK_INTERVAL)
		pcall(function()
			MessagingService:PublishAsync(MESSAGING_TOPIC, { type = "restock" })
		end)
	else
		local stored
		pcall(function() stored = shopStore:GetAsync(SHOP_DS_KEY) end)
		if stored then
			applyState(stored.slots, (stored.lastRestock or 0) + RESTOCK_INTERVAL)
		end
	end
end

local function loadFromDataStore()
	local stored
	pcall(function() stored = shopStore:GetAsync(SHOP_DS_KEY) end)

	if not stored then
		doRestock()
		return
	end

	local elapsed = os.time() - (stored.lastRestock or 0)
	if elapsed >= RESTOCK_INTERVAL then
		doRestock()
	else
		applyState(stored.slots, stored.lastRestock + RESTOCK_INTERVAL)
	end
end

pcall(function()
	MessagingService:SubscribeAsync(MESSAGING_TOPIC, function(msg)
		local data = msg.Data
		if data and data.type == "slotBought" then
			local idx = data.slotIndex
			if currentSlots[idx] then
				currentSlots[idx].available = false
			end
			return
		end
		task.wait(1)
		local stored
		pcall(function() stored = shopStore:GetAsync(SHOP_DS_KEY) end)
		if stored then
			local elapsed = os.time() - (stored.lastRestock or 0)
			if elapsed >= RESTOCK_INTERVAL then
				doRestock()
			else
				applyState(stored.slots, stored.lastRestock + RESTOCK_INTERVAL)
			end
		end
	end)
end)

task.spawn(function()
	while true do
		local remaining = math.max(0, nextRestockTime - os.time())
		local m = math.floor(remaining / 60)
		local s = remaining % 60
		nameLabel.Text = string.format("Restock in %d:%02d", m, s)

		if remaining <= 0 and nextRestockTime > 0 then
			doRestock()
		end

		task.wait(1)
	end
end)

loadFromDataStore()
placeRobuxBobberSlot()

local restockBE = Instance.new("BindableEvent")
restockBE.Name = "BobberShopRestockBE"
restockBE.Parent = ServerScriptService
restockBE.Event:Connect(function()
	doRestock(true)
end)

Players.PlayerAdded:Connect(function(player)
	player:WaitForChild("DataReady", 30)
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, ROBUX_BOBBER_GAMEPASS_ID)
	end)
	if ok and owns then
		grantRobuxBobber(player)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if gamePassId == ROBUX_BOBBER_GAMEPASS_ID and wasPurchased then
		grantRobuxBobber(player)
	end
end)
