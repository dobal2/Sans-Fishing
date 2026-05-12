-- LocalScript
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local textLabel = script.Parent

-- RemoteFunction 생성 (서버와 통신용)
local getFriendsCountRemote = ReplicatedStorage:WaitForChild("GetFriendsCountRemote")

local function updateFriendBonus()
	-- 서버에서 친구 수 가져오기
	local success, friendsCount = pcall(function()
		return getFriendsCountRemote:InvokeServer()
	end)

	if success and friendsCount then
		--if friendsCount == 0 then
		--	textLabel.Visible = false
		--else
		--	textLabel.Visible = true
		--end

		local bonusPercent = friendsCount * 5
		textLabel.Text = string.format('Friends Bonus: <font color="rgb(255,255,0)">+%d%%</font>', bonusPercent)
	else
		textLabel.Text = "Friends Bonus: Loading..."
	end
end

-- 5초마다 업데이트
local lastUpdate = 0
RunService.Heartbeat:Connect(function()
	local currentTime = tick()
	if currentTime - lastUpdate >= 5 then
		lastUpdate = currentTime
		updateFriendBonus()
	end
end)

-- 처음 시작할 때 한 번 실행
updateFriendBonus()
