local WeatherSystem = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local MessagingService = game:GetService("MessagingService")

-- SnowPart only exists in ServerStorage server-side
local snowPart = RunService:IsServer() and ServerStorage:WaitForChild("SnowPart") or nil

-- Timing: 15-minute cycle, weather on :00-:05, Clear on :05-:15 (UTC)
local CYCLE_SECONDS   = 900  -- 15 minutes
local WEATHER_SECONDS = 300  -- 5 minutes active, 10 minutes clear
local MS_TOPIC        = "WeatherSync_v1"

-- Weather type definitions
WeatherSystem.WeatherTypes = {
	Clear    = { name = "Clear",    chance = 0,  effects = { sizeMultiplier = 1.0, valueMultiplier = 1.0, namePrefix = "",          mutationChance = 0    } },
	Rain     = { name = "Rain",     chance = 40, effects = { sizeMultiplier = 1.2, valueMultiplier = 1.0, namePrefix = "",          mutationChance = 0    } },
	Snow     = { name = "Snow",     chance = 40, effects = { sizeMultiplier = 1.0, valueMultiplier = 2.0, namePrefix = "Frozen ",   mutationChance = 0.25 } },
	Firework = { name = "Firework", chance = 20, effects = { sizeMultiplier = 1.0, valueMultiplier = 1.5, namePrefix = "Festival ", mutationChance = 0.25 } },
}

local state = {
	currentWeather = "Clear",
	isActive       = false,
	cycleIndex     = 0,   -- which UTC cycle slot we last acted on
}

-- ── Helpers ──────────────────────────────────────────────────────────────────

-- Returns the UTC cycle slot index (floor(os.time() / CYCLE_SECONDS))
-- and whether we're in the active weather window (first WEATHER_SECONDS of that slot)
local function getScheduleState()
	local now       = os.time()
	local slotIndex = math.floor(now / CYCLE_SECONDS)
	local offset    = now % CYCLE_SECONDS   -- seconds into current 10-min slot
	local isActive  = offset < WEATHER_SECONDS
	local remaining = isActive and (WEATHER_SECONDS - offset) or (CYCLE_SECONDS - offset)
	return slotIndex, isActive, remaining
end

-- Deterministic RNG from slot index so every server picks the same weather
local function pickWeather(slotIndex)
	local rng = Random.new(slotIndex)
	local options = {}
	local total = 0
	for _, w in pairs(WeatherSystem.WeatherTypes) do
		if w.chance > 0 then
			table.insert(options, w)
			total += w.chance
		end
	end
	table.sort(options, function(a, b) return a.name < b.name end)  -- stable order
	local roll = rng:NextNumber(0, total)
	local sum = 0
	for _, w in ipairs(options) do
		sum += w.chance
		if roll <= sum then return w.name end
	end
	return "Rain"
end

local function setDayCyclePause(paused)
	if not RunService:IsServer() then return end
	local pauseEvent = ServerScriptService:FindFirstChild("DayCyclePause")
	if pauseEvent then pauseEvent:Fire(paused) end
end

local function updateSnowPartState(weatherName)
	if not snowPart then return end
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
		if existing then existing:Destroy() end
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

function WeatherSystem.GetCurrentWeatherEffects()
	local t = WeatherSystem.WeatherTypes[state.currentWeather]
	return (state.isActive and t and t.effects) or WeatherSystem.WeatherTypes.Clear.effects
end

function WeatherSystem.GetSecureWeatherInfo()
	local _, isActive, remaining = getScheduleState()
	return {
		currentWeather = state.currentWeather,
		isActive       = state.isActive,
		remainingTime  = (state.isActive and isActive) and remaining or 0,
		nextWeatherIn  = (not state.isActive and not isActive) and remaining or 0,
		cycleCount     = state.cycleIndex,
		effects        = WeatherSystem.GetCurrentWeatherEffects(),
	}
end

function WeatherSystem.GetCurrentWeatherInfo()
	return WeatherSystem.GetSecureWeatherInfo()
end

function WeatherSystem.ApplySecureWeatherEffects(fishInfo)
	if not fishInfo then return end
	local effects = WeatherSystem.GetCurrentWeatherEffects()
	local info = WeatherSystem.GetSecureWeatherInfo()
	if not info.isActive then return fishInfo end

	local ow, ov, on = fishInfo.weight, fishInfo.value, fishInfo.fishName

	local mutationChance = effects.mutationChance or 0
	local isMutation = effects.namePrefix ~= "" and math.random() < mutationChance

	if isMutation then
		fishInfo.fishName = effects.namePrefix .. on
		if effects.valueMultiplier ~= 1.0 then
			fishInfo.value = math.floor(ov * effects.valueMultiplier)
		end
		if effects.namePrefix == "Frozen "  then fishInfo.isFrozen   = true end
		if effects.namePrefix == "Festival " then fishInfo.isFestival = true end
	end

	if effects.sizeMultiplier ~= 1.0 then
		fishInfo.weight = math.floor(ow * effects.sizeMultiplier * 10 + 0.5) / 10
	end

	fishInfo.appliedWeather = info.currentWeather
	fishInfo.weatherCycle   = info.cycleCount
	return fishInfo
end

function WeatherSystem.ApplyWeatherEffects(fishInfo)
	return WeatherSystem.ApplySecureWeatherEffects(fishInfo)
end

-- Admin override: force a specific weather (ignores schedule, fires WeatherChanged)
function WeatherSystem.SetWeather(name, duration)
	local w = WeatherSystem.WeatherTypes[name]
	if not w then return false end
	if WeatherSystem.WeatherChanged then
		WeatherSystem.WeatherChanged:Fire(name, duration)
	end
	return true
end

-- :weatherskip — cuts remaining time (no-op with UTC schedule; kept for API compat)
function WeatherSystem.ReduceWeatherTime(_seconds)
	return false
end

-- ── Initialize (server only) ──────────────────────────────────────────────────

function WeatherSystem.Initialize()
	if not RunService:IsServer() then return end

	if not WeatherSystem.WeatherChanged then
		WeatherSystem.WeatherChanged = Instance.new("BindableEvent")
	end

	local weatherRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Weather")
	local weatherChangedEvent = weatherRemotes:WaitForChild("WeatherChangedEvent")

	local CLOCK_TWEEN_DURATION = 4
	local prevWeather = "Clear"

	-- Central handler: fires DayCyclePause and notifies clients (with tween delay for Firework)
	WeatherSystem.WeatherChanged.Event:Connect(function(newWeather, _duration)
		state.currentWeather = (newWeather == "Clear") and "Clear" or newWeather
		state.isActive       = (newWeather ~= "Clear")

		updateSnowPartState(newWeather)

		if newWeather == "Firework" then
			updateSnowPartState(newWeather)
			setDayCyclePause(true)
			task.delay(CLOCK_TWEEN_DURATION, function()
				for _, p in ipairs(Players:GetPlayers()) do
					weatherChangedEvent:FireClient(p, newWeather)
				end
			end)
		elseif prevWeather == "Firework" then
			setDayCyclePause(false)
			task.delay(CLOCK_TWEEN_DURATION, function()
				updateSnowPartState(newWeather)
				for _, p in ipairs(Players:GetPlayers()) do
					weatherChangedEvent:FireClient(p, newWeather)
				end
			end)
		else
			updateSnowPartState(newWeather)
			setDayCyclePause(false)
			for _, p in ipairs(Players:GetPlayers()) do
				weatherChangedEvent:FireClient(p, newWeather)
			end
		end

		prevWeather = newWeather
	end)

	-- New player: sync to current weather immediately
	Players.PlayerAdded:Connect(function(player)
		task.wait(2)
		updateSnowPartState(state.currentWeather)
		weatherChangedEvent:FireClient(player, state.isActive and state.currentWeather or "Clear")
	end)

	-- MessagingService: receive weather from another server in the same slot
	local msOk = pcall(function()
		MessagingService:SubscribeAsync(MS_TOPIC, function(msg)
			local data = msg.Data
			if type(data) ~= "table" then return end
			local slotIndex, isActive, _ = getScheduleState()
			-- Only accept if this message is for the current or next slot
			if data.slot ~= slotIndex then return end
			if data.weather and WeatherSystem.WeatherTypes[data.weather] then
				if isActive and data.weather ~= "Clear" then
					WeatherSystem.WeatherChanged:Fire(data.weather)
				end
			end
		end)
	end)
	if not msOk then
		-- Studio: MessagingService unavailable, silent fallback
	end

	-- ── UTC schedule loop ──
	-- Check every second; when the slot changes, pick weather and broadcast
	task.spawn(function()
		local lastSlot, lastActive = getScheduleState()

		-- Apply initial weather on server start
		if lastActive then
			local weather = pickWeather(lastSlot)
			state.cycleIndex = lastSlot
			WeatherSystem.WeatherChanged:Fire(weather)
			-- Broadcast so other servers know what we picked
			pcall(function()
				MessagingService:PublishAsync(MS_TOPIC, { slot = lastSlot, weather = weather })
			end)
		end

		while true do
			task.wait(1)
			local slotIndex, isActive, _ = getScheduleState()

			if slotIndex ~= lastSlot then
				-- New 10-minute slot started
				lastSlot = slotIndex
				lastActive = isActive
				state.cycleIndex = slotIndex

				if isActive then
					-- First half of new slot: pick weather
					local weather = pickWeather(slotIndex)
					WeatherSystem.WeatherChanged:Fire(weather)
					pcall(function()
						MessagingService:PublishAsync(MS_TOPIC, { slot = slotIndex, weather = weather })
					end)
				else
					-- Second half of slot (shouldn't happen on slot boundary but guard it)
					WeatherSystem.WeatherChanged:Fire("Clear")
				end

			elseif isActive ~= lastActive then
				-- Crossed the :05 boundary within the same slot (active → clear)
				lastActive = isActive
				if not isActive then
					WeatherSystem.WeatherChanged:Fire("Clear")
				end
			end
		end
	end)
end

function WeatherSystem.GetInternalState()
	warn("Internal state access blocked")
	return nil
end

return WeatherSystem
