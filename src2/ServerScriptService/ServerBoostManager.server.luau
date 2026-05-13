local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BOOST_STEPS = {1, 2, 4, 6, 8}
local BOOST_DURATION = 15 * 60

local STEP_PRODUCTS = {
	[1] = 3591613623,
	[2] = 3591613620,
	[3] = 3591613622,
	[4] = 3591613619,
}
local PRODUCT_TO_STEP = {}
for step, pid in pairs(STEP_PRODUCTS) do PRODUCT_TO_STEP[pid] = step end

local STEP_PRICE = {
	[1] = 49,
	[2] = 99,
	[3] = 199,
	[4] = 299,
}

local boostStep    = 1
local boostExpires = 0

local function getCurrentMult()
	if os.clock() < boostExpires then
		return BOOST_STEPS[boostStep] or 1
	end
	return 1
end

local function getNextStep()
	if os.clock() < boostExpires then
		return math.min(boostStep + 1, #BOOST_STEPS)
	end
	return 2
end

local boostRemote = Instance.new("RemoteEvent")
boostRemote.Name  = "ServerBoostRemote"
boostRemote.Parent = ReplicatedStorage

local function buildState()
	local mult      = getCurrentMult()
	local nextIdx   = getNextStep()
	local nextMult  = BOOST_STEPS[nextIdx] or mult
	local remaining = math.max(0, math.floor(boostExpires - os.clock()))
	local buyStep   = nextIdx - 1  -- STEP_PRODUCTS index to buy next
	local nextPrice = STEP_PRICE[buyStep] or STEP_PRICE[#STEP_PRICE]
	local atMax     = (mult >= BOOST_STEPS[#BOOST_STEPS])
	return mult, nextMult, remaining, nextPrice, atMax, buyStep
end

local getBoostStateRF = Instance.new("RemoteFunction")
getBoostStateRF.Name = "GetBoostState"
getBoostStateRF.OnServerInvoke = function()
	return buildState()
end
getBoostStateRF.Parent = ReplicatedStorage

local function broadcastState()
	boostRemote:FireAllClients("update", buildState())
end

local boostApiFolder = Instance.new("Folder")
boostApiFolder.Name = "ServerBoostAPI"
boostApiFolder.Parent = script

local getMultBF = Instance.new("BindableFunction")
getMultBF.Name = "GetBoostMult"
getMultBF.OnInvoke = function() return getCurrentMult() end
getMultBF.Parent = boostApiFolder

local function applyBoost(step)
	local wasActive = os.clock() < boostExpires
	boostStep = math.min(step + 1, #BOOST_STEPS)
	if wasActive then
		boostExpires = boostExpires + BOOST_DURATION
	else
		boostExpires = os.clock() + BOOST_DURATION
	end
	broadcastState()

	local mult = BOOST_STEPS[boostStep] or 1
	local showNoticeEvent = ReplicatedStorage:FindFirstChild("ShowNoticeEvent")
	if showNoticeEvent then
		showNoticeEvent:FireAllClients("Server Luck boosted to " .. mult .. "x!", false)
	end
end

local boostPurchaseBE = Instance.new("BindableEvent")
boostPurchaseBE.Name = "BoostPurchased"
boostPurchaseBE.Parent = boostApiFolder

boostPurchaseBE.Event:Connect(function(productId)
	local step = PRODUCT_TO_STEP[productId]
	if not step then return end
	local expectedStep = (os.clock() < boostExpires) and boostStep or 1
	if step == expectedStep then
		applyBoost(step)
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.wait(2)
	boostRemote:FireClient(player, "update", buildState())
end)

task.spawn(function()
	while true do
		task.wait(1)
		if os.clock() < boostExpires then
			broadcastState()
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(5)
		if boostStep > 1 and os.clock() >= boostExpires then
			boostStep = 1
			broadcastState()
		end
	end
end)
