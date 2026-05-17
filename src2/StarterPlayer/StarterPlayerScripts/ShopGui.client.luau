local player = game.Players.LocalPlayer
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local cam = workspace.CurrentCamera
local MarketplaceService = game:GetService("MarketplaceService")

local RodData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("RodDataModule"))
local voidRodModel = workspace:FindFirstChild("VoidRodModel")
local voidProximity = voidRodModel and voidRodModel:FindFirstChild("ProximityPrompt")
local ROBUX_ROD_GAMEPASS_ID = 1410895892

local shopGui = player.PlayerGui:WaitForChild("ShopGui")
local gui = shopGui
local buyframe = gui:WaitForChild("buyframe")
local nameText = buyframe:WaitForChild("Name")
local coinText = buyframe:WaitForChild("Cointext")
local showNoticeEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("NoticeEventForClient")
local luckText = buyframe:WaitForChild("Luck")
local powerText = buyframe:WaitForChild("Power")
local weightText = buyframe:WaitForChild("Weight")

local originalTextColor = coinText.TextColor3

local customInventory = player.PlayerGui:WaitForChild("Custom Inventory")
local hotBar = customInventory:WaitForChild("hotBar")
local inventoryOpenButton = customInventory:FindFirstChild("openButton") or customInventory:FindFirstChild("OpenButton")

local mainGui = player.PlayerGui:WaitForChild("Main")
local fishingButton = mainGui:WaitForChild("Fishing")
local sellButton = mainGui:WaitForChild("Sell")
local upgradeButton = mainGui:WaitForChild("Upgrade")
local freeRewardButton = mainGui:WaitForChild("Free Reward")

local buyBtnFrame = buyframe:WaitForChild("buybutton")
local buyButton    = buyBtnFrame:WaitForChild("TextButton")
local buyBtnLabel  = buyBtnFrame:FindFirstChild("TextLabel")
local buyBtnGlow   = buyBtnFrame:FindFirstChild("Glow")
local leftButton   = buyframe:WaitForChild("leftarrow")
local rightButton  = buyframe:WaitForChild("rightarrow")
local exitBtnFrame = buyframe:WaitForChild("Exitbutton")
local exitButton   = exitBtnFrame:WaitForChild("TextButton")

-- Hover tween for buy button
local HOVER_IN  = TweenInfo.new(0.12, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local HOVER_OUT = TweenInfo.new(0.10, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local buyBtnScale = buyBtnFrame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
if not buyBtnScale.Parent then buyBtnScale.Parent = buyBtnFrame end
local buyBtnGradient = buyButton:FindFirstChildOfClass("UIGradient")

local GREEN_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 255, 100)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 50)),
})
local RED_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 0, 0)),
})

local GREEN_COLOR = Color3.fromRGB(0, 200, 50)
local RED_COLOR   = Color3.fromRGB(200, 0, 0)

local buyBtnStroke = buyButton:FindFirstChildOfClass("UIStroke")
	or buyBtnFrame:FindFirstChildOfClass("UIStroke")

local function setBuyButtonState(isGreen)
	if buyBtnGradient then
		buyBtnGradient.Color = isGreen and GREEN_GRADIENT or RED_GRADIENT
	end
	if buyBtnStroke then
		buyBtnStroke.Color = isGreen and GREEN_COLOR or RED_COLOR
	end
	buyButton.BackgroundColor3 = isGreen and GREEN_COLOR or RED_COLOR
	if buyBtnGlow then
		ts:Create(buyBtnGlow, TweenInfo.new(0.2), {ImageColor3 = isGreen and GREEN_COLOR or RED_COLOR}):Play()
	end
end

local nameGradient = nameText:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
if not nameGradient.Parent then nameGradient.Parent = nameText end
nameGradient.Rotation = 90

