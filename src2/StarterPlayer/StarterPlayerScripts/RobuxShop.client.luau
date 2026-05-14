local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local robuxShopGui = player.PlayerGui:WaitForChild("RobuxShop")
local shopFrame = robuxShopGui:WaitForChild("Shop")
local uiScale   = shopFrame:WaitForChild("UIScale")
local closeBtn  = shopFrame:WaitForChild("Close"):WaitForChild("TextButton")
local blur      = lighting:WaitForChild("ShopBlur")
local camera    = workspace.CurrentCamera

local OPEN_TWEEN  = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.2,  Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FOV_TWEEN   = TweenInfo.new(0.5,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function isOpen()
	return shopFrame.Visible
end

local function openShop()
	shopFrame.Visible = true
	uiScale.Scale = 0
	TweenService:Create(uiScale, OPEN_TWEEN, {Scale = 1}):Play()
	blur.Enabled = true
	TweenService:Create(camera, FOV_TWEEN, {FieldOfView = 60}):Play()
end

local function closeShop()
	TweenService:Create(uiScale, CLOSE_TWEEN, {Scale = 0}):Play()
	task.delay(0.2, function() shopFrame.Visible = false end)
	blur.Enabled = false
	TweenService:Create(camera, FOV_TWEEN, {FieldOfView = 70}):Play()
end

closeBtn.MouseButton1Click:Connect(function()
	if isOpen() then closeShop() end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isOpen() then closeShop() end
end)

local remote = ReplicatedStorage:FindFirstChild("OpenRobuxShop")
if remote then
	remote.OnClientEvent:Connect(function()
		if isOpen() then closeShop() else openShop() end
	end)
end

shopFrame.Visible = false
uiScale.Scale = 0

-- ServerBoost UI
local STEP_PRODUCTS = {
	[1] = 3591613623,
	[2] = 3591613620,
	[3] = 3591613622,
	[4] = 3591613619,
}
local STEP_PRICE = { [1]=49, [2]=99, [3]=199, [4]=299 }
local BOOST_STEPS = {1, 2, 4, 6, 8}

local currentStep = 1
local isAtMax = false

local serverBoost  = shopFrame:FindFirstChild("ServerBoost", true)
local sbCurrent    = serverBoost and serverBoost:FindFirstChild("Current")
local sbNext       = serverBoost and serverBoost:FindFirstChild("Next")
local sbTimer      = serverBoost and serverBoost:FindFirstChild("Timer")
local sbBuyFrame   = serverBoost and serverBoost:FindFirstChild("Buy")
local sbBuyLabel   = sbBuyFrame and sbBuyFrame:FindFirstChild("TextLabel")
local sbBuyBtn     = sbBuyFrame and (sbBuyFrame:FindFirstChildOfClass("ImageButton") or sbBuyFrame:FindFirstChildOfClass("TextButton"))

local function formatTime(secs)
	local m = math.floor(secs / 60)
	local s = secs % 60
	return string.format("%02d:%02d left", m, s)
end

local function updateBoostUI(mult, nextMult, remaining, nextPrice, atMax, buyStep)
	isAtMax = atMax
	if buyStep then currentStep = buyStep end
	if sbCurrent then sbCurrent.Text = mult .. "x" end
	if sbNext then sbNext.Text = (atMax and "8x" or nextMult .. "x") end
	if sbBuyLabel then sbBuyLabel.Text = atMax and "MAX" or ("\xEE\x80\x82" .. tostring(nextPrice)) end
	if sbTimer then
		sbTimer.Visible = remaining > 0
		if remaining > 0 then sbTimer.Text = formatTime(remaining) end
	end
end

if sbBuyBtn then
	sbBuyBtn.Activated:Connect(function()
		if isAtMax then return end
		local pid = STEP_PRODUCTS[currentStep]
		if pid then MarketplaceService:PromptProductPurchase(player, pid) end
	end)
end

task.spawn(function()
	local boostRemote = ReplicatedStorage:WaitForChild("ServerBoostRemote", 15)
	if boostRemote then
		boostRemote.OnClientEvent:Connect(function(action, mult, nextMult, remaining, nextPrice, atMax, buyStep)
			if action == "update" then updateBoostUI(mult, nextMult, remaining, nextPrice, atMax, buyStep) end
		end)
	end

	local getBoostStateRF = ReplicatedStorage:WaitForChild("GetBoostState", 15)
	if getBoostStateRF then
		local mult, nextMult, remaining, nextPrice, atMax, buyStep = getBoostStateRF:InvokeServer()
		updateBoostUI(mult, nextMult, remaining, nextPrice, atMax, buyStep)
	else
		updateBoostUI(1, 2, 0, 49, false, 1)
	end
end)
