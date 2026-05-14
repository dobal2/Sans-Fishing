local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local donationRefreshEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("DonationRefresh")

local function getDonationUI()
	local main = playerGui:FindFirstChild("Main")
	if not main then return end
	local donation = main:FindFirstChild("Donation")
	if not donation then return end
	local mainFrame = donation:FindFirstChild("Main")
	if not mainFrame then return end
	local scroll = mainFrame:FindFirstChild("ScrollingFrame")
	local myStat = donation:FindFirstChild("MyDonationStat")
	return scroll, myStat
end

local function formatRobux(amount)
	if amount >= 1000000 then
		return string.format("%.1fM", amount / 1000000)
	elseif amount >= 1000 then
		return string.format("%.1fK", amount / 1000)
	else
		return tostring(amount)
	end
end

local function populateList(list, myData)
	local scroll, myStat = getDonationUI()
	if not scroll then return end

	-- Find template (hidden frame)
	local template = scroll:FindFirstChild("DonationTemplate")
	if not template then return end

	-- Clear existing entries (keep template)
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") and c.Name ~= "DonationTemplate" then
			c:Destroy()
		end
	end

	-- Populate entries
	for i, entry in ipairs(list) do
		local clone = template:Clone()
		clone.Name = "Entry_" .. i
		clone.LayoutOrder = i
		clone.Visible = true

		local rank = clone:FindFirstChild("Rank")
		local userName = clone:FindFirstChild("UserName")
		local profile = clone:FindFirstChild("Profile")
		-- There are two Title children; find the one for donation amount
		local titles = clone:GetChildren()
		local titleLabel, amountLabel
		for _, c in ipairs(titles) do
			if c.Name == "Title" then
				if not titleLabel then titleLabel = c else amountLabel = c end
			end
		end

		if rank then rank.Text = "#" .. i end
		if userName then userName.Text = "@" .. entry.name end
		if profile then profile.Image = "rbxthumb://type=AvatarHeadShot&id=" .. entry.userId .. "&w=150&h=150" end
		if titleLabel then titleLabel.Text = entry.name end
		if amountLabel then amountLabel.Text = formatRobux(entry.donations) .. " R$" end

		clone.Parent = scroll
	end

	-- Update canvas size
	local uiList = scroll:FindFirstChildOfClass("UIListLayout")
	if uiList then
		scroll.CanvasSize = UDim2.new(0, 0, 0, uiList.AbsoluteContentSize.Y)
	end

	-- Update MyDonationStat
	if myStat and myData then
		local disp = myStat:FindFirstChild("Displayname")
		local uname = myStat:FindFirstChild("UserName")
		local prof = myStat:FindFirstChild("Profile")
		local robuxVal = myStat:FindFirstChild("RobuxValue")
		local rankLabel = myStat:FindFirstChild("Rank")

		if disp then disp.Text = player.DisplayName end
		if uname then uname.Text = "@" .. player.Name end
		if prof then prof.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150" end
		if robuxVal then robuxVal.Text = formatRobux(myData.donations) .. " R$" end
		if rankLabel then rankLabel.Text = myData.rank and ("#" .. myData.rank) or "-" end
	end
end

donationRefreshEvent.OnClientEvent:Connect(function(list, myData)
	populateList(list, myData)
end)

-- Request on join after GUI loads
task.delay(4, function()
	donationRefreshEvent:FireServer()
end)