local ROD_NAME_GRADIENTS = {
	SliverRod    = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 220, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 160, 220)) }),
	GoldRod      = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 80)),  ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 140, 20))  }),
	CrystalRod   = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 240, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 180, 255))  }),
	MagneticRod  = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 100, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 200))    }),
	BoneRod      = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 220, 200)), ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 140, 110)) }),
	CloverRod    = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 255, 120)),  ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 180, 60))   }),
	RainbowRod   = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),   ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 0)), ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 200, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 0, 255)) }),
	UnknownRod   = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 60, 60)),    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 20))    }),
	RobuxRod     = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 100)),   ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 180, 60))    }),
	ElectricRod  = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 100)), ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 200, 255))  }),
	RealisticRod = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 200, 100)), ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 120, 60))   }),
	ArcaneRod    = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 100, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 0, 200))   }),
	VoidRod      = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 80, 255)),  ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 0, 120))    }),
}
buyButton.MouseEnter:Connect(function()
	ts:Create(buyBtnScale, HOVER_IN, {Scale = 1.1}):Play()
end)
buyButton.MouseLeave:Connect(function()
	ts:Create(buyBtnScale, HOVER_OUT, {Scale = 1}):Play()
end)
buyButton.MouseButton1Down:Connect(function()
	ts:Create(buyBtnScale, HOVER_OUT, {Scale = 0.93}):Play()
end)
buyButton.MouseButton1Up:Connect(function()
	ts:Create(buyBtnScale, HOVER_IN, {Scale = 1.1}):Play()
end)

local openShopRemote    = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("OpenShop")
local openShopLocal     = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("OpenShopLocal")
local enablePromptEvent = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SetPromptEvent")
local buyRemote = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("BuyFishingRod")
local proximy = workspace:WaitForChild("Upgrade Shop"):WaitForChild("ShopSeller"):WaitForChild("ProximityPrompt")
local buySound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("Buy SFX")
local errorSound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("error")
local equipSound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("Equip")

local voidRodEvents = game.ReplicatedStorage:WaitForChild("VoidRodEvents")
local openVoidShopEvent = voidRodEvents:WaitForChild("OpenVoidShop")
local voidShopNoticeEvent = voidRodEvents:WaitForChild("VoidShopNotice")

local GroupService = game:GetService("GroupService")
local GROUP_ID = 9744474

local function checkGroupMembership()
	local success, isInGroup = pcall(function()
		return player:IsInGroup(GROUP_ID)
	end)
	if success and isInGroup then
		freeRewardButton.Visible = false
		return true
	end
	return false
end

local rodKeys = {
	"SliverRod", "GoldRod", "CrystalRod", "MagneticRod", "BoneRod",
	"CloverRod", "RainbowRod", "UnknownRod", "RobuxRod",
	"ElectricRod", "RealisticRod", "ArcaneRod"
}

local voidRodKeys = {"VoidRod"}

local target = 1
local canShop = true
local inputEnabled = true
local canBuy = true
local isVoidShop = false

local function isPlayerFishing()
	return player:GetAttribute("IsFishing") == true
end

local function hasRod(itemName)
	local rods = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Rods")
	if not rods then return false end
	local rodData = RodData.Rods[itemName]
	local lookupName = (rodData and rodData.storageName) or itemName
	local rod = rods:FindFirstChild(lookupName)
	return rod and rod.Value
end

local function equippedRod(itemName)
	local rod = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("CurrentRod")
	return rod and rod.Value == itemName
end

local function hasGamepass(gamepassId)
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	return success and result
end

local function hasCompletedVoidQuest()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return false end
	local quests = leaderstats:FindFirstChild("Quests")
	if not quests then return false end
	local completedQuests = quests:FindFirstChild("CompletedQuests")
	if not completedQuests then return false end
	local voidQuest = completedQuests:FindFirstChild("void_unknown_challenge")
	return voidQuest and voidQuest.Value == true
end

local function setCharacterTransparency(char, alpha)
	for _, part in pairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.LocalTransparencyModifier = alpha
		end
	end
end

