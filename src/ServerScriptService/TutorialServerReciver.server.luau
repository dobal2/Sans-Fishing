-- 서버 스크립트 (ServerScriptService에 위치)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- 튜토리얼 완료 리모트 이벤트 생성 (없으면 생성)
local tutorialCompleteRemote = ReplicatedStorage:FindFirstChild("TutorialCompleteRemote")
if not tutorialCompleteRemote then
	tutorialCompleteRemote = Instance.new("RemoteEvent")
	tutorialCompleteRemote.Name = "TutorialCompleteRemote"
	tutorialCompleteRemote.Parent = ReplicatedStorage
end

-- 튜토리얼 완료 처리
tutorialCompleteRemote.OnServerEvent:Connect(function(player)
	print("🎓 플레이어", player.Name, "의 튜토리얼 완료 요청 받음")

	-- IsTutorialed 값을 true로 설정
	local isTutorialed = player:FindFirstChild("IsTutorialed")
	if isTutorialed then
		isTutorialed.Value = true
		print("✅ 서버에서", player.Name, "의 IsTutorialed를 true로 설정!")
	else
		print("⚠️ 플레이어", player.Name, "의 IsTutorialed를 찾을 수 없음")
	end

	-- 필요시 데이터 저장 등 추가 처리
	-- 예: DataStore에 튜토리얼 완료 정보 저장
end)
