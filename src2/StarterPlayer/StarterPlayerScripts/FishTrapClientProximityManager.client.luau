local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local shopRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop")
local openFishTrapShop = shopRemotes:WaitForChild("OpenFishTrapShop")
local buyFishTrapRemote = shopRemotes:WaitForChild("BuyFishTrapRemote")
local buySound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Buy SFX")

-- Robux Fish Trap gamepass ID
local ROBUX_FISHTRAP_GAMEPASS_ID = 1423175879
local CLOSED_SCALE = 0.55
local OPEN_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local FISH_TRAP_DATA = {
	BasicFishTrap = {
		displayName = "Basic Fish Trap",
		price = 30000,
		desc = "Capacity: 20 fish  |  Luck +10%  |  Catch Time: 10 min",
	},
	AdvancedFishTrap = {
		displayName = "Advanced Fish Trap",
		price = 200000,
		desc = "Capacity: 30 fish  |  Luck +35%  |  Catch Time: 8 min",
	},
	MasterFishTrap = {
		displayName = "Master Fish Trap",
		price = 600000,
		desc = "Capacity: 40 fish  |  Luck +75%  |  Catch Time: 6 min",
	},
	RobuxFishTrap = {
		displayName = "Robux Fish Trap",
		price = 0,
		desc = "Capacity: 60 fish  |  Luck +150%  |  Catch Time: 5 min",
	},
}

local FISH_TRAP_OBJECT_TEXT = {
	BasicFishTrap = "Basic Fish Trap",
	AdvancedFishTrap = "Advanced Fish Trap",
	MasterFishTrap = "Master Fish Trap",
	RobuxFishTrap = "Robux Fish Trap",
}

local mainGui = playerGui:WaitForChild("Main")
local fishTrapFrame = mainGui:WaitForChild("FishTrap")
local fishTrapScale = fishTrapFrame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
fishTrapScale.Name = "OpenScale"
fishTrapScale.Scale = CLOSED_SCALE
fishTrapScale.Parent = fishTrapFrame

local titleLabel = fishTrapFrame:WaitForChild("Title")
local descLabel = fishTrapFrame:WaitForChild("Desc")
local priceLabel = fishTrapFrame:WaitForChild("Price")
local equipFrame = fishTrapFrame:WaitForChild("Equip")
local buyBtn = equipFrame:WaitForChild("TextButton")
local buyLabel = equipFrame:WaitForChild("TextLabel")
local onGradient = buyBtn:FindFirstChild("OnGradient")
local offGradient = buyBtn:FindFirstChild("OffGradient")
local closeFrame = fishTrapFrame:WaitForChild("Close")
local closeBtn = closeFrame:WaitForChild("TextButton")

local currentFishTrapName = nil
local isBuying = false
local cachedRobuxFishTrapOwned = nil
local frameTween = nil
local closeToken = 0

-- Check gamepass ownership
local function hasGamepass(player, gamepassId)
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	return success and result
end

task.spawn(function()
	cachedRobuxFishTrapOwned = hasGamepass(player, ROBUX_FISHTRAP_GAMEPASS_ID)
end)

