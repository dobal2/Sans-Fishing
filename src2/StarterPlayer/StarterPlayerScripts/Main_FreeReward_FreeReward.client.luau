local player = game.Players.LocalPlayer
local MarketplaceService = game:GetService("MarketplaceService")
local GroupService = game:GetService("GroupService")

local GROUP_ID = 9744474

local mainGui = player.PlayerGui:WaitForChild("Main")
local freeRewardFrame = mainGui:WaitForChild("Free Reward")

-- TODO: re-enable group check before release
-- local function checkGroupMembership()
-- 	local success, isInGroup = pcall(function()
-- 		return player:IsInGroup(GROUP_ID)
-- 	end)
-- 	if success and isInGroup then
-- 		freeRewardFrame.Visible = false
-- 		return true
-- 	end
-- 	return false
-- end
-- if checkGroupMembership() then return end
