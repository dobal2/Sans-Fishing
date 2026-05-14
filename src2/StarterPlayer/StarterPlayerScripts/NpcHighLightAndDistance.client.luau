local player = game.Players.LocalPlayer
local sellShop = workspace:WaitForChild("Sell Shop"):WaitForChild("Seller")
local gambler = workspace:WaitForChild("Gambler")
local updateShop = workspace:WaitForChild("Upgrade Shop"):WaitForChild("ShopSeller")
local robuxShop = workspace:WaitForChild("Pap")
local boatDealer1 = workspace:WaitForChild("BoatDealer1")
local boatDealer2 = workspace:FindFirstChild("BoatDealer2")
local voidQuestGiver = workspace:FindFirstChild("Void Quest Giver")

local TweenService = game:GetService("TweenService")

-- Create Highlights
local sellHighlight = sellShop:FindFirstChild("Highlight") or Instance.new("Highlight")
sellHighlight.Parent = sellShop

local gambleHighlight = gambler:FindFirstChild("Highlight") or Instance.new("Highlight")
gambleHighlight.Parent = gambler

local updateHighlight = updateShop:FindFirstChild("Highlight") or Instance.new("Highlight")
updateHighlight.Parent = updateShop

local robuxHighlight = robuxShop:FindFirstChild("Highlight") or Instance.new("Highlight")
robuxHighlight.Parent = robuxShop

local boatDealer1Highlight = boatDealer1:FindFirstChild("Highlight") or Instance.new("Highlight")
boatDealer1Highlight.Parent = boatDealer1

local boatDealer2Highlight = boatDealer2 and (boatDealer2:FindFirstChild("Highlight") or Instance.new("Highlight"))
if boatDealer2Highlight and boatDealer2 then
	boatDealer2Highlight.Parent = boatDealer2
end

-- Add Void Quest Giver Highlight
local voidQuestHighlight = voidQuestGiver and (voidQuestGiver:FindFirstChild("Highlight") or Instance.new("Highlight"))
if voidQuestHighlight and voidQuestGiver then voidQuestHighlight.Parent = voidQuestGiver end

local RANGE = 10
local UPDATE_SHOP_RANGE = 15  -- Separate range for upgrade shop
local VOID_QUEST_RANGE = 12   -- Void Quest Giver range
local CHECK_INTERVAL = 0.1
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sellChoiceEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SellChoiceEvent")

-- Void Quest related events
local voidQuestEvents = ReplicatedStorage:FindFirstChild("VoidQuestEvents")
local voidQuestChoiceEvent = voidQuestEvents and voidQuestEvents:FindFirstChild("VoidQuestChoiceEvent")

-- Wait for character to load
repeat task.wait(0.1) until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

-- Function to get NPC position
local function getNPCPosition(npc)
	if npc.PrimaryPart then
		return npc.PrimaryPart.Position
	end
	local part = npc:FindFirstChild("HumanoidRootPart", true) or
		npc:FindFirstChild("Torso", true) or
		npc:FindFirstChild("UpperTorso", true) or
		npc:FindFirstChild("Head", true) or
		npc:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or Vector3.new(0, 0, 0)
end

-- Highlight animation function
local function animateHighlight(highlight, targetTransparency)
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(highlight, tweenInfo, {OutlineTransparency = targetTransparency})
	tween:Play()
end

-- Check if NPC can be interacted with
local function canInteractWithNPC(npc)
	local prompt = npc:FindFirstChild("ProximityPrompt")
	return prompt and prompt.Enabled
end

local wasNearby = {
	seller = false,
	gambler = false,
	questGiver = false,
	updateShop = false,
	robuxShop = false,
	boatDealer1 = false,
	boatDealer2 = false,
	voidQuestGiver = false  -- Void Quest Giver
}

-- Distance check function (per-NPC range)
local function isPlayerNearby(npc, customRange)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	local playerPos = character.HumanoidRootPart.Position
	local npcPos = getNPCPosition(npc)
	local distance = (playerPos - npcPos).Magnitude
	local range = customRange or RANGE
	return distance <= range
end

-- Initial state
sellHighlight.Enabled = true
sellHighlight.OutlineTransparency = 1
gambleHighlight.Enabled = true
gambleHighlight.OutlineTransparency = 1
updateHighlight.Enabled = true
updateHighlight.OutlineTransparency = 1
robuxHighlight.Enabled = true
robuxHighlight.OutlineTransparency = 1
boatDealer1Highlight.Enabled = true
boatDealer1Highlight.OutlineTransparency = 1
if boatDealer2Highlight then
	boatDealer2Highlight.Enabled = true
	boatDealer2Highlight.OutlineTransparency = 1
end
if voidQuestHighlight then
	voidQuestHighlight.Enabled = true
	voidQuestHighlight.OutlineTransparency = 1
	voidQuestHighlight.OutlineColor = Color3.fromRGB(150, 100, 255)
	voidQuestHighlight.FillColor = Color3.fromRGB(150, 100, 255)
	voidQuestHighlight.FillTransparency = 0.8
