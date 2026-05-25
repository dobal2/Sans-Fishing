local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local ROBUX_BOBBER_GAMEPASS_ID = 1853589181
local cachedRobuxBobberOwned = false

task.spawn(function()
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, ROBUX_BOBBER_GAMEPASS_ID)
	end)
	if ok and owns then
		cachedRobuxBobberOwned = true
	end
end)
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("Main")
local equipFrame = mainGui:WaitForChild("Equipments")

local RodData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RodDataModule"))
local BobberData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BobberDataModule"))

if not RodData.Rods["FishingRod"] then
	RodData.Rods["FishingRod"] = {
		price = 0, storageName = "FishingRod", displayName = "Fishing Rod",
		position = Vector3.new(0,0,0), luck = "+0%", power = "+15%", weight = "0.5 ~ 100kg",
	}
end

local equipSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Equip")
local equipBobberRemote = ReplicatedStorage:WaitForChild("EquipBobberRemote")
local bobberModels = ReplicatedStorage:WaitForChild("Bobbers")

local mainContent = equipFrame:WaitForChild("Main")
local scrollingFrame = mainContent:WaitForChild("ScrollingFrame")
local template = scrollingFrame:WaitForChild("RodSlotTemplate")
template.Visible = false

local bobberScrollingFrame = mainContent:WaitForChild("BobberScrollingFrame")
local bobberTemplate = bobberScrollingFrame:WaitForChild("BobberSlotTemplate")
bobberTemplate.Visible = false

local closeBtn = equipFrame:FindFirstChild("Close") and equipFrame.Close:FindFirstChild("TextButton")

local function getCurrentRod()
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("CurrentRod") and ls.CurrentRod.Value
end

local function getCurrentBobber()
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("EquippedBobber") and ls.EquippedBobber.Value or "Basic Bobber"
end

local function getOwnedRods()
	local ls = player:FindFirstChild("leaderstats")
	local rodsFolder = ls and ls:FindFirstChild("Rods")

	local owned = {}
	local addedKeys = {}

	local fishingRodData = RodData.Rods["FishingRod"]
	if fishingRodData then
		table.insert(owned, {key = "FishingRod", data = fishingRodData})
		addedKeys["FishingRod"] = true
	end

	if rodsFolder then
		for rodKey, data in pairs(RodData.Rods) do
			if not addedKeys[rodKey] then
				local bv = rodsFolder:FindFirstChild(data.storageName)
				if bv and bv.Value then
					table.insert(owned, {key = rodKey, data = data})
				end
			end
		end
	end

	local function getPower(data)
		local s = tostring(data.power or "0")
		return tonumber(s:match("([%d%.]+)")) or 9999
	end
	table.sort(owned, function(a, b)
		return getPower(a.data) < getPower(b.data)
	end)

	return owned
end

local function getOwnedBobbers()
	local ls = player:FindFirstChild("leaderstats")
	local ownedFolder = ls and ls:FindFirstChild("OwnedBobbers")
	if not ownedFolder then return {{"Basic Bobber", BobberData.Bobbers["Basic Bobber"]}} end

	local owned = {}
	local hasRobuxBobber = false
	for _, bv in ipairs(ownedFolder:GetChildren()) do
		if bv:IsA("BoolValue") and bv.Value then
			local data = BobberData.Bobbers[bv.Name]
			if data then
				table.insert(owned, {bv.Name, data})
				if bv.Name == "Robux Bobber" then hasRobuxBobber = true end
			end
		end
	end
	if not hasRobuxBobber and cachedRobuxBobberOwned then
		local data = BobberData.Bobbers["Robux Bobber"]
		if data then table.insert(owned, {"Robux Bobber", data}) end
	end

	table.sort(owned, function(a, b)
		return (a[2].price or 0) < (b[2].price or 0)
	end)

	return owned
end

