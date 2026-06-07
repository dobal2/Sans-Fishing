local TweenService       = game:GetService("TweenService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage      = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players            = game:GetService("Players")

local FishData              = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDataModule"))
local fishTrapDataManager   = require(ServerScriptService:WaitForChild("FishTrapManager"):WaitForChild("DataManager"))

local ShowNoticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("ShowNoticeEvent")
local FillFishTrapBindable = ServerScriptService:FindFirstChild("FillFishTrapBindable")
if not FillFishTrapBindable then
	FillFishTrapBindable = Instance.new("BindableEvent")
	FillFishTrapBindable.Name = "FillFishTrapBindable"
	FillFishTrapBindable.Parent = ServerScriptService
end

local FISH_TRAP_HARVEST_PRODUCT_ID = 3381869322

local FISHTRAP_CONFIGS = {
	BasicFishTrap    = { catchInterval = 600, maxCapacity = 20, displayName = "Basic Fish Trap"    },
	AdvancedFishTrap = { catchInterval = 480, maxCapacity = 30, displayName = "Advanced Fish Trap" },
	MasterFishTrap   = { catchInterval = 360, maxCapacity = 40, displayName = "Master Fish Trap"   },
	RobuxFishTrap    = { catchInterval = 300, maxCapacity = 60, displayName = "Robux Fish Trap"    },
}

local FishTrapCore = {}

local function isRodOrTrap(itemName)
	if not itemName then return false end
	local lower = itemName:lower()
	return lower:match("rod$") ~= nil or lower:match("trap") ~= nil
end

local function restoreEquippedFishTrapTool(player, trapName)
	local character = player.Character
	if not character then return end

	local tool = character:FindFirstChild(trapName)
	if not tool or not tool:IsA("Tool") then return end
	if not tool:GetAttribute("PlacedTransparent") then return end

	tool:SetAttribute("PlacedTransparent", nil)
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 0
			descendant.CanCollide = false
			descendant.CanTouch = true
			descendant.CanQuery = true
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 0
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Enabled = true
		end
	end
end

local function buildFishTool(fishesFolder, fishInfo)
	local template = fishesFolder:FindFirstChild(fishInfo.fishName)
	if not template then
		local lower = fishInfo.fishName:lower()
		for _, child in ipairs(fishesFolder:GetChildren()) do
			if child.Name:lower() == lower then template = child break end
		end
	end
	if not template then return nil end

	local tool = template:Clone()
	tool.Name = string.format("%s [%s] - %.1fkg", fishInfo.fishName, fishInfo.name, fishInfo.weight)

	local function ensureValue(class, name, val)
		local v = tool:FindFirstChild(name) or Instance.new(class)
		v.Name = name; v.Value = val; v.Parent = tool
	end
	ensureValue("IntValue",    "FishValue",  fishInfo.value  or 0)
	ensureValue("NumberValue", "FishWeight", fishInfo.weight or 1)
	ensureValue("StringValue", "FishRarity", fishInfo.name   or "Common")

	local handle = tool:FindFirstChild("Handle")
	if handle and fishInfo.weight then
		local minW = fishInfo.minWeight or 1
		local maxW = fishInfo.maxWeight or 100
		local ratio = math.clamp(1 + ((fishInfo.weight - minW) / math.max(maxW - minW, 1)) * 4, 1, 5)
		handle.Size = handle.Size * ratio
		handle.Massless = true
	end
	tool:SetAttribute("FromFishTrap", true)
	return tool
end

function FishTrapCore.init(fishTrap)
	local proximity    = fishTrap:WaitForChild("ProximityPrompt")
	local display      = fishTrap:WaitForChild("Display")
	local bar          = display:WaitForChild("FishCountBar")
	local fill         = bar:WaitForChild("Fill")
	local progressText = bar:WaitForChild("Progress")
	local nextBar      = display:WaitForChild("NextFishCatchBar")
	local nextFill     = nextBar:WaitForChild("Fill")
	local nextText     = nextBar:WaitForChild("Progress")
	local nameLabel    = display:WaitForChild("name")

	local storedFish    = {}
	local isRunning     = false
	local isHarvesting  = false
	local nextCatchTime = 0

	local ownerValue    = fishTrap:FindFirstChild("Owner")
	local trapIdValue   = fishTrap:FindFirstChild("TrapId")
	local trapTypeValue = fishTrap:FindFirstChild("TrapType")

	local owner    = ownerValue    and ownerValue.Value    or nil
	local trapId   = trapIdValue   and trapIdValue.Value   or nil
	local trapType = trapTypeValue and trapTypeValue.Value or "BasicFishTrap"

	local cfg            = FISHTRAP_CONFIGS[trapType] or FISHTRAP_CONFIGS.BasicFishTrap
	local CATCH_INTERVAL = cfg.catchInterval
	local MAX_CAPACITY   = cfg.maxCapacity
	local DISPLAY_NAME   = cfg.displayName

	if nameLabel then nameLabel.Text = DISPLAY_NAME end
	if owner then proximity.ObjectText = owner .. "'s Fish Trap" end

	local function updateUI()
		local pct = math.min(#storedFish / MAX_CAPACITY, 1)
		progressText.Text = #storedFish .. " / " .. MAX_CAPACITY
		TweenService:Create(fill, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(pct, 0, 1, 0) }):Play()
	end

	local function updateNextCatchUI()
		if #storedFish >= MAX_CAPACITY then
			nextText.Text = "FULL"
			nextFill.Size = UDim2.new(1, 0, 1, 0)
			nextFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
			return
		end
		local remaining = math.max(0, nextCatchTime - tick())
		local pct = math.max(0, 1 - remaining / CATCH_INTERVAL)
		nextText.Text = string.format("%d:%02d", math.floor(remaining/60), math.floor(remaining%60))
		nextFill.Size = UDim2.new(pct, 0, 1, 0)
	end

	local function saveTrapData()
		if not owner or not trapId then return end
		local player = Players:FindFirstChild(owner)
		if not player or not fishTrap.PrimaryPart then return end
		local pos = fishTrap.PrimaryPart.Position
		local rot = fishTrap.PrimaryPart.Rotation
		fishTrapDataManager:UpdateData(player, "FishTrapData_" .. trapId, {
			position      = { x = pos.X, y = pos.Y, z = pos.Z },
			rotation      = { x = rot.X, y = rot.Y, z = rot.Z },
			storedFish    = storedFish,
			nextCatchTime = nextCatchTime,
			lastSaveTime  = tick(),
			trapId        = trapId,
			trapType      = trapType,
			isActive      = true,
		})
	end

	local function loadTrapData()
		if not owner or not trapId then return end
		local player = Players:FindFirstChild(owner)
		if not player then return end
		local data = fishTrapDataManager:GetData(player)
		if not data then return end
		local td = data["FishTrapData_" .. trapId]
		if not td or td.isActive == false then return end
		if td.storedFish    then storedFish    = td.storedFish    end
		if td.nextCatchTime then nextCatchTime = td.nextCatchTime end


		-- 오프라인 물고기 계산은 DataManager:RestorePlayerFishTraps에서 처리됨
	end

	local function clearTrapData()
		if not owner or not trapId then return end
		local player = Players:FindFirstChild(owner)
		if player then fishTrapDataManager:UpdateData(player, "FishTrapData_" .. trapId, nil) end
	end

	local function sendRestoreSignal(playerName)
		local s = Instance.new("StringValue")
		s.Name   = "FishTrapRemoved"
		s.Value  = playerName
		s.Parent = ReplicatedStorage
		task.delay(3, function() if s.Parent then s:Destroy() end end)
	end

	local function deliverFishList(player, fishList)
		local fishCaughtBindable = ServerScriptService:FindFirstChild("FishCaughtBindable")
		if not fishCaughtBindable then
			warn("FishTrapCore: FishCaughtBindable not found")
			return 0
		end

		if not player:FindFirstChild("ItemReady") then
			player:WaitForChild("ItemReady", 10)
		end

		if not player:FindFirstChild("ItemReady") then
			warn("FishTrapCore: ItemReady not found for", player.Name)
			return 0
		end

		local given = 0
		for _, fishInfo in ipairs(fishList) do
			if fishInfo and fishInfo.fishName then
				fishCaughtBindable:Fire(player, fishInfo)
				given += 1
			end
		end
		return given
	end

	local function collectOwn(player)
		if isHarvesting then
			ShowNoticeEvent:FireClient(player, "Harvest already in progress!")
			return
		end
		isHarvesting = true

		if #storedFish == 0 then
			clearTrapData()
			sendRestoreSignal(owner)
			restoreEquippedFishTrapTool(player, trapType)
			isRunning = false
			if fishTrap.Parent then fishTrap:Destroy() end
			ShowNoticeEvent:FireClient(player, "Empty fish trap collected!")
			isHarvesting = false
			return
		end

		local fishToGive = {table.unpack(storedFish)}
		local given = deliverFishList(player, fishToGive)
		if given <= 0 then
			ShowNoticeEvent:FireClient(player, "Failed to collect fish trap. Try again.")
			isHarvesting = false
			return
		end

		for _ = 1, given do table.remove(storedFish, 1) end

		clearTrapData()
		sendRestoreSignal(owner)
		restoreEquippedFishTrapTool(player, trapType)
		isRunning = false
		if fishTrap.Parent then fishTrap:Destroy() end
		ShowNoticeEvent:FireClient(player, string.format("Fish Trap collected! Got %d fish.", given))
		isHarvesting = false
	end

	local function promptSteal(player)
		local purchaseStorage = ReplicatedStorage:FindFirstChild("FishTrapPurchases")
		if not purchaseStorage then
			purchaseStorage = Instance.new("Folder")
			purchaseStorage.Name = "FishTrapPurchases"
			purchaseStorage.Parent = ReplicatedStorage
		end
		for _, v in ipairs(purchaseStorage:GetChildren()) do
			if v:IsA("ObjectValue") and v.Value == player then v:Destroy() end
		end
		local pd = Instance.new("ObjectValue")
		pd.Name  = "Purchase_" .. player.Name .. "_" .. trapId
		pd.Value = player
		pd.Parent = purchaseStorage
		local tidVal = Instance.new("StringValue")
		tidVal.Name  = "TrapId"
		tidVal.Value = trapId
		tidVal.Parent = pd
		game:GetService("Debris"):AddItem(pd, 600)
		pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, FISH_TRAP_HARVEST_PRODUCT_ID)
	end

	local function onStealPurchased(thief)
		if #storedFish == 0 then
			ShowNoticeEvent:FireClient(thief, "The trap is empty now!")
			return
		end
		local toSteal = {table.unpack(storedFish)}
		local given = deliverFishList(thief, toSteal)
		if given <= 0 then
			ShowNoticeEvent:FireClient(thief, "Failed to steal fish trap. Try again.")
			return
		end

		storedFish = {}

		clearTrapData()
		sendRestoreSignal(owner)
		isRunning = false
		if fishTrap.Parent then fishTrap:Destroy() end

		ShowNoticeEvent:FireClient(thief,
			string.format("Stole %d fish from the trap!", given))
		if owner then
			local ownerPlayer = Players:FindFirstChild(owner)
			if ownerPlayer then
				restoreEquippedFishTrapTool(ownerPlayer, trapType)
				ShowNoticeEvent:FireClient(ownerPlayer,
					string.format("%s stole all %d fish from your trap!", thief.Name, given))
			end
		end
	end

	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "PurchaseComplete_" .. trapId and child:IsA("StringValue") then
			local thief = Players:FindFirstChild(child.Value)
			if thief then onStealPurchased(thief) end
		end
	end)

	proximity.Triggered:Connect(function(player)
		if owner and player.Name == owner then
			collectOwn(player)
			return
		end
		if #storedFish == 0 then
			ShowNoticeEvent:FireClient(player, "This fish trap is empty!")
			return
		end
		promptSteal(player)
	end)

	FillFishTrapBindable.Event:Connect(function(targetPlayer, targetTrapKey, fishList, updatedNextCatchTime)
		if not targetPlayer or targetPlayer.Name ~= owner then return end
		if targetTrapKey ~= "FishTrapData_" .. tostring(trapId) then return end

		storedFish = fishList or {}
		nextCatchTime = updatedNextCatchTime or nextCatchTime
		updateUI()
		updateNextCatchUI()
	end)

	local function catchFish()
		if #storedFish >= MAX_CAPACITY then return end
		local fishInfo = FishData.GetRandomFish(trapType, nil, true)
		if fishInfo then
			table.insert(storedFish, fishInfo)
			saveTrapData()
			updateUI()
		end
	end

	local function startLoop()
		if isRunning then return end
		isRunning = true
		local now = tick()
		if nextCatchTime <= 0 or nextCatchTime > now + CATCH_INTERVAL then
			nextCatchTime = now + CATCH_INTERVAL
		end
		task.spawn(function()
			while isRunning do
				local now = tick()
				if now >= nextCatchTime and #storedFish < MAX_CAPACITY then
					nextCatchTime = now + CATCH_INTERVAL
					catchFish()
				end
				updateNextCatchUI()
				if math.floor(now) % 60 == 0 then saveTrapData() end
				task.wait(1)
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		if player.Name == owner then
			saveTrapData()
			isRunning = false
			if fishTrap.Parent then fishTrap:Destroy() end
		end
	end)

	fishTrap.AncestryChanged:Connect(function()
		if not fishTrap.Parent then isRunning = false end
	end)

	loadTrapData()
	updateUI()
	startLoop()
end

return FishTrapCore
