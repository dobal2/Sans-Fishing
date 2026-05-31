local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local soldNotification = ReplicatedStorage:WaitForChild("Remotes")
	:WaitForChild("Sell")
	:WaitForChild("SoldNotification")

local coinTemplate    = ReplicatedStorage:WaitForChild("Models"):WaitForChild("Coin")
local soundOut        = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("VisualCoinOut")
local soundCollect    = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("CoinVisualCollect")

local SPREAD        = 7
local ARC_HEIGHT    = 8
local FLY_OUT_TIME  = 0.45
local HOVER_TIME    = 0.15
local RETURN_TIME   = 0.35

-- 웨이브 스폰 설정
local WAVE_DURATION = 3.0   -- 최대 분산 시간 (초)
local WAVE_MIN_AMOUNT = 500 -- 이 금액 이상이면 웨이브 모드

local function setCoinPosition(coin, pos)
	if coin:IsA("BasePart") then
		coin.Position = pos
	elseif coin:IsA("Model") then
		coin:PivotTo(CFrame.new(pos))
	end
end

local function getCoinPosition(coin)
	if coin:IsA("BasePart") then
		return coin.Position
	elseif coin:IsA("Model") then
		return coin:GetPivot().Position
	end
	return Vector3.zero
end

local function arcPosition(s, e, alpha, height)
	local mid = (s + e) / 2 + Vector3.new(0, height, 0)
	return s:Lerp(mid, alpha):Lerp(mid:Lerp(e, alpha), alpha)
end

local function animateOut(coin, startPos, endPos, onDone)
	local eTime = 0
	local conn
	conn = RunService.PreRender:Connect(function(dt)
		eTime += dt
		local t = math.min(eTime / FLY_OUT_TIME, 1)
		local ease = 1 - (1 - t) ^ 3
		local pos = arcPosition(startPos, endPos, ease, ARC_HEIGHT)
		setCoinPosition(coin, pos)
		if t >= 1 then
			conn:Disconnect()
			onDone()
		end
	end)
end

local function animateReturn(coin, target, onDone)
	local startPos = getCoinPosition(coin)
	local eTime = 0
	local conn
	conn = RunService.PreRender:Connect(function(dt)
		eTime += dt
		local t = math.min(eTime / RETURN_TIME, 1)
		local ease = t ^ 4
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local dest = root and (root.Position + Vector3.new(0, 1, 0)) or target
		local pos = startPos:Lerp(dest, ease)
		setCoinPosition(coin, pos)
		if t >= 1 then
			conn:Disconnect()
			onDone()
		end
	end)
end

local function getRandomEndPosition(origin)
	local dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
	local dist = SPREAD * (0.6 + math.random() * 0.6)
	local pos = origin + dir * dist

	local rayParams = RaycastParams.new()
	local char = player.Character
	if char then rayParams.FilterDescendantsInstances = { char } end

	local result = workspace:Raycast(pos + Vector3.new(0, 15, 0), Vector3.new(0, -40, 0), rayParams)
	if result then
		return Vector3.new(pos.X, result.Position.Y + 0.6, pos.Z)
	end
	return Vector3.new(pos.X, origin.Y, pos.Z)
end

local function spawnCoin(origin, delay)
	task.delay(delay, function()
		local char = player.Character
		if not char then return end

		local coin = coinTemplate:Clone()

		if coin:IsA("BasePart") then
			coin.Position = origin
			coin.Anchored = true
			coin.CanCollide = false
		elseif coin:IsA("Model") then
			coin:PivotTo(CFrame.new(origin))
			for _, p in ipairs(coin:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CanCollide = false
				end
			end
		end
		coin.Parent = workspace

		local endPos = getRandomEndPosition(origin)

		soundOut:Play()
		animateOut(coin, origin, endPos, function()
			task.delay(HOVER_TIME, function()
				if not coin.Parent then return end
				soundCollect:Play()
				animateReturn(coin, origin, function()
					coin:Destroy()
				end)
			end)
		end)
	end)
end

-- 지수적으로 간격이 늘어나는 딜레이 생성
-- i=1이면 0초, i=count이면 duration초에 가까움
-- t = (e^(i/count) - 1) / (e - 1) 형태 → 앞은 촘촘, 뒤는 성김
local function exponentialDelay(i, count, duration)
	if count <= 1 then return 0 end
	local t = (math.exp((i - 1) / (count - 1)) - 1) / (math.exp(1) - 1)
	return t * duration
end

local function spawnCoinEffect(amount)
	if amount <= 0 then return end

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local origin = root.Position + Vector3.new(0, 2, 0)

	-- 초반 억제, 후반 급증: 1K→4개, 100K→22개, 1M→47개, 10M→80개
	local logMax = math.log(10000000 / 300 + 1)
	local t = math.clamp(math.log(amount / 300 + 1) / logMax, 0, 1)
	local count = math.clamp(math.floor(t ^ 2.5 * 77) + 3, 1, 80)

	-- 웨이브: 500원부터 시작, 천만원에서 3초 꽉 참
	local duration = 0
	if amount >= WAVE_MIN_AMOUNT then
		local ratio = math.clamp(math.log(amount / WAVE_MIN_AMOUNT + 1, 10000000 / WAVE_MIN_AMOUNT + 1), 0, 1)
		duration = ratio * WAVE_DURATION
	end

	for i = 1, count do
		local delay = exponentialDelay(i, count, duration)
		spawnCoin(origin, delay)
	end
end

soldNotification.OnClientEvent:Connect(function(amount, isPreview)
	if isPreview then return end
	spawnCoinEffect(amount)
end)
