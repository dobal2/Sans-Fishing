local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LATEST_VERSION = 2

local UPDATE_DATA = {
	[1] = {
		label = "Update 1",
		desc = [[🎣 Update Notes

<font color="#00ff88">• All rod models reworked (except Void Rod &amp; Friend Rod)</font>
<font color="#00ff88">• Fishing system &amp; animations reworked</font>
<font color="#00ff88">• All rod stats rebalanced</font>
<font color="#00ff88">• Skill Tree added</font>
<font color="#00ff88">• Donation Leaderboard moved from the map into the in-game UI</font>
<font color="#ff4444">• Void Rod is now Limited</font>
<font color="#ff4444">• Enchants removed (may return in a future update)</font>
<font color="#ff4444">• Boats removed (may return in a future update)</font>
<font color="#ff4444">• Snow Island removed (returning as World 2 in a future update)</font>
<font color="#ff4444">• All Fish Traps nerfed — each trap now takes 10 minutes to catch one fish</font>]],
	},
	[2] = {
		label = "Update 2",
		desc = [[🎣 Update Notes

<font color="#00ff88">• Collect Fish Trap button added — pick up your trap while holding it</font>
<font color="#00ff88">• All Fish Traps buffed — online catch interval reduced to 5 minutes</font>
<font color="#00ff88">• Fish Trap steal system added — purchase to steal all fish from another player's trap</font>
<font color="#00ff88">• FishingPoint x2 gamepass added</font>]],
	},
}

local lastSeenVal = player:WaitForChild("LastSeenUpdateVersion", 60)
if not lastSeenVal then return end

local currentVersion = lastSeenVal.Value
if currentVersion >= LATEST_VERSION then return end

local setSeenRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("SetSeenUpdateVersion")
setSeenRemote:FireServer(LATEST_VERSION)

task.wait(1.5)

local main = playerGui:WaitForChild("Main")
local updateLog = main:WaitForChild("UpdateLog")
local desc = updateLog:WaitForChild("Desc")
local categories = updateLog:WaitForChild("Categories")
local template = categories:WaitForChild("VersionButton")
local closeFrame = updateLog:WaitForChild("Close")
local closeBtn = closeFrame:FindFirstChildOfClass("ImageButton") or closeFrame:FindFirstChildOfClass("TextButton")
local uiScale = updateLog:FindFirstChild("UIScale")

if not uiScale then
	uiScale = Instance.new("UIScale")
	uiScale.Parent = updateLog
end

template.Visible = false

local buttons = {}
for i = LATEST_VERSION, 1, -1 do
	local data = UPDATE_DATA[i]
	if not data then continue end

	local btn = template:Clone()
	btn.Name = "VersionButton_" .. i
	btn.Visible = true
	btn.Parent = categories

	local label = btn:FindFirstChildWhichIsA("TextLabel")
	if label then label.Text = data.label end

	table.insert(buttons, { frame = btn, version = i })
end

local function selectVersion(version)
	local data = UPDATE_DATA[version]
	if data then desc.Text = data.desc end

	for _, entry in ipairs(buttons) do
		local imgBtn = entry.frame:FindFirstChildOfClass("ImageButton")
		local glow = entry.frame:FindFirstChild("Glow")
		local isSelected = entry.version == version
		if imgBtn then
			local grad = imgBtn:FindFirstChildOfClass("UIGradient")
			if grad then
				if isSelected then
					grad.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 200, 120)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 140, 80)),
					})
				else
					grad.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 60, 80)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 40, 60)),
					})
				end
			end
		end
		if glow then
			glow.ImageColor3 = Color3.fromRGB(255, 255, 255)
			glow.ImageTransparency = isSelected and 0.3 or 1
		end
	end
end

for _, entry in ipairs(buttons) do
	local imgBtn = entry.frame:FindFirstChildOfClass("ImageButton")
	if imgBtn then
		local v = entry.version
		imgBtn.Activated:Connect(function()
			selectVersion(v)
		end)
	end
end

selectVersion(LATEST_VERSION)

uiScale.Scale = 0
updateLog.Visible = true
TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

local function closeLog()
	local t = TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
	t:Play()
	t.Completed:Connect(function()
		updateLog.Visible = false
	end)
end

if closeBtn then
	closeBtn.Activated:Connect(closeLog)
end

closeFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closeLog()
	end
end)
