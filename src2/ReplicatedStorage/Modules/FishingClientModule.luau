local FishingClient = {}
FishingClient.__index = FishingClient

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local FishDifficulty = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDifficultyModule"))
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishingConfigModule"))
local failSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Fail")
local SuccessSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Success sound")
local SuccessBellSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("success bell")
local GUI = ReplicatedStorage:WaitForChild("FishingGui")
local RandomGen = Random.new()

-- Tutorial event
local tutorialEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("TutorialEvent")

-- Per-tool instance map
local instanceMap = {}

function FishingClient.init(tool)
	if instanceMap[tool] then
		warn("FishingClient already initialized for this tool.")
		return instanceMap[tool]
	end

	local self = setmetatable({}, FishingClient)
	instanceMap[tool] = self
	tool.AncestryChanged:Connect(function()
		if not tool:IsDescendantOf(game) then
			instanceMap[tool] = nil
		end
	end)

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
	self.preloadedFishFailAnimation = nil
	self.fishFailAnimationTrack = nil
	self.lastFishWeight = 0

	-- Preload animations
	self:_preloadAnimations()

	self.isProcessing = false
	self.inputCooldown = 0
	self.player = game.Players.LocalPlayer
	self.remote = tool:WaitForChild("RemoteEvent", 5)
	self.castEvent = tool:WaitForChild("CastRod", 5)
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

	-- Camera shake state
	self.cameraShakeConn = nil
	self.cameraShakeOffset = CFrame.identity
	self.cameraShakeIntensity = 0

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
			if self:_isInventoryFull() then return end
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

-- Returns true if inventory is full (and fires notice), false if OK to cast
function FishingClient:_isInventoryFull()
	local backpack = self.player:FindFirstChild("Backpack")
	if not backpack then return false end
	local fishCount = 0
	for _, item in ipairs(backpack:GetChildren()) do
		if item:IsA("Tool") and item:FindFirstChild("FishValue") then
			fishCount += 1
		end
	end
	local hasExpansion = self:_hasInventoryExpansionGamepass()
	local limit = hasExpansion and 200 or 100
	if fishCount >= limit then
		local noticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("NoticeEventForClient")
		local message = hasExpansion and
			"Expanded inventory full! Go sell fish (Max 200)" or
			"Inventory full! Go sell fish or buy expansion pass (Max 100)"
		noticeEvent:Fire(message)
		return true
	end
	return false
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

	local rodName = self.tool and self.tool.Name
	if rodName == "FishingRod" then
		tweenTime = tweenTime * 1.25
	elseif rodName == "SliverRod" then
		tweenTime = tweenTime * 1.111
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
		self:_triggerHitShake("strong")

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
		self:_triggerHitShake("normal")

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

-- Rarity → base shake intensity
local RARITY_BASE_INTENSITY = {
	Common    = 0.01,
	Uncommon  = 0.04,
	Rare      = 0.08,
	Epic      = 0.13,
	Legendary = 0.19,
	Mystic    = 0.27,
	Fantasy   = 0.36,
	Unknown   = 0.46,
}

function FishingClient:_startCameraShake(rarity, fishWeight)
	self:_stopCameraShake()

	local base = RARITY_BASE_INTENSITY[rarity] or 0.01
	-- Weight adds up to 30% of base on top (e.g. 200kg fish = +base*0.3)
	local weightBonus = math.clamp((fishWeight or 0) / 200, 0, 1) * base * 0.3
	local intensity = base + weightBonus
	self.cameraShakeIntensity = intensity

	local camera = Workspace.CurrentCamera
	if not camera then return end

	local t = 0
	-- hitImpulse: extra one-shot shake added when player hits the zone
	self.hitImpulse = 0
	self.cameraShakeConn = RunService.RenderStepped:Connect(function(dt)
		if not camera or not camera.Parent then return end
		t = t + dt * 18

		-- Decay hit impulse each frame
		if self.hitImpulse > 0 then
			self.hitImpulse = math.max(0, self.hitImpulse - dt * 8)
		end

		local total = intensity + self.hitImpulse
		local ix = math.sin(t * 1.3) * total
		local iy = math.sin(t * 1.7 + 1) * total * 0.6
		local iz = math.sin(t * 2.1 + 2) * total * 0.4
		self.cameraShakeOffset = CFrame.new(ix, iy, 0) * CFrame.Angles(math.rad(iz), math.rad(ix * 0.5), 0)
		camera.CFrame = camera.CFrame * self.cameraShakeOffset
	end)
end

-- One-shot hit impulse proportional to current shake intensity
function FishingClient:_triggerHitShake(hitType)
	if not self.cameraShakeConn then return end
	-- strong hit: 2× intensity spike, normal hit: 1.2×
	local multiplier = hitType == "strong" and 2.0 or 1.2
	self.hitImpulse = (self.hitImpulse or 0) + self.cameraShakeIntensity * multiplier
