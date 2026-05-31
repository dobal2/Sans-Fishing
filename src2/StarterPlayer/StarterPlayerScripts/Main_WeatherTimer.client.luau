local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local main = player.PlayerGui:WaitForChild("Main")
local timerLabel = main:WaitForChild("WeatherTimer")
local abilityLabel = main:FindFirstChild("WeatherAbility")

local weatherChangedEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Weather"):WaitForChild("WeatherChangedEvent")
local getWeatherState = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Weather"):WaitForChild("GetWeatherState")

-- UTC schedule constants (must match WeatherSystemModule)
local CYCLE_SECONDS   = 900  -- 15분 사이클 (5분 날씨 + 10분 Clear)
local WEATHER_SECONDS = 300  -- 5분 활성

local WEATHER_NAMES = {
	Rain     = "Rain",
	Snow     = "Snow",
	Firework = "Firework",
}

local WEATHER_ABILITY = {
	Rain     = "Size +20%",
	Snow     = "Frozen chance +25%  ·  Value x2",
	Firework = "Festival chance +25%  ·  Value x1.5",
}

local currentWeather = "Clear"

local function formatTime(seconds)
	local s = math.floor(seconds)
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- Calculate remaining/next directly from UTC clock
local function getScheduleRemaining()
	local now       = os.time()
	local offset    = now % CYCLE_SECONDS
	local isActive  = offset < WEATHER_SECONDS
	local remaining = isActive and (WEATHER_SECONDS - offset) or (CYCLE_SECONDS - offset)
	return isActive, remaining
end

-- Sync current weather from server on join
task.spawn(function()
	local ok, info = pcall(function()
		return getWeatherState:InvokeServer()
	end)
	if ok and info then
		currentWeather = info.currentWeather or "Clear"
	end
end)

-- Keep currentWeather updated via event
weatherChangedEvent.OnClientEvent:Connect(function(newWeather)
	currentWeather = newWeather or "Clear"
end)

while true do
	local isActive, remaining = getScheduleRemaining()
	local activeWeather = isActive and currentWeather ~= "Clear" and currentWeather

	if activeWeather then
		timerLabel.Text = (WEATHER_NAMES[activeWeather] or activeWeather) .. " ends in " .. formatTime(remaining)
		if abilityLabel then
			abilityLabel.Text = WEATHER_ABILITY[activeWeather] or ""
			abilityLabel.Visible = abilityLabel.Text ~= ""
		end
	else
		timerLabel.Text = "Next Weather: " .. formatTime(remaining)
		if abilityLabel then
			abilityLabel.Visible = false
		end
	end

	task.wait(1)
end
