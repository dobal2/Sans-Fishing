local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

local ROD_TOOLS = {
	"FishingRod", "SliverRod", "GoldRod", "CrystalRod", "MagneticRod",
	"BoneRod", "CloverRod", "RainbowRod", "UnknownRod", "RobuxRod",
	"ElectricRod", "RealisticRod", "BlockyRod", "ArcaneRod", "VoidRod",
	"DevRod",
}
local ROD_SET = {}
for _, name in ipairs(ROD_TOOLS) do ROD_SET[name] = true end

-- Attach point: UpperTorso (R15) or Torso (R6)
local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
if not torso then return end

local backRod = nil     -- the visual clone sitting on the back
local backWeld = nil    -- Motor6D / Weld attaching it

local function removeBackRod()
	if backRod then
		backRod:Destroy()
		backRod = nil
		backWeld = nil
	end
end

local function showBackRod(toolName)
	removeBackRod()

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end
	local tool = backpack:FindFirstChild(toolName)
	if not tool then return end
	local srcHandle = tool:FindFirstChild("Handle")
	if not srcHandle then return end

	-- Clone only the Handle (and its descendants for mesh/texture)
	local clone = srcHandle:Clone()
	clone.Name = "BackRodVisual"
	clone.Anchored = false
	clone.CanCollide = false
	clone.CastShadow = false
	clone.Massless = true

	-- Disable any scripts/sounds inside the clone
	for _, v in ipairs(clone:GetDescendants()) do
		if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Sound") then
			v:Destroy()
		end
	end

	clone.Parent = character

	local weld = Instance.new("Weld")
	weld.Name = "BackRodWeld"
	weld.Part0 = torso
	weld.Part1 = clone
	-- Position: diagonal across the back, angled
	-- C0 offsets from torso center; C1 is handle center
	-- Rod lies diagonally: tilt ~40° from vertical, rotated to be across the back
	weld.C0 = CFrame.new(0.2, 0.3, 0.55)
		* CFrame.Angles(math.rad(35), math.rad(15), math.rad(-20))
	weld.C1 = CFrame.new(0, 0, 0)
	weld.Parent = clone

	backRod = clone
	backWeld = weld
end

local currentEquipped = nil   -- tool name if rod is equipped (held), nil otherwise
local currentShown = nil      -- tool name currently displayed on back

local function getEquippedRod()
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") and ROD_SET[tool.Name] then
			return tool.Name
		end
	end
	return nil
end

local function getBackpackRod()
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return nil end
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and ROD_SET[tool.Name] then
			return tool.Name
		end
	end
	return nil
end

local function update()
	local equipped = getEquippedRod()
	if equipped then
		-- Rod is being held — hide back visual
		if backRod then removeBackRod() end
		currentShown = nil
	else
		local inBackpack = getBackpackRod()
		if inBackpack then
			if currentShown ~= inBackpack then
				showBackRod(inBackpack)
				currentShown = inBackpack
			end
		else
			if backRod then removeBackRod() end
			currentShown = nil
		end
	end
end

-- Poll every 0.5s (tool equip/unequip is infrequent)
while true do
	update()
	task.wait(0.5)
end
