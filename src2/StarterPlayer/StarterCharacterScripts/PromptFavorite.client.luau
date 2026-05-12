local ReplicatedStorage = game:GetService("ReplicatedStorage")
local avatarEditorService = game:GetService("AvatarEditorService")

-- Wait for remote event
local setFavoriteRemote = ReplicatedStorage:WaitForChild("SetFavoriteRemote")

-- Run when remote event is received
setFavoriteRemote.OnClientEvent:Connect(function()
	-- Show favorite prompt immediately (no state check)
	avatarEditorService:PromptSetFavorite(129796299052709, Enum.AvatarItemType.Asset, true)
end)
