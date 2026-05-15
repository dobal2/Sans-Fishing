local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local BIG_FISH_THRESHOLD = 30.0

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

local holdBigFishAnim = nil
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("Animations", 30)
	if folder then
		holdBigFishAnim = folder:WaitForChild("HoldBigFish", 10)
	end
end)

local currentTrack = nil

local function stopBigFishAnim()
	if currentTrack then
		currentTrack:Stop()
		currentTrack = nil
	end
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

local function onToolEquipped(tool, character)
	local fw = tool:FindFirstChild("FishWeight")
	if not fw then return end -- 물고기 Tool이 아님

	if fw.Value >= BIG_FISH_THRESHOLD then
		playBigFishAnim(character)
	end
end

local function onToolUnequipped()
	stopBigFishAnim()
end

local function watchCharacter(character)
	stopBigFishAnim()

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			-- Equipped 시점에 FishWeight가 아직 복제 안 됐을 수 있으므로 잠깐 대기
			task.defer(function()
				onToolEquipped(child, character)
			end)
			child.Unequipped:Connect(onToolUnequipped)
		end
	end)
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	watchCharacter(player.Character)
end
