local player = game.Players.LocalPlayer
local shopGui = player.PlayerGui:WaitForChild("BoatShop")
local shopFrame = shopGui:WaitForChild("BoatFrame")
local shopShadowFrame = shopGui:WaitForChild("ShadowFrame")
local clickSound = shopGui:WaitForChild("click")
local buySound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("Buy SFX")
local errorSound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("error")
local lighting = game:GetService("Lighting")
local blur = lighting:WaitForChild("ShopBlur")
local TweenService = game:GetService("TweenService")
local xButton = shopFrame:WaitForChild("XButton")
local camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("OpenBoatShop")
local buyBoatRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("BuyBoat")
local spawnBoatRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("SpawnBoat")
local boatFrame = shopFrame:WaitForChild("ScrollingFrame"):WaitForChild("BoatFrame")
local boatFrameButton = boatFrame:WaitForChild("Button")
local optionFrame = shopGui:WaitForChild("Options")
local notice = shopGui:WaitForChild("notice")

local yesButton = optionFrame:WaitForChild("Yes")
local noButton = optionFrame:WaitForChild("No")
local optionPrice = optionFrame:WaitForChild("Price")

local BoatData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("BoatDataModule"))

local originalFOV = 70
local expandedFOV = 60
local canClick = true

local currentSelectedBoat = nil

local isNoticeTweening = false

local assignedSpawnIndex = 1

local function formatNumber(num)
	local str = tostring(num)
	local result = ""
	local len = #str

	for i = 1, len do
		local char = str:sub(i, i)
		result = result .. char

		local remainingDigits = len - i
		if remainingDigits > 0 and remainingDigits % 3 == 0 then
			result = result .. ","
		end
	end

	return result
end

local function isShopOpen()
	return shopFrame.Visible
end

