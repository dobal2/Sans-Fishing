local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer
local mainGui = player.PlayerGui:WaitForChild("Main")
local button = mainGui:WaitForChild("Fishing"):WaitForChild("TextButton")
local clickSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("click")
local enable = true
local fishPoint = workspace:WaitForChild("FishPoint")

local noticeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("NoticeEventForClient")

local function getCurrentRodTool()
	local char = player.Character
	if not char then return nil end
	for _, obj in ipairs(char:GetChildren()) do
		if obj:IsA("Tool") and obj:FindFirstChild("CastRod") then
			return obj
		end
	end
	return nil
end

local function getRodFromBackpack()
	local leaderstats = player:FindFirstChild("leaderstats")
	local currentRodVal = leaderstats and leaderstats:FindFirstChild("CurrentRod")
	local rodName = currentRodVal and currentRodVal.Value ~= "" and currentRodVal.Value or "FishingRod"

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return nil end

	-- storageName 매핑 (RealisticRod → BlockyRod 등)
	local RodDataModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RodDataModule"))
	local rodData = RodDataModule.Rods and RodDataModule.Rods[rodName]
	local storageName = (rodData and rodData.storageName) or rodName

	return backpack:FindFirstChild(storageName) or backpack:FindFirstChild(rodName)
end

local function castAfterEquip(tool)
	-- ServerInit attribute가 설정될 때까지 대기 (최대 5초)
	local timeout = 5
	while not tool:GetAttribute("ServerInit") and timeout > 0 do
		task.wait(0.2)
		timeout -= 0.2
	end
	-- IsFishing이 아닐 때만 캐스트
	if not player:GetAttribute("IsFishing") then
		local autoCastEvent = tool:FindFirstChild("AutoCastEvent")
		if autoCastEvent then
			autoCastEvent:Fire()
		end
	end
end

button.MouseButton1Down:Connect(function()
	if not enable then return end

	if player:GetAttribute("IsFishing") then
		noticeEvent:Fire("You can't teleport while fishing")
		return
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid and humanoid.Sit then
			noticeEvent:Fire("You can't teleport while sitting")
			return
		end
	end

	enable = false
	character = character or player.CharacterAdded:Wait()
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and fishPoint then
		hrp.CFrame = fishPoint.CFrame
	end
	clickSound:Play()

	task.spawn(function()
		task.wait(0.3)

		-- 이미 낚싯대 들고 있으면 바로 캐스트
		local heldRod = getCurrentRodTool()
		if heldRod then
			castAfterEquip(heldRod)
		else
			-- 백팩에서 낚싯대 찾아서 장착
			local rod = getRodFromBackpack()
			if rod then
				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum:EquipTool(rod)
					castAfterEquip(rod)
				end
			end
		end
	end)

	task.wait(0.5)
	enable = true
end)
