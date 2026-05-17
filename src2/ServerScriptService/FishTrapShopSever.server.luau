local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")

local datamanager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))

local ROBUX_FISHTRAP_GAMEPASS_ID = 1423175879

-- Tracks players who initiated a gamepass purchase mid-session
local pendingGamepassPurchases = {}

-- Coin prices (RobuxFishTrap is free with gamepass)
local FISH_TRAP_DATA = {
	["BasicFishTrap"]    = 30000,
	["AdvancedFishTrap"] = 200000,
	["MasterFishTrap"]   = 600000,
	["RobuxFishTrap"]    = 0,
}

local buyFishTrapBindable = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("BuyFishTrapBindable")
local showNoticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("ShowNoticeEvent")

local function hasGamepass(player, gamepassId)
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	return success and result
end

-- Remove all equipped fish traps then give the selected one
local function equipFishTrap(plr, fishTrapName)
	for _, container in ipairs({ plr:FindFirstChild("Backpack"), plr:FindFirstChild("StarterGear"), plr.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool.Name:find("FishTrap") then
					tool:Destroy()
				end
			end
		end
	end

	local trapModel = ServerStorage:FindFirstChild(fishTrapName)
	if not trapModel then
		warn("Fish Trap model not found in ServerStorage:", fishTrapName)
		return false
	end

	local clonedTrap = trapModel:Clone()
	clonedTrap.Parent = plr:FindFirstChild("Backpack") or plr

	-- Update CurrentFishTrap value
	local leaderstats = plr:FindFirstChild("leaderstats")
	if leaderstats then
		local currentFishTrap = leaderstats:FindFirstChild("CurrentFishTrap")
		if currentFishTrap then
			local valueObj = currentFishTrap:FindFirstChild("Value")
			if valueObj then
				valueObj.Value = fishTrapName
			end
		end
	end

	return true
end

-- Grant RobuxFishTrap immediately after successful gamepass purchase
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if gamePassId ~= ROBUX_FISHTRAP_GAMEPASS_ID or not wasPurchased then return end
	if not pendingGamepassPurchases[player.UserId] then return end

	pendingGamepassPurchases[player.UserId] = nil

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local fishTrapsFolder = leaderstats:FindFirstChild("FishTraps")
	if not fishTrapsFolder then return end

	local robuxFishTrap = fishTrapsFolder:FindFirstChild("RobuxFishTrap")
	if robuxFishTrap then
		robuxFishTrap.Value = true
		local msg = equipFishTrap(player, "RobuxFishTrap")
			and "Robux Fish Trap purchased and equipped!"
			or  "Robux Fish Trap purchased but failed to equip!"
		showNoticeEvent:FireClient(player, msg)
	end
end)

buyFishTrapBindable.Event:Connect(function(plr, fishTrapName)
	local fishTrapPrice = FISH_TRAP_DATA[fishTrapName]
	if not fishTrapPrice then
		warn("Unknown Fish Trap:", fishTrapName)
		showNoticeEvent:FireClient(plr, "Unknown Fish Trap!")
		return
	end

	local leaderstats = plr:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("No leaderstats:", plr.Name)
		return
	end

	local coins          = leaderstats:FindFirstChild("Coins")
	local fishTrapsFolder = leaderstats:FindFirstChild("FishTraps")

	if not (coins and fishTrapsFolder) then
		warn("Missing required leaderstats elements:", plr.Name)
		return
	end

	local fishTrapBool = fishTrapsFolder:FindFirstChild(fishTrapName)
	if not fishTrapBool then
		warn("FishTrap BoolValue not found:", plr.Name, fishTrapName)
		return
	end

	-- RobuxFishTrap: requires gamepass
	if fishTrapName == "RobuxFishTrap" then
		if fishTrapBool.Value then
			local msg = equipFishTrap(plr, fishTrapName) and "Robux Fish Trap equipped!" or "Failed to equip Robux Fish Trap!"
			showNoticeEvent:FireClient(plr, msg)
			return
		end

		if not hasGamepass(plr, ROBUX_FISHTRAP_GAMEPASS_ID) then
			pendingGamepassPurchases[plr.UserId] = true
			showNoticeEvent:FireClient(plr, "Purchasing Robux Fish Trap gamepass...")
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(plr, ROBUX_FISHTRAP_GAMEPASS_ID)
			end)
			return
		end

		-- Gamepass already owned: grant for free
		fishTrapBool.Value = true
		local msg = equipFishTrap(plr, fishTrapName)
			and "Robux Fish Trap obtained for free with gamepass!"
			or  "Robux Fish Trap obtained but failed to equip!"
		showNoticeEvent:FireClient(plr, msg)
		return
	end

	-- Already owned: just equip
	if fishTrapBool.Value then
		local msg = equipFishTrap(plr, fishTrapName) and "Fish Trap equipped!" or "Failed to equip Fish Trap!"
		showNoticeEvent:FireClient(plr, msg)
		return
	end

	-- Insufficient coins
	if coins.Value < fishTrapPrice then
		showNoticeEvent:FireClient(plr, string.format("Not enough coins! Need %d coins", fishTrapPrice))
		return
	end

	-- Purchase
	coins.Value = coins.Value - fishTrapPrice
	datamanager:UpdateData(plr, "Coins", coins.Value)
	fishTrapBool.Value = true

	local msg = equipFishTrap(plr, fishTrapName) and "Fish Trap purchased successfully!" or "Fish Trap purchased but failed to equip!"
	showNoticeEvent:FireClient(plr, msg)
end)

game.Players.PlayerRemoving:Connect(function(player)
	pendingGamepassPurchases[player.UserId] = nil
end)
