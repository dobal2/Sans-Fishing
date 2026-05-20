local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local fishLockEvent = Instance.new("RemoteEvent")
fishLockEvent.Name = "FishLockEvent"
fishLockEvent.Parent = ReplicatedStorage

local playerCooldowns = {}
local COOLDOWN_TIME = 0.1

-- FishLockBindable: tells ItemSave to update lock state in PlayerFishData
local FishLockBindable = nil
task.spawn(function()
	FishLockBindable = ServerScriptService:WaitForChild("FishLockBindable", 30)
end)

-- client fires: (tool_or_nil, isLocked, fishIndex)
-- tool may be nil when the fish is not currently equipped (data-only mode)
fishLockEvent.OnServerEvent:Connect(function(player, toolOrIndex, isLocked, fishIndex)
	local currentTime = tick()
	if (playerCooldowns[player.UserId] or 0) + COOLDOWN_TIME > currentTime then return end
	playerCooldowns[player.UserId] = currentTime

	if typeof(isLocked) ~= "boolean" then return end

	-- If a real Tool instance was passed and it is owned by this player, update BoolValue on it too
	if typeof(toolOrIndex) == "Instance" and toolOrIndex:IsA("Tool") then
		local tool = toolOrIndex
		if tool.Parent ~= player.Character and tool.Parent ~= player.Backpack then
			warn(player.Name .. " - Attempted to lock unowned tool")
			return
		end
		if not tool:FindFirstChild("FishValue") then return end

		local lockValue = tool:FindFirstChild("FishLock")
		if not lockValue then
			lockValue = Instance.new("BoolValue")
			lockValue.Name = "FishLock"
			lockValue.Parent = tool
		end
		lockValue.Value = isLocked
	end

	-- Always update PlayerFishData via FishLockBindable (index-based)
	if FishLockBindable and type(fishIndex) == "number" and fishIndex >= 1 and fishIndex == math.floor(fishIndex) then
		FishLockBindable:Fire(player, fishIndex, isLocked)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
end)
