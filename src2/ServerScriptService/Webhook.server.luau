local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local WELCOME_WEBHOOK_URL  = "https://discord.com/api/webhooks/1505557738519003256/3NmA5pxnHskrhVBA35U8n-E4m2bGl1GW3WsPqgPmT_sIoLG11Yt6scs3h5O0Pkwqgo41"
local LEFT_WEBHOOK_URL     = "https://discord.com/api/webhooks/1505557810765893712/UgekshEu0uwRW0EaprAAErn2vQH-BKvqeOWKqgh_3w9FWktX_55PCku_NbYwrf1gp8-u"
local ERROR_WEBHOOK_URL    = "https://discord.com/api/webhooks/1505557856924209234/njV0XIR1EuT0UGp7d3o_HI9CHmHjd5vu0EG0vMHDYl6iui65IFQ2ndvd_7rqoG2VfsnO"
local PURCHASE_WEBHOOK_URL = "https://discord.com/api/webhooks/1505561651749982268/p5vbjsLvNEH14ufj1Ynvxc51ckrpH6S9v-w6Z93UUzgimpekC4rdeWm_MJy_R6JrUb7X"

local GAMEPASS_NAMES = {
	[1293430515] = "Coin x2",
	[1289569606] = "Luck x2",
	[1290056221] = "Power x2",
	[1410895892] = "Robux Rod",
	[1423175879] = "Robux Fish Trap",
	[1294285302] = "Inventory Expansion",
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

local function sendWebhook(url, title, message, color)
	local prefix = RunService:IsStudio() and "🔧 **[STUDIO]** " or ""
	local data = {
		["username"] = "Game Logger",
		["embeds"] = {{
			["title"] = title,
			["description"] = prefix .. message,
			["color"] = color,
			["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
		}}
	}

	local jsonData = HttpService:JSONEncode(data)

	local ok, err = pcall(function()
		HttpService:PostAsync(url, jsonData, Enum.HttpContentType.ApplicationJson)
	end)
	if not ok then
		warn("Webhook failed:", err)
		if url ~= ERROR_WEBHOOK_URL then
			sendWebhook(ERROR_WEBHOOK_URL, "Webhook Error", string.format("URL: %s\nError: %s", url, tostring(err)), 16711680)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	playerJoinTimes[player.UserId] = tick()
	if RunService:IsStudio() then return end
	local message = string.format("**%s** joined the game!", player.Name)
	sendWebhook(WELCOME_WEBHOOK_URL, "Player Joined", message, 65280)
end)

Players.PlayerRemoving:Connect(function(player)
	local joinTime = playerJoinTimes[player.UserId]
	local message

	if joinTime then
		local playTime = tick() - joinTime
		local formattedTime = formatPlayTime(playTime)
		message = string.format("**%s** left the game.\nPlay time: %s", player.Name, formattedTime)
		playerJoinTimes[player.UserId] = nil
	else
		message = string.format("**%s** left the game.", player.Name)
	end

	if RunService:IsStudio() then return end
	sendWebhook(LEFT_WEBHOOK_URL, "Player Left", message, 16711680)
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
	local message = string.format("**%s** purchased gamepass **%s**", player.Name, name)
	task.spawn(sendWebhook, PURCHASE_WEBHOOK_URL, "Gamepass Purchased", message, 16776960)
end)

-- Developer product purchases (fired from ProcessReceipt via BindableEvent)
local purchaseLogEvent = Instance.new("BindableEvent")
purchaseLogEvent.Name = "PurchaseLogEvent"
purchaseLogEvent.Parent = game:GetService("ServerScriptService")

purchaseLogEvent.Event:Connect(function(playerName, productId)
	local name = PRODUCT_NAMES[productId] or ("Product #" .. productId)
	local message = string.format("**%s** purchased **%s**", playerName, name)
	task.spawn(sendWebhook, PURCHASE_WEBHOOK_URL, "Product Purchased", message, 16776960)
end)
