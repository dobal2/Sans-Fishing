local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icon = require(ReplicatedStorage:WaitForChild("TopbarPlus"):WaitForChild("Icon"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Inventory icon ────────────────────────────────────────────────
local inventoryIcon = Icon.new()
	:setImage("rbxassetid://96943151264418")
	:setImageScale(1.1)
	:setLabel("Inventory")

local function getInventoryFrame()
	local inv = playerGui:FindFirstChild("Custom Inventory")
	return inv and inv:FindFirstChild("Inventory")
end

inventoryIcon:bindEvent("selected", function()
	local frame = getInventoryFrame()
	if frame then frame.Visible = true end
end)
inventoryIcon:bindEvent("deselected", function()
	local frame = getInventoryFrame()
	if frame then frame.Visible = false end
end)

-- ── Donation icon ─────────────────────────────────────────────────
local donationIcon = Icon.new()
	:setImage("rbxassetid://11560341132")
	:setImageScale(0.8)
	:setLabel("Donation")

local function getDonationFrame()
	local main = playerGui:FindFirstChild("Main")
	return main and main:FindFirstChild("Donation")
end

local function openDonation()
	local frame = getDonationFrame()
	if not frame then return end
	frame.Visible = true
	local uiScale = frame:FindFirstChild("UIScale")
	if uiScale then
		uiScale.Scale = 0
		TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end
end

local function closeDonation()
	local frame = getDonationFrame()
	if not frame then return end
	local uiScale = frame:FindFirstChild("UIScale")
	if uiScale then
		TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0}):Play()
		task.delay(0.2, function() frame.Visible = false end)
	else
		frame.Visible = false
	end
end

donationIcon:bindEvent("selected", openDonation)
donationIcon:bindEvent("deselected", closeDonation)

-- Close button wiring
task.spawn(function()
	task.wait(1)
	local frame = getDonationFrame()
	if not frame then return end
	local closeFrame = frame:FindFirstChild("Close")
	local closeBtn = closeFrame and (closeFrame:FindFirstChildOfClass("ImageButton") or closeFrame:FindFirstChildOfClass("TextButton"))
	if closeBtn then
		closeBtn.Activated:Connect(function()
			donationIcon:deselect()
		end)
	end
	frame.Visible = false
end)
