-- Server script (place in ServerScriptService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Create RemoteEvent (run once)
local fishLockEvent = Instance.new("RemoteEvent")
fishLockEvent.Name = "FishLockEvent"
fishLockEvent.Parent = ReplicatedStorage

-- Request rate limiting to prevent spam/exploits
local playerCooldowns = {}
local COOLDOWN_TIME = 0.1 -- 0.1 second cooldown

-- Handle fish lock state change requests from client (with security)
fishLockEvent.OnServerEvent:Connect(function(player, tool, isLocked)
	-- Cooldown check (spam prevention)
	local currentTime = tick()
	local lastRequest = playerCooldowns[player.UserId] or 0

	if currentTime - lastRequest < COOLDOWN_TIME then
		warn(player.Name .. " - Fish lock request too fast (spam prevention)")
		return
	end
	playerCooldowns[player.UserId] = currentTime

	-- Basic validation
	if not tool or not tool:IsA("Tool") then
		warn(player.Name .. " - Invalid tool")
		return
	end

	if typeof(isLocked) ~= "boolean" then
		warn(player.Name .. " - Invalid lock state")
		return
	end

	-- Ownership validation (exploit prevention)
	if tool.Parent ~= player.Character and tool.Parent ~= player.Backpack then
		warn(player.Name .. " - Attempted to lock unowned tool: " .. tool.Name)
		return
	end

	-- Verify it is a fish
	if not tool:FindFirstChild("FishValue") then
		warn(player.Name .. " - Attempted to lock non-fish tool: " .. tool.Name)
		return
	end

	-- All checks passed - create/update BoolValue on server
	local lockValue = tool:FindFirstChild("FishLock")
	if not lockValue then
		lockValue = Instance.new("BoolValue")
		lockValue.Name = "FishLock"
		lockValue.Parent = tool
	end

	lockValue.Value = isLocked
end)

-- Clean up cooldown data when player leaves
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
end)
