local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteEvent (once only)
local platformEvent = Instance.new("RemoteEvent")
platformEvent.Name = "PlatformEvent"
platformEvent.Parent = ReplicatedStorage

-- Table to store platform per player
local playerPlatforms = {}

platformEvent.OnServerEvent:Connect(function(player, platformName)
	playerPlatforms[player.UserId] = platformName
end)

-- Create RemoteFunction (for platform requests)
local platformRequest = Instance.new("RemoteFunction")
platformRequest.Name = "PlatformRequest"
platformRequest.Parent = ReplicatedStorage

platformRequest.OnServerInvoke = function(player)
	return playerPlatforms[player.UserId] or "Unknown"
end
