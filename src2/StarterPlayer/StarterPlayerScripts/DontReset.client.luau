local StarterGui = game:GetService("StarterGui")
local success = false

repeat
	success = pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
	wait() -- Brief wait to avoid tight loop
until success
