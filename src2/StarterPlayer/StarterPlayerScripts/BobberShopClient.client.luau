local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BobberData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BobberDataModule"))

local openBobberShopRemote = ReplicatedStorage:WaitForChild("OpenBobberShopRemote")
local buyBobberRemote = ReplicatedStorage:WaitForChild("BuyBobberRemote")
local buySound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Buy SFX")

local ROBUX_BOBBER_GAMEPASS_ID = 1853589181

local mainGui = playerGui:WaitForChild("Main")
local bobberFrame = mainGui:WaitForChild("Bobber")
local bobberScale = bobberFrame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
local CLOSED_SCALE = 0.55
bobberScale.Name = "OpenScale"
bobberScale.Scale = CLOSED_SCALE
bobberScale.Parent = bobberFrame

local OPEN_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local titleLabel   = bobberFrame:WaitForChild("Title")
local descLabel    = bobberFrame:WaitForChild("Desc")
local priceLabel   = bobberFrame:WaitForChild("Price")
local equipFrame   = bobberFrame:WaitForChild("Equip")
local buyBtn       = equipFrame:WaitForChild("TextButton")
local buyLabel     = equipFrame:WaitForChild("TextLabel")
local onGradient   = buyBtn:FindFirstChild("OnGradient")
local offGradient  = buyBtn:FindFirstChild("OffGradient")
local closeFrame   = bobberFrame:WaitForChild("Close")
local closeBtn     = closeFrame:WaitForChild("TextButton")

local currentBobberName = nil
local currentSlotIndex  = nil
local isBuying = false
local cachedRobuxBobberOwned = nil
local frameTween = nil
local closeToken = 0

task.spawn(function()
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, ROBUX_BOBBER_GAMEPASS_ID)
	end)
	if ok then cachedRobuxBobberOwned = owns end
end)

local function formatCoins(n)
	local s = tostring(math.floor(n))
	local result = ""
	local len = #s
	for i = 1, len do
		if i > 1 and (len - i + 1) % 3 == 0 then result = result .. "," end
		result = result .. s:sub(i, i)
	end
	return result
end

local function getCoins()
	local ls = player:FindFirstChild("leaderstats")
	local c = ls and ls:FindFirstChild("Coins")
	return c and c.Value or 0
end

local function ownsAlready(bobberName)
	if bobberName == "Robux Bobber" and cachedRobuxBobberOwned then return true end
	local ls = player:FindFirstChild("leaderstats")
	local folder = ls and ls:FindFirstChild("OwnedBobbers")
	if not folder then return false end
	local bv = folder:FindFirstChild(bobberName)
	return bv and bv.Value == true
end

local function updateBuyButton(price)
	if ownsAlready(currentBobberName) then
		buyLabel.Text = "Already Owned"
		buyBtn.Active = false
		if onGradient then onGradient.Enabled = false end
		if offGradient then offGradient.Enabled = true end
		return
	end

	if currentBobberName == "Robux Bobber" then
		buyBtn.Active = true
		if onGradient then onGradient.Enabled = true end
		if offGradient then offGradient.Enabled = false end
		buyLabel.Text = "Buy (Robux)"
		return
	end

	local canAfford = getCoins() >= price
	buyBtn.Active = canAfford
	if onGradient then onGradient.Enabled = canAfford end
	if offGradient then offGradient.Enabled = not canAfford end
	buyLabel.Text = canAfford and "Buy" or "Not Enough Coins"
end

local function closeFrame_()
	closeToken += 1
	local token = closeToken
	if frameTween then frameTween:Cancel() end
	frameTween = TweenService:Create(bobberScale, CLOSE_TWEEN, {Scale = CLOSED_SCALE})
	frameTween:Play()
	frameTween.Completed:Once(function()
		if token ~= closeToken then return end
		bobberFrame.Visible = false
	end)
	currentBobberName = nil
	currentSlotIndex = nil
	isBuying = false
end

local function showFrame()
	closeToken += 1
	if frameTween then frameTween:Cancel() end
	bobberScale.Scale = CLOSED_SCALE
	bobberFrame.Visible = true
	frameTween = TweenService:Create(bobberScale, OPEN_TWEEN, {Scale = 1})
	frameTween:Play()
end

local function openFrame(bobberName, slotIndex)
	local data = BobberData.Bobbers[bobberName]
	if not data then return end

	currentBobberName = bobberName
	currentSlotIndex = slotIndex

	titleLabel.Text = bobberName
	descLabel.Text = data.desc or ""
	if bobberName == "Robux Bobber" then
		if ownsAlready(bobberName) then
			priceLabel.Text = "Already Owned"
		else
			priceLabel.Text = "\u{E002} ..."
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(ROBUX_BOBBER_GAMEPASS_ID, Enum.InfoType.GamePass)
				end)
				if currentBobberName ~= "Robux Bobber" then return end
				if ok and info and info.PriceInRobux then
					priceLabel.Text = "\u{E002} " .. info.PriceInRobux
				else
					priceLabel.Text = "\u{E002} Robux"
				end
			end)
		end
	else
		priceLabel.Text = formatCoins(data.price or 0) .. " Coins"
	end

	updateBuyButton(data.price or 0)
	showFrame()
end

openBobberShopRemote.OnClientEvent:Connect(function(bobberName, slotIndex, justPurchased)
	if not bobberName then
		closeFrame_()
		return
	end
	if justPurchased then
		isBuying = false
		currentBobberName = bobberName
		currentSlotIndex = slotIndex
		local data = BobberData.Bobbers[bobberName]
		titleLabel.Text = bobberName
		if data then
			descLabel.Text = data.desc or ""
			priceLabel.Text = formatCoins(data.price or 0) .. " Coins"
		end
		buyLabel.Text = "Already Owned"
		buyBtn.Active = false
		if onGradient then onGradient.Enabled = false end
		if offGradient then offGradient.Enabled = true end
		showFrame()
		return
	end
	openFrame(bobberName, slotIndex)
end)

buyBtn.MouseButton1Click:Connect(function()
	if not currentBobberName or not currentSlotIndex then return end

	if currentBobberName == "Robux Bobber" then
		if ownsAlready(currentBobberName) then return end
		MarketplaceService:PromptGamePassPurchase(player, ROBUX_BOBBER_GAMEPASS_ID)
		return
	end

	if ownsAlready(currentBobberName) then return end
	if isBuying then return end
	local data = BobberData.Bobbers[currentBobberName]
	if not data then return end
	if getCoins() < (data.price or 0) then return end

	isBuying = true
	buySound:Play()
	buyBobberRemote:FireServer(currentBobberName, currentSlotIndex)
end)

closeBtn.MouseButton1Click:Connect(closeFrame_)

bobberFrame.Visible = false
