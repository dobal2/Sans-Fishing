local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:FindFirstChildOfClass("Animator")

-- ReplicatedStorage/Animations 폴더에서 모든 애니메이션 가져오기
local animationsFolder = ReplicatedStorage:WaitForChild("Animations")
for _, anim in ipairs(animationsFolder:GetChildren()) do
	if anim:IsA("Animation") then
		local track = animator:LoadAnimation(anim)
		track:Play()
		track:Stop()
		--print("🎬 클라이언트 프리로드 완료:", anim.Name)
	else
		warn("❌ 애니메이션 아님:", anim.Name)
	end
end
