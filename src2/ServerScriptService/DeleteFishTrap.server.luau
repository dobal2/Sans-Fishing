local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local FishTrapDataManager = require(ServerScriptService:WaitForChild("FishTrapManager"):WaitForChild("DataManager"))
local FishData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDataModule"))

local Misc = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc")
local CollectFishTrapRemote = Misc:WaitForChild("CollectFishTrapRemote")
local ShowNoticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("ShowNoticeEvent")

local FISH_TRAP_NAMES = {
	["BasicFishTrap"]    = true,
	["AdvancedFishTrap"] = true,
	["MasterFishTrap"]   = true,
	["RobuxFishTrap"]    = true,
}

local function isFishTrap(tool)
	if not tool or not tool:IsA("Tool") then return false end
	return FISH_TRAP_NAMES[tool.Name] == true
end

local function getEquippedFishTrap(player)
	local char = player.Character
	if not char then return nil end
	local tool = char:FindFirstChildWhichIsA("Tool")
	if isFishTrap(tool) then return tool end
	return nil
end

local function buildFishInfo(storedFish)
	return {
		name      = storedFish.name or "Common",
		fishName  = storedFish.fishName or "Unknown",
		weight    = storedFish.weight or 1,
		minWeight = storedFish.minWeight or 1,
		maxWeight = storedFish.maxWeight or 1,
		value     = storedFish.value or 0,
	}
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

local function deliverStoredFish(player, storedFishList)
	local fishCaughtBindable = ServerScriptService:FindFirstChild("FishCaughtBindable")
	if not fishCaughtBindable then
		warn("DeleteFishTrap: FishCaughtBindable not found")
		return 0
	end

	if not player:FindFirstChild("ItemReady") then
		player:WaitForChild("ItemReady", 10)
	end

	if not player:FindFirstChild("ItemReady") then
		warn("DeleteFishTrap: ItemReady not found for", player.Name)
		return 0
	end

	local total = 0
	for _, storedFish in ipairs(storedFishList) do
		local fishInfo = buildFishInfo(storedFish)
		if fishInfo.fishName then
			fishCaughtBindable:Fire(player, fishInfo)
			total += 1
		end
	end

	return total
end

CollectFishTrapRemote.OnServerEvent:Connect(function(player)
	local tool = getEquippedFishTrap(player)
	if not tool then
		ShowNoticeEvent:FireClient(player, "Hold a Fish Trap to collect it!")
		return
	end

	local totalFishAdded = 0
	local removed = false

	for _, obj in ipairs(workspace:GetChildren()) do
		local ownerVal = obj:FindFirstChild("Owner")
		local trapIdVal = obj:FindFirstChild("TrapId")
		if ownerVal and ownerVal.Value == player.Name and trapIdVal then
			local trapKey = "FishTrapData_" .. trapIdVal.Value
			local allData = FishTrapDataManager:GetData(player)
			local trapData = allData and allData[trapKey]

			if trapData and trapData.storedFish and #trapData.storedFish > 0 then
				local delivered = deliverStoredFish(player, trapData.storedFish)
				if delivered <= 0 then
					ShowNoticeEvent:FireClient(player, "Failed to collect fish trap. Try again.")
					return
				end
				totalFishAdded += delivered
			end

			FishTrapDataManager:UpdateData(player, "FishTrapData_" .. trapIdVal.Value, nil)
			local trapTypeVal = obj:FindFirstChild("TrapType")
			restoreEquippedFishTrapTool(player, trapTypeVal and trapTypeVal.Value or tool.Name)
			obj:Destroy()
			removed = true
		end
	end

	if removed then
		if totalFishAdded > 0 then
			ShowNoticeEvent:FireClient(player, string.format("Fish Trap collected! Got %d fish.", totalFishAdded))
		else
			ShowNoticeEvent:FireClient(player, "Fish Trap collected! (No fish inside)")
		end
	else
		ShowNoticeEvent:FireClient(player, "No placed Fish Trap found!")
	end
end)
