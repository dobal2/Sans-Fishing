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
local fishesFolder = ReplicatedStorage:WaitForChild("Fishes")

local categoriesFrame = newIndexFrame:WaitForChild("Categories")
local catNormal   = categoriesFrame:WaitForChild("Normal")
local catGold     = categoriesFrame:WaitForChild("Gold")
local catFrozen   = categoriesFrame:WaitForChild("Frozen")
local catFestival = categoriesFrame:WaitForChild("Festival")
local catSans     = categoriesFrame:WaitForChild("Sans")

local mainGui    = player:WaitForChild("PlayerGui"):WaitForChild("Main")
local notifBadge = mainGui.Left.Index:WaitForChild("Notification")
local notifLabel = notifBadge:WaitForChild("TextLabel")

local discoverRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("FishDiscoverReward")
local getClaimedRF   = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("GetDiscoveryClaimed")

local slotTemplate = scrollFrame:WaitForChild("IndexSlot")
slotTemplate.Visible = false

local canClick = true
local OPEN_TWEEN  = TweenInfo.new(0.35, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.2,  Enum.EasingStyle.Quad,  Enum.EasingDirection.In)

local currentCategory = "Normal"

local FishRarities = {
	{ name="Common",    chance=44.4, fishes={ {fishName="Small Carp",value=80},{fishName="Gold Fish",value=100},{fishName="Stone Fish",value=400} } },
	{ name="Uncommon",  chance=25,   fishes={ {fishName="Crab",value=160},{fishName="Crystal Bass",value=160},{fishName="Dust Fish",value=680} } },
	{ name="Rare",      chance=17,   fishes={ {fishName="Bass",value=400},{fishName="Snow Fish",value=400},{fishName="Diri",value=680} } },
	{ name="Epic",      chance=7,    fishes={ {fishName="Dragon Head Fish",value=700},{fishName="Reggigash",value=680} } },
	{ name="Legendary", chance=4,    fishes={ {fishName="Golden Trout",value=1800},{fishName="Armor Fish",value=2500} } },
	{ name="Mystic",    chance=2,    fishes={ {fishName="Shark",value=4500},{fishName="Ray",value=4200} } },
	{ name="Fantasy",   chance=0.5,  fishes={ {fishName="Undyine",value=9000},{fishName="Sans",value=11111},{fishName="Electric Fish",value=13333} } },
	{ name="Unknown",   chance=0.1,  fishes={ {fishName="Unknown",value=50000},{fishName="Nyan Cat",value=56000} } },
	{ name="Soul",      chance=0.02, fishes={
		{fishName="Determination",value=120000},
		{fishName="Patience",value=120000},
		{fishName="Bravery",value=120000},
		{fishName="Integrity",value=120000},
		{fishName="Perseverance",value=120000},
		{fishName="Kindness",value=120000},
		{fishName="Justice",value=120000},
	} },
}

-- halved base rewards
local DISCOVER_REWARDS = { Common=25,Uncommon=75,Rare=200,Epic=500,Legendary=1500,Mystic=4000,Fantasy=12500,Unknown=50000,Soul=150000 }
local VARIANT_MULTIPLIER = 2

local VARIANT_PREFIXES = { "Gold", "Frozen", "Festival", "Sans" }

local rarityColors = {
	Common=Color3.fromRGB(255,255,255), Uncommon=Color3.fromRGB(12,255,32),
	Rare=Color3.fromRGB(5,188,255),     Epic=Color3.fromRGB(162,12,255),
	Legendary=Color3.fromRGB(255,0,221),Mystic=Color3.fromRGB(255,217,2),
	Fantasy=Color3.fromRGB(64,224,208), Unknown=Color3.fromRGB(0,0,0),
	Soul=Color3.fromRGB(255,45,45),
}