local NUMBER_SUFFIXES = {
	{1e63, "Vg"}, {1e60, "Nod"}, {1e57, "Ocd"}, {1e54, "Spd"}, {1e51, "Sxd"},
	{1e48, "Qid"}, {1e45, "Qad"}, {1e42, "Td"}, {1e39, "Dd"}, {1e36, "Ud"},
	{1e33, "Dc"}, {1e30, "No"}, {1e27, "Oc"}, {1e24, "Sp"}, {1e21, "Sx"},
	{1e18, "Qi"}, {1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"},
}

local function formatCoins(n)
	n = math.floor(tonumber(n) or 0)
	for _, unit in ipairs(NUMBER_SUFFIXES) do
		if n >= unit[1] then return string.format("%.2f%s", n / unit[1], unit[2]) end
	end
	local s = tostring(math.floor(n))
	local result = ""
	local len = #s
	for i = 1, len do
		if i > 1 and (len - i + 1) % 3 == 0 then result = result .. "," end
		result = result .. s:sub(i, i)
	end
	return result
end

local function getCoins()
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	return coins and coins.Value or 0
end

local function getFishTrapState(fishTrapName)
	local leaderstats = player:FindFirstChild("leaderstats")
	local fishTrapsFolder = leaderstats and leaderstats:FindFirstChild("FishTraps")
	local currentFishTrap = leaderstats and leaderstats:FindFirstChild("CurrentFishTrap")
	local currentFishTrapValue = currentFishTrap and currentFishTrap:FindFirstChild("Value")
	local fishTrapBool = fishTrapsFolder and fishTrapsFolder:FindFirstChild(fishTrapName)
	local owned = fishTrapBool and fishTrapBool.Value == true

	if fishTrapName == "RobuxFishTrap" and cachedRobuxFishTrapOwned then
		owned = true
	end

	return owned, currentFishTrapValue and currentFishTrapValue.Value == fishTrapName
end

local function setButtonState(active, label, enabledGradient)
	buyBtn.Active = active
	buyBtn.AutoButtonColor = active
	buyLabel.Text = label
	if onGradient then onGradient.Enabled = enabledGradient end
	if offGradient then offGradient.Enabled = not enabledGradient end
end

local function updateBuyButton()
	if not currentFishTrapName then return end

	local data = FISH_TRAP_DATA[currentFishTrapName]
	if not data then return end

	local owned, equipped = getFishTrapState(currentFishTrapName)
	if equipped then
		setButtonState(false, "Equipped", false)
		return
	end

	if owned then
		setButtonState(true, "Equip", true)
		return
	end

	if currentFishTrapName == "RobuxFishTrap" then
		setButtonState(true, "Buy (Robux)", true)
		return
	end

	local canAfford = getCoins() >= data.price
	setButtonState(canAfford, canAfford and "Buy" or "Not Enough Coins", canAfford)
end

local function closeFrame_()
	closeToken += 1
	local token = closeToken
	if frameTween then frameTween:Cancel() end
	frameTween = TweenService:Create(fishTrapScale, CLOSE_TWEEN, {Scale = CLOSED_SCALE})
	frameTween:Play()
	frameTween.Completed:Once(function()
		if token ~= closeToken then return end
		fishTrapFrame.Visible = false
	end)
	currentFishTrapName = nil
	isBuying = false
end

local function showFrame()
	closeToken += 1
	if frameTween then frameTween:Cancel() end
	fishTrapScale.Scale = CLOSED_SCALE
	fishTrapFrame.Visible = true
	frameTween = TweenService:Create(fishTrapScale, OPEN_TWEEN, {Scale = 1})
	frameTween:Play()
end

local function openFrame(fishTrapName)
	local data = FISH_TRAP_DATA[fishTrapName]
	if not data then return end

	currentFishTrapName = fishTrapName
	titleLabel.Text = data.displayName
	descLabel.Text = data.desc

	local owned = getFishTrapState(fishTrapName)
	if fishTrapName == "RobuxFishTrap" then
		if owned then
			priceLabel.Text = "Already Owned"
		else
			priceLabel.Text = "\u{E002} ..."
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(ROBUX_FISHTRAP_GAMEPASS_ID, Enum.InfoType.GamePass)
				end)
				if currentFishTrapName ~= "RobuxFishTrap" then return end
				if ok and info and info.PriceInRobux then
					priceLabel.Text = "\u{E002} " .. info.PriceInRobux
				else
					priceLabel.Text = "\u{E002} Robux"
				end
			end)
		end
	else
		priceLabel.Text = formatCoins(data.price) .. " Coins"
	end

	updateBuyButton()
	showFrame()
end

local function waitForPrompt(modelName)
	local model = workspace:WaitForChild(modelName)
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	while not prompt do
		model.DescendantAdded:Wait()
		prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	end
	return prompt
end

-- Find ProximityPrompts
local basicProximity = waitForPrompt("Basic FishtrapMainModel")
local advancedProximity = waitForPrompt("T2 FishtrapMainModel")
local masterProximity = waitForPrompt("T3 FishtrapMainModel")
local robuxProximity = waitForPrompt("Robux FishtrapMainModel")

-- Fish Trap mapping (ProximityPrompt -> Fish Trap name)
local proximityToFishTrap = {
	[basicProximity] = "BasicFishTrap",
	[advancedProximity] = "AdvancedFishTrap",
	[masterProximity] = "MasterFishTrap",
	[robuxProximity] = "RobuxFishTrap"
}

