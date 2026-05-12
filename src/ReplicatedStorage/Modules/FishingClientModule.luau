local FishingClient = {}
FishingClient.__index = FishingClient

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FishDifficulty = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDifficultyModule"))
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishingConfigModule"))
local failSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Fail")
local SuccessSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Success sound")
local SuccessBellSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("success bell")
local GUI = ReplicatedStorage:WaitForChild("FishingGui")
local RandomGen = Random.new()

-- 튜토리얼 이벤트 추가
local tutorialEvent = ReplicatedStorage:WaitForChild("TutorialEvent")

-- 툴 별 인스턴스 저장
local instanceMap = {}

function FishingClient.init(tool)
	if instanceMap[tool] then
		warn("FishingClient already initialized for this tool.")
		return instanceMap[tool]
	end

	print("FishingClient Init")
	local self = setmetatable({}, FishingClient)
	instanceMap[tool] = self

	self.tool = tool

	self.fishingAnimationTrack = nil
	self.waitingAnimationTrack = nil
	self.finishAnimationTrack = nil
	self.holdingAnimationTrack = nil
	self.fishBaitEatAnimationTrack = nil -- 새로운 미끼 먹는 애니메이션

	self.preloadedFishingAnimation = nil
	self.preloadedWaitingAnimation = nil
	self.preloadedFinishAnimation = nil
	self.preloadedHoldingAnimation = nil
	self.preloadedFishBaitEatAnimation = nil -- 새로운 미끼 먹는 애니메이션

	-- 애니메이션 프리로드
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

	-- 흔들림 효과를 위한 변수들 추가
	self.frame = nil
	self.originalFramePosition = nil

	-- 프로그레스 바 게임 변수들
	self.currentProgress = 0
	self.maxProgress = 100
	self.strongZoneProgress = 20
	self.normalZoneProgress = 10
	self.rodPower = 1.0
	self.progressBar = nil
	self.progressFill = nil
	self.progressTween = nil

	-- 미니게임 종료 후 보호 시간
	self.gameEndCooldown = 0

	-- UserInputService 연결 변수들
	self.inputBeganConnection = nil
	self.inputEndedConnection = nil

	self:_bind()
	return self
end

local MarketplaceService = game:GetService("MarketplaceService")
local INVENTORY_EXPANSION_GAMEPASS_ID = 1294285302

-- 클라이언트에서 게임패스 확인 함수 추가
function FishingClient:_hasInventoryExpansionGamepass()
	local success, hasGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(self.player.UserId, INVENTORY_EXPANSION_GAMEPASS_ID)
	end)

	if success then
		return hasGamepass
	else
		warn("클라이언트: 인벤토리 확장 게임패스 확인 실패")
		return false
	end
end

