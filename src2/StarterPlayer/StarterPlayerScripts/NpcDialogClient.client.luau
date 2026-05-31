local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local player   = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local DialogModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DialogModule"))

local sellChoiceEvent      = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SellChoiceEvent")
local gambleChoiceEvent    = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("GambleChoiceEvent")
local soldNotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SoldNotification")
local gambleNotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("GambleNotification")
local enablePromptEvent    = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SetPromptEvent")

local shopSellerDialogEvent  = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("ShopSellerDialog")
local openShopLocalEvent     = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("OpenShopLocal")
local openRobuxShopEvent     = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("OpenRobuxShop")
local openRobuxShopLocalEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("OpenRobuxShopLocal")

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
				dialog:hideGui("Hold a fish first to check its value!")
			else
				dialog:hideGui(("That's worth <font color='rgb(0,187,255)'>¢%d</font>!"):format(amount))
			end
		else
			if amount == 0 then
				dialog:hideGui("Hold a fish to sell it, or use 'Sell All'!")
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

	local dialog = DialogModule.new("Appraiser", root, head, prompt)
	dialog:addDialog("Want me to appraise your fish? <font color='rgb(255,150,150)'>(¢4000)</font>", {
		"Appraise it!",
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
				dialog:hideGui("Hold a fish to appraise!")
			elseif messageType == "insufficient_coins" then
				dialog:hideGui("You need <font color='rgb(255,150,150)'>¢4000</font> to appraise!")
			elseif messageType == "invalid_fish" then
				dialog:hideGui("This fish can't be appraised!")
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

-- ─── Pap (Robux Shop) ─────────────────────────────────────────────────────────
local papDialog = nil

local function initPap()
	local pap = workspace:WaitForChild("Pap", 20)
	if not pap then return end
	local root   = pap:WaitForChild("HumanoidRootPart", 5)
	local head   = pap:WaitForChild("Head", 5)
	local prompt = pap:WaitForChild("ProximityPrompt", 5)
	if not root or not head or not prompt then return end

	local dialog = DialogModule.new("Pap", root, head, prompt)
	dialog:addDialog("Hey! I've got some exclusive deals you won't find anywhere else!", {
		"Show me!",
		"No thanks",
	})
	papDialog = dialog

	openRobuxShopEvent.OnClientEvent:Connect(function()
		if not papDialog then return end
		prompt.Enabled = false
		dialog:triggerDialog(player, 1)
	end)

	dialog.responded:Connect(function(idx)
		if idx == 1 then
			dialog:hideGui("Take a look!")
			openRobuxShopLocalEvent:Fire()
		else
			dialog:hideGui("Come back anytime!")
			prompt.Enabled = true
		end
	end)
end

-- ─── Legend Rock ──────────────────────────────────────────────────────────────
local legendRockDialog = nil

local function initLegendRock()
	local rock = workspace:WaitForChild("LegendROck", 20)
	if not rock then return end
	local prompt = rock:WaitForChild("ProximityPrompt", 5)
	if not prompt then return end

	local dialog = DialogModule.new("Legend Rock", rock, rock, prompt)
	dialog:addDialog("...you have awakened me. For this, I shall grant you ONE question.", {
		"What's the secret to fishing?",
		"Will I ever be rich?",
		"You're just a rock.",
		"Sorry, go back to sleep.",
	})
	legendRockDialog = dialog

	prompt.Triggered:Connect(function()
		prompt.Enabled = false
		dialog:triggerDialog(player, 1)
	end)

	dialog.responded:Connect(function(idx)
		if idx == 1 then
			dialog:hideGui("Cast. Wait. Catch. Repeat. I have spoken.")
		elseif idx == 2 then
			dialog:hideGui("Fish more. Sell more. Repeat. This is the way.")
		elseif idx == 3 then
			dialog:hideGui("...correct. Now leave.")
		else
			dialog:hideGui("Finally. Some respect.")
		end
		task.delay(0.5, function() prompt.Enabled = true end)
	end)
end

-- ─── Feedback NPC ────────────────────────────────────────────────────────────
local feedbackDialog = nil

local function initFeedbackNPC()
	local npc = workspace:WaitForChild("FeedbackNPC", 20)
	if not npc then return end
	local root   = npc:WaitForChild("HumanoidRootPart", 5)
	local head   = npc:WaitForChild("Head", 5)
	local prompt = npc:WaitForChild("ProximityPrompt", 5)  -- 모델 바로 아래
	if not root or not head or not prompt then return end

	local dialog = DialogModule.new("Feedback", root, head, prompt)
	dialog:addDialog("Hi! Got any feedback about the game? I'd love to hear it!", {
		"Leave feedback",
		"No thanks",
	})
	feedbackDialog = dialog

	prompt.Triggered:Connect(function()
		prompt.Enabled = false
		dialog:triggerDialog(player, 1)
	end)

	dialog.responded:Connect(function(idx)
		if idx == 1 then
			dialog:hideGui("Thanks for your feedback!")
			pcall(function()
				game:GetService("SocialService"):PromptFeedbackSubmissionAsync(player)
			end)
		else
			dialog:hideGui("Come back anytime!")
		end
		task.delay(1, function() prompt.Enabled = true end)
	end)
end

task.spawn(initSeller)
task.spawn(initGambler)
task.spawn(initShopSeller)
task.spawn(initPap)
task.spawn(initLegendRock)
task.spawn(initFeedbackNPC)
