-- LocalScript
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tips = {
	{text = "Tip: Upgrade your fishing rod to catch fish more easily!", color = "#FFD700"},
	{text = "Tip: Better fishing rods give you bonus chances to catch rare fish!", color = "#8A2BE2"},
	{text = "Tip: Each fish has different weight - try to catch the heaviest ones!", color = "#00BFFF"},
	{text = "Tip: Some fish are much rarer than others - keep fishing to find them!", color = "#FF1493"},
	{text = "Tip: Challenge yourself to catch a 100kg fish!", color = "#FF4500"},
	{text = "Tip: Sell your fish to earn money and buy better rods!", color = "#228B22"},
	{text = "Tip: Try to catch the fantasy Sans fish - it's extremely rare!", color = "#FF00FF"},
	{text = "Tip: The weight of your fish determines how much money you'll earn!", color = "#FFD700"},
	{text = "Tip: Higher tier fishing rods can catch bigger and heavier fish!", color = "#1E90FF"},
	{text = "Tip: Keep fishing to discover all the different fish species!", color = "#00FF7F"},
	{text = "Tip: Join our group and get 15% more money when selling fish!", color = "#FF69B4"}
}

local textChannels = TextChatService:WaitForChild("TextChannels")
local generalChannel = textChannels:WaitForChild("RBXGeneral")

-- Send message to chat
local function sendMessageToChat(message, color)
	local formattedMessage = string.format('<font color="%s">%s</font>', color, message)
	generalChannel:DisplaySystemMessage(formattedMessage)
end

-- Send a random tip to chat
local function sendTipToChat()
	local randomTipData = tips[math.random(1, #tips)]
	sendMessageToChat(randomTipData.text, randomTipData.color)
end

-- Handle leaderboard notification events
local leaderboardNotificationEvent = ReplicatedStorage:WaitForChild("LeaderboardNotificationEvent")
leaderboardNotificationEvent.OnClientEvent:Connect(function(message, color)
	sendMessageToChat(message, color)
end)

-- Send tip every 3 minutes
task.spawn(function()
	while true do
		sendTipToChat()
		task.wait(180)
	end
end)
