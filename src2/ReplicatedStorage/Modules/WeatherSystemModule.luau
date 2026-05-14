local WeatherSystem = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local snowPart = serverStorage:WaitForChild("SnowPart")

-- Security seed to prevent client spoofing
local WEATHER_SECRET_KEY = "WEATHER_" .. math.random(100000, 999999) .. "_" .. tick()
local SERVER_START_TIME = tick()

-- Timing constants (seconds)
local WEATHER_CYCLE_TIME = 600
local WEATHER_DURATION = 300
local COOLDOWN_TIME = WEATHER_CYCLE_TIME - WEATHER_DURATION

local fireworkConnection = nil

-- Weather type definitions
WeatherSystem.WeatherTypes = {
	Clear = { name = "Clear", chance = 0, effects = { sizeMultiplier = 1.0, valueMultiplier = 1.0, namePrefix = "" } },
	Rain = { name = "Rain", chance = 40, effects = { sizeMultiplier = 1.2, valueMultiplier = 1.0, namePrefix = "" } },
	Snow = { name = "Snow", chance = 40, effects = { sizeMultiplier = 1.0, valueMultiplier = 2.0, namePrefix = "Frozen " } },
	Firework = { name = "Firework", chance = 20, effects = { sizeMultiplier = 1.0, valueMultiplier = 1.5, namePrefix = "Festival " } }
}

-- Server-authoritative weather state
local SecureWeatherState = {
	currentWeather = "Clear",
	lastWeatherStart = 0,
	nextWeatherTime = SERVER_START_TIME + WEATHER_CYCLE_TIME,
	isWeatherActive = false,
	weatherEndTime = 0,
	cycleCount = 0
}

-- Signal all clients to play a firework burst
local function createFireworkEffect()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local weatherFolder = remotes and remotes:FindFirstChild("Weather")
	local fireworkEvent = weatherFolder and weatherFolder:FindFirstChild("FireworkEffectEvent")
	if fireworkEvent then
		fireworkEvent:FireAllClients()
	end
end

-- Start/stop the periodic firework signal loop
local function startFireworkEffects()
	if fireworkConnection then
		task.cancel(fireworkConnection)
	end

	fireworkConnection = task.spawn(function()
		while SecureWeatherState.currentWeather == "Firework" and SecureWeatherState.isWeatherActive do
			createFireworkEffect()
			task.wait(3)
		end
	end)
end

local function stopFireworkEffects()
	if fireworkConnection then
		task.cancel(fireworkConnection)
		fireworkConnection = nil
	end
end

-- Add/remove the SnowPart in workspace based on current weather
local function updateSnowPartState(weatherName)
	local existing = workspace:FindFirstChild("SnowPart")
	if weatherName == "Snow" then
		if not existing then
			local clone = snowPart:Clone()
			clone.Name = "SnowPart"
			clone.Anchored = true
			clone.CanCollide = false
			clone.Position = Vector3.new(0, 50, 0)
			clone.Parent = workspace
		end
	else
		if existing then
			existing:Destroy()
		end
	end
end

local function validateServerTime()
	local uptime = tick() - SERVER_START_TIME
	if uptime < 0 or uptime > 86400 * 7 then
		warn("Suspicious server time detected")
		return false
	end
	return true
end

local function validateWeatherState()
	local now = tick()
	if SecureWeatherState.isWeatherActive and now > SecureWeatherState.weatherEndTime then
		-- 🎆 폭죽 효과 중지
		if SecureWeatherState.currentWeather == "Firework" then
			stopFireworkEffects()
		end

		SecureWeatherState.isWeatherActive = false
		SecureWeatherState.currentWeather = "Clear"
		SecureWeatherState.nextWeatherTime = now + COOLDOWN_TIME
		if WeatherSystem.WeatherChanged then
			WeatherSystem.WeatherChanged:Fire("Clear")
		end
		return false
	end
	return SecureWeatherState.isWeatherActive
end