end

-- Main loop
while true do
	task.wait(CHECK_INTERVAL)
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		continue
	end

	-- Seller
	local sellNearby = isPlayerNearby(sellShop)
	local canInteractSeller = canInteractWithNPC(sellShop)
	local shouldShowSellerHighlight = sellNearby and canInteractSeller

	if shouldShowSellerHighlight ~= wasNearby.seller then
		animateHighlight(sellHighlight, shouldShowSellerHighlight and 0 or 1)
	end

	if not sellNearby and wasNearby.seller then
		local prompt = sellShop:FindFirstChild("ProximityPrompt")
		if prompt and not prompt.Enabled then
			sellChoiceEvent:FireServer("Option4")
			local gui = player.PlayerGui:FindFirstChild("SellOptions")
			if gui then gui.Enabled = false end
		end
	end
	wasNearby.seller = shouldShowSellerHighlight

	-- Gambler
	local gambleNearby = isPlayerNearby(gambler)
	local canInteractGambler = canInteractWithNPC(gambler)
	local shouldShowGamblerHighlight = gambleNearby and canInteractGambler

	if shouldShowGamblerHighlight ~= wasNearby.gambler then
		animateHighlight(gambleHighlight, shouldShowGamblerHighlight and 0 or 1)
	end

	if not gambleNearby and wasNearby.gambler then
		local prompt = gambler:FindFirstChild("ProximityPrompt")
		if prompt and not prompt.Enabled then
			sellChoiceEvent:FireServer("Option4")
			local gui = player.PlayerGui:FindFirstChild("GambleOptions")
			if gui then gui.Enabled = false end
		end
	end
	wasNearby.gambler = shouldShowGamblerHighlight

	-- Update Shop (range 15)
	local updateNearby = isPlayerNearby(updateShop, UPDATE_SHOP_RANGE)
	local canInteractUpdate = canInteractWithNPC(updateShop)
	local shouldShowUpdateHighlight = updateNearby and canInteractUpdate

	if shouldShowUpdateHighlight ~= wasNearby.updateShop then
		animateHighlight(updateHighlight, shouldShowUpdateHighlight and 0 or 1)
	end
	wasNearby.updateShop = shouldShowUpdateHighlight

	-- Robux Shop
	local robuxNearby = isPlayerNearby(robuxShop)
	local canInteractRobux = canInteractWithNPC(robuxShop)
	local shouldShowRobuxHighlight = robuxNearby and canInteractRobux

	if shouldShowRobuxHighlight ~= wasNearby.robuxShop then
		animateHighlight(robuxHighlight, shouldShowRobuxHighlight and 0 or 1)
	end
	wasNearby.robuxShop = shouldShowRobuxHighlight

	-- Boat Dealer 1
	local boatDealer1Nearby = isPlayerNearby(boatDealer1)
	local canInteractBoatDealer1 = canInteractWithNPC(boatDealer1)
	local shouldShowBoatDealer1Highlight = boatDealer1Nearby and canInteractBoatDealer1

	if shouldShowBoatDealer1Highlight ~= wasNearby.boatDealer1 then
		animateHighlight(boatDealer1Highlight, shouldShowBoatDealer1Highlight and 0 or 1)
	end
	wasNearby.boatDealer1 = shouldShowBoatDealer1Highlight

	-- Boat Dealer 2
	if boatDealer2 and boatDealer2Highlight then
		local boatDealer2Nearby = isPlayerNearby(boatDealer2)
		local canInteractBoatDealer2 = canInteractWithNPC(boatDealer2)
		local shouldShowBoatDealer2Highlight = boatDealer2Nearby and canInteractBoatDealer2

		if shouldShowBoatDealer2Highlight ~= wasNearby.boatDealer2 then
			animateHighlight(boatDealer2Highlight, shouldShowBoatDealer2Highlight and 0 or 1)
		end
		wasNearby.boatDealer2 = shouldShowBoatDealer2Highlight
	end

	-- Void Quest Giver
	if voidQuestGiver then
		local voidQuestNearby = isPlayerNearby(voidQuestGiver, VOID_QUEST_RANGE)
		local canInteractVoidQuest = canInteractWithNPC(voidQuestGiver)
		local shouldShowVoidQuestHighlight = voidQuestNearby and canInteractVoidQuest

		if shouldShowVoidQuestHighlight ~= wasNearby.voidQuestGiver then
			if voidQuestHighlight then
				animateHighlight(voidQuestHighlight, shouldShowVoidQuestHighlight and 0 or 1)
			end
		end

		if not voidQuestNearby and wasNearby.voidQuestGiver then
			local prompt = voidQuestGiver:FindFirstChild("ProximityPrompt")
			if prompt and not prompt.Enabled and voidQuestChoiceEvent then
				voidQuestChoiceEvent:FireServer("Option2")
				local gui = player.PlayerGui:FindFirstChild("VoidQuestOptions")
				if gui then gui.Enabled = false end
			end
		end
		wasNearby.voidQuestGiver = shouldShowVoidQuestHighlight
	end
end
