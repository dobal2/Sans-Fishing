-- 빔 관리 LocalScript (StarterGui에 생성)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ShowBeamEvent = ReplicatedStorage:WaitForChild("ShowBeamEvent")
local tutorialBeam = ReplicatedStorage:WaitForChild("TutorialBeam")

-- 빔 관리 변수들
local currentBeam = nil
local playerAttachment = nil
local targetAttachment = nil

-- 빔 생성 함수
local function createBeam(targetTrap)
	-- 해당 도구가 장착되어 있는지 확인
	local character = player.Character
	if not character then
		warn("캐릭터가 없음 - 빔 생성 실패")
		return
	end

	-- 도구가 장착되어 있는지 확인
	local isToolEquipped = false
	for _, tool in pairs(character:GetChildren()) do
		if tool:IsA("Tool") and (tool.Name == "BasicFishTrap" or tool.Name == "AdvancedFishTrap" or
			tool.Name == "MasterFishTrap" or tool.Name == "RobuxFishTrap") then
			isToolEquipped = true
			break
		end
	end

	-- 도구가 장착되어 있지 않으면 빔 생성 안 함
	if not isToolEquipped then
		--print("도구 미장착 - 빔 생성 취소:", player.Name)
		return
	end

	-- 기존 빔 제거
	if currentBeam then
		currentBeam:Destroy()
		currentBeam = nil
	end
	if playerAttachment then
		playerAttachment:Destroy()
		playerAttachment = nil
	end
	if targetAttachment then
		targetAttachment:Destroy()
		targetAttachment = nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		warn("HumanoidRootPart가 없음 - 빔 생성 실패")
		return
	end

	-- 플레이어 어태치먼트 생성
	playerAttachment = Instance.new("Attachment")
	playerAttachment.Name = "TutorialPlayerAttachment"
	playerAttachment.Parent = rootPart

	-- 타겟 어태치먼트 생성
	local targetPart = targetTrap.PrimaryPart or targetTrap:FindFirstChildWhichIsA("BasePart")
	if not targetPart then
		warn("타겟 파트가 없음 - 빔 생성 실패")
		playerAttachment:Destroy()
		playerAttachment = nil
		return
	end

	targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "TutorialTargetAttachment"
	targetAttachment.Parent = targetPart

	-- 빔 생성
	currentBeam = tutorialBeam:Clone()
	currentBeam.Name = "TutorialBeamClone"
	currentBeam.Attachment0 = targetAttachment
	currentBeam.Attachment1 = playerAttachment
	currentBeam.Parent = rootPart

	--print("클라이언트 빔 생성 완료:", player.Name)
end

-- 빔 제거 함수
local function removeBeam()
	if currentBeam then
		currentBeam:Destroy()
		currentBeam = nil
		--print("빔 제거됨:", player.Name)
	end
	if playerAttachment then
		playerAttachment:Destroy()
		playerAttachment = nil
	end
	if targetAttachment then
		targetAttachment:Destroy()
		targetAttachment = nil
	end
end

-- 서버에서 빔 표시/숨김 요청 처리
ShowBeamEvent.OnClientEvent:Connect(function(action, targetTrap)
	--print("빔 이벤트 수신:", action, targetTrap and "타겟있음" or "타겟없음")

	if action == "show" and targetTrap then
		createBeam(targetTrap)
	elseif action == "hide" then
		removeBeam()
	end
end)

-- 캐릭터가 리스폰될 때 빔 정리
player.CharacterAdded:Connect(function(character)
	removeBeam()
	--print("캐릭터 리스폰 - 빔 정리")
end)

-- 플레이어가 게임을 떠날 때 정리
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		removeBeam()
		--print("플레이어 떠남 - 빔 정리")
	end
end)

--print("클라이언트 빔 관리 시스템 로딩 완료:", player.Name)