local soulColors = {
	Determination = Color3.fromRGB(255, 45, 45),
	Patience = Color3.fromRGB(0, 255, 255),
	Bravery = Color3.fromRGB(255, 128, 0),
	Integrity = Color3.fromRGB(45, 120, 255),
	Perseverance = Color3.fromRGB(170, 70, 255),
	Kindness = Color3.fromRGB(60, 220, 80),
	Justice = Color3.fromRGB(255, 230, 40),
}

local function getSoulColor(fishName, fallback)
	for soulName, color in pairs(soulColors) do
		if fishName:find(soulName, 1, true) then
			return color
		end
	end
	return fallback
end

local catAccentColors = {
	Normal   = Color3.fromRGB(255, 255, 255),
	Gold     = Color3.fromRGB(255, 235, 60),
	Frozen   = Color3.fromRGB(100, 200, 255),
	Festival = Color3.fromRGB(255, 100, 200),
	Sans     = Color3.fromRGB(0, 200, 255),
}

local fishRarityMap = {}
for _, rd in ipairs(FishRarities) do
	for _, fd in ipairs(rd.fishes) do
		fishRarityMap[fd.fishName] = rd.name
	end
end

-- unclaimed[fishName] = true  (used for Normal category)
-- variantUnclaimed["Gold Bass"] = true  (used for variant categories)
local unclaimed        = {}
local variantUnclaimed = {}

-- last server data, refreshed on open
local lastClaimed        = {}
local lastVariantClaimed = {}

local function isIndexOpen() return newIndexFrame.Visible end

local function totalUnclaimedCount()
	local n = 0
	for _ in pairs(unclaimed) do n += 1 end
	for _ in pairs(variantUnclaimed) do n += 1 end
	return n
end

local function updateNotifBadge()
	local count = totalUnclaimedCount()
	if count > 0 then
		notifLabel.Text = tostring(count)
		notifBadge.Visible = true
	else
		notifBadge.Visible = false
	end
end

