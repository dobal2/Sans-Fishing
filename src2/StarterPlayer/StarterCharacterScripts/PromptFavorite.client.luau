local ReplicatedStorage = game:GetService("ReplicatedStorage")
local avatarEditorService = game:GetService("AvatarEditorService")

local setFavoriteRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("SetFavoriteRemote")

setFavoriteRemote.OnClientEvent:Connect(function()
	avatarEditorService:PromptSetFavorite(129796299052709, Enum.AvatarItemType.Asset, true)
end)
