local Players = game:GetService("Players")
local ProfileService = require(script.ProfileService)
local RunService = game:GetService("RunService")

local DATA_TEMPLATE = { -- Data template
	items = {};
}

--local ENV = RunService:IsStudio() and "TestData" or "AlphaData"
local ProfileStore = ProfileService.GetProfileStore("AlphaData3", DATA_TEMPLATE)

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

-- Update data; saved to current session only; call SaveData() to persist to DataStore
function DataManager:UpdateData(player, key, data)
	local profile = Profiles[player]

	if key == "" then -- Can prevent certain keys from going below a value
		if profile.Data[key] and profile.Data[key] > data then
			return
		end
	end

	profile.Data[key] = data
end

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
