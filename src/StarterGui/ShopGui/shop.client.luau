local player = game.Players.LocalPlayer
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local cam = workspace.CurrentCamera
local MarketplaceService = game:GetService("MarketplaceService")

local RodData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("RodDataModule"))
local voidRodModel = workspace:WaitForChild("VoidRodModel")
local voidProximity = voidRodModel:WaitForChild("ProximityPrompt")
-- 로벅스 로드 게임패스 ID
local ROBUX_ROD_GAMEPASS_ID = 1410895892

-- UI
local gui = script.Parent
local frame1 = gui:WaitForChild("Frame1")
local frame2 = gui:WaitForChild("Frame2")
local buyframe = gui:WaitForChild("buyframe")
local nameText = frame2:WaitForChild("Name")
local coinText = buyframe:WaitForChild("Cointext")
local noticeText = buyframe:WaitForChild("notice")
local descText = buyframe:WaitForChild("Desc")

-- 원래 텍스트 색상 저장
local originalTextColor = coinText.TextColor3

-- Custom Inventory hotBar 참조
local customInventory = player.PlayerGui:WaitForChild("Custom Inventory")
local hotBar = customInventory:WaitForChild("hotBar")

-- Main GUI 버튼들 참조
local mainGui = player.PlayerGui:WaitForChild("Main")
local fishingButton = mainGui:WaitForChild("Fishing")
local sellButton = mainGui:WaitForChild("Sell")
local upgradeButton = mainGui:WaitForChild("Upgrade")
local freeRewardButton = mainGui:WaitForChild("Free Reward")

-- Buttons
local buyButton = buyframe:WaitForChild("buybutton")
local leftButton = buyframe:WaitForChild("leftarrow")
local rightButton = buyframe:WaitForChild("rightarrow")
local exitButton = buyframe:WaitForChild("Exitbutton")

-- 리모트
local openShopRemote = game.ReplicatedStorage:WaitForChild("OpenShop")
local buyRemote = game.ReplicatedStorage:WaitForChild("BuyFishingRod")
local proximy = workspace:WaitForChild("Upgrade Shop"):WaitForChild("ShopSeller"):WaitForChild("ProximityPrompt")
local buySound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("Buy SFX")
local errorSound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("error")
local equipSound = game:GetService("ReplicatedStorage"):WaitForChild("Sounds"):WaitForChild("Equip")

-- 보이드 로드 이벤트들
local voidRodEvents = game.ReplicatedStorage:WaitForChild("VoidRodEvents")
local openVoidShopEvent = voidRodEvents:WaitForChild("OpenVoidShop")
local voidShopNoticeEvent = voidRodEvents:WaitForChild("VoidShopNotice")

local GroupService = game:GetService("GroupService")
local GROUP_ID = 9744474

-- 그룹 멤버 체크 및 UI 숨기기
local function checkGroupMembership()
	local success, isInGroup = pcall(function()
		return player:IsInGroup(GROUP_ID)
	end)

	if success and isInGroup then
		freeRewardButton.Visible = false
		return true
	end
	return false
end

-- 상태 변수 - 일반 상점용 (VoidRod 제외)
local rodKeys = {
	"SliverRod",
	"GoldRod",
	"CrystalRod",
	"MagneticRod",
	"BoneRod",
	"CloverRod",
	"RainbowRod",
	"UnknownRod",
	"RobuxRod",
	"ElectricRod",
	"RealisticRod",
	"ArcaneRod"
}

-- 보이드 상점용 (VoidRod만)
local voidRodKeys = {"VoidRod"}

local target = 1
local canShop = true
local inputEnabled = true
local canBuy = true
local isVoidShop = false  -- 현재 보이드 상점 모드인지 확인

print("ShopScriptLoaded")

local function isPlayerFishing()
	return player:GetAttribute("IsFishing") == true
end

local function hasRod(itemName)
	local rods = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Rods")
	local rod = rods and rods:FindFirstChild(itemName)
	return rod and rod.Value
end

local function equippedRod(itemName)
	local rod = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("CurrentRod")
	return rod and rod.Value == itemName
end

local function hasGamepass(gamepassId)
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	return success and result
end

local function hasCompletedVoidQuest()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return false end

	local quests = leaderstats:FindFirstChild("Quests")
	if not quests then return false end

	local completedQuests = quests:FindFirstChild("CompletedQuests")
	if not completedQuests then return false end

	local voidQuest = completedQuests:FindFirstChild("void_unknown_challenge")
	return voidQuest and voidQuest.Value == true
end

local function setCharacterTransparency(char, alpha)
	for _, part in pairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.LocalTransparencyModifier = alpha
		end
	end
end

local function formatNumber(number)
	local str = tostring(number)
	local formatted = ""
	local length = #str

	for i = 1, length do
		formatted = formatted .. str:sub(i, i)
		if (length - i) % 3 == 0 and i ~= length then
			formatted = formatted .. ","
		end
	end

	return formatted
end

