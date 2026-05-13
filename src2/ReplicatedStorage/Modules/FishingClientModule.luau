local FishingClient = {}
FishingClient.__index = FishingClient

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local FishDifficulty = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDifficultyModule"))
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishingConfigModule"))
local failSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Fail")
local SuccessSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Success sound")
local SuccessBellSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("success bell")
local GUI = ReplicatedStorage:WaitForChild("FishingGui")
local RandomGen = Random.new()

-- Tutorial event
local tutorialEvent = ReplicatedStorage:WaitForChild("TutorialEvent")

-- Per-tool instance map
local instanceMap = {}

function FishingClient.init(tool)
	if instanceMap[tool] then
		warn("FishingClient already initialized for this tool.")
		return instanceMap[tool]
	end

	local self = setmetatable({}, FishingClient)
	instanceMap[tool] = self

	self.tool = tool

	self.fishingAnimationTrack = nil
	self.waitingAnimationTrack = nil
	self.finishAnimationTrack = nil
	self.holdingAnimationTrack = nil
	self.fishBaitEatAnimationTrack = nil
	self.reelingAnimationTrack = nil

	self.preloadedFishingAnimation = nil
	self.preloadedWaitingAnimation = nil
	self.preloadedFinishAnimation = nil
	self.preloadedHoldingAnimation = nil
	self.preloadedHoldBigFishAnimation = nil
	self.preloadedFishBaitEatAnimation = nil
	self.preloadedReelingAnimation = nil
	self.lastFishWeight = 0

	-- Preload animations
	self:_preloadAnimations()

	self.isProcessing = false
	self.inputCooldown = 0
	self.player = game.Players.LocalPlayer
	self.remote = tool:WaitForChild("RemoteEvent")
	self.castEvent = tool:WaitForChild("CastRod")
	self.locked = false
	self.newGUI = nil
	self.sliderTween = nil
	self.slider = nil
	self.hitZone = nil
	self.strongZone = nil
	self.baitThrown = false
	self.baitThrowTime = 0
	self.cancelDelay = 2

	-- Shake effect variables
	self.frame = nil
	self.originalFramePosition = nil

	-- Progress bar game variables
	self.currentProgress = 0
	self.maxProgress = 100
	self.strongZoneProgress = 20
	self.normalZoneProgress = 10
	self.rodPower = 1.0
	self.progressBar = nil
	self.progressFill = nil
	self.progressTween = nil

	-- Protection time after minigame ends
	self.gameEndCooldown = 0

	-- UserInputService connection variables
	self.inputBeganConnection = nil
	self.inputEndedConnection = nil

	-- Auto fishing click bridge
	local autoClickEvent = Instance.new("BindableEvent")
	autoClickEvent.Name = "AutoClickEvent"
	autoClickEvent.Parent = tool
	autoClickEvent.Event:Connect(function()
		if self.newGUI then
			self:_processFishingInput()
		end
	end)
	self.autoClickEvent = autoClickEvent

	-- Auto fishing cast bridge
	local autoCastEvent = Instance.new("BindableEvent")
	autoCastEvent.Name = "AutoCastEvent"
	autoCastEvent.Parent = tool
	autoCastEvent.Event:Connect(function()
		if not self.newGUI and not self.locked and not self.baitThrown then
			local character = self.player.Character
			if not character then return end
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then return end
			local hum = character:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then return end

			local lookDirection = humanoidRootPart.CFrame.LookVector
			local currentPosition = humanoidRootPart.Position
			local targetPosition = currentPosition + (lookDirection * 50)
			targetPosition = Vector3.new(targetPosition.X, currentPosition.Y, targetPosition.Z)

			self.locked = true
			self.baitThrown = true
			self.baitThrowTime = tick()
			self:_stopHoldingAnimation()
			self:_playFishingAnimation()
			tutorialEvent:Fire("baitThrow_success")

			task.delay(0.3, function()
				if self.baitThrown and not self.newGUI then
					self.castEvent:FireServer(targetPosition)
					self:_startClientBaitTracking()
				end
			end)
		end
	end)
	self.autoCastEvent = autoCastEvent

	self:_bind()
	return self
end

local INVENTORY_EXPANSION_GAMEPASS_ID = 1294285302

-- Check inventory expansion gamepass on client
function FishingClient:_hasInventoryExpansionGamepass()
	local success, hasGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(self.player.UserId, INVENTORY_EXPANSION_GAMEPASS_ID)
	end)

	if success then
		return hasGamepass
	else
		warn("Client: Failed to check inventory expansion gamepass")
		return false
	end
end

-- Fast position + rotation compound shake effect
function FishingClient:_shakeFrame()
	if not self.frame or not self.originalFramePosition then return end

	local shakeIntensity = 6
	local maxRotation = 3
	local shakeDuration = 0.12
	local shakeCount = 20

	task.spawn(function()
		local shakeTime = shakeDuration / shakeCount

		for i = 1, shakeCount do
			if not self.frame then break end

			local randomX = RandomGen:NextNumber(-shakeIntensity, shakeIntensity)
			local randomY = RandomGen:NextNumber(-shakeIntensity, shakeIntensity)
			local randomRotation = RandomGen:NextNumber(-maxRotation, maxRotation)

			local fadeMultiplier = (shakeCount - i + 1) / shakeCount
			randomX = randomX * fadeMultiplier
			randomY = randomY * fadeMultiplier
			randomRotation = randomRotation * fadeMultiplier

			local shakePosition = UDim2.new(
				self.originalFramePosition.X.Scale,
				self.originalFramePosition.X.Offset + randomX,
				self.originalFramePosition.Y.Scale,
				self.originalFramePosition.Y.Offset + randomY
			)

			local tweenInfo = TweenInfo.new(shakeTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			local shakeTween = TweenService:Create(self.frame, tweenInfo, {
				Position = shakePosition,
				Rotation = randomRotation
			})
			shakeTween:Play()
			shakeTween.Completed:Wait()
		end

		if self.frame and self.originalFramePosition then
			local returnTweenInfo = TweenInfo.new(0.03, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			local returnTween = TweenService:Create(self.frame, returnTweenInfo, {
				Position = self.originalFramePosition,
				Rotation = 0
			})
			returnTween:Play()
		end
	end)
end

-- Update progress bar
function FishingClient:_updateProgressBar()
	if self.progressFill then
		local progressPercent = self.currentProgress / self.maxProgress
		local targetSize = UDim2.new(progressPercent, 0, 1, 0)

		if self.progressTween then
			self.progressTween:Cancel()
		end

		local tweenInfo = TweenInfo.new(
			0.5,
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.Out
		)

		self.progressTween = TweenService:Create(self.progressFill, tweenInfo, {
			Size = targetSize
		})
		self.progressTween:Play()

		local targetColor
		if progressPercent >= 0.8 then
			targetColor = Color3.fromRGB(46, 204, 113)
		elseif progressPercent >= 0.5 then
			targetColor = Color3.fromRGB(241, 196, 15)
		else
			targetColor = Color3.fromRGB(231, 76, 60)
		end

		local colorTween = TweenService:Create(self.progressFill, tweenInfo, {
			BackgroundColor3 = targetColor
		})
		colorTween:Play()
	end
end

-- Hit zone rotation effect
function FishingClient:_rotateHitZone()
	if not self.hitZone then return end

	local originalRotation = self.hitZone.Rotation

	task.spawn(function()
		local rotateLeft = TweenService:Create(self.hitZone,
			TweenInfo.new(0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{Rotation = originalRotation - 10}
		)
		rotateLeft:Play()
		rotateLeft.Completed:Wait()

		local rotateBack = TweenService:Create(self.hitZone,
			TweenInfo.new(0.15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{Rotation = originalRotation}
		)
		rotateBack:Play()
	end)
end

-- Hit text effect
function FishingClient:_showHitText(hitType, hitPosition)
	if not self.frame then return end

	local textContent = hitType == "strong" and "Perfect!" or "Good"
	local textColor = hitType == "strong" and Color3.fromRGB(255, 12, 16) or Color3.fromRGB(46, 204, 113)

	local hitText = Instance.new("TextLabel")
	hitText.Name = "HitText"
	hitText.Text = textContent
	hitText.Size = UDim2.new(0, 120, 0, 40)
	hitText.BackgroundTransparency = 1
	hitText.FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
	hitText.TextSize = 28
	hitText.TextColor3 = textColor
	hitText.TextStrokeTransparency = 0
	hitText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hitText.ZIndex = 10

	local sliderPos = self.slider.Position
	hitText.Position = UDim2.new(sliderPos.X.Scale, sliderPos.X.Offset - 60, sliderPos.Y.Scale, sliderPos.Y.Offset - 60)
	hitText.Parent = self.frame

	task.spawn(function()
		local moveUp = TweenService:Create(hitText,
			TweenInfo.new(1.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				Position = UDim2.new(sliderPos.X.Scale, sliderPos.X.Offset - 60, sliderPos.Y.Scale, sliderPos.Y.Offset - 120),
				TextTransparency = 1,
				TextStrokeTransparency = 1
			}
		)
		moveUp:Play()

		local scaleEffect = TweenService:Create(hitText,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Size = UDim2.new(0, 140, 0, 50)}
		)
		scaleEffect:Play()

		scaleEffect.Completed:Wait()

		local scaleBack = TweenService:Create(hitText,
			TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{Size = UDim2.new(0, 120, 0, 40)}
		)
		scaleBack:Play()

		moveUp.Completed:Wait()
		hitText:Destroy()
	end)
end

-- Randomize hit zone position
function FishingClient:_resetHitZone(hitSizeRange)
	local hitSizeX
	if hitSizeRange then
		hitSizeX = RandomGen:NextNumber(hitSizeRange.min, hitSizeRange.max)
	else
		hitSizeX = RandomGen:NextNumber(0.2, 0.25)
	end

	local maxCenterX = 1 - hitSizeX / 2
	local minCenterX = hitSizeX / 2
	local hitCenterX = RandomGen:NextNumber(minCenterX, maxCenterX)

	self.hitZone.AnchorPoint = Vector2.new(0.5, 0.5)
	self.hitZone.Size = UDim2.new(hitSizeX, 0, 0.86, 0)
	self.hitZone.Position = UDim2.new(hitCenterX, 0, 0.48, 0)

	if self.strongZone then
		local strongSizeX = hitSizeX * 0.25
		self.strongZone.AnchorPoint = Vector2.new(0.5, 0)
		self.strongZone.Size = UDim2.new(strongSizeX / hitSizeX, 0, 1, 0)
		self.strongZone.Position = UDim2.new(0.5, 0, 0, 0)
	end
end

-- Start slider movement
function FishingClient:_startSlider(speedRange)
	local halfWidth = self.slider.Size.X.Scale / 2
	local halfHeight = self.slider.Size.Y.Scale / 2
	local leftEdge = halfWidth
	local rightEdge = 1 - halfWidth

	self.slider.AnchorPoint = Vector2.new(0.5, 0.5)
	self.slider.Position = UDim2.new(leftEdge, 0, 0.5, 0)

	local tweenTime
	if speedRange then
		tweenTime = RandomGen:NextNumber(speedRange.min, speedRange.max)
	else
		tweenTime = RandomGen:NextNumber(1.2, 1.8)
	end

	local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local goal = { Position = UDim2.new(rightEdge, 0, 0.5, 0) }

	self.sliderTween = TweenService:Create(self.slider, tweenInfo, goal)
	self.sliderTween:Play()
end

-- Check for strength buff
function FishingClient:_hasStrengthBuff()
	return self.player:GetAttribute("StrengthBubbleBuff") == true
end

function FishingClient:_processFishingInput()
	if self.isProcessing then
		return
	end

	local currentTime = tick()
	if self.lastClickTime and (currentTime - self.lastClickTime) < 0.15 then
		return
	end
	self.lastClickTime = currentTime

	self.isProcessing = true

	local sliderLeft = self.slider.AbsolutePosition.X
	local sliderRight = sliderLeft + self.slider.AbsoluteSize.X
	local hitLeft = self.hitZone.AbsolutePosition.X
	local hitRight = hitLeft + self.hitZone.AbsoluteSize.X

	local strongLeft, strongRight = 0, 0
	if self.strongZone then
		strongLeft = self.strongZone.AbsolutePosition.X
		strongRight = strongLeft + self.strongZone.AbsoluteSize.X
	end

	local hitStrongZone = self.strongZone and (sliderRight > strongLeft and sliderLeft < strongRight)
	local hitNormalZone = sliderRight > hitLeft and sliderLeft < hitRight

	local hasStrengthBuff = self:_hasStrengthBuff()
	local strengthMultiplier = hasStrengthBuff and 2 or 1

	if hitStrongZone then
		local progressGain = self.strongZoneProgress * strengthMultiplier
		self.currentProgress = math.min(self.currentProgress + progressGain, self.maxProgress)
		self:_updateProgressBar()

		self:_rotateHitZone()
		self:_showHitText("strong", sliderLeft)

		if self.currentProgress >= self.maxProgress then
			SuccessSound:Play()
			tutorialEvent:Fire("fishing_success")
			self.remote:FireServer("progress_success")
		else
			SuccessBellSound:Play()
			self:_shakeFrame()
			self:_resetHitZone()
		end

	elseif hitNormalZone then
		local progressGain = self.normalZoneProgress * strengthMultiplier
		self.currentProgress = math.min(self.currentProgress + progressGain, self.maxProgress)
		self:_updateProgressBar()

		self:_rotateHitZone()
		self:_showHitText("normal", sliderLeft)

		if self.currentProgress >= self.maxProgress then
			SuccessSound:Play()
			tutorialEvent:Fire("fishing_success")
			self.remote:FireServer("progress_success")
		else
			SuccessBellSound:Play()
			self:_shakeFrame()
			self:_resetHitZone()
		end

	else
		self.currentProgress = math.max(self.currentProgress - 15, 0)
		self:_updateProgressBar()

		failSound:Play()

		if self.currentProgress <= 0 and not self._drainFired then
			self._drainFired = true
			if self._drainConn then self._drainConn:Disconnect(); self._drainConn = nil end
			tutorialEvent:Fire("fishing_failed")
			self.remote:FireServer("fail")
		else
			self:_resetHitZone()
		end
	end

	task.spawn(function()
		task.wait(0.05)
		self.isProcessing = false
	end)
end

function FishingClient:_preloadAnimations()
	task.spawn(function()
		local animationsFolder = ReplicatedStorage:WaitForChild("Animations", 30)
		if not animationsFolder then
			warn("Animations folder not found")
			return
		end

		local fishingAnim = animationsFolder:WaitForChild("Fishing", 10)
		if fishingAnim and fishingAnim:IsA("Animation") then
			self.preloadedFishingAnimation = fishingAnim
		end

		local waitingAnim = animationsFolder:WaitForChild("Waiting", 10)
		if waitingAnim and waitingAnim:IsA("Animation") then
			self.preloadedWaitingAnimation = waitingAnim
		end

		local finishAnim = animationsFolder:WaitForChild("Finish", 10)
		if finishAnim and finishAnim:IsA("Animation") then
			self.preloadedFinishAnimation = finishAnim
		end

		local holdingAnim = animationsFolder:WaitForChild("Holding", 10)
		if holdingAnim and holdingAnim:IsA("Animation") then
			self.preloadedHoldingAnimation = holdingAnim
		end

		local fishBaitEatAnim = animationsFolder:WaitForChild("FishBaitEat", 10)
		if fishBaitEatAnim and fishBaitEatAnim:IsA("Animation") then
			self.preloadedFishBaitEatAnimation = fishBaitEatAnim
		end

		local reelingAnim = animationsFolder:WaitForChild("Reeling", 10)
		if reelingAnim and reelingAnim:IsA("Animation") then
			self.preloadedReelingAnimation = reelingAnim
		end

		local holdBigFishAnim = animationsFolder:WaitForChild("HoldBigFish", 10)
		if holdBigFishAnim and holdBigFishAnim:IsA("Animation") then
			self.preloadedHoldBigFishAnimation = holdBigFishAnim
		end
	end)
end

function FishingClient:_playHoldingAnimation(holdingFish)
	local character = self.player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChild("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if self.holdingAnimationTrack then
		self.holdingAnimationTrack:Stop()
		if self.holdingAnimationTrack.Destroy then
			self.holdingAnimationTrack:Destroy()
		end
		self.holdingAnimationTrack = nil
	end

	local BIG_FISH_THRESHOLD = 40.0
	local isBig = holdingFish and (self.lastFishWeight or 0) >= BIG_FISH_THRESHOLD
	local animToPlay = isBig and self.preloadedHoldBigFishAnimation or self.preloadedHoldingAnimation

	if animToPlay then
		local success, result = pcall(function()
			return animator:LoadAnimation(animToPlay)
		end)

		if success then
			self.holdingAnimationTrack = result
			self.holdingAnimationTrack.Priority = Enum.AnimationPriority.Action
			self.holdingAnimationTrack.Looped = true
			self.holdingAnimationTrack:Play()
		else
			warn("Client: Failed to load holding animation:", result)
		end
	end
end

function FishingClient:_stopHoldingAnimation()
	if self.holdingAnimationTrack then
		self.holdingAnimationTrack:Stop()
		if self.holdingAnimationTrack.Destroy then
			self.holdingAnimationTrack:Destroy()
		end
		self.holdingAnimationTrack = nil
	end
end

-- Play fishing animation
function FishingClient:_playFishingAnimation()
	local character = self.player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChild("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Stop all existing animations including holding
	self:_stopHoldingAnimation()

	-- Also stop FishBaitEat and Reeling animations
	if self.fishBaitEatAnimationTrack then
		self.fishBaitEatAnimationTrack:Stop()
		if self.fishBaitEatAnimationTrack.Destroy then
			self.fishBaitEatAnimationTrack:Destroy()
		end
		self.fishBaitEatAnimationTrack = nil
	end
	if self.reelingAnimationTrack then
		self.reelingAnimationTrack:Stop()
		if self.reelingAnimationTrack.Destroy then
			self.reelingAnimationTrack:Destroy()
		end
		self.reelingAnimationTrack = nil
	end

	if self.fishingAnimationTrack then
		self.fishingAnimationTrack:Stop()
		if self.fishingAnimationTrack.Destroy then
			self.fishingAnimationTrack:Destroy()
		end
		self.fishingAnimationTrack = nil
	end

	if self.preloadedFishingAnimation then
		local success, result = pcall(function()
			return animator:LoadAnimation(self.preloadedFishingAnimation)
		end)

		if success then
			self.fishingAnimationTrack = result
			self.fishingAnimationTrack.Priority = Enum.AnimationPriority.Action
			self.fishingAnimationTrack.Looped = false
			self.fishingAnimationTrack:Play()

			self.fishingAnimationTrack.Ended:Connect(function()
				self.fishingAnimationTrack = nil
			end)
		else
			warn("Client: Failed to load fishing animation:", result)
		end
	end
end

-- Play waiting animation
function FishingClient:_playWaitingAnimation()
	local character = self.player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChild("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if self.waitingAnimationTrack then
		self.waitingAnimationTrack:Stop()
		if self.waitingAnimationTrack.Destroy then
			self.waitingAnimationTrack:Destroy()
		end
		self.waitingAnimationTrack = nil
	end

	if self.preloadedWaitingAnimation then
		local success, result = pcall(function()
			return animator:LoadAnimation(self.preloadedWaitingAnimation)
		end)

		if success then
			self.waitingAnimationTrack = result
			self.waitingAnimationTrack.Priority = Enum.AnimationPriority.Action
			self.waitingAnimationTrack.Looped = true
			self.waitingAnimationTrack:Play()
		else
			warn("Client: Failed to load waiting animation:", result)
		end
	end
end

-- Play finish animation, then holding. Self-contained so nothing external can race it.
function FishingClient:_playFinishAnimation()
	-- Fallback: fetch directly if preload missed
	local animObj = self.preloadedFinishAnimation
	if not animObj then
		local folder = ReplicatedStorage:FindFirstChild("Animations")
		animObj = folder and folder:FindFirstChild("Finish")
	end
	if not animObj then
		warn("[FINISH] Finish animation not found")
		task.spawn(function()
			task.wait(0.1)
			if self.tool and self.tool.Parent == self.player.Character then
				self:_playHoldingAnimation(true)
			end
		end)
		return
	end

	local character = self.player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Stop all other tracks immediately
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end
	self.fishingAnimationTrack = nil
	self.waitingAnimationTrack = nil
	self.fishBaitEatAnimationTrack = nil
	self.reelingAnimationTrack = nil
	self.holdingAnimationTrack = nil
	self.finishAnimationTrack = nil

	local ok, track = pcall(function()
		return animator:LoadAnimation(animObj)
	end)
	if not ok or not track then
		warn("[FINISH] LoadAnimation failed:", track)
		task.spawn(function()
			task.wait(0.1)
			if self.tool and self.tool.Parent == self.player.Character then
				self:_playHoldingAnimation(true)
			end
		end)
		return
	end

	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = false
	self.finishAnimationTrack = track

	-- Play and wait for end internally — no external race condition
	track:Play()
	task.spawn(function()
		track.Ended:Wait()
		self.finishAnimationTrack = nil
		if self.tool and self.tool.Parent == self.player.Character then
			self:_playHoldingAnimation(true)
		end
	end)
end

-- Play bait eat animation
function FishingClient:_playFishBaitEatAnimation()
	local character = self.player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChild("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Stop holding animation first
	self:_stopHoldingAnimation()

	-- Stop existing bait eat animation
	if self.fishBaitEatAnimationTrack then
		self.fishBaitEatAnimationTrack:Stop()
		if self.fishBaitEatAnimationTrack.Destroy then
			self.fishBaitEatAnimationTrack:Destroy()
		end
		self.fishBaitEatAnimationTrack = nil
	end

	if self.preloadedFishBaitEatAnimation then
		local success, result = pcall(function()
			return animator:LoadAnimation(self.preloadedFishBaitEatAnimation)
		end)

		if success then
			self.fishBaitEatAnimationTrack = result
			self.fishBaitEatAnimationTrack.Priority = Enum.AnimationPriority.Action
			self.fishBaitEatAnimationTrack.Looped = false
			self.fishBaitEatAnimationTrack:Play()
			-- After FishBaitEat finishes, transition to Reeling loop
			self.fishBaitEatAnimationTrack.Ended:Connect(function()
				if self.reelingAnimationTrack then return end
				self:_playReelingAnimation()
			end)
		else
			warn("Client: Failed to load bait eat animation:", result)
		end
	end
end

function FishingClient:_playReelingAnimation()
	local character = self.player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator")
	animator.Parent = humanoid

	if self.reelingAnimationTrack then
		self.reelingAnimationTrack:Stop()
		self.reelingAnimationTrack = nil
	end

	if self.preloadedReelingAnimation then
		local success, result = pcall(function()
			return animator:LoadAnimation(self.preloadedReelingAnimation)
		end)
		if success then
			self.reelingAnimationTrack = result
			self.reelingAnimationTrack.Priority = Enum.AnimationPriority.Action
			self.reelingAnimationTrack.Looped = true
			self.reelingAnimationTrack:Play()
		else
			warn("Client: Failed to load reeling animation:", result)
		end
	end
end

function FishingClient:_startClientBaitTracking() end -- no-op, replaced by BaitLandedEvent

-- Reset tool grip to default
function FishingClient:_resetToolGrip()
	--if self.tool then
	--	self.tool.GripPos = Vector3.new(0, 0, 0)
	--	self.tool.GripRight = Vector3.new(1, 0, 0)
	--	self.tool.GripUp = Vector3.new(0, 1, 0)      -- default (0 degrees)
	--	self.tool.GripForward = Vector3.new(0, 0, -1) -- default
	--end
end

function FishingClient:_stopAllAnimations()
	if self.fishingAnimationTrack then
		self.fishingAnimationTrack:Stop()
		if self.fishingAnimationTrack.Destroy then
			self.fishingAnimationTrack:Destroy()
		end
		self.fishingAnimationTrack = nil
	end

	if self.waitingAnimationTrack then
		self.waitingAnimationTrack:Stop()
		if self.waitingAnimationTrack.Destroy then
			self.waitingAnimationTrack:Destroy()
		end
		self.waitingAnimationTrack = nil
	end

	-- Never stop finish animation if it's currently playing
	if self.finishAnimationTrack and not self.finishAnimationTrack.IsPlaying then
		self.finishAnimationTrack:Stop()
		if self.finishAnimationTrack.Destroy then
			self.finishAnimationTrack:Destroy()
		end
		self.finishAnimationTrack = nil
	end

	if self.holdingAnimationTrack then
		self.holdingAnimationTrack:Stop()
		if self.holdingAnimationTrack.Destroy then
			self.holdingAnimationTrack:Destroy()
		end
		self.holdingAnimationTrack = nil
	end

	if self.fishBaitEatAnimationTrack then
		self.fishBaitEatAnimationTrack:Stop()
		if self.fishBaitEatAnimationTrack.Destroy then
			self.fishBaitEatAnimationTrack:Destroy()
		end
		self.fishBaitEatAnimationTrack = nil
	end
	if self.reelingAnimationTrack then
		self.reelingAnimationTrack:Stop()
		if self.reelingAnimationTrack.Destroy then
			self.reelingAnimationTrack:Destroy()
		end
		self.reelingAnimationTrack = nil
	end

	self:_resetToolGrip()

end

-- Immediate input handler
function FishingClient:_handleUserInput(inputObject, gameProcessed)
	if gameProcessed then return end

	if not self.newGUI then return end

	if inputObject.UserInputType == Enum.UserInputType.Touch or
		inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
		self:_processFishingInput()
		return
	end
end

function FishingClient:_bind()
	self.tool.Activated:Connect(function()
		if self.gameEndCooldown and tick() < self.gameEndCooldown then
			return
		end

		if self.newGUI then return end
		if tick() < self.inputCooldown then return end
		self.inputCooldown = tick() + 0.2

		local backpack = self.player:FindFirstChild("Backpack")
		if backpack then
			local fishCount = 0
			for _, item in ipairs(backpack:GetChildren()) do
				if item:IsA("Tool") and item:FindFirstChild("FishValue") then
					fishCount += 1
				end
			end

			local hasExpansion = self:_hasInventoryExpansionGamepass()
			local limit = hasExpansion and 200 or 100

			if fishCount >= limit then
				local noticeEvent = ReplicatedStorage:WaitForChild("NoticeEventForClient")
				local message = hasExpansion and
					"Expanded inventory full! Go sell fish (Max 200)" or
					"Inventory full! Go sell fish or buy expansion pass (Max 100)"
				noticeEvent:Fire(message)
				return
			end
		end

		if self.baitThrown and not self.newGUI then
			local currentTime = tick()
			local timeSinceThrow = currentTime - self.baitThrowTime

			if timeSinceThrow >= self.cancelDelay then
				self.remote:FireServer("cancel")
				self:_closeGui()
				self.baitThrown = false
				self.baitThrowTime = 0
				return
			else
				return
			end
		end

		if self.locked then return end

		local character = self.player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				local lookDirection = humanoidRootPart.CFrame.LookVector
				local currentPosition = humanoidRootPart.Position
				local castDistance = 50
				local targetPosition = currentPosition + (lookDirection * castDistance)
				targetPosition = Vector3.new(targetPosition.X, currentPosition.Y, targetPosition.Z)

				-- Raft style: play animation immediately on client, then fire server after delay
				self.locked = true
				self.baitThrown = true
				self.baitThrowTime = tick()
				self:_stopHoldingAnimation()
				self:_playFishingAnimation()
				tutorialEvent:Fire("baitThrow_success")

				task.delay(0.3, function()
					if self.baitThrown and not self.newGUI then
						self.castEvent:FireServer(targetPosition)
						self:_startClientBaitTracking()
					end
				end)
			end
		end
	end)

	-- Remote event handling
	self.remote.OnClientEvent:Connect(function(data)
		if data == "fail" then
			self:_closeGui()
			self.baitThrown = false
			task.spawn(function()
				task.wait(0.1)
				if self.tool and self.tool.Parent == self.player.Character then
					self:_playHoldingAnimation()
				end
			end)
			return
		end

		if data == "success" then
			-- Stop drain, close GUI elements, stop non-finish animations
			if self._drainConn then self._drainConn:Disconnect(); self._drainConn = nil end
			if self.inputBeganConnection then self.inputBeganConnection:Disconnect(); self.inputBeganConnection = nil end
			if self.sliderTween then self.sliderTween:Cancel(); self.sliderTween = nil end
			if self.progressTween then self.progressTween:Cancel(); self.progressTween = nil end
			if self.newGUI then self.newGUI:Destroy(); self.newGUI = nil end
			self.frame = nil; self.strongZone = nil; self.progressBar = nil; self.progressFill = nil
			self.originalFramePosition = nil; self.isProcessing = false; self.currentProgress = 0
			self.locked = false; self.baitThrown = false; self.baitThrowTime = 0
			self.gameEndCooldown = tick() + 1.5
			for _, gui in ipairs(self.player:WaitForChild("PlayerGui"):GetChildren()) do
				if gui.Name == "FishingGui" then gui:Destroy() end
			end

			-- Stop all except finish
			if self.fishingAnimationTrack then self.fishingAnimationTrack:Stop(); self.fishingAnimationTrack = nil end
			if self.waitingAnimationTrack then self.waitingAnimationTrack:Stop(); self.waitingAnimationTrack = nil end
			if self.fishBaitEatAnimationTrack then self.fishBaitEatAnimationTrack:Stop(); self.fishBaitEatAnimationTrack = nil end
			if self.reelingAnimationTrack then self.reelingAnimationTrack:Stop(); self.reelingAnimationTrack = nil end
			if self.holdingAnimationTrack then self.holdingAnimationTrack:Stop(); self.holdingAnimationTrack = nil end

			-- _playFinishAnimation plays finish then transitions to holding internally
			self:_playFinishAnimation()

			return
		end

		if data == "play_fishing_animation" then
			-- Already played client-side on cast; skip to avoid double-play
			return
		end

		if data == "play_waiting_animation" then
			self:_playWaitingAnimation()
			return
		end

		if data == "keep_waiting_animation" then
			-- Play FishBaitEat animation when fish bites the bait
			self:_playFishBaitEatAnimation()
			return
		end

		if data == "stop_all_animations" then
			-- Don't kill finish animation if it's currently playing
			if not (self.finishAnimationTrack and self.finishAnimationTrack.IsPlaying) then
				self:_stopAllAnimations()
			end
			return
		end


		if not data or typeof(data) ~= "table" or not data.rarity then
			self:_closeGui()
			self.baitThrown = false
			return
		end

		self.lastFishWeight = data.fishWeight or 0
		self:_openGui(data.rarity, data.toolName, data.difficultyMod)
	end)

	self.tool.Equipped:Connect(function()
		-- Only start holding animation if no other animation is playing
		if (not self.fishBaitEatAnimationTrack or not self.fishBaitEatAnimationTrack.IsPlaying) and
			(not self.finishAnimationTrack or not self.finishAnimationTrack.IsPlaying) then
			self:_playHoldingAnimation()
		end
	end)

	self.tool.Unequipped:Connect(function()
		self:_stopHoldingAnimation()
		-- Don't kill finish animation if it's currently playing
		if not (self.finishAnimationTrack and self.finishAnimationTrack.IsPlaying) then
			self:_stopAllAnimations()
		end
		self:_closeGui()
		self.baitThrown = false
	end)
end

function FishingClient:_openGui(rarity, serverToolName, serverDifficultyMod)
	-- Check if FishBaitEat animation is playing
	local wasFishBaitEatPlaying = self.fishBaitEatAnimationTrack and self.fishBaitEatAnimationTrack.IsPlaying

	self:_closeGui() -- Remove existing GUI

	local Config = require(ReplicatedStorage.Modules:WaitForChild("FishingConfigModule"))
	local FishDifficulty = require(ReplicatedStorage.Modules:WaitForChild("FishDifficultyModule"))

	local toolName = serverToolName or self.tool.Name
	local toolConfig = Config[toolName]

	if toolConfig and toolConfig.RodPower then
		self.rodPower = toolConfig.RodPower
	else
		self.rodPower = 1.0
	end

	local difficulty = FishDifficulty.GetModifiedSetting(rarity, self.rodPower)

	self.maxProgress = difficulty.targetProgress
	self.strongZoneProgress = FishDifficulty.GetProgressGain("strong", difficulty)
	self.normalZoneProgress = FishDifficulty.GetProgressGain("normal", difficulty)

	self.newGUI = GUI:Clone()
	self.newGUI.Parent = self.player:WaitForChild("PlayerGui")
	self.newGUI.Enabled = true
	self.newGUI:SetAttribute("FishRarity", rarity)

	self.frame = self.newGUI:WaitForChild("GaugeFrame")
	self.slider = self.frame:WaitForChild("InFrame"):WaitForChild("Slider")
	self.hitZone = self.frame:WaitForChild("InFrame"):WaitForChild("HitZone")
	self.strongZone = self.hitZone:WaitForChild("StrongZone")

	self.progressBar = self.newGUI:WaitForChild("ProgressBar")
	self.progressFill = self.progressBar:WaitForChild("Fill")

	self.originalFramePosition = self.frame.Position

	-- Start at 30% progress
	self.currentProgress = self.maxProgress * 0.3
	self:_updateProgressBar()

	for _, child in pairs(self.frame:GetChildren()) do
		if child:IsA("TextLabel") and child.Text:find("클릭하여") then
			child.Text = string.format("Target %d%% | Strong(+%d%%) Normal(+%d%%) Miss(-15%%)",
				self.maxProgress, self.strongZoneProgress, self.normalZoneProgress)
			break
		end
	end

	self:_resetHitZone(difficulty.hitSize)
	self:_startSlider(difficulty.speed)

	tutorialEvent:Fire("minigame_started")

	-- Passive drain: progress slowly decreases over time
	self._drainFired = false
	self._drainConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
		if not self._drainConn then return end
		self.currentProgress = math.max(self.currentProgress - dt * 4, 0)
		self:_updateProgressBar()
		if self.currentProgress <= 0 and not self._drainFired then
			self._drainFired = true
			self._drainConn:Disconnect()
			self._drainConn = nil
			tutorialEvent:Fire("fishing_failed")
			self.remote:FireServer("fail")
		end
	end)

	-- Keep FishBaitEat animation if it was playing
	if wasFishBaitEatPlaying then
		self:_playFishBaitEatAnimation()
	end

	self.inputBeganConnection = UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		self:_handleUserInput(inputObject, gameProcessed)
	end)
end

function FishingClient:_closeGui()
	self.gameEndCooldown = tick() + 1.5

	if self._drainConn then
		self._drainConn:Disconnect()
		self._drainConn = nil
	end

	if self._baitTrackConn then
		self._baitTrackConn:Disconnect()
		self._baitTrackConn = nil
	end

	if self.inputBeganConnection then
		self.inputBeganConnection:Disconnect()
		self.inputBeganConnection = nil
	end

	if self.inputEndedConnection then
		self.inputEndedConnection:Disconnect()
		self.inputEndedConnection = nil
	end

	if self.sliderTween then
		self.sliderTween:Cancel()
		self.sliderTween = nil
	end

	if self.progressTween then
		self.progressTween:Cancel()
		self.progressTween = nil
	end

	if self.newGUI then
		self.newGUI:Destroy()
		self.newGUI = nil
	end

	self.frame = nil
	self.strongZone = nil
	self.progressBar = nil
	self.progressFill = nil
	self.originalFramePosition = nil
	self.isProcessing = false

	self.currentProgress = 0

	for _, gui in ipairs(self.player:WaitForChild("PlayerGui"):GetChildren()) do
		if gui.Name == "FishingGui" then
			gui:Destroy()
		end
	end

	self.locked = false
	self.baitThrown = false
	self.baitThrowTime = 0

	-- Stop all in-progress fishing animations; caller is responsible for what plays next
	if self.fishingAnimationTrack then self.fishingAnimationTrack:Stop(); self.fishingAnimationTrack = nil end
	if self.waitingAnimationTrack then self.waitingAnimationTrack:Stop(); self.waitingAnimationTrack = nil end
	if self.fishBaitEatAnimationTrack then self.fishBaitEatAnimationTrack:Stop(); self.fishBaitEatAnimationTrack = nil end
	if self.reelingAnimationTrack then self.reelingAnimationTrack:Stop(); self.reelingAnimationTrack = nil end
	if self.holdingAnimationTrack then self.holdingAnimationTrack:Stop(); self.holdingAnimationTrack = nil end
end

local function playBaitSplashEffect(pos)
	local splashSound = ReplicatedStorage:FindFirstChild("Sounds") and ReplicatedStorage.Sounds:FindFirstChild("Water Splash Sound")
	local baitDiveTemplate = ReplicatedStorage:FindFirstChild("Particle") and ReplicatedStorage.Particle:FindFirstChild("Bait Dive")
	if splashSound then
		local sc = splashSound:Clone()
		sc.RollOffMode = Enum.RollOffMode.Linear
		sc.MaxDistance = 60
		sc.Volume = 0.8
		sc.Parent = workspace.CurrentCamera
		sc:Play()
		game:GetService("Debris"):AddItem(sc, 3)
	end
	if baitDiveTemplate then
		local effect = baitDiveTemplate:Clone()
		effect.CFrame = CFrame.new(pos)
		effect.Anchored = true
		effect.CanCollide = false
		effect.Parent = workspace
		local att = effect:FindFirstChildOfClass("Attachment")
		if att then
			for _, p in ipairs(att:GetChildren()) do
				if p:IsA("ParticleEmitter") then
					p:Emit(p.Rate > 0 and math.ceil(p.Rate * 0.15) or 8)
				end
			end
		end
		game:GetService("Debris"):AddItem(effect, 3)
	end
end

-- BaitLandedEvent: fires only to the fishing player — freeze bait + effects with zero lag
task.spawn(function()
	local baitLandedEvent = ReplicatedStorage:WaitForChild("BaitLandedEvent", 30)
	if not baitLandedEvent then return end
	baitLandedEvent.OnClientEvent:Connect(function(restPos, baitInstance)
		-- Use the exact Part passed from server; fallback to workspace search
		local baitPart = baitInstance
		if not baitPart then
			local found = workspace:FindFirstChild("Bait")
			if found then
				baitPart = found:IsA("BasePart") and found or (found.PrimaryPart or found:FindFirstChildOfClass("BasePart"))
			end
		end
		if baitPart and baitPart:IsA("BasePart") and not baitPart.Anchored then
			baitPart.AssemblyLinearVelocity = Vector3.zero
			baitPart.AssemblyAngularVelocity = Vector3.zero
			baitPart.CFrame = CFrame.new(restPos)
			baitPart.Anchored = true
		end
		playBaitSplashEffect(restPos)
	end)
end)

-- BaitSplashEvent: fires to spectators (everyone except the fishing player)
task.spawn(function()
	local baitSplashEvent = ReplicatedStorage:WaitForChild("BaitSplashEvent", 30)
	if not baitSplashEvent then return end
	baitSplashEvent.OnClientEvent:Connect(function(pos)
		playBaitSplashEffect(pos)
	end)
end)

return FishingClient
