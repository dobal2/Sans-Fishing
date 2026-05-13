local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")

local PRODUCT_1X = 3591644219
local VP_CHANGE_INTERVAL = 4  -- seconds between silhouette changes in buy panel

local RARITY_COLORS = {
	Common    = Color3.fromRGB(255, 255, 255),
	Uncommon  = Color3.fromRGB(12,  255,  32),
	Rare      = Color3.fromRGB(5,   188, 255),
	Epic      = Color3.fromRGB(162,  12, 255),
	Legendary = Color3.fromRGB(255,   0, 221),
	Mystic    = Color3.fromRGB(255, 217,   2),
	Fantasy   = Color3.fromRGB(64,  224, 208),
	Unknown   = Color3.fromRGB(0,     0,   0),
}

local player = Players.LocalPlayer
local main   = script.Parent

local buyFrame = main:WaitForChild("RandomFish")
local button   = buyFrame:FindFirstChild("Button")
local buyVp    = buyFrame:FindFirstChild("ViewportFrame")

local playerGui = player:WaitForChild("PlayerGui")
local rfGui     = playerGui:WaitForChild("RandomFish", 10)
local rfFrame   = rfGui and rfGui:WaitForChild("Random", 10)
local viewport  = rfFrame and rfFrame:FindFirstChild("ViewportFrame")
local shine     = rfFrame and rfFrame:FindFirstChild("Shine")
local nameLbl   = rfFrame and rfFrame:FindFirstChild("Robux")
local rarityLbl = rfFrame and rfFrame:FindFirstChild("Rarity")

-- Start hidden
-- ScreenGui stays Enabled; hide the frame until reveal
if rfFrame then rfFrame.Visible = false end

local fishesFolder = ReplicatedStorage:FindFirstChild("Fishes")

-- ── Buy panel: rotating black silhouette ─────────────────────────
local function setBuyVpFish(fishName)
	if not buyVp or not fishesFolder then return end
	local fishModel = fishesFolder:FindFirstChild(fishName)
	local handle = fishModel and fishModel:FindFirstChild("Handle")
	if not handle then return end

	for _, c in ipairs(buyVp:GetChildren()) do
		if c:IsA("BasePart") or c:IsA("Camera") then c:Destroy() end
	end

	local cloned = handle:Clone()
	local maxDim = math.max(cloned.Size.X, cloned.Size.Y, cloned.Size.Z)
	local targetSize = (fishName == "Unknown" or fishName == "Nyan Cat") and 1.5 or 3
	local scale = targetSize / maxDim
	cloned.Size = cloned.Size * scale
	local mesh = cloned:FindFirstChildOfClass("SpecialMesh")
	if mesh then mesh.Scale = mesh.Scale * scale end
	cloned.CFrame = CFrame.new(0, 0, 0)
	cloned.Transparency = 0
	cloned.Color = Color3.new(0, 0, 0)
	cloned.Material = Enum.Material.SmoothPlastic
	cloned.CastShadow = false
	cloned.Parent = buyVp

	buyVp.Ambient    = Color3.new(0, 0, 0)
	buyVp.LightColor = Color3.new(0, 0, 0)

	local cam = Instance.new("Camera", buyVp)
	buyVp.CurrentCamera = cam
	cam.CFrame = CFrame.lookAt(Vector3.new(2.2, 0.8, 2.2), Vector3.new(0, 0, 0))
end

