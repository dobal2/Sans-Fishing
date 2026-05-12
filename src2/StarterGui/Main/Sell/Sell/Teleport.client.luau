local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer
local button = script.Parent
local enable = true
local fishPoint = workspace:WaitForChild("SellPoint")

button.MouseButton1Down:Connect(function()
	if not enable then return end

	if player:GetAttribute("IsFishing") then
		local noticeEvent = ReplicatedStorage:WaitForChild("NoticeEventForClient")
		noticeEvent:Fire("You can't teleport while fishing")
		return
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid and humanoid.Sit then
			local noticeEvent = ReplicatedStorage:WaitForChild("NoticeEventForClient")
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
	script:WaitForChild("click"):Play()
	task.wait(0.5)
	enable = true
end)
