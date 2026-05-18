local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local saveAutoFishing = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("SaveAutoFishing")
local mainGui = player.PlayerGui:WaitForChild("Main")
local frame = mainGui:WaitForChild("AutoButton")
local button = frame:WaitForChild("TextButton")
local onGradient  = button:WaitForChild("OnUIGradient")
local offGradient = button:WaitForChild("OffUIGradient")
local uiScale = frame:WaitForChild("UIScale")
local glow = frame:WaitForChild("Glow")

local isAuto = false

local GLOW_ON_COLOR  = Color3.fromRGB(0, 180, 255)
local GLOW_OFF_COLOR = Color3.fromRGB(255, 255, 255)

local HOVER_IN  = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HOVER_OUT = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function setAutoState(on, skipSave)
	isAuto = on
	player:SetAttribute("AutoFishing", on)
	if not skipSave then
		saveAutoFishing:FireServer(on)
	end

	onGradient.Enabled  = on
	offGradient.Enabled = not on

	if on then
		TweenService:Create(glow, TweenInfo.new(0.3), {ImageTransparency = 0.3, ImageColor3 = GLOW_ON_COLOR}):Play()
	else
		TweenService:Create(glow, TweenInfo.new(0.3), {ImageTransparency = 0.65, ImageColor3 = GLOW_OFF_COLOR}):Play()
	end

	uiScale.Scale = 1.15
	TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

button.MouseEnter:Connect(function()
	TweenService:Create(uiScale, HOVER_IN, {Scale = 1.08}):Play()
end)
button.MouseLeave:Connect(function()
	TweenService:Create(uiScale, HOVER_OUT, {Scale = 1}):Play()
end)
button.MouseButton1Click:Connect(function()
	setAutoState(not isAuto)
end)

local function hasAutoFishSkill()
	local skillsFolder = player:FindFirstChild("Skills")
	local sv = skillsFolder and skillsFolder:FindFirstChild("AutoFish")
	return sv and sv.Value >= 1
end

local function updateVisibility()
	local char = player.Character
	if not char then frame.Visible = false; return end
	if not hasAutoFishSkill() then frame.Visible = false; return end
	local hasFishingRod = false
	for _, obj in ipairs(char:GetChildren()) do
		if obj:IsA("Tool") and obj:FindFirstChild("CastRod") then
			hasFishingRod = true
			break
		end
	end
	frame.Visible = hasFishingRod
end

local function watchCharacter(char)
	updateVisibility()
	char.ChildAdded:Connect(updateVisibility)
	char.ChildRemoved:Connect(updateVisibility)
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then watchCharacter(player.Character) end

-- AutoFish 스킬 해금 시 즉시 반영
local function watchSkills(skillsFolder)
	local sv = skillsFolder:FindFirstChild("AutoFish")
	if sv then
		sv:GetPropertyChangedSignal("Value"):Connect(updateVisibility)
	else
		skillsFolder.ChildAdded:Connect(function(child)
			if child.Name == "AutoFish" then
				child:GetPropertyChangedSignal("Value"):Connect(updateVisibility)
				updateVisibility()
			end
		end)
	end
end

local skillsFolder = player:FindFirstChild("Skills")
if skillsFolder then
	watchSkills(skillsFolder)
else
	player.ChildAdded:Connect(function(child)
		if child.Name == "Skills" then watchSkills(child) end
	end)
end

-- 외부(AutoFishing.client)에서 attribute를 직접 켤 경우 UI 동기화
player.AttributeChanged:Connect(function(attr)
	if attr == "AutoFishing" then
		local val = player:GetAttribute("AutoFishing") == true
		if val ~= isAuto then
			setAutoState(val, true)
		end
	end
end)

setAutoState(false, true)
frame.Visible = false
