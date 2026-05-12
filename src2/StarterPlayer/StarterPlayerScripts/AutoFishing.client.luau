local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local AUTO_CAST_COOLDOWN = 1.5
local AUTO_CLICK_COOLDOWN = 2.0  -- cooldown after hitting zone
local EQUIP_DELAY = 1.0          -- delay after equipping rod before first cast

local lastCastTime = 0
local lastClickTime = 0
local equipTime = 0

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
	watchEquip(char)
end)
if player.Character then
	equipTime = tick()
	watchEquip(player.Character)
end

RunService.Heartbeat:Connect(function()
	if not isAutoOn() then return end

	local now = tick()
	local gui = getFishingGui()

	if gui then
		-- Minigame open: click when slider in zone, with cooldown
		if now - lastClickTime < AUTO_CLICK_COOLDOWN then return end
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
		-- No minigame: auto cast with cooldowns
		if now - lastCastTime < AUTO_CAST_COOLDOWN then return end
		if now - equipTime < EQUIP_DELAY then return end
		if player:GetAttribute("IsFishing") == true then return end

		local tool = getCurrentRodTool()
		if not tool then return end

		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end

		lastCastTime = now
		local autoCastEvent = tool:FindFirstChild("AutoCastEvent")
		if autoCastEvent then
			autoCastEvent:Fire()
		end
	end
end)
