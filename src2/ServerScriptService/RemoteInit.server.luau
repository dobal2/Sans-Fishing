-- Ensures all RemoteEvents/BindableEvents exist in the correct Remotes folder structure.
-- Runs first so all other scripts can WaitForChild without infinite yield.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function ensureRemote(parent, name, className)
	if not parent:FindFirstChild(name) then
		local r = Instance.new(className or "RemoteEvent")
		r.Name = name
		r.Parent = parent
	end
end

local Remotes = ensureFolder(ReplicatedStorage, "Remotes")

-- Fishing
local Fishing = ensureFolder(Remotes, "Fishing")
ensureRemote(Fishing, "SetFavoriteRemote")
ensureRemote(Fishing, "ShowBeamEvent")
ensureRemote(Fishing, "BaitLandedEvent")
ensureRemote(Fishing, "BaitSplashEvent")
ensureRemote(Fishing, "RandomFishResult")
ensureRemote(Fishing, "FishDiscoverReward")
ensureRemote(Fishing, "GetDiscoveryClaimed", "RemoteFunction")
ensureRemote(Fishing, "TriggerRandomFish", "BindableEvent")
ensureRemote(Fishing, "StreakUpdateEvent")
ensureRemote(Fishing, "StreakEndBroadcast")
ensureRemote(Fishing, "RecoverEvent")

-- Shop
local Shop = ensureFolder(Remotes, "Shop")
ensureRemote(Shop, "BuyFishingRod")
ensureRemote(Shop, "OpenShop")
ensureRemote(Shop, "OpenBoatShop")
ensureRemote(Shop, "OpenRobuxShop")
ensureRemote(Shop, "BuyBoat")
ensureRemote(Shop, "SpawnBoat")
ensureRemote(Shop, "ShopSellerDialog")
ensureRemote(Shop, "OpenGearShop")
ensureRemote(Shop, "codeEvent")
ensureRemote(Shop, "OpenShopLocal", "BindableEvent")
ensureRemote(Shop, "OpenRobuxShopLocal", "BindableEvent")
ensureRemote(Shop, "BuyFishTrapBindable", "BindableEvent")
ensureRemote(Shop, "BuyBubbleBindable", "BindableEvent")

-- Sell
local Sell = ensureFolder(Remotes, "Sell")
ensureRemote(Sell, "SellChoiceEvent")
ensureRemote(Sell, "SellGuiEvent")
ensureRemote(Sell, "SetPromptEvent")
ensureRemote(Sell, "SoldNotification")
ensureRemote(Sell, "TalkEvent")
ensureRemote(Sell, "GambleChoiceEvent")
ensureRemote(Sell, "GambleGuiEvent")
ensureRemote(Sell, "GambleNotification")

-- Notice
local Notice = ensureFolder(Remotes, "Notice")
ensureRemote(Notice, "ShowNoticeEvent")
ensureRemote(Notice, "FishNoticeEvent")
ensureRemote(Notice, "NoticeEventForClient", "BindableEvent")
ensureRemote(Notice, "TutorialEvent", "BindableEvent")
ensureRemote(Notice, "DiscoverNoticeEvent")

-- Quest
local Quest = ensureFolder(Remotes, "Quest")
ensureRemote(Quest, "QuestGuiEvent")
ensureRemote(Quest, "QuestReceiveEvent")
ensureRemote(Quest, "QuestCompleteEvent")
ensureRemote(Quest, "QuestNotification")
ensureRemote(Quest, "QuestChoiceEvent")
ensureRemote(Quest, "Quest Giver")

-- Weather
local Weather = ensureFolder(Remotes, "Weather")
ensureRemote(Weather, "WeatherChangedEvent")
ensureRemote(Weather, "FireworkEffectEvent")
ensureRemote(Weather, "GetWeatherState", "RemoteFunction")