local function loadRodModel(vf, rodKey, rodData)
	local modelName = (rodData.storageName or rodKey) .. "Model"
	local upgradeShop = workspace:FindFirstChild("Upgrade Shop")
	if not upgradeShop then return end
	local model = upgradeShop:FindFirstChild(modelName)
	if not model then return end

	for _, c in ipairs(vf:GetChildren()) do
		if not c:IsA("UIAspectRatioConstraint") then c:Destroy() end
	end

	vf.Ambient = Color3.fromRGB(180, 180, 180)
	vf.LightColor = Color3.fromRGB(230, 230, 230)
	vf.LightDirection = Vector3.new(-1, -2, -1)

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = vf

	local clone = model:Clone()
	clone.Parent = worldModel

	local parts = {}
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BasePart") then table.insert(parts, desc) end
	end
	for _, p in ipairs(parts) do
		p.Anchored = true
		p.Parent = clone
	end
	for _, child in ipairs(clone:GetChildren()) do
		if child:IsA("Model") then child:Destroy() end
	end
	if clone:IsA("BasePart") then clone.Anchored = true end

	local pitch, yaw, zoom = -30, 60, 0.7
	local rotCF = CFrame.Angles(0, math.rad(yaw), 0)
	local bboxSize
	if clone:IsA("Model") then
		local bboxCF, sz = clone:GetBoundingBox()
		bboxSize = sz
		local toOrigin = CFrame.new(-bboxCF.Position)
		for _, p in ipairs(clone:GetChildren()) do
			if p:IsA("BasePart") then
				p.CFrame = rotCF * toOrigin * p.CFrame
			end
		end
	else
		clone.CFrame = rotCF
		clone.Anchored = true
		bboxSize = clone.Size
	end

	local camera = Instance.new("Camera")
	camera.FieldOfView = 60
	local halfFov = math.rad(60 / 2)
	local radius = math.max(bboxSize.X, bboxSize.Y, bboxSize.Z) / 2
	local dist = (radius / math.tan(halfFov)) * zoom
	camera.CFrame = CFrame.Angles(math.rad(pitch), math.rad(yaw), 0) * CFrame.new(0, 0, dist)
	camera.Focus = CFrame.new(0, 0, 0)
	camera.Parent = vf
	vf.CurrentCamera = camera
end

local function loadBobberModel(vf, bobberName)
	for _, c in ipairs(vf:GetChildren()) do
		if not c:IsA("UIAspectRatioConstraint") then c:Destroy() end
	end

	local tmpl = bobberModels:FindFirstChild(bobberName)
	if not tmpl then return end

	vf.Ambient = Color3.fromRGB(180, 180, 180)
	vf.LightColor = Color3.fromRGB(230, 230, 230)
	vf.LightDirection = Vector3.new(-1, -2, -1)

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = vf

	local clone = tmpl:Clone()
	clone.Anchored = true
	clone.CFrame = CFrame.new(0, 0, 0)
	clone.Parent = worldModel

	local camera = Instance.new("Camera")
	camera.FieldOfView = 60
	local radius = math.max(clone.Size.X, clone.Size.Y, clone.Size.Z) / 2
	local dist = (radius / math.tan(math.rad(30))) * 1.8
	camera.CFrame = CFrame.new(0, 0, dist)
	camera.Focus = CFrame.new(0, 0, 0)
	camera.Parent = vf
	vf.CurrentCamera = camera
end

local function populateRodSlots()
	for _, c in ipairs(scrollingFrame:GetChildren()) do
		if c:IsA("Frame") and c.Name == "RodSlot" then c:Destroy() end
	end

	local owned = getOwnedRods()
	local currentRod = getCurrentRod()

	for slotIndex, entry in ipairs(owned) do
		local rodKey = entry.key
		local data = entry.data
		local displayName = data.displayName or rodKey

		local slot = template:Clone()
		slot.Name = "RodSlot"
		slot.Visible = true
		slot.LayoutOrder = slotIndex

		local title = slot:FindFirstChild("Title")
		if title then title.Text = displayName end

		local power = slot:FindFirstChild("Power")
		if power then power.Text = "Power: " .. (data.power or "?") end

		local luckSet = false
		local weightSet = false
		for _, c in ipairs(slot:GetChildren()) do
			if c.Name == "Luck" and c:IsA("TextLabel") then
				if not luckSet then
					c.Text = "Luck: " .. (data.luck or "?")
					luckSet = true
				elseif not weightSet then
					c.Text = "Weight: " .. (data.weight or "?")
					weightSet = true
				end
			end
		end

		local isEquipped = (currentRod == data.storageName)
		local stroke = slot:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = isEquipped and Color3.fromRGB(255, 220, 50) or Color3.fromRGB(80, 80, 80)
			stroke.Thickness = isEquipped and 3 or 1.5
		end

		local equipButtonFrame = slot:FindFirstChild("Equip")
		if equipButtonFrame then
			equipButtonFrame.Visible = true
			local equipLabel = equipButtonFrame:FindFirstChildOfClass("TextLabel")
			if equipLabel then equipLabel.Text = isEquipped and "Equipped" or "Equip" end
		end

		local vf = slot:FindFirstChild("ViewportFrame")
		if vf then task.spawn(loadRodModel, vf, rodKey, data) end

		local function doEquip()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local shopRemote = remotes and remotes:FindFirstChild("Shop") and remotes.Shop:FindFirstChild("BuyFishingRod")
			if shopRemote then
				shopRemote:FireServer(rodKey)
				equipSound:Play()
			end
			task.wait(0.3)
			populateRodSlots()
		end

		local textBtn = slot:FindFirstChild("TextButton")
		if textBtn then textBtn.MouseButton1Click:Connect(doEquip) end
		if equipButtonFrame then
			local equipBtn = equipButtonFrame:FindFirstChildOfClass("ImageButton")
			if equipBtn then equipBtn.MouseButton1Click:Connect(doEquip) end
		end

		slot.Parent = scrollingFrame
	end
