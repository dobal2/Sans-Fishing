local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local player   = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local DialogModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DialogModule"))

local sellChoiceEvent      = ReplicatedStorage:WaitForChild("SellChoiceEvent")
local gambleChoiceEvent    = ReplicatedStorage:WaitForChild("GambleChoiceEvent")
local soldNotificationEvent = ReplicatedStorage:WaitForChild("SoldNotification")
local gambleNotificationEvent = ReplicatedStorage:WaitForChild("GambleNotification")
local enablePromptEvent    = ReplicatedStorage:WaitForChild("SetPromptEvent")

local voidQuestEvents      = ReplicatedStorage:FindFirstChild("VoidQuestEvents")
local voidQuestChoiceEvent = voidQuestEvents and voidQuestEvents:FindFirstChild("VoidQuestChoiceEvent")
local voidQuestGuiEvent    = voidQuestEvents and voidQuestEvents:FindFirstChild("VoidQuestGuiEvent")
local voidQuestNotifEvent  = voidQuestEvents and voidQuestEvents:FindFirstChild("VoidQuestNotificationEvent")

local shopSellerDialogEvent = ReplicatedStorage:WaitForChild("ShopSellerDialog")
local openShopLocalEvent    = ReplicatedStorage:WaitForChild("OpenShopLocal")

-- ─── Seller ───────────────────────────────────────────────────────────────────
local sellerDialog = nil

local function initSeller()
	local sellShop = workspace:WaitForChild("Sell Shop", 20)
	if not sellShop then return end
	local seller = sellShop:WaitForChild("Seller", 10)
	if not seller then return end
	local root   = seller:WaitForChild("HumanoidRootPart", 5)
	local head   = seller:WaitForChild("Head", 5)
	local prompt = seller:WaitForChild("ProximityPrompt", 5)
	if not root or not head or not prompt then return end

	local dialog = DialogModule.new("Seller", root, head, prompt)
	dialog:addDialog("Got anything to sell?", {
		"Sell all fish",
		"Sell held fish",
		"Check held fish value",
		"No thanks",
	})
	sellerDialog = dialog

	prompt.Triggered:Connect(function()
		prompt.Enabled = false
		dialog:triggerDialog(player, 1)
	end)

	dialog.responded:Connect(function(idx)
		if idx == 1 then
			sellChoiceEvent:FireServer("Option1")
		elseif idx == 2 then
			sellChoiceEvent:FireServer("Option2")
		elseif idx == 3 then
			sellChoiceEvent:FireServer("Option3")
		else
			dialog:hideGui("Come back anytime!")
			enablePromptEvent:FireServer(true, "seller")
		end
	end)

	soldNotificationEvent.OnClientEvent:Connect(function(amount, isPreview)
		if not sellerDialog then return end
		if isPreview then
			if amount == -1 then
				dialog:hideGui("Bye!")
			elseif amount == 0 then
				dialog:hideGui("I don't see any fish on you!")
			else
				dialog:hideGui(("That's worth <font color='rgb(0,187,255)'>¢%d</font>!"):format(amount))
			end
		else
			if amount == 0 then
				dialog:hideGui("You don't have any fish to sell!")
			else
				dialog:hideGui(("Here's <font color='rgb(0,187,255)'>¢%d</font> for your catch!"):format(amount))
			end
		end
		enablePromptEvent:FireServer(true, "seller")
	end)
end

-- ─── Gambler ──────────────────────────────────────────────────────────────────
local gamblerDialog = nil

