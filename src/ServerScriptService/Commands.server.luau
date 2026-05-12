-- -----------[[Clean Admin System with Global Features]]------------

-- 📢 Services
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- 📢 공지 리모트 이벤트 생성/가져오기
local announceRemote = ReplicatedStorage:FindFirstChild("AnnounceRemote")
if not announceRemote then
	announceRemote = Instance.new("RemoteEvent")
	announceRemote.Name = "AnnounceRemote"
	announceRemote.Parent = ReplicatedStorage
end

-- 🔑 권한 설정
local Ranks = {
	Developer = {"tallmo_bim", "mkdoingsu"},
	Moderator = {},
}

local Permissions = {
	Developer = {
		speed = true,
		ang = true,
		kick = true,
		setcoins = true,
		announce = true,
		GlobalGiveCoins = true,
		SlapBattle = true,
		SlapBattleAll = true,
		DevRod = true,
		DevRodAll = true,
	},
	Moderator = {
		kick = true,
		announce = true,
		GlobalGiveCoins = true,
		SlapBattle = true,
		SlapBattleAll = true,
		DevRod = true,
		DevRodAll = true,
	}
}

local Prefix = ":"

-- 🎯 기본 함수들
local function getPlayerRank(playerName)
	for rank, players in pairs(Ranks) do
		for _, name in pairs(players) do
			if name == playerName then
				return rank
			end
		end
	end
	return nil
end

local function hasPermission(playerName, command)
	local rank = getPlayerRank(playerName)
	if not rank then return false end
	return Permissions[rank] and Permissions[rank][command] == true
end

