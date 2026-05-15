local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.leaderstats.DataManager)

local Misc = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc")
local saveRemote = Misc:WaitForChild("SaveHotBarLayout")
local getRemote = Misc:WaitForChild("GetHotBarLayout")

-- 클라이언트 → 서버: 핫바 슬롯 배치 저장 {[slot] = toolName}
saveRemote.OnServerEvent:Connect(function(player, layout)
	if typeof(layout) ~= "table" then return end
	-- 최대 9슬롯만 허용, 값은 string만
	local clean = {}
	for slot = 1, 9 do
		local v = layout[slot]
		if typeof(v) == "string" then
			clean[slot] = v
		end
	end
	DataManager:UpdateData(player, "HotBarLayout", clean)
	DataManager:SaveData(player)
end)

-- 클라이언트 → 서버: 핫바 레이아웃 요청
getRemote.OnServerInvoke = function(player)
	local data = DataManager:GetData(player)
	return data and data.HotBarLayout or {}
end
