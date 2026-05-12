local tool = script.Parent
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local castEvent = tool:WaitForChild("CastRod")
local event = tool:WaitForChild("RemoteEvent")
local GUI = script:WaitForChild("FishingGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishDifficulty = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDifficultyModule"))
local RandomGen = Random.new()

local newGUI = nil
local sliderTween = nil
local slider = nil
local hitZone = nil
local currentAttempt = 1
local maxAttempts = 1

-- HitZone 재랜덤 함수
local function resetHitZone(hitSizeRange)
	local hitSizeX = RandomGen:NextNumber(hitSizeRange.min, hitSizeRange.max)
	local maxCenterX = 1 - hitSizeX / 2
	local minCenterX = hitSizeX / 2
	local hitCenterX = RandomGen:NextNumber(minCenterX, maxCenterX)

	-- 중앙 기준 설정
	hitZone.AnchorPoint = Vector2.new(0.5, 0)
	hitZone.Size = UDim2.new(hitSizeX, 0, 1, 0)
	hitZone.Position = UDim2.new(hitCenterX, 0, 0, 0)
end


-- Slider 초기화 함수
local function startSlider(speedRange)
	-- 슬라이더 중심 기준으로 좌우 경계 계산
	local halfWidth = slider.Size.X.Scale / 2
	local leftEdge = halfWidth
	local rightEdge = 1 - halfWidth

	-- AnchorPoint를 슬라이더 중심으로 설정
	slider.AnchorPoint = Vector2.new(0.5, 0)

	-- 초기 위치 (왼쪽에서 시작)
	slider.Position = UDim2.new(leftEdge, 0, 0, 0)

	local tweenTime = RandomGen:NextNumber(speedRange.min, speedRange.max)
	local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

	local goal = { Position = UDim2.new(rightEdge, 0, 0, 0) }

	sliderTween = TweenService:Create(slider, tweenInfo, goal)
	sliderTween:Play()
end



-- 시도 1회 처리
-- 시도 1회 처리 (한 번이라도 실패하면 낚시 종료)
local function processAttempt(fishRarity)
	if sliderTween then sliderTween:Cancel() end

	local sliderLeft = slider.AbsolutePosition.X
	local sliderRight = sliderLeft + slider.AbsoluteSize.X
	local hitLeft = hitZone.AbsolutePosition.X
	local hitRight = hitLeft + hitZone.AbsoluteSize.X

	local success = sliderRight >= hitLeft and sliderLeft <= hitRight

	if success then
		print("Success")
		if currentAttempt >= maxAttempts then
			event:FireServer({ name = fishRarity })
			newGUI:Destroy()
			newGUI = nil
		else
			currentAttempt += 1
			local difficulty = FishDifficulty.GetSetting(fishRarity)
			resetHitZone(difficulty.hitSize)
			startSlider(difficulty.speed)
		end
	else
		print("Fail")
		event:FireServer(0)
		newGUI:Destroy()
		newGUI = nil
	end
end




UserInputService.InputBegan:Connect(function(input, processed)
	if not newGUI or processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		processAttempt(newGUI:GetAttribute("FishRarity"))
	end
end)

-- 낚시 GUI 열기
event.OnClientEvent:Connect(function(fishInfo)
	if fishInfo and type(fishInfo) == "table" and fishInfo.name then
		local difficulty = FishDifficulty.GetSetting(fishInfo.name)
		maxAttempts = difficulty.attempts
		currentAttempt = 1

		newGUI = GUI:Clone()
		newGUI.Parent = player:WaitForChild("PlayerGui")
		newGUI.Enabled = true
		newGUI:SetAttribute("FishRarity", fishInfo.name)

		local frame = newGUI:WaitForChild("GaugeFrame")
		slider = frame:WaitForChild("Slider")
		hitZone = frame:WaitForChild("HitZone")

		resetHitZone(difficulty.hitSize)
		startSlider(difficulty.speed)
	elseif not fishInfo and newGUI then
		if sliderTween then sliderTween:Cancel() end
		newGUI:Destroy()
		newGUI = nil
	end
end)

-- 낚시 던지기
tool.Activated:Connect(function()
	if mouse and mouse.Hit then
		castEvent:FireServer(mouse.Hit.Position)
	end
end)
