local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local timerLabel = player.PlayerGui:WaitForChild("Main"):WaitForChild("WeatherTimer")

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

local function updateTimer()
	local ok, info = pcall(function()
		return getWeatherState:InvokeServer()
	end)
	if not ok or not info then return end

	if info.isActive and info.currentWeather ~= "Clear" then
		local name = WEATHER_NAMES[info.currentWeather] or info.currentWeather
		timerLabel.Text = name .. " ends in " .. formatTime(info.remainingTime)
	else
		timerLabel.Text = "Next Weather: " .. formatTime(info.nextWeatherIn)
	end
end

while true do
	updateTimer()
	task.wait(1)
end
