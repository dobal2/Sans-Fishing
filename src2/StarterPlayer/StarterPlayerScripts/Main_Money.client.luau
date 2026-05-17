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

-- 유효숫자 3자리 + 단위 포맷 (단위 붙은 후 소수점 3자리)
local function formatNumber(n)
	n = math.floor(n)
	if n >= 1000000000 then
		return string.format("%.3fB", n / 1000000000)
	elseif n >= 1000000 then
		return string.format("%.3fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.3fK", n / 1000)
	else
		return tostring(n)
	end
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