task.spawn(function()
	if not fishesFolder then return end
	while #fishesFolder:GetChildren() == 0 do task.wait(0.5) end
	local idx = math.random(1, #FISH_POOL_NAMES)
	setBuyVpFish(FISH_POOL_NAMES[idx])
	while buyFrame.Parent do
		task.wait(VP_CHANGE_INTERVAL)
		idx = (idx % #FISH_POOL_NAMES) + 1
		setBuyVpFish(FISH_POOL_NAMES[idx])
	end
end)

-- ── Reveal panel ─────────────────────────────────────────────────
local vpScale = viewport and viewport:FindFirstChildOfClass("UIScale")
if not vpScale and viewport then
	vpScale = Instance.new("UIScale")
	vpScale.Scale = 1
	vpScale.Parent = viewport
end

local GACHA_RARITIES = {
	Epic=true, Legendary=true, Mystic=true, Fantasy=true, Unknown=true
}
local FISH_POOL_NAMES = {
	"Dragon Head Fish", "Reggigash",
	"Golden Trout", "Armor Fish",
	"Shark", "Ray",
	"Undyine", "Sans", "Electric Fish",
	"Unknown", "Nyan Cat",
}

local allFishNames = FISH_POOL_NAMES

local shineRot = 0
RunService.Heartbeat:Connect(function(dt)
	shineRot += dt * 45
	if shine then shine.Rotation = shineRot end
end)

local function setVpFish(fishName, silhouette)
	if not viewport or not fishesFolder then return end
	local fishModel = fishesFolder:FindFirstChild(fishName)
	local handle = fishModel and fishModel:FindFirstChild("Handle")
	if not handle then return end

	for _, c in ipairs(viewport:GetChildren()) do
		if c:IsA("BasePart") or c:IsA("Camera") then c:Destroy() end
	end

	local cloned = handle:Clone()
	local maxDim = math.max(cloned.Size.X, cloned.Size.Y, cloned.Size.Z)
	local targetSize = (fishName == "Unknown" or fishName == "Nyan Cat") and 1.5 or 3
	local scale = targetSize / maxDim
	cloned.Size = cloned.Size * scale
	local mesh = cloned:FindFirstChildOfClass("SpecialMesh")
	if mesh then mesh.Scale = mesh.Scale * scale end
	cloned.CFrame = CFrame.new(0, 0, 0)
	cloned.Transparency = 0
	if silhouette then
		cloned.Color = Color3.new(0, 0, 0)
		cloned.Material = Enum.Material.SmoothPlastic
		viewport.Ambient    = Color3.new(0, 0, 0)
		viewport.LightColor = Color3.new(0, 0, 0)
	else
		viewport.Ambient    = Color3.fromRGB(180, 180, 180)
		viewport.LightColor = Color3.fromRGB(230, 230, 230)
	end
	cloned.Parent = viewport

	local cam = Instance.new("Camera", viewport)
	viewport.CurrentCamera = cam
	cam.CFrame = CFrame.lookAt(Vector3.new(2.2, 0.8, 2.2), Vector3.new(0, 0, 0))
end

local function vpPop(shrinkTo)
	if not vpScale then return end
	shrinkTo = shrinkTo or 0.65
	TweenService:Create(vpScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = shrinkTo}):Play()
	task.delay(0.07, function()
		TweenService:Create(vpScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end)
end

local revealing = false

local function playReveal(fishName, rarityName)
	if not rfFrame or not rfGui then
		warn("RandomFish reveal: rfGui/rfFrame not found")
		return
	end
	if revealing then return end
	if #allFishNames == 0 then
		if fishesFolder then
			for _, f in ipairs(fishesFolder:GetChildren()) do
				table.insert(allFishNames, f.Name)
			end
		end
		if #allFishNames == 0 then return end
	end
	revealing = true

	task.delay(0.4, function()
		if not revealing then return end
		if vpScale then vpScale.Scale = 1 end
		rfFrame.Visible = true

		local TOTAL_SPIN = 6.0
		local elapsed    = 0
		local lastChange = 0

		local spinConn
		spinConn = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			local progress = math.clamp(elapsed / TOTAL_SPIN, 0, 1)
			local interval = 0.04 + progress ^ 2.5 * 0.55

			if elapsed - lastChange >= interval then
				lastChange = elapsed
				local randFish = allFishNames[math.random(1, #allFishNames)]
				setVpFish(randFish, true)
				vpPop()
				if nameLbl then nameLbl.Text = randFish; nameLbl.TextColor3 = Color3.new(1,1,1) end
				if rarityLbl then rarityLbl.Text = "???"; rarityLbl.TextColor3 = Color3.new(1,1,1) end
			end

			if elapsed >= TOTAL_SPIN then
				spinConn:Disconnect()
				setVpFish(fishName, true)
				vpPop(0.5)

				task.delay(0.2, function()
					task.delay(0.15, function()
						setVpFish(fishName, false)
						if vpScale then
							vpScale.Scale = 0.5
							TweenService:Create(vpScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
						end

						local rarityColor = RARITY_COLORS[rarityName] or Color3.new(1,1,1)
						if nameLbl then
							nameLbl.Text = fishName
							nameLbl.TextColor3 = Color3.new(1,1,1)
							local op = nameLbl.Position
							nameLbl.Position = UDim2.new(op.X.Scale, op.X.Offset, op.Y.Scale + 0.05, op.Y.Offset)
							TweenService:Create(nameLbl, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = op}):Play()
						end
						task.delay(0.1, function()
							if rarityLbl then
								rarityLbl.Text = rarityName
								rarityLbl.TextColor3 = rarityColor
								local op2 = rarityLbl.Position
								rarityLbl.Position = UDim2.new(op2.X.Scale, op2.X.Offset, op2.Y.Scale + 0.05, op2.Y.Offset)
								TweenService:Create(rarityLbl, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = op2}):Play()
							end
						end)

						local closed = false
						local function doClose()
							if closed then return end
							closed = true
							task.delay(0.3, function()
								rfFrame.Visible = false
								if nameLbl then nameLbl.Text = "" end
								if rarityLbl then rarityLbl.Text = ""; rarityLbl.TextColor3 = Color3.new(1,1,1) end
								if vpScale then vpScale.Scale = 1 end
								revealing = false
								-- Fire notice after reveal closes
								local noticeEvent = ReplicatedStorage:FindFirstChild("DiscoverNoticeEvent")
								local msg = string.format("You got: %s [%s]!", fishName, rarityName)
								if noticeEvent then noticeEvent:Fire(msg) end -- BindableEvent
							end)
						end

						task.delay(1.5, function()
							if closed then return end
							local closeConn
							closeConn = rfFrame.InputBegan:Connect(function()
								closeConn:Disconnect()
								doClose()
							end)
							task.delay(5, doClose)
						end)
					end)
				end)
			end
		end)
	end)
end

-- ── Buttons ───────────────────────────────────────────────────────
if button then
	button.Activated:Connect(function()
		MarketplaceService:PromptProductPurchase(player, PRODUCT_1X)
	end)
end

-- ── Result remote ─────────────────────────────────────────────────
local resultRemote = ReplicatedStorage:WaitForChild("RandomFishResult", 30)
if resultRemote then
	resultRemote.OnClientEvent:Connect(function(fishName, rarityName)
		playReveal(fishName, rarityName)
	end)
end
