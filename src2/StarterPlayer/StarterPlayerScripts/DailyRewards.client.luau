local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local robuxBuySound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("RobuxBuySound")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local miscRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc")
local ClaimDailyReward = miscRemotes:WaitForChild("ClaimDailyReward")
local CheckDailyReward = miscRemotes:WaitForChild("CheckDailyReward")

local gui = playerGui:WaitForChild("DailyRewards")
local dailyRewardFrame = gui:WaitForChild("DailyReward")
local main = dailyRewardFrame:WaitForChild("Main")

local buttonFrame = dailyRewardFrame:FindFirstChild("Button")
if buttonFrame then buttonFrame.Visible = false end

local currentDay = 1
local canClaim = false
local claiming = false

local uiScale = dailyRewardFrame:FindFirstChildOfClass("UIScale")
if not uiScale then
	uiScale = Instance.new("UIScale")
	uiScale.Parent = dailyRewardFrame
end
uiScale.Scale = 0

local TWEEN_IN  = TweenInfo.new(0.35, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local TWEEN_OUT = TweenInfo.new(0.2,  Enum.EasingStyle.Quart, Enum.EasingDirection.In)

local dayFrames = {}
for i = 1, 7 do
	dayFrames[i] = main:FindFirstChild("Day" .. i)
end

local function setDayActive(dayIndex, active)
	local frame = dayFrames[dayIndex]
	if not frame then return end
	local stroke = frame:FindFirstChild("UIStroke")
	if stroke then stroke.Enabled = active end
	local claimUIStroke = frame:FindFirstChild("ClaimUIStroke")
	if claimUIStroke then claimUIStroke.Enabled = active end
	local claimText = frame:FindFirstChild("ClaimText")
	if claimText then
		if active then claimText.Text = "CLAIM" end
		claimText.Visible = active
	end
	local claimButton = frame:FindFirstChild("ClaimButton")
	if claimButton then claimButton.Visible = active end
	frame.BackgroundTransparency = active and 0 or 0.45
end

local function hideFrame()
	local t = TweenService:Create(uiScale, TWEEN_OUT, { Scale = 0 })
	t:Play()
	t.Completed:Once(function()
		dailyRewardFrame.Visible = false
	end)
end

local function showFrame()
	dailyRewardFrame.Visible = true
	uiScale.Scale = 0
	TweenService:Create(uiScale, TWEEN_IN, { Scale = 1 }):Play()
end

local function refreshUI(data)
	currentDay = data.day or 1
	canClaim = data.canClaim == true
	for i = 1, 7 do
		setDayActive(i, false)
	end
	if canClaim then
		setDayActive(currentDay, true)
	else
		local frame = dayFrames[currentDay]
		if frame then
			frame.BackgroundTransparency = 0.6
			local claimText = frame:FindFirstChild("ClaimText")
			if claimText then
				claimText.Text = "✓ Claimed"
				claimText.Visible = true
			end
			local claimUIStroke = frame:FindFirstChild("ClaimUIStroke")
			if claimUIStroke then claimUIStroke.Enabled = true end
		end
	end
end

-- 각 Day ClaimButton 연결
for i = 1, 7 do
	local frame = dayFrames[i]
	if not frame then continue end
	local claimButton = frame:FindFirstChild("ClaimButton")
	if not claimButton then continue end
	claimButton.MouseButton1Click:Connect(function()
		if claiming or not canClaim or currentDay ~= i then return end
		claiming = true
		claimButton.Active = false

		-- claiming 타임아웃: 서버 무응답 시 10초 후 자동 해제
		task.delay(10, function()
			if claiming then
				claiming = false
				claimButton.Active = true
			end
		end)

		ClaimDailyReward:FireServer()
	end)
end

-- 서버: 상태 응답
CheckDailyReward.OnClientEvent:Connect(function(data)
	refreshUI(data)
	if data.openGui then
		showFrame()
	elseif not data.canClaim then
		dailyRewardFrame.Visible = false
		uiScale.Scale = 0
	end
end)

-- 서버: 클레임 결과
ClaimDailyReward.OnClientEvent:Connect(function(data)
	claiming = false
	for i = 1, 7 do
		local frame = dayFrames[i]
		if frame then
			local cb = frame:FindFirstChild("ClaimButton")
			if cb then cb.Active = true end
		end
	end

	if data.reason == "reset" or data.reason == "already_claimed" then return end
	if not data.success then return end

	canClaim = false
	robuxBuySound:Play()
	hideFrame()

	-- 로드 보상 장착
	if data.equippedRod then
		task.spawn(function()
			task.wait(0.3)
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local backpack = player:FindFirstChild("Backpack")
			if hum and backpack then
				local tool = backpack:FindFirstChild(data.equippedRod)
				if tool then hum:EquipTool(tool) end
			end
		end)
	end

	-- 물고기 보상: FishDataAddedRemote 오면 장착
	if data.equippedFish then
		local fishName = data.equippedFish
		task.spawn(function()
			local fishAddedRemote = miscRemotes:FindFirstChild("FishDataAddedRemote")
			if fishAddedRemote then
				local conn
				-- 타임아웃: 5초 내 응답 없으면 폴링으로 전환
				local done = false
				task.delay(5, function()
					if not done and conn then conn:Disconnect() end
				end)
				conn = fishAddedRemote.OnClientEvent:Connect(function()
					done = true
					conn:Disconnect()
					task.wait(0.1)
					local char = player.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					local backpack = player:FindFirstChild("Backpack")
					if not hum or not backpack then return end
					for _, t in ipairs(backpack:GetChildren()) do
						if t:IsA("Tool") and t.Name:find(fishName, 1, true) then
							hum:EquipTool(t)
							return
						end
					end
				end)
			else
				-- 폴백 폴링 (0.5초 딜레이 후 시작)
				task.wait(0.5)
				local deadline = tick() + 4
				while tick() < deadline do
					local char = player.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					local backpack = player:FindFirstChild("Backpack")
					if hum and backpack then
						for _, t in ipairs(backpack:GetChildren()) do
							if t:IsA("Tool") and t.Name:find(fishName, 1, true) then
								hum:EquipTool(t)
								return
							end
						end
					end
					task.wait(0.2)
				end
			end
		end)
	end

	-- NoticeFrame 알림
	local noticeEvent = ReplicatedStorage:FindFirstChild("Remotes")
		and ReplicatedStorage.Remotes:FindFirstChild("Notice")
		and ReplicatedStorage.Remotes.Notice:FindFirstChild("NoticeEventForClient")
	if noticeEvent then
		local r = data.reward
		local msg = ""
		if r.type == "Coins" then
			msg = string.format("Daily Reward Day %d: +%d Coins!", data.day, r.amount)
		elseif r.type == "Rod" then
			msg = string.format("Daily Reward Day %d: %s!", data.day, r.rodName)
		elseif r.type == "Fish" then
			msg = string.format("Daily Reward Day %d: %s!", data.day, r.fishName)
		end
		if msg ~= "" then noticeEvent:Fire(msg) end
	end
end)

-- 접속 시 DataReady 후 상태 요청 → canClaim일 때만 열기
task.spawn(function()
	local dataReady = player:WaitForChild("DataReady", 30)
	if dataReady then
		repeat task.wait(0.5) until dataReady.Value == true
	else
		task.wait(3)
	end

	local opened = false
	local conn
	-- 타임아웃: 10초 내 응답 없으면 conn 정리
	task.delay(10, function()
		if not opened and conn then conn:Disconnect() end
	end)
	conn = CheckDailyReward.OnClientEvent:Connect(function(data)
		if not opened then
			opened = true
			conn:Disconnect()
			if data.canClaim then
				task.wait(1)
				showFrame()
			end
		end
	end)
	CheckDailyReward:FireServer()
end)

-- 외부 토글용 BindableEvent
local openBindable = Instance.new("BindableEvent")
openBindable.Name = "OpenDailyRewards"
openBindable.Parent = playerGui
openBindable.Event:Connect(function()
	if dailyRewardFrame.Visible then
		hideFrame()
	else
		showFrame()
	end
end)
