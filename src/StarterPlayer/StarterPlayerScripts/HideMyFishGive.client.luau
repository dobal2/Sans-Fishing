local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- 내 Tool에 FishValue 있는지 확인하는 함수
local function hasFishTool()
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return tool and tool:FindFirstChild("FishValue") ~= nil
end

-- 자기 캐릭터 Prompt 비활성화 (항상 꺼짐)
local function onMyCharacterAdded(character)
	local hrp = character:WaitForChild("HumanoidRootPart")
	local prompt = hrp:WaitForChild("ReceiveFishPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end
end

-- 다른 플레이어의 Prompt 상태 갱신
local function updateOtherPlayerPrompt(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local prompt = hrp:FindFirstChild("ReceiveFishPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then return end

	-- 다른 사람 Prompt는 내가 FishTool 들었을 때만 켜짐
	prompt.Enabled = hasFishTool()
end

-- 모든 다른 플레이어 Prompt 갱신
local function updateAllOtherPrompts()
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			updateOtherPlayerPrompt(otherPlayer.Character)
		end
	end
end

-- 내 캐릭터 Tool 변경 감지
local function connectToolEvents(char)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			wait(0.05)
			updateAllOtherPrompts()
		end
	end)

	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			wait(0.05)
			updateAllOtherPrompts()
		end
	end)
end

-- 다른 플레이어 캐릭터 추가 시 처리
local function onOtherPlayerCharacterAdded(character)
	-- ProximityPrompt 생성 대기 후 상태 갱신
	spawn(function()
		local hrp = character:WaitForChild("HumanoidRootPart")
		hrp:WaitForChild("ReceiveFishPrompt")
		wait(0.1)
		updateOtherPlayerPrompt(character)
	end)
end

-- 기존 플레이어들 처리
for _, existingPlayer in ipairs(Players:GetPlayers()) do
	if existingPlayer == player then
		-- 내 캐릭터 처리
		if existingPlayer.Character then
			onMyCharacterAdded(existingPlayer.Character)
			connectToolEvents(existingPlayer.Character)
		end
	else
		-- 다른 플레이어 처리
		if existingPlayer.Character then
			onOtherPlayerCharacterAdded(existingPlayer.Character)
		end
		existingPlayer.CharacterAdded:Connect(onOtherPlayerCharacterAdded)
	end
end

-- 새로운 플레이어 추가 시 처리
Players.PlayerAdded:Connect(function(newPlayer)
	if newPlayer ~= player then
		newPlayer.CharacterAdded:Connect(onOtherPlayerCharacterAdded)
	end
end)

-- 내 캐릭터 이벤트 연결
player.CharacterAdded:Connect(function(char)
	onMyCharacterAdded(char)
	connectToolEvents(char)
	-- 내가 리스폰하면 다른 플레이어들 Prompt도 갱신
	updateAllOtherPrompts()
end)
