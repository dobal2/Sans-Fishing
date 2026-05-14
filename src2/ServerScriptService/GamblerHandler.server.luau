-- Handles Gambler NPC ProximityPrompt and gamble choice logic.
-- Moved from workspace.Gambler.ProximityPrompt.Gamble

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")

local gambleChoiceEvent       = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("GambleChoiceEvent")
local enablePromptEvent       = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SetPromptEvent")
local gambleNotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("GambleNotification")

local WeatherSystemModule = nil
pcall(function()
	WeatherSystemModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeatherSystemModule"))
end)

local FishIceEffect = nil
pcall(function()
	local iceModule = ReplicatedStorage:WaitForChild("Modules"):FindFirstChild("FishIceEffectModule")
	if iceModule then FishIceEffect = require(iceModule) end
end)

local FishData = nil
pcall(function()
	local fishDataModule = ReplicatedStorage:WaitForChild("Modules"):FindFirstChild("FishDataModule")
	if fishDataModule then FishData = require(fishDataModule) end
end)

local GAMBLE_COST          = 4000
local FROZEN_CHANCE        = 0.025
local FESTIVAL_CHANCE      = 0.04
local WEIGHT_DECREASE_MIN  = 1
local WEIGHT_DECREASE_MAX  = 2.5
local WEIGHT_INCREASE_MIN  = 1
local WEIGHT_INCREASE_MAX  = 2
local MIN_WEIGHT           = 1.0
local MAX_WEIGHT           = 200

local GAMBLE_COOLDOWN  = 1
local PROMPT_COOLDOWN  = 0.5

local ICE_SETTINGS = {
	material = Enum.Material.Ice,
	transparency = 0.3,
	color = Color3.fromRGB(200, 240, 255),
	size_multiplier = 1.05,
	glow_intensity = 0.3,
}

local lastGambleTime = {}
local lastPromptTime = {}
local activeUsers = {}

Players.PlayerRemoving:Connect(function(player)
	lastGambleTime[player.UserId] = nil
	lastPromptTime[player.UserId] = nil
	activeUsers[player] = nil
end)

local function isGamblableFish(tool)
	if not tool:IsA("Tool") then return false end
	local value = tool:FindFirstChild("FishValue")
	local weight = tool:FindFirstChild("FishWeight")
	return value and value.Value > 0 and weight
end

local function removeExistingMutations(fishName)
	local name = fishName
	name = name:gsub("^Frozen Festival ", "")
	name = name:gsub("^Festival Frozen ", "")
	name = name:gsub("^Frozen ", "")
	name = name:gsub("^Festival ", "")
	return name
end

local function hasFrozenPrefix(name)
	return string.find(name, "^Frozen ") or string.find(name, "Frozen Festival") or string.find(name, "Festival Frozen")
end

local function hasFestivalPrefix(name)
	return string.find(name, "^Festival ") or string.find(name, "Frozen Festival") or string.find(name, "Festival Frozen")
end

local function removeIceEffect(tool)
	local ice = tool:FindFirstChild("IceBlock")
	if ice then ice:Destroy() end
	tool:SetAttribute("HasIceEffect", nil)
	tool:SetAttribute("IceAppliedTime", nil)
end

local function removeFestivalEffect(tool)
	local handle = tool:FindFirstChild("Handle")
	if handle then
		local fx = handle:FindFirstChild("FestivalEffect")
		if fx then fx:Destroy() end
	end
	tool:SetAttribute("HasFestivalEffect", nil)
	tool:SetAttribute("FestivalAppliedTime", nil)
end

local function applyIceEffectDirect(tool, info)
	if not tool or not info then return end
	if tool:FindFirstChild("IceBlock") then return end
	local handle = tool:FindFirstChild("Handle")
	if not handle then return end
	local sizeMultiplier = ICE_SETTINGS.size_multiplier * (1 + ((info.weight or 1) - 1) * 0.01)
	sizeMultiplier = math.clamp(sizeMultiplier, 0.9, 1.5)
	local ice = Instance.new("Part")
	ice.Name = "IceBlock"
	ice.Anchored = false
	ice.CanCollide = false
	ice.Massless = true
	ice.Size = handle.Size * sizeMultiplier
	ice.CFrame = handle.CFrame
	ice.Shape = Enum.PartType.Block
	ice.Material = ICE_SETTINGS.material
	ice.Transparency = ICE_SETTINGS.transparency
	ice.Color = ICE_SETTINGS.color
	local light = Instance.new("PointLight")
	light.Color = ICE_SETTINGS.color
	light.Brightness = ICE_SETTINGS.glow_intensity
	light.Range = handle.Size.Magnitude * 1.5
	light.Parent = ice
	ice.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = ice
	weld.Parent = ice
	tool:SetAttribute("HasIceEffect", true)
	tool:SetAttribute("IceAppliedTime", tick())