local function unclaimedCountForCategory(cat)
	if cat == "Normal" then
		local n = 0
		for _ in pairs(unclaimed) do n += 1 end
		return n
	else
		local n = 0
		for key in pairs(variantUnclaimed) do
			if key:sub(1, #cat) == cat then n += 1 end
		end
		return n
	end
end

local function updateCategoryBadges()
	for _, catName in ipairs({ "Normal", "Gold", "Frozen", "Festival", "Sans" }) do
		local frame = categoriesFrame:FindFirstChild(catName)
		if frame then
			local badge = frame:FindFirstChild("Exclamation")
			if badge then
				local count = unclaimedCountForCategory(catName)
				badge.Visible = count > 0
				local lbl = badge:FindFirstChild("Label")
				if lbl then lbl.Text = tostring(count) end
			end
		end
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
		-- Paint all parts black so edges don't show through
		local wm = vp:FindFirstChildOfClass("WorldModel")
		if wm then
			for _, p in ipairs(wm:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Color = Color3.new(0, 0, 0)
					p.Material = Enum.Material.SmoothPlastic
					p.CastShadow = false
				end
			end
		end
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
	["Determination"] = { pitch = -5, yaw = 0, zoom = 2.2 },
	["Patience"]      = { pitch = -5, yaw = 0, zoom = 2.2 },
	["Bravery"]       = { pitch = -5, yaw = 0, zoom = 2.2 },
	["Integrity"]     = { pitch = -5, yaw = 0, zoom = 2.2 },
	["Perseverance"]  = { pitch = -5, yaw = 0, zoom = 2.2 },
	["Kindness"]      = { pitch = -5, yaw = 0, zoom = 2.2 },
	["Justice"]       = { pitch = -5, yaw = 0, zoom = 2.2 },
	["Electric Fish"] = { pitch = -10, yaw = 45, zoom = 0.9 },
	["Nyan Cat"]      = { pitch = -10, yaw = 30, zoom = 0.9 },
}

local function setupModelInViewport(vp, fishModel, isGold, isSans)
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

	if isGold then
		clone.Color = Color3.fromRGB(255, 235, 60)
		clone.Material = Enum.Material.Metal
		clone.Reflectance = 0.6
	elseif isSans then
		clone.Color = Color3.fromRGB(0, 200, 255)
		clone.Material = Enum.Material.Neon
	end

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

local PULSE_IN = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local function startClaimPulse(slot)
	local us = slot:FindFirstChild("UIStroke")
	if us then TweenService:Create(us, PULSE_IN, {Transparency = 0.2}):Play() end
	local shine = slot:FindFirstChild("Shine")
	if shine then
		shine.Visible = true
		TweenService:Create(shine, PULSE_IN, {ImageTransparency = 0.3}):Play()
	end
end

local function stopClaimPulse(slot)
	local us = slot:FindFirstChild("UIStroke")
	if us then TweenService:Create(us, TweenInfo.new(0.2), {Transparency = 0}):Play() end
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

local function claimReward(displayName, slot, rarityColor, isVariant)
	if isVariant then
		if not variantUnclaimed[displayName] then return end
		variantUnclaimed[displayName] = nil
	else
		if not unclaimed[displayName] then return end
		unclaimed[displayName] = nil
	end

	updateNotifBadge()
	updateCategoryBadges()
	discoverRemote:FireServer(displayName)
	stopClaimPulse(slot)

	local overlay = slot:FindFirstChild("ClaimOverlay")
	if overlay then overlay:Destroy() end

	local us = slot:FindFirstChild("UIStroke")
	if us then
		us.Color = Color3.new(1, 1, 1)
		us.Thickness = 5
		task.delay(0.15, function()
			TweenService:Create(us, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
				Color = rarityColor, Thickness = 3,
			}):Play()
		end)
	end

	local usc = slot:FindFirstChild("UIScale")
	if usc then
		usc.Scale = 1.15
		TweenService:Create(usc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end
end

-- Build the catalog list for a given category
local function getFishListForCategory(cat)
	-- returns array of { displayName, baseName, rarityName, reward }
	local list = {}
	for _, rd in ipairs(FishRarities) do
		for _, fd in ipairs(rd.fishes) do
			local base = fd.fishName
			local displayName = (cat == "Normal") and base or (cat .. " " .. base)
			local reward = DISCOVER_REWARDS[rd.name] or 0
			if cat ~= "Normal" then reward = math.floor(reward * VARIANT_MULTIPLIER) end
			table.insert(list, {
				displayName = displayName,
				baseName    = base,
				rarityName  = rd.name,
				reward      = reward,
			})
		end
	end
	return list
end

local function createFishIndexUI()
	for _, child in pairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name == "IndexSlot" and child ~= slotTemplate then
			child:Destroy()
		end
	end

	local leaderstats   = player:WaitForChild("leaderstats")
	local fishFolder    = leaderstats:WaitForChild("Fish")
	local variantFolder = leaderstats:FindFirstChild("FishVariant")

	local isVariant  = currentCategory ~= "Normal"
	local fishList   = getFishListForCategory(currentCategory)
	local layoutOrder = 1

	for _, entry in ipairs(fishList) do
		local displayName = entry.displayName
		local baseName    = entry.baseName
		local rarityName  = entry.rarityName
		local rarityColor = rarityColors[rarityName] or Color3.fromRGB(255, 255, 255)
		if rarityName == "Soul" then
			rarityColor = getSoulColor(displayName, rarityColor)
		end

		local isDiscovered
		if isVariant then
			local vBool = variantFolder and variantFolder:FindFirstChild(displayName)
			isDiscovered = vBool and vBool.Value or false
		else
			local fishBool = fishFolder:FindFirstChild(displayName)
			isDiscovered = fishBool and fishBool.Value or false
		end

		local isClaiming
		if isVariant then
			isClaiming = variantUnclaimed[displayName] == true
		else
			isClaiming = unclaimed[displayName] == true
		end

		local slot = slotTemplate:Clone()
		slot.Name = "IndexSlot"
		slot.LayoutOrder = layoutOrder
		slot.Visible = true

		local uiStroke = slot:FindFirstChildOfClass("UIStroke")
		if uiStroke then
			uiStroke.Color = rarityColor
			uiStroke.Transparency = isDiscovered and 0 or 0.6
		end

		local titleLbl = slot:FindFirstChild("Title")
		if titleLbl then
			titleLbl.Text = isDiscovered and displayName or "???"
			titleLbl.TextColor3 = isDiscovered and Color3.new(1, 1, 1) or Color3.new(0.5, 0.5, 0.5)
			titleLbl.TextTransparency = isDiscovered and 0 or 0.3
		end

		local rarityLbl = slot:FindFirstChild("Rarity")
		if rarityLbl then
			rarityLbl.Text = isDiscovered and rarityName or "???"
			rarityLbl.TextColor3 = isDiscovered and rarityColor or Color3.new(0.4, 0.4, 0.4)
		end

		local vp = slot:FindFirstChild("ViewportFrame")
		if vp then
			local fishModel = fishesFolder:FindFirstChild(baseName)
			setupModelInViewport(vp, fishModel, currentCategory == "Gold" and isDiscovered, currentCategory == "Sans" and isDiscovered)
			setVpSilhouette(vp, not isDiscovered)
			if isDiscovered then createHoverEffect(slot, vp) end
		end

		local shine = slot:FindFirstChild("Shine")
		if shine then shine.Visible = isDiscovered and not isClaiming end

		if isClaiming then
			addClaimOverlay(slot, displayName, rarityColor)
			startClaimPulse(slot)
			local btn = slot:FindFirstChildOfClass("TextButton")
			if btn then
				btn.MouseButton1Click:Connect(function()
					claimReward(displayName, slot, rarityColor, isVariant)
				end)
			end
		end

		slot.Parent = scrollFrame
		layoutOrder += 1
	end
end

local playerGui = player.PlayerGui

local function refreshUnclaimed()
	local ok, result = pcall(function() return getClaimedRF:InvokeServer() end)

	local claimed        = {}
	local variantClaimed = {}
	if ok and type(result) == "table" then
		claimed        = type(result.claimed)        == "table" and result.claimed        or {}
		variantClaimed = type(result.variantClaimed) == "table" and result.variantClaimed or {}
	end
	lastClaimed        = claimed
	lastVariantClaimed = variantClaimed

	local ls = player:FindFirstChild("leaderstats")
	local fishFolder    = ls and ls:FindFirstChild("Fish")
	local variantFolder = ls and ls:FindFirstChild("FishVariant")
	if not fishFolder then return end

	-- base fish unclaimed
	for _, rd in ipairs(FishRarities) do
		for _, fd in ipairs(rd.fishes) do
			local fishName = fd.fishName
			local fishBool = fishFolder:FindFirstChild(fishName)
			if fishBool then
				if fishBool.Value and not claimed[fishName] then
					unclaimed[fishName] = true
				else
					unclaimed[fishName] = nil
				end
			end
		end
	end

	-- variant unclaimed
	variantUnclaimed = {}
	if variantFolder then
		for _, prefix in ipairs(VARIANT_PREFIXES) do
			for _, rd in ipairs(FishRarities) do
				for _, fd in ipairs(rd.fishes) do
					local key = prefix .. " " .. fd.fishName
					local vBool = variantFolder:FindFirstChild(key)
					if vBool and vBool.Value and not variantClaimed[key] then
						variantUnclaimed[key] = true
					end
				end
			end
		end
	end

	updateNotifBadge()
	updateCategoryBadges()
end

-- Category button selection highlight
local function selectCategory(cat)
	currentCategory = cat
	for _, catName in ipairs({ "Normal", "Gold", "Frozen", "Festival", "Sans" }) do
		local frame = categoriesFrame:FindFirstChild(catName)
		if frame then
			local btn = frame:FindFirstChild("TextButton")
			if btn then
				-- gradient always on; darken color when not selected
				btn.ImageColor3 = catName == cat and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)
				btn.ImageTransparency = 0
			end
			local glow = frame:FindFirstChild("Glow")
			if glow then glow.Visible = catName == cat end
		end
	end
	createFishIndexUI()
