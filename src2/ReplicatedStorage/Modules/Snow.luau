-- Snow module: Rain처럼 카메라를 따라다니는 Emitter + raycast로 착지 시간 계산
-- SnowPart(서버 배치)는 사용하지 않음. 이 모듈이 클라이언트 시각 효과를 전담.

local RunService  = game:GetService("RunService")
local Players     = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ── 설정 ────────────────────────────────────────────────────────────────────

local EMITTER_HALF   = 60       -- 카메라 주변 Emitter 크기 (studs)
local EMITTER_UP     = 30       -- 카메라 위로 Emitter 위치 오프셋
local SCAN_HEIGHT    = 400      -- raycast 위에서 아래로 탐색 거리
local SNOW_RATE      = 400      -- 파티클 rate (Rain의 600보다 적게)
local SNOW_SPEED_MIN = 4
local SNOW_SPEED_MAX = 7
local SNOW_SIZE      = 0.25     -- 눈송이 크기
local SNOW_TEXTURE   = "rbxasset://textures/particles/sparkles_main.dds"
local UPDATE_PERIOD  = 4        -- N 프레임마다 Lifetime 재계산

-- ── Emitter 파트 ────────────────────────────────────────────────────────────

local Emitter = Instance.new("Part")
Emitter.Name          = "__SnowEmitter"
Emitter.Transparency  = 1
Emitter.Anchored      = true
Emitter.CanCollide    = false
Emitter.CastShadow    = false
Emitter.Locked        = true
Emitter.Archivable    = false
Emitter.Size          = Vector3.new(1, 1, 1)

local PE = Instance.new("ParticleEmitter")
PE.Name              = "SnowParticle"
PE.Texture           = SNOW_TEXTURE
PE.EmissionDirection = Enum.NormalId.Bottom
PE.Rate              = SNOW_RATE
PE.Speed             = NumberRange.new(SNOW_SPEED_MIN, SNOW_SPEED_MAX)
PE.SpreadAngle       = Vector2.new(8, 8)
PE.RotSpeed          = NumberRange.new(-60, 60)
PE.Rotation          = NumberRange.new(0, 360)
PE.LightInfluence    = 0.8
PE.LightEmission     = 0
PE.WindAffectsDrag   = true
PE.LockedToPart      = false
PE.Enabled           = false

PE.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0,   SNOW_SIZE),
	NumberSequenceKeypoint.new(0.6, SNOW_SIZE * 1.1),
	NumberSequenceKeypoint.new(1,   0),
})

PE.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0,   0.1),
	NumberSequenceKeypoint.new(0.7, 0.1),
	NumberSequenceKeypoint.new(1,   1),
})

PE.Color = ColorSequence.new(Color3.fromRGB(220, 235, 255))
PE.Parent = Emitter

-- ── 상태 ────────────────────────────────────────────────────────────────────

local enabled      = false
local connections  = {}
local frame        = 0

-- 수면 Y: Water 파트는 CanCollide=false라 raycast에 안 걸림 → 직접 구함
local WATER_SURFACE_Y = -3.69
task.spawn(function()
	local water = workspace:FindFirstChild("Water", true)
	if water and water:IsA("BasePart") then
		WATER_SURFACE_Y = water.Position.Y + water.Size.Y / 2
	end
end)

-- ── raycast 파라미터 (캐릭터 + Emitter 제외) ────────────────────────────────

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateRayParams()
	local excludes = { Emitter }
	local char = player.Character
	if char then table.insert(excludes, char) end
	rayParams.FilterDescendantsInstances = excludes
end

-- ── 착지까지 남은 시간으로 Lifetime 계산 ──────────────────────────────────

local function calcLifetime(emitterY)
	local camPos = workspace.CurrentCamera.CFrame.Position

	-- raycast로 지면 감지 (CanCollide 파트)
	local result = workspace:Raycast(
		Vector3.new(camPos.X, emitterY, camPos.Z),
		Vector3.new(0, -SCAN_HEIGHT, 0),
		rayParams
	)

	-- 충돌 지점과 수면 Y 중 더 높은 쪽을 "착지점"으로 사용
	-- → 바다 위에서는 수면이 착지점, 육지에서는 지면이 착지점
	local groundY = result and result.Position.Y or (emitterY - SCAN_HEIGHT)
	local floorY  = math.max(groundY, WATER_SURFACE_Y)

	local fallDist = math.max(emitterY - floorY, 1)
	local avgSpeed = (SNOW_SPEED_MIN + SNOW_SPEED_MAX) / 2
	local t        = fallDist / avgSpeed
	return NumberRange.new(t * 0.9, t * 1.05)
end

-- ── 루프 ────────────────────────────────────────────────────────────────────

local function connectLoop()
	updateRayParams()
	Emitter.Parent = workspace

	table.insert(connections, RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		local camPos = cam.CFrame.Position

		-- Emitter를 카메라 위 EMITTER_UP studs에 배치, 크기로 넓은 영역 커버
		Emitter.Size  = Vector3.new(EMITTER_HALF * 2, 1, EMITTER_HALF * 2)
		Emitter.CFrame = CFrame.new(camPos.X, camPos.Y + EMITTER_UP, camPos.Z)

		-- 주기적으로 Lifetime 재계산
		frame = frame + 1
		if frame >= UPDATE_PERIOD then
			frame = 0
			local emitterY = camPos.Y + EMITTER_UP
			PE.Lifetime = calcLifetime(emitterY)
		end
	end))
end

local function disconnectLoop()
	for _, c in ipairs(connections) do c:Disconnect() end
	connections = {}
	PE.Enabled = false
	Emitter.Parent = nil
	frame = 0
end

-- ── 공개 API ────────────────────────────────────────────────────────────────

local Snow = {}

function Snow:Enable(tweenInfo)
	if enabled then return end
	enabled = true
	connectLoop()

	if tweenInfo then
		-- Rate를 0→SNOW_RATE로 트윈 (NumberValue 경유)
		local nv = Instance.new("NumberValue")
		nv.Value = 0
		nv.Changed:Connect(function(v)
			PE.Rate = math.floor(v)
			PE.Enabled = v > 0
		end)
		TweenService:Create(nv, tweenInfo, { Value = SNOW_RATE }):Play()
	else
		PE.Rate    = SNOW_RATE
		PE.Enabled = true
	end
end

function Snow:Disable(tweenInfo)
	if not enabled then return end
	enabled = false

	if tweenInfo then
		local nv = Instance.new("NumberValue")
		nv.Value = SNOW_RATE
		nv.Changed:Connect(function(v)
			PE.Rate = math.floor(v)
			if v <= 0 then
				disconnectLoop()
			end
		end)
		TweenService:Create(nv, tweenInfo, { Value = 0 }):Play()
	else
		disconnectLoop()
	end
end

-- 캐릭터 리스폰 시 rayParams 갱신
player.CharacterAdded:Connect(function()
	task.wait(0.1)
	updateRayParams()
end)

return Snow
