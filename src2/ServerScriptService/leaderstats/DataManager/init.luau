local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local CoinLeaderboard = DataStoreService:GetOrderedDataStore("CoinLeaderboard")
local DonationLeaderboard = DataStoreService:GetOrderedDataStore("DonationLeaderboard")
local PlaytimeLeaderboard = DataStoreService:GetOrderedDataStore("PlaytimeLeaderBoard")
local ProfileService = require(script.Parent.Parent.ProfileService)

local DATA_TEMPLATE = {
	Coins = 2000;
	Donations = 0;
	CurrentRod = "FishingRod";
	CurrentFishTrap = "";
	IsTutorialed = false;
	SeenUpdateLog = false;
	LastSeenUpdateVersion = 0;
	Playtime = 0;
	DiscoveryClaimed = {};
	VariantDiscoveryClaimed = {};
	Fish = {};
	FishVariant = {};
	SkillPoints = 0;
	Skills = {};
	AutoFishingOn = false;
	Bubbles = {};
	TotalCatches = 0;
	FishStreak = 0;
	OwnedBobbers = {"Basic Bobber"};
	EquippedBobber = "Basic Bobber";
	InviteCount = 0;
	InviteRodGranted = false;
}

local sessionStartTimes = {}
local ProfileStore = ProfileService.New("StoreName", DATA_TEMPLATE)
local Profiles = {}

local function OnPlayerAdded(player)
	local profile
	for attempt = 1, 3 do
		profile = ProfileStore:StartSessionAsync("Player_" .. player.UserId, {Steal = true})
		if profile then break end
		if not player:IsDescendantOf(Players) then return end
		task.wait(3)
	end

	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			player:Kick()
		end)

		if player:IsDescendantOf(Players) then
			Profiles[player] = profile

			local userId = tostring(player.UserId)
			local coins = profile.Data.Coins or 0
			pcall(function() CoinLeaderboard:SetAsync(userId, coins) end)

			local playtime = profile.Data.Playtime or 0
			sessionStartTimes[player.UserId] = tick()
			pcall(function() PlaytimeLeaderboard:SetAsync(userId, playtime) end)
		else
			profile:EndSession()
		end
	else
		player:Kick("Data loading failed, Please try again")
	end
end
Players.PlayerAdded:Connect(OnPlayerAdded)

-- Playtime update + EndSession handled by SafeSavePlayer (called from leaderstats/init.server.luau)

-----------------------Module-------------------------

local DataManager = {}

function DataManager:GetData(player)
	local profile = Profiles[player]
	return profile and profile.Data or nil
end

function DataManager:GetProfileStore()
	return ProfileStore
end

game:GetService("ReplicatedStorage").ChildAdded:Connect(function(child)
	if child.Name:find("DeleteTrapData_") and child:IsA("StringValue") then
		local parts = string.split(child.Name, "_")
		if #parts >= 3 then
			local ownerName = parts[2]
			local trapId = parts[3]

			local player = Players:FindFirstChild(ownerName)
			if player then
				local profile = Profiles[player]
				if profile then
					profile.Data["FishTrapData_" .. ownerName .. "_" .. trapId] = nil
				end
			else
				local success, userId = pcall(function()
					return Players:GetUserIdFromNameAsync(ownerName)
				end)
				if success then
					local offlineProfile = ProfileStore:GetAsync("Player_" .. userId)
					if offlineProfile then
						offlineProfile.Data["FishTrapData_" .. ownerName .. "_" .. trapId] = nil
						offlineProfile:SetAsync()
					end
				end
			end
		end
	end
end)

function DataManager:UpdateData(player, key, data)
	local profile = Profiles[player]

	if not profile then
		-- Don't start a new session for a player who has already left
		if not player:IsDescendantOf(Players) then
			warn("UpdateData skipped: player has left", player.Name, key)
			return
		end
		profile = ProfileStore:StartSessionAsync("Player_" .. player.UserId, {Steal = true})
		if profile then
			profile:Reconcile()
			Profiles[player] = profile
		else
			warn("UpdateData failed: profile load failed", player, key)
			return
		end
	end

	profile.Data[key] = data

	if key == "Coins" then
		local userId = tostring(player.UserId)
		pcall(function() CoinLeaderboard:SetAsync(userId, data) end)
	elseif key == "Donations" then
		local userId = tostring(player.UserId)
		pcall(function() DonationLeaderboard:SetAsync(userId, data) end)
	end
end

function DataManager:GetTopDonationPlayers(limit)
	local top = {}
	limit = limit or 10
	local success, pages = pcall(function()
		return DonationLeaderboard:GetSortedAsync(false, limit)
	end)
	if not success then return {} end
	for i, entry in ipairs(pages:GetCurrentPage()) do
		table.insert(top, {UserId = tonumber(entry.key), Donations = entry.value, Rank = i})
	end
	return top
end

function DataManager:GetTopCoinPlayers(limit)
	local top = {}
	limit = math.min(limit or 10, 100)
	local success, pages = pcall(function()
		return CoinLeaderboard:GetSortedAsync(false, limit)
	end)
	if not success then return {} end
	for i, entry in ipairs(pages:GetCurrentPage()) do
		table.insert(top, {UserId = tonumber(entry.key), Coins = entry.value, Rank = i})
	end
	return top
end

function DataManager:GetCurrentPlaytime(player)
	local profile = Profiles[player]
	if not profile then return 0 end
	local basePlaytime = profile.Data.Playtime or 0
	local sessionStart = sessionStartTimes[player.UserId]
	if sessionStart then
		return basePlaytime + math.floor(tick() - sessionStart)
	end
	return basePlaytime
end

