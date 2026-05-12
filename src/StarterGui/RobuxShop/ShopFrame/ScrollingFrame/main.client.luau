local EnterBox = script.Parent["Frame"]["Box"]
local Redeem = EnterBox.Parent["Redeem"]

local Player = game:GetService("Players").LocalPlayer
local ClickDB = false

local code_event = game:GetService("ReplicatedStorage"):WaitForChild("codeEvent")
local code_response_event = game:GetService("ReplicatedStorage"):WaitForChild("CodeResponseEvent")

local successSound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("Success")
local failSound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("Fail")

local function button_animation(Button,bool)
	local isHovering = false
	local normalX = Button.Size.X.Scale
	local noramlY = Button.Size.Y.Scale

	local enterX = normalX + 0.007
	local enterY = noramlY + 0.007

	local pressX = normalX - 0.025
	local pressY = noramlY - 0.005

	Button.MouseEnter:Connect(function()
		isHovering = true
		Button:TweenSize(UDim2.new(enterX,0,enterY,0), Enum.EasingDirection.InOut, Enum.EasingStyle.Quint, 0.2, true)
	end)

	Button.MouseLeave:Connect(function()
		isHovering = false
		Button:TweenSize(UDim2.new(normalX,0,noramlY,0), Enum.EasingDirection.InOut, Enum.EasingStyle.Quint, 0.2, true)
	end)
	if bool == true then
		Button.MouseButton1Down:Connect(function()
			Button:TweenSize(UDim2.new(pressX,0,pressY,0), Enum.EasingDirection.InOut, Enum.EasingStyle.Quint, 0.2, true)
		end)
		Button.MouseButton1Up:Connect(function()
			if not isHovering then
				Button:TweenSize(UDim2.new(normalX,0,noramlY,0), Enum.EasingDirection.InOut, Enum.EasingStyle.Quint, 0.2, true)
			else
				Button:TweenSize(UDim2.new(enterX,0,enterY,0), Enum.EasingDirection.InOut, Enum.EasingStyle.Quint, 0.2, true)
			end
		end)
	end
end


-- 🆕 서버 응답 처리 (사운드 추가)
code_response_event.OnClientEvent:Connect(function(result, reward)
	if result == "success" then
		-- 🎵 성공 사운드 재생
		successSound:Play()

		EnterBox.TextColor3 = Color3.fromRGB(0, 170, 127)
		EnterBox.TextEditable = false
		EnterBox.Text = 'Code Redeemed!'
		delay(1, function()
			EnterBox.TextEditable = true
			EnterBox.Text = 'Enter Code'
			EnterBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		end)
	elseif result == "already_used" then
		-- 🎵 실패 사운드 재생
		failSound:Play()

		EnterBox.TextColor3 = Color3.fromRGB(255, 8, 61)
		EnterBox.TextEditable = false
		EnterBox.Text = 'Code Already Redeemed!'
		delay(1.25, function()
			EnterBox.TextEditable = true
			EnterBox.Text = 'Enter Code'
			EnterBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		end)
	elseif result == "invalid" then
		-- 🎵 실패 사운드 재생
		failSound:Play()

		EnterBox.TextColor3 = Color3.fromRGB(255, 8, 61)
		EnterBox.TextEditable = false
		EnterBox.Text = 'Invalid Code!'
		delay(1.25, function()
			EnterBox.TextEditable = true
			EnterBox.Text = 'Enter Code'
			EnterBox.TextColor3 = Color3.fromRGB(171, 171, 171)
		end)
	end
end)

-- 🔧 단순화된 버튼 클릭 처리
local function button_clicked()
	-- 🛡️ 모든 검증을 서버에 맡김
	if EnterBox.Text and string.len(EnterBox.Text) > 0 then
		code_event:FireServer(EnterBox.Text)
	end
end


Redeem.Activated:Connect(function()
	if ClickDB == false then
		ClickDB = true
		button_clicked()
		wait(0.15)
		ClickDB = false
	end
end)

-- 🔧 Open 버튼 애니메이션 제거, Redeem 버튼만 애니메이션
button_animation(Redeem,true)