local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("Main")
local serverTimeText = mainGui:FindFirstChild("ServerTimeText", true)

if not serverTimeText then return end

local getServerAge = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("GetServerAge")

local function formatTime(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("Server Time: %d:%02d:%02d", h, m, s)
	else
		return string.format("Server Time: %d:%02d", m, s)
	end
end

local serverAgeAtJoin = 0
local localTickAtJoin = 0

task.spawn(function()
	local ok, age = pcall(function() return getServerAge:InvokeServer() end)
	if ok and age then
		serverAgeAtJoin = age
		localTickAtJoin = tick()
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		if localTickAtJoin > 0 then
			local elapsed = serverAgeAtJoin + math.floor(tick() - localTickAtJoin)
			serverTimeText.Text = formatTime(elapsed)
		end
	end
end)
