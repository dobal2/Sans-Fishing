local StarterGui = game:GetService("StarterGui")
local success = false

repeat
	success = pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
	wait() -- 너무 빠르게 루프 돌지 않도록 잠깐 대기
until success