end

local function getWeatherMultipliers()
	local frozenMult = 2.0
	local festivalMult = 1.5
	if WeatherSystemModule and WeatherSystemModule.WeatherTypes then
		local snow = WeatherSystemModule.WeatherTypes.Snow
		if snow and snow.effects then
			frozenMult = snow.effects.valueMultiplier or 2.0
		end
		local firework = WeatherSystemModule.WeatherTypes.Firework
		if firework and firework.effects then
			festivalMult = firework.effects.valueMultiplier or 1.5
		end
	end
	return frozenMult, festivalMult
end

local function applyMutations(originalName, tool, weight)
	removeIceEffect(tool)
	removeFestivalEffect(tool)
	local cleanName = removeExistingMutations(originalName)
	local rng = Random.new()
	local willBeFrozen = rng:NextNumber() <= FROZEN_CHANCE
	local willBeFestival = rng:NextNumber() <= FESTIVAL_CHANCE
	local newName = cleanName
	if willBeFrozen and willBeFestival then
		newName = rng:NextNumber() > 0.5 and ("Frozen Festival " .. cleanName) or ("Festival Frozen " .. cleanName)
	elseif willBeFrozen then
		newName = "Frozen " .. cleanName
	elseif willBeFestival then
		newName = "Festival " .. cleanName
	end
	task.spawn(function()
		task.wait(0.1)
		local info = { fishName = newName, weight = weight }
		if willBeFrozen then
			if FishIceEffect then
				pcall(function() FishIceEffect.ApplyIceEffect(tool, info) end)
			else
				applyIceEffectDirect(tool, info)
			end
		end
		if willBeFestival and FishData then
			pcall(function() FishData.ApplyFestivalEffect(tool, info) end)
		end
	end)
	return newName, willBeFrozen, willBeFestival
end

local function calculateWeightChange(current)
	local rng = Random.new()
	if rng:NextNumber() < 0.45 then
		local delta = rng:NextNumber(WEIGHT_INCREASE_MIN, WEIGHT_INCREASE_MAX)
		return math.min(MAX_WEIGHT, math.floor((current + delta) * 10 + 0.5) / 10)
	else
		local delta = rng:NextNumber(WEIGHT_DECREASE_MIN, WEIGHT_DECREASE_MAX)
		return math.max(MIN_WEIGHT, math.floor((current - delta) * 10 + 0.5) / 10)
	end
end

local function calculateUnifiedPrice(fishValue, oldWeight, newWeight, wasFrozen, wasFestival, willBeFrozen, willBeFestival)
	local originalBase = fishValue:GetAttribute("OriginalBaseValue")
	if not originalBase then
		local currentPrice = fishValue.Value
		local oldRatio = math.clamp((oldWeight - MIN_WEIGHT) / (MAX_WEIGHT - MIN_WEIGHT), 0, 1)
		local oldWeightMult = 1.2 + math.pow(oldRatio, 0.8) * 7.0
		local frozenMult, festivalMult = getWeatherMultipliers()
		local oldMutMult = 1.0
		if wasFrozen and wasFestival then oldMutMult = frozenMult * festivalMult
		elseif wasFrozen then oldMutMult = frozenMult
		elseif wasFestival then oldMutMult = festivalMult end
		originalBase = math.floor(currentPrice / (oldWeightMult * oldMutMult))
		fishValue:SetAttribute("OriginalBaseValue", originalBase)
	end
	local newRatio = math.clamp((newWeight - MIN_WEIGHT) / (MAX_WEIGHT - MIN_WEIGHT), 0, 1)
	local newWeightMult = 1.2 + math.pow(newRatio, 0.8) * 7.0
	local frozenMult, festivalMult = getWeatherMultipliers()
	local newMutMult = 1.0
	if willBeFrozen and willBeFestival then newMutMult = frozenMult * festivalMult
	elseif willBeFrozen then newMutMult = frozenMult
	elseif willBeFestival then newMutMult = festivalMult end
	return math.max(1, math.floor(originalBase * newWeightMult * newMutMult))
