local player = game.Players.LocalPlayer
local MarketplaceService = game:GetService("MarketplaceService")
local GroupService = game:GetService("GroupService")

local GROUP_ID = 9744474

local function checkGroupMembership()
	local success, isInGroup = pcall(function()
		return player:IsInGroup(GROUP_ID)
	end)

	if success and isInGroup then
		script.Parent.Visible = false
		return true
	end
	return false
end

if checkGroupMembership() then
	return
end
