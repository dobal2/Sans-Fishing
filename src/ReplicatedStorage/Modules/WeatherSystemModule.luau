local WeatherSystem = {}
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")
local snowPart = serverStorage:WaitForChild("SnowPart")

-- 🔒 보안 설정
local WEATHER_SECRET_KEY = "WEATHER_" .. math.random(100000, 999999) .. "_" .. tick()
local SERVER_START_TIME = tick()

-- 🕐 타이밍 설정
local WEATHER_CYCLE_TIME = 600
local WEATHER_DURATION = 300
local COOLDOWN_TIME = WEATHER_CYCLE_TIME - WEATHER_DURATION

-- 🎆 폭죽 효과 변수 (클라이언트 신호용)
local fireworkConnection = nil

-- 날씨 타입 정의 (🎆 Firework 추가)
WeatherSystem.WeatherTypes = {
	Clear = { name = "Clear", chance = 0, effects = { sizeMultiplier = 1.0, valueMultiplier = 1.0, namePrefix = "" } },
	Rain = { name = "Rain", chance = 40, effects = { sizeMultiplier = 1.2, valueMultiplier = 1.0, namePrefix = "" } },
	Snow = { name = "Snow", chance = 40, effects = { sizeMultiplier = 1.0, valueMultiplier = 2.0, namePrefix = "Frozen " } },
	Firework = { name = "Firework", chance = 20, effects = { sizeMultiplier = 1.0, valueMultiplier = 1.5, namePrefix = "Festival " } }
}

-- 🔒 날씨 상태
local SecureWeatherState = {
	currentWeather = "Clear",
	lastWeatherStart = 0,
	nextWeatherTime = SERVER_START_TIME + WEATHER_CYCLE_TIME,
	isWeatherActive = false,
	weatherEndTime = 0,
	cycleCount = 0
}

-- 🎆 폭죽 효과 함수 (클라이언트에 신호만 전송)
local function createFireworkEffect()
	-- 🔧 서버에서는 클라이언트에 신호만 전송
	local fireworkEvent = ReplicatedStorage:FindFirstChild("FireworkEffectEvent")
	if fireworkEvent then
		-- 모든 클라이언트에 폭죽 신호 전송
		fireworkEvent:FireAllClients()
		print("🎆 폭죽 신호 전송됨")
	else
		warn("❌ FireworkEffectEvent를 찾을 수 없습니다!")
	end
end

-- 🎆 폭죽 효과 시작/중지 함수
local function startFireworkEffects()
	if fireworkConnection then
		task.cancel(fireworkConnection)
	end

	print("🎆 폭죽 효과 시작 - 2초마다 실행")
	fireworkConnection = task.spawn(function()
		while SecureWeatherState.currentWeather == "Firework" and SecureWeatherState.isWeatherActive do
			createFireworkEffect()
			wait(3)  -- 2초마다 실행
		end
		print("🎆 폭죽 효과 종료")
	end)
end

local function stopFireworkEffects()
	if fireworkConnection then
		task.cancel(fireworkConnection)
		fireworkConnection = nil
		print("🎆 폭죽 효과 중지")
	end
end

-- 🧊 SnowPart 처리 함수
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
			print("❄️ SnowPart 생성됨")
		end
	else
		if existing then
			existing:Destroy()
			print("☀️ SnowPart 제거됨")
		end
	end
end

local function validateServerTime()
	local now = tick()
	local uptime = now - SERVER_START_TIME
	if uptime < 0 or uptime > 86400 * 7 then
		warn("🔒 서버 시간 이상")
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
		print("🔒 날씨 자동 종료 - Clear")
		if WeatherSystem.WeatherChanged then
			WeatherSystem.WeatherChanged:Fire("Clear")
		end
		return false
	end
	return SecureWeatherState.isWeatherActive
end

-- 🌙 밤 시간인지 확인하는 함수
local function isNightTime()
	local lighting = game:GetService("Lighting")
	local timeOfDay = lighting.TimeOfDay

	-- TimeOfDay를 시간(숫자)으로 변환
	local hours, minutes, seconds = timeOfDay:match("(%d+):(%d+):(%d+)")
	local totalHours = tonumber(hours) + tonumber(minutes)/60 + tonumber(seconds)/3600

	-- 밤 시간: 18:00 ~ 06:00 (오후 6시 ~ 오전 6시)
	return totalHours >= 18 or totalHours < 6
end

local function selectSecureRandomWeather()
	local seed = (tick() * 1000) + SecureWeatherState.cycleCount + string.len(WEATHER_SECRET_KEY)
	local rng = Random.new(seed)

	local options = {}
	local total = 0
	for _, weather in pairs(WeatherSystem.WeatherTypes) do
		if weather.chance > 0 then
			-- 🌙 폭죽은 밤에만 가능
			if weather.name == "Firework" and not isNightTime() then
				print("🌙 낮 시간이므로 폭죽 날씨 제외")
				-- 폭죽을 제외하고 계속
			else
				table.insert(options, weather)
				total = total + weather.chance
			end
		end
	end

	-- 옵션이 없으면 기본 비 날씨
	if #options == 0 then
		print("⚠️ 사용 가능한 날씨가 없음, 비 날씨로 설정")
		return "Rain"
	end

	local target = rng:NextNumber(0, total)
	local sum = 0
	for _, weather in ipairs(options) do
		sum = sum + weather.chance
		if target <= sum then
			print("🎲 선택된 날씨:", weather.name, "(밤 시간:", isNightTime(), ")")
			return weather.name
		end
	end

	return "Rain"
