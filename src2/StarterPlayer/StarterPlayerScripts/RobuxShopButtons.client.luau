local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local scroll = player.PlayerGui:WaitForChild("RobuxShop")
	:WaitForChild("Shop")
	:WaitForChild("Main")
	:WaitForChild("ScrollingFrame")

local passes = scroll:WaitForChild("Passes")

local GAMEPASSES = {
	{ passes:WaitForChild("Coin x2"),  1293430515 },
	{ passes:WaitForChild("Luck x2"),  1289569606 },
	{ passes:WaitForChild("Power x2"), 1290056221 },
}

local function getOrCreateOwnedLabel(frame, buyFrame)
	local owned = frame:FindFirstChild("Owned") or frame:FindFirstChild("OwnedLabel")
	if owned then return owned end

	-- Owned 라벨 없으면 Buy 프레임과 같은 위치/크기로 생성
	owned = Instance.new("TextLabel")
	owned.Name = "Owned"
	owned.Text = "Owned!"
	owned.Size = buyFrame and buyFrame.Size or UDim2.new(0.67, 0, 0.22, 0)
	owned.Position = buyFrame and buyFrame.Position or UDim2.new(0.5, 0, 0.72, 0)
	owned.AnchorPoint = buyFrame and buyFrame.AnchorPoint or Vector2.new(0.5, 0.5)
	owned.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	owned.TextColor3 = Color3.fromRGB(255, 255, 255)
	owned.TextScaled = true
	owned.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	owned.ZIndex = 14
	owned.Visible = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = owned

	owned.Parent = frame
	return owned
end

local function setupGamePass(frame, gamePassId)
	local button = frame:FindFirstChild("BuyButton")
	local buyFrame = frame:FindFirstChild("Buy")
	local buyFrameBtn = buyFrame and (buyFrame:FindFirstChildOfClass("ImageButton") or buyFrame:FindFirstChildOfClass("TextButton"))

	if not button and not buyFrameBtn then return end

	local ownedLabel = getOrCreateOwnedLabel(frame, buyFrame)

	local function setOwned(has)
		if buyFrame then buyFrame.Visible = not has end
		if button then
			button.Visible = not has
			button.Active = not has
			button.AutoButtonColor = not has
		end
		ownedLabel.Visible = has
	end

	local function refreshOwnership()
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
		end)
		if not ok then return end
		setOwned(has)
	end

	local function promptPurchase()
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
		end)
		if ok and has then return end
		MarketplaceService:PromptGamePassPurchase(player, gamePassId)
	end

	refreshOwnership()

	if button then
		button.MouseButton1Click:Connect(promptPurchase)
	end
	if buyFrameBtn then
		buyFrameBtn.MouseButton1Click:Connect(promptPurchase)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(userId, assetId, wasPurchased)
		if userId == player.UserId and assetId == gamePassId and wasPurchased then
			setOwned(true)
		end
	end)
end

for _, entry in ipairs(GAMEPASSES) do
	task.spawn(setupGamePass, entry[1], entry[2])
end
