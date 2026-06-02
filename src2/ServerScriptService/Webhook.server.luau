local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")

local datamanager = require(ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))

local WELCOME_WEBHOOK_URL  = "https://webhook.lewisakura.moe/api/webhooks/1505557738519003256/3NmA5pxnHskrhVBA35U8n-E4m2bGl1GW3WsPqgPmT_sIoLG11Yt6scs3h5O0Pkwqgo41"
local LEFT_WEBHOOK_URL     = "https://webhook.lewisakura.moe/api/webhooks/1505557810765893712/UgekshEu0uwRW0EaprAAErn2vQH-BKvqeOWKqgh_3w9FWktX_55PCku_NbYwrf1gp8-u"
local ERROR_WEBHOOK_URL    = "https://webhook.lewisakura.moe/api/webhooks/1505557856924209234/njV0XIR1EuT0UGp7d3o_HI9CHmHjd5vu0EG0vMHDYl6iui65IFQ2ndvd_7rqoG2VfsnO"
local PURCHASE_WEBHOOK_URL = "https://webhook.lewisakura.moe/api/webhooks/1505561651749982268/p5vbjsLvNEH14ufj1Ynvxc51ckrpH6S9v-w6Z93UUzgimpekC4rdeWm_MJy_R6JrUb7X"
local FISH_GIVE_WEBHOOK_URL = "https://webhook.lewisakura.moe/api/webhooks/1507595695622721547/GpcMcrPmLIFLKBmZw5QD2wr1X22k84Uqz6n6EcNQ4oZH5VYFWdEhQpkd5DMg25S5OaZD"
local FOLLOWER_ALERT_WEBHOOK_URL = "https://discord.com/api/webhooks/1511370238430543903/563ZU5EntFpaq1CGDs5_L5woSirFXze2AAzWNyoDDoQD-LQdrr_8PmmQa1RKmnZhvsb2"
local FOLLOWER_ALERT_THRESHOLD = 100
local FOLLOWER_COUNT_URLS = {
	"https://friends.roproxy.com/v1/users/%d/followers/count",
	"https://friends.roblox.com/v1/users/%d/followers/count",
}

local GAMEPASS_NAMES = {
	[1293430515] = "Coin x2",
	[1289569606] = "Luck x2",
	[1290056221] = "Power x2",
	[1410895892] = "Robux Rod",
	[1423175879] = "Robux Fish Trap",
	[1294285302] = "FishingPoint x2",
}

local PRODUCT_NAMES = {
	[3591644219] = "Random Fish (x1)",
	[3591613623] = "Server Boost Tier 1",
	[3591613620] = "Server Boost Tier 2",
	[3591613622] = "Server Boost Tier 3",
	[3591613619] = "Server Boost Tier 4",
	[3364008117] = "Donation 2 R$",
	[3364050876] = "Donation 5 R$",
	[3364051385] = "Donation 10 R$",
	[3364051789] = "Donation 50 R$",
	[3364052354] = "Donation 100 R$",
	[3364066503] = "Donation 500 R$",
	[3364067189] = "Donation 1000 R$",
	[3364067188] = "Donation 5000 R$",
	[3591658074] = "Donation 10000 R$",
	[3591658073] = "Donation 100000 R$",
}

local playerJoinTimes = {}

