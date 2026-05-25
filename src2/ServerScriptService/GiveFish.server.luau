local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local fishGiveLogEvent = nil
task.spawn(function()
	fishGiveLogEvent = ServerScriptService:WaitForChild("FishGiveLogEvent", 30)
end)

local FishReceiveNoticeEvent = Instance.new("RemoteEvent")
FishReceiveNoticeEvent.Name = "FishReceiveNoticeEvent"
FishReceiveNoticeEvent.Parent = ReplicatedStorage

-- FishGiveBindable: ItemSave handles the actual data transfer
local FishGiveBindable = Instance.new("BindableFunction")
FishGiveBindable.Name = "FishGiveBindable"
FishGiveBindable.Parent = ServerScriptService

local function isFish(tool)
	if not tool or not tool:IsA("Tool") then return false end
	local fishValue = tool:FindFirstChild("FishValue")
	if not fishValue then return false end
	local ok, isInt = pcall(function() return fishValue:IsA("IntValue") end)
	return ok and isInt
end

local function addPromptToCharacter(char, owner)
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if not hrp then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ReceiveFishPrompt"
	prompt.ActionText = "Give My Fish"
	prompt.ObjectText = owner.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 1
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 6
	prompt.Parent = hrp

	prompt.Triggered:Connect(function(fromPlayer)
		if fromPlayer == owner then return end

		local senderChar = fromPlayer.Character
		if not senderChar then return end

		-- Character에 장착 중인 물고기 툴만 허용 (Backpack에 있으면 들고 있지 않은 것)
		local tool = senderChar:FindFirstChildWhichIsA("Tool")
		if not isFish(tool) then
			FishReceiveNoticeEvent:FireClient(fromPlayer, "You need to hold a fish to give!")
			return
		end

		-- Delegate to ItemSave: move equipped fish data from sender to receiver
		local ok, success = pcall(function()
			return FishGiveBindable:Invoke(fromPlayer, owner, tool)
		end)

		if ok and success then
			FishReceiveNoticeEvent:FireClient(fromPlayer, "Fish given to " .. owner.Name .. "!")
			FishReceiveNoticeEvent:FireClient(owner, "Received fish from " .. fromPlayer.Name .. "!")
			if fishGiveLogEvent then
				fishGiveLogEvent:Fire(fromPlayer.Name, fromPlayer.UserId, owner.Name, tool.Name)
			end
		else
			FishReceiveNoticeEvent:FireClient(fromPlayer, "Failed to give fish to " .. owner.Name)
		end
	end)
end

local function setupPlayer(player)
	if player.Character then
		addPromptToCharacter(player.Character, player)
	end
	player.CharacterAdded:Connect(function(char)
		task.wait(1)
		addPromptToCharacter(char, player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in pairs(Players:GetPlayers()) do
	setupPlayer(player)
end
