local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local serverBoostRemote = ReplicatedStorage:WaitForChild("ServerBoostRemote")
local getBoostStateRF   = ReplicatedStorage:WaitForChild("GetBoostState")

local scroll = player.PlayerGui:WaitForChild("RobuxShop")
	:WaitForChild("Shop")
	:WaitForChild("Main")
	:WaitForChild("ScrollingFrame")

local sb = scroll:WaitForChild("ServerBoost")

local labelCurrent = sb:WaitForChild("Current")
local labelNext    = sb:WaitForChild("Next")
local labelTimer   = sb:WaitForChild("Timer")
local labelMax     = sb:WaitForChild("Max")
local buyFrame     = sb:WaitForChild("Buy")
local buyButton    = buyFrame:WaitForChild("TextButton")
local buyLabel     = buyFrame:WaitForChild("TextLabel")

-- STEP_PRICE mirrors ServerBoostManager
local STEP_PRICE = { [1] = 49, [2] = 99, [3] = 199, [4] = 299 }
local STEP_PRODUCTS = { [1] = 3591613623, [2] = 3591613620, [3] = 3591613622, [4] = 3591613619 }
local MAX_MULT = 8

local function formatTime(seconds)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%02d:%02d left", m, s)
end

local function updateUI(mult, nextMult, remaining, nextPrice, atMax, buyStep)
	labelCurrent.Text = mult .. "x"
	labelNext.Text    = nextMult .. "x"
	labelMax.Text     = mult .. "x" .. (atMax and " (max)" or "")
	labelTimer.Text   = remaining > 0 and formatTime(remaining) or "Inactive"

	if atMax then
		buyLabel.Text          = "MAX"
		buyButton.Active       = false
		buyButton.AutoButtonColor = false
	else
		local price = STEP_PRICE[buyStep] or nextPrice
		buyLabel.Text          = tostring(price)
		buyButton.Active       = true
		buyButton.AutoButtonColor = true
	end
end

-- 초기 상태
task.spawn(function()
	local ok, mult, nextMult, remaining, nextPrice, atMax, buyStep = pcall(function()
		return getBoostStateRF:InvokeServer()
	end)
	if ok then
		updateUI(mult, nextMult, remaining, nextPrice, atMax, buyStep)
	end
end)

-- 서버 업데이트 수신
serverBoostRemote.OnClientEvent:Connect(function(_, mult, nextMult, remaining, nextPrice, atMax, buyStep)
	updateUI(mult, nextMult, remaining, nextPrice, atMax, buyStep)
end)

-- 구매 버튼
buyButton.MouseButton1Click:Connect(function()
	local ok, mult, nextMult, remaining, nextPrice, atMax, buyStep = pcall(function()
		return getBoostStateRF:InvokeServer()
	end)
	if not ok or atMax then return end
	local productId = STEP_PRODUCTS[buyStep]
	if productId then
		MarketplaceService:PromptProductPurchase(player, productId)
	end
end)
