local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("Main")
local rodsFrame = mainGui:WaitForChild("Rods")

local RodData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RodDataModule"))
-- FishingRod fallback in case module cache is stale
if not RodData.Rods["FishingRod"] then
	RodData.Rods["FishingRod"] = {
		price = 0, storageName = "FishingRod", displayName = "Fishing Rod",
		position = Vector3.new(0,0,0), luck = "+0%", power = "+15%", weight = "0.5 ~ 100kg",
	}
end
local equipSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Equip")

local scrollingFrame = rodsFrame:WaitForChild("Main"):WaitForChild("ScrollingFrame")
local template = scrollingFrame:WaitForChild("RodSlotTemplate")
template.Visible = false

local closeBtn = rodsFrame:FindFirstChild("Close") and rodsFrame.Close:FindFirstChild("TextButton")

-- 현재 장착 로드
local function getCurrentRod()
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("CurrentRod") and ls.CurrentRod.Value
end

local function getOwnedRods()
	local ls = player:FindFirstChild("leaderstats")
	local rodsFolder = ls and ls:FindFirstChild("Rods")

	local owned = {}
	local addedKeys = {}

	-- FishingRod is always owned by everyone
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

	-- power % 기준 정렬 (낮은 것 → 높은 것), Special은 맨 끝
	local function getPower(data)
		local s = tostring(data.power or "0")
		return tonumber(s:match("([%d%.]+)")) or 9999
	end
	table.sort(owned, function(a, b)
		return getPower(a.data) < getPower(b.data)
	end)

	return owned
end

-- ViewportFrame에 로드 모델 표시
local function loadRodModel(vf, rodKey, rodData)
	local modelName = (rodData.storageName or rodKey) .. "Model"
	local upgradeShop = workspace:FindFirstChild("Upgrade Shop")
	if not upgradeShop then return end
	local model = upgradeShop:FindFirstChild(modelName)
	if not model then return end

	-- 기존 내용 정리
	for _, c in ipairs(vf:GetChildren()) do
		if not c:IsA("UIAspectRatioConstraint") then c:Destroy() end
	end

	vf.Ambient = Color3.fromRGB(180, 180, 180)
	vf.LightColor = Color3.fromRGB(230, 230, 230)
	vf.LightDirection = Vector3.new(-1, -2, -1)

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = vf

	local clone = model:Clone()
	-- Parent first so CFrames are stable before any re-parenting
	clone.Parent = worldModel

	-- Flatten nested sub-Models: extract all BaseParts, destroy empty sub-Models
	local parts = {}
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BasePart") then
			table.insert(parts, desc)
		end
	end
	for _, p in ipairs(parts) do
		p.Anchored = true
		p.Parent = clone
	end
	-- Remove now-empty sub-Models so they don't skew GetBoundingBox
	for _, child in ipairs(clone:GetChildren()) do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	if clone:IsA("BasePart") then clone.Anchored = true end

	-- 회전 적용 후 원점 중앙 정렬 (PivotTo 대신 파트 직접 변환)
	local pitch, yaw, zoom = -30, 60, 0.7
	local rotCF = CFrame.Angles(0, math.rad(yaw), 0)
	local bboxSize
	if clone:IsA("Model") then
		-- Step 1: bounding box 중심 계산
		local bboxCF, sz = clone:GetBoundingBox()
		bboxSize = sz
		-- Step 2: 각 파트를 직접 변환 (중심 이동 + 회전)
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

-- 슬롯 채우기
local function populateSlots()
	-- 기존 슬롯 제거
	for _, c in ipairs(scrollingFrame:GetChildren()) do
		if c:IsA("Frame") and c.Name == "RodSlot" then
			c:Destroy()
		end
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

		-- Luck 첫 번째 → Luck, 두 번째 → Weight
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

		-- 장착 중 강조
		local isEquipped = (currentRod == data.storageName)
		local stroke = slot:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = isEquipped and Color3.fromRGB(255, 220, 50) or Color3.fromRGB(80, 80, 80)
			stroke.Thickness = isEquipped and 3 or 1.5
		end

		-- Equip 버튼 텍스트
		local equipFrame = slot:FindFirstChild("Equip")
		if equipFrame then
			equipFrame.Visible = true
			local equipLabel = equipFrame:FindFirstChildOfClass("TextLabel")
			if equipLabel then
				equipLabel.Text = isEquipped and "Equipped" or "Equip"
			end
		end

		-- ViewportFrame에 모델 로드
		local vf = slot:FindFirstChild("ViewportFrame")
		if vf then
			task.spawn(loadRodModel, vf, rodKey, data)
		end

		-- 클릭 시 로드 장착 (슬롯 전체 TextButton + Equip 안 ImageButton 둘 다 연결)
		local function doEquip()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local shopRemote = remotes and remotes:FindFirstChild("Shop") and remotes.Shop:FindFirstChild("BuyFishingRod")
			if shopRemote then
				shopRemote:FireServer(rodKey)
				equipSound:Play()
			end
			task.wait(0.3)
			populateSlots()
		end

		local textBtn = slot:FindFirstChild("TextButton")
		if textBtn then
			textBtn.MouseButton1Click:Connect(doEquip)
		end
		if equipFrame then
			local equipBtn = equipFrame:FindFirstChildOfClass("ImageButton")
			if equipBtn then
				equipBtn.MouseButton1Click:Connect(doEquip)
			end
		end

		slot.Parent = scrollingFrame
	end
end

-- 창 열기/닫기
local function openRods()
	populateSlots()
	rodsFrame.Visible = true
end

local function closeRods()
	rodsFrame.Visible = false
end

if closeBtn then
	closeBtn.MouseButton1Click:Connect(closeRods)
end

rodsFrame.Visible = false

-- Rods 툴 장착/해제 감지
local function setupCharacter(char)
	character = char
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Rods" then
			openRods()
		end
	end)
	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Rods" then
			closeRods()
		end
	end)
end

setupCharacter(character)
player.CharacterAdded:Connect(setupCharacter)
