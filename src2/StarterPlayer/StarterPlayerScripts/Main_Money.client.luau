local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local leaderstats = player:WaitForChild("leaderstats")
local coins = leaderstats:WaitForChild("Coins")
local textLabel = player.PlayerGui:WaitForChild("Main"):WaitForChild("CoinText")
local buySound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Buy SFX")
local sellSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Success")

local currentDisplayValue = coins.Value
local targetValue = coins.Value
local currentTween = nil
local renderConnection = nil
local previousValue = coins.Value
local canPlayCoinSound = false

local NUMBER_SUFFIXES = {
	{1e63, "Vg"}, {1e60, "Nod"}, {1e57, "Ocd"}, {1e54, "Spd"}, {1e51, "Sxd"},
	{1e48, "Qid"}, {1e45, "Qad"}, {1e42, "Td"}, {1e39, "Dd"}, {1e36, "Ud"},
	{1e33, "Dc"}, {1e30, "No"}, {1e27, "Oc"}, {1e24, "Sp"}, {1e21, "Sx"},
	{1e18, "Qi"}, {1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"},
}

-- 유효숫자 3자리 + 단위 포맷 (단위 붙은 후 소수점 3자리)
local function formatNumber(n)
	n = math.floor(n)
	for _, unit in ipairs(NUMBER_SUFFIXES) do
		if n >= unit[1] then
			return string.format("%.3f%s", n / unit[1], unit[2])
		end
	end
	return tostring(n)
end

local function animateToValue(newValue)
	if currentTween then currentTween:Cancel(); currentTween = nil end
	if renderConnection then renderConnection:Disconnect(); renderConnection = nil end

	targetValue = newValue
	local startValue = currentDisplayValue
	local difference = targetValue - startValue

	if math.abs(difference) < 1 then
		currentDisplayValue = targetValue
		textLabel.Text = formatNumber(targetValue)
		return
	end

	local duration = math.min(1.5, 0.5 + math.abs(difference) / 10000)
	local valueObject = Instance.new("NumberValue")
	valueObject.Value = startValue

	currentTween = TweenService:Create(valueObject, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Value = targetValue})

	renderConnection = RunService.RenderStepped:Connect(function()
		currentDisplayValue = valueObject.Value
		textLabel.Text = formatNumber(currentDisplayValue)
	end)

	currentTween.Completed:Connect(function()
		if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
		currentDisplayValue = targetValue
		textLabel.Text = formatNumber(targetValue)
		currentTween = nil
		valueObject:Destroy()
	end)

	currentTween:Play()
end

coins.Changed:Connect(function(newValue)
	if newValue ~= targetValue then
		if not canPlayCoinSound then
			previousValue = newValue
			currentDisplayValue = newValue
			targetValue = newValue
			textLabel.Text = formatNumber(newValue)
			return
		end

		if newValue > previousValue then
			sellSound:Play()
		elseif newValue < previousValue then
			buySound:Play()
		end
		previousValue = newValue
		animateToValue(newValue)
	end
end)

textLabel.Text = formatNumber(coins.Value)

task.spawn(function()
	local dataReady = player:WaitForChild("DataReady", 30)
	if dataReady then
		repeat task.wait() until dataReady.Value == true
	end

	previousValue = coins.Value
	currentDisplayValue = coins.Value
	targetValue = coins.Value
	textLabel.Text = formatNumber(coins.Value)
	canPlayCoinSound = true
end)
