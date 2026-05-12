-- LocalScript에서 실행해야 합니다 (StarterPlayerScripts 또는 StarterGui에 배치)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- DistanceFade 모듈을 require (모듈이 ReplicatedStorage에 있다고 가정)
local DistanceFade = require(game.ReplicatedStorage.DistanceFade) -- 모듈 경로를 실제 위치에 맞게 수정

-- DistanceFade 인스턴스 생성
local distanceFade = DistanceFade.new()

-- 애니메이션 변수들
local animationSpeed = 3 -- 움직임 속도 (높을수록 빠름)
local startTime = tick() -- 시작 시간

-- 커스텀 설정 (선택사항)
local baseSettings = {
	["DistanceOuter"] = 30,     -- 이펙트가 시작되는 거리
	["DistanceInner"] = 10,      -- 이펙트가 완전히 보이는 거리
	["EffectRadius"] = 30,      -- 이펙트 크기
	["Texture"] = "rbxassetid://18838056070", -- 텍스처 ID
	["TextureTransparency"] = 0.2,
	["TextureColor"] = Color3.fromRGB(255, 100, 100), -- 빨간색 톤
	["TextureSize"] = Vector2.new(8, 8), -- 텍스처 크기
}

-- 대각선 스크롤 애니메이션 함수
local function getDiagonalOffset(time)
	-- 오른쪽 위로 대각선 스크롤
	local progress = time * animationSpeed
	local offsetX = progress % 16 -- 16스터드마다 반복
	local offsetY = progress % 16 -- 같은 속도로 위로
	return Vector2.new(offsetX, offsetY)
end

-- 설정 적용
distanceFade:UpdateSettings(baseSettings)

-- Wall 폴더의 모든 파트에 이펙트 적용하는 함수
local function applyEffectToWallParts()
	local wallFolder = workspace:FindFirstChild("Wall")

	if not wallFolder then
		warn("Wall 폴더를 찾을 수 없습니다!")
		return
	end

	-- Wall 폴더의 모든 BasePart에 이펙트 적용
	for _, child in pairs(wallFolder:GetChildren()) do
		if child:IsA("BasePart") then
			-- 각 파트의 모든 면에 이펙트 적용 (필요한 면만 선택할 수 있음)
			distanceFade:AddFace(child, Enum.NormalId.Front)
			distanceFade:AddFace(child, Enum.NormalId.Back)
			distanceFade:AddFace(child, Enum.NormalId.Left)
			distanceFade:AddFace(child, Enum.NormalId.Right)
			distanceFade:AddFace(child, Enum.NormalId.Top)
			distanceFade:AddFace(child, Enum.NormalId.Bottom)

			print("이펙트 적용됨:", child.Name)
		end
	end

	-- 새로 추가되는 파트에도 자동으로 이펙트 적용
	wallFolder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			wait() -- 파트가 완전히 로드될 때까지 대기
			distanceFade:AddFace(child, Enum.NormalId.Front)
			distanceFade:AddFace(child, Enum.NormalId.Back)
			distanceFade:AddFace(child, Enum.NormalId.Left)
			distanceFade:AddFace(child, Enum.NormalId.Right)
			distanceFade:AddFace(child, Enum.NormalId.Top)
			distanceFade:AddFace(child, Enum.NormalId.Bottom)

			print("새 파트에 이펙트 적용됨:", child.Name)
		end
	end)

	-- 파트가 제거될 때 이펙트도 제거
	wallFolder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			-- 모든 면의 이펙트 제거
			for _, normalId in pairs(Enum.NormalId:GetEnumItems()) do
				distanceFade:RemoveFace(child, normalId)
			end

			print("파트에서 이펙트 제거됨:", child.Name)
		end
	end)
end

-- 텍스처 오프셋 업데이트 함수
local function updateTextureAnimation()
	local currentTime = tick() - startTime
	local newOffset = getDiagonalOffset(currentTime)

	-- 현재 설정을 복사하고 오프셋만 변경
	local animatedSettings = {}
	for key, value in pairs(baseSettings) do
		animatedSettings[key] = value
	end
	animatedSettings["TextureOffset"] = newOffset

	-- 업데이트된 설정 적용
	distanceFade:UpdateSettings(animatedSettings)
end

-- 애니메이션 속도 변경 함수
local function changeAnimationSpeed(newSpeed)
	animationSpeed = math.max(0.1, newSpeed) -- 최소 속도 제한
	print("애니메이션 속도 변경:", animationSpeed)
end

-- 전역 함수로 만들어서 콘솔에서 호출 가능하게 함
_G.changeAnimationSpeed = changeAnimationSpeed

-- 플레이어가 스폰될 때까지 대기
local player = Players.LocalPlayer
if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
	applyEffectToWallParts()
else
	player.CharacterAdded:Connect(function()
		applyEffectToWallParts()
	end)
end

-- 매 프레임마다 이펙트 업데이트 (필수!)
RunService.Heartbeat:Connect(function()
	-- 텍스처 애니메이션 업데이트
	updateTextureAnimation()

	-- 이펙트 업데이트
	distanceFade:Step() -- 플레이어 위치를 자동으로 사용
	-- 또는 특정 위치를 지정하려면: distanceFade:Step(Vector3.new(0, 0, 0))
end)



-- 콘솔 명령어 안내
print("=== 대각선 텍스처 애니메이션 ===")
print("애니메이션 속도 변경: changeAnimationSpeed(5) -- 숫자가 클수록 빠름")
print("현재 속도:", animationSpeed)