local function findPlayers(executor, targetName)
	local foundPlayers = {}

	if targetName:lower() == "me" then
		table.insert(foundPlayers, executor)
		return foundPlayers
	end

	if targetName:lower() == "all" then
		for _, player in pairs(Players:GetPlayers()) do
			table.insert(foundPlayers, player)
		end
		return foundPlayers
	end

	for _, player in pairs(Players:GetPlayers()) do
		if player.Name:lower():sub(1, #targetName) == targetName:lower() then
			table.insert(foundPlayers, player)
		end
	end

	return foundPlayers
end

-- 🥊 SlapBattle 관련 함수들 (순서대로 정의)
local function giveSlapBattle(targetPlayer, executorName)
	local slapBattleTool = ServerStorage:FindFirstChild("SlapBattle")

	if not slapBattleTool then
		warn("❌ SlapBattle 도구를 ServerStorage에서 찾을 수 없습니다!")
		return false
	end

	local backpack = targetPlayer:FindFirstChild("Backpack")
	if not backpack then
		warn("❌ 플레이어 백팩을 찾을 수 없습니다:", targetPlayer.Name)
		return false
	end

	-- 중복 확인
	local existingTool = backpack:FindFirstChild("SlapBattle")
	if existingTool then
		print("⚠️ 플레이어가 이미 SlapBattle을 가지고 있습니다:", targetPlayer.Name)
		return true
	end

	-- SlapBattle 클론해서 지급
	local clonedTool = slapBattleTool:Clone()
	clonedTool.Parent = backpack

	print("🥊 SlapBattle 지급 완료:", executorName, "→", targetPlayer.Name)
	return true
end

local function giveSlapBattleToAllInServer(senderName)
	local successCount = 0
	local failCount = 0

	for _, player in pairs(Players:GetPlayers()) do
		if giveSlapBattle(player, senderName) then
			successCount = successCount + 1
		else
			failCount = failCount + 1
		end

		-- 플레이어에게 알림
		local message = string.format("Received SlapBattle from developer %s", senderName)
		announceRemote:FireClient(player, message, "SYSTEM")
	end

	print("🥊 서버 SlapBattle 지급 완료:", senderName, "→ 성공:", successCount, "실패:", failCount)
end

-- 🎣 DevRod 관련 함수들
local function giveDevRod(targetPlayer, executorName)
	local devRodTool = ServerStorage:FindFirstChild("DevRod")

	if not devRodTool then
		warn("❌ DevRod 도구를 ServerStorage에서 찾을 수 없습니다!")
		return false
	end

	local backpack = targetPlayer:FindFirstChild("Backpack")
	if not backpack then
		warn("❌ 플레이어 백팩을 찾을 수 없습니다:", targetPlayer.Name)
		return false
	end

	-- 중복 확인
	local existingTool = backpack:FindFirstChild("DevRod")
	if existingTool then
		print("⚠️ 플레이어가 이미 DevRod를 가지고 있습니다:", targetPlayer.Name)
		return true
	end

	-- DevRod 클론해서 지급
	local clonedTool = devRodTool:Clone()
	clonedTool.Parent = backpack

	print("🎣 DevRod 지급 완료:", executorName, "→", targetPlayer.Name)
	return true
end

local function giveDevRodToAllInServer(senderName)
	local successCount = 0
	local failCount = 0

	for _, player in pairs(Players:GetPlayers()) do
		if giveDevRod(player, senderName) then
			successCount = successCount + 1
		else
			failCount = failCount + 1
		end

		-- 플레이어에게 알림
		local message = string.format("Received DevRod from developer %s", senderName)
		announceRemote:FireClient(player, message, "SYSTEM")
	end

	print("🎣 서버 DevRod 지급 완료:", senderName, "→ 성공:", successCount, "실패:", failCount)
end

-- 💰 코인 관련 함수들
local function giveCoinsToAllInServer(amount, senderName)
	local playersAffected = 0

	for _, player in pairs(Players:GetPlayers()) do
		local stats = player:FindFirstChild("leaderstats")
		if stats and stats:FindFirstChild("Coins") then
			stats.Coins.Value = stats.Coins.Value + amount
			playersAffected = playersAffected + 1

			local message = string.format("Received %s coins from developer %s", amount, senderName)
			announceRemote:FireClient(player, message, "SYSTEM")
		end
	end

	print("💰 서버 코인 지급 완료:", amount, "코인 →", playersAffected, "명의 플레이어")
end

local function sendAnnounceToServer(message, senderName, senderRank)
	for _, player in pairs(Players:GetPlayers()) do
		announceRemote:FireClient(player, message, senderName, senderRank)
	end
	print("📢 서버 공지 전송 완료:", message)
end

-- 🌐 MessagingService 구독
MessagingService:SubscribeAsync("GlobalAnnouncement", function(data)
	local messageData = data.Data
	print("📢 전체 서버 공지 수신:", messageData.message)
	sendAnnounceToServer(messageData.message, messageData.senderName, messageData.senderRank)
end)

MessagingService:SubscribeAsync("GlobalCoinGive", function(data)
	local coinData = data.Data
	print("💰 전체 서버 코인 지급 수신:", coinData.amount, "코인")
	giveCoinsToAllInServer(coinData.amount, coinData.senderName)
end)

MessagingService:SubscribeAsync("GlobalSlapBattleGive", function(data)
	local slapData = data.Data
	print("🥊 전체 서버 SlapBattle 지급 수신:", slapData.senderName)
	giveSlapBattleToAllInServer(slapData.senderName)
end)

MessagingService:SubscribeAsync("GlobalDevRodGive", function(data)
	local devRodData = data.Data
	print("🎣 전체 서버 DevRod 지급 수신:", devRodData.senderName)
	giveDevRodToAllInServer(devRodData.senderName)
end)

-- 🎮 명령어 처리
local function command(plr, chat)
	if not chat:find(Prefix) then return end

	-- ✅ :speed
	if chat:sub(1, 6) == Prefix.."speed" then
		if hasPermission(plr.Name, "speed") then
			local args = string.split(chat, " ")
			local targetName = args[2]
			local speed = tonumber(args[3]) or 16

			if not targetName then return end

			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				if v.Character and v.Character:FindFirstChild("Humanoid") then
					v.Character.Humanoid.WalkSpeed = speed
					print("🏃 Speed 변경:", plr.Name, "→", v.Name, "속도:", speed)
				end
			end
		end
	end

	-- ✅ :ang
	if chat:sub(1, 4) == Prefix.."ang" then
		if hasPermission(plr.Name, "ang") then
			local args = string.split(chat, " ")
			local targetName = args[2]

			if not targetName then return end

			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				if v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
					local explosion = Instance.new("Explosion")
					explosion.Position = v.Character.HumanoidRootPart.Position
					explosion.BlastRadius = 50
					explosion.BlastPressure = 1000000
					explosion.Parent = workspace
					print("💥 Ang 실행:", plr.Name, "→", v.Name)
				end
			end
		end
	end

	-- ✅ :kick
	if chat:sub(1, 5) == Prefix.."kick" then
		if hasPermission(plr.Name, "kick") then
			local args = string.split(chat, " ")
			local targetName = args[2]
			local reason = table.concat(args, " ", 3) or "No reason provided"

			if not targetName or targetName:lower() == "all" then return end

			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				v:Kick("You have been kicked by " .. plr.Name .. ". Reason: " .. reason)
				print("👢 Kick 실행:", plr.Name, "→", v.Name, "사유:", reason)
			end
		end
	end

	-- ✅ :setcoins
	if chat:sub(1, 9) == Prefix.."setcoins" then
		if hasPermission(plr.Name, "setcoins") then
			local args = string.split(chat, " ")
			local targetName = args[2]
			local amount = tonumber(args[3])

			if not targetName or not amount then return end

			local foundPlayers = findPlayers(plr, targetName)
			for _, v in pairs(foundPlayers) do
				local stats = v:FindFirstChild("leaderstats")
				if stats and stats:FindFirstChild("Coins") then
					stats.Coins.Value = amount
					print("💼 SetCoins 실행:", plr.Name, "→", v.Name, "금액:", amount)
				end
			end
		end
	end

	-- ✅ :announce
	if chat:sub(1, 9) == Prefix.."announce" then
		if hasPermission(plr.Name, "announce") then
			local message = chat:sub(11)

			if message and message:len() > 0 then
				local success, errorMessage = pcall(function()
					MessagingService:PublishAsync("GlobalAnnouncement", {
						message = message,
						senderName = plr.Name,
						senderRank = getPlayerRank(plr.Name),
						timestamp = os.time()
					})
				end)

				if success then
					print("📢 전체 서버 공지 발송 완료:", plr.Name, "→", message)
				else
					warn("📢 MessagingService 오류:", errorMessage)
				end
			end
		end
	end

	-- ✅ :GlobalGiveCoins
	if chat:find("^"..Prefix.."GlobalGiveCoins") then
		if hasPermission(plr.Name, "GlobalGiveCoins") then
			local args = string.split(chat, " ")
			local amount = tonumber(args[2])

			if not amount or amount <= 0 then return end

			local success, errorMessage = pcall(function()
				MessagingService:PublishAsync("GlobalCoinGive", {
					amount = amount,
					senderName = plr.Name,
					senderRank = getPlayerRank(plr.Name),
					timestamp = os.time()
				})
			end)

			if success then
				print("💰 전체 서버 코인 지급 명령 발송 완료:", plr.Name, "→", amount, "코인")
			else
				warn("💰 MessagingService 오류:", errorMessage)
			end
		end
	end

	-- ✅ :SlapBattleAll
	if chat:sub(1, 14) == Prefix.."SlapBattleAll" then
		if hasPermission(plr.Name, "SlapBattleAll") then
			print("🥊 SlapBattleAll 명령어 실행:", plr.Name)

			local success, errorMessage = pcall(function()
				MessagingService:PublishAsync("GlobalSlapBattleGive", {
					senderName = plr.Name,
					senderRank = getPlayerRank(plr.Name),
					timestamp = os.time()
				})
			end)

			if success then
				print("🥊 전체 서버 SlapBattle 지급 명령 발송 완료:", plr.Name)
			else
				warn("🥊 MessagingService 오류:", errorMessage)
				-- 실패시 현재 서버에만 지급
				giveSlapBattleToAllInServer(plr.Name)
			end
		end
	end

	-- ✅ :SlapBattle
	if chat:sub(1, 11) == Prefix.."SlapBattle" and not chat:find("SlapBattleAll") then
		if hasPermission(plr.Name, "SlapBattle") then
			local args = string.split(chat, " ")
			local targetName = args[2]

			if not targetName then return end

			local foundPlayers = findPlayers(plr, targetName)
			local successCount = 0
			local failCount = 0

			for _, v in pairs(foundPlayers) do
				if giveSlapBattle(v, plr.Name) then
					successCount = successCount + 1
				else
					failCount = failCount + 1
				end
			end

			print("🥊 SlapBattle 지급 결과:", plr.Name, "→ 성공:", successCount, "실패:", failCount)
		end
	end

	-- ✅ :DevRodAll
	if chat:sub(1, 10) == Prefix.."DevRodAll" then
		if hasPermission(plr.Name, "DevRodAll") then
			print("🎣 DevRodAll 명령어 실행:", plr.Name)

			local success, errorMessage = pcall(function()
				MessagingService:PublishAsync("GlobalDevRodGive", {
					senderName = plr.Name,
					senderRank = getPlayerRank(plr.Name),
					timestamp = os.time()
				})
			end)

			if success then
				print("🎣 전체 서버 DevRod 지급 명령 발송 완료:", plr.Name)
			else
				warn("🎣 MessagingService 오류:", errorMessage)
				-- 실패시 현재 서버에만 지급
				giveDevRodToAllInServer(plr.Name)
			end
		end
	end

	-- ✅ :DevRod
	if chat:sub(1, 7) == Prefix.."DevRod" and not chat:find("DevRodAll") then
		if hasPermission(plr.Name, "DevRod") then
			local args = string.split(chat, " ")
			local targetName = args[2]

			if not targetName then return end

			local foundPlayers = findPlayers(plr, targetName)
			local successCount = 0
			local failCount = 0

			for _, v in pairs(foundPlayers) do
				if giveDevRod(v, plr.Name) then
					successCount = successCount + 1
				else
					failCount = failCount + 1
				end
			end

			print("🎣 DevRod 지급 결과:", plr.Name, "→ 성공:", successCount, "실패:", failCount)
		end
	end
end

-- 🔌 플레이어 이벤트 연결
Players.PlayerAdded:Connect(function(plr)
	local rank = getPlayerRank(plr.Name)
	if rank then
		print("✅ Admin joined: " .. plr.Name .. " (" .. rank .. ")")
		plr.Chatted:Connect(function(msg)
			command(plr, msg)
		end)
	end
end)

print("✅ Clean Admin System with DevRod initialized")
