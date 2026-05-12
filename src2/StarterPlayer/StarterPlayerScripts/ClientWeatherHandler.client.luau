-- StarterPlayer/StarterPlayerScripts/ClientWeatherHandler.lua
-- Receives weather changes on the client and controls Rain module + smooth lighting + firework effects

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- Load firework sound (safe, waits indefinitely)
local fireworkSound = nil
spawn(function()
	local sounds = ReplicatedStorage:WaitForChild("Sounds")
	fireworkSound = sounds:WaitForChild("firework")
end)

-- Load Rain module
local modules = ReplicatedStorage:WaitForChild("Modules")
local RainModule = require(modules:WaitForChild("Rain"))

-- Wait for events (indefinitely)
local weatherChangedEvent = ReplicatedStorage:WaitForChild("WeatherChangedEvent")
local fireworkEffectEvent = ReplicatedStorage:WaitForChild("FireworkEffectEvent")


-- Track current firework state
local isFireworkActive = false
local fireworkLoopConnection = nil

-- Firework color palette
local FIREWORK_COLORS = {
	-- Base colors
	Color3.fromRGB(255, 100, 100), -- Red
	Color3.fromRGB(100, 255, 100), -- Green
	Color3.fromRGB(100, 100, 255), -- Blue
	Color3.fromRGB(255, 255, 100), -- Yellow
	Color3.fromRGB(255, 100, 255), -- Pink

	-- Additional colors
	Color3.fromRGB(100, 255, 255), -- Cyan
	Color3.fromRGB(255, 165, 0),   -- Orange
	Color3.fromRGB(255, 20, 147),  -- Deep pink
	Color3.fromRGB(0, 255, 127),   -- Spring green
	Color3.fromRGB(138, 43, 226),  -- Purple
	Color3.fromRGB(255, 215, 0),   -- Gold
	Color3.fromRGB(255, 69, 0),    -- Red-orange
	Color3.fromRGB(50, 205, 50),   -- Lime green
	Color3.fromRGB(30, 144, 255),  -- Dodger blue
	Color3.fromRGB(255, 105, 180), -- Hot pink
	Color3.fromRGB(0, 191, 255)    -- Deep sky blue
}

-- Fixed Y + wide X,Z position generation
local function getRandomFireworkPosition()
	local character = player.Character
	local basePos = Vector3.new(0, 0, 0)

	if character and character:FindFirstChild("HumanoidRootPart") then
		basePos = character.HumanoidRootPart.Position
	end

	-- Fixed Y + wide X,Z range
	local distance = math.random(100, 500)
	local angle = math.random() * math.pi * 2
	local fixedHeight = 300 -- Fixed Y

	local x = basePos.X + math.cos(angle) * distance
	local z = basePos.Z + math.sin(angle) * distance

	return Vector3.new(x, fixedHeight, z)
end

-- Firework patterns
local FIREWORK_PATTERNS = {
	-- 1. Circle burst
	{
		name = "Circle",
		emitCount = 5000,
		spreadAngle = Vector2.new(360, 360),
		speed = NumberRange.new(25, 60),
		particleCount = 3
	},

	-- 2. Big burst
	{
		name = "BigBurst",
		emitCount = 5000,
		spreadAngle = Vector2.new(360, 360),
		speed = NumberRange.new(30, 80),
		particleCount = 4
	},

	-- 3. Sparkle
	{
		name = "Sparkle",
		emitCount = 5000,
		spreadAngle = Vector2.new(180, 180),
		speed = NumberRange.new(15, 40),
		particleCount = 2
	},

	-- 4. Waterfall
	{
		name = "Waterfall",
		emitCount = 5000,
		spreadAngle = Vector2.new(120, 60),
		speed = NumberRange.new(20, 50),
		particleCount = 3
	}
}

-- Tween settings
local TWEEN_DURATION = 3
local TWEEN_INFO = TweenInfo.new(
	TWEEN_DURATION,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.InOut,
	0,
	false,
	0
)

-- Store active tweens
local activeTweens = {}

-- Safely cancel all active tweens
local function cleanupTweens()
	for _, tween in pairs(activeTweens) do
		if tween then
			tween:Cancel()
		end
	end
	activeTweens = {}
end

-- Smooth rain lighting
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

