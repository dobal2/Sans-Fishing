-- 기존 GUI 구조와 연동하는 로컬 스크립트 (UI 생성 없음)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- 리모트 이벤트 대기
local miscRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc")
local ClaimDailyReward = miscRemotes:WaitForChild("ClaimDailyReward")
local CheckDailyReward = miscRemotes:WaitForChild("CheckDailyReward")

-- 기존 GUI 요소들 찾기
local dailyRewardsGui = player.PlayerGui:WaitForChild("DailyRewards")
local shopFrame = dailyRewardsGui:WaitForChild("ShopFrame")
local container = shopFrame:WaitForChild("Container")
local buttonFrame = dailyRewardsGui:WaitForChild("ButtonFrame")
local claimButton = buttonFrame:WaitForChild("ClaimButton")

-- 변수들
local currentRewardData = nil
local isProcessing = false

-- Day 프레임들과 UIStroke 찾기
local dayFrames = {}
local dayStrokes = {}

for i = 1, 7 do
	local dayFrame = container:FindFirstChild("Day" .. i)
	if dayFrame then
		dayFrames[i] = dayFrame
		-- UIStroke 찾기 (없으면 생성)
		local uiStroke = dayFrame:FindFirstChild("UIStroke")
		if not uiStroke then
			uiStroke = Instance.new("UIStroke")
			uiStroke.Color = Color3.fromRGB(0, 255, 0) -- 초록색 테두리
			uiStroke.Thickness = 3
			uiStroke.Enabled = false -- 기본적으로 비활성화
			uiStroke.Parent = dayFrame
		end
		dayStrokes[i] = uiStroke
	end
end

-- Day 프레임 업데이트 함수
local function updateDayFrames(data)
	-- 모든 UIStroke 비활성화
	for i = 1, 7 do
		if dayStrokes[i] then
			dayStrokes[i].Enabled = false
		end
	end

	-- 현재 연속 출석일에 해당하는 Day 프레임의 UIStroke 활성화 및 깜빡이기
	if data.consecutiveDays and data.consecutiveDays > 0 and data.consecutiveDays <= 7 then
		if dayStrokes[data.consecutiveDays] then
			local currentStroke = dayStrokes[data.consecutiveDays]
			currentStroke.Enabled = true

			-- 자연스러운 깜빡이기 효과
			local blinkTween = TweenService:Create(
				currentStroke,
				TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{Transparency = 0.3}
			)
			blinkTween:Play()
		end
	end
end

-- GUI 업데이트
local function updateGui(data)
	currentRewardData = data

	-- Day 프레임들 업데이트
	updateDayFrames(data)
end

-- 이벤트 연결
claimButton.MouseButton1Click:Connect(function()
	if not currentRewardData or not currentRewardData.canClaim or isProcessing then
		return
	end

	isProcessing = true

	ClaimDailyReward:FireServer()
end)

-- 서버 응답 처리
CheckDailyReward.OnClientEvent:Connect(function(data)
	updateGui(data)
end)

ClaimDailyReward.OnClientEvent:Connect(function(result)
	isProcessing = false

	if result.success then
		-- GUI 업데이트를 위해 다시 확인
		CheckDailyReward:FireServer()
	else
		-- 실패 시 그냥 다시 확인
		CheckDailyReward:FireServer()
	end
end)

-- 플레이어 입장 시 확인
player.CharacterAdded:Connect(function()
	task.wait(2)
	CheckDailyReward:FireServer()
end)

-- 이미 캐릭터가 있다면
if player.Character then
	task.wait(2)
	CheckDailyReward:FireServer()
end
