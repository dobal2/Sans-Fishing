local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local indexGui = player.PlayerGui:WaitForChild("Index")
local indexToggle = indexGui:WaitForChild("IndexToggle")

local newIndexFrame = nil
for _, c in ipairs(indexGui:GetChildren()) do
	if c.Name == "Index" and c:IsA("Frame") then newIndexFrame = c; break end
end

local closeFrame   = newIndexFrame:WaitForChild("Close")
local xButton      = closeFrame:FindFirstChildOfClass("ImageButton") or closeFrame:FindFirstChildOfClass("TextButton")
local main         = newIndexFrame:WaitForChild("Main")
local scrollFrame  = main:WaitForChild("ScrollingFrame")
local uiScale      = newIndexFrame:WaitForChild("UIScale")
local clickSound   = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("click")
local blur         = lighting:WaitForChild("ShopBlur")
local fishesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Fishes")

local mainGui       = player:WaitForChild("PlayerGui"):WaitForChild("Main")
local notifBadge    = mainGui.Left.Index:WaitForChild("Notification")
local notifLabel    = notifBadge:WaitForChild("TextLabel")

local discoverRemote  = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("FishDiscoverReward")
local getClaimedRF    = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("GetDiscoveryClaimed")

local slotTemplate = scrollFrame:WaitForChild("IndexSlot")
slotTemplate.Visible = false

local canClick = true
local OPEN_TWEEN  = TweenInfo.new(0.35, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.2,  Enum.EasingStyle.Quad,  Enum.EasingDirection.In)

local FishRarities = {
	{ name="Common",    chance=44.4, fishes={ {fishName="Small Carp",value=80},{fishName="Gold Fish",value=100},{fishName="Stone Fish",value=400} } },
	{ name="Uncommon",  chance=25,   fishes={ {fishName="Crab",value=160},{fishName="Crystal Bass",value=160},{fishName="Dust Fish",value=680} } },
	{ name="Rare",      chance=17,   fishes={ {fishName="Bass",value=400},{fishName="Snow Fish",value=400},{fishName="Diri",value=680} } },
	{ name="Epic",      chance=7,    fishes={ {fishName="Dragon Head Fish",value=700},{fishName="Reggigash",value=680} } },
	{ name="Legendary", chance=4,    fishes={ {fishName="Golden Trout",value=1800},{fishName="Armor Fish",value=2500} } },
	{ name="Mystic",    chance=2,    fishes={ {fishName="Shark",value=4500},{fishName="Ray",value=4200} } },
	{ name="Fantasy",   chance=0.5,  fishes={ {fishName="Undyine",value=9000},{fishName="Sans",value=11111},{fishName="Electric Fish",value=13333} } },
	{ name="Unknown",   chance=0.1,  fishes={ {fishName="Unknown",value=50000},{fishName="Nyan Cat",value=56000} } },
}

local DISCOVER_REWARDS = { Common=50,Uncommon=150,Rare=400,Epic=1000,Legendary=3000,Mystic=8000,Fantasy=25000,Unknown=100000 }

local rarityColors = {
	Common=Color3.fromRGB(255,255,255), Uncommon=Color3.fromRGB(12,255,32),
	Rare=Color3.fromRGB(5,188,255),     Epic=Color3.fromRGB(162,12,255),
	Legendary=Color3.fromRGB(255,0,221),Mystic=Color3.fromRGB(255,217,2),
	Fantasy=Color3.fromRGB(64,224,208), Unknown=Color3.fromRGB(0,0,0),
}

-- fishName -> rarity name lookup
local fishRarityMap = {}
local fishRewardMap = {}
for _, rd in ipairs(FishRarities) do
	for _, fd in ipairs(rd.fishes) do
		fishRarityMap[fd.fishName] = rd.name
		fishRewardMap[fd.fishName] = DISCOVER_REWARDS[rd.name] or 0
	end
end

