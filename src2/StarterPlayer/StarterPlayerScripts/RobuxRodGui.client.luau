local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local ROBUX_ROD_PASS = 1410895892

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local main = playerGui:WaitForChild("Main")
local frame = main:WaitForChild("RobuxRod")
local button = frame:WaitForChild("Button")

-- 패스 보유 여부 확인 후 프레임 표시 여부 결정
frame.Visible = false

task.spawn(function()
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, ROBUX_ROD_PASS)
	end)
	if ok and owns then
		frame.Visible = false
	else
		frame.Visible = true
	end
end)

button.Activated:Connect(function()
	pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, ROBUX_ROD_PASS)
	end)
end)

-- 구매 완료 시 프레임 숨김
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, passId, wasPurchased)
	if passId == ROBUX_ROD_PASS and wasPurchased then
		frame.Visible = false
	end
end)
