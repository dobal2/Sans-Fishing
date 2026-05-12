-- ServerScriptService/WeatherController.lua
-- Server script that automatically starts the weather system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Load modules safely
local modules = ReplicatedStorage:WaitForChild("Modules")
local WeatherSystem = require(modules:WaitForChild("WeatherSystemModule"))

-- FishData module is optional (weather system works without it)
local FishData = nil
local fishDataModule = modules:FindFirstChild("FishDataModule")
if fishDataModule then
	FishData = require(fishDataModule)
else
	warn("FishDataModule not found. Fish testing will be disabled.")
end

-- Initialize weather system (starts 20-minute cycle + creates RemoteEvents)
WeatherSystem.Initialize()

-- Wait for initialization to complete
wait(1)

-- Admin account list
local allowedUsers = {"tallmo_bim", "mkdoingsu"}

-- Admin check function
local function isAdmin(playerName)
	for _, allowedUser in ipairs(allowedUsers) do
		if playerName == allowedUser then
			return true
		end
	end
	return false
end

-- Test commands (for development use only)
local function setupTestCommands()
	-- Apply to already connected players
	for _, player in pairs(Players:GetPlayers()) do
		if isAdmin(player.Name) then
			player.Chatted:Connect(function(message)
				handleAdminCommand(player, message)
			end)
		end
	end

	-- Apply to newly joining players
	Players.PlayerAdded:Connect(function(player)
		-- Check admin permission
		if isAdmin(player.Name) then
			player.Chatted:Connect(function(message)
				handleAdminCommand(player, message)
			end)
		end
	end)
end

-- Admin command handler
function handleAdminCommand(player, message)
	local args = string.split(message, " ")
	local command = args[1]:lower()

	if command == "/rain" then
		local duration = tonumber(args[2]) or 600
		local success = WeatherSystem.SetWeather("Rain", duration)
		if success then
			game:GetService("ReplicatedStorage").WeatherChangedEvent:FireClient(player, "Rain")
		else
			warn("Failed to set rain weather")
		end

	elseif command == "/snow" then
		local duration = tonumber(args[2]) or 600
		local success = WeatherSystem.SetWeather("Snow", duration)
		if success then
			game:GetService("ReplicatedStorage").WeatherChangedEvent:FireClient(player, "Snow")
		else
			warn("Failed to set snow weather")
		end

	elseif command == "/firework" then
		local duration = tonumber(args[2]) or 600
		local success = WeatherSystem.SetWeather("Firework", duration)
		if success then
			game:GetService("ReplicatedStorage").WeatherChangedEvent:FireClient(player, "Firework")
		else
			warn("Failed to set firework weather")
		end

	elseif command == "/clear" then
		local success = WeatherSystem.SetWeather("Clear", 0)
		if success then
			game:GetService("ReplicatedStorage").WeatherChangedEvent:FireClient(player, "Clear")
		else
			warn("Failed to clear weather")
		end

	elseif command == "/weather" then
		local info = WeatherSystem.GetCurrentWeatherInfo()
	else
		-- Ignore normal chat
		return
	end
end

-- Activate test commands (development only)
setupTestCommands()

-- Debug: check system status every 5 seconds
spawn(function()
	while true do
		wait(5)
		local info = WeatherSystem.GetCurrentWeatherInfo()
		if info then
			-- Only print when status changes
			local statusText = string.format("[%s] %s",
				info.isActive and "Active" or "Idle",
				info.currentWeather)
			-- print(statusText) -- Commented out to avoid excessive output
		end
	end
end)