end

local function resizeFishHandle(tool, oldW, newW)
	local h = tool:FindFirstChild("Handle")
	if not h then return end
	local function getScale(w)
		local t = (math.clamp(w, MIN_WEIGHT, MAX_WEIGHT) - MIN_WEIGHT) / (MAX_WEIGHT - MIN_WEIGHT)
		return 1 + (5 - 1) * t
	end
	h.Size = (h.Size / getScale(oldW)) * getScale(newW)
end

local function extractFishInfo(name)
	return name:match("(.+) %[(.+)%] %- (.+)kg")
end

local function findHeldFish(player)
	if not player.Character then return nil end
	for _, tool in ipairs(player.Character:GetChildren()) do
		if isGamblableFish(tool) then return tool end
	end
	return nil
end

local function performGamble(player, tool)
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins or coins.Value < GAMBLE_COST then
		gambleNotificationEvent:FireClient(player, 0, true, "insufficient_coins")
		return
	end
	local fishName, rarity, weight = extractFishInfo(tool.Name)
	if not fishName or not weight then
		gambleNotificationEvent:FireClient(player, 0, true, "invalid_fish")
		return
	end
	weight = tonumber(weight)
	if not weight or weight <= 0 then
		gambleNotificationEvent:FireClient(player, 0, true, "invalid_fish")
		return
	end
	local fishValue = tool:FindFirstChild("FishValue")
	local fishWeight = tool:FindFirstChild("FishWeight")
	if not fishValue or not fishWeight then
		gambleNotificationEvent:FireClient(player, 0, true, "invalid_fish")
		return
	end
	coins.Value -= GAMBLE_COST
	pcall(function()
		AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, "Coins",
			GAMBLE_COST, coins.Value, "Gamble", "GambleFish")
	end)
	local wasFrozen = hasFrozenPrefix(fishName)
	local wasFestival = hasFestivalPrefix(fishName)
	local newWeight = calculateWeightChange(weight)
	local newName, willBeFrozen, willBeFestival = applyMutations(fishName, tool, newWeight)
	local newPrice = calculateUnifiedPrice(fishValue, weight, newWeight, wasFrozen, wasFestival, willBeFrozen, willBeFestival)
	fishValue.Value = newPrice
	fishWeight.Value = newWeight
	tool.Name = string.format("%s [%s] - %.1fkg", newName, rarity, newWeight)
	resizeFishHandle(tool, weight, newWeight)
	gambleNotificationEvent:FireClient(player, GAMBLE_COST, false, "success", {
		oldWeight = weight, newWeight = newWeight, newPrice = newPrice,
		wasFrozen = wasFrozen, willBeFrozen = willBeFrozen,
		wasFestival = wasFestival, willBeFestival = willBeFestival,
	})
end

local gamblerPrompt = nil

-- Wire ProximityPrompt
local function wireGambler()
	local gambler = workspace:WaitForChild("Gambler", 30)
	if not gambler then return end
	for _, d in ipairs(gambler:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			gamblerPrompt = d
			d.Triggered:Connect(function(player)
				local now = tick()
				if lastPromptTime[player.UserId] and now - lastPromptTime[player.UserId] < PROMPT_COOLDOWN then return end
				lastPromptTime[player.UserId] = now
				activeUsers[player] = true
			end)
			break
		end
	end
end

task.spawn(wireGambler)

enablePromptEvent.OnServerEvent:Connect(function(player, enabled, target)
	if target == "gambler" and gamblerPrompt then
		gamblerPrompt.Enabled = enabled
	end
end)

gambleChoiceEvent.OnServerEvent:Connect(function(player, choice)
	if not activeUsers[player] then return end
	local now = tick()
	if lastGambleTime[player.UserId] and now - lastGambleTime[player.UserId] < GAMBLE_COOLDOWN then return end
	lastGambleTime[player.UserId] = now

	local character = player.Character
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not character or not coins then return end

	if choice == "Option1" then
		local fish = findHeldFish(player)
		if fish then
			performGamble(player, fish)
		else
			gambleNotificationEvent:FireClient(player, 0, true, "no_fish")
		end
		activeUsers[player] = nil
	elseif choice == "Option2" then
		gambleNotificationEvent:FireClient(player, -1, true, "exit")
		activeUsers[player] = nil
	end
end)
