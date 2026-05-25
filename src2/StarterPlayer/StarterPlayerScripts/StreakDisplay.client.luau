local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local streakUpdateEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("StreakUpdateEvent")
local streakEndBroadcast = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("StreakEndBroadcast")

streakEndBroadcast.OnClientEvent:Connect(function(displayName, streak)
	local textChannels = TextChatService:WaitForChild("TextChannels")
	local generalChannel = textChannels:WaitForChild("RBXGeneral")
	generalChannel:DisplaySystemMessage(string.format('<font color="#FF4500">🔥 %s\'s %d stack ended!</font>', displayName, streak))
end)

local function getNameTagForUserId(userId)
	local target = Players:GetPlayerByUserId(userId)
	if not target then return nil end
	local character = target.Character
	if not character then return nil end
	local head = character:FindFirstChild("Head")
	if not head then return nil end
	return head:FindFirstChild("NameTag")
end

streakUpdateEvent.OnClientEvent:Connect(function(userId, streak)
	local nameTag = getNameTagForUserId(userId)
	if not nameTag then return end
	local stackText  = nameTag:FindFirstChild("StackText")
	local stackImage = nameTag:FindFirstChild("StackImage")
	if not stackText or not stackImage then return end
	if streak and streak >= 1 then
		stackText.Text     = tostring(streak)
		stackText.Visible  = true
		stackImage.Visible = true
	else
		stackText.Visible  = false
		stackImage.Visible = false
	end
end)
