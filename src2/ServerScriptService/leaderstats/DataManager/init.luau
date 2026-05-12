local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local CoinLeaderboard = DataStoreService:GetOrderedDataStore("CoinLeaderboard")
local DonationLeaderboard = DataStoreService:GetOrderedDataStore("DonationLeaderboard")
local PlaytimeLeaderboard = DataStoreService:GetOrderedDataStore("PlaytimeLeaderBoard")
local ProfileService = require(script.ProfileService)

-- Default data applied to new or reconciled profiles
local DATA_TEMPLATE = {
	Coins = 2000;
	Donations = 0;
	CurrentRod = "FishingRod";
	CurrentFishTrap = "";
	IsTutorialed = false;
	Playtime = 0;
}

local sessionStartTimes = {}

local ProfileStore = ProfileService.GetProfileStore("StoreName", DATA_TEMPLATE)

local Profiles = {}

local function HandleLockedUpdate(globalUpdates, update)
	local id = update[1] -- update[1] is the data ID
	local data = update[2] -- update[2] is the data content

	globalUpdates:ClearLockedUpdate(id)
end



-- Called when a player joins
local function OnPlayerAdded(player)

	-- Load player profile data
	local profile = ProfileStore:LoadProfileAsync(
		-- Key value
		"Player_"..player.UserId,

		-- How to handle a profile locked by another server:
		-- "ForceLoad" immediately takes the profile (forces release on the other server)
		"ForceLoad"
	)
	-- If profile data exists
	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile() -- Auto-apply any new template fields
		-- Register release event handler (follows profile:Release() below)
		profile:ListenToRelease(function()
			Profiles[player] = nil -- Clean up Profiles table
			player:Kick() -- Guarantee player exit
		end)

		-- Cache data if player is in game (handle case where player left during loading)
		if player:IsDescendantOf(Players) then
			Profiles[player] = profile

			local userId = tostring(player.UserId)
			local coins = profile.Data.Coins or 0
			pcall(function()
				CoinLeaderboard:SetAsync(userId, coins)
			end)

			local playtime = profile.Data.Playtime or 0
			sessionStartTimes[player.UserId] = tick() -- Record session start time
			pcall(function()
				PlaytimeLeaderboard:SetAsync(userId, playtime)
			end)

			local globalUpdates = profile.GlobalUpdates

			for index, update in pairs(globalUpdates:GetActiveUpdates())do
				globalUpdates:LockActiveUpdate(update[1])
			end

			for index, update in pairs(globalUpdates:GetLockedUpdates())do
				HandleLockedUpdate(globalUpdates, update)
			end

			globalUpdates:ListenToNewActiveUpdate(function(id, data)
				globalUpdates:LockActiveUpdate(id)
			end)

			globalUpdates:ListenToNewLockedUpdate(function(id, data)
				HandleLockedUpdate(globalUpdates, {id, data})
			end)



		else
			profile:Release()
			-- Call release to clean up data table when player has left
			-- Continues to profile:ListenToRelease above
		end
	else
		player:Kick("Data loading failed, Please try again")
	end
end
Players.PlayerAdded:Connect(OnPlayerAdded)


local function OnPlayerRemoving(player)
	local profile = Profiles[player]
	if profile then
		local sessionStart = sessionStartTimes[player.UserId]
		if sessionStart then
			local sessionTime = math.floor(tick() - sessionStart)
			local totalPlaytime = (profile.Data.Playtime or 0) + sessionTime
			profile.Data.Playtime = totalPlaytime

			-- Update playtime leaderboard
			local userId = tostring(player.UserId)
			pcall(function()
				PlaytimeLeaderboard:SetAsync(userId, totalPlaytime)
			end)
		end
		profile:Save()
		profile:Release() -- Call release to clean up data table when player leaves
	end
end
Players.PlayerRemoving:Connect(OnPlayerRemoving)


-----------------------Module-------------------------

local DataManager = {}

-- Return player data
function DataManager:GetData(player)
	local profile = Profiles[player]

	if profile then
		return profile.Data
	else
		return nil
	end
end

function DataManager:GetProfileStore()
	return ProfileStore
end

