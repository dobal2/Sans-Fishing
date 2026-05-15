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

local ROBUX_ICON = "\u{E002}"  -- Roblox 로벅스 아이콘

-- 초기 기본값 표시 (서버 응답 전)
buyLabel.Text = ROBUX_ICON .. "99"

-- STEP_PRICE mirrors ServerBoostManager
local STEP_PRICE = { [1] = 99, [2] = 199, [3] = 299, [4] = 499 }
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
		buyLabel.Text             = "MAX"
		buyButton.Active          = false
		buyButton.AutoButtonColor = false
	else
		local price = STEP_PRICE[buyStep] or nextPrice
		buyLabel.Text             = ROBUX_ICON .. tostring(price)
		buyButton.Active          = true
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

-- 구매 완료 후 서버에서 새 상태 가져와 버튼 가격 갱신
MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, productId, purchased)
	if not purchased then return end
	local isBoostProduct = false
	for _, pid in pairs(STEP_PRODUCTS) do
		if pid == productId then isBoostProduct = true; break end
	end
	if not isBoostProduct then return end

	task.wait(1)
	local ok, mult, nextMult, remaining, nextPrice, atMax, buyStep = pcall(function()
		return getBoostStateRF:InvokeServer()
	end)
	if ok then
		updateUI(mult, nextMult, remaining, nextPrice, atMax, buyStep)
	end
end)
