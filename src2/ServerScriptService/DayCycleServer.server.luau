local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")

-- WeatherSystemModule fires this to suppress Lighting updates during Firework
local pauseEvent = Instance.new("BindableEvent")
pauseEvent.Name = "DayCyclePause"
pauseEvent.Parent = ServerScriptService

-- Commands.server.luau fires this to set speed multiplier
local speedEvent = Instance.new("BindableEvent")
speedEvent.Name = "DayCycleSpeed"
speedEvent.Parent = ServerScriptService

local DAY_START   = 6
local NIGHT_START = 18

local DAY_RATE   = 12 / (15 * 60)  -- 15 real minutes for day (6→18)
local NIGHT_RATE = 12 / (5 * 60)   -- 5 real minutes for night (18→6)

local TICK = 1

local clockTime = 8

local overridden = false
local speedMultiplier = 1
local clockTween = nil

local CLOCK_TWEEN_INFO = TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local function tweenClockTime(target)
	if clockTween then clockTween:Cancel() end
	clockTween = TweenService:Create(Lighting, CLOCK_TWEEN_INFO, { ClockTime = target })
	clockTween.Completed:Connect(function()
		clockTween = nil
		-- tween done: hand control back to the loop
		overridden = false
	end)
	clockTween:Play()
end

pauseEvent.Event:Connect(function(isOverridden)
	if isOverridden and not overridden then
		overridden = true
		clockTime = 21
		tweenClockTime(21)
	elseif not isOverridden and overridden then
		-- keep overridden=true while tween plays; tweenClockTime.Completed sets it false
		local target = clockTime
		tweenClockTime(target)
	end
end)

speedEvent.Event:Connect(function(mult)
	speedMultiplier = math.max(0, mult)
end)

-- Save the daytime skybox textures at startup so we can restore them during the day.
-- At night the textures are cleared so Roblox's built-in star rendering shows through
-- the dark sky.  Custom opaque day-textures would otherwise block star rendering.
local sky = Lighting:FindFirstChildOfClass("Sky")
local DAY_SKYBOX = {}
if sky then
	DAY_SKYBOX = {
		SkyboxBk = sky.SkyboxBk,
		SkyboxFt = sky.SkyboxFt,
		SkyboxDn = sky.SkyboxDn,
		SkyboxUp = sky.SkyboxUp,
	}
end

local isNight = false  -- track to avoid redundant texture swaps

local function setNightSky()
	if isNight or not sky then return end
	isNight = true
	sky.SkyboxBk = ""
	sky.SkyboxFt = ""
	sky.SkyboxDn = ""
	sky.SkyboxUp = ""
end

local function setDaySky()
	if not isNight or not sky then return end
	isNight = false
	sky.SkyboxBk = DAY_SKYBOX.SkyboxBk or ""
	sky.SkyboxFt = DAY_SKYBOX.SkyboxFt or ""
	sky.SkyboxDn = DAY_SKYBOX.SkyboxDn or ""
	sky.SkyboxUp = DAY_SKYBOX.SkyboxUp or ""
end

Lighting.ClockTime = clockTime

task.spawn(function()
	while true do
		task.wait(TICK)

		if clockTime >= DAY_START and clockTime < NIGHT_START then
			clockTime = clockTime + DAY_RATE * TICK * speedMultiplier
			if clockTime >= NIGHT_START then clockTime = NIGHT_START end
		else
			clockTime = clockTime + NIGHT_RATE * TICK * speedMultiplier
			if clockTime >= 24 then clockTime = clockTime - 24 end
		end

		if not overridden then
			Lighting.ClockTime = clockTime
		end

		-- Swap skybox based on time of day
		local ct = Lighting.ClockTime
		if ct >= NIGHT_START or ct < DAY_START then
			setNightSky()
		else
			setDaySky()
		end
	end
end)
