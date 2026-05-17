local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- DataReady 대기 후에 SeenUpdateLog를 읽어야 정확한 저장값을 확인할 수 있음
player:WaitForChild("DataReady", 30)

local seenFlag = player:WaitForChild("SeenUpdateLog", 30)
if not seenFlag or seenFlag.Value then return end

local setSeenRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("SetSeenUpdateLog")
setSeenRemote:FireServer()

task.wait(1.5)

local main = playerGui:WaitForChild("Main")
local updateLog = main:WaitForChild("UpdateLog")
local closeFrame = updateLog:WaitForChild("Close")
local closeBtn = closeFrame:FindFirstChildOfClass("ImageButton") or closeFrame:FindFirstChildOfClass("TextButton")
local uiScale = updateLog:FindFirstChild("UIScale")

if not uiScale then
	uiScale = Instance.new("UIScale")
	uiScale.Parent = updateLog
end

uiScale.Scale = 0
updateLog.Visible = true

TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

local function closeLog()
	local t = TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0})
	t:Play()
	t.Completed:Connect(function()
		updateLog.Visible = false
	end)
end

if closeBtn then
	closeBtn.Activated:Connect(closeLog)
end

-- Close 프레임 자체의 ButtonTween 스크립트가 있을 경우를 대비해 전체 Close 영역도 연결
closeFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closeLog()
	end
end)
