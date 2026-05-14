local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer

local SOUND_ID = "rbxassetid://6895079853"
local TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local sellGuiEvent    = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("SellGuiEvent")
local gambleGuiEvent  = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Sell"):WaitForChild("GambleGuiEvent")
local questGuiEvent   = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Quest"):WaitForChild("QuestGuiEvent")

local function animateOptions(guiName, optionNames)
	local gui = player.PlayerGui:WaitForChild(guiName)
	for _, optionName in ipairs(optionNames) do
		local button = gui:FindFirstChild(optionName)
		if not button then continue end

		local originalSize = button.Size

		local sound = Instance.new("Sound")
		sound.SoundId = SOUND_ID
		sound.Volume = 10
		sound.Looped = false
		sound.Parent = button
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 3)

		button.Visible = true
		button.Size = UDim2.new(0, 0, 0, 0)
		TweenService:Create(button, TWEEN_INFO, {Size = originalSize}):Play()
	end
end

sellGuiEvent.OnClientEvent:Connect(function()
	animateOptions("SellOptions", {"Option1", "Option2", "Option3", "Option4"})
end)

gambleGuiEvent.OnClientEvent:Connect(function()
	animateOptions("GambleOptions", {"Option1", "Option2"})
end)

questGuiEvent.OnClientEvent:Connect(function()
	animateOptions("QuestOptions", {"Option1", "Option2"})
end)

-- TextLabel hover: sound + slide right on hover
local HOVER_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER_OFFSET = UDim2.new(0, 10, 0, 0)

local function setupTextLabelHover(label)
	local originalPos = label.Position
	local hoverSound = Instance.new("Sound")
	hoverSound.SoundId = SOUND_ID
	hoverSound.Volume = 10
	hoverSound.Parent = label

	label.MouseEnter:Connect(function()
		hoverSound:Play()
		TweenService:Create(label, HOVER_TWEEN, {Position = originalPos + HOVER_OFFSET}):Play()
	end)
	label.MouseLeave:Connect(function()
		TweenService:Create(label, HOVER_TWEEN, {Position = originalPos}):Play()
	end)
end

local GUI_OPTION_MAP = {
	{ guiName = "SellOptions",   options = {"Option1", "Option2", "Option3", "Option4"} },
	{ guiName = "GambleOptions", options = {"Option1", "Option2"} },
	{ guiName = "QuestOptions",  options = {"Option1", "Option2"} },
}

task.spawn(function()
	for _, entry in ipairs(GUI_OPTION_MAP) do
		local gui = player.PlayerGui:WaitForChild(entry.guiName)
		for _, optName in ipairs(entry.options) do
			local option = gui:WaitForChild(optName)
			local label = option:FindFirstChild("TextLabel")
			if label then
				setupTextLabelHover(label)
			end
		end
	end
end)

