-- StarterPlayer/StarterPlayerScripts/ClientWeatherHandler.lua
-- 클라이언트에서 날씨 변경을 받아서 Rain 모듈 + 부드러운 라이팅 제어 + 향상된 폭죽 효과

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- 🎆 폭죽 사운드 로드 (안전하게, 하지만 무한정 기다림)
local fireworkSound = nil
spawn(function()
	local sounds = ReplicatedStorage:WaitForChild("Sounds")
	fireworkSound = sounds:WaitForChild("firework")
	print("✅ 폭죽 사운드 로드 완료")
end)

-- 🌧️ Rain 모듈 로드
local modules = ReplicatedStorage:WaitForChild("Modules")
local RainModule = require(modules:WaitForChild("Rain"))

-- 📡 이벤트 대기 (무한정 기다림)
local weatherChangedEvent = ReplicatedStorage:WaitForChild("WeatherChangedEvent")
local fireworkEffectEvent = ReplicatedStorage:WaitForChild("FireworkEffectEvent")

print("✅ WeatherChangedEvent 발견!")
print("✅ FireworkEffectEvent 발견!")

-- 🎆 현재 폭죽 상태 추적
local isFireworkActive = false
local fireworkLoopConnection = nil

-- 🎨 원래 기본 색상 + 추가 다양한 색상 팔레트
local FIREWORK_COLORS = {
	-- 🔥 원래 기본 색상들 (유지)
	Color3.fromRGB(255, 100, 100), -- 빨강
	Color3.fromRGB(100, 255, 100), -- 초록
	Color3.fromRGB(100, 100, 255), -- 파랑
	Color3.fromRGB(255, 255, 100), -- 노랑
	Color3.fromRGB(255, 100, 255), -- 분홍

	-- ✨ 추가 화려한 색상들
	Color3.fromRGB(100, 255, 255), -- 하늘색
	Color3.fromRGB(255, 165, 0),   -- 주황
	Color3.fromRGB(255, 20, 147),  -- 진한 분홍
	Color3.fromRGB(0, 255, 127),   -- 봄 초록
	Color3.fromRGB(138, 43, 226),  -- 보라
	Color3.fromRGB(255, 215, 0),   -- 금색
	Color3.fromRGB(255, 69, 0),    -- 빨강-주황
	Color3.fromRGB(50, 205, 50),   -- 라임 초록
	Color3.fromRGB(30, 144, 255),  -- 도지블루
	Color3.fromRGB(255, 105, 180), -- 핫핑크
	Color3.fromRGB(0, 191, 255)    -- 딥스카이블루
}

-- 🎯 Y값 고정 + 더 넓은 X,Z 위치 생성 (멀리서도 폭죽 생성)
local function getRandomFireworkPosition()
	local character = player.Character
	local basePos = Vector3.new(0, 0, 0)

	if character and character:FindFirstChild("HumanoidRootPart") then
		basePos = character.HumanoidRootPart.Position
	end

	-- 🔧 Y값 고정 + 훨씬 더 넓은 X,Z 범위 (멀리서도 폭죽 생성)
	local distance = math.random(100, 500) -- 100~500 범위로 확장 (기존: 50~150)
	local angle = math.random() * math.pi * 2 -- 완전 랜덤 각도
	local fixedHeight = 300 -- 🎯 Y값 고정

	local x = basePos.X + math.cos(angle) * distance
	local z = basePos.Z + math.sin(angle) * distance

	return Vector3.new(x, fixedHeight, z)
end