end

local function populateBobberSlots()
	for _, c in ipairs(bobberScrollingFrame:GetChildren()) do
		if c:IsA("Frame") and c.Name == "BobberSlot" then c:Destroy() end
	end

	local owned = getOwnedBobbers()
	local currentBobber = getCurrentBobber()

	for slotIndex, entry in ipairs(owned) do
		local bobberName = entry[1]
		local data = entry[2]

		local slot = bobberTemplate:Clone()
		slot.Name = "BobberSlot"
		slot.Visible = true
		slot.LayoutOrder = slotIndex

		local title = slot:FindFirstChild("Title")
		if title then title.Text = bobberName end

		local descLabel = slot:FindFirstChild("Desc")
		if descLabel then descLabel.Text = data.desc or "" end

		local isEquipped = (currentBobber == bobberName)
		local stroke = slot:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = isEquipped and Color3.fromRGB(255, 220, 50) or Color3.fromRGB(80, 80, 80)
			stroke.Thickness = isEquipped and 3 or 1.5
		end

		local equipButtonFrame = slot:FindFirstChild("Equip")
		if equipButtonFrame then
			equipButtonFrame.Visible = true
			local equipLabel = equipButtonFrame:FindFirstChildOfClass("TextLabel")
			if equipLabel then equipLabel.Text = isEquipped and "Equipped" or "Equip" end
		end

		local vf = slot:FindFirstChild("ViewportFrame")
		if vf then task.spawn(loadBobberModel, vf, bobberName) end

		local function doEquip()
			if isEquipped then return end
			equipBobberRemote:FireServer(bobberName)
			equipSound:Play()
			task.wait(0.3)
			populateBobberSlots()
		end

		local textBtn = slot:FindFirstChild("TextButton")
		if textBtn then textBtn.MouseButton1Click:Connect(doEquip) end
		if equipButtonFrame then
			local equipBtn = equipButtonFrame:FindFirstChildOfClass("ImageButton")
			if equipBtn then equipBtn.MouseButton1Click:Connect(doEquip) end
		end

		slot.Parent = bobberScrollingFrame
	end

	-- Keep UIPadding and Padding frames last in children order
	for _, c in ipairs(bobberScrollingFrame:GetChildren()) do
		if c:IsA("Frame") and c.Name == "Padding" then
			c.LayoutOrder = 999999
		end
	end
	local pad = bobberScrollingFrame:FindFirstChildWhichIsA("UIPadding")
	if pad then
		pad.Parent = nil
		pad.Parent = bobberScrollingFrame
	end
end

local function openEquipments()
	populateRodSlots()
	populateBobberSlots()
	equipFrame.Visible = true
end

local function closeEquipments()
	equipFrame.Visible = false
end

if closeBtn then
	closeBtn.MouseButton1Click:Connect(closeEquipments)
end

equipFrame.Visible = false

local function setupCharacter(char)
	character = char
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Equipment" then
			openEquipments()
		end
	end)
	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Equipment" then
			closeEquipments()
		end
	end)
end

setupCharacter(character)
player.CharacterAdded:Connect(setupCharacter)

-- Refresh bobber slots when any bobber is granted mid-session
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	local ownedFolder = ls:WaitForChild("OwnedBobbers")
	local function watchBobber(bv)
		bv.Changed:Connect(function()
			if equipFrame.Visible then populateBobberSlots() end
		end)
	end
	for _, bv in ipairs(ownedFolder:GetChildren()) do
		if bv:IsA("BoolValue") then watchBobber(bv) end
	end
	ownedFolder.ChildAdded:Connect(function(bv)
		if bv:IsA("BoolValue") then watchBobber(bv) end
	end)
end)

-- Refresh rod slots when any rod is purchased mid-session
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	local rodsFolder = ls:WaitForChild("Rods")
	local function watchRod(bv)
		bv.Changed:Connect(function()
			if equipFrame.Visible then populateRodSlots() end
		end)
	end
	for _, bv in ipairs(rodsFolder:GetChildren()) do
		if bv:IsA("BoolValue") then watchRod(bv) end
	end
	rodsFolder.ChildAdded:Connect(function(bv)
		if bv:IsA("BoolValue") then watchRod(bv) end
	end)
end)
