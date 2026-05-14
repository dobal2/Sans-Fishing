-- Handles bubble ProximityPrompts in Workspace.
-- Each bubble model's ProximityPrompt fires BuyBubbleBindable with the bubble type name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local buyBubbleBindable = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("BuyBubbleBindable")

local BUBBLE_NAMES = {
	["Strength Bubble"] = "Strength Bubble",
	["SizeBuff Bubble"] = "SizeBuff Bubble",
	["Luck Bubble"] = "Luck Bubble",
}

local function wireBubble(modelName, bubbleType)
	local model = workspace:FindFirstChild(modelName)
	if not model then return end
	local prompt = model:FindFirstChildOfClass("ProximityPrompt")
		or model:FindFirstChildWhichIsA("BasePart") and model:FindFirstChildWhichIsA("BasePart"):FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		-- search descendants
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				prompt = d
				break
			end
		end
	end
	if not prompt then return end

	prompt.Triggered:Connect(function(plr)
		buyBubbleBindable:Fire(plr, bubbleType)
	end)
end

wireBubble("Strength Bubble", "Strength Bubble")
wireBubble("SizeBuff Bubble", "SizeBuff Bubble")
wireBubble("Luck Bubble", "Luck Bubble")
