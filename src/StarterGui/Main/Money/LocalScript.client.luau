local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local leaderstats = player:WaitForChild("leaderstats")
local coins = leaderstats:WaitForChild("Coins")
local textLabel = script.Parent  -- TextLabel 객체
local buySound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("Buy SFX")
local SellSound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("Success")

-- 애니메이션 변수들
local currentDisplayValue = coins.Value  -- 현재 화면에 표시되는 값
local targetValue = coins.Value  -- 목표 값
local currentTween = nil  -- 현재 실행 중인 트윈
local renderConnection = nil  -- RenderStepped 연결

-- 이전 값 저장 (사운드 판별용)
local previousValue = coins.Value

-- 숫자를 3자리마다 콤마로 포맷하는 함수
local function formatNumberWithCommas(n)
	local formatted = tostring(math.floor(n))  -- 소수점 제거
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

-- 애니메이션 함수
local function animateToValue(newValue)
	-- 기존 트윈이 있으면 정리
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	targetValue = newValue
	local startValue = currentDisplayValue
	local difference = targetValue - startValue

	-- 차이가 없으면 즉시 적용
	if math.abs(difference) < 1 then
		currentDisplayValue = targetValue
		textLabel.Text = "¢ " .. formatNumberWithCommas(targetValue)
		return
	end

	-- 애니메이션 지속시간 (차이가 클수록 조금 더 오래)
	local duration = math.min(1.5, 0.5 + math.abs(difference) / 10000)

	-- 애니메이션 정보
	local animationInfo = TweenInfo.new(
		duration,  -- 지속시간
		Enum.EasingStyle.Quart,  -- 부드러운 애니메이션
		Enum.EasingDirection.Out,  -- 끝부분이 천천히
		0,  -- 반복 횟수
		false,  -- 역방향 재생 안함
		0  -- 지연시간
	)

	-- 애니메이션할 임시 값 객체 (NumberValue 사용)
	local valueObject = Instance.new("NumberValue")
	valueObject.Value = startValue

	-- 트윈 생성
	currentTween = TweenService:Create(valueObject, animationInfo, {Value = targetValue})

	-- 애니메이션 중 값 업데이트
	renderConnection = RunService.RenderStepped:Connect(function()
		currentDisplayValue = valueObject.Value
		textLabel.Text = "¢ " .. formatNumberWithCommas(currentDisplayValue)
	end)

	-- 애니메이션 완료 시
	currentTween.Completed:Connect(function()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		currentDisplayValue = targetValue
		textLabel.Text = "¢ " .. formatNumberWithCommas(targetValue)
		currentTween = nil
		valueObject:Destroy()  -- 임시 객체 정리
	end)

	-- 애니메이션 시작
	currentTween:Play()
end

-- 코인 값 변화 감지
coins.Changed:Connect(function(newValue)
	if newValue ~= targetValue then  -- 실제로 값이 바뀌었을 때만
		-- 🔊 사운드 재생 (이전 값과 비교)
		if newValue > previousValue then
			-- 코인이 증가했을 때 (판매 등)
			SellSound:Play()
		elseif newValue < previousValue then
			-- 코인이 감소했을 때 (구매 등)
			buySound:Play()
		end

		-- 이전 값 업데이트
		previousValue = newValue

		-- 애니메이션 시작
		animateToValue(newValue)
	end
end)

-- 초기 값 설정
textLabel.Text = "¢ " .. formatNumberWithCommas(coins.Value)