-- Unclaimed discovered fish: fishName -> true
local unclaimed = {}

local function isIndexOpen() return newIndexFrame.Visible end

local function updateNotifBadge()
	local count = 0
	for _ in pairs(unclaimed) do count += 1 end
	if count > 0 then
		notifLabel.Text = tostring(count)
		notifBadge.Visible = true
	else
		notifBadge.Visible = false
	end
end

local function tweenFOV(fov)
	TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = fov}):Play()
end

local function setVpSilhouette(vp, enabled)
	if not vp then return end
	if enabled then
		vp.Ambient    = Color3.new(0, 0, 0)
		vp.LightColor = Color3.new(0, 0, 0)
	else
		vp.Ambient    = Color3.fromRGB(180, 180, 180)
		vp.LightColor = Color3.fromRGB(230, 230, 230)
	end
end

local VP_FOV   = 60
local VP_PITCH = -20
local VP_YAW   = 45
local VP_ZOOM  = 1.2

local VP_OVERRIDES = {
	["Unknown"]       = { pitch = -20, yaw = 45, zoom = 3.5 },
	["Electric Fish"] = { pitch = -10, yaw = 45, zoom = 0.9 },
	["Nyan Cat"]      = { pitch = -10, yaw = 30, zoom = 0.9 },
}

local function setupModelInViewport(vp, fishModel)
	for _, c in ipairs(vp:GetChildren()) do
		if not c:IsA("Camera") then c:Destroy() end
	end

	local handle = fishModel and fishModel:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return end

	vp.Ambient    = Color3.fromRGB(180, 180, 180)
	vp.LightColor = Color3.fromRGB(230, 230, 230)

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = vp

	local clone = handle:Clone()
	clone.CFrame = CFrame.new(0, 0, 0)
	clone.Anchored = true
	clone.Parent = worldModel

	local fishName = fishModel and fishModel.Name or ""
	local ov = VP_OVERRIDES[fishName] or {}
	local pitch = ov.pitch or VP_PITCH
	local yaw   = ov.yaw   or VP_YAW
	local zoom  = ov.zoom  or VP_ZOOM

	local size = clone.Size
	local radius = math.max(size.X, size.Y, size.Z) / 2
	local dist = (radius / math.tan(math.rad(VP_FOV / 2))) * zoom

	local vpCam = vp:FindFirstChildOfClass("Camera")
	if not vpCam then
		vpCam = Instance.new("Camera")
		vpCam.Parent = vp
	end
	vp.CurrentCamera = vpCam
	vpCam.FieldOfView = VP_FOV
	vpCam.CFrame = CFrame.Angles(math.rad(pitch), math.rad(yaw), 0) * CFrame.new(0, 0, dist)
	vpCam.Focus = CFrame.new(0, 0, 0)
end