-- Returns true between 18:00 and 06:00 game time (firework weather window)
local function isNightTime()
	local timeOfDay = Lighting.TimeOfDay
	local hours, minutes, seconds = timeOfDay:match("(%d+):(%d+):(%d+)")
	local totalHours = tonumber(hours) + tonumber(minutes) / 60 + tonumber(seconds) / 3600
	return totalHours >= 18 or totalHours < 6
end

local function selectSecureRandomWeather()
	local seed = (tick() * 1000) + SecureWeatherState.cycleCount + string.len(WEATHER_SECRET_KEY)
	local rng = Random.new(seed)

	-- Firework only at night; skip it during the day
	local options = {}
	local total = 0
	for _, weather in pairs(WeatherSystem.WeatherTypes) do
		if weather.chance > 0 and not (weather.name == "Firework" and not isNightTime()) then
			table.insert(options, weather)
			total = total + weather.chance
		end
	end

	if #options == 0 then
		return "Rain"
	end

	local target = rng:NextNumber(0, total)
	local sum = 0
	for _, weather in ipairs(options) do
		sum = sum + weather.chance
		if target <= sum then
			return weather.name
		end
	end

	return "Rain"
end

function WeatherSystem.UpdateWeatherCycle()
	if not validateServerTime() then return end
	local now = tick()
	validateWeatherState()

	-- At night with no active weather: immediately start Firework
	if isNightTime() and not SecureWeatherState.isWeatherActive then
		local newWeather = "Firework"
		SecureWeatherState.currentWeather = newWeather
		SecureWeatherState.lastWeatherStart = now
		SecureWeatherState.weatherEndTime = now + WEATHER_DURATION
		SecureWeatherState.isWeatherActive = true
		SecureWeatherState.cycleCount += 1
		SecureWeatherState.nextWeatherTime = now + WEATHER_DURATION + COOLDOWN_TIME

		startFireworkEffects()

		if WeatherSystem.WeatherChanged then
			WeatherSystem.WeatherChanged:Fire(newWeather)
		end
		return
	end

	-- During the day: end any active Firework weather immediately
	if not isNightTime() and SecureWeatherState.currentWeather == "Firework" and SecureWeatherState.isWeatherActive then
		stopFireworkEffects()
		SecureWeatherState.isWeatherActive = false
		SecureWeatherState.currentWeather = "Clear"
		SecureWeatherState.nextWeatherTime = now + COOLDOWN_TIME
		if WeatherSystem.WeatherChanged then
			WeatherSystem.WeatherChanged:Fire("Clear")
		end
		return
	end

	-- Daytime weather cycle
	if not isNightTime() and now >= SecureWeatherState.nextWeatherTime and not SecureWeatherState.isWeatherActive then
		local newWeather = selectSecureRandomWeather()
		SecureWeatherState.currentWeather = newWeather
		SecureWeatherState.lastWeatherStart = now
		SecureWeatherState.weatherEndTime = now + WEATHER_DURATION
		SecureWeatherState.isWeatherActive = true
		SecureWeatherState.cycleCount += 1
		SecureWeatherState.nextWeatherTime = now + WEATHER_DURATION + COOLDOWN_TIME

		if newWeather == "Firework" then
			startFireworkEffects()
		end

		if WeatherSystem.WeatherChanged then
			WeatherSystem.WeatherChanged:Fire(newWeather)
		end
	end
end

function WeatherSystem.GetCurrentWeatherEffects()
	validateWeatherState()
	local t = WeatherSystem.WeatherTypes[SecureWeatherState.currentWeather]
	return SecureWeatherState.isWeatherActive and t and t.effects or WeatherSystem.WeatherTypes.Clear.effects
end