-- 🎆 여러 타입의 폭죽 패턴
local FIREWORK_PATTERNS = {
	-- 1. 원형 폭발
	{
		name = "Circle",
		emitCount = 5000,
		spreadAngle = Vector2.new(360, 360),
		speed = NumberRange.new(25, 60),
		particleCount = 3
	},

	-- 2. 큰 폭발
	{
		name = "BigBurst",
		emitCount = 5000,
		spreadAngle = Vector2.new(360, 360),
		speed = NumberRange.new(30, 80),
		particleCount = 4
	},

	-- 3. 작은 반짝임
	{
		name = "Sparkle",
		emitCount = 5000,
		spreadAngle = Vector2.new(180, 180),
		speed = NumberRange.new(15, 40),
		particleCount = 2
	},

	-- 4. 폭포형
	{
		name = "Waterfall",
		emitCount = 5000,
		spreadAngle = Vector2.new(120, 60),
		speed = NumberRange.new(20, 50),
		particleCount = 3
	}
}

-- 트윈 설정
local TWEEN_DURATION = 3
local TWEEN_INFO = TweenInfo.new(
	TWEEN_DURATION,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.InOut,
	0,
	false,
	0
)

-- 현재 실행중인 트윈들을 저장
local activeTweens = {}

-- 트윈을 안전하게 정리하는 함수
local function cleanupTweens()
	for _, tween in pairs(activeTweens) do
		if tween then
			tween:Cancel()
		end
	end
	activeTweens = {}
end

