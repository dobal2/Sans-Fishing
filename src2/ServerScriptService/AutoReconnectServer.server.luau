local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local dataManager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))
local RodDataModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RodDataModule"))

local Misc = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc")
local autoReconnectRequest = Misc:WaitForChild("AutoReconnectRequest")
local saveAutoFishing = Misc:WaitForChild("SaveAutoFishing")
local getAutoFishing = Misc:WaitForChild("GetAutoFishing")

-- Auto 상태 저장
saveAutoFishing.OnServerEvent:Connect(function(player, state)
	if type(state) ~= "boolean" then return end
	local data = dataManager:GetData(player)
	if not data then return end
	data.AutoFishingOn = state
	dataManager:UpdateData(player, "AutoFishingOn", state)
end)

-- Auto 상태 + 로드 이름 반환
getAutoFishing.OnServerInvoke = function(player)
	local data = dataManager:GetData(player)
	local autoOn = data and data.AutoFishingOn or false

	local rodName = nil
	local ls = player:FindFirstChild("leaderstats")
	local currentRod = ls and ls:FindFirstChild("CurrentRod")
	if currentRod and currentRod.Value ~= "" then
		local rodData = RodDataModule.Rods and RodDataModule.Rods[currentRod.Value]
		rodName = (rodData and rodData.storageName) or currentRod.Value
	end

	return autoOn, rodName
end


-- auto 켜져있으면 접속 시 캐릭터 방향 90도 회전
local function rotateCharacter90(player)
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		task.wait(1)
		local pos = hrp.Position
		local currentAngle = math.atan2(hrp.CFrame.LookVector.X, hrp.CFrame.LookVector.Z)
		local newAngle = currentAngle + math.rad(90)
		hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, newAngle, 0)
	end
end

Players.PlayerAdded:Connect(function(player)
	local data = dataManager:GetData(player)
	-- 데이터 로드 대기
	local timeout = 10
	while not dataManager:GetData(player) and timeout > 0 do
		task.wait(0.5)
		timeout -= 0.5
	end
	data = dataManager:GetData(player)
	if data and data.AutoFishingOn then
		-- Client handles auto-fishing rotation after character and rod are fully ready.
	end
end)

-- 텔레포트 처리
autoReconnectRequest.OnServerEvent:Connect(function(player, rodName)
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ autoReconnect = true })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		warn("AutoReconnect teleport failed for", player.Name, err)
	end
end)
