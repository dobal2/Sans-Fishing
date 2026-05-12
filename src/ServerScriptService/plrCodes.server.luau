local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local gameDataStore = DataStoreService:GetDataStore("./gameData")

local Codes = {
	{"Sans",4000},
	{"Gamble",3000},
	{"Undyine",2000},
	{"Nyan",6000},
	{"Firework",3000},
}

local currencyName = "Coins"

-- 🆕 서버 응답 이벤트 생성
local CodeResponseEvent = Instance.new("RemoteEvent")
CodeResponseEvent.Name = "CodeResponseEvent"
CodeResponseEvent.Parent = ReplicatedStorage

local function save(p)
	local saved,failed = pcall(function()
		local usedCodes = {}
		for i, v in pairs(p.CodesFolder:GetChildren()) do
			if v.Value == true then
				table.insert(usedCodes,v.Name)
			end
		end
		gameDataStore:SetAsync(p.UserId, usedCodes)
	end)
	if not saved then warn(failed) end
end

local function load(p)
	local CodeFolder = Instance.new("Folder")
	CodeFolder.Name = "CodesFolder"
	CodeFolder.Parent = p

	for i, v in pairs(Codes) do
		local newV = Instance.new("BoolValue")
		newV.Parent = CodeFolder
		newV.Value = false
		newV.Name = v[1]
	end

	local data
	local gotdata,newplr = pcall(function()
		data = gameDataStore:GetAsync(p.UserId)
	end)
	if data and gotdata then
		for i, v in pairs(data) do
			if CodeFolder:FindFirstChild(v) then
				CodeFolder[v].Value = true
			end
		end
	end
end

-- 🔧 보안 강화된 코드 처리
ReplicatedStorage.codeEvent.OnServerEvent:Connect(function(Player, Entered)
	-- 🛡️ 입력값 검증
	if type(Entered) ~= "string" or string.len(Entered) > 50 then
		CodeResponseEvent:FireClient(Player, "invalid")
		return
	end

	local folder = Player.CodesFolder
	if not folder then
		CodeResponseEvent:FireClient(Player, "invalid")
		return
	end

	-- 🛡️ 서버에서만 코드 유효성 검증
	local isValidCode = false
	local codeReward = 0

	for i, v in pairs(Codes) do
		if v[1] == Entered then
			isValidCode = true
			codeReward = v[2]
			break
		end
	end

	if not isValidCode then
		CodeResponseEvent:FireClient(Player, "invalid")
		return
	end

	-- 코드가 존재하고 사용 가능한지 확인
	local codeValue = folder:FindFirstChild(Entered)
	if not codeValue then
		CodeResponseEvent:FireClient(Player, "invalid")
		return
	end

	if codeValue.Value == true then
		CodeResponseEvent:FireClient(Player, "already_used")
		return
	end

	-- 성공적으로 코드 사용
	codeValue.Value = true
	if Player.leaderstats and Player.leaderstats[currencyName] then
		Player.leaderstats[currencyName].Value += codeReward
	end
	CodeResponseEvent:FireClient(Player, "success", codeReward)
end)

Players.PlayerAdded:Connect(function(Player)
	load(Player)
	-- 🔧 코드 목록 전송하지 않음 (보안 강화)
end)

Players.PlayerRemoving:Connect(function(Player)
	save(Player)
end)

game:BindToClose(function()
	if RunService:IsStudio() then
		wait(1)
	else
		for _, p in pairs(Players:GetPlayers()) do
			save(p)
		end
	end
end)