local function initGambler()
	local gambler = workspace:WaitForChild("Gambler", 20)
	if not gambler then return end
	local root   = gambler:WaitForChild("HumanoidRootPart", 5)
	local head   = gambler:WaitForChild("Head", 5)
	local prompt = gambler:WaitForChild("ProximityPrompt", 5)
	if not root or not head or not prompt then return end

	local dialog = DialogModule.new("Gambler", root, head, prompt)
	dialog:addDialog("Want to gamble? <font color='rgb(255,150,150)'>(¢4000)</font>", {
		"Let's gamble!",
		"No thanks",
	})
	gamblerDialog = dialog

	prompt.Triggered:Connect(function()
		prompt.Enabled = false
		dialog:triggerDialog(player, 1)
	end)

	dialog.responded:Connect(function(idx)
		if idx == 1 then
			gambleChoiceEvent:FireServer("Option1")
		else
			dialog:hideGui("Come back anytime!")
			enablePromptEvent:FireServer(true, "gambler")
		end
	end)

	gambleNotificationEvent.OnClientEvent:Connect(function(amount, isPreview, messageType, extraData)
		if not gamblerDialog then return end
		if isPreview then
			if messageType == "exit" then
				dialog:hideGui("Come back anytime!")
			elseif messageType == "no_fish" then
				dialog:hideGui("Hold a fish to gamble!")
			elseif messageType == "insufficient_coins" then
				dialog:hideGui("You need <font color='rgb(255,150,150)'>¢4000</font> to gamble!")
			elseif messageType == "invalid_fish" then
				dialog:hideGui("This fish can't be gambled!")
			end
		else
			if messageType == "success" and extraData then
				local weightChange = extraData.newWeight - extraData.oldWeight
				local dir = weightChange > 0 and "increased" or "decreased"
				local frozenStatus = ""
				if extraData.wasFrozen and not extraData.willBeFrozen then
					frozenStatus = " <font color='rgb(150,220,255)'>(Unfrozen)</font>"
				elseif not extraData.wasFrozen and extraData.willBeFrozen then
					frozenStatus = " <font color='rgb(150,220,255)'>(Frozen!)</font>"
				end
				dialog:hideGui(("Weight %s by <font color='rgb(255,220,0)'>%.1fkg</font>%s"):format(dir, math.abs(weightChange), frozenStatus))
			end
		end
		enablePromptEvent:FireServer(true, "gambler")
	end)
end

-- ─── Void Quest Giver ─────────────────────────────────────────────────────────
local voidDialog = nil

local function initVoidQuestGiver()
	local voidNpc = workspace:WaitForChild("Void Quest Giver", 20)
	if not voidNpc then return end
	local root   = voidNpc:WaitForChild("HumanoidRootPart", 5)
	local head   = voidNpc:WaitForChild("Head", 5)
	local prompt = voidNpc:WaitForChild("ProximityPrompt", 5)
	if not root or not head or not prompt then return end

	local dialog = DialogModule.new("Void Collector", root, head, prompt)
	dialog:addDialog("<font color='rgb(180,130,255)'>The void hungers for Unknown fish...</font>", {
		"Tell me more",
		"Leave",
	})
	voidDialog = dialog

	prompt.Triggered:Connect(function()
		prompt.Enabled = false
		dialog:triggerDialog(player, 1)
	end)

	dialog.responded:Connect(function(idx)
		if idx == 1 then
			voidQuestChoiceEvent:FireServer("Option1")
		else
			voidQuestChoiceEvent:FireServer("Option2")
			dialog:hideGui("<font color='rgb(180,130,255)'>The void will wait...</font>")
			enablePromptEvent:FireServer(true, "void_collector")
		end
	end)

	voidQuestNotifEvent.OnClientEvent:Connect(function(title, message, messageType)
		if not voidDialog then return end
		local color = "rgb(255,255,255)"
		if messageType == "success" or messageType == "complete" then
			color = "rgb(180,130,255)"
		elseif messageType == "error" then
			color = "rgb(255,100,100)"
		elseif messageType == "progress" then
			color = "rgb(180,130,255)"
		end
		dialog:hideGui(("<font color='%s'>%s</font>"):format(color, message))
		enablePromptEvent:FireServer(true, "void_collector")
	end)
end

-- ─── Shop Seller ──────────────────────────────────────────────────────────────
local shopSellerDialog = nil

local function initShopSeller()
	local upgradeShop = workspace:WaitForChild("Upgrade Shop", 20)
	if not upgradeShop then return end
	local shopSeller = upgradeShop:WaitForChild("ShopSeller", 10)
	if not shopSeller then return end
	local root   = shopSeller:WaitForChild("HumanoidRootPart", 5)
	local head   = shopSeller:WaitForChild("Head", 5)
	local prompt = shopSeller:WaitForChild("ProximityPrompt", 5)
	if not root or not head or not prompt then return end

	local dialog = DialogModule.new("Shop Keeper", root, head, prompt)
	dialog:addDialog("Looking for a new rod? I've got the best in stock!", {
		"Show me the rods",
		"No thanks",
	})
	shopSellerDialog = dialog

	shopSellerDialogEvent.OnClientEvent:Connect(function()
		if not shopSellerDialog then return end
		prompt.Enabled = false
		dialog:triggerDialog(player, 1)
	end)

	dialog.responded:Connect(function(idx)
		if idx == 1 then
			dialog:hideGui("Right this way!")
			openShopLocalEvent:Fire()
		else
			dialog:hideGui("Come back anytime!")
			enablePromptEvent:FireServer(true, "shop_seller")
		end
	end)
end

task.spawn(initSeller)
task.spawn(initGambler)
task.spawn(initVoidQuestGiver)
task.spawn(initShopSeller)