function WeatherSystem.GetSecureWeatherInfo()
	validateWeatherState()
	local now = tick()
	return {
		currentWeather = SecureWeatherState.currentWeather,
		isActive = SecureWeatherState.isWeatherActive,
		remainingTime = SecureWeatherState.isWeatherActive and math.max(0, SecureWeatherState.weatherEndTime - now) or 0,
		nextWeatherIn = math.max(0, SecureWeatherState.nextWeatherTime - now),
		cycleCount = SecureWeatherState.cycleCount,
		effects = WeatherSystem.GetCurrentWeatherEffects()
	}
end

function WeatherSystem.ApplySecureWeatherEffects(fishInfo)
	if not fishInfo then return end
	local effects = WeatherSystem.GetCurrentWeatherEffects()
	local info = WeatherSystem.GetSecureWeatherInfo()
	if not info.isActive then return fishInfo end

	local ow, ov, on = fishInfo.weight, fishInfo.value, fishInfo.fishName
	if effects.sizeMultiplier ~= 1.0 then
		fishInfo.weight = math.floor(ow * effects.sizeMultiplier * 10 + 0.5) / 10
	end
	if effects.valueMultiplier ~= 1.0 then
		fishInfo.value = math.floor(ov * effects.valueMultiplier)
	end
	if effects.namePrefix ~= "" then
		fishInfo.fishName = effects.namePrefix .. on
	end

	fishInfo.appliedWeather = info.currentWeather
	fishInfo.weatherCycle = info.cycleCount
	return fishInfo
end

function WeatherSystem.GetCurrentWeatherInfo()
	return WeatherSystem.GetSecureWeatherInfo()
end
function WeatherSystem.ApplyWeatherEffects(fishInfo)
	return WeatherSystem.ApplySecureWeatherEffects(fishInfo)
end

function WeatherSystem.SetWeather(name, duration)
	local w = WeatherSystem.WeatherTypes[name]
	if not w then return false end

	-- 🎆 이전 폭죽 효과 중지
	if SecureWeatherState.currentWeather == "Firework" then
		stopFireworkEffects()
	end

	local now = tick()
	SecureWeatherState.currentWeather = name
	SecureWeatherState.lastWeatherStart = now
	SecureWeatherState.weatherEndTime = now + (duration or WEATHER_DURATION)
	SecureWeatherState.isWeatherActive = (name ~= "Clear")
	SecureWeatherState.nextWeatherTime = SecureWeatherState.weatherEndTime + COOLDOWN_TIME

	-- 🎆 폭죽 날씨면 효과 시작
	if name == "Firework" and SecureWeatherState.isWeatherActive then
		startFireworkEffects()
	end

	if WeatherSystem.WeatherChanged then
		WeatherSystem.WeatherChanged:Fire(name)
	end
	return true
end

function WeatherSystem.Initialize()
	if not WeatherSystem.WeatherChanged then
		WeatherSystem.WeatherChanged = Instance.new("BindableEvent")
	end

	local weatherRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Weather")
	local weatherChangedEvent = weatherRemotes:WaitForChild("WeatherChangedEvent")
	local fireworkEffectEvent = weatherRemotes:WaitForChild("FireworkEffectEvent")

	WeatherSystem.WeatherChanged.Event:Connect(function(newWeather)
		updateSnowPartState(newWeather)

		if newWeather ~= "Firework" then
			stopFireworkEffects()
		end

		for _, player in pairs(Players:GetPlayers()) do
			weatherChangedEvent:FireClient(player, newWeather)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.wait(2)
		local info = WeatherSystem.GetSecureWeatherInfo()
		updateSnowPartState(info.currentWeather)
		weatherChangedEvent:FireClient(player, info.currentWeather)
	end)

	SecureWeatherState.nextWeatherTime = SERVER_START_TIME + WEATHER_CYCLE_TIME

	-- Poll weather cycle every 5 seconds for fast day/night detection
	task.spawn(function()
		while true do
			task.wait(5)
			WeatherSystem.UpdateWeatherCycle()
		end
	end)
end

function WeatherSystem.GetInternalState()
	warn("Internal state access blocked")
	return nil
end

return WeatherSystem
