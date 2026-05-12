repeat wait() until game:IsLoaded()

local spawnLocation = workspace:WaitForChild("SpawnLocation")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- ⏱️ 설정값
local fallThresholdY = -500
local maxDistance = 6000

local function monitorFall(character)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then return end

	RunService.RenderStepped:Connect(function()
		if not root or not root.Parent then return end

		local distance = (root.Position - spawnLocation.Position).Magnitude

		if root.Position.Y < fallThresholdY or distance > maxDistance then
			-- ⛔ 순간이동 + 속도 제거
			root.CFrame = spawnLocation.CFrame
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			print("⏎ 위치 초기화됨 (낙하 또는 거리 이탈)")
		end
	end)
end

-- 현재 캐릭터가 있으면 바로 감시 시작
if player.Character then
	monitorFall(player.Character)
end

-- 이후 캐릭터가 새로 생길 때도 감시
player.CharacterAdded:Connect(monitorFall)