end

local function openIndex()
	playerGui:SetAttribute("ActiveLargeUI", "Index")
	newIndexFrame.Visible = true
	uiScale.Scale = 0
	TweenService:Create(uiScale, OPEN_TWEEN, {Scale = 1}):Play()
	blur.Enabled = true
	tweenFOV(60)
	task.spawn(function()
		task.wait(0.3)
		refreshUnclaimed()
		selectCategory(currentCategory)
	end)
end

local function closeIndex()
	playerGui:SetAttribute("ActiveLargeUI", nil)
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

-- Wire up category buttons
for _, catName in ipairs({ "Normal", "Gold", "Frozen", "Festival", "Sans" }) do
	local frame = categoriesFrame:FindFirstChild(catName)
	if frame then
		local btn = frame:FindFirstChild("TextButton")
		if btn then
			btn.MouseButton1Click:Connect(function()
				if currentCategory ~= catName then
					selectCategory(catName)
				end
			end)
		end
	end
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
	local leaderstats   = player:WaitForChild("leaderstats")
	local fishFolder    = leaderstats:WaitForChild("Fish")
	local variantFolder = leaderstats:WaitForChild("FishVariant")

	local dataReady = player:WaitForChild("DataReady", 30)
	if dataReady then
		repeat task.wait() until dataReady.Value == true
	end

	local ok, result = pcall(function() return getClaimedRF:InvokeServer() end)
	local claimed        = {}
	local variantClaimed = {}
	if ok and type(result) == "table" then
		claimed        = type(result.claimed)        == "table" and result.claimed        or {}
		variantClaimed = type(result.variantClaimed) == "table" and result.variantClaimed or {}
	end
	lastClaimed        = claimed
	lastVariantClaimed = variantClaimed

	-- base fish watchers
	for _, rd in ipairs(FishRarities) do
		for _, fd in ipairs(rd.fishes) do
			local fishName = fd.fishName
			local fishBool = fishFolder:FindFirstChild(fishName)
			if fishBool then
				if fishBool.Value and not claimed[fishName] then
					unclaimed[fishName] = true
				end
				fishBool.Changed:Connect(function(newVal)
					if newVal and not lastClaimed[fishName] then
						unclaimed[fishName] = true
						updateNotifBadge()
						updateCategoryBadges()
						if isIndexOpen() and currentCategory == "Normal" then createFishIndexUI() end
					end
				end)
			end
		end
	end

	-- variant watchers
	for _, prefix in ipairs(VARIANT_PREFIXES) do
		for _, rd in ipairs(FishRarities) do
			for _, fd in ipairs(rd.fishes) do
				local key = prefix .. " " .. fd.fishName
				local vBool = variantFolder:FindFirstChild(key)
				if vBool then
					if vBool.Value and not variantClaimed[key] then
						variantUnclaimed[key] = true
					end
					vBool.Changed:Connect(function(newVal)
						if newVal and not lastVariantClaimed[key] then
							variantUnclaimed[key] = true
							updateNotifBadge()
							updateCategoryBadges()
							local prefixMatch = key:sub(1, #prefix) == prefix
							if isIndexOpen() and prefixMatch and currentCategory == prefix then
								createFishIndexUI()
							end
						end
					end)
				end
			end
		end
	end

	updateNotifBadge()
	updateCategoryBadges()
end

newIndexFrame.Visible = false
uiScale.Scale = 0
notifBadge.Visible = false

player.CharacterAdded:Connect(setupDiscoveryWatchers)
if player.Character then task.spawn(setupDiscoveryWatchers) end
