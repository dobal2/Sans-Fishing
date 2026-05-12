-- 🔧 서버 스크립트 (ServerScriptService에 넣으세요)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- RemoteEvent 생성 (한 번만 실행)
local fishLockEvent = Instance.new("RemoteEvent")
fishLockEvent.Name = "FishLockEvent"
fishLockEvent.Parent = ReplicatedStorage

-- 🛡️ 해킹 방지를 위한 요청 제한 (스팸 방지)
local playerCooldowns = {}
local COOLDOWN_TIME = 0.1 -- 0.1초 쿨다운

-- 🛡️ 클라이언트에서 잠금 상태 변경 요청 처리 (보안 강화)
fishLockEvent.OnServerEvent:Connect(function(player, tool, isLocked)
	-- 🔒 쿨다운 체크 (스팸 방지)
	local currentTime = tick()
	local lastRequest = playerCooldowns[player.UserId] or 0

	if currentTime - lastRequest < COOLDOWN_TIME then
		warn("🚫 " .. player.Name .. " - 너무 빠른 물고기 잠금 요청 (스팸 방지)")
		return
	end
	playerCooldowns[player.UserId] = currentTime

	-- 🔒 기본 검증
	if not tool or not tool:IsA("Tool") then
		warn("🚫 " .. player.Name .. " - 유효하지 않은 도구")
		return
	end

	if typeof(isLocked) ~= "boolean" then
		warn("🚫 " .. player.Name .. " - 유효하지 않은 잠금 상태")
		return
	end

	-- 🔒 소유권 검증 (해킹 방지)
	if tool.Parent ~= player.Character and tool.Parent ~= player.Backpack then
		warn("🚫 " .. player.Name .. " - 소유하지 않은 도구에 잠금 시도: " .. tool.Name)
		return
	end

	-- 🔒 물고기인지 확인
	if not tool:FindFirstChild("FishValue") then
		warn("🚫 " .. player.Name .. " - 물고기가 아닌 도구에 잠금 시도: " .. tool.Name)
		return
	end

	-- ✅ 모든 검증 통과 - 서버에서 BoolValue 생성/업데이트
	local lockValue = tool:FindFirstChild("FishLock")
	if not lockValue then
		lockValue = Instance.new("BoolValue")
		lockValue.Name = "FishLock"
		lockValue.Parent = tool
	end

	lockValue.Value = isLocked

	print("🔧 서버에서 물고기 잠금 상태 업데이트:", tool.Name, "플레이어:", player.Name, "잠금:", isLocked)
end)

-- 🧹 플레이어가 나갈 때 쿨다운 정리
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
end)
