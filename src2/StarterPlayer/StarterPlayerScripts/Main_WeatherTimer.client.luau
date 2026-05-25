local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local main = player.PlayerGui:WaitForChild("Main")
local timerLabel = main:WaitForChild("WeatherTimer")
local abilityLabel = main:FindFirstChild("WeatherAbility")

local getWeatherState = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Weather"):WaitForChild("GetWeatherState")

local function formatTime(seconds)
	local s = math.floor(seconds)
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local WEATHER_NAMES = {
	Rain     = "Rain",
	Snow     = "Snow",
	Firework = "Firework",
	Clear    = "Clear",
}

local WEATHER_ABILITY = {
	Rain     = "Fish size x1.2",
	Snow     = "Fish value x2  (Frozen fish)",
	Firework = "Fish value x1.5  (Festival fish)",
}

local function updateTimer()
	local ok, info = pcall(function()
		return getWeatherState:InvokeServer()
	end)
	if not ok or not info then return end

	if info.isActive and info.currentWeather ~= "Clear" then
		local name = WEATHER_NAMES[info.currentWeather] or info.currentWeather
		timerLabel.Text = name .. " ends in " .. formatTime(info.remainingTime)
		if abilityLabel then
			abilityLabel.Text = WEATHER_ABILITY[info.currentWeather] or ""
			abilityLabel.Visible = abilityLabel.Text ~= ""
		end
	else
		timerLabel.Text = "Next Weather: " .. formatTime(info.nextWeatherIn)
		if abilityLabel then
			abilityLabel.Visible = false
		end
	end
end

while true do
	updateTimer()
	task.wait(1)
end
