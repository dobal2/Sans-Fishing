--local fishTrapDataManager = require(game.ServerScriptService:WaitForChild("FishTrapManager"):WaitForChild("DataManager"))
--local mainDataManager = require(game.ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))

--local fishTrapDeleteEvent = ReplicatedStorage:FindFirstChild("FishTrapDeleteEvent")

---- Fish trap delete function
--local function deleteFishTrap(player)
--	print("=== Fish trap delete start ===", player.Name)

--	-- 1. Delete fish trap data from FishTrapManager DataManager
--	local fishTrapData = fishTrapDataManager:GetData(player)
--	if fishTrapData then
--		local deletedCount = 0
--		for key, value in pairs(fishTrapData) do
--			if string.find(key, "FishTrapData_") then
--				fishTrapDataManager:UpdateData(player, key, nil)
--				print("Deleted from FishTrapManager:", key)
--				deletedCount = deletedCount + 1
--			end
--		end
--		print("FishTrapManager delete complete:", deletedCount, "items")
--	else
--		print("No FishTrapManager data")
--	end

--	-- 2. Remove all fish traps belonging to this player from the world
--	local removedCount = 0
--	for _, obj in pairs(workspace:GetChildren()) do
--		local ownerValue = obj:FindFirstChild("Owner")
--		if ownerValue and ownerValue.Value == player.Name then
--			local trapIdValue = obj:FindFirstChild("TrapId")
--			if trapIdValue then
--				print("Removing fish trap from world:", trapIdValue.Value)
--				obj:Destroy()
--				removedCount = removedCount + 1
--			end
--		end
--	end
--	print("Fish traps removed from world:", removedCount, "items")

--	-- 3. Restore tool state
--	showToolParts()
--	ShowBeamEvent:FireClient(player, "hide")

--	-- Restore tool animation
--	tool.RequiresHandle = true
--	tool.ManualActivationOnly = false

--	-- 4. Notify
--	ShowNoticeEvent:FireClient(player, "FishTrap deleted successfully!")

--	print("=== Fish trap delete complete ===", player.Name)
--end

---- Delete event handler
--fishTrapDeleteEvent.OnServerEvent:Connect(function(player, action)
--	if action == "delete_fishtrap" then
--		print("Fish trap delete request received:", player.Name)
--		deleteFishTrap(player)
--	end
--end)