function DataManager:GetTopPlaytimePlayers(limit)
	local top = {}
	limit = limit or 10
	local success, pages = pcall(function()
		return PlaytimeLeaderboard:GetSortedAsync(false, limit)
	end)
	if not success then return {} end
	for i, entry in ipairs(pages:GetCurrentPage()) do
		table.insert(top, {UserId = tonumber(entry.key), Playtime = entry.value, Rank = i})
	end
	return top
end

function DataManager:UpdatePlaytime(player)
	local profile = Profiles[player]
	local sessionStart = sessionStartTimes[player.UserId]
	if not profile or not sessionStart then return 0 end

	local sessionTime = math.floor(tick() - sessionStart)
	local totalPlaytime = (profile.Data.Playtime or 0) + sessionTime
	profile.Data.Playtime = totalPlaytime

	local userId = tostring(player.UserId)
	pcall(function() PlaytimeLeaderboard:SetAsync(userId, totalPlaytime) end)

	sessionStartTimes[player.UserId] = tick()
	return totalPlaytime
end

function DataManager:SafeSavePlayer(player)
	local profile = Profiles[player]
	if not profile then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		if profile:IsActive() then profile:EndSession() end
		return
	end

	local coins       = leaderstats:FindFirstChild("Coins")
	local currentRod  = leaderstats:FindFirstChild("CurrentRod")
	local rodsFolder  = leaderstats:FindFirstChild("Rods")
	local FishFolder  = leaderstats:FindFirstChild("Fish")
	local boatFolder  = leaderstats:FindFirstChild("Boats")
	local fishTrapFolder = leaderstats:FindFirstChild("FishTraps")
	local isTutorialed   = player:FindFirstChild("IsTutorialed")

	local currentFishTrap = leaderstats:FindFirstChild("CurrentFishTrap")
	if currentFishTrap and currentFishTrap:FindFirstChild("Value") then
		profile.Data.CurrentFishTrap = currentFishTrap.Value.Value
	end

	if coins then
		profile.Data.Coins = coins.Value
		local userId = tostring(player.UserId)
		pcall(function() CoinLeaderboard:SetAsync(userId, coins.Value) end)
	end
	if currentRod    then profile.Data.CurrentRod    = currentRod.Value end
	if isTutorialed  then profile.Data.IsTutorialed  = isTutorialed.Value end
	local seenUpdateLog = player:FindFirstChild("SeenUpdateLog")
	if seenUpdateLog then profile.Data.SeenUpdateLog = seenUpdateLog.Value end

	local skillPoints = player:FindFirstChild("SkillPoints")
	if skillPoints then profile.Data.SkillPoints = skillPoints.Value end

	local skillsFolder = player:FindFirstChild("Skills")
	if skillsFolder then
		local skillsData = {}
		for _, sv in ipairs(skillsFolder:GetChildren()) do
			if sv:IsA("IntValue") then
				skillsData[sv.Name] = sv.Value
			end
		end
		profile.Data.Skills = skillsData
	end

	local rodsData = {}
	if rodsFolder then
		for _, rod in ipairs(rodsFolder:GetChildren()) do
			if rod:IsA("BoolValue") then rodsData[rod.Name] = rod.Value end
		end
	end
	profile.Data.Rods = rodsData

	local fishData = {}
	if FishFolder then
		for _, fish in ipairs(FishFolder:GetChildren()) do
			if fish:IsA("BoolValue") then fishData[fish.Name] = fish.Value end
		end
	end
	profile.Data.Fish = fishData

	local fishVariantFolder = leaderstats:FindFirstChild("FishVariant")
	local fishVariantData = {}
	if fishVariantFolder then
		for _, vBool in ipairs(fishVariantFolder:GetChildren()) do
			if vBool:IsA("BoolValue") then fishVariantData[vBool.Name] = vBool.Value end
		end
	end
	profile.Data.FishVariant = fishVariantData

	local boatsData = {}
	if boatFolder then
		for _, boat in ipairs(boatFolder:GetChildren()) do
			if boat:IsA("BoolValue") then boatsData[boat.Name] = boat.Value end
		end
	end
	profile.Data.Boats = boatsData

	local fishTrapsData = {}
	if fishTrapFolder then
		for _, fishTrap in ipairs(fishTrapFolder:GetChildren()) do
			if fishTrap:IsA("BoolValue") then fishTrapsData[fishTrap.Name] = fishTrap.Value end
		end
	end
	profile.Data.FishTraps = fishTrapsData

	-- Update playtime
	local sessionStart = sessionStartTimes[player.UserId]
	if sessionStart then
		local sessionTime = math.floor(tick() - sessionStart)
		profile.Data.Playtime = (profile.Data.Playtime or 0) + sessionTime
		sessionStartTimes[player.UserId] = tick()
	end

	if profile:IsActive() then
		profile:EndSession()
	end
end

function DataManager:SaveData(player)
	local profile = Profiles[player]
	if not profile or not profile:IsActive() then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local fishFolder = leaderstats:FindFirstChild("Fish")
		if fishFolder then
			local fishData = {}
			for _, v in ipairs(fishFolder:GetChildren()) do
				if v:IsA("BoolValue") then fishData[v.Name] = v.Value end
			end
			profile.Data.Fish = fishData
		end

		local variantFolder = leaderstats:FindFirstChild("FishVariant")
		if variantFolder then
			local variantData = {}
			for _, v in ipairs(variantFolder:GetChildren()) do
				if v:IsA("BoolValue") then variantData[v.Name] = v.Value end
			end
			profile.Data.FishVariant = variantData
		end
	end

	profile:Save()
end

local RunService = game:GetService("RunService")
function DataManager:ClearData(player)
	if RunService:IsStudio() and RunService:IsServer() then
		local profile = Profiles[player]
		if profile then
			profile.Data = DATA_TEMPLATE
			player:Kick("Data Cleared")
		end
	end
end

return DataManager
