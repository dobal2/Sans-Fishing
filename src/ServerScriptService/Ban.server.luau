local ADMINS = {1853104124} -- UserId로 구성된 관리자 리스트

local DataStoreService = game:GetService("DataStoreService")
local banStore = DataStoreService:GetDataStore("TestBannedUsers")

-- 플레이어 영구 밴
local function banPlayer(player)
	player:Kick("You've been banned!")
	banStore:SetAsync(player.UserId, true)
end

-- 플레이어 밴 해제
local function unbanPlayer(id)
	banStore:SetAsync(tonumber(id), false)
end

-- 플레이어 접속 시 밴 여부 확인
game.Players.PlayerAdded:Connect(function(player)
	local banData = banStore:GetAsync(player.UserId)
	if banData then
		player:Kick("You've been banned by creator")
	end

	-- 관리자 명령 처리
	player.Chatted:Connect(function(msg)
		if not table.find(ADMINS, player.UserId) then return end

		local splitMsg = string.split(msg, " ")
		local command = string.lower(splitMsg[1])

		if command == ":ban" then
			local username = splitMsg[2]
			local playerBanned = game.Players:FindFirstChild(username)
			if playerBanned then
				banPlayer(playerBanned)
			end

		elseif command == ":unban" then
			local id = splitMsg[2]
			unbanPlayer(id)
		end
	end)
end)