local function createHoverEffect(slot, viewportFrame)
	if not viewportFrame or not viewportFrame.CurrentCamera then return end
	local vpCamera = viewportFrame.CurrentCamera
	local origCF   = vpCamera.CFrame
	local zoomedCF = CFrame.Angles(math.rad(VP_PITCH), math.rad(VP_YAW), 0)
		* CFrame.new(0, 0, (origCF.Position - Vector3.new(0,0,0)).Magnitude * 0.75)
	local ti        = TweenInfo.new(0.2,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local HOVER_IN  = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local HOVER_OUT = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local us  = slot:FindFirstChild("UIScale")
	local btn = slot:FindFirstChildOfClass("TextButton")
	if btn then
		btn.MouseEnter:Connect(function()
			TweenService:Create(vpCamera, ti, {CFrame = zoomedCF}):Play()
			if us then TweenService:Create(us, HOVER_IN, {Scale = 1.08}):Play() end
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(vpCamera, ti, {CFrame = origCF}):Play()
			if us then TweenService:Create(us, HOVER_OUT, {Scale = 1}):Play() end
		end)
	end
end

-- Pulsing glow tween for unclaimed slots
local PULSE_IN  = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local function startClaimPulse(slot)
	local us = slot:FindFirstChild("UIStroke")
	if us then
		TweenService:Create(us, PULSE_IN, {Transparency = 0.2}):Play()
	end
	local shine = slot:FindFirstChild("Shine")
	if shine then
		shine.Visible = true
		TweenService:Create(shine, PULSE_IN, {ImageTransparency = 0.3}):Play()
	end
end

local function stopClaimPulse(slot)
	local us = slot:FindFirstChild("UIStroke")
	if us then
		TweenService:Create(us, TweenInfo.new(0.2), {Transparency = 0}):Play()
	end
end

local function claimReward(fishName, slot, rarityColor)
	if not unclaimed[fishName] then return end
	unclaimed[fishName] = nil
	updateNotifBadge()
	discoverRemote:FireServer(fishName)

	stopClaimPulse(slot)

	-- Remove claim overlay
	local overlay = slot:FindFirstChild("ClaimOverlay")
	if overlay then overlay:Destroy() end

	-- Flash white then settle to rarity color
	local us = slot:FindFirstChild("UIStroke")
	if us then
		us.Color = Color3.new(1, 1, 1)
		us.Thickness = 5
		task.delay(0.15, function()
			TweenService:Create(us, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
				Color = rarityColor,
				Thickness = 3,
			}):Play()
		end)
	end

	-- Scale pop
	local usc = slot:FindFirstChild("UIScale")
	if usc then
		usc.Scale = 1.15
		TweenService:Create(usc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end
end

local function addClaimOverlay(slot, fishName, rarityColor)
	local existing = slot:FindFirstChild("ClaimOverlay")
	if existing then existing:Destroy() end

	local overlay = Instance.new("Frame")
	overlay.Name = "ClaimOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 10

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = overlay

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 0.35)
	lbl.Position = UDim2.fromScale(0, 0.35)
	lbl.BackgroundTransparency = 1
	lbl.Text = "Claim!"
	lbl.TextColor3 = Color3.fromRGB(0, 210, 80)
	lbl.TextScaled = true
	lbl.FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
	lbl.ZIndex = 11

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = lbl

	lbl.Parent = overlay
	overlay.Parent = slot
end

local function createFishIndexUI()
	for _, child in pairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name == "IndexSlot" and child ~= slotTemplate then
			child:Destroy()
		end
	end

	local leaderstats = player:WaitForChild("leaderstats")
	local fishFolder  = leaderstats:WaitForChild("Fish")
	local layoutOrder = 1

	for _, rarityData in ipairs(FishRarities) do
		for _, fishData in ipairs(rarityData.fishes) do
			local fishName = fishData.fishName
			local slot = slotTemplate:Clone()
			slot.Name = "IndexSlot"
			slot.LayoutOrder = layoutOrder
			slot.Visible = true

			local rarityColor = rarityColors[rarityData.name] or Color3.fromRGB(255, 255, 255)
			local fishBool = fishFolder:FindFirstChild(fishName)
			local isDiscovered = fishBool and fishBool.Value or false
			local isClaiming = unclaimed[fishName] == true

			local uiStroke = slot:FindFirstChildOfClass("UIStroke")
			if uiStroke then
				uiStroke.Color = rarityColor
				uiStroke.Transparency = isDiscovered and 0 or 0.6
			end

			local titleLbl = slot:FindFirstChild("Title")
			if titleLbl then
				titleLbl.Text = isDiscovered and fishName or "???"
				titleLbl.TextColor3 = isDiscovered and Color3.new(1, 1, 1) or Color3.new(0.5, 0.5, 0.5)
				titleLbl.TextTransparency = isDiscovered and 0 or 0.3
			end

			local rarityLbl = slot:FindFirstChild("Rarity")
			if rarityLbl then
				rarityLbl.Text = isDiscovered and rarityData.name or "???"
				rarityLbl.TextColor3 = isDiscovered and rarityColor or Color3.new(0.4, 0.4, 0.4)
			end

			local vp = slot:FindFirstChild("ViewportFrame")
			if vp then
				local fishModel = fishesFolder:FindFirstChild(fishName)
				setupModelInViewport(vp, fishModel)
				setVpSilhouette(vp, not isDiscovered)
				if isDiscovered then
					createHoverEffect(slot, vp)
				end
			end

			local shine = slot:FindFirstChild("Shine")
			if shine then shine.Visible = isDiscovered and not isClaiming end

			-- Unclaimed reward: dark overlay + Claim! text, click to claim
			if isClaiming then
				addClaimOverlay(slot, fishName, rarityColor)
				startClaimPulse(slot)
				local btn = slot:FindFirstChildOfClass("TextButton")
				if btn then
					btn.MouseButton1Click:Connect(function()
						claimReward(fishName, slot, rarityColor)
					end)
				end
			end

			slot.Parent = scrollFrame
			layoutOrder += 1
		end
	end
