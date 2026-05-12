local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 🆕 물고기 받기 전용 리모트 이벤트 생성
local FishReceiveNoticeEvent = Instance.new("RemoteEvent")
FishReceiveNoticeEvent.Name = "FishReceiveNoticeEvent"
FishReceiveNoticeEvent.Parent = ReplicatedStorage

-- 인벤토리 확장 게임패스 ID (FishingServerModule과 동일)
local INVENTORY_EXPANSION_GAMEPASS_ID = 1294285302

-- 인벤토리 확장 게임패스 확인 함수
local function hasInventoryExpansionGamepass(player)
	local success, hasGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, INVENTORY_EXPANSION_GAMEPASS_ID)
	end)

	if success then
		return hasGamepass
	else
		warn("인벤토리 확장 게임패스 확인 실패:", player.Name)
		return false
	end
end

-- 인벤토리 한도 확인 함수
local function getInventoryLimit(player)
	local baseLimit = 100
	local expandedLimit = 200

	if hasInventoryExpansionGamepass(player) then
		return expandedLimit
	else
		return baseLimit
	end
end

-- 유효한 물고기 판별 함수
local function isFish(tool)
	if not tool or not tool:IsA("Tool") then
		return false
	end
	local fishValue = tool:FindFirstChild("FishValue")
	if not fishValue then
		return false
	end
	-- pcall로 안전하게 IntValue 확인
	local success, isIntValue = pcall(function()
		return fishValue:IsA("IntValue")
	end)
	return success and isIntValue
end

-- 🔧 들고 있는 물고기까지 포함한 인벤토리 체크
local function checkInventoryLimit(player)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	local fishCount = 0

	-- 🔧 백팩에 있는 물고기 카운트
	if backpack then
		for _, item in pairs(backpack:GetChildren()) do
			if item:IsA("Tool") and item:FindFirstChild("FishValue") then
				fishCount = fishCount + 1
			end
		end
	end

	-- 🔧 들고 있는 물고기도 카운트 (핵심!)
	if character then
		for _, item in pairs(character:GetChildren()) do
			if item:IsA("Tool") and item:FindFirstChild("FishValue") then
				fishCount = fishCount + 1
			end
		end
	end

	local inventoryLimit = getInventoryLimit(player)

	print("🔧 전체 물고기 체크:", player.Name, "총 물고기:", fishCount, "한도:", inventoryLimit)

	if fishCount >= inventoryLimit then
		local hasExpansion = hasInventoryExpansionGamepass(player)
		local message = hasExpansion and
			string.format("Expanded inventory full! (%d/200) Go sell fish", fishCount) or
			string.format("Inventory full! (%d/100) Go sell fish or buy expansion pass", fishCount)
		FishReceiveNoticeEvent:FireClient(player, message)
		return false
	end
	return true
end

-- Prompt를 캐릭터에 붙이는 함수
local function addPromptToCharacter(char, owner)
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if not hrp then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ReceiveFishPrompt"
	prompt.ActionText = "Give My Fish"
	prompt.ObjectText = owner.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 1
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 6
	prompt.Parent = hrp

	prompt.Triggered:Connect(function(fromPlayer)
		if fromPlayer == owner then return end -- 자기 자신은 무시

		local senderChar = fromPlayer.Character
		if not senderChar then return end

		-- 들고 있는 Tool 중 물고기인지 확인
		local tool = senderChar:FindFirstChildWhichIsA("Tool")
		if not isFish(tool) then
			-- 물고기가 아니면 송신자에게 알림
			FishReceiveNoticeEvent:FireClient(fromPlayer, "You need to hold a fish to give!")
			return
		end

		-- 🆕 받는 사람의 인벤토리 한도 체크
		if not checkInventoryLimit(owner) then
			-- 인벤토리가 가득 찬 경우 양쪽 모두에게 알림
			FishReceiveNoticeEvent:FireClient(fromPlayer, owner.Name .. "'s inventory is full!")
			-- checkInventoryLimit 함수에서 이미 받는 사람에게 알림을 보냄
			return
		end

		local receiverBackpack = owner:FindFirstChild("Backpack")
		if receiverBackpack then
			-- 물고기 정보 가져오기
			local fishName = tool.Name or "Unknown Fish"

			-- 물고기 이전
			tool.Parent = receiverBackpack

			-- 성공 알림
			FishReceiveNoticeEvent:FireClient(fromPlayer, "Fish given to " .. owner.Name .. "!")
			FishReceiveNoticeEvent:FireClient(owner, "Received fish from " .. fromPlayer.Name .. "!")

			print("🐟 " .. fromPlayer.Name .. " gave fish (" .. fishName .. ") to " .. owner.Name)
		else
			-- 백팩을 찾을 수 없는 경우
			FishReceiveNoticeEvent:FireClient(fromPlayer, "Failed to give fish to " .. owner.Name)
		end
	end)
end

-- Player가 들어오면 캐릭터에 Prompt 부착
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		task.wait(1)
		addPromptToCharacter(char, player)
	end)
end)

-- 🆕 이미 접속한 플레이어들도 처리
for _, player in pairs(Players:GetPlayers()) do
	if player.Character then
		addPromptToCharacter(player.Character, player)
	end
	player.CharacterAdded:Connect(function(char)
		task.wait(1)
		addPromptToCharacter(char, player)
	end)
end