local function updateView(skipTween)
	skipTween = skipTween or false

	-- 현재 모드에 따라 다른 배열 사용
	local currentRodKeys = isVoidShop and voidRodKeys or rodKeys
	local rodName = currentRodKeys[target]
	local rodData = RodData.Rods[rodName]

	nameText.Text = rodName
	descText.Text = rodData.desc

	-- 보이드 로드 특별 처리
	if rodName == "VoidRod" then
		if not hasCompletedVoidQuest() then
			buyButton.AutoButtonColor = false
			buyButton.Text = "Quest Required"
		elseif hasRod(rodName) then
			buyButton.AutoButtonColor = false
			buyButton.Text = "Owned"
		else
			buyButton.AutoButtonColor = true
			buyButton.Text = "Buy"
		end
	elseif rodName == "RobuxRod" then
		-- 로벅스 로드 처리
		if hasGamepass(ROBUX_ROD_GAMEPASS_ID) then
			buyButton.AutoButtonColor = false
			buyButton.Text = "Owned"
		else
			buyButton.AutoButtonColor = true
			buyButton.Text = "Buy"
		end
	else
		-- 일반 로드 처리
		if hasRod(rodName) then
			buyButton.AutoButtonColor = false
			buyButton.Text = "Owned"
		else
			buyButton.AutoButtonColor = true
			buyButton.Text = "Buy"
		end
	end

	if equippedRod(rodName) then
		buyButton.AutoButtonColor = false
		buyButton.Text = "Equipped"
	end

	-- 가격 표시
	if rodName == "RobuxRod" then
		coinText.Text = formatNumber(rodData.price) .. " Robux"
		coinText.TextColor3 = Color3.fromRGB(0, 255, 0) -- 초록색
	elseif rodName == "VoidRod" then
		coinText.Text = formatNumber(rodData.price) .. " Coins"
		coinText.TextColor3 = Color3.fromRGB(150, 100, 255) -- 보라색
	else
		coinText.Text = formatNumber(rodData.price) .. " Coins"
		coinText.TextColor3 = originalTextColor -- 원래 색상
	end

	if not skipTween then
		local modelPosition = rodData.position

		-- 실제 모델을 찾아서 크기와 방향 고려
		local shopModel = workspace:FindFirstChild("Upgrade Shop")
		local rodModel = shopModel and shopModel:FindFirstChild(rodName)

		-- VoidRod는 다른 위치에 있을 수 있음
		if rodName == "VoidRod" then
			rodModel = workspace:FindFirstChild("VoidRodModel")
		end

		local camPos, camCF

		if rodModel then
			-- 실제 모델이 있는 경우 - 모델의 크기와 방향 고려
			local modelCFrame = rodModel:GetPrimaryPartCFrame() or rodModel:GetModelCFrame()
			local modelSize = rodModel:GetExtentsSize()

			-- 모델 크기에 따른 거리 조정
			local distance = math.max(8, modelSize.Magnitude * 1.5)
			local height = math.max(0, modelSize.Y * 0)

			local frontDirection, rightDirection

			-- VoidRod인 경우 Y축 180도 회전 적용
			if rodName == "VoidRod" then
				local rotatedCFrame = modelCFrame * CFrame.Angles(0, math.rad(180), 0)
				frontDirection = -rotatedCFrame.LookVector
				rightDirection = rotatedCFrame.RightVector
			else
				-- 일반 로드의 경우 원래 방향 사용
				frontDirection = -modelCFrame.LookVector
				rightDirection = modelCFrame.RightVector
			end

			-- 카메라를 모델의 오른쪽 측면에 배치
			camPos = modelPosition + (rightDirection * distance) + Vector3.new(0, height, 0)
			camCF = CFrame.lookAt(camPos, modelPosition + Vector3.new(0, height * 0.5, 0))

		else
			-- 모델을 찾을 수 없는 경우 - 기본 방식
			local rightOffset = Vector3.new(8, 0, 0)
			local upOffset = Vector3.new(0, 3, 0)

			camPos = modelPosition + rightOffset + upOffset
			camCF = CFrame.lookAt(camPos, modelPosition)
		end

		ts:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = camCF }):Play()
	end
end

local function openShop(voidMode)
	isVoidShop = voidMode or false

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
	end
	setCharacterTransparency(player.Character, 1)
	proximy.Enabled = false

	voidProximity.Enabled = false

	-- hotBar 숨기기
	hotBar.Visible = false

	-- Main GUI 버튼들 숨기기
	fishingButton.Visible = false
	sellButton.Visible = false
	upgradeButton.Visible = false
	freeRewardButton.Visible = false
	checkGroupMembership()

	canShop = false
	target = 1
	cam.CameraType = Enum.CameraType.Scriptable

	updateView()
	frame1.Visible = true
	frame2.Visible = true
	buyframe.Visible = true
end

