local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RemoteEvent 생성 (최초 1회만)
local platformEvent = Instance.new("RemoteEvent")
platformEvent.Name = "PlatformEvent"
platformEvent.Parent = ReplicatedStorage

-- 플레이어별 플랫폼 저장 테이블
local playerPlatforms = {}

platformEvent.OnServerEvent:Connect(function(player, platformName)
	playerPlatforms[player.UserId] = platformName
end)

-- RemoteFunction 생성 (플랫폼 요청용)
local platformRequest = Instance.new("RemoteFunction")
platformRequest.Name = "PlatformRequest"
platformRequest.Parent = ReplicatedStorage

platformRequest.OnServerInvoke = function(player)
	return playerPlatforms[player.UserId] or "Unknown"
end
