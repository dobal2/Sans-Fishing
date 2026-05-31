local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local BIG_FISH_THRESHOLD = 30.0

local holdBigFishAnim = nil
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("Animations", 30)
	if folder then
		holdBigFishAnim = folder:WaitForChild("HoldBigFish", 10)
	end
end)

local currentTrack = nil
local isStopping = false

local function getAnimator(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function stopBigFishAnim()
	if isStopping then return end
	isStopping = true
	if currentTrack then
		currentTrack:Stop()
		currentTrack = nil
	end
	isStopping = false
end

local function playBigFishAnim(character)
	if not holdBigFishAnim then return end
	local animator = getAnimator(character)
	if not animator then return end

	stopBigFishAnim()

	local ok, track = pcall(function()
		return animator:LoadAnimation(holdBigFishAnim)
	end)
	if not ok then return end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play()
	currentTrack = track
end

local BIG_FISH_EXCLUDE = { ["Crab"] = true }

local function isBigFishTool(tool)
	local fw = tool:FindFirstChild("FishWeight")
	if not fw or fw.Value < BIG_FISH_THRESHOLD then return false end
	local baseName = tool.Name:gsub("%s*%[.-%]%s*%-.*", ""):match("^%s*(.-)%s*$")
	return not BIG_FISH_EXCLUDE[baseName]
end

local function hasBigFishEquipped(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and isBigFishTool(child) then
			return true
		end
	end
	return false
end

local function watchCharacter(character)
	stopBigFishAnim()

	local toolConnections = {}

	character.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") then return end
		if toolConnections[child] then return end

		local conn = child.Unequipped:Connect(function()
			stopBigFishAnim()
		end)
		toolConnections[child] = conn

		task.defer(function()
			if child.Parent and isBigFishTool(child) then
				playBigFishAnim(character)
			end
		end)
	end)

	character.ChildRemoved:Connect(function(child)
		if toolConnections[child] then
			toolConnections[child]:Disconnect()
			toolConnections[child] = nil
		end
		-- 캐릭터에서 도구가 제거될 때 big fish가 더 없으면 애니 중단
		if child:IsA("Tool") then
			task.defer(function()
				if not hasBigFishEquipped(character) then
					stopBigFishAnim()
				end
			end)
		end
	end)
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	watchCharacter(player.Character)
end
