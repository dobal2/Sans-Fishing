local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("Main")
local skillTreeGui = playerGui:WaitForChild("SkillTree")

local skillTreeFrame = mainGui:WaitForChild("Left"):WaitForChild("SkillTree")
local skillTreeBtn   = skillTreeFrame:WaitForChild("TextButton")
local notification   = skillTreeFrame:WaitForChild("Notification")
local notifLabel     = notification:WaitForChild("TextLabel")

local getSkillData = ReplicatedStorage:WaitForChild("GetSkillData")

-- 현재 게임에 실제로 존재하는 스킬만 포함
local ACTIVE_SKILLS = {
	Root        = true,
	AutoFish    = true,
	LuckUp      = true,
	FriendBonus = true,
	SellBonus   = true,
	InvenUp     = true,
}

local isUpdating = false
local function updateNotification()
	if isUpdating then return end
	isUpdating = true
	local ok, data = pcall(function() return getSkillData:InvokeServer() end)
	isUpdating = false
	if not ok or not data then return end

	local count = 0
	local rootUnlocked = (data.levels["Root"] or 0) >= 1

	for skillName, cfg in pairs(data.skills) do
		if not ACTIVE_SKILLS[skillName] then continue end

		local curLevel = data.levels[skillName] or 0
		if curLevel >= cfg.maxLevel then continue end

		local nextStage = curLevel + 1

		if not rootUnlocked and skillName ~= "Root" then continue end
		if skillName == "FriendBonus" and (data.levels["LuckUp"] or 0) < 2 then continue end

		local cost    = cfg.costs[nextStage]
		local balance = cfg.currency == "Coins" and data.coins or data.fishingPoints
		if cost and balance >= cost then
			count = count + 1
		end
	end

	if count > 0 then
		notification.Visible = true
		notifLabel.Text = tostring(count)
	else
		notification.Visible = false
	end
end

local function watchCurrencyChanges()
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if coins then
		coins:GetPropertyChangedSignal("Value"):Connect(function()
			task.defer(updateNotification)
		end)
	end

	local sp = player:FindFirstChild("SkillPoints")
	if sp then
		sp:GetPropertyChangedSignal("Value"):Connect(function()
			task.defer(updateNotification)
		end)
	end
end

task.spawn(function()
	player:WaitForChild("DataReady", 30)
	task.wait(1)
	watchCurrencyChanges()
	updateNotification()
	while true do
		task.wait(10)
		if not skillTreeGui.Enabled then
			updateNotification()
		end
	end
end)

skillTreeBtn.MouseButton1Click:Connect(function()
	skillTreeGui.Enabled = true
end)

skillTreeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	task.wait(0.3)
	updateNotification()
end)
