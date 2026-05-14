local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer
local mainGui = player.PlayerGui:WaitForChild("Main")
local button = mainGui:WaitForChild("Upgrade"):WaitForChild("TextButton")
local clickSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("click")
local enable = true
local fishPoint = workspace:WaitForChild("UpgradePoint")

button.MouseButton1Down:Connect(function()
	if not enable then return end

	if player:GetAttribute("IsFishing") then
		local noticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("NoticeEventForClient")
		noticeEvent:Fire("You can't teleport while fishing")
		return
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid and humanoid.Sit then
			local noticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("NoticeEventForClient")
			noticeEvent:Fire("You can't teleport while sitting")
			return
		end
	end

	enable = false
	character = character or player.CharacterAdded:Wait()
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and fishPoint then
		hrp.CFrame = fishPoint.CFrame
	end
	clickSound:Play()
	task.wait(0.5)
	enable = true
end)