local function formatPlayTime(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)

	if hours > 0 then
		return string.format("%dh %dm %ds", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	else
		return string.format("%ds", secs)
	end
end

local MAX_RETRIES = 3
local RETRY_DELAY = 2
local RATE_LIMIT_RETRY_DELAY = 8

local function isRateLimitError(err)
	return string.find(tostring(err), "HTTP 429", 1, true) ~= nil
end

local function redactWebhookUrl(url)
	return tostring(url):gsub("/api/webhooks/(%d+)/[^/%s`]+", "/api/webhooks/%1/[redacted]")
end

local function sendWebhook(url, title, color, authorName, authorUrl, authorIconUrl, fields, description)
	local embed = {
		["title"] = title,
		["color"] = color,
		["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}
	if description then
		embed["description"] = (RunService:IsStudio() and "🔧 **[STUDIO]**\n" or "") .. description
	elseif RunService:IsStudio() then
		embed["description"] = "🔧 **[STUDIO]**"
	end
	if authorName then
		embed["author"] = {
			["name"] = authorName,
			["url"] = authorUrl or nil,
			["icon_url"] = authorIconUrl or nil,
		}
	end
	if fields then
		embed["fields"] = fields
	end
	local data = {
		["username"] = "Sans Fishing",
		["avatar_url"] = "https://tr.rbxcdn.com/180DAY-d4f5c02f9a3a7e4d2a6b1c8e3f0a9b7d/420/420/Image/Webp/noFilter",
		["embeds"] = { embed },
	}
	local body = HttpService:JSONEncode(data)

	for attempt = 1, MAX_RETRIES do
		local ok, err = pcall(HttpService.PostAsync, HttpService, url,
			body, Enum.HttpContentType.ApplicationJson)
		if ok then return end
		warn(string.format("Webhook failed (attempt %d/%d): %s", attempt, MAX_RETRIES, tostring(err)))
		if attempt < MAX_RETRIES then
			task.wait(isRateLimitError(err) and RATE_LIMIT_RETRY_DELAY or RETRY_DELAY)
		elseif url ~= ERROR_WEBHOOK_URL and not isRateLimitError(err) then
			task.spawn(sendWebhook, ERROR_WEBHOOK_URL, "Webhook Error", 16711680, nil, nil, nil, nil,
				string.format("URL: `%s`\nError: `%s`", redactWebhookUrl(url), tostring(err)))
		end
	end
end

local function formatSkills(skills)
	if not skills or next(skills) == nil then return "없음" end
	local parts = {}
	for name, level in pairs(skills) do
		if level > 0 then
			table.insert(parts, name .. " Lv" .. level)
		end
	end
	table.sort(parts)
	return #parts > 0 and table.concat(parts, ", ") or "없음"
end

local function buildPlayerFields(data, sessionPlayTime)
	if not data then return {} end
	local totalPlaytime = (data.Playtime or 0) + (sessionPlayTime or 0)
	return {
		{ name = "🕐 총 플레이타임", value = formatPlayTime(totalPlaytime), inline = true },
		{ name = "🪙 코인",          value = tostring(data.Coins or 0),       inline = true },
		{ name = "🎣 낚싯대",        value = tostring(data.CurrentRod or "FishingRod"), inline = true },
		{ name = "⭐ 스킬포인트",   value = tostring(data.SkillPoints or 0),  inline = true },
		{ name = "🔮 스킬",          value = formatSkills(data.Skills),        inline = false },
	}
end

local function getProfileUrl(userId)
	return "https://www.roblox.com/users/" .. tostring(userId) .. "/profile"
end

local function getAvatarUrl(userId)
	return "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(userId) .. "&width=48&height=48&format=png"
end

local function getFollowerCount(userId)
	for _, urlTemplate in ipairs(FOLLOWER_COUNT_URLS) do
		local url = string.format(urlTemplate, userId)
		local ok, response = pcall(HttpService.GetAsync, HttpService, url)
		if ok then
			local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, response)
			if decodeOk and type(decoded) == "table" and type(decoded.count) == "number" then
				return decoded.count
			end
		else
			warn("Follower count request failed:", tostring(response))
		end
	end

	return nil
end

local function sendFollowerAlertIfNeeded(player)
	local followerCount = getFollowerCount(player.UserId)
	if not followerCount or followerCount < FOLLOWER_ALERT_THRESHOLD then return end

	sendWebhook(
		FOLLOWER_ALERT_WEBHOOK_URL, "100+ Followers Player Joined", 0xF1C40F,
		player.Name, getProfileUrl(player.UserId), getAvatarUrl(player.UserId),
		{
			{ name = "Followers", value = tostring(followerCount), inline = true },
			{ name = "UserId", value = tostring(player.UserId), inline = true },
			{ name = "Profile", value = getProfileUrl(player.UserId), inline = false },
		}
	)
end

Players.PlayerAdded:Connect(function(player)
	playerJoinTimes[player.UserId] = tick()
	if RunService:IsStudio() then return end

	task.spawn(function()
		-- DataReady 대기 (최대 30초) 후 전송
		local dataReady = player:WaitForChild("DataReady", 30)
		if dataReady then
			repeat task.wait(0.5) until dataReady.Value == true or not player:IsDescendantOf(Players)
		else
			task.wait(5)
		end
		if not player:IsDescendantOf(Players) then return end
		local data = datamanager:GetData(player)
		local fields = buildPlayerFields(data, 0)
		sendWebhook(
			WELCOME_WEBHOOK_URL, "✅ 플레이어 입장", 0x2ECC71,
			player.Name, getProfileUrl(player.UserId), getAvatarUrl(player.UserId),
			fields
		)
		sendFollowerAlertIfNeeded(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local joinTime = playerJoinTimes[player.UserId]
	local sessionTime = joinTime and (tick() - joinTime) or 0
	playerJoinTimes[player.UserId] = nil

	if RunService:IsStudio() then return end

	-- 데이터를 미리 캡처 (PlayerRemoving 이후엔 GetData가 nil 반환할 수 있음)
	local data = datamanager:GetData(player)
	local fields = buildPlayerFields(data, sessionTime)
	table.insert(fields, 1, { name = "⏱️ 이번 세션", value = formatPlayTime(sessionTime), inline = true })

	-- task.spawn으로 non-blocking 처리 (서버 종료 시에도 가능한 한 전송)
	task.spawn(function()
		sendWebhook(
			LEFT_WEBHOOK_URL, "🚪 플레이어 퇴장", 0xE74C3C,
			player.Name, getProfileUrl(player.UserId), getAvatarUrl(player.UserId),
			fields
		)
	end)
end)

-- Record join time for players already in server on script start
for _, player in pairs(Players:GetPlayers()) do
	if not playerJoinTimes[player.UserId] then
		playerJoinTimes[player.UserId] = tick()
	end
end

-- Gamepass purchases
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then return end
	local name = GAMEPASS_NAMES[gamePassId] or ("GamePass #" .. gamePassId)
	sendWebhook(
		PURCHASE_WEBHOOK_URL, "💎 게임패스 구매", 0xF1C40F,
		player.Name, getProfileUrl(player.UserId), getAvatarUrl(player.UserId),
		{ { name = "패스", value = name, inline = true } }
	)
end)

-- Developer product purchases (fired from ProcessReceipt via BindableEvent)
local purchaseLogEvent = Instance.new("BindableEvent")
purchaseLogEvent.Name = "PurchaseLogEvent"
purchaseLogEvent.Parent = game:GetService("ServerScriptService")

purchaseLogEvent.Event:Connect(function(playerName, productId)
	local name = PRODUCT_NAMES[productId] or ("Product #" .. productId)
	sendWebhook(
		PURCHASE_WEBHOOK_URL, "🛒 상품 구매", 0xF1C40F,
		playerName, nil, nil,
		{ { name = "상품", value = name, inline = true } }
	)
end)

-- Fish give log (fired from GiveFish.server.luau on successful give)
local fishGiveLogEvent = Instance.new("BindableEvent")
fishGiveLogEvent.Name = "FishGiveLogEvent"
fishGiveLogEvent.Parent = ServerScriptService

fishGiveLogEvent.Event:Connect(function(giverName, giverId, receiverName, fishName)
	if RunService:IsStudio() then return end
	sendWebhook(
		FISH_GIVE_WEBHOOK_URL, "🐟 물고기 선물", 0x3498DB,
		giverName, getProfileUrl(giverId), getAvatarUrl(giverId),
		{
			{ name = "받는 사람", value = receiverName, inline = true },
			{ name = "물고기",   value = fishName,     inline = true },
		}
	)
end)