local function formatNumber(number)
	local str = tostring(number)
	local formatted = ""
	local length = #str
	for i = 1, length do
		formatted = formatted .. str:sub(i, i)
		if (length - i) % 3 == 0 and i ~= length then
			formatted = formatted .. ","
		end
	end
	return formatted
end

local function updateView(skipTween)
	skipTween = skipTween or false
	local currentRodKeys = isVoidShop and voidRodKeys or rodKeys
	local rodName = currentRodKeys[target]
	local rodData = RodData.Rods[rodName]

	nameText.Text = rodData.displayName or rodName
	if ROD_NAME_GRADIENTS[rodName] then
		nameGradient.Color = ROD_NAME_GRADIENTS[rodName]
	end
	luckText.Text = "Luck: " .. (rodData.luck or "-")
	powerText.Text = "Power: " .. (rodData.power or "-")
	weightText.Text = "Weight: " .. (rodData.weight or "-")

	if rodName == "VoidRod" then
		if not hasCompletedVoidQuest() then
			buyButton.AutoButtonColor = false
			if buyBtnLabel then buyBtnLabel.Text = "Quest Required" end
		elseif hasRod(rodName) then
			buyButton.AutoButtonColor = false
			if buyBtnLabel then buyBtnLabel.Text = "Owned" end
		else
			buyButton.AutoButtonColor = true
			if buyBtnLabel then buyBtnLabel.Text = "Buy" end
		end
	elseif rodName == "RobuxRod" then
		if hasGamepass(ROBUX_ROD_GAMEPASS_ID) then
			buyButton.AutoButtonColor = false
			if buyBtnLabel then buyBtnLabel.Text = "Owned" end
		else
			buyButton.AutoButtonColor = true
			if buyBtnLabel then buyBtnLabel.Text = "Buy" end
		end
	else
		if hasRod(rodName) then
			buyButton.AutoButtonColor = false
			if buyBtnLabel then buyBtnLabel.Text = "Owned" end
		else
			buyButton.AutoButtonColor = true
			if buyBtnLabel then buyBtnLabel.Text = "Buy" end
		end
	end

	if equippedRod(rodName) then
		buyButton.AutoButtonColor = false
		if buyBtnLabel then buyBtnLabel.Text = "Equipped" end
	end

	if rodName == "RobuxRod" then
		coinText.Text = formatNumber(rodData.price) .. " Robux"
		coinText.TextColor3 = Color3.fromRGB(0, 255, 0)
	elseif rodName == "VoidRod" then
		coinText.Text = formatNumber(rodData.price) .. " Coins"
		coinText.TextColor3 = Color3.fromRGB(150, 100, 255)
	else
		coinText.Text = formatNumber(rodData.price) .. " Coins"
		coinText.TextColor3 = originalTextColor
	end

	-- Buy 버튼 색상: owned/equipped이면 항상 초록, 아니면 코인 여부로 판단
	local isOwned = equippedRod(rodName)
		or (rodName == "RobuxRod" and hasGamepass(ROBUX_ROD_GAMEPASS_ID))
		or (rodName ~= "RobuxRod" and hasRod(rodName))
	if isOwned then
		setBuyButtonState(true)
	elseif rodName == "RobuxRod" then
		setBuyButtonState(true)
	else
		local coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
		local affordable = coins and coins.Value >= rodData.price
		setBuyButtonState(affordable)
	end

	if not skipTween then
		local modelPosition = rodData.position
		local shopModel = workspace:FindFirstChild("Upgrade Shop")
		local rodModel = nil
		if rodName == "VoidRod" then
			rodModel = workspace:FindFirstChild("VoidRodModel")
		end
		local camPos, camCF
		if rodModel then
			local modelCFrame = rodModel:GetPrimaryPartCFrame() or rodModel:GetModelCFrame()
			local modelSize = rodModel:GetExtentsSize()
			local distance = math.max(8, modelSize.Magnitude * 1.5)
			local rightDirection = (modelCFrame * CFrame.Angles(0, math.rad(180), 0)).RightVector
			rightDirection = Vector3.new(rightDirection.X, 0, rightDirection.Z).Unit
			camPos = modelPosition + (rightDirection * distance) + Vector3.new(0, 2, 0)
			camCF = CFrame.lookAt(camPos, modelPosition + Vector3.new(0, 1, 0), Vector3.yAxis)
		else
			camPos = modelPosition + Vector3.new(8, 3, 0)
			camCF = CFrame.lookAt(camPos, modelPosition + Vector3.new(0, 1, 0), Vector3.yAxis)
		end
		ts:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = camCF }):Play()
	end