-- Update ActionText for a ProximityPrompt
local function updateProximityText(proximity, fishTrapName)
	proximity.ActionText = "View"
	proximity.HoldDuration = 0
	proximity.ObjectText = FISH_TRAP_OBJECT_TEXT[fishTrapName] or "Fish Trap"
end

-- Update all ProximityPrompts
local function updateAllProximityTexts()
	for proximity, fishTrapName in pairs(proximityToFishTrap) do
		updateProximityText(proximity, fishTrapName)
	end
end

-- Wait for leaderstats to load
local function waitForLeaderstats()
	local leaderstats = player:WaitForChild("leaderstats")
	if not leaderstats then
		warn("leaderstats failed to load")
		return
	end

	local fishTrapsFolder = leaderstats:WaitForChild("FishTraps")
	local currentFishTrap = leaderstats:WaitForChild("CurrentFishTrap")
	if not (fishTrapsFolder and currentFishTrap) then
		warn("FishTraps or CurrentFishTrap failed to load")
		return
	end

	-- Wait for each Fish Trap BoolValue
	local basicBool = fishTrapsFolder:WaitForChild("BasicFishTrap")
	local advancedBool = fishTrapsFolder:WaitForChild("AdvancedFishTrap")
	local masterBool = fishTrapsFolder:WaitForChild("MasterFishTrap")
	local robuxBool = fishTrapsFolder:WaitForChild("RobuxFishTrap")
	local currentValue = currentFishTrap:WaitForChild("Value")

	if not (basicBool and advancedBool and masterBool and robuxBool and currentValue) then
		warn("Fish Trap data failed to load")
		return
	end

	-- Set initial text
	updateAllProximityTexts()

	-- Connect change listeners
	basicBool.Changed:Connect(function()
		updateProximityText(basicProximity, "BasicFishTrap")
	end)

	advancedBool.Changed:Connect(function()
		updateProximityText(advancedProximity, "AdvancedFishTrap")
	end)

	masterBool.Changed:Connect(function()
		updateProximityText(masterProximity, "MasterFishTrap")
	end)

	robuxBool.Changed:Connect(function()
		updateProximityText(robuxProximity, "RobuxFishTrap")
	end)

	currentValue.Changed:Connect(function()
		updateAllProximityTexts() -- Update all texts when equipped fish trap changes
		updateBuyButton()
	end)

	-- Periodically check gamepass status changes
	task.spawn(function()
		local lastGamepassStatus = hasGamepass(player, ROBUX_FISHTRAP_GAMEPASS_ID)
		while true do
			task.wait(5) -- Check every 5 seconds
			local currentGamepassStatus = hasGamepass(player, ROBUX_FISHTRAP_GAMEPASS_ID)
			if currentGamepassStatus ~= lastGamepassStatus then
				updateProximityText(robuxProximity, "RobuxFishTrap")
				lastGamepassStatus = currentGamepassStatus
			end
		end
	end)

end

-- DataReady가 될 때까지 기다린 뒤 초기화 (데이터 복원 전에 텍스트가 깜빡이는 버그 방지)
task.spawn(function()
	player:WaitForChild("DataReady", 60)
	waitForLeaderstats()
end)

openFishTrapShop.OnClientEvent:Connect(function(fishTrapName)
	openFrame(fishTrapName)
end)

buyBtn.MouseButton1Click:Connect(function()
	if not currentFishTrapName then return end
	local data = FISH_TRAP_DATA[currentFishTrapName]
	if not data then return end

	local owned, equipped = getFishTrapState(currentFishTrapName)
	if equipped then return end
	if isBuying then return end

	if not owned and currentFishTrapName ~= "RobuxFishTrap" and getCoins() < data.price then
		updateBuyButton()
		return
	end

	isBuying = true
	if not owned and currentFishTrapName ~= "RobuxFishTrap" then
		buySound:Play()
	end
	buyFishTrapRemote:FireServer(currentFishTrapName)
	task.delay(1, function()
		isBuying = false
		updateBuyButton()
	end)
end)

closeBtn.MouseButton1Click:Connect(closeFrame_)

fishTrapFrame.Visible = false