end

local playerGui = player.PlayerGui

local function openIndex()
	playerGui:SetAttribute("ActiveLargeUI", "Index")
	newIndexFrame.Visible = true
	uiScale.Scale = 0
	TweenService:Create(uiScale, OPEN_TWEEN, {Scale = 1}):Play()
	blur.Enabled = true
	tweenFOV(60)
	createFishIndexUI()
end

local function closeIndex()
	TweenService:Create(uiScale, CLOSE_TWEEN, {Scale = 0}):Play()
	task.delay(0.2, function() newIndexFrame.Visible = false end)
	blur.Enabled = false
	tweenFOV(70)
end

local function toggleIndex()
	if not canClick then return end
	canClick = false
	clickSound:Play()
	if isIndexOpen() then closeIndex() else openIndex() end
	task.wait(0.5)
	canClick = true
end

playerGui:GetAttributeChangedSignal("ActiveLargeUI"):Connect(function()
	if playerGui:GetAttribute("ActiveLargeUI") ~= "Index" and isIndexOpen() then
		closeIndex()
	end
end)

indexToggle.Event:Connect(function(action)
	if action == "toggle" then
		toggleIndex()
	elseif action == "close" then
		if isIndexOpen() then closeIndex() end
	end
end)

xButton.MouseButton1Click:Connect(function()
	if isIndexOpen() then closeIndex() end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isIndexOpen() then closeIndex() end
end)

local function setupDiscoveryWatchers()
	local leaderstats = player:WaitForChild("leaderstats")
	local fishFolder  = leaderstats:WaitForChild("Fish")

	-- Restore unclaimed rewards from server: discovered but not yet claimed
	local ok, claimedData = pcall(function() return getClaimedRF:InvokeServer() end)
	local claimed = (ok and type(claimedData) == "table") and claimedData or {}

	for _, rarityData in ipairs(FishRarities) do
		for _, fishData in ipairs(rarityData.fishes) do
			local fishName = fishData.fishName
			local fishBool = fishFolder:FindFirstChild(fishName)
			if fishBool then
				-- If discovered but not claimed → restore unclaimed badge
				if fishBool.Value and not claimed[fishName] then
					unclaimed[fishName] = true
				end

				if not fishBool.Value then
					-- Not yet discovered: watch for first discovery
					fishBool.Changed:Connect(function(newVal)
						if newVal then
							unclaimed[fishName] = true
							updateNotifBadge()
							if isIndexOpen() then createFishIndexUI() end
						end
					end)
				end
			end
		end
	end

	updateNotifBadge()
end

newIndexFrame.Visible = false
uiScale.Scale = 0
notifBadge.Visible = false

player.CharacterAdded:Connect(setupDiscoveryWatchers)
if player.Character then task.spawn(setupDiscoveryWatchers) end
