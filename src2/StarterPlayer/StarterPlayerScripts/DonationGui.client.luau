local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local donationRefreshEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("DonationRefresh")
local robuxBuySound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("RobuxBuySound")

-- TextLabel 텍스트 기준으로 product ID 매핑 (프레임 이름 중복 있어서 텍스트로 구분)
-- TextLabel에 Robux 아이콘 특수문자(\xEE\x80\x82) 앞에 붙어있어서 숫자 부분만 추출해서 매핑
local DONATION_PRODUCTS_BY_AMOUNT = {
	["10"]      = 3364051385,
	["100"]     = 3364052354,
	["1,000"]   = 3364067189,
	["10,000"]  = 3591658074,
	["100,000"] = 3591658073,
}

local function getDonationUI()
	local main = playerGui:FindFirstChild("Main")
	if not main then return end
	local donation = main:FindFirstChild("Donation")
	if not donation then return end
	local mainFrame = donation:FindFirstChild("Main")
	if not mainFrame then return end
	local scroll = mainFrame:FindFirstChild("ScrollingFrame")
	local myStat = mainFrame:FindFirstChild("MyDonationStat")
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

local function showLoading()
	local scroll, _, _ = getDonationUI()
	if not scroll then return end

	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") and c.Name ~= "DonationTemplate" then
			c:Destroy()
		end
	end

	local existing = scroll:FindFirstChild("_Loading")
	if existing then return end

	local frame = Instance.new("Frame")
	frame.Name = "_Loading"
	frame.Size = UDim2.new(1, 0, 0, 60)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = 0
	local label = Instance.new("TextLabel", frame)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Loading..."
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	frame.Parent = scroll
end

local function populateList(list, myData)
	local scroll, myStat = getDonationUI()
	if not scroll then return end

	local template = scroll:FindFirstChild("DonationTemplate")
	if not template then return end

	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") and c.Name ~= "DonationTemplate" then
			c:Destroy()
		end
	end

	if #list == 0 then
		local frame = Instance.new("Frame")
		frame.Name = "_Empty"
		frame.Size = UDim2.new(1, 0, 0, 60)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = 0
		local label = Instance.new("TextLabel", frame)
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "아직 도네이션 데이터가 없습니다."
		label.TextColor3 = Color3.fromRGB(180, 180, 180)
		label.TextScaled = true
		label.Font = Enum.Font.Gotham
		frame.Parent = scroll
		return
	end

	for i, entry in ipairs(list) do
		local clone = template:Clone()
		clone.Name = "Entry_" .. i
		clone.LayoutOrder = i
		clone.Visible = true

		local rank     = clone:FindFirstChild("Rank")
		local userName = clone:FindFirstChild("UserName")
		local profile  = clone:FindFirstChild("Profile")

		-- Title이 두 개: Position.X가 작은 쪽이 이름, 큰 쪽이 금액
		local nameLabel, amountLabel
		for _, c in ipairs(clone:GetChildren()) do
			if c.Name == "Title" and c:IsA("TextLabel") then
				if not nameLabel then
					nameLabel = c
				elseif c.Position.X.Scale > nameLabel.Position.X.Scale then
					amountLabel = c
				else
					amountLabel = nameLabel
					nameLabel = c
				end
			end
		end

		if rank      then rank.Text      = "#" .. i end
		if userName  then userName.Text  = "@" .. entry.name end
		if profile   then profile.Image  = "rbxthumb://type=AvatarHeadShot&id=" .. entry.userId .. "&w=150&h=150" end
		if nameLabel   then nameLabel.Text   = entry.name end
		if amountLabel then amountLabel.Text = formatRobux(entry.donations) .. " R$" end

		clone.Parent = scroll
	end

	-- entry 개수 × (높이 + padding) 으로 정확하게 계산
	local ENTRY_HEIGHT = 55
	local ENTRY_PADDING = 4
	local totalHeight = #list * ENTRY_HEIGHT + math.max(0, #list - 1) * ENTRY_PADDING
	scroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)

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

local buttonsSetup = false
local function setupDonationButtons()
	if buttonsSetup then return end

	local main = playerGui:WaitForChild("Main", 10)
	if not main then return end
	local donation = main:WaitForChild("Donation", 10)
	if not donation then return end
	local mainFrame = donation:WaitForChild("Main", 10)
	if not mainFrame then return end
	local categories = mainFrame:WaitForChild("Categories", 10)
	if not categories then return end

	for _, frame in ipairs(categories:GetChildren()) do
		if not frame:IsA("Frame") then continue end
		local label = frame:FindFirstChildOfClass("TextLabel")
		if not label then continue end
		-- 앞의 특수문자(Robux 아이콘 등) 제거하고 숫자+콤마만 추출
		local stripped = label.Text:match("[%d,]+")
		if not stripped then continue end
		local productId = DONATION_PRODUCTS_BY_AMOUNT[stripped]
		if not productId then continue end
		local btn = frame:FindFirstChildOfClass("ImageButton") or frame:FindFirstChildOfClass("TextButton")
		if not btn then continue end

		btn.MouseButton1Click:Connect(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
	end
	buttonsSetup = true
end

-- 초기 로딩중 표시 후 서버 요청
task.delay(2, function()
	showLoading()
	task.delay(2, function()
		donationRefreshEvent:FireServer()
		setupDonationButtons()
	end)
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, productId, purchased)
	if purchased then
		for _, pid in pairs(DONATION_PRODUCTS_BY_AMOUNT) do
			if pid == productId then
				robuxBuySound:Play()
				break
			end
		end
	end
end)