end

function FishingClient:_stopCameraShake()
	if self.cameraShakeConn then
		self.cameraShakeConn:Disconnect()
		self.cameraShakeConn = nil
	end
	self.cameraShakeOffset = CFrame.identity
	self.cameraShakeIntensity = 0
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

		local fishFailAnim = animationsFolder:WaitForChild("FishFail", 10)
		if fishFailAnim and fishFailAnim:IsA("Animation") then
			self.preloadedFishFailAnimation = fishFailAnim
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

	local BIG_FISH_THRESHOLD = 30.0
	local isBig = false
	if holdingFish then
		local backpack = self.player:FindFirstChild("Backpack")
		if backpack then
			for _, item in ipairs(backpack:GetChildren()) do
				local fw = item:FindFirstChild("FishWeight")
				if fw and fw.Value >= BIG_FISH_THRESHOLD then
					isBig = true
					break
				end
			end
		end
	end

	if isBig and not self.preloadedHoldBigFishAnimation then
		local folder = ReplicatedStorage:FindFirstChild("Animations")
		local anim = folder and folder:FindFirstChild("HoldBigFish")
		if anim and anim:IsA("Animation") then
			self.preloadedHoldBigFishAnimation = anim
		end
	end

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
		local folder = ReplicatedStorage:WaitForChild("Animations", 5)
		animObj = folder and (folder:FindFirstChild("Finish") or folder:WaitForChild("Finish", 3))
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

	track:Play()

	-- Wait for finish animation to end; use a timeout as safety in case Ended fires late
	task.spawn(function()
		local finished = false
		local conn
		conn = track.Ended:Connect(function()
			finished = true
			conn:Disconnect()
		end)

		-- Poll with timeout matching the animation length (max 5s)
		local deadline = tick() + 5
		while not finished and tick() < deadline and track.IsPlaying do
			task.wait(0.05)
		end
		conn:Disconnect()

		self.finishAnimationTrack = nil
		if self.tool and self.tool.Parent == self.player.Character then
			self:_playHoldingAnimation(false)
		end
	end)
end

-- Play fail animation then transition to holding
function FishingClient:_playFishFailAnimation()
	local animObj = self.preloadedFishFailAnimation
	if not animObj then
		local folder = ReplicatedStorage:FindFirstChild("Animations")
		animObj = folder and folder:FindFirstChild("FishFail")
	end
	if not animObj then return end

	local character = self.player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- 기존 트랙 정지
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end
	self.fishingAnimationTrack = nil
	self.waitingAnimationTrack = nil
	self.fishBaitEatAnimationTrack = nil
	self.reelingAnimationTrack = nil
	self.holdingAnimationTrack = nil
	self.fishFailAnimationTrack = nil

	local ok, track = pcall(function()
		return animator:LoadAnimation(animObj)
	end)
	if not ok or not track then return end

	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = false
	self.fishFailAnimationTrack = track
	track:Play()

	task.spawn(function()
		local done = false
		local conn
		conn = track.Ended:Connect(function()
			done = true
			conn:Disconnect()
		end)
		local deadline = tick() + 5
		while not done and tick() < deadline and track.IsPlaying do
			task.wait(0.05)
		end
		conn:Disconnect()
		self.fishFailAnimationTrack = nil
		if self.tool and self.tool.Parent == self.player.Character then
			self:_playHoldingAnimation()
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
			-- After FishBaitEat finishes naturally, transition to Reeling loop.
			-- If fishBaitEatAnimationTrack is nil here it was stopped externally (e.g. success/fail),
			-- so don't start Reeling.
			local capturedTrack = self.fishBaitEatAnimationTrack
			capturedTrack.Ended:Connect(function()
				if self.fishBaitEatAnimationTrack ~= capturedTrack then return end
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

	if self.fishFailAnimationTrack then
		self.fishFailAnimationTrack:Stop()
		self.fishFailAnimationTrack = nil
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
	-- 모바일 터치는 카메라 조작과 겹쳐 gameProcessed=true가 되므로
	-- 미니게임 중 Touch 입력은 gameProcessed 무시
	local isTouch = inputObject.UserInputType == Enum.UserInputType.Touch
	if gameProcessed and not (isTouch and self.newGUI) then return end
	if self.player.PlayerGui:GetAttribute("ActiveLargeUI") then return end

	if not self.newGUI then return end

	if isTouch or inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
		self:_processFishingInput()
		return
	end
end

function FishingClient:_bind()
	self.tool.Activated:Connect(function()
		if self.player:GetAttribute("AutoFishing") == true then return end
		if self.gameEndCooldown and tick() < self.gameEndCooldown then
			return
		end

		if self.newGUI then return end
		if tick() < self.inputCooldown then return end
		self.inputCooldown = tick() + 0.2

		if self:_isInventoryFull() then return end

		if self.baitThrown and not self.newGUI then
			local currentTime = tick()
			local timeSinceThrow = currentTime - self.baitThrowTime

			if timeSinceThrow >= self.cancelDelay then
				if self.remote then self.remote:FireServer("cancel") end
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
		if data == "inventory_full" then
			self:_closeGui()
			self.baitThrown = false
			task.spawn(function()
				task.wait(0.5)
				if self.tool and self.tool.Parent == self.player.Character then
					self:_playHoldingAnimation(false)
				end
			end)
			return
		end

		if data == "fail" then
			self:_closeGui()
			self.baitThrown = false
			task.spawn(function()
				task.wait(0.1)
				if self.tool and self.tool.Parent == self.player.Character then
					self:_playFishFailAnimation()
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

			self:_stopCameraShake()

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
			if self.waitingAnimationTrack then self.waitingAnimationTrack:Stop(); self.waitingAnimationTrack = nil end
			if self.fishingAnimationTrack then self.fishingAnimationTrack:Stop(); self.fishingAnimationTrack = nil end
			self:_stopHoldingAnimation()
			self:_playReelingAnimation()
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
			self.locked = false
			self.baitThrown = false
			return
		end

		self.lastFishWeight = data.fishWeight or 0
		self:_openGui(data.rarity, data.toolName, data.difficultyMod)
	end)

	self.tool.Equipped:Connect(function()
		-- Wait until holding animation is preloaded before playing
		task.spawn(function()
			local deadline = tick() + 5
			while not self.preloadedHoldingAnimation and tick() < deadline do
				task.wait(0.05)
			end
			if (not self.fishBaitEatAnimationTrack or not self.fishBaitEatAnimationTrack.IsPlaying) and
				(not self.finishAnimationTrack or not self.finishAnimationTrack.IsPlaying) and
				self.tool.Parent == self.player.Character then
				self:_playHoldingAnimation(false)
			end
		end)
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
	local wasReelingPlaying = self.reelingAnimationTrack and self.reelingAnimationTrack.IsPlaying

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

	-- Apply PowerUp skill bonus
	local skillsFolder = self.player:FindFirstChild("Skills")
	local powerUpVal = skillsFolder and skillsFolder:FindFirstChild("PowerUp")
	local powerUpLevel = powerUpVal and powerUpVal.Value or 0
	local POWER_UP_EFFECTS = { 0.05, 0.10, 0.20 }
	local powerBonus = (powerUpLevel > 0 and POWER_UP_EFFECTS[powerUpLevel]) or 0
	self.rodPower = self.rodPower * (1 + powerBonus)

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

	local hitSizeBonus = toolConfig and toolConfig.HitZoneBonus or 1
	local bonusHitSize = {
		min = math.min(0.35, difficulty.hitSize.min * hitSizeBonus),
		max = math.min(0.40, difficulty.hitSize.max * hitSizeBonus),
	}
	self:_resetHitZone(bonusHitSize)
	self:_startSlider(difficulty.speed)
	self:_startCameraShake(rarity, self.lastFishWeight)

	tutorialEvent:Fire("minigame_started")

	-- Passive drain: progress slowly decreases over time (faster for rarer fish)
	local drainRate = difficulty.drainRate or 4
	self._drainFired = false
	self._drainConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
		if not self._drainConn then return end
		if self.player.PlayerGui:GetAttribute("ActiveLargeUI") then return end
		self.currentProgress = math.max(self.currentProgress - dt * drainRate, 0)
		self:_updateProgressBar()
		if self.currentProgress <= 0 and not self._drainFired then
			self._drainFired = true
			self._drainConn:Disconnect()
			self._drainConn = nil
			tutorialEvent:Fire("fishing_failed")
			self.remote:FireServer("fail")
		end
	end)

	if wasReelingPlaying then
		self:_playReelingAnimation()
	end

	self.inputBeganConnection = UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		self:_handleUserInput(inputObject, gameProcessed)
	end)

	-- When a large UI (e.g. skill tree) closes, re-show the minigame GUI if it was hidden behind it
	self._largeUIConn = self.player.PlayerGui:GetAttributeChangedSignal("ActiveLargeUI"):Connect(function()
		if not self.player.PlayerGui:GetAttribute("ActiveLargeUI") and self.newGUI then
			self.newGUI.Enabled = true
		end
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

	if self._largeUIConn then
		self._largeUIConn:Disconnect()
		self._largeUIConn = nil
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

	self:_stopCameraShake()

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

-- BaitLandedEvent: fires only to the fishing player — play splash effect only.
-- Server already anchored + snapped the bait; touching CFrame client-side causes jitter.
task.spawn(function()
	local baitLandedEvent = ReplicatedStorage:WaitForChild("BaitLandedEvent", 30)
	if not baitLandedEvent then return end
	baitLandedEvent.OnClientEvent:Connect(function(restPos, baitInstance)
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
