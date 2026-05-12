local DataManager = require(game.ServerScriptService.leaderstats.DataManager)
local Players = game:GetService("Players")
local surfaceGui = workspace:WaitForChild("LeaderBoard"):WaitForChild("LeadBoardPart"):WaitForChild("SurfaceGui")

-- 제외할 유저 목록 (소문자로 저장하여 대소문자 구분 없이 비교)
local excludedUsernames = {
	["bluehome79"] = true,
	["tallmo_bim"] = true,
	["mkdoingsu"] = true,
	["thatcoolgamedev"] = true
}

-- 유저 이름 가져오기
local function getNameFromUserId(userId)
	local name = "Unknown"
	pcall(function()
		name = Players:GetNameFromUserIdAsync(userId)
	end)
	return name
end

-- 기존 텍스트 정리
local function clearLeaderboard()
	for _, child in pairs(surfaceGui:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

-- 제외 대상 유저인지 확인
local function shouldExcludeUser(userId)
	local name = getNameFromUserId(userId)
	-- 이름을 소문자로 변환하여 비교
	return excludedUsernames[string.lower(name)] == true
end

-- 랭킹 표시 (필터링 적용)
local function updateLeaderboardGui()
	local rawLeaderboard = DataManager:GetTopCoinPlayers(20) -- 더 많이 가져와서 필터링 후 10개 선택
	if not rawLeaderboard then return end

	-- 제외 대상 유저들을 필터링
	local filteredLeaderboard = {}
	for _, entry in ipairs(rawLeaderboard) do
		if not shouldExcludeUser(entry.UserId) then
			table.insert(filteredLeaderboard, entry)
			-- 10개가 되면 중단
			if #filteredLeaderboard >= 10 then
				break
			end
		end
	end

	clearLeaderboard()

	local lineHeight = 40
	local spacing = 4
	local startY = 0

	for i, entry in ipairs(filteredLeaderboard) do
		local name = getNameFromUserId(entry.UserId)
		local coins = entry.Coins

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, lineHeight)
		label.Position = UDim2.new(0, 0, 0, startY + (i - 1) * (lineHeight + spacing))
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Cartoon
		label.TextScaled = true
		label.RichText = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.AutoLocalize = false
		label.Text = string.format(
			'<font color="rgb(255,255,255)">%d. %s - </font><font color="rgb(255, 221, 0)">%d Coins</font>',
			i, name, coins
		)

		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 40
		constraint.MinTextSize = 10
		constraint.Parent = label

		label.Parent = surfaceGui
	end
end

-- 주기적 갱신
updateLeaderboardGui()
while true do
	task.wait(5)
	updateLeaderboardGui()
end