local function tweenFOV(targetFOV, duration)
	local tweenInfo = TweenInfo.new(
		duration or 0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	local tween = TweenService:Create(camera, tweenInfo, {
		FieldOfView = targetFOV
	})
	tween:Play()
	return tween
end

local function showInsufficientFundsNotice()
	if isNoticeTweening then
		return
	end

	isNoticeTweening = true
	errorSound:Play()
	notice.Visible = true

	notice.TextTransparency = 1

	local showTween = TweenService:Create(notice,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{TextTransparency = 0}
	)

	showTween:Play()
	showTween.Completed:Connect(function()
		task.wait(2)

		local hideTween = TweenService:Create(notice,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{TextTransparency = 1}
		)

		hideTween:Play()
		hideTween.Completed:Connect(function()
			notice.Visible = false
			isNoticeTweening = false
		end)
	end)
end

local function updatePriceDisplay()
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		warn("leaderstats not found")
		return
	end

	local boats = leaderstats:FindFirstChild("Boats")
	if not boats then
		warn("Boats folder not found")
		return
	end

	local priceText = boatFrame:FindFirstChild("Price")
	if not priceText then
		warn("Price text not found")
		return
	end

	local basicBoat = boats:FindFirstChild("BasicBoat")
	local isOwned = basicBoat and basicBoat.Value

	if isOwned then
		priceText.Text = "Spawn"
		print("Boat owned - showing Spawn")
	else
		local boatData = BoatData.Boats["BasicBoat"]
		if boatData then
			priceText.Text = "[¢ " .. formatNumber(boatData.price) .. "]"
			print("Boat not owned - showing price:", boatData.price)
		else
			priceText.Text = "Error"
			warn("Boat data not found")
		end
	end
end

local function updateOptionPrice(boatName)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		warn("leaderstats not found")
		return
	end

	local boats = leaderstats:FindFirstChild("Boats")
	if not boats then
		warn("Boats folder not found")
		return
	end

	local boatBool = boats:FindFirstChild(boatName)
	local isOwned = boatBool and boatBool.Value

	if isOwned then
		optionPrice.Text = "Spawn"
		print("Option frame - boat owned, showing Spawn")
	else
		local boatData = BoatData.Boats[boatName]
		if boatData then
			optionPrice.Text = "[¢ " .. formatNumber(boatData.price) .. "]"
			print("Option frame - boat not owned, showing price:", boatData.price)
		else
			optionPrice.Text = "Error"
			warn("Boat data not found")
		end
	end
end

local function syncShopState()
	if isShopOpen() then
		shopShadowFrame.Visible = true
	else
		shopShadowFrame.Visible = false
	end
end

local function toggleShop()
	if not canClick then return end
	canClick = false
	clickSound:Play()

	local currentlyOpen = isShopOpen()
	local newState = not currentlyOpen

	shopFrame.Visible = newState
	shopShadowFrame.Visible = newState

	local playerGui = player:WaitForChild("PlayerGui")
	local robuxShop = playerGui:FindFirstChild("RobuxShop")
	local index = playerGui:FindFirstChild("Index")

	if newState then
		blur.Enabled = true
		tweenFOV(expandedFOV, 0.5)
		print("Shop opened - FOV:", expandedFOV)

		if robuxShop then
			local robuxShadowFrame = robuxShop:FindFirstChild("ShadowFrame")
			local robuxShopFrame = robuxShop:FindFirstChild("ShopFrame")
			if robuxShadowFrame then robuxShadowFrame.Visible = false end
			if robuxShopFrame then robuxShopFrame.Visible = false end
		end

		if index then
			local indexShadowFrame = index:FindFirstChild("ShadowFrame")
			local indexFrame = index:FindFirstChild("IndexFrame")
			if indexShadowFrame then indexShadowFrame.Visible = false end
			if indexFrame then indexFrame.Visible = false end
		end

		updatePriceDisplay()
	else
		blur.Enabled = false
		tweenFOV(originalFOV, 0.5)
		print("Shop closed - FOV restored to 70")

		optionFrame.Visible = false
	end

	task.wait(0.5)
	canClick = true
end

local function showOptionFrame(boatName)
	currentSelectedBoat = boatName
	updateOptionPrice(boatName)
	optionFrame.Visible = true
	print("Option frame shown:", boatName)
end

local function hideOptionFrame()
	optionFrame.Visible = false
	currentSelectedBoat = nil
	print("Option frame hidden")
end

local function buyOrSpawnBoat(boatName)
	local boatData = BoatData.Boats[boatName]
	if not boatData then
		warn("Boat does not exist:", boatName)
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("leaderstats not found")
		return
	end

	local boats = leaderstats:FindFirstChild("Boats")
	local coins = leaderstats:FindFirstChild("Coins")

	if not boats or not coins then
		warn("Boats or Coins not found")
		return
	end

	local boatBool = boats:FindFirstChild(boatName)
	local isOwned = boatBool and boatBool.Value

	if isOwned then
		print("Boat spawn request:", boatName, "position:", assignedSpawnIndex)
		spawnBoatRemote:FireServer(boatName, assignedSpawnIndex)
		hideOptionFrame()
		toggleShop()
	else
		if coins.Value < boatData.price then
			warn("Insufficient funds. Required:", boatData.price, "Current:", coins.Value)
			showInsufficientFundsNotice()
			return
		end

		print("Boat purchase request:", boatName, "price:", boatData.price)
		buySound:Play()
		buyBoatRemote:FireServer(boatName)
		hideOptionFrame()
	end
end

boatFrameButton.MouseButton1Click:Connect(function()
	print("Boat frame clicked")

	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		warn("leaderstats not found")
		return
	end

	local boats = leaderstats:FindFirstChild("Boats")
	if not boats then
		warn("Boats folder not found")
		return
	end

	local basicBoat = boats:FindFirstChild("BasicBoat")
	local isOwned = basicBoat and basicBoat.Value

	if isOwned then
		print("Boat spawn request:", "BasicBoat", "position:", assignedSpawnIndex)
		spawnBoatRemote:FireServer("BasicBoat", assignedSpawnIndex)
		toggleShop()
	else
		print("Boat not owned - showing option frame")
		showOptionFrame("BasicBoat")
	end
end)

yesButton:WaitForChild("Button").MouseButton1Click:Connect(function()
	print("Yes button clicked")
	if currentSelectedBoat then
		buyOrSpawnBoat(currentSelectedBoat)
	end
end)

noButton:WaitForChild("Button").MouseButton1Click:Connect(function()
	print("No button clicked")
	hideOptionFrame()
end)

buyBoatRemote.OnClientEvent:Connect(function(success, boatName)
	if success then
		print("Boat purchased:", boatName)
		updatePriceDisplay()
	else
		warn("Boat purchase failed:", boatName)
	end
end)

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		local boats = child:WaitForChild("Boats")
		boats.ChildAdded:Connect(updatePriceDisplay)
		boats.ChildRemoved:Connect(updatePriceDisplay)

		for _, boat in pairs(boats:GetChildren()) do
			if boat:IsA("BoolValue") then
				boat.Changed:Connect(updatePriceDisplay)
			end
		end
	end
end)

if player:FindFirstChild("leaderstats") then
	local boats = player.leaderstats:FindFirstChild("Boats")
	if boats then
		boats.ChildAdded:Connect(updatePriceDisplay)
		boats.ChildRemoved:Connect(updatePriceDisplay)

		for _, boat in pairs(boats:GetChildren()) do
			if boat:IsA("BoolValue") then
				boat.Changed:Connect(updatePriceDisplay)
			end
		end
	end
end

shopFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	print("Shop visibility changed:", shopFrame.Visible)
	syncShopState()
end)

xButton.MouseButton1Click:Connect(function()
	if isShopOpen() then
		toggleShop()
	end
end)

remote.OnClientEvent:Connect(function(spawnIndex)
	if spawnIndex then
		assignedSpawnIndex = spawnIndex
		print("Spawn position assigned:", assignedSpawnIndex)
	end
	toggleShop()
end)

shopFrame.Visible = false
shopShadowFrame.Visible = false
optionFrame.Visible = false
notice.Visible = false
notice.TextTransparency = 1
blur.Enabled = false
print("Boat shop UI initialized")
