local Players = game:GetService("Players")
local ProfileService = require(script.Parent.Parent.ProfileService)
local RunService = game:GetService("RunService")

local DATA_TEMPLATE = {
	items = {};
	hotbarSlots = {};
}

local ProfileStore = ProfileService.New("AlphaData3", DATA_TEMPLATE)
local Profiles = {}

local function OnPlayerAdded(player)
	local profile = ProfileStore:StartSessionAsync("Player_" .. player.UserId, {Steal = true})

	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			player:Kick()
		end)

		if player:IsDescendantOf(Players) then
			Profiles[player] = profile
		else
			profile:EndSession()
		end
	else
		player:Kick("Data loading failed, Please try again")
	end
end
Players.PlayerAdded:Connect(OnPlayerAdded)

local function OnPlayerRemoving(player)
	local profile = Profiles[player]
	if profile and profile:IsActive() then
		profile:EndSession()
	end
end
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-----------------------Module-------------------------

local DataManager = {}

function DataManager:GetData(player)
	local profile = Profiles[player]
	return profile and profile.Data or nil
end

function DataManager:GetProfileStore()
	return ProfileStore
end

function DataManager:UpdateData(player, key, data)
	local profile = Profiles[player]
	if not profile then return end
	profile.Data[key] = data
end

local function sanitizeString(s)
	if type(s) ~= "string" then return tostring(s) end
	-- Replace invalid UTF-8 sequences with "?"
	return (s:gsub("[\x80-\xFF][\x80-\xBF]*", function(seq)
		-- Valid UTF-8 multi-byte check
		local b1 = seq:byte(1)
		if b1 >= 0xC2 and b1 <= 0xDF and #seq == 2 then return seq end
		if b1 >= 0xE0 and b1 <= 0xEF and #seq == 3 then return seq end
		if b1 >= 0xF0 and b1 <= 0xF4 and #seq == 4 then return seq end
		return "?"
	end))
end

local function sanitizeData(data)
	if type(data) == "string" then
		return sanitizeString(data)
	elseif type(data) == "table" then
		local clean = {}
		for k, v in pairs(data) do
			clean[k] = sanitizeData(v)
		end
		return clean
	end
	return data
end

function DataManager:SaveData(player)
	local profile = Profiles[player]
	if profile and profile:IsActive() then
		if profile.Data.items then
			profile.Data.items = sanitizeData(profile.Data.items)
		end
		profile:Save()
	end
end

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
