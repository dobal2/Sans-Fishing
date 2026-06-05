local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService     = game:GetService("TweenService")

local RECOVER_PRODUCT_ID = 3596255843
local TIMER_DURATION     = 15

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local recoverGui = playerGui:WaitForChild("Recover")
local frame     = recoverGui:WaitForChild("Frame")
local vp        = recoverGui:WaitForChild("ViewportFrame")
local fishNameLbl = recoverGui:WaitForChild("FishName")
local progressBar = recoverGui:WaitForChild("ProgressBar")
local filler    = progressBar:WaitForChild("Main"):WaitForChild("Filler")
local progressText = progressBar:WaitForChild("ProgressText")
local skipFrame = recoverGui:WaitForChild("Skip")
local keepFrame = recoverGui:WaitForChild("Keep")
local skipBtn   = skipFrame:WaitForChild("TextButton")
local keepBtn   = keepFrame:WaitForChild("TextButton")
local keepLbl   = keepFrame:WaitForChild("TextLabel")

local fishesFolder = ReplicatedStorage:WaitForChild("Fishes")
local robuxBuySound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("RobuxBuySound")

local recoverEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("RecoverEvent")

task.spawn(function()
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(RECOVER_PRODUCT_ID, Enum.InfoType.Product)
	end)
	if ok and info and info.PriceInRobux then
		keepLbl.Text = string.format("Keep (\u{E002}%d)", info.PriceInRobux)
	end
end)

local rarityColors = {
	Common    = Color3.fromRGB(255, 255, 255),
	Uncommon  = Color3.fromRGB(12,  255, 32),
	Rare      = Color3.fromRGB(5,   188, 255),
	Epic      = Color3.fromRGB(162, 12,  255),
	Legendary = Color3.fromRGB(255, 0,   221),
	Mystic    = Color3.fromRGB(255, 217, 2),
	Fantasy   = Color3.fromRGB(64,  224, 208),
	Unknown   = Color3.fromRGB(0,   0,   0),
	Soul      = Color3.fromRGB(255, 45, 45),
}

local VP_FOV   = 60
local VP_PITCH = -20
local VP_YAW   = 45
local VP_ZOOM  = 1.2
local VP_OVERRIDES = {
	["Unknown"]       = { pitch = -20, yaw = 45, zoom = 3.5 },
	["Determination"] = { pitch = -5, yaw = 0, zoom = 2.2 },
	["Electric Fish"] = { pitch = -10, yaw = 45, zoom = 0.9 },
	["Nyan Cat"]      = { pitch = -10, yaw = 30, zoom = 0.9 },
}

local function setupViewport(fishName)
	for _, c in ipairs(vp:GetChildren()) do
		if not c:IsA("Camera") then c:Destroy() end
	end
	local fishModel = fishesFolder:FindFirstChild(fishName)
	if not fishModel then return end
	local handle = fishModel:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return end

	vp.Ambient    = Color3.fromRGB(180, 180, 180)
	vp.LightColor = Color3.fromRGB(230, 230, 230)

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = vp
	local clone = handle:Clone()
	clone.CFrame   = CFrame.new(0, 0, 0)
	clone.Anchored = true
	clone.Parent   = worldModel

	local ov    = VP_OVERRIDES[fishName] or {}
	local pitch = ov.pitch or VP_PITCH
	local yaw   = ov.yaw   or VP_YAW
	local zoom  = ov.zoom  or VP_ZOOM
	local size  = clone.Size
	local radius = math.max(size.X, size.Y, size.Z) / 2
	local dist   = (radius / math.tan(math.rad(VP_FOV / 2))) * zoom

	local cam = vp:FindFirstChildOfClass("Camera")
	if not cam then
		cam = Instance.new("Camera")
		cam.Parent = vp
	end
	vp.CurrentCamera = cam
	cam.FieldOfView  = VP_FOV
	cam.CFrame = CFrame.new(0, 0, 0)
		* CFrame.Angles(0, math.rad(yaw), 0)
		* CFrame.Angles(math.rad(pitch), 0, 0)
		* CFrame.new(0, 0, dist)
end

local timerTask = nil
local function closeRecover()
	local t = timerTask
	timerTask = nil
	if t then
		local ok = pcall(task.cancel, t)
		if not ok then end
	end
	recoverGui.Enabled = false
	for _, c in ipairs(vp:GetChildren()) do
		if not c:IsA("Camera") then c:Destroy() end
	end
end

local function startTimer()
	local t = timerTask
	timerTask = nil
	if t then pcall(task.cancel, t) end

	filler.Size = UDim2.new(1, 0, 1, 0)
	progressText.Text = string.format("%.1fs", TIMER_DURATION)

	local startTime = tick()
	local thisTask
	thisTask = task.spawn(function()
		while true do
			task.wait(0.05)
			if timerTask ~= thisTask then return end
			local elapsed = tick() - startTime
			local remaining = math.max(TIMER_DURATION - elapsed, 0)
			local ratio = remaining / TIMER_DURATION

			filler.Size = UDim2.new(ratio, 0, 1, 0)
			progressText.Text = string.format("%.1fs", remaining)

			if remaining <= 0 then
				timerTask = nil
				recoverGui.Enabled = false
				for _, c in ipairs(vp:GetChildren()) do
					if not c:IsA("Camera") then c:Destroy() end
				end
				return
			end
		end
	end)
	timerTask = thisTask
end

recoverEvent.OnClientEvent:Connect(function(data)
	if data == "granted" then
		robuxBuySound:Play()
		closeRecover()
		return
	end
	if type(data) ~= "table" then return end

	local fishName = data.fishName or "Unknown"
	local rarity   = data.rarity   or "Common"
	local weight   = data.weight   or 1
	local color    = rarityColors[rarity] or Color3.fromRGB(255, 255, 255)

	-- Set fish name label
	fishNameLbl.Text       = string.format("%s [%s] - %.1fkg", fishName, rarity, weight)
	fishNameLbl.TextColor3 = color


	setupViewport(fishName)
	recoverGui.Enabled = true
	startTimer()
end)

skipBtn.MouseButton1Click:Connect(function()
	closeRecover()
end)

keepBtn.MouseButton1Click:Connect(function()
	MarketplaceService:PromptProductPurchase(player, RECOVER_PRODUCT_ID)
end)

-- Hide on start
recoverGui.Enabled = false
