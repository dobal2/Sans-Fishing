local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local noticeEvent = ReplicatedStorage:WaitForChild("TutorialEvent")
local sound = script.Parent:WaitForChild("Sound")

local tutorialCompleteRemote = ReplicatedStorage:WaitForChild("TutorialCompleteRemote")

local tutorialBeam = ReplicatedStorage:WaitForChild("TutorialBeam")
local fishingPoint = game.Workspace:WaitForChild("TutorialWaterPoint")
local Seller = game.Workspace:WaitForChild("Sell Shop"):WaitForChild("Seller"):WaitForChild("HumanoidRootPart")
local upgradeNpc = game.Workspace:WaitForChild("Upgrade Shop"):WaitForChild("ShopSeller"):WaitForChild("HumanoidRootPart")

local textLabel = script.Parent
local player = Players.LocalPlayer

local currentTween = nil
local currentTask = nil
local currentStep = ""
local stepCompleted = false
local tutorialStarted = false

local currentBeam = nil
local playerAttachment = nil
local targetAttachment = nil

local initialMoney = 0
local currentMoney = 0
local tutorialCompleted = false

-- Forward declarations
local showText, checkStepCompletion, removeTutorialBeam, createTutorialBeam

local function createTween(object, targetProps, duration)
	return TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), targetProps)
end

local function getPlayerMoney()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins")
		if coins then
			return coins.Value
		end
	end
	return 0
end

local function checkUpgradedRod()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rods = leaderstats:FindFirstChild("Rods")
		if rods then
			local silverRod = rods:FindFirstChild("SliverRod")

			print("Checking SliverRod:")
			if silverRod then
				print("  SliverRod value:", silverRod.Value)
				if silverRod.Value == true then
					print("SliverRod detected!")
					return true
				end
			else
				print("  SliverRod not found")
			end
		else
			print("Rods not found")
		end
	else
		print("leaderstats not found")
	end
	print("SliverRod not owned")
	return false
end



removeTutorialBeam = function()
	if currentBeam then
		currentBeam:Destroy()
		currentBeam = nil
		print("Tutorial beam removed")
	end
	if playerAttachment then
		playerAttachment:Destroy()
		playerAttachment = nil
	end
	if targetAttachment then
		targetAttachment:Destroy()
		targetAttachment = nil
	end
end

local function hideText()
	if currentTween then
		currentTween:Cancel()
	end
	if currentTask then
		local success = pcall(function()
			task.cancel(currentTask)
		end)
		currentTask = nil
	end

	currentTween = createTween(textLabel, {TextTransparency = 1, TextStrokeTransparency = 1}, 0.3)
	currentTween:Play()
	currentTween.Completed:Wait()
	textLabel.Visible = false
	currentStep = ""
	stepCompleted = false
end

local function checkMoneyIncrease()
	if tutorialCompleted then return false end

	local newMoney = getPlayerMoney()
	if newMoney > initialMoney then
		print("Coins increased:", initialMoney, "->", newMoney)

		removeTutorialBeam()
		if checkUpgradedRod() then
			tutorialCompleted = true

			task.spawn(function()
				task.wait(0.1)
				hideText()
				task.wait(0.5)
				showText("Congratulations! You've completed the tutorial!")

				tutorialCompleteRemote:FireServer()

				local isTutorialed = player:FindFirstChild("IsTutorialed")
				if isTutorialed then
					isTutorialed.Value = true
				end
			end)
		else
			task.spawn(function()
				task.wait(0.1)
				hideText()
				task.wait(0.5)
				showText("Great! Now go to the upgrade shop and buy the Silver Rod!")
				createTutorialBeam(upgradeNpc)
				currentStep = "visit_upgrade"
			end)
		end
		return true
	end
	return false
end

local function checkUpgradeStepCompletion()
	print("Upgrade step check:", "currentStep =", currentStep, "tutorialCompleted =", tutorialCompleted)

	if currentStep == "visit_upgrade" and not tutorialCompleted then
		local hasUpgradedRod = checkUpgradedRod()
		if hasUpgradedRod then
			print("SliverRod upgrade complete! Starting tutorial end sequence")
			stepCompleted = true

			tutorialCompleted = true

			removeTutorialBeam()

			task.spawn(function()
				hideText()
				task.wait(0.5)
				showText("Congratulations! You've completed the tutorial!")

				tutorialCompleteRemote:FireServer()

				local isTutorialed = player:FindFirstChild("IsTutorialed")
				if isTutorialed then
					isTutorialed.Value = true
				end
			end)
			return true
		end
	end
	return false
end

local function setupRodTracking()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rods = leaderstats:FindFirstChild("Rods")
		if rods then
			local silverRod = rods:FindFirstChild("SliverRod")

			if silverRod then
				print("SliverRod change detection set up")
				silverRod.Changed:Connect(function()
					print("SliverRod value changed:", silverRod.Value)
					if currentStep == "visit_upgrade" and not tutorialCompleted then
						checkUpgradeStepCompletion()
					end
				end)
			else
				print("SliverRod not found, cannot set up detection")
			end
		else
			print("Rods folder not found")
		end
	else
		print("leaderstats not found")
	end
end

createTutorialBeam = function(target)
	target = target or fishingPoint

	if currentBeam then
		currentBeam:Destroy()
		currentBeam = nil
	end
	if playerAttachment then
		playerAttachment:Destroy()
		playerAttachment = nil
	end
	if targetAttachment then
		targetAttachment:Destroy()
		targetAttachment = nil
	end

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	playerAttachment = Instance.new("Attachment")
	playerAttachment.Name = "TutorialPlayerAttachment"
	playerAttachment.Parent = rootPart

	targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "TutorialTargetAttachment"
	targetAttachment.Parent = target

	currentBeam = tutorialBeam:Clone()
	currentBeam.Attachment0 = targetAttachment
	currentBeam.Attachment1 = playerAttachment
	currentBeam.Parent = rootPart

	print("Tutorial beam created! Target:", target.Name)
end

local function checkRodEquipped()
	local character = player.Character
	if not character then return false end

	for _, tool in pairs(character:GetChildren()) do
		if tool:IsA("Tool") and string.sub(tool.Name, -3) == "Rod" then
			return true
		end
	end
	return false
end

local function checkFishCaught()
	return false
end

showText = function(message)
	sound:Play()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
	if currentTask then
		local success = pcall(function()
			task.cancel(currentTask)
		end)
		currentTask = nil
	end

	if string.find(message, "Welcome") then
		currentStep = "welcome"
	elseif string.find(message, "fishing rod") then
		currentStep = "equip_rod"
	elseif string.find(message, "Great") and string.find(message, "cast") then
		currentStep = "start_fishing"
		createTutorialBeam(fishingPoint)
	elseif string.find(message, "sell") then
		currentStep = "sell_fish"
		createTutorialBeam(Seller)
		initialMoney = getPlayerMoney()
		print("Initial coins:", initialMoney)
	elseif string.find(message, "upgrade") then
		currentStep = "visit_upgrade"
	elseif string.find(message, "Wait for a fish") then
		-- currentStep = "wait_for_bite" already set by event
	elseif string.find(message, "Hit the zones") then
		-- currentStep = "minigame_active" already set by event
	elseif string.find(message, "Try again") then
		currentStep = "start_fishing"
	elseif string.find(message, "Congratulations") then
		currentStep = "tutorial_complete"
	elseif string.find(message, "fishing") and not string.find(message, "Great") then
		currentStep = "start_fishing"
	elseif string.find(message, "Great") or string.find(message, "Nice") or string.find(message, "Well done") then
		-- praise message, no step change
	else
		-- other messages, no step change
	end

	stepCompleted = false

	textLabel.Text = message
	textLabel.Visible = true
	textLabel.TextTransparency = 1
	textLabel.TextStrokeTransparency = 1
	createTween(textLabel, {TextTransparency = 0, TextStrokeTransparency = 0}, 0.2):Play()

	if currentStep == "welcome" then
		currentTask = task.spawn(function()
			task.wait(2)
			hideText()
			task.wait(0.5)
			showText("Equip your fishing rod from your backpack")
		end)
	elseif currentStep == "tutorial_complete" then
		currentTask = task.spawn(function()
			task.wait(3)
			hideText()
		end)
	end

	if currentStep == "equip_rod" then
		task.spawn(function()
			task.wait(0.1)
			if checkStepCompletion then
				checkStepCompletion()
			end
		end)
	end
end

checkStepCompletion = function()
	if stepCompleted then return end

	if currentStep == "equip_rod" and checkRodEquipped() then
		stepCompleted = true
		hideText()
		task.wait(0.5)
		showText("Great! Now go to the water and click to cast your bait!")
	end
end

player.CharacterAdded:Connect(function(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and string.sub(child.Name, -3) == "Rod" then
			task.wait(0.1)
			if checkStepCompletion then
				checkStepCompletion()
			end
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and string.sub(child.Name, -3) == "Rod" then
			task.wait(0.1)
			if checkStepCompletion then
				checkStepCompletion()
			end
		end
	end)
end)

if player:FindFirstChild("Backpack") then
	player.Backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and string.sub(child.Name, -3) == "Rod" then
			task.wait(0.1)
			if checkStepCompletion then
				checkStepCompletion()
			end
		end
	end)

	player.Backpack.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and string.sub(child.Name, -3) == "Rod" then
			task.wait(0.1)
			if checkStepCompletion then
				checkStepCompletion()
			end
		end
	end)
end

player.ChildAdded:Connect(function(child)
	if child.Name == "Backpack" then
		child.ChildAdded:Connect(function(item)
			if item:IsA("Tool") and string.sub(item.Name, -3) == "Rod" then
				task.wait(0.1)
				if checkStepCompletion then
					checkStepCompletion()
				end
			end
		end)

		child.ChildRemoved:Connect(function(item)
			if item:IsA("Tool") and string.sub(item.Name, -3) == "Rod" then
				task.wait(0.1)
				if checkStepCompletion then
					checkStepCompletion()
				end
			end
		end)
	end
end)

game:GetService("RunService").Heartbeat:Connect(function()
	if currentStep == "equip_rod" then
		if checkStepCompletion then
			checkStepCompletion()
		end
	end
	if currentStep == "sell_fish" and not tutorialCompleted then
		checkMoneyIncrease()
	end
	if currentStep == "visit_upgrade" and not tutorialCompleted then
		checkUpgradeStepCompletion()
	end
end)

local function setupMoneyTracking()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins")
		if coins then
			coins.Changed:Connect(function()
				if currentStep == "sell_fish" and not tutorialCompleted then
					checkMoneyIncrease()
				end
			end)
		end
	end
end

if player:FindFirstChild("leaderstats") then
	setupMoneyTracking()
	setupRodTracking()
else
	player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			setupMoneyTracking()
			setupRodTracking()
		end
	end)
end

noticeEvent.Event:Connect(function(eventType)
	if not eventType and not tutorialStarted then
		tutorialStarted = true
		print("Tutorial auto-started!")
		if showText then
			showText("Welcome to Sans Fishing!")
		end
	end

	if eventType == "baitThrow_success" and currentStep == "start_fishing" then
		print("Bait cast successful!")
		removeTutorialBeam()
		hideText()
		task.wait(0.5)
		showText("Wait for a fish to bite your bait!")
		currentStep = "wait_for_bite"
	end

	if eventType == "minigame_started" and currentStep == "wait_for_bite" then
		print("Minigame started!")
		hideText()
		task.wait(0.3)
		showText("Hit the zones to catch the fish!")
		currentStep = "minigame_active"
	end

	if eventType == "fishing_success" and (currentStep == "start_fishing" or currentStep == "wait_for_bite" or currentStep == "minigame_active") then
		print("Fishing success detected!")
		stepCompleted = true
		removeTutorialBeam()
		hideText()
		task.wait(0.5)
		showText("Great! Now go to the shop and sell your fish!")
	end

	if eventType == "fishing_failed" and (currentStep == "start_fishing" or currentStep == "wait_for_bite" or currentStep == "minigame_active") then
		print("Fishing failed detected!")
		removeTutorialBeam()
		hideText()
		task.wait(0.5)
		showText("Try again! Click to cast your bait in the water")
		createTutorialBeam(fishingPoint)
		currentStep = "start_fishing"
	end
end)