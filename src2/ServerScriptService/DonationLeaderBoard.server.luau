local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(ServerScriptService.leaderstats.DataManager)
local donationRefreshEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("DonationRefresh")

local excludedUsernames = {}
local nameCache = {}

local function getNameFromUserId(userId)
	if nameCache[userId] then return nameCache[userId] end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = ok and result or ("User_" .. userId)
	nameCache[userId] = name
	return name
end

local cachedList = {}
local listReady = false

local function buildDonationList()
	local raw = DataManager:GetTopDonationPlayers(100)
	if #raw == 0 then return {} end

	-- 이름 병렬 조회
	local threads = {}
	for _, entry in ipairs(raw) do
		if not nameCache[entry.UserId] then
			threads[#threads + 1] = task.spawn(getNameFromUserId, entry.UserId)
		end
	end
	-- 모든 스레드 완료 대기
	for _, t in ipairs(threads) do
		task.wait()
	end

	local result = {}
	for _, entry in ipairs(raw) do
		if (entry.Donations or 0) > 0 then
			local name = getNameFromUserId(entry.UserId)
			local lname = string.lower(name)
			if not excludedUsernames[lname] then
				result[#result + 1] = {
					userId    = entry.UserId,
					name      = name,
					donations = entry.Donations,
					rank      = #result + 1,
				}
				if #result >= 100 then break end
			end
		end
	end
	return result
end

local function sendToPlayer(player)
	-- 최초 로드 완료될 때까지 대기 (최대 15초)
	local waited = 0
	while not listReady and waited < 15 do
		task.wait(1)
		waited += 1
	end

	local myData = nil
	for _, entry in ipairs(cachedList) do
		if entry.userId == player.UserId then
			myData = entry
			break
		end
	end
	if not myData then
		local profile = DataManager:GetData(player)
		local donations = profile and profile.Donations or 0
		myData = {
			userId    = player.UserId,
			name      = player.Name,
			donations = donations,
			rank      = nil,
		}
	end
	donationRefreshEvent:FireClient(player, cachedList, myData)
end

local function refreshAll()
	local newList = buildDonationList()
	cachedList = newList
	listReady = true
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(sendToPlayer, player)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.wait(3)
	task.spawn(sendToPlayer, player)
end)

donationRefreshEvent.OnServerEvent:Connect(function(player)
	task.spawn(sendToPlayer, player)
end)

-- ProcessReceipt에서 도네이션 구매 시 즉시 갱신 신호 수신
local donationForceRefresh = ReplicatedStorage:WaitForChild("DonationForceRefresh", 10)
if donationForceRefresh then
	donationForceRefresh.Event:Connect(function(player)
		local newList = buildDonationList()
		cachedList = newList
		listReady = true
		for _, p in ipairs(Players:GetPlayers()) do
			task.spawn(sendToPlayer, p)
		end
	end)
end

-- 최초 빌드
task.spawn(function()
	refreshAll()
	while task.wait(30) do
		refreshAll()
	end
end)
