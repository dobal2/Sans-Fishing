local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- 기준 해상도 (이 해상도에서 UIStroke 두께가 의도한 값)
local BASE_WIDTH = 1920
local BASE_HEIGHT = 1080

-- 각 UIStroke의 원본 두께 저장
local originalThickness = {}

local function getScale()
	local vp = camera.ViewportSize
	-- 짧은 축 기준으로 스케일 계산 (세로가 더 안정적)
	local scaleX = vp.X / BASE_WIDTH
	local scaleY = vp.Y / BASE_HEIGHT
	return math.min(scaleX, scaleY)
end

local function applyScale(gui)
	local scale = getScale()
	for _, desc in ipairs(gui:GetDescendants()) do
		if desc:IsA("UIStroke") then
			local base = originalThickness[desc]
			if base then
				desc.Thickness = math.max(0.5, base * scale)
			end
		end
	end
end

local function collectAndApply(gui)
	local scale = getScale()
	for _, desc in ipairs(gui:GetDescendants()) do
		if desc:IsA("UIStroke") then
			if not originalThickness[desc] then
				originalThickness[desc] = desc.Thickness
			end
			desc.Thickness = math.max(0.5, originalThickness[desc] * scale)
		end
	end

	-- 이후 동적으로 추가되는 UIStroke도 처리
	gui.DescendantAdded:Connect(function(desc)
		if desc:IsA("UIStroke") then
			task.defer(function()
				if not desc.Parent then return end
				if not originalThickness[desc] then
					originalThickness[desc] = desc.Thickness
				end
				desc.Thickness = math.max(0.5, originalThickness[desc] * getScale())
			end)
		end
	end)
end

-- ViewportSize 변경 시 전체 재적용
local lastVP = camera.ViewportSize
camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	local newVP = camera.ViewportSize
	if newVP == lastVP then return end
	lastVP = newVP

	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		applyScale(playerGui)
	end
end)

-- PlayerGui 로드 대기 후 초기 적용
local playerGui = player:WaitForChild("PlayerGui")

-- ScreenGui들이 복제되길 잠깐 기다림
task.wait(0.5)
collectAndApply(playerGui)