end

function WeatherSystem.UpdateWeatherCycle()
	if not validateServerTime() then return end
	local now = tick()
	validateWeatherState()  -- 현재 상태 확인

	-- 🌙 밤이고 현재 날씨가 없으면 즉시 폭죽 시작
	if isNightTime() and not SecureWeatherState.isWeatherActive then
		local newWeather = "Firework"
		SecureWeatherState.currentWeather = newWeather
		SecureWeatherState.lastWeatherStart = now
		SecureWeatherState.weatherEndTime = now + WEATHER_DURATION
		SecureWeatherState.isWeatherActive = true
		SecureWeatherState.cycleCount += 1
		SecureWeatherState.nextWeatherTime = now + WEATHER_DURATION + COOLDOWN_TIME

		-- 🎆 폭죽 효과 시작
		startFireworkEffects()

		print("🌙 밤 시간 감지 - 폭죽 날씨 즉시 시작:", newWeather)
		if WeatherSystem.WeatherChanged then
			WeatherSystem.WeatherChanged:Fire(newWeather)
		end
		return
	end

	-- 🌅 낮이고 폭죽 날씨면 즉시 종료
	if not isNightTime() and SecureWeatherState.currentWeather == "Firework" and SecureWeatherState.isWeatherActive then
		stopFireworkEffects()
		SecureWeatherState.isWeatherActive = false
		SecureWeatherState.currentWeather = "Clear"
		SecureWeatherState.nextWeatherTime = now + COOLDOWN_TIME
		print("🌅 낮 시간 감지 - 폭죽 날씨 즉시 종료")
		if WeatherSystem.WeatherChanged then
			WeatherSystem.WeatherChanged:Fire("Clear")
		end
		return
	end

	-- 기존 날씨 사이클 로직 (낮 시간용)
	if not isNightTime() and now >= SecureWeatherState.nextWeatherTime and not SecureWeatherState.isWeatherActive then
		local newWeather = selectSecureRandomWeather()
		SecureWeatherState.currentWeather = newWeather
		SecureWeatherState.lastWeatherStart = now
		SecureWeatherState.weatherEndTime = now + WEATHER_DURATION
		SecureWeatherState.isWeatherActive = true
		SecureWeatherState.cycleCount += 1
		SecureWeatherState.nextWeatherTime = now + WEATHER_DURATION + COOLDOWN_TIME

		-- 🎆 폭죽 날씨면 효과 시작 (하지만 낮에는 폭죽이 선택되지 않음)
		if newWeather == "Firework" then
			startFireworkEffects()
		end

		print("🌤️ 새 날씨 시작:", newWeather)
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
	print("🔒 WeatherSystem 초기화")

	if not WeatherSystem.WeatherChanged then
		WeatherSystem.WeatherChanged = Instance.new("BindableEvent")
	end

	local weatherChangedEvent = Instance.new("RemoteEvent")
	weatherChangedEvent.Name = "WeatherChangedEvent"
	weatherChangedEvent.Parent = ReplicatedStorage

	-- 🆕 폭죽 효과 이벤트 생성
	local fireworkEffectEvent = Instance.new("RemoteEvent")
	fireworkEffectEvent.Name = "FireworkEffectEvent"
	fireworkEffectEvent.Parent = ReplicatedStorage
	print("✅ FireworkEffectEvent 생성됨")

	WeatherSystem.WeatherChanged.Event:Connect(function(newWeather)
		print("📡 날씨 변경:", newWeather)

		-- SnowPart 처리
		updateSnowPartState(newWeather)

		-- 🎆 폭죽 효과 처리
		if newWeather == "Firework" then
			-- 폭죽 효과는 SetWeather나 UpdateWeatherCycle에서 이미 시작됨
		else
			stopFireworkEffects()
		end

		-- 클라이언트에 알림
		for _, player in pairs(game:GetService("Players"):GetPlayers()) do
			weatherChangedEvent:FireClient(player, newWeather)
		end
	end)

	game:GetService("Players").PlayerAdded:Connect(function(player)
		wait(2)
		local info = WeatherSystem.GetSecureWeatherInfo()
		updateSnowPartState(info.currentWeather)
		weatherChangedEvent:FireClient(player, info.currentWeather)
	end)

	SecureWeatherState.nextWeatherTime = SERVER_START_TIME + WEATHER_CYCLE_TIME

	spawn(function()
		while true do
			wait(5)  -- 🔧 30초 → 5초로 변경 (더 빠른 밤/낮 감지)
			WeatherSystem.UpdateWeatherCycle()
		end
	end)

	spawn(function()
		while true do
			wait(60)
			local info = WeatherSystem.GetSecureWeatherInfo()
			if info.isActive then
				print(string.format("🌤️ 현재 날씨: %s (%d초 남음)", info.currentWeather, math.floor(info.remainingTime)))
			else
				print(string.format("☀️ Clear 상태 (다음 날씨까지 %d초)", math.floor(info.nextWeatherIn)))
			end
		end
	end)
end

function WeatherSystem.GetInternalState()
	warn("🔒 내부 상태 접근 차단")
	return nil
end

return WeatherSystem