local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer
local button = script.Parent
local enable = true
local fishPoint = workspace:WaitForChild("UpgradePoint")

button.MouseButton1Down:Connect(function()
	if not enable then return end

	-- ✅ 어트리뷰트로 낚시 중 여부 확인
	if player:GetAttribute("IsFishing") then
		local noticeEvent = ReplicatedStorage:WaitForChild("NoticeEventForClient")
		noticeEvent:Fire("You can't teleport while fishing")
		return
	end

	-- 🪑 플레이어가 앉아있는지 확인
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid and humanoid.Sit then
			local noticeEvent = ReplicatedStorage:WaitForChild("NoticeEventForClient")
			noticeEvent:Fire("You can't teleport while sitting")
			return
		end
	end

	-- ✅ 텔레포트 실행
	enable = false
	character = character or player.CharacterAdded:Wait()
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and fishPoint then
		hrp.CFrame = fishPoint.CFrame
	end
	script:WaitForChild("click"):Play()
	task.wait(0.5)
	enable = true
end)
