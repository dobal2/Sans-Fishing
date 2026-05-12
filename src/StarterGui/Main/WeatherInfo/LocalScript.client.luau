local Info = script.Parent:WaitForChild("Frame")
local image = script.Parent

-- 마우스 들어올 때 프레임 보이기 (PC)
image.MouseEnter:Connect(function()
	Info.Visible = true
end)

-- 마우스 나갈 때 프레임 숨기기 (PC)
image.MouseLeave:Connect(function()
	Info.Visible = false
end)

---- 터치 시작 시 프레임 보이기 (모바일)
--image.TouchTap:Connect(function()
--	Info.Visible = not Info.Visible -- 토글 방식
--end)

-- 또는 길게 누르고 있을 때만 보이게 하려면:

image.TouchLongPress:Connect(function()
	Info.Visible = true
end)

-- 터치가 끝나면 숨기기
local UserInputService = game:GetService("UserInputService")
UserInputService.TouchEnded:Connect(function()
	Info.Visible = false
end)