-- 빠른 위치+회전 복합 흔들림 효과 함수
function FishingClient:_shakeFrame()
	if not self.frame or not self.originalFramePosition then return end

	local shakeIntensity = 6
	local maxRotation = 3
	local shakeDuration = 0.12
	local shakeCount = 20

	spawn(function()
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

-- 프로그레스 바 업데이트
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

-- 히트존 회전 효과 함수
function FishingClient:_rotateHitZone()
	if not self.hitZone then return end

	local originalRotation = self.hitZone.Rotation

	spawn(function()
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

-- 판정 텍스트 효과 함수
function FishingClient:_showHitText(hitType, hitPosition)
	if not self.frame then return end

	local textContent = hitType == "strong" and "Perfect!" or "Good"
	local textColor = hitType == "strong" and Color3.fromRGB(255, 12, 16) or Color3.fromRGB(46, 204, 113)

	local hitText = Instance.new("TextLabel")
	hitText.Name = "HitText"
	hitText.Text = textContent
	hitText.Size = UDim2.new(0, 120, 0, 40)
	hitText.BackgroundTransparency = 1
	hitText.Font = Enum.Font.SourceSansBold
	hitText.TextSize = 28
	hitText.TextColor3 = textColor
	hitText.TextStrokeTransparency = 0
	hitText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hitText.ZIndex = 10

	local sliderPos = self.slider.Position
	hitText.Position = UDim2.new(sliderPos.X.Scale, sliderPos.X.Offset - 60, sliderPos.Y.Scale, sliderPos.Y.Offset - 60)
	hitText.Parent = self.frame

	spawn(function()
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

-- 히트존 랜덤 위치 설정
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

-- 슬라이더 이동 시작
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

-- 힘 버프 확인 함수
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

		if self.currentProgress <= 0 then
			tutorialEvent:Fire("fishing_failed")
			self.remote:FireServer("check_retry")
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
	local animationsFolder = ReplicatedStorage:FindFirstChild("Animations")
	if not animationsFolder then
		warn("❌ Animations 폴더를 찾을 수 없습니다")
		return
	end

	-- 낚시 애니메이션
	local fishingAnim = animationsFolder:FindFirstChild("Fishing")
	if fishingAnim and fishingAnim:IsA("Animation") then
		self.preloadedFishingAnimation = fishingAnim
		--print("🎬 클라이언트: Fishing 애니메이션 프리로드 완료")
	end

	-- 대기 애니메이션
	local waitingAnim = animationsFolder:FindFirstChild("Waiting")
	if waitingAnim and waitingAnim:IsA("Animation") then
		self.preloadedWaitingAnimation = waitingAnim
		--print("🎬 클라이언트: Waiting 애니메이션 프리로드 완료")
	end

	-- 완료 애니메이션
	local finishAnim = animationsFolder:FindFirstChild("Finish")
	if finishAnim and finishAnim:IsA("Animation") then
		self.preloadedFinishAnimation = finishAnim
		--print("🎬 클라이언트: Finish 애니메이션 프리로드 완료")
	end

	-- 들고있는 애니메이션 프리로드
	local holdingAnim = animationsFolder:FindFirstChild("Holding")
	if holdingAnim and holdingAnim:IsA("Animation") then
		self.preloadedHoldingAnimation = holdingAnim
		--print("🎬 클라이언트: Holding 애니메이션 프리로드 완료")
	end

	-- 미끼 먹는 애니메이션 프리로드
	local fishBaitEatAnim = animationsFolder:FindFirstChild("FishBaitEat")
	if fishBaitEatAnim and fishBaitEatAnim:IsA("Animation") then
		self.preloadedFishBaitEatAnimation = fishBaitEatAnim
		--print("🎬 클라이언트: FishBaitEat 애니메이션 프리로드 완료")
	end
end

function FishingClient:_playHoldingAnimation()
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

	if self.preloadedHoldingAnimation then
		local success, result = pcall(function()
			return animator:LoadAnimation(self.preloadedHoldingAnimation)
		end)

		if success then
			self.holdingAnimationTrack = result
			self.holdingAnimationTrack.Priority = Enum.AnimationPriority.Action
			self.holdingAnimationTrack.Looped = true
			self.holdingAnimationTrack:Play()
			--print("🎬 클라이언트: 들고있는 애니메이션 루프 시작")
		else
			warn("❌ 클라이언트: 들고있는 애니메이션 로드 실패:", result)
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
		--print("🎬 클라이언트: 들고있는 애니메이션 정지")
	end
end

-- 낚시 애니메이션 재생
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

	-- 🔧 모든 기존 애니메이션 정지 (holding 포함)
	self:_stopHoldingAnimation()

	-- 🔧 FishBaitEat 애니메이션도 정지
	if self.fishBaitEatAnimationTrack then
		self.fishBaitEatAnimationTrack:Stop()
		if self.fishBaitEatAnimationTrack.Destroy then
			self.fishBaitEatAnimationTrack:Destroy()
		end
		self.fishBaitEatAnimationTrack = nil
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
			--print("🎬 클라이언트: 낚시 애니메이션 재생")

			self.fishingAnimationTrack.Ended:Connect(function()
				self.fishingAnimationTrack = nil
				--print("🎬 클라이언트: 낚시 애니메이션 완료")
			end)
		else
			warn("❌ 클라이언트: 낚시 애니메이션 로드 실패:", result)
		end
	end
end

-- 대기 애니메이션 재생
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
			--print("🎬 클라이언트: 대기 애니메이션 루프 시작")
		else
			warn("❌ 클라이언트: 대기 애니메이션 로드 실패:", result)
		end
	end
end

-- 완료 애니메이션 재생
function FishingClient:_playFinishAnimation()
	local character = self.player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChild("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

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

	if self.preloadedFinishAnimation then
		local success, result = pcall(function()
			return animator:LoadAnimation(self.preloadedFinishAnimation)
		end)

		if success then
			self.finishAnimationTrack = result
			self.finishAnimationTrack.Priority = Enum.AnimationPriority.Action
			self.finishAnimationTrack.Looped = false
			self.finishAnimationTrack:Play()
			--print("🎬 클라이언트: 완료 애니메이션 재생")

			self.finishAnimationTrack.Ended:Connect(function()
				self.finishAnimationTrack = nil
				--print("🎬 클라이언트: 완료 애니메이션 완료")
			end)
		else
			warn("❌ 클라이언트: 완료 애니메이션 로드 실패:", result)
		end
	end
end

-- 미끼 먹는 애니메이션 재생
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

	-- holding 애니메이션 먼저 정지
	self:_stopHoldingAnimation()

	-- 기존 미끼 먹는 애니메이션 정지
	if self.fishBaitEatAnimationTrack then
		self.fishBaitEatAnimationTrack:Stop()
		if self.fishBaitEatAnimationTrack.Destroy then
			self.fishBaitEatAnimationTrack:Destroy()
		end
		self.fishBaitEatAnimationTrack = nil
	end

	-- 🔧 도구 그립 방향 변경 (FishBaitEat 애니메이션용)
	--if self.tool then
	--	local angle = math.rad(-15)
	--	local cos15 = math.cos(angle)
	--	local sin15 = math.sin(angle)

	--	self.tool.GripPos = Vector3.new(0, 0, 0)
	--	self.tool.GripRight = Vector3.new(1, 0, 0)
	--	self.tool.GripUp = Vector3.new(0, cos15, sin15)
	--	self.tool.GripForward = Vector3.new(0, -sin15, cos15)
	--	print("🔧 도구 그립 15도 회전 적용:", cos15, sin15)
	--end

	if self.preloadedFishBaitEatAnimation then
		local success, result = pcall(function()
			return animator:LoadAnimation(self.preloadedFishBaitEatAnimation)
		end)

		if success then
			self.fishBaitEatAnimationTrack = result
			self.fishBaitEatAnimationTrack.Priority = Enum.AnimationPriority.Action
			self.fishBaitEatAnimationTrack.Looped = true
			self.fishBaitEatAnimationTrack:Play()
			--print("🎬 클라이언트: 미끼 먹는 애니메이션 루프 시작 (그립 회전 적용)")
		else
			warn("❌ 클라이언트: 미끼 먹는 애니메이션 로드 실패:", result)
		end
	end
end

-- 도구 그립을 기본값으로 복원
function FishingClient:_resetToolGrip()
	--if self.tool then
	--	self.tool.GripPos = Vector3.new(0, 0, 0)
	--	self.tool.GripRight = Vector3.new(1, 0, 0)
	--	self.tool.GripUp = Vector3.new(0, 1, 0)      -- 기본값 (0도)
	--	self.tool.GripForward = Vector3.new(0, 0, -1) -- 기본값
	--	print("🔧 도구 그립 기본값으로 복원")
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

	if self.finishAnimationTrack then
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

	self:_resetToolGrip()

	print("🎬 클라이언트: 모든 애니메이션 정지")
end

-- 즉시 반응하는 입력 처리 함수
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

				self.castEvent:FireServer(targetPosition)
				self.locked = true
				self.baitThrown = true
				self.baitThrowTime = tick()
				tutorialEvent:Fire("baitThrow_success")
			end
		end
	end)

	-- remote 이벤트 처리
	self.remote.OnClientEvent:Connect(function(data)
		if data == "fail" then
			self:_closeGui()
			self.baitThrown = false
			return
		end

		if data == "success" then
			-- 성공 시 finish 애니메이션 재생하고 GUI 바로 닫기
			self:_playFinishAnimation()
			self:_closeGui()

			-- finish 애니메이션이 끝나면 holding 애니메이션 시작
			task.spawn(function()
				if self.finishAnimationTrack then
					self.finishAnimationTrack.Ended:Wait()
				end
				if self.tool and self.tool.Parent == self.player.Character then
					self:_playHoldingAnimation()
				end
			end)

			self.baitThrown = false
			return
		end

		if data == "play_fishing_animation" then
			--self:_resetToolGrip()
			self:_stopHoldingAnimation()
			self:_playFishingAnimation()
			return
		end

		if data == "play_waiting_animation" then
			--self:_resetToolGrip()
			self:_playWaitingAnimation()
			return
		end

		if data == "keep_waiting_animation" then
			-- 물고기가 미끼를 물면 FishBaitEat 애니메이션 재생
			self:_playFishBaitEatAnimation()
			return
		end

		if data == "stop_all_animations" then
			self:_stopAllAnimations()
			return
		end

		if data == "retry_granted" then
			self.currentProgress = 0
			self:_updateProgressBar()
			self:_resetHitZone()
			return
		end

		if not data or typeof(data) ~= "table" or not data.rarity then
			self:_closeGui()
			self.baitThrown = false
			return
		end

		self:_openGui(data.rarity, data.toolName, data.difficultyMod)
	end)

	self.tool.Equipped:Connect(function()
		-- 🔧 다른 애니메이션이 재생 중이 아닐 때만 holding 애니메이션 시작
		if (not self.fishBaitEatAnimationTrack or not self.fishBaitEatAnimationTrack.IsPlaying) and
			(not self.finishAnimationTrack or not self.finishAnimationTrack.IsPlaying) then
			self:_playHoldingAnimation()
		end
	end)

	self.tool.Unequipped:Connect(function()
		self:_stopHoldingAnimation()
		self:_stopAllAnimations()
		self:_closeGui()
		self.baitThrown = false
	end)
end

function FishingClient:_openGui(rarity, serverToolName, serverDifficultyMod)
	-- FishBaitEat 애니메이션이 재생 중인지 확인
	local wasFishBaitEatPlaying = self.fishBaitEatAnimationTrack and self.fishBaitEatAnimationTrack.IsPlaying

	self:_closeGui() -- 기존 GUI 제거

	local Config = require(game.ReplicatedStorage.Modules:WaitForChild("FishingConfigModule"))
	local FishDifficulty = require(game.ReplicatedStorage.Modules:WaitForChild("FishDifficultyModule"))

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

	self.currentProgress = 0
	self:_updateProgressBar()

	for _, child in pairs(self.frame:GetChildren()) do
		if child:IsA("TextLabel") and child.Text:find("클릭하여") then
			child.Text = string.format("목표 %d%% | 스트롱존(+%d%%) 일반존(+%d%%) 실패(-15%%)",
				self.maxProgress, self.strongZoneProgress, self.normalZoneProgress)
			break
		end
	end

	self:_resetHitZone(difficulty.hitSize)
	self:_startSlider(difficulty.speed)

	tutorialEvent:Fire("minigame_started")

	-- FishBaitEat 애니메이션이 재생 중이었다면 계속 유지
	if wasFishBaitEatPlaying then
		self:_playFishBaitEatAnimation()
	end

	self.inputBeganConnection = UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		self:_handleUserInput(inputObject, gameProcessed)
	end)
end

function FishingClient:_closeGui()
	self.gameEndCooldown = tick() + 1.5

	local preserveFinishAnimation = self.finishAnimationTrack and self.finishAnimationTrack.IsPlaying

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

	-- finish 애니메이션을 제외한 모든 애니메이션 정지
	if self.fishingAnimationTrack then
		self.fishingAnimationTrack:Stop()
		self.fishingAnimationTrack = nil
	end

	if self.waitingAnimationTrack then
		self.waitingAnimationTrack:Stop()
		self.waitingAnimationTrack = nil
	end

	if self.fishBaitEatAnimationTrack then
		self.fishBaitEatAnimationTrack:Stop()
		self.fishBaitEatAnimationTrack = nil
	end

	if self.holdingAnimationTrack then
		self.holdingAnimationTrack:Stop()
		self.holdingAnimationTrack = nil
	end

	-- finish 애니메이션이 재생 중이 아니라면 바로 holding 애니메이션 시작
	if not preserveFinishAnimation then
		task.spawn(function()
			task.wait(0.1)
			-- 🔧 FishBaitEat 애니메이션이 재생 중이 아닐 때만 holding 애니메이션 시작
			if self.tool and self.tool.Parent == self.player.Character and
				(not self.fishBaitEatAnimationTrack or not self.fishBaitEatAnimationTrack.IsPlaying) then
				self:_playHoldingAnimation()
			end
		end)
	end
end

return FishingClient