-- Leaderboard (YourStats client update)
local Leaderboard = ensureFolder(Remotes, "Leaderboard")
ensureRemote(Leaderboard, "CoinYourStats")
ensureRemote(Leaderboard, "PlaytimeYourStats")

-- Invite
local Invite = ensureFolder(Remotes, "Invite")
ensureRemote(Invite, "InviteSent")          -- client → server: 초대장을 실제로 보냈을 때
ensureRemote(Invite, "InviteQuestProgress") -- server → client: 현재 진행도 알림

-- Misc
local Misc = ensureFolder(Remotes, "Misc")
ensureRemote(Misc, "EscapeTheWorld")
ensureRemote(Misc, "DonationRefresh")
ensureRemote(Misc, "ClaimDailyReward")
ensureRemote(Misc, "CheckDailyReward")
ensureRemote(Misc, "SaveHotBarLayout")
ensureRemote(Misc, "GetHotBarLayout", "RemoteFunction")
ensureRemote(Misc, "GetServerAge", "RemoteFunction")
ensureRemote(Misc, "SetSeenUpdateLog")
ensureRemote(Misc, "SetSeenUpdateVersion")
ensureRemote(Misc, "AutoReconnectRequest")
ensureRemote(Misc, "SaveAutoFishing")
ensureRemote(Misc, "GetAutoFishing", "RemoteFunction")
ensureRemote(Misc, "EquipFishRequest")
ensureRemote(Misc, "UnequipFishRequest")
ensureRemote(Misc, "GetInventoryData", "RemoteFunction")
ensureRemote(Misc, "FishDataAdded")
ensureRemote(Misc, "InventoryDataSync")
ensureRemote(Misc, "SaveFishHotBarPins")
ensureRemote(Misc, "GetFishHotBarPins", "RemoteFunction")
ensureRemote(Misc, "CollectFishTrapRemote")
ensureRemote(Misc, "PlaceFishTrapRemote")
ensureRemote(Misc, "RequestFeedbackPrompt")

local _serverStartClock = os.clock()
local _getServerAge = Misc:FindFirstChild("GetServerAge")
if _getServerAge then
	_getServerAge.OnServerInvoke = function()
		return math.floor(os.clock() - _serverStartClock)
	end
end

local _setSeenUpdateLog = Misc:FindFirstChild("SetSeenUpdateLog")
if _setSeenUpdateLog then
	_setSeenUpdateLog.OnServerEvent:Connect(function(player)
		local v = player:FindFirstChild("SeenUpdateLog")
		if v then v.Value = true end
	end)
end

local _setSeenUpdateVersion = Misc:FindFirstChild("SetSeenUpdateVersion")
if _setSeenUpdateVersion then
	_setSeenUpdateVersion.OnServerEvent:Connect(function(player, version)
		if type(version) ~= "number" then return end
		local v = player:FindFirstChild("LastSeenUpdateVersion")
		local dm = require(game:GetService("ServerScriptService"):WaitForChild("leaderstats"):WaitForChild("DataManager"))
		if v and version > v.Value then
			v.Value = version
			dm:UpdateData(player, "LastSeenUpdateVersion", version)
		end
	end)
end

-- RS root shortcuts (some legacy scripts reference these directly on RS)
ensureRemote(ReplicatedStorage, "TutorialEvent", "BindableEvent")
ensureRemote(ReplicatedStorage, "DonationForceRefresh", "BindableEvent")

-- VoidQuestEvents (RS root — referenced by client scripts)
local voidQuestEvents = ensureFolder(ReplicatedStorage, "VoidQuestEvents")
ensureRemote(voidQuestEvents, "VoidQuestGuiEvent")
ensureRemote(voidQuestEvents, "VoidQuestChoiceEvent")

-- VoidRodEvents (RS root — Folder with child RemoteEvents used by shop.client)
local voidRodEvents = ensureFolder(ReplicatedStorage, "VoidRodEvents")
ensureRemote(voidRodEvents, "OpenVoidShop")
ensureRemote(voidRodEvents, "VoidShopNotice")
