local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local WeatherSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeatherSystemModule"))

WeatherSystem.Initialize()
task.wait(1)

-- Admins allowed to use weather chat commands
local ADMIN_USERS = { "tallmo_bim", "mkdoingsu" }

local function isAdmin(playerName)
	for _, name in ipairs(ADMIN_USERS) do
		if playerName == name then return true end
	end
	return false
end

-- Handle /rain /snow /firework /clear chat commands for admins
local function handleAdminCommand(player, message)
	local args = string.split(message, " ")
	local command = args[1]:lower()
	local weatherEvent = ReplicatedStorage:FindFirstChild("WeatherChangedEvent")

	local weatherMap = {
		["/rain"]     = { name = "Rain",     default = 600 },
		["/snow"]     = { name = "Snow",     default = 600 },
		["/firework"] = { name = "Firework", default = 600 },
		["/clear"]    = { name = "Clear",    default = 0   },
	}

	local entry = weatherMap[command]
	if not entry then return end

	local duration = tonumber(args[2]) or entry.default
	local ok = WeatherSystem.SetWeather(entry.name, duration)
	if ok and weatherEvent then
		weatherEvent:FireClient(player, entry.name)
	elseif not ok then
		warn("Failed to set weather:", entry.name)
	end
end

local function connectAdminCommands(player)
	if isAdmin(player.Name) then
		player.Chatted:Connect(function(msg)
			handleAdminCommand(player, msg)
		end)
	end
end

for _, player in pairs(Players:GetPlayers()) do
	connectAdminCommands(player)
end
Players.PlayerAdded:Connect(connectAdminCommands)