-- Random color selection (prevents consecutive duplicates)
local lastColorIndex = 0
local function getRandomFireworkColor()
	local newIndex
	repeat
		newIndex = math.random(1, #FIREWORK_COLORS)
	until newIndex ~= lastColorIndex or #FIREWORK_COLORS <= 1

	lastColorIndex = newIndex
	return FIREWORK_COLORS[newIndex]
end

-- Create firework effect on client
local function createClientFireworkEffect()

	local fireworkPos = getRandomFireworkPosition()
	local pattern = FIREWORK_PATTERNS[math.random(#FIREWORK_PATTERNS)]
	local fireworkColor = getRandomFireworkColor()

	local fireworkPart = ReplicatedStorage:FindFirstChild("FireWorkEffectPart")
	local fireworkClone

	if not fireworkPart then

		fireworkClone = Instance.new("Part")
		fireworkClone.Name = "ClientFireworkPart"
		fireworkClone.Anchored = true
		fireworkClone.CanCollide = false
		fireworkClone.Transparency = 1
		fireworkClone.Size = Vector3.new(1, 1, 1)
		fireworkClone.Position = fireworkPos
		fireworkClone.Parent = workspace

		for i = 1, pattern.particleCount do
			local particleEmitter = Instance.new("ParticleEmitter")
			particleEmitter.Name = "FireworkEmitter" .. i

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

			-- All emitters use same color
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

		task.spawn(function()
			for i = 1, pattern.particleCount do
				local emitter = fireworkClone:FindFirstChild("FireworkEmitter" .. i)
				if emitter then
					task.wait(i * 0.1)
					emitter:Emit(pattern.emitCount / pattern.particleCount)
				end
			end
		end)

	else
		-- Use existing part
		fireworkClone = fireworkPart:Clone()
		fireworkClone.Position = fireworkPos
		fireworkClone.Parent = workspace

		-- Set all ParticleEmitters to same color
		for _, child in pairs(fireworkClone:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child.Color = ColorSequence.new(fireworkColor)
				child.Enabled = false
			end
		end

		task.spawn(function()
			task.wait(0.1)
			for _, child in pairs(fireworkClone:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child:Emit(pattern.emitCount / 2)
				end
			end
		end)
	end

	-- Play sound
	if fireworkSound then
		local soundClone = fireworkSound:Clone()
		soundClone.Parent = fireworkClone
		soundClone.Volume = math.random(50, 100) / 100 -- 0.5~1.0 volume
		soundClone:Play()
	end

	-- Safe cleanup (particle lifetime + buffer)
	task.spawn(function()
		task.wait(8) -- Max particle lifetime (4s) + buffer (4s)
		if fireworkClone and fireworkClone.Parent then
			fireworkClone:Destroy()
		end
	end)
end

-- Start/stop firework loop
local function startFireworkLoop()
	if fireworkLoopConnection then return end

	fireworkLoopConnection = spawn(function()
		while isFireworkActive do
			-- Launch 1-3 fireworks simultaneously
			local fireworkCount = math.random(1, 3)

			for i = 1, fireworkCount do
				spawn(function()
					-- Small delay per firework
					wait(math.random() * 0.5)
					createClientFireworkEffect()
				end)
			end

			-- Varied interval (1-5 seconds)
			wait(math.random() * 4 + 1)
		end
	end)
end

local function stopFireworkLoop()
	if fireworkLoopConnection then
		task.cancel(fireworkLoopConnection)
		fireworkLoopConnection = nil
	end
end

-- Handle weather change
local function handleWeatherChange(newWeather)

	-- Clean up previous firework state
	if isFireworkActive and newWeather ~= "Firework" then
		isFireworkActive = false
		stopFireworkLoop()
	end

	if newWeather == "Rain" then
		local success, err = pcall(function()
			wait(0.5)
			RainModule:Enable()
		end)
		if not success then
			warn("Rain module Enable failed:", err)
		end

		applyRainLighting()

	elseif newWeather == "Snow" then
		local success, err = pcall(function()
			RainModule:Disable()
		end)
		if not success then
			warn("Rain module Disable failed:", err)
		end

		applyRainLighting()

	elseif newWeather == "Firework" then
		local success, err = pcall(function()
			RainModule:Disable()
		end)
		if not success then
			warn("Rain module Disable failed:", err)
		end

		applyRainLighting()  -- Night atmosphere

		-- Start firework loop
		isFireworkActive = true
		startFireworkLoop()

	else -- Clear
		local success, err = pcall(function()
			RainModule:Disable()
		end)
		if not success then
			warn("Rain module Disable failed:", err)
		end

		applyClearLighting()

		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = "The weather has cleared up",
			Color = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.SourceSansBold,
			FontSize = Enum.FontSize.Size18
		})
	end
end

-- Connect weather event
weatherChangedEvent.OnClientEvent:Connect(handleWeatherChange)

-- Connect firework event (server signal)
fireworkEffectEvent.OnClientEvent:Connect(function()
	if isFireworkActive then
		-- Launch 1-2 simultaneously on server signal
		local count = math.random(1, 2)
		for i = 1, count do
			spawn(function()
				wait(math.random() * 0.3)
				createClientFireworkEffect()
			end)
		end
	end
end)
