local ReplicatedStorage = game:GetService("ReplicatedStorage")
local avatarEditorService = game:GetService("AvatarEditorService")

local setFavoriteRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("SetFavoriteRemote")

local promptInProgress = false

setFavoriteRemote.OnClientEvent:Connect(function()
	if promptInProgress then return end
	promptInProgress = true
	pcall(function()
		avatarEditorService:PromptSetFavorite(129796299052709, Enum.AvatarItemType.Asset, true)
	end)
	task.delay(3, function()
		promptInProgress = false
	end)
end)
