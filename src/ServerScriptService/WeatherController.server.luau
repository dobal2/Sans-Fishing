-- ServerScriptService/WeatherController.lua
-- 날씨 시스템을 자동으로 시작하는 서버 스크립트

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("🚀 WeatherController 시작")

-- 모듈 로드 (안전한 방식)
local modules = ReplicatedStorage:WaitForChild("Modules")
local WeatherSystem = require(modules:WaitForChild("WeatherSystemModule"))

-- FishData 모듈은 옵션으로 처리 (없어도 날씨 시스템은 작동하도록)
local FishData = nil
local fishDataModule = modules:FindFirstChild("FishDataModule")
if fishDataModule then
	FishData = require(fishDataModule)
	print("✅ FishData 모듈 로드 완료")
else
	warn("⚠️ FishDataModule을 찾을 수 없습니다. 물고기 테스트는 비활성화됩니다.")
end

-- 🌤️ 날씨 시스템 초기화 (자동으로 20분 사이클 시작 + RemoteEvent 생성)
print("🌤️ 날씨 시스템 초기화 중...")
WeatherSystem.Initialize()

-- 초기화 완료 대기
wait(1)

print("✅ 날씨 시스템 초기화 완료")

-- 🔧 관리자 계정 리스트
local allowedUsers = {"tallmo_bim", "mkdoingsu"}

-- 관리자 권한 확인 함수
local function isAdmin(playerName)
	for _, allowedUser in ipairs(allowedUsers) do
		if playerName == allowedUser then
			return true
		end
	end
	return false
end

-- 🧪 테스트 명령어들 (개발 중에만 사용)
local function setupTestCommands()
	-- 이미 접속한 플레이어들에게도 적용
	for _, player in pairs(Players:GetPlayers()) do
		if isAdmin(player.Name) then
			print("🔧 관리자 권한 부여:", player.Name)
			player.Chatted:Connect(function(message)
				handleAdminCommand(player, message)
			end)
		end
	end

	-- 새로 접속하는 플레이어들에게 적용
	Players.PlayerAdded:Connect(function(player)
		print("👤 플레이어 접속:", player.Name)

		-- 관리자 권한 확인
		if isAdmin(player.Name) then
			print("🔧 관리자 권한 부여:", player.Name)
			player.Chatted:Connect(function(message)
				handleAdminCommand(player, message)
			end)
		end
	end)
end

-- 관리자 명령어 처리 함수
function handleAdminCommand(player, message)
	print("💬 관리자 명령어 수신:", player.Name, "->", message)

	local args = string.split(message, " ")
	local command = args[1]:lower()

	if command == "/rain" then
		local duration = tonumber(args[2]) or 600
		local success = WeatherSystem.SetWeather("Rain", duration)
		if success then
			print("🧪 테스트: 비 날씨 설정 -", duration, "초")
			game:GetService("ReplicatedStorage").WeatherChangedEvent:FireClient(player, "Rain")
		else
			warn("❌ 비 날씨 설정 실패")
		end

	elseif command == "/snow" then
		local duration = tonumber(args[2]) or 600
		local success = WeatherSystem.SetWeather("Snow", duration)
		if success then
			print("🧪 테스트: 눈 날씨 설정 -", duration, "초")
			game:GetService("ReplicatedStorage").WeatherChangedEvent:FireClient(player, "Snow")
		else
			warn("❌ 눈 날씨 설정 실패")
		end

	elseif command == "/firework" then
		local duration = tonumber(args[2]) or 600
		local success = WeatherSystem.SetWeather("Firework", duration)
		if success then
			print("🧪 테스트: 폭죽 날씨 설정 -", duration, "초")
			game:GetService("ReplicatedStorage").WeatherChangedEvent:FireClient(player, "Firework")
		else
			warn("❌ 폭죽 날씨 설정 실패")
		end

	elseif command == "/clear" then
		local success = WeatherSystem.SetWeather("Clear", 0)
		if success then
			print("🧪 테스트: 날씨 해제")
			game:GetService("ReplicatedStorage").WeatherChangedEvent:FireClient(player, "Clear")
		else
			warn("❌ 날씨 해제 실패")
		end

	elseif command == "/weather" then
		local info = WeatherSystem.GetCurrentWeatherInfo()
		print("🧪 현재 날씨 상태:")
		print("  - 날씨:", info.currentWeather)
		print("  - 활성:", info.isActive)
		print("  - 남은시간:", math.floor(info.remainingTime), "초")
		print("  - 다음 날씨까지:", math.floor(info.nextWeatherIn), "초")
		print("  - 사이클 수:", info.cycleCount)
	else
		-- 명령어가 아닌 일반 채팅은 무시
		return
	end
end

-- 🧪 테스트 명령어 활성화 (개발 중에만)
setupTestCommands()

-- 디버그: 5초마다 시스템 상태 확인
spawn(function()
	while true do
		wait(5)
		local info = WeatherSystem.GetCurrentWeatherInfo()
		if info then
			-- 상태가 변경되었을 때만 출력
			local statusText = string.format("🌤️ [%s] %s",
				info.isActive and "활성" or "대기중",
				info.currentWeather)
			-- print(statusText) -- 너무 많은 출력을 방지하기 위해 주석 처리
		end
	end
end)
