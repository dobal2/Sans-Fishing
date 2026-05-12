local ReplicatedStorage = game:GetService("ReplicatedStorage")
local avatarEditorService = game:GetService("AvatarEditorService")

-- 리모트 이벤트 대기
local setFavoriteRemote = ReplicatedStorage:WaitForChild("SetFavoriteRemote")

-- 리모트 이벤트를 받으면 실행
setFavoriteRemote.OnClientEvent:Connect(function()
	-- 페이버릿 프롬프트 바로 표시 (상태 확인 없이)
	avatarEditorService:PromptSetFavorite(129796299052709, Enum.AvatarItemType.Asset, true)
end)