-- Listen for offline trap-delete signals written to ReplicatedStorage
game:GetService("ReplicatedStorage").ChildAdded:Connect(function(child)
	if child.Name:find("DeleteTrapData_") and child:IsA("StringValue") then
		local parts = string.split(child.Name, "_")
		if #parts >= 3 then
			local ownerName = parts[2]
			local trapId = parts[3]


			local player = Players:FindFirstChild(ownerName)
			if player then
				-- Online player: delete directly from profile
				local profile = Profiles[player]
				if profile then
					profile.Data["FishTrapData_" .. ownerName .. "_" .. trapId] = nil
				end
			else
				-- Offline player: load profile and delete
				local success, userId = pcall(function()
					return Players:GetUserIdFromNameAsync(ownerName)
				end)

				if success then
					local offlineProfile = ProfileStore:LoadProfileAsync("Player_" .. userId, "ForceLoad")
					if offlineProfile then
						offlineProfile.Data["FishTrapData_" .. ownerName .. "_" .. trapId] = nil
						offlineProfile:Save()
						offlineProfile:Release()
					else
						warn("Failed to load offline player profile:", ownerName)
					end
				else
					warn("Failed to convert player name to UserId:", ownerName)
				end
			end
		end
	end
end)

-- Update data; saved to current session only; call SaveData() to persist to DataStore
function DataManager:UpdateData(player, key, data)
	local profile = Profiles[player]

	-- Force load profile if not available
	if not profile then
		profile = ProfileStore:LoadProfileAsync("Player_"..player.UserId, "ForceLoad")
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
		local success, err = pcall(function()
			CoinLeaderboard:SetAsync(userId, data)
		end)

		if not success then
			warn("[Leaderboard Save Failed] UserId:", userId, "Error:", err)
		end
	elseif key == "Donations" then
		local userId = tostring(player.UserId)
		local success, err = pcall(function()
			DonationLeaderboard:SetAsync(userId, data)
		end)
		if not success then
			warn("Donation Leaderboard Save Failed:", err)
		end
	end

end

function DataManager:GetTopDonationPlayers(limit)
	local top = {}
	limit = limit or 10

	local success, pages = pcall(function()
		return DonationLeaderboard:GetSortedAsync(false, limit)
	end)

	if not success then
		warn("DonationLeaderboard:GetSortedAsync failed")
		return {}
	end

	local data = pages:GetCurrentPage()
	for i, entry in ipairs(data) do
		local userId = tonumber(entry.key)
		local donations = entry.value
		table.insert(top, {
			UserId = userId,
			Donations = donations,
			Rank = i
		})
	end
	return top
end


-- Get top N coin players
function DataManager:GetTopCoinPlayers(limit)
	local top = {}
	limit = limit or 10 -- Default 10

	local success, pages = pcall(function()
		return CoinLeaderboard:GetSortedAsync(false, limit) -- false: descending
	end)

	if not success then
		warn("[Leaderboard] GetSortedAsync failed")
		return {}
	end

	local data = pages:GetCurrentPage()
	for i, entry in ipairs(data) do
		local userId = tonumber(entry.key)
		local coins = entry.value
		table.insert(top, {
			UserId = userId,
			Coins = coins,
			Rank = i,
		})
	end

	return top
end


function DataManager:GetCurrentPlaytime(player)
	local profile = Profiles[player]
	if not profile then return 0 end

	local basePlaytime = profile.Data.Playtime or 0
	local sessionStart = sessionStartTimes[player.UserId]

	if sessionStart then
		local sessionTime = math.floor(tick() - sessionStart)
		return basePlaytime + sessionTime
	else
		return basePlaytime
	end
end

-- Get top playtime players
function DataManager:GetTopPlaytimePlayers(limit)
	local top = {}
	limit = limit or 10

	local success, pages = pcall(function()
		return PlaytimeLeaderboard:GetSortedAsync(false, limit)
	end)

	if not success then
		warn("PlaytimeLeaderboard:GetSortedAsync failed")
		return {}
	end

	local data = pages:GetCurrentPage()
	for i, entry in ipairs(data) do
		local userId = tonumber(entry.key)
		local playtime = entry.value
		table.insert(top, {
			UserId = userId,
			Playtime = playtime,
			Rank = i
		})
	end
	return top
end

