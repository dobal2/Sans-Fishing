local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local player = game.Players.LocalPlayer
local mainGui = player.PlayerGui:WaitForChild("Main")

local shopButton = mainGui:WaitForChild("Free Reward")
local shopFrame = mainGui:WaitForChild("Free Reward Frame")
local shopShadowFrame = mainGui:FindFirstChild("ShadowFrame")
local clickSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("click")
local lighting = game:GetService("Lighting")
local blur = lighting:WaitForChild("ShopBlur")
local closeFrame = shopFrame:WaitForChild("Close")
local xButton = closeFrame:FindFirstChildOfClass("ImageButton") or closeFrame:FindFirstChildOfClass("TextButton")
local joinGroupFrame = shopFrame:WaitForChild("JoinGroup")
local joinGroupButton = joinGroupFrame:FindFirstChildOfClass("ImageButton") or joinGroupFrame:FindFirstChildOfClass("TextButton")
local camera = workspace.CurrentCamera

local GROUP_ID = 9744474

local originalFOV = camera.FieldOfView or 70
local expandedFOV = 60
local canClick = true
local isShopOpen = false

local function tweenFOV(targetFOV, duration)
	TweenService:Create(camera, TweenInfo.new(duration or 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = targetFOV}):Play()
end

local function toggleShop()
	if not canClick then return end
	canClick = false
	clickSound:Play()
	isShopOpen = not isShopOpen
	shopFrame.Visible = isShopOpen
	if shopShadowFrame then shopShadowFrame.Visible = isShopOpen end
	if isShopOpen then
		blur.Enabled = true
		tweenFOV(expandedFOV, 0.5)
	else
		blur.Enabled = false
		tweenFOV(originalFOV, 0.5)
	end
	task.wait(0.5)
	canClick = true
end

shopButton.MouseButton1Click:Connect(toggleShop)
if xButton then
	xButton.MouseButton1Click:Connect(function()
		if isShopOpen then toggleShop() end
	end)
end
if joinGroupButton then
	joinGroupButton.MouseButton1Click:Connect(function()
		local GroupService = game:GetService("GroupService")
		task.spawn(function()
			pcall(function()
				GroupService:PromptJoinAsync(GROUP_ID)
			end)
		end)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isShopOpen then
		toggleShop()
	end
end)

local function updateOriginalFOV()
	if not isShopOpen then originalFOV = camera.FieldOfView end
end

game.Players.LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	updateOriginalFOV()
end)

local lastFOV = camera.FieldOfView
RunService.Heartbeat:Connect(function()
	if not isShopOpen and camera.FieldOfView ~= lastFOV then
		lastFOV = camera.FieldOfView
		originalFOV = camera.FieldOfView
	end
end)

game.Players.LocalPlayer.AncestryChanged:Connect(function()
	if isShopOpen then
		blur.Enabled = false
		camera.FieldOfView = originalFOV
	end
end)

shopFrame.Visible = false
if shopShadowFrame then shopShadowFrame.Visible = false end
isShopOpen = false
blur.Enabled = false