-- 부드러운 라이팅 효과 함수들
local function applyRainLighting()
	cleanupTweens()

	local atmosphere = Lighting:FindFirstChild("Atmosphere")
	if atmosphere then
		local tween = TweenService:Create(atmosphere, TWEEN_INFO, {Density = 0.5})
		activeTweens[#activeTweens + 1] = tween
		tween:Play()
	end

	local blur = Lighting:FindFirstChild("Blur")
	if blur then
		local tween = TweenService:Create(blur, TWEEN_INFO, {Size = 4})
		activeTweens[#activeTweens + 1] = tween
		tween:Play()
	end

	local sunRays = Lighting:FindFirstChild("SunRays")
	if sunRays then
		local tween = TweenService:Create(sunRays, TWEEN_INFO, {Intensity = 0})
		activeTweens[#activeTweens + 1] = tween
		tween:Play()

		tween.Completed:Connect(function()
			sunRays.Enabled = false
		end)
	end
end

local function applyClearLighting()
	cleanupTweens()

	local atmosphere = Lighting:FindFirstChild("Atmosphere")
	if atmosphere then
		local tween = TweenService:Create(atmosphere, TWEEN_INFO, {Density = 0.35})
		activeTweens[#activeTweens + 1] = tween
		tween:Play()
	end

	local blur = Lighting:FindFirstChild("Blur")
	if blur then
		local tween = TweenService:Create(blur, TWEEN_INFO, {Size = 2})
		activeTweens[#activeTweens + 1] = tween
		tween:Play()
	end

	local sunRays = Lighting:FindFirstChild("SunRays")
	if sunRays then
		sunRays.Enabled = true
		sunRays.Intensity = 0

		local tween = TweenService:Create(sunRays, TWEEN_INFO, {Intensity = 0.06})
		activeTweens[#activeTweens + 1] = tween
		tween:Play()
	end
end

-- 🎨 더 나은 랜덤 색상 선택 (연속으로 같은 색 방지)
local lastColorIndex = 0
local function getRandomFireworkColor()
	local newIndex
	repeat
		newIndex = math.random(1, #FIREWORK_COLORS)
	until newIndex ~= lastColorIndex or #FIREWORK_COLORS <= 1

	lastColorIndex = newIndex
	return FIREWORK_COLORS[newIndex]
end

-- 🎆 향상된 폭죽 효과 처리 함수 (버그 수정 버전)
local function createClientFireworkEffect()
	print("🎆 폭죽 효과 실행 시도")

	-- 🎯 랜덤 위치 생성
	local fireworkPos = getRandomFireworkPosition()

	-- 🎲 랜덤 패턴 선택
	local pattern = FIREWORK_PATTERNS[math.random(#FIREWORK_PATTERNS)]

	-- 🌈 폭죽 전체에 사용할 단일 색상 선택
	local fireworkColor = getRandomFireworkColor()

	-- ReplicatedStorage에서 FireWorkEffectPart 찾기
	local fireworkPart = ReplicatedStorage:FindFirstChild("FireWorkEffectPart")
	local fireworkClone

	if not fireworkPart then
		print("❌ FireWorkEffectPart 없음 - 향상된 버전 직접 생성")

		-- 향상된 폭죽 파트 생성
		fireworkClone = Instance.new("Part")
		fireworkClone.Name = "ClientFireworkPart"
		fireworkClone.Anchored = true
		fireworkClone.CanCollide = false
		fireworkClone.Transparency = 1
		fireworkClone.Size = Vector3.new(1, 1, 1)
		fireworkClone.Position = fireworkPos
		fireworkClone.Parent = workspace

		-- 🎨 선택된 패턴으로 ParticleEmitter 생성
		for i = 1, pattern.particleCount do
			local particleEmitter = Instance.new("ParticleEmitter")
			particleEmitter.Name = "FireworkEmitter" .. i

			-- 🎆 다양한 텍스처 사용
			local textures = {
				"rbxasset://textures/particles/fire_main.dds",
				"rbxasset://textures/particles/sparkles_main.dds",
				"rbxasset://textures/particles/explosion_main.dds"
			}
			particleEmitter.Texture = textures[math.random(#textures)]

			particleEmitter.Lifetime = NumberRange.new(1.5, 4.0)
			particleEmitter.Rate = 100
			particleEmitter.SpreadAngle = pattern.spreadAngle
			particleEmitter.Speed = pattern.speed

			-- 🌈 모든 이미터가 같은 색상 사용 (단일 색상)
			particleEmitter.Color = ColorSequence.new(fireworkColor)

			particleEmitter.Size = NumberSequence.new{
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.3, 1.8),
				NumberSequenceKeypoint.new(0.7, 1.2),
				NumberSequenceKeypoint.new(1, 0)
			}

			particleEmitter.Transparency = NumberSequence.new{
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.8, 0.3),
				NumberSequenceKeypoint.new(1, 1)
			}

			particleEmitter.Enabled = false
			particleEmitter.Parent = fireworkClone
		end

		-- 🔧 spawn() 대신 task.wait() 사용하여 안정성 향상
		task.spawn(function()
			for i = 1, pattern.particleCount do
				local emitter = fireworkClone:FindFirstChild("FireworkEmitter" .. i)
				if emitter then
					task.wait(i * 0.1)
					emitter:Emit(pattern.emitCount / pattern.particleCount)
					print("✨ 이미터", i, "실행됨")
				end
			end
		end)

		print("🎆 향상된 직접 생성 폭죽:", pattern.name, "색상:", fireworkColor, "위치:", fireworkPos)
	else
		-- 기존 파트 사용하되 위치와 효과 개선
		fireworkClone = fireworkPart:Clone()
		fireworkClone.Position = fireworkPos
		fireworkClone.Parent = workspace

		print("🎆 기존 파트 사용, 위치:", fireworkPos)

		-- 🎨 모든 ParticleEmitter를 같은 색상으로 설정
		for _, child in pairs(fireworkClone:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				-- 🌈 모든 이미터가 같은 색상 사용 (단일 색상)
				child.Color = ColorSequence.new(fireworkColor)

				child.Enabled = false

				print("✨ ParticleEmitter 색상 변경:", child.Name, "색상:", fireworkColor)
			end
		end

		-- 🔧 기존 파트도 안정적으로 실행
		task.spawn(function()
			task.wait(0.1)
			for _, child in pairs(fireworkClone:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child:Emit(pattern.emitCount / 2)
					print("✨ 기존 이미터 실행:", child.Name)
				end
			end
		end)
	end

	-- 🔊 사운드 재생 (볼륨 랜덤)
	if fireworkSound then
		local soundClone = fireworkSound:Clone()
		soundClone.Parent = fireworkClone
		soundClone.Volume = math.random(50, 100) / 100 -- 0.5~1.0 볼륨
		soundClone:Play()
	end

	-- 🚮 더 안전한 정리 (파티클 수명 + 여유시간)
	task.spawn(function()
		task.wait(8) -- 파티클 최대 수명(4초) + 여유시간(4초)
		if fireworkClone and fireworkClone.Parent then
			fireworkClone:Destroy()
			print("🗑️ 폭죽 파트 정리 완료")
		end
	end)
end
-- 🎆 폭죽 자동 반복 시작/중지 (더 다양한 간격)
local function startFireworkLoop()
	if fireworkLoopConnection then return end

	print("🎆 폭죽 자동 반복 시작")
	fireworkLoopConnection = spawn(function()
		while isFireworkActive do
			-- 🎲 1~3개의 폭죽을 동시에 터뜨리기
			local fireworkCount = math.random(1, 3)

			for i = 1, fireworkCount do
				spawn(function()
					-- 각 폭죽마다 약간의 지연
					wait(math.random() * 0.5)
					createClientFireworkEffect()
				end)
			end

			-- 🕐 더 다양한 간격 (1~5초)
			wait(math.random() * 4 + 1)
		end
		print("🎆 폭죽 자동 반복 종료")
	end)
end

local function stopFireworkLoop()
	if fireworkLoopConnection then
		task.cancel(fireworkLoopConnection)
		fireworkLoopConnection = nil
		print("🎆 폭죽 자동 반복 중지")
	end
end

-- 날씨 변경 처리 함수
local function handleWeatherChange(newWeather)
	print("🌤️ 날씨 변경 처리:", newWeather)

	-- 이전 폭죽 상태 정리
	if isFireworkActive and newWeather ~= "Firework" then
		isFireworkActive = false
		stopFireworkLoop()
	end

	if newWeather == "Rain" then
		print("🌧️ 비 이펙트 시작")
		local success, err = pcall(function()
			wait(0.5)
			RainModule:Enable()
		end)
		if not success then
			warn("❌ Rain 모듈 Enable 실패:", err)
		end

		applyRainLighting()

	elseif newWeather == "Snow" then
		print("❄️ 눈 이펙트 시작 (비 끄기)")
		local success, err = pcall(function()
			RainModule:Disable()
		end)
		if not success then
			warn("❌ Rain 모듈 Disable 실패:", err)
		end

		applyRainLighting()

	elseif newWeather == "Firework" then
		print("🎆 폭죽 이펙트 시작")
		local success, err = pcall(function()
			RainModule:Disable()
		end)
		if not success then
			warn("❌ Rain 모듈 Disable 실패:", err)
		end

		applyRainLighting()  -- 밤 분위기

		-- 폭죽 자동 반복 시작
		isFireworkActive = true
		startFireworkLoop()

	else -- Clear
		print("☀️ 맑은 날씨 (모든 이펙트 끄기)")
		local success, err = pcall(function()
			RainModule:Disable()
		end)
		if not success then
			warn("❌ Rain 모듈 Disable 실패:", err)
		end

		applyClearLighting()

		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = "☀️ 날씨가 맑아졌습니다",
			Color = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.SourceSansBold,
			FontSize = Enum.FontSize.Size18
		})
	end
end

-- 이벤트 연결
weatherChangedEvent.OnClientEvent:Connect(handleWeatherChange)

-- 🎆 폭죽 이벤트 연결 (서버 신호용)
fireworkEffectEvent.OnClientEvent:Connect(function()
	print("🎆 서버에서 폭죽 신호 수신")
	if isFireworkActive then
		-- 🎲 서버 신호 시에도 1~2개 동시 실행
		local count = math.random(1, 2)
		for i = 1, count do
			spawn(function()
				wait(math.random() * 0.3)
				createClientFireworkEffect()
			end)
		end
	end
end)

print("✅ ClientWeatherHandler 초기화 완료")
