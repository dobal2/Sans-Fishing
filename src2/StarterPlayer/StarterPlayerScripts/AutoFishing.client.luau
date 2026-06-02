local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local AUTO_RECONNECT_TIME = 19 * 60  -- 19 minutes

local autoReconnectRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("AutoReconnectRequest")
local getAutoFishing = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("GetAutoFishing")

local function rotateCharacterForAuto()
	local char = player.Character
	if not char then return end
	if char:GetAttribute("AutoFishingRotated") == true then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end

	local pos = hrp.Position
	local currentAngle = math.atan2(hrp.CFrame.LookVector.X, hrp.CFrame.LookVector.Z)
	local newAngle = currentAngle + math.rad(90)
	hum.AutoRotate = false
	hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, newAngle, 0)
	char:SetAttribute("AutoFishingRotated", true)
	task.delay(0.25, function()
		if hum.Parent and player:GetAttribute("AutoFishing") ~= true then
			hum.AutoRotate = true
		end
	end)
end

-- 접속 시 auto 상태 복원
task.spawn(function()
	if not player.Character then player.CharacterAdded:Wait() end
	task.wait(3)
	local ok, autoOn, rodName = pcall(function()
		return getAutoFishing:InvokeServer()
	end)
	if not ok or not autoOn then return end
	-- 로드 equip
	local equippedRod = nil
	if rodName then
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			local rod = backpack:FindFirstChild(rodName)
			if rod then
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum:EquipTool(rod)
					equippedRod = rod
				end
			end
		end
	end
	-- 서버에서 FishingServer가 tool에 붙을 때까지 대기 (ServerInit attribute)
	if equippedRod then
		local timeout = 10
		while not equippedRod:GetAttribute("ServerInit") and timeout > 0 do
			task.wait(0.2)
			timeout -= 0.2
		end
	else
		task.wait(2)
	end
	rotateCharacterForAuto()
	task.wait(0.15)
	rotateCharacterForAuto()
	player:SetAttribute("AutoFishing", true)
end)

-- 19-minute AFK kick prevention timer (started after isAutoOn/getCurrentRodTool are defined below)
local afkTimer = 0

local mainGui = player:WaitForChild("PlayerGui"):WaitForChild("Main")
local rejoinTimer = mainGui:FindFirstChild("RejoinTimer")
if rejoinTimer then rejoinTimer.Visible = false end

local AUTO_CAST_COOLDOWN = 1.1   -- wait after IsFishing clears before next cast
local AUTO_CLICK_COOLDOWN_BASE = 1.5

local AUTO_UP_REDUCTIONS = { 0.1, 0.4, 0.8 }
local function getAutoClickCooldown()
	local folder = player:FindFirstChild("Skills")
	local sv = folder and folder:FindFirstChild("AutoUp")
	local level = sv and sv.Value or 0
	local reduction = (level > 0 and AUTO_UP_REDUCTIONS[level]) or 0
	return AUTO_CLICK_COOLDOWN_BASE - reduction
end
local EQUIP_DELAY = 1.0          -- delay after equipping rod before first cast
local AUTO_ENABLE_DELAY = 1.0    -- delay after enabling AutoFishing before first cast

local lastCastTime = 0
local lastClickTime = 0
local equipTime = 0
local fishingEndedAt = 0         -- tick() when IsFishing last became false
local minigameStartTime = 0      -- tick() when minigame GUI first appeared
local MINIGAME_CLICK_DELAY = 0.5 -- 미니게임 시작 후 최소 이 시간 지나야 자동 클릭 가능

local function isAutoOn()
	return player:GetAttribute("AutoFishing") == true
end

local function getCurrentRodTool()
	local char = player.Character
	if not char then return nil end
	for _, obj in ipairs(char:GetChildren()) do
		if obj:IsA("Tool") and obj:FindFirstChild("CastRod") then
			return obj
		end
	end
	return nil
end

local function getFishingGui()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return nil end
	for _, gui in ipairs(pg:GetChildren()) do
		if gui.Name == "FishingGui" and gui:IsA("ScreenGui") then
			return gui
		end
	end
	return nil
end

local function getSliderAndHitZone(gui)
	local gaugeFrame = gui:FindFirstChild("GaugeFrame")
	if not gaugeFrame then return nil, nil, nil end
	local inFrame = gaugeFrame:FindFirstChild("InFrame")
	if not inFrame then return nil, nil, nil end
	local slider  = inFrame:FindFirstChild("Slider")
	local hitZone = inFrame:FindFirstChild("HitZone")
	return slider, hitZone, hitZone and hitZone:FindFirstChild("StrongZone")
end

local function isSliderInZone(slider, zone)
	if not slider or not zone then return false end
	local sL = slider.AbsolutePosition.X
	local sR = sL + slider.AbsoluteSize.X
	local zL = zone.AbsolutePosition.X
	local zR = zL + zone.AbsoluteSize.X
	return sR > zL and sL < zR
end

-- Track equip time so first cast waits EQUIP_DELAY seconds
local function watchEquip(char)
	if not char then return end
	char.ChildAdded:Connect(function(obj)
		if obj:IsA("Tool") and obj:FindFirstChild("CastRod") then
			equipTime = tick()
		end
	end)
end

player.CharacterAdded:Connect(function(char)
	equipTime = tick()
	char:SetAttribute("AutoFishingRotated", false)
	watchEquip(char)
end)
if player.Character then
	equipTime = tick()
	player.Character:SetAttribute("AutoFishingRotated", false)
	watchEquip(player.Character)
end

-- Track when IsFishing clears so cooldown starts from that moment
player.AttributeChanged:Connect(function(attr)
	if attr == "IsFishing" and player:GetAttribute("IsFishing") == false then
		fishingEndedAt = tick()
	end
	if attr == "AutoFishing" and player:GetAttribute("AutoFishing") == true then
		rotateCharacterForAuto()
		local soon = tick() - AUTO_CAST_COOLDOWN + AUTO_ENABLE_DELAY
		lastCastTime = soon
		fishingEndedAt = soon
		equipTime = soon
		afkTimer = 0
	end
end)

-- AFK kick prevention: reconnect after 19 minutes of auto fishing
local lastTimerUpdate = 0
RunService.Heartbeat:Connect(function(dt)
	if isAutoOn() and getCurrentRodTool() then
		afkTimer = afkTimer + dt
		if rejoinTimer then
			rejoinTimer.Visible = true
			if tick() - lastTimerUpdate >= 1 then
				lastTimerUpdate = tick()
				local remaining = math.max(0, AUTO_RECONNECT_TIME - afkTimer)
				local mins = math.floor(remaining / 60)
				local secs = math.floor(remaining % 60)
				rejoinTimer.Text = string.format("Rejoin After: %d:%02d", mins, secs)
			end
		end
		if afkTimer >= AUTO_RECONNECT_TIME then
			afkTimer = 0
			local tool = getCurrentRodTool()
			autoReconnectRequest:FireServer(tool and tool.Name or nil)
		end
	else
		afkTimer = 0
		if rejoinTimer then
			rejoinTimer.Visible = false
		end
	end
end)

RunService.Heartbeat:Connect(function()
	if not isAutoOn() then return end

	local now = tick()
	local gui = getFishingGui()

	if gui then
		-- 미니게임 GUI가 처음 감지된 시점 기록
		if minigameStartTime == 0 then
			minigameStartTime = now
		end
		-- 미니게임 시작 직후엔 클릭 금지 (서버 gameStartTime 기준 0.3초 검사 통과 여유)
		if now - minigameStartTime < MINIGAME_CLICK_DELAY then return end
		-- Minigame open: click when slider in zone, with cooldown
		if now - lastClickTime < getAutoClickCooldown() then return end
		local slider, hitZone, strongZone = getSliderAndHitZone(gui)
		if slider and hitZone then
			if isSliderInZone(slider, strongZone) or isSliderInZone(slider, hitZone) then
				local tool = getCurrentRodTool()
				if tool then
					local autoClickEvent = tool:FindFirstChild("AutoClickEvent")
					if autoClickEvent then
						lastClickTime = now
						autoClickEvent:Fire()
					end
				end
			end
		end
	else
		-- GUI 없으면 다음 미니게임을 위해 타이머 리셋
		minigameStartTime = 0
		-- No minigame: auto cast with cooldowns
		if now - lastCastTime < AUTO_CAST_COOLDOWN then return end
		if now - fishingEndedAt < AUTO_CAST_COOLDOWN then return end
		if now - equipTime < EQUIP_DELAY then return end
		if player:GetAttribute("IsFishing") == true then return end

		local tool = getCurrentRodTool()
		if not tool then return end

		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end

		rotateCharacterForAuto()
		lastCastTime = now
		local autoCastEvent = tool:FindFirstChild("AutoCastEvent")
		if autoCastEvent then
			autoCastEvent:Fire()
		end
	end
end)
