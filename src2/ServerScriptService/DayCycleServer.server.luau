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

-- 데이/나이트 사이클은 비활성화. Firework 날씨일 때만 WeatherSystem이 DayCyclePause로 밤을 제어한다.
-- pauseEvent: Firework 시작 → true(밤), 종료 → false(낮으로 복원)

local FIREWORK_CLOCK = 21  -- Firework 중 고정할 시각 (밤)
local DAY_CLOCK      = 10  -- 평상시 고정 시각 (낮)

local CLOCK_TWEEN_INFO = TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local clockTween = nil

local function tweenClockTime(target)
	if clockTween then clockTween:Cancel() end
	clockTween = TweenService:Create(Lighting, CLOCK_TWEEN_INFO, { ClockTime = target })
	clockTween:Play()
end

-- 낮 시각으로 초기화
Lighting.ClockTime = DAY_CLOCK

pauseEvent.Event:Connect(function(isFirework)
	if isFirework then
		tweenClockTime(FIREWORK_CLOCK)
	else
		tweenClockTime(DAY_CLOCK)
	end
end)

-- speedEvent는 호환성을 위해 수신만 (낮밤 루프 없으므로 실제 효과 없음)
speedEvent.Event:Connect(function(_mult) end)