end

local function openShop(voidMode)
	player.PlayerGui:SetAttribute("ActiveLargeUI", "ShopGui")
	isVoidShop = voidMode or false
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
	end
	setCharacterTransparency(player.Character, 1)
	proximy.Enabled = false
	if voidProximity then voidProximity.Enabled = false end
	hotBar.Visible = false
	fishingButton.Visible = false
	sellButton.Visible = false
	upgradeButton.Visible = false
	freeRewardButton.Visible = false
	if inventoryOpenButton then inventoryOpenButton.Visible = false end
	checkGroupMembership()
	canShop = false
	target = 1
	cam.CameraType = Enum.CameraType.Scriptable
	updateView()
	buyframe.Visible = true
end

local function closeShop()
	buyframe.Visible = false
	setCharacterTransparency(player.Character, 0)
	cam.CameraType = Enum.CameraType.Custom
	isVoidShop = false
	hotBar.Visible = true
	fishingButton.Visible = true
	sellButton.Visible = true
	upgradeButton.Visible = true
	freeRewardButton.Visible = true
	if inventoryOpenButton then inventoryOpenButton.Visible = true end
	checkGroupMembership()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and not isPlayerFishing() then
		humanoid.WalkSpeed = 16
		humanoid.JumpHeight = 7.2
	end
	task.wait(0.5)
	proximy.Enabled = true
	if voidProximity then voidProximity.Enabled = true end
	enablePromptEvent:FireServer(true, "shop_seller")
	canShop = true
end

player.PlayerGui:GetAttributeChangedSignal("ActiveLargeUI"):Connect(function()
	if player.PlayerGui:GetAttribute("ActiveLargeUI") ~= "ShopGui" and buyframe.Visible then
		task.spawn(closeShop)
	end
end)

openShopRemote.OnClientEvent:Connect(function()
	if canShop then openShop(false) end
end)

openShopLocal.Event:Connect(function()
	task.wait(0.8)
	if canShop then openShop(false) end
end)

openVoidShopEvent.OnClientEvent:Connect(function()
	if canShop then openShop(true) end
end)

voidShopNoticeEvent.OnClientEvent:Connect(function(title, message)
	errorSound:Play()
	showNoticeEvent:Fire(message)
end)

local ARROW_NORMAL  = UDim2.new(0.102, 0, 0.495, 0)
local ARROW_HOVER   = UDim2.new(0.12,  0, 0.6,   0)
local ARROW_PRESS   = UDim2.new(0.09,  0, 0.4,   0)
local ARROW_TWEEN   = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
local ARROW_CLICK_ID = "rbxassetid://6895079853"

local function setupArrowButton(btn)
	local hovering = false
	local clickEnabled = true

	local clickSound = Instance.new("Sound")
	clickSound.SoundId = ARROW_CLICK_ID
	clickSound.Volume = 5
	clickSound.Parent = btn

	btn.MouseEnter:Connect(function()
		hovering = true
		ts:Create(btn, ARROW_TWEEN, {Size = ARROW_HOVER}):Play()
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		ts:Create(btn, ARROW_TWEEN, {Size = ARROW_NORMAL}):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		if clickEnabled then
			clickEnabled = false
			ts:Create(btn, ARROW_TWEEN, {Size = ARROW_PRESS}):Play()
			clickSound:Play()
			task.delay(0.5, function() clickEnabled = true end)
		end
	end)
	btn.MouseButton1Up:Connect(function()
		ts:Create(btn, ARROW_TWEEN, {Size = hovering and ARROW_HOVER or ARROW_NORMAL}):Play()
	end)
end

setupArrowButton(leftButton)
setupArrowButton(rightButton)

rightButton.MouseButton1Click:Connect(function()
	if inputEnabled then
		inputEnabled = false
		local currentRodKeys = isVoidShop and voidRodKeys or rodKeys
		target = target % #currentRodKeys + 1
		updateView()
		task.wait(0.5)
		inputEnabled = true
	end
end)

leftButton.MouseButton1Click:Connect(function()
	if inputEnabled then
		inputEnabled = false
		local currentRodKeys = isVoidShop and voidRodKeys or rodKeys
		target = (target - 2) % #currentRodKeys + 1
		updateView()
		task.wait(0.5)
		inputEnabled = true
	end
end)

buyButton.MouseButton1Click:Connect(function()
	if not canBuy then return end
	canBuy = false

	local currentRodKeys = isVoidShop and voidRodKeys or rodKeys
	local rodName = currentRodKeys[target]
	local rodData = RodData.Rods[rodName]
	local leaderstats = player:FindFirstChild("leaderstats")
	local currentRod = leaderstats and leaderstats:FindFirstChild("CurrentRod")

	if rodName == "VoidRod" then
		if not hasCompletedVoidQuest() then
			errorSound:Play()
			showNoticeEvent:Fire("Complete the Void Quest first!")
			canBuy = true
			return
		end
	end

	if rodName == "RobuxRod" then
		if hasGamepass(ROBUX_ROD_GAMEPASS_ID) then
			if currentRod and currentRod.Value ~= rodName then
				if buyBtnLabel then buyBtnLabel.Text = "Equipped" end
				buyRemote:FireServer(rodName)
				equipSound:Play()
				showNoticeEvent:Fire(rodName .. " equipped.")
			else
				if buyBtnLabel then buyBtnLabel.Text = "Equipped" end
				errorSound:Play()
				showNoticeEvent:Fire("Already equipped.")
			end
		else
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(player, ROBUX_ROD_GAMEPASS_ID)
			end)
		end
		canBuy = true
		return
	end

	if hasRod(rodName) then
		local storageName = (rodData and rodData.storageName) or rodName
		if currentRod and currentRod.Value ~= storageName then
			if buyBtnLabel then buyBtnLabel.Text = "Equipped" end
			buyRemote:FireServer(rodName)
			equipSound:Play()
			showNoticeEvent:Fire(rodName .. " equipped.")
		else
			if buyBtnLabel then buyBtnLabel.Text = "Equipped" end
			errorSound:Play()
			showNoticeEvent:Fire("Already equipped.")
		end
		canBuy = true
		return
	end

	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins and coins.Value >= rodData.price then
		buySound:Play()
		buyRemote:FireServer(rodName)
		if buyBtnLabel then buyBtnLabel.Text = "Equipped" end
	else
		errorSound:Play()
		showNoticeEvent:Fire("Not enough coins!")
	end

	task.wait(0.5)
	canBuy = true
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if player == game.Players.LocalPlayer and gamePassId == ROBUX_ROD_GAMEPASS_ID then
		if wasPurchased then
			local currentRodKeys = isVoidShop and voidRodKeys or rodKeys
			local currentRodName = currentRodKeys[target]
			if currentRodName == "RobuxRod" then
				task.wait(1)
				buyRemote:FireServer("RobuxRod")
				updateView(true)
				equipSound:Play()
				showNoticeEvent:Fire("RobuxRod equipped.")
			end
		end
	end
end)

exitButton.MouseButton1Click:Connect(closeShop)