-- Manual playtime update (call every 5 minutes)
function DataManager:UpdatePlaytime(player)
	local profile = Profiles[player]
	local sessionStart = sessionStartTimes[player.UserId]

	if profile and sessionStart then
		local sessionTime = math.floor(tick() - sessionStart)
		local totalPlaytime = (profile.Data.Playtime or 0) + sessionTime
		profile.Data.Playtime = totalPlaytime

		-- Update leaderboard
		local userId = tostring(player.UserId)
		pcall(function()
			PlaytimeLeaderboard:SetAsync(userId, totalPlaytime)
		end)

		-- Reset session start time
		sessionStartTimes[player.UserId] = tick()

		return totalPlaytime
	end
	return 0
end



function DataManager:SafeSavePlayer(player)
	local profile = Profiles[player]
	if not profile then
		warn("Save failed - no profile:", player)
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local isTutorialed = player:FindFirstChild("IsTutorialed")
	if not leaderstats then return end

	local coins = leaderstats:FindFirstChild("Coins")
	local currentRod = leaderstats:FindFirstChild("CurrentRod")
	local rodsFolder = leaderstats:FindFirstChild("Rods")
	local FishFolder = leaderstats:FindFirstChild("Fish")
	local boatFolder = leaderstats:FindFirstChild("Boats")

	-- Add below existing boatFolder section in SafeSavePlayer
	local fishTrapFolder = leaderstats:FindFirstChild("FishTraps")

	local currentFishTrap = leaderstats:FindFirstChild("CurrentFishTrap")
	if currentFishTrap and currentFishTrap:FindFirstChild("Value") then
		profile.Data.CurrentFishTrap = currentFishTrap.Value.Value
	end

	-- Add below existing BoatsData save section
	local FishTrapsData = {}
	if fishTrapFolder then
		for _, fishTrap in ipairs(fishTrapFolder:GetChildren()) do
			if fishTrap:IsA("BoolValue") then
				FishTrapsData[fishTrap.Name] = fishTrap.Value
			end
		end
	end
	profile.Data.FishTraps = FishTrapsData

	if coins then
		profile.Data.Coins = coins.Value

		-- Also update leaderboard
		local userId = tostring(player.UserId)
		local success, err = pcall(function()
			CoinLeaderboard:SetAsync(userId, coins.Value)
		end)
		if not success then
			warn("[Leaderboard Save Failed] UserId:", userId, "Error:", err)
		end
	end

	if currentRod then
		profile.Data.CurrentRod = currentRod.Value
	end

	if isTutorialed then
		profile.Data.IsTutorialed = isTutorialed.Value
	end

	local rodsData = {}
	if rodsFolder then
		for _, rod in ipairs(rodsFolder:GetChildren()) do
			if rod:IsA("BoolValue") then
				rodsData[rod.Name] = rod.Value
			end
		end
	end
	profile.Data.Rods = rodsData

	local FishData = {}
	if FishFolder then
		for _, fish in ipairs(FishFolder:GetChildren()) do
			if fish:IsA("BoolValue") then
				FishData[fish.Name] = fish.Value
			end
		end
	end
	profile.Data.Fish = FishData

	local BoatsData = {}
	if boatFolder then
		for _, boat in ipairs(boatFolder:GetChildren()) do
			if boat:IsA("BoolValue") then
				BoatsData[boat.Name] = boat.Value
			end
		end
	end
	profile.Data.Boats = BoatsData


	local success, err = pcall(function()
		profile:Save()
	end)
	if not success then
		warn("Save failed:", player.Name, err)
	end

	profile:Release()
end



-- Save to DataStore; for safety call right after UpdateData
-- For optimization, call only every 5 minutes (saves automatically on leave)
function DataManager:SaveData(player)
	Profiles[player]:Save()
end


---------------- Clear specific player data ------------------
local RunService = game:GetService("RunService")
function DataManager:ClearData(player)
	if RunService:IsStudio() and RunService:IsServer() then -- Studio only, server-side only
		local profile = Profiles[player] or ProfileStore:LoadProfileAsync(
			"Player_"..player.UserId,
			"ForceLoad"
		)
		profile["Data"] = DATA_TEMPLATE -- Reset to default template
		player:Kick("Data Cleared")
	end
end


return DataManager