local function closeShop()
	frame1.Visible = false
	frame2.Visible = false
	buyframe.Visible = false
	setCharacterTransparency(player.Character, 0)
	cam.CameraType = Enum.CameraType.Custom
	isVoidShop = false  -- 모드 리셋

	-- hotBar 다시 보이기
	hotBar.Visible = true

	-- Main GUI 버튼들 다시 보이기
	fishingButton.Visible = true
	sellButton.Visible = true
	upgradeButton.Visible = true
	freeRewardButton.Visible = true
	checkGroupMembership()

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if isPlayerFishing() then
			-- 낚시 중이므로 속도는 그대로 유지
		else
			humanoid.WalkSpeed = 16
			humanoid.JumpHeight = 7.2
		end
	end

	task.wait(0.5)
	proximy.Enabled = true
	voidProximity.Enabled = true
	canShop = true
end

-- 일반 상점 오픈
openShopRemote.OnClientEvent:Connect(function()
	if canShop then
		openShop(false) -- 일반 모드
	end
end)

-- 보이드 상점 오픈
openVoidShopEvent.OnClientEvent:Connect(function()
	if canShop then
		openShop(true) -- 보이드 모드
	end
end)

-- 보이드 상점 알림
voidShopNoticeEvent.OnClientEvent:Connect(function(title, message)
	noticeText.Text = message
	noticeText.Visible = true
	errorSound:Play()
	task.wait(2)
	noticeText.Visible = false
end)

rightButton.MouseButton1Click:Connect(function()
	if inputEnabled then
		inputEnabled = false
		local currentRodKeys = isVoidShop and voidRodKeys or rodKeys
		target = target % #currentRodKeys + 1
		updateView()
		task.wait(0.5)
		inputEnabled = true
	end
end)

leftButton.MouseButton1Click:Connect(function()
	if inputEnabled then
		inputEnabled = false
		local currentRodKeys = isVoidShop and voidRodKeys or rodKeys
		target = (target - 2) % #currentRodKeys + 1
		updateView()
		task.wait(0.5)
		inputEnabled = true
	end
end)

buyButton.MouseButton1Click:Connect(function()
	if not canBuy then return end
	canBuy = false

	local currentRodKeys = isVoidShop and voidRodKeys or rodKeys
	local rodName = currentRodKeys[target]
	local rodData = RodData.Rods[rodName]
	local leaderstats = player:FindFirstChild("leaderstats")
	local currentRod = leaderstats and leaderstats:FindFirstChild("CurrentRod")

	-- 보이드 로드 특별 처리
	if rodName == "VoidRod" then
		if not hasCompletedVoidQuest() then
			errorSound:Play()
			noticeText.Text = "Complete the Void Quest first!"
			noticeText.Visible = true
			task.wait(2)
			noticeText.Visible = false
			canBuy = true
			return
		end
	end

	-- 로벅스 로드 처리
	if rodName == "RobuxRod" then
		if hasGamepass(ROBUX_ROD_GAMEPASS_ID) then
			if currentRod and currentRod.Value ~= rodName then
				buyButton.Text = "Equipped"
				buyRemote:FireServer(rodName)
				noticeText.Text = rodName .. " equipped."
				equipSound:Play()
			else
				buyButton.Text = "Equipped"
				noticeText.Text = "Already equipped."
				errorSound:Play()
			end
			noticeText.Visible = true
			task.wait(1)
			noticeText.Visible = false
		else
			print("게임패스 구매 프롬프트 표시")
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(player, ROBUX_ROD_GAMEPASS_ID)
			end)
		end
		canBuy = true
		return
	end

	-- 일반 로드 처리
	if hasRod(rodName) then
		if currentRod and currentRod.Value ~= rodName then
			buyButton.Text = "Equipped"
			buyRemote:FireServer(rodName)
			noticeText.Text = rodName .. " equipped."
			equipSound:Play()
		else
			buyButton.Text = "Equipped"
			noticeText.Text = "Already equipped."
			errorSound:Play()
		end
		noticeText.Visible = true
		task.wait(1)
		noticeText.Visible = false
		canBuy = true
		return
	end

	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins and coins.Value >= rodData.price then
		buySound:Play()
		buyRemote:FireServer(rodName)
		buyButton.Text = "Equipped"
	else
		errorSound:Play()
		noticeText.Text = "Not enough coins."
		noticeText.Visible = true
		task.wait(1)
		noticeText.Visible = false
	end

	task.wait(0.5)
	canBuy = true
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if player == game.Players.LocalPlayer and gamePassId == ROBUX_ROD_GAMEPASS_ID then
		if wasPurchased then
			local currentRodKeys = isVoidShop and voidRodKeys or rodKeys
			local currentRodName = currentRodKeys[target]
			if currentRodName == "RobuxRod" then-- 보이드 상점을 여는 스크립트
				local voidRodEvents = game:GetService("ReplicatedStorage"):WaitForChild("VoidRodEvents")
				local openVoidShopEvent = voidRodEvents:WaitForChild("OpenVoidShop")
				local proximity = script.Parent
				proximity.Triggered:Connect(function(player)
					openVoidShopEvent:FireClient(player)
				end)
				task.wait(1)
				buyRemote:FireServer("RobuxRod")
				updateView(true)

				noticeText.Text = "RobuxRod equipped."
				noticeText.Visible = true
				equipSound:Play()
				task.wait(1)
				noticeText.Visible = false
			end
		end
	end
end)

exitButton.MouseButton1Click:Connect(closeShop)