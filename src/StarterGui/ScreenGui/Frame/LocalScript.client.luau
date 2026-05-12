local Players = game:GetService("Players")
local player = Players.LocalPlayer
local sound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("Success")
local rewardData = nil

-- Streak day names
local streakNames = {
	[1] = "Day 1",
	[2] = "Day 2",
	[3] = "Day 3",
	[4] = "Day 4",
	[5] = "Day 5",
	[6] = "Day 6",
	[7] = "Day 7 Complete!"
}

-- Server requests to show daily reward UI
game:GetService("ReplicatedStorage"):WaitForChild("PPEAZX").OnClientEvent:Connect(function(receivedData)
	rewardData = receivedData
	script.Parent.Parent.Frame.Visible = true

	-- Display streak information
	local streakText = streakNames[rewardData.streak]
	local rewardText = rewardData.rewardRange.min .. " Coins"
	local displayInfo = streakText .. "\nReward: " .. rewardText

	-- Show streak info in UI
	if script.Parent.Parent.Frame:FindFirstChild("StreakInfo") then
		script.Parent.Parent.Frame.StreakInfo.Text = displayInfo
	end

	-- Change button text
	--if script.Parent.TextButton then
	--	script.Parent.TextButton.Text = "Claim Daily Reward (Day " .. rewardData.streak .. ")"
	--end

	-- 미리 코인 보상량을 표시
	local rewardAmount = rewardData.rewardRange.min
	script.Parent.Frame1.TextLabel.Text = "+" .. rewardAmount .. " Coins!"


end)

-- Claim reward button click
script.Parent.TextButton.MouseButton1Click:Connect(function()
	if not rewardData then
		warn("Reward data not set!")
		return
	end

	-- Fixed reward amount
	local rewardAmount = rewardData.rewardRange.min

	script.Parent.TextButton.Visible = false

	-- Request reward from server (send streak info too)
	game.ReplicatedStorage.PPEAZX:FireServer({
		rewardAmount = rewardAmount,
		streak = rewardData.streak
	})

	sound:Play()

	-- Hide UI
	script.Parent.Parent.Frame.Visible = false

	---- Reset button and hide special effects
	--script.Parent.TextButton.Visible = true
	--script.Parent.TextButton.Text = "Claim Daily Reward"
	--script.Parent.Frame1.TextLabel.Text = ""

end)