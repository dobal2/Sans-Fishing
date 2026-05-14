local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local donationRefreshEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("DonationRefresh")

-- Robux donation product IDs mapped to frame name
local DONATION_PRODUCTS = {
	["10Robux"]   = 3364051385,
	["100Robux"]  = 3364052354,
	["1kRobux"]   = 3364067189,
	["10kRobux"]  = 3591658074,
	["100kRobux"] = 3591658073,
}

local function getDonationUI()
	local main = playerGui:FindFirstChild("Main")
	if not main then return end
	local donation = main:FindFirstChild("Donation")
	if not donation then return end
	local mainFrame = donation:FindFirstChild("Main")
	if not mainFrame then return end
	local scroll = mainFrame:FindFirstChild("ScrollingFrame")
	local myStat = donation:FindFirstChild("MyDonationStat")
	return scroll, myStat, donation
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

	local template = scroll:FindFirstChild("DonationTemplate")
	if not template then return end

	-- Clear existing entries (keep template)
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") and c.Name ~= "DonationTemplate" then
			c:Destroy()
		end
	end

	for i, entry in ipairs(list) do
		local clone = template:Clone()
		clone.Name = "Entry_" .. i
		clone.LayoutOrder = i
		clone.Visible = true

		local rank     = clone:FindFirstChild("Rank")
		local userName = clone:FindFirstChild("UserName")
		local profile  = clone:FindFirstChild("Profile")

		local titleLabel, amountLabel
		for _, c in ipairs(clone:GetChildren()) do
			if c.Name == "Title" then
				if not titleLabel then titleLabel = c else amountLabel = c end
			end
		end

		if rank      then rank.Text      = "#" .. i end
		if userName  then userName.Text  = "@" .. entry.name end
		if profile   then profile.Image  = "rbxthumb://type=AvatarHeadShot&id=" .. entry.userId .. "&w=150&h=150" end
		if titleLabel  then titleLabel.Text  = entry.name end
		if amountLabel then amountLabel.Text = formatRobux(entry.donations) .. " R$" end

		clone.Parent = scroll
	end

	-- MyDonationStat
	if myStat and myData then
		local disp     = myStat:FindFirstChild("Displayname")
		local uname    = myStat:FindFirstChild("UserName")
		local prof     = myStat:FindFirstChild("Profile")
		local robuxVal = myStat:FindFirstChild("RobuxValue")
		local rankLbl  = myStat:FindFirstChild("Rank")

		if disp     then disp.Text     = player.DisplayName end
		if uname    then uname.Text    = "@" .. player.Name end
		if prof     then prof.Image    = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150" end
		if robuxVal then robuxVal.Text = formatRobux(myData.donations) .. " R$" end
		if rankLbl  then rankLbl.Text  = myData.rank and ("#" .. myData.rank) or "-" end
	end
end

donationRefreshEvent.OnClientEvent:Connect(function(list, myData)
	populateList(list, myData)
end)

-- Wire up donation purchase buttons
local function setupDonationButtons()
	local _, _, donation = getDonationUI()
	if not donation then return end
	local categories = donation:FindFirstChild("Categories")
	if not categories then return end

	for frameName, productId in pairs(DONATION_PRODUCTS) do
		local frame = categories:FindFirstChild(frameName)
		if not frame then continue end
		local btn = frame:FindFirstChildOfClass("ImageButton") or frame:FindFirstChildOfClass("TextButton")
		if not btn then continue end

		btn.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
	end
end

-- Request data on join
task.delay(4, function()
	donationRefreshEvent:FireServer()
	setupDonationButtons()
end)

-- Re-request after any purchase to update leaderboard
MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, productId, purchased)
	if purchased and DONATION_PRODUCTS then
		for _, pid in pairs(DONATION_PRODUCTS) do
			if pid == productId then
				task.wait(2)
				donationRefreshEvent:FireServer()
				break
			end
		end
	end
end)
