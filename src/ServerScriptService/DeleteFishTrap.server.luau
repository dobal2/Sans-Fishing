--local fishTrapDataManager = require(game.ServerScriptService:WaitForChild("FishTrapManager"):WaitForChild("DataManager"))
--local mainDataManager = require(game.ServerScriptService:WaitForChild("leaderstats"):WaitForChild("DataManager"))

--local fishTrapDeleteEvent = ReplicatedStorage:FindFirstChild("FishTrapDeleteEvent")

---- 통발 삭제 함수
--local function deleteFishTrap(player)
--	print("=== 통발 삭제 시작 ===", player.Name)

--	-- 1. FishTrapManager DataManager에서 통발 데이터 삭제
--	local fishTrapData = fishTrapDataManager:GetData(player)
--	if fishTrapData then
--		local deletedCount = 0
--		for key, value in pairs(fishTrapData) do
--			if string.find(key, "FishTrapData_") then
--				fishTrapDataManager:UpdateData(player, key, nil)
--				print("FishTrapManager에서 삭제:", key)
--				deletedCount = deletedCount + 1
--			end
--		end
--		print("FishTrapManager 삭제 완료:", deletedCount, "개")
--	else
--		print("FishTrapManager 데이터 없음")
--	end

--	-- 2. 월드에서 해당 플레이어의 통발 모두 제거
--	local removedCount = 0
--	for _, obj in pairs(workspace:GetChildren()) do
--		local ownerValue = obj:FindFirstChild("Owner")
--		if ownerValue and ownerValue.Value == player.Name then
--			local trapIdValue = obj:FindFirstChild("TrapId")
--			if trapIdValue then
--				print("월드에서 통발 제거:", trapIdValue.Value)
--				obj:Destroy()
--				removedCount = removedCount + 1
--			end
--		end
--	end
--	print("월드에서 제거한 통발:", removedCount, "개")

--	-- 3. 도구 상태 복원
--	showToolParts()
--	ShowBeamEvent:FireClient(player, "hide")

--	-- 도구 애니메이션 복원
--	tool.RequiresHandle = true
--	tool.ManualActivationOnly = false

--	-- 4. 알림
--	ShowNoticeEvent:FireClient(player, "FishTrap deleted successfully!")

--	print("=== 통발 삭제 완료 ===", player.Name)
--end

---- 삭제 이벤트 처리
--fishTrapDeleteEvent.OnServerEvent:Connect(function(player, action)
--	if action == "delete_fishtrap" then
--		print("통발 삭제 요청 받음:", player.Name)
--		deleteFishTrap(player)
--	end
--end)
