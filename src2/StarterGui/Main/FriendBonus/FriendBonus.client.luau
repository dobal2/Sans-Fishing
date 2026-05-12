local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local textLabel = script.Parent
local getFriendsCountRemote = ReplicatedStorage:WaitForChild("GetFriendsCountRemote")

local function updateFriendBonus()
	local success, friendsCount = pcall(function()
		return getFriendsCountRemote:InvokeServer()
	end)
	if success and friendsCount then
		local bonusPercent = friendsCount * 5
		textLabel.Text = string.format("FriendBonus: +%d%%", bonusPercent)
	else
		textLabel.Text = "FriendBonus: +0%"
	end
end

local lastUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastUpdate >= 5 then
		lastUpdate = now
		updateFriendBonus()
	end
end)

updateFriendBonus()
