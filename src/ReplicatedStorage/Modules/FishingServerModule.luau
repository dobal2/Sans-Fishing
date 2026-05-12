-- FishingServerModule (ModuleScript in ReplicatedStorage.Modules)
local MarketplaceService = game:GetService("MarketplaceService")
local BadgeService = game:GetService("BadgeService")
local SANS_BADGE_ID = 2468526859123734


-- 🆕 설정 (원하는 게임패스 ID로 변경)
local RETRY_GAMEPASS_ID = 1290056221
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FishData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDataModule"))
local CastSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Fishing Rod Cast")
local FishingSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Fishing Rod Reel")
local GetSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("GetSound")
local FishGetEffect = ReplicatedStorage:WaitForChild("Particle"):WaitForChild("GetFishParticle")
local TweenService = game:GetService("TweenService")
local FishingServer = {}
FishingServer.__index = FishingServer

function FishingServer.init(tool)
	print("Fishing Server Init")
	local self = setmetatable({}, FishingServer)
	self.tool = tool

	self.castEvent = tool:WaitForChild("CastRod")
	self.remote = tool:WaitForChild("RemoteEvent")
	self.cancelled = false
	self.baitPart = nil
	self.rope = nil
	self.activated = false
	self.isReeling = false
	self.character = nil
	self.player = nil
	self.hasUsedRetry = false

	self:_bindEvents()

	local Players = game:GetService("Players")
	self.playerLeavingConnection = Players.PlayerRemoving:Connect(function(leavingPlayer)
		if self.player == leavingPlayer then
			print("🚪 플레이어 나감: 물린 물고기 제거")
			if self.hookedFishHandle then
				self.hookedFishHandle:Destroy()
				self.hookedFishHandle = nil
			end
			self:_cleanup()
		end
	end)

	return self
end



-- 🆕 변이 접두사 자동 제거 함수 (FishingServerModule 상단에 추가)
local function getBaseFishName(fishName)
	if not fishName then return nil end

	-- 🚀 FishData에서 모든 기본 물고기 이름 가져오기
	local FishData = require(game.ReplicatedStorage.Modules:WaitForChild("FishDataModule"))
	local allBaseFishNames = {}

	-- 모든 등급에서 기본 물고기 이름 수집
	for _, rarity in ipairs(FishData.Rarities) do
		for _, fish in ipairs(rarity.fishes) do
			allBaseFishNames[fish.fishName] = true
		end
	end

	-- 🔍 현재 이름이 이미 기본 물고기 이름인지 확인
	if allBaseFishNames[fishName] then
		--print("✅ 기본 물고기:", fishName)
		return fishName
	end

	-- 🔧 자동 매칭: 끝부분이 기본 물고기 이름과 일치하는지 확인
	for baseName, _ in pairs(allBaseFishNames) do
		-- "Frozen Bass" → "Bass"로 매칭
		if string.sub(fishName, -(#baseName)) == baseName then
			-- 앞에 공백이 있는지 확인 (정확한 매칭)
			local prefixLength = #fishName - #baseName
			if prefixLength > 0 and string.sub(fishName, prefixLength, prefixLength) == " " then
				--print("🔄 자동 변이 제거:", fishName, "→", baseName)
				return baseName
			end
		end
	end

	-- 🔧 백업: 마지막 단어만 추출 (공백 기준)
	local words = {}
	for word in string.gmatch(fishName, "%S+") do
		table.insert(words, word)
	end

	if #words > 1 then
		local lastWord = words[#words]
		local secondLastWord = words[#words - 1] or ""

		-- 마지막 두 단어 조합 시도 ("Golden Trout")
		local lastTwoWords = secondLastWord .. " " .. lastWord
		if allBaseFishNames[lastTwoWords] then
			print("🔄 마지막 두 단어로 매칭:", fishName, "→", lastTwoWords)
			return lastTwoWords
		end

		-- 마지막 단어만 시도 ("Bass")
		if allBaseFishNames[lastWord] then
			print("🔄 마지막 단어로 매칭:", fishName, "→", lastWord)
			return lastWord
		end
	end

	-- 🤷 매칭 실패 시 원본 반환
	print("⚠️ 기본 물고기 매칭 실패:", fishName, "→ 원본 사용")
	return fishName
end


function FishingServer:_hasRetryGamepass(player)
	local success, hasGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, RETRY_GAMEPASS_ID)
	end)

	if success then
		return hasGamepass
	else
		warn("게임패스 확인 실패:", player.Name)
		return false
	end
end

local function getBaseToolName(fullToolName)
	if not fullToolName then return "FishingRod" end

	-- [인첸트명] 도구명 형식에서 도구명만 추출
	local enchantName, toolName = fullToolName:match("^%[(.+)%] (.+)")
	if enchantName and toolName then
		return toolName  -- 순수 도구명 반환
	else
		return fullToolName  -- 인첸트가 없는 경우 원본 반환
	end
end


function FishingServer:_bindEvents()
	self.castEvent.OnServerEvent:Connect(function(player, targetPos)
		if self.activated or self.isReeling then return end

		if not self:_checkInventoryLimit(player) then
			warn("Security: Cannot start fishing, inventory full for", player.Name)
			return
		end

		self.player = player
		self.character = player.Character
		if not self.character then return end
		player:SetAttribute("IsFishing", true)

		local humanoid = self.character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		-- 플레이어 속도 제한 먼저 설정
		self.isReeling = true
		self.activated = true
		humanoid:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)
		humanoid:SetAttribute("OriginalJumpHeight", humanoid.JumpHeight)
		humanoid:SetAttribute("OriginalUseJumpPower", humanoid.UseJumpPower)
		humanoid.WalkSpeed = 0
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = 0
		humanoid.Jump = false

		self.remote:FireClient(player, "play_fishing_animation")

		local newCastSound = CastSound:Clone()
		newCastSound.Parent = self.tool.Handle or self.tool
		newCastSound.RollOffMode = Enum.RollOffMode.Linear
		newCastSound.EmitterSize = 5
		newCastSound.MaxDistance = 100
		newCastSound.Volume = 1
		newCastSound:Play()


		local animationDelay = 0.35
		task.spawn(function()
			task.wait(animationDelay)

			if not self.cancelled and self.player == player then
				self:_createBait()
				self:_setupRope()
				self:_moveBaitTo(targetPos)

				-- 🆕 대기 애니메이션 시작 명령 (던진 후 0.5초 뒤)
				task.spawn(function()
					task.wait(0.5)
					if not self.cancelled and self.player == player then
						self.remote:FireClient(player, "play_waiting_animation")
						print("🎬 서버: 대기 애니메이션 명령 전송")
					end
				end)

				self:_checkMaterial()
			end
		end)
	end)

	self.remote.OnServerEvent:Connect(function(player, action, payload)
		if action == "progress_success" then
			-- 보안 검증 추가
			if not self.fishInfo or not self.sessionId then
				warn("Security: No active fishing session for", player.Name)
				self:_resolveFishing(player, "fail")
				return
			end

			if not self.gameStartTime then
				warn("Security: No game start time for", player.Name)
				self:_resolveFishing(player, "fail")
				return
			end

			local gameTime = tick() - self.gameStartTime
			if gameTime < 0.5 then
				warn("Security: Game completed too quickly:", gameTime, "seconds by", player.Name)
				player:Kick("Suspicious fishing behavior detected")
				return
			end

			if not self:_checkInventoryLimit(player) then
				warn("Security: Inventory full at success time for", player.Name)
				self:_resolveFishing(player, "fail")
				return
			end

			self:_resolveFishing(player, "success")

		elseif action == "check_retry" then
			if not self.hasUsedRetry and self:_hasRetryGamepass(player) then
				self.hasUsedRetry = true
				self.remote:FireClient(player, "retry_granted")
			else
				self:_resolveFishing(player, "fail")
			end

		elseif action == "cancel" then
			self:_resolveFishing(player, "cancel")

		else
			warn("Security: Unknown action:", action, "from", player.Name)
		end
	end)

	self.tool.Unequipped:Connect(function()
		self.cancelled = true
		if self.player and self.player:IsA("Player") then
			self.player:SetAttribute("IsFishing", false)
			self.remote:FireClient(self.player, false)
		end

		if self.hookedFishHandle then
			print("🗑️ 도구 해제: 물린 물고기 제거")
			self.hookedFishHandle:Destroy()
			self.hookedFishHandle = nil
		end

		self:_resetPlayer()
		self:_cleanup()
	end)
end


function FishingServer:_getValidatedToolConfig(player)
	-- 🛡️ Config 모듈 불러오기
	local Config = require(game.ReplicatedStorage.Modules:WaitForChild("FishingConfigModule"))

	-- 🛡️ 서버에서 실제 도구 확인
	if not player.Character then
		warn("Security: Player has no character")
		return nil
	end

	-- 실제로 장착된 도구가 self.tool과 같은지 확인
	local equippedTool = nil
	for _, obj in pairs(player.Character:GetChildren()) do
		if obj:IsA("Tool") and obj == self.tool then
			equippedTool = obj
			break
		end
	end

	if not equippedTool then
		warn("Security: Tool not equipped by", player.Name)
		return nil
	end

	-- 🛡️ 서버에 저장된 원본 도구명 사용 (클라이언트 조작 무시)
	local originalToolName = self.originalToolName

	-- 🛡️ Config에서 해당 도구 설정 확인
	local toolConfig = Config[originalToolName]
	if not toolConfig then
		warn("Security: Invalid tool name:", originalToolName, "from", player.Name)
		return nil
	end

	print("🛡️ Validated tool:", originalToolName, "DifficultyMod:", toolConfig.DifficultyMod)
	return toolConfig, originalToolName
end


function FishingServer:_createBait()
	self.baitPart = Instance.new("Part")
	self.baitPart.Massless = true
	self.baitPart.Name = "Bait"
	self.baitPart.Size = Vector3.new(0.4, 0.4, 0.4)
	self.baitPart.Shape = Enum.PartType.Block
	self.baitPart.Anchored = false
	self.baitPart.CanCollide = true
	self.baitPart.BrickColor = BrickColor.new("Bright orange")
	self.baitPart.Material = Enum.Material.Plastic
	self.baitPart.CustomPhysicalProperties = PhysicalProperties.new(5, 0.8, 0.2, 1, 1)
	self.baitPart.Massless = true
	self.baitPart.Parent = workspace

	local touched = false
	self.baitPart.Touched:Connect(function(hit)
		if touched then return end
		if hit.Name ~= "Water" and hit.CanCollide and hit.Anchored then
			touched = true
			-- 원래 코드를 이렇게 수정
			if self.baitPart and self.baitPart.Parent then
				pcall(function()
					self.baitPart.AssemblyLinearVelocity = Vector3.zero
					self.baitPart.AssemblyAngularVelocity = Vector3.zero
				end)

				local success, err = pcall(function()
					local bodyPosition = Instance.new("BodyPosition")
					bodyPosition.MaxForce = Vector3.new(4000, 4000, 4000)
					bodyPosition.Position = self.baitPart.Position
					bodyPosition.D = 1000
					bodyPosition.P = 10000
					bodyPosition.Parent = self.baitPart
				end)

				if not success then
					warn("BodyPosition 생성 실패:", err)
				end
			end
		end
	end)
end



-- 🔧 _validateAttempt 함수 수정 (DifficultyMod 에러 해결)

function FishingServer:_validateAttempt(player, payload)
	if not self.fishInfo or not payload or type(payload) ~= "table" then
		print("❌ 검증 실패: fishInfo 또는 payload 없음")
		return
	end

	-- 세션 불일치 체크
	if payload.SessionId ~= self.sessionId then
		warn("🚨 세션 불일치 차단:", player.Name, "예상:", self.sessionId, "받음:", payload.SessionId)
		self:_resolveFishing(player, "fail")
		return
	end

	-- 서버 스팸 방지
	local currentTime = tick()
	if self.lastServerAttempt and (currentTime - self.lastServerAttempt) < 0.15 then
		warn("🚨 서버 스팸 차단:", player.Name)
		return
	end
	self.lastServerAttempt = currentTime

	-- 서버에서 인벤토리 체크
	if not self:_checkInventoryLimit(player) then
		warn("🚨 인벤토리 가득참으로 낚시 차단:", player.Name)
		self:_resolveFishing(player, "fail")
		return
	end

	-- 기본 보안 검증
	if not self:_validateBasicSecurity(player, "attempt") then
		warn("🚨 보안 검증 실패! 실패 처리:", player.Name)
		self:_resolveFishing(player, "fail")
		return
	end

	local sL = payload.SliderPos.Left
	local sR = payload.SliderPos.Right
	local hL = payload.HitZone.Left
	local hR = payload.HitZone.Right

	local success = sR >= hL and sL <= hR

	if success then
		self.successCount = (self.successCount or 0) + 1

		-- 순수 도구명 추출 (인챈트 제거)
		local baseToolName = getBaseToolName(self.tool.Name)
		local Config = require(game.ReplicatedStorage.Modules:WaitForChild("FishingConfigModule"))
		local difficultyMod = 1  -- 기본값

		-- 플레이어의 인챈트 정보를 포함한 설정 가져오기
		local playerConfig = Config.GetPlayerRodConfig(player, baseToolName)
		if playerConfig and playerConfig.DifficultyMod then
			difficultyMod = playerConfig.DifficultyMod
			print("시도 중 - 플레이어 인챈트 포함 난이도:", baseToolName, "=", difficultyMod)
		else
			-- 백업: 기본 설정만 사용
			local basicConfig = Config.GetBaseRodConfig(baseToolName)
			if basicConfig and basicConfig.DifficultyMod then
				difficultyMod = basicConfig.DifficultyMod
				print("기본 설정만 사용:", baseToolName, "=", difficultyMod)
			end
		end

		self.currentDifficultyMod = difficultyMod

		local difficulty = require(game.ReplicatedStorage.Modules:WaitForChild("FishDifficultyModule"))
			.GetModifiedSetting(self.fishInfo.name, difficultyMod)

		if self.successCount >= difficulty.attempts then
			self:_resolveFishing(player, "success")
		else
			local newSessionId = game:GetService("HttpService"):GenerateGUID(false)
			self.sessionId = newSessionId
			self.lastServerAttempt = nil

			self.remote:FireClient(player, {
				rarity = self.fishInfo.name,
				sessionId = newSessionId,
				nextAttempt = true,
				toolName = baseToolName,  -- 순수 도구명 사용
				difficultyMod = difficultyMod
			})
		end
	else
		print("💥 실패!")
		if not self.hasUsedRetry and self:_hasRetryGamepass(player) then
			self.hasUsedRetry = true
			print("🎟️ 게임패스 재시도 발동!")

			local newSessionId = game:GetService("HttpService"):GenerateGUID(false)
			self.sessionId = newSessionId
			self.lastServerAttempt = nil

			-- 순수 도구명 사용
			local baseToolName = getBaseToolName(self.tool.Name)

			-- 원래 난이도 사용
			local difficultyMod = self.currentDifficultyMod
			if not difficultyMod then
				local Config = require(game.ReplicatedStorage.Modules:WaitForChild("FishingConfigModule"))
				local playerConfig = Config.GetPlayerRodConfig(player, baseToolName)
				difficultyMod = 1

				if playerConfig and playerConfig.DifficultyMod then
					difficultyMod = playerConfig.DifficultyMod
				else
					local basicConfig = Config.GetBaseRodConfig(baseToolName)
					if basicConfig and basicConfig.DifficultyMod then
						difficultyMod = basicConfig.DifficultyMod
					end
				end
				self.currentDifficultyMod = difficultyMod
			end

			print("🎟️ 재시도 난이도:", difficultyMod)

			self.remote:FireClient(player, {
				rarity = self.fishInfo.name,
				sessionId = newSessionId,
				nextAttempt = true,
				toolName = baseToolName,  -- 순수 도구명 사용
				difficultyMod = difficultyMod,
				isRetry = true
			})

			game:GetService("ReplicatedStorage"):WaitForChild("FishNoticeEvent"):FireClient(
				player,
				"🎟️ Gamepass Retry! One more chance!"
			)

			return
		end
		self:_resolveFishing(player, "fail")
	end
end

function FishingServer:_validateBasicSecurity(player, action)
	-- 도구 소유권 확인 (더 관대하게)
	if not player.Character then
		warn("Security: Player has no character:", player.Name)
		return false
	end

	-- 도구가 캐릭터에 있는지 확인 (더 유연하게)
	local hasTool = false
	for _, obj in pairs(player.Character:GetChildren()) do
		if obj:IsA("Tool") and obj.Name == self.tool.Name then
			hasTool = true
			break
		end
	end

	if not hasTool then
		print("⚠️ Security: Tool not found but allowing:", player.Name)
		-- 도구가 없어도 그냥 진행 (너무 엄격하지 않게)
	end

	-- 낚시 상태 확인 (더 관대하게)
	if not player:GetAttribute("IsFishing") then
		print("⚠️ Security: Player not fishing but allowing:", player.Name)
		-- 낚시 상태가 아니어도 그냥 진행
	end

	-- 올바른 플레이어인지 확인
	if player ~= self.player then
		warn("Security: Wrong player:", player.Name, "Expected:", self.player and self.player.Name)
		return false -- 이건 확실히 차단
	end

	-- 스팸 방지 (조금 더 관대하게)
	local now = tick()
	self.lastAction = self.lastAction or 0
	if now - self.lastAction < 0.01 then -- 0.05에서 0.01로 완화
		warn("Security: Too fast action from", player.Name)
		return false
	end
	self.lastAction = now

	return true
end


local INVENTORY_EXPANSION_GAMEPASS_ID = 1294285302

-- 🆕 인벤토리 확장 게임패스 확인 함수 (기존 _hasRetryGamepass 함수 아래에 추가)
function FishingServer:_hasInventoryExpansionGamepass(player)
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

function FishingServer:_getInventoryLimit(player)
	local baseLimit = 100
	local expandedLimit = 200  -- 100개 추가

	if self:_hasInventoryExpansionGamepass(player) then
		return expandedLimit
	else
		return baseLimit
	end
end


function FishingServer:_checkInventoryLimit(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return true end

	local totalItemCount = 0

	-- 🔧 로컬 IsRod 함수 사용 (self:_isRodTool 대신)
	local function IsRod(itemName)
		if not itemName then return false end
		itemName = itemName:lower()
		return itemName:match("rod$") ~= nil or
			itemName:match("trap") ~= nil
	end

	-- 🔧 모든 도구 카운트 (낚싯대와 통발 제외)
	for _, item in pairs(backpack:GetChildren()) do
		if item:IsA("Tool") then
			if not IsRod(item.Name) then
				totalItemCount = totalItemCount + 1
			end
		end
	end

	-- 인벤토리 한도 확인
	local inventoryLimit = self:_getInventoryLimit(player)

	if totalItemCount >= inventoryLimit then
		-- 클라이언트에 알림 전송
		local noticeEvent = game:GetService("ReplicatedStorage"):FindFirstChild("FishNoticeEvent")
		if noticeEvent then
			local hasExpansion = self:_hasInventoryExpansionGamepass(player)
			local message = hasExpansion and
				"Expanded inventory full! Go sell fish (Max 200)" or
				"Inventory full! Go sell fish or buy expansion pass (Max 100)"
			noticeEvent:FireClient(player, message)
		end
		return false
	end

	return true
end



function FishingServer:_setupRope()
	local baitAttachment = Instance.new("Attachment", self.baitPart)

	-- 🔧 순수 도구명 추출 (인첸트 제거)
	local baseToolName = getBaseToolName(self.tool.Name)
	local handleAttachment

	if baseToolName == "RealisticRod" or baseToolName == "VoidRod" then
		-- RealisticRod의 경우 특별 처리
		print("RealisticRod 감지 - 커스텀 로프 위치 설정")

		-- Pier 파트 찾기
		local pierPart = self.tool.Handle:FindFirstChild("Pier")

		if pierPart then
			print("Pier 파트 발견:", pierPart.Name, "크기:", pierPart.Size)

			-- 기존 Att0 삭제 (잘못된 위치에 있을 수 있음)
			local existingAtt = pierPart:FindFirstChild("Att0")
			if existingAtt then
				existingAtt:Destroy()
				print("Pier의 기존 Att0 제거")
			end

			-- Pier 파트에 새로운 Attachment 생성
			handleAttachment = Instance.new("Attachment")
			handleAttachment.Name = "Att0"
			handleAttachment.Parent = pierPart  -- Pier 파트에 부착

			-- Pier 파트의 가장 위쪽으로 위치 설정
			handleAttachment.Position = Vector3.new(0, pierPart.Size.Y/2, 0)  -- Pier 위쪽 끝

			print("RealisticRod Pier 로프 위치 설정:", handleAttachment.Position)
			print("Pier 파트 크기:", pierPart.Size, "최종 위치:", pierPart.Position + handleAttachment.Position)

		else
			-- Pier 파트가 없으면 Handle에서 찾기 (백업)
			warn("Pier 파트를 찾을 수 없습니다. Handle 사용")
			print("Handle 내부 파트들:")
			for _, child in pairs(self.tool.Handle:GetChildren()) do
				if child:IsA("BasePart") then
					print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
				end
			end

			-- 기존 방식으로 Handle에 생성
			local existingAtt = self.tool.Handle:FindFirstChild("Att0")
			if existingAtt then
				existingAtt:Destroy()
				print("Handle의 기존 Att0 제거")
			end

			handleAttachment = Instance.new("Attachment")
			handleAttachment.Name = "Att0"
			handleAttachment.Parent = self.tool.Handle
			handleAttachment.Position = Vector3.new(0, self.tool.Handle.Size.Y/2 + 0.5, 0)

			print("RealisticRod Handle 로프 위치 설정:", handleAttachment.Position)
		end
	elseif baseToolName == "MagneticRod" then
		print("MagneticRod 감지 - 기존 어태치먼트 찾기")

		local pierPart = self.tool.Handle:FindFirstChild("Part")
		if pierPart then
			print("Part 발견, 내부 어태치먼트 검색 중...")

			-- Part 안에서 기존 어태치먼트 찾기
			local existingAttachment = nil
			for _, child in pairs(pierPart:GetChildren()) do
				if child:IsA("Attachment") then
					print("발견된 어태치먼트:", child.Name, "위치:", child.Position)
					existingAttachment = child
					break
				end
			end

			if existingAttachment then
				print("기존 어태치먼트 사용:", existingAttachment.Name)
				handleAttachment = existingAttachment
			else
				warn("Part 안에 어태치먼트가 없어서 새로 생성")
				handleAttachment = Instance.new("Attachment")
				handleAttachment.Name = "Att0"
				handleAttachment.Parent = pierPart
				handleAttachment.Position = Vector3.new(0, pierPart.Size.Y/2, 0)
			end
		else
			warn("Part를 찾을 수 없음")
			handleAttachment = Instance.new("Attachment")
			handleAttachment.Name = "Att0"
			handleAttachment.Parent = self.tool.Handle
			handleAttachment.Position = Vector3.new(0, self.tool.Handle.Size.Y/2, 0)
		end

	else
		-- 다른 낚싯대들은 기존 방식 유지
		handleAttachment = self.tool.Handle:FindFirstChild("Att0") or Instance.new("Attachment", self.tool.Handle)
		if not handleAttachment.Name then handleAttachment.Name = "Att0" end
		print("일반 낚싯대 - 기존 로프 위치 사용")
	end

	self.rope = Instance.new("RopeConstraint")
	self.rope.Attachment0 = handleAttachment
	self.rope.Attachment1 = baitAttachment
	self.rope.Visible = true
	self.rope.Thickness = 0.05
	self.rope.Length = 50
	self.rope.Color = BrickColor.new("White")

	-- 핵심 수정: 물리 반발 완전 제거
	self.rope.Restitution = 0  -- 0으로 설정 (기존: 0.3)

	-- 로프 물리 최적화 설정 추가
	self.rope.WinchEnabled = false  -- 윈치 비활성화
	self.rope.WinchSpeed = 0       -- 윈치 속도 0
	self.rope.WinchResponsiveness = 0  -- 윈치 반응성 0

	self.rope.Parent = self.tool.Handle

	-- 추가: 도구 핸들을 더 무겁게 설정 (끌려가는 것 방지)
	if self.tool.Handle then
		-- 원래 물리 속성 저장
		self.originalPhysicalProperties = self.tool.Handle.CustomPhysicalProperties
	end
end

function FishingServer:_cleanup()
	if self.baitPart then self.baitPart:Destroy() end
	if self.rope then self.rope:Destroy() end

	-- 🆕 도구 핸들 물리 속성 복원
	if self.tool and self.tool.Handle then
		self.tool.Handle.CustomPhysicalProperties = self.originalPhysicalProperties
	end

	-- 🔊 사운드 정리
	if self.fishingSoundLoop then
		self.fishingSoundLoop:Stop()
		self.fishingSoundLoop:Destroy()
		self.fishingSoundLoop = nil
	end



	-- 변수 초기화
	self.baitPart = nil
	self.rope = nil
	self.activated = false
	self.isReeling = false
	self.player = nil
	self.character = nil
	self.cancelled = false
	self.gameStartTime = nil
	self.sessionId = nil
	self.originalPhysicalProperties = nil
end

function FishingServer:_moveBaitTo(targetPos)
	local origin = self.tool.Handle.Position + Vector3.new(0, 3, 0)

	-- 💡 방향 벡터만 사용하고, 거리 고정 (70 + 위로 230)
	local direction = (targetPos - origin).Unit
	local velocity = direction * 70 + Vector3.new(0, 230, 0)

	self.baitPart.Position = origin
	self.baitPart.AssemblyLinearVelocity = velocity

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(0, 3000, 0)
	bodyVelocity.Velocity = Vector3.new(0, -60, 0)
	bodyVelocity.Parent = self.baitPart

	task.delay(0.3, function()
		if bodyVelocity and bodyVelocity.Parent then
			bodyVelocity:Destroy()
		end
	end)
end

local function getScaleRatio(weight, minWeight, maxWeight, maxScale)
	local clampedWeight = math.clamp(weight, minWeight, maxWeight)
	local t = (clampedWeight - minWeight) / (maxWeight - minWeight)
	return 1 + (maxScale - 1) * t
end


-- 🎣 수정된 퀘스트 진행도 업데이트 함수
function FishingServer:_updateQuestProgress(player, fishName)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local quests = leaderstats:FindFirstChild("Quests")
	if not quests then return end

	local activeQuests = quests:FindFirstChild("ActiveQuests")
	if not activeQuests then return end

	-- 🆕 기본 물고기 이름 추출 (변이 제거)
	local baseFishName = getBaseFishName(fishName)

	print("🔍 퀘스트 체크:", "원본 =", fishName, "/ 기본 =", baseFishName)

	-- 모든 활성 퀘스트 확인
	for _, quest in pairs(activeQuests:GetChildren()) do
		if quest:IsA("Folder") then
			local targetFish = quest:FindFirstChild("TargetFish")
			local currentProgress = quest:FindFirstChild("CurrentProgress")
			local requiredProgress = quest:FindFirstChild("RequiredProgress")
			local isReceived = quest:FindFirstChild("IsReceived")
			local questName = quest:FindFirstChild("QuestName")

			if targetFish and currentProgress and requiredProgress and isReceived and questName then
				-- 🔧 퀘스트를 받았고, 아직 완료하지 않았다면
				if isReceived.Value and currentProgress.Value < requiredProgress.Value then
					-- 🆕 기본 이름과 타겟 물고기 이름 둘 다 체크
					local isMatch = false

					-- 1. 정확한 이름 매칭
					if targetFish.Value == fishName then
						isMatch = true
						print("✅ 정확한 이름 매칭:", fishName)
						-- 2. 기본 이름으로 매칭 (변이 처리)
					elseif targetFish.Value == baseFishName then
						isMatch = true
						print("✅ 기본 이름 매칭:", baseFishName, "(원본:", fishName, ")")
						-- 3. 타겟이 기본 이름이고 잡은 물고기가 변이인 경우
					elseif baseFishName and getBaseFishName(targetFish.Value) == baseFishName then
						isMatch = true
						print("✅ 변이 매칭:", targetFish.Value, "←→", fishName)
					end

					if isMatch then
						currentProgress.Value = currentProgress.Value + 1

						print("🎣 퀘스트 진행 (낚시):", player.Name, "→", questName.Value, currentProgress.Value .. "/" .. requiredProgress.Value)
						print("📝 매칭된 물고기:", "타겟=" .. targetFish.Value, "잡은것=" .. fishName, "기본=" .. baseFishName)

						-- 완료 조건을 만족했다면 알림
						if currentProgress.Value >= requiredProgress.Value then
							print("🏆 퀘스트 달성 (낚시):", player.Name, "→", questName.Value)
						end
					else
						print("❌ 매칭 실패:", "타겟=" .. targetFish.Value, "잡은것=" .. fishName, "기본=" .. baseFishName)
					end
				end
			end
		end
	end
end

function FishingServer:_checkMaterial()
	local touched = false
	self.baitPart.Touched:Connect(function(hit)
		if touched then return end
		if not self.player then return end

		local isWater = (
			hit.Name == "Water"
				or hit.Material == Enum.Material.Water
				or hit:IsA("Terrain")
		)

		if isWater then
			touched = true

			if not self.activated then return end
			self.activated = false

			self.gameStartTime = tick()
			self.hasUsedRetry = false

			self.baitPart.AssemblyAngularVelocity = Vector3.zero
			local bodyPosition = Instance.new("BodyPosition")
			bodyPosition.MaxForce = Vector3.new(1000,50, 1000)
			bodyPosition.Position = self.baitPart.Position
			bodyPosition.D = 1000
			bodyPosition.P = 5000
			bodyPosition.Parent = self.baitPart

			local sessionId = game:GetService("HttpService"):GenerateGUID(false)
			self.sessionId = sessionId
			self.successCount = 0

			task.wait(math.random(2, 3))

			if self.cancelled then return end
			if self.sessionId ~= sessionId then
				print("이전 세션 무시됨")
				return
			end

			if not self.tool or not self.tool:IsDescendantOf(game) then return end
			if not self.player or not self.player:IsDescendantOf(game.Players) then return end

			self.fishingSoundLoop = FishingSound:Clone()
			self.fishingSoundLoop.Name = "Fishing Reel Sound"
			self.fishingSoundLoop.Parent = self.tool.Handle or self.tool
			self.fishingSoundLoop.RollOffMode = Enum.RollOffMode.Linear
			self.fishingSoundLoop.EmitterSize = 5
			self.fishingSoundLoop.MaxDistance = 100
			self.fishingSoundLoop.Volume = 1
			self.fishingSoundLoop.Looped = true
			self.fishingSoundLoop:Play()

			-- 🔧 핵심 수정: 순수 도구명 사용
			local baseToolName = getBaseToolName(self.tool.Name)
			local fishInfo = FishData.GetRandomFish(baseToolName, self.player)  -- 순수 도구명 사용
			fishInfo.rarity = fishInfo.name
			self.fishInfo = fishInfo

			-- 물고기 모델 생성
			local toolModel = fishInfo.model
			local handle = toolModel:FindFirstChild("Handle")

			if handle then
				local fakeHandle = handle:Clone()
				local ratio = getScaleRatio(fishInfo.weight, fishInfo.minWeight, fishInfo.maxWeight, 5)

				if self.player and self.player:GetAttribute("SizeBubbleBuff") == true then
					ratio = ratio * 1.35
					print("사이즈 버블 버프 적용 - 미끼 물고기 크기 35% 증가!")
				end

				self.remote:FireClient(self.player, "keep_waiting_animation")
				fakeHandle.Size = fakeHandle.Size * ratio

				local highLight = Instance.new("Highlight")
				highLight.FillTransparency = 1
				highLight.OutlineTransparency = 0
				highLight.OutlineColor = Color3.new(1,1,1)
				highLight.Parent = fakeHandle

				fakeHandle.Anchored = false
				fakeHandle.CanCollide = false
				fakeHandle.Massless = true
				fakeHandle.Name = "FlyingFish"
				fakeHandle.CFrame = self.baitPart.CFrame
				fakeHandle.Parent = workspace

				fakeHandle.AssemblyLinearVelocity = Vector3.new(0, -10, 0)

				-- 얼음 효과 등 처리 (기존 코드와 동일)
				local weatherInfo = FishData.GetWeatherInfo()
				if weatherInfo and weatherInfo.isActive and weatherInfo.currentWeather == "Snow" then
					if fishInfo.fishName and string.find(fishInfo.fishName, "Frozen") then
						local function createHookedFishIceBlock(targetPart, fishWeight)
							local sizeMultiplier = 1.05
							if fishWeight then
								local weightMultiplier = 1.0 + (fishWeight - 1) * 0.01
								weightMultiplier = math.max(0.9, math.min(1.5, weightMultiplier))
								sizeMultiplier = sizeMultiplier * weightMultiplier
							end

							local iceBlock = Instance.new("Part")
							iceBlock.Name = "IceBlock"
							iceBlock.Anchored = false
							iceBlock.CanCollide = false
							iceBlock.Massless = true
							iceBlock.Size = targetPart.Size * sizeMultiplier
							iceBlock.Position = targetPart.Position
							iceBlock.Rotation = targetPart.Rotation
							iceBlock.Material = Enum.Material.Plastic
							iceBlock.Transparency = 0.3
							iceBlock.Color = Color3.fromRGB(200, 240, 255)
							iceBlock.Shape = Enum.PartType.Block
							iceBlock.Parent = targetPart

							local weld = Instance.new("WeldConstraint")
							weld.Part0 = targetPart
							weld.Part1 = iceBlock
							weld.Parent = iceBlock

							print("🧊 미끼 물고기에 통일된 얼음 효과 적용:", fishWeight and (fishWeight .. "kg") or "Unknown", "크기 배율:", sizeMultiplier)
							return iceBlock
						end

						createHookedFishIceBlock(fakeHandle, fishInfo.weight)
					end
				end

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = self.baitPart
				weld.Part1 = fakeHandle
				weld.Parent = fakeHandle

				self:_showFishCaughtNotice()
				self.hookedFishHandle = fakeHandle
			end

			-- 인챈트 포함 설정 가져오기
			local Config = require(game.ReplicatedStorage.Modules:WaitForChild("FishingConfigModule"))
			local difficultyMod = 1

			-- 🔧 순수 도구명으로 플레이어 설정 가져오기
			local playerConfig = Config.GetPlayerRodConfig(self.player, baseToolName)
			if playerConfig and playerConfig.DifficultyMod then
				difficultyMod = playerConfig.DifficultyMod
				print("✅ 첫 낚시 시작 - 플레이어 인챈트 포함 난이도:", baseToolName, "=", difficultyMod)
			else
				-- 백업: 기본 설정만 사용
				local basicConfig = Config.GetBaseRodConfig(baseToolName)
				if basicConfig and basicConfig.DifficultyMod then
					difficultyMod = basicConfig.DifficultyMod
					print("⚠️ 기본 설정만 사용:", baseToolName, "=", difficultyMod)
				end
			end

			self.currentDifficultyMod = difficultyMod

			self.remote:FireClient(self.player, {
				rarity = fishInfo.rarity,
				sessionId = sessionId,
				toolName = baseToolName,  -- 🔧 순수 도구명 사용
				difficultyMod = difficultyMod
			})
		end
	end)
end

-- 웹훅 전송 함수 추가 (FishingServerModule 내부에)
local function sendSansWebhook(playerName, fishWeight)
	--local data = {
	--	["username"] = "Sans Fisher Alert",
	--	["embeds"] = {{
	--		["title"] = "💀 SANS CAUGHT! 💀",
	--		["description"] = string.format("**%s** just caught **Sans**!\n🎣 Weight: **%.1fkg**\n💰 This is a Fantasy rarity fish!",
	--			playerName, fishWeight),
	--		["color"] = 16776960, -- 노란색
	--		["thumbnail"] = {
	--			["url"] = "https://i.imgur.com/YourSansImage.png" -- Sans 이미지 URL (선택사항)
	--		},
	--		["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
	--	}}
	--}

	--local jsonData = HttpService:JSONEncode(data)

	--pcall(function()
	--	HttpService:PostAsync(SANS_WEBHOOK_URL, jsonData, Enum.HttpContentType.ApplicationJson)
	--	print("🚀 Sans 웹훅 전송 완료:", playerName)
	--end)
end


-- 🔧 완전한 _resolveFishing 함수
function FishingServer:_resolveFishing(player, result)
	-- 🔧 먼저 플레이어 상태 정리
	if player then
		player:SetAttribute("IsFishing", false)
	end

	self.remote:FireClient(player, "stop_all_animations")

	-- 🔧 크기 조정 함수들을 먼저 정의
	local function scaleHandleByRatio(handle, scaleRatio)
		if not handle or not handle:IsA("BasePart") then
			warn("Invalid handle")
			return
		end
		if scaleRatio == 1 then return end

		-- Tool의 무게중심 고정을 위한 개선된 크기 조정
		local originalCFrame = handle.CFrame
		local originalSize = handle.Size

		-- 크기만 조정하고 위치는 그대로
		handle.Size = originalSize * scaleRatio
		handle.CFrame = originalCFrame

		-- 무게중심 보정을 위해 Masslessness 설정
		handle.Massless = true
	end

	-- 🧊 FishingServerModule의 tweenHandleToPlayerLinear 함수 완전 수정
	local function tweenHandleToPlayerLinear(handle, startPos, targetPos, duration)
		if not handle then return end

		-- 🔧 얼음 블록 찾기
		local iceBlock = handle:FindFirstChild("IceBlock")

		-- 🔧 기존 WeldConstraint 제거 (Anchored 상태에서는 의미없음)
		if iceBlock then
			for _, child in pairs(iceBlock:GetChildren()) do
				if child:IsA("WeldConstraint") then
					child:Destroy()
				end
			end
		end

		handle.Anchored = true
		handle.CanCollide = false
		handle.Massless = true
		handle.CanTouch = false
		handle.CFrame = CFrame.new(startPos)
		handle.Parent = workspace

		-- 🔧 얼음 블록도 Anchored로 설정하고 상대 위치 저장
		local iceOffset = nil
		if iceBlock then
			iceOffset = iceBlock.CFrame:ToObjectSpace(handle.CFrame)  -- 상대 위치 저장
			iceBlock.Anchored = true
			iceBlock.CanCollide = false
			iceBlock.Massless = true
			iceBlock.CanTouch = false
		end

		local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(handle, tweenInfo, {Position = targetPos})

		-- 🔧 Tween 업데이트 이벤트로 얼음 블록 위치 동기화
		local connection = nil
		if iceBlock and iceOffset then
			connection = game:GetService("RunService").Heartbeat:Connect(function()
				if handle and handle.Parent and iceBlock and iceBlock.Parent then
					-- 물고기 위치에 맞춰 얼음 블록 위치 업데이트
					iceBlock.CFrame = handle.CFrame * iceOffset
				end
			end)
		end

		tween:Play()

		task.delay(duration - 0.2, function()
			if player and player.Character then
				local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local attachment = Instance.new("Attachment")
					attachment.Position = Vector3.new(0, 0, 0)
					attachment.Parent = rootPart

					local newEffect = FishGetEffect:Clone()
					newEffect.Parent = attachment
					newEffect.Enabled = false
					newEffect:Emit(1)

					local newGetSound = GetSound:Clone()
					newGetSound.Parent = rootPart
					newGetSound.RollOffMode = Enum.RollOffMode.Linear
					newGetSound.EmitterSize = 5
					newGetSound.MaxDistance = 100
					newGetSound.Volume = 1
					newGetSound:Play()

					game:GetService("Debris"):AddItem(newGetSound, 1)
					game:GetService("Debris"):AddItem(attachment, 1)
				end
			end
		end)

		task.delay(duration - 0.1, function()
			-- 🔧 연결 해제
			if connection then
				connection:Disconnect()
			end
			if handle then
				handle:Destroy()  -- 이때 얼음 블록도 함께 삭제됨
			end
		end)
	end

	local function applyMutationEffects(clone, itemName, fishInfo)

		local ParticleFolder = game:GetService("ReplicatedStorage"):WaitForChild("Particle")

		local mutationMap = {
			["赤"] = "Red",
			["青"] = "Blue",
			["紫"] = "Purple",
			["Massive"] = "Massive",
			["Rainbow"] = "Rainbow",
			["Red"] = "Red",
			["Blue"] = "Blue",
			["Trinity"] = "Trinity",
			["Windy"] = "Windy",
			["Wet"] = "Wet",
			["Luck"] = "Luck",
			["Clover"] = "Clover",
			["Void"] = "Void",
		}

		for symbolOrName, mutation in pairs(mutationMap) do
			if itemName:find(symbolOrName) then
				for _, attach in ipairs(ParticleFolder:GetChildren()) do
					if attach:IsA("Attachment") and attach.Name:match("^" .. mutation) then
						local cloneAttach = attach:Clone()
						cloneAttach.Parent = clone
					end
				end
			end
		end

		-- 🔴 ERROR 변이 전용 처리
		if itemName:find("ERROR") then
			local errorFolder = ParticleFolder:FindFirstChild("ERROR")
			if errorFolder then
				for _, obj in ipairs(errorFolder:GetChildren()) do
					local cloneObj = obj:Clone()
					cloneObj.Parent = clone
				end
			end
		end

		-- 기존 Frozen, Festival 처리
		if itemName:find("Frozen") then
			-- FishIceEffect 모듈 사용
			local success, FishIceEffect = pcall(function()
				return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("FishIceEffectModule"))
			end)

			if success then
				FishIceEffect.ApplyIceEffect(clone, { fishName = itemName, currentWeather = "Snow" })
			else
				-- 백업: FishData의 얼음 효과 사용
				FishData.ApplyIceEffect(clone, { fishName = itemName })
			end
			print("얼음 효과 적용:", itemName)
		end

		--if itemName:find("Festival") then
		--	FishData.ApplyFestivalEffect(clone, { fishName = itemName, currentWeather = "Firework" })
		--	print("축제 효과 적용:", itemName)
		--end
	end

	-- FishingServerModule의 createFishTool 함수 완전 교체
	-- FishingServerModule의 createFishTool 함수 수정 (아이템 세이브와 동일한 계산)
	local function createFishTool(fishInfo)
		-- FishData의 새로운 인벤토리용 함수 사용
		local toolClone = FishData.CreateInventoryFishModel(fishInfo)

		if not toolClone then
			warn("CreateInventoryFishModel 실패, 백업 방식 사용")
			toolClone = fishInfo.model:Clone()
			toolClone.CanBeDropped = false
		end

		applyMutationEffects(toolClone, fishInfo.fishName, fishInfo)

		-- Handle 설정 및 크기 조정
		local handle = toolClone:FindFirstChild("Handle")
		if handle then
			handle.Anchored = false
			local ratio = getScaleRatio(fishInfo.weight, fishInfo.minWeight, fishInfo.maxWeight, 5)

			if player and player:GetAttribute("SizeBubbleBuff") == true then
				ratio = ratio * 1.35
				print("사이즈 버블 버프 적용 - 물고기 크기 35% 증가!")
			end

			scaleHandleByRatio(handle, ratio)
			handle.AssemblyLinearVelocity = Vector3.zero
			handle.AssemblyAngularVelocity = Vector3.zero

			toolClone.Equipped:Connect(function()
				handle.AssemblyLinearVelocity = Vector3.zero
				handle.AssemblyAngularVelocity = Vector3.zero

				for _, obj in pairs(handle:GetChildren()) do
					if obj:IsA("BodyPosition") or obj:IsA("BodyVelocity") or obj:IsA("BodyAngularVelocity") or
						obj:IsA("BodyThrust") or obj:IsA("BodyForce") or obj:IsA("BodyGyro") then
						obj:Destroy()
					end
				end

				task.wait(0.1)
				handle.AssemblyLinearVelocity = Vector3.zero
				handle.AssemblyAngularVelocity = Vector3.zero
			end)
		end

		-- 🔧 아이템세이브와 완전히 동일한 getMutationBonus 함수
		local function getMutationBonus(itemName)
			local totalBonus = 0
			local appliedMutations = {}

			-- 각 변이별 보너스 값 (합산 방식 - 아이템세이브와 완전 동일)
			local mutationValues = {
				["Windy"] = 0.6,
				["Wet"] = 0.6,
				["赤"] = 1.0,
				["青"] = 1.0,
				["Long"] = 1.5,
				["Massive"] = 3.0,
				["Trinity"] = 3.0,
				["Rainbow"] = 3.5,
				["Clover"] = 4.0,
				["Lucky"] = 5.0,
				["Void"] = 7.0,
				["ERROR"] = 20.0,
				["紫"] = 12.0,
				["Frozen"] = 0.4,
				["Festival"] = 0.3
			}

			-- 아이템 이름에서 변이 찾기 (합산)
			for mutation, bonus in pairs(mutationValues) do
				if itemName:find(mutation) then
					totalBonus = totalBonus + bonus
					table.insert(appliedMutations, mutation)
				end
			end

			return totalBonus, appliedMutations
		end

		-- 🔧 아이템세이브와 완전히 동일한 가격 계산 방식
		-- fishInfo에서 원본 물고기 데이터 찾기
		local originalFishData = nil
		for _, rarity in ipairs(require(game.ReplicatedStorage.Modules.FishDataModule).Rarities) do
			for _, fish in ipairs(rarity.fishes) do
				-- 변이 제거한 기본 이름으로 비교
				local baseFishName = fishInfo.fishName
				-- 모든 변이 접두사 제거
				local mutationPrefixes = {
					"Windy ", "Wet ", "赤 ", "青 ", "Long ", "Massive ",
					"Trinity ", "Rainbow ", "Clover ", "Lucky ", "Void ", "ERROR ", "紫 ",
					"Frozen ", "Festival "
				}
				for _, prefix in ipairs(mutationPrefixes) do
					baseFishName = baseFishName:gsub("^" .. prefix, "")
				end

				if fish.fishName == baseFishName then
					originalFishData = fish
					break
				end
			end
			if originalFishData then break end
		end

		-- 기본 가격으로 다시 계산 (아이템세이브와 동일)
		local minW, maxW = fishInfo.minWeight or 1, fishInfo.maxWeight or 1
		local baseValue = originalFishData and originalFishData.value or fishInfo.value  -- 원본 기본 가격 사용
		local valueRatio = (fishInfo.weight - minW) / (maxW - minW)
		local adjustedValue = math.floor(baseValue * (1.2 + math.pow(valueRatio, 0.8) * 7.0))

		-- 변이 보너스 계산 (아이템 세이브와 완전히 동일한 방식)
		local mutationBonus, appliedMutations = getMutationBonus(fishInfo.fishName)
		local finalValue = math.floor(adjustedValue * (1 + mutationBonus))  -- 곱셈 방식

		if #appliedMutations > 0 then
			print("🔧 올바른 계산:", table.concat(appliedMutations, ", "),
				"원본가격:", baseValue, "무게보정:", adjustedValue, "변이배수:", (1 + mutationBonus), "최종:", finalValue)
		else
			finalValue = adjustedValue
		end

		-- 🔧 물고기 이름에 kg 포함
		local fishName = fishInfo.fishName
		local nameWithGrade = string.format("%s [%s] - %.1fkg", fishName, fishInfo.name, fishInfo.weight)
		toolClone.Name = nameWithGrade

		-- 값 저장
		local valueObj = toolClone:FindFirstChild("FishValue") or Instance.new("IntValue")
		valueObj.Name = "FishValue"
		valueObj.Value = finalValue
		valueObj.Parent = toolClone

		local weightObj = toolClone:FindFirstChild("FishWeight") or Instance.new("NumberValue")
		weightObj.Name = "FishWeight"
		weightObj.Value = fishInfo.weight
		weightObj.Parent = toolClone

		local rarityObj = toolClone:FindFirstChild("FishRarity") or Instance.new("StringValue")
		rarityObj.Name = "FishRarity"
		rarityObj.Value = fishInfo.name
		rarityObj.Parent = toolClone

		return toolClone
	end

	-- 🔧 결과에 따른 처리
	if result == "success" then
		-- ✅ 성공한 경우
		local fishInfo = self.fishInfo
		if fishInfo then
			self.remote:FireClient(player, "success")

			self:_updateQuestProgress(player, fishInfo.fishName)



			-- 🐟 도감에 물고기 등록 (🆕 자동 변이 제거 적용)
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local fishFolder = leaderstats:FindFirstChild("Fish")
				if fishFolder then
					-- 🚀 자동으로 기본 물고기 이름 추출
					local baseFishName = getBaseFishName(fishInfo.fishName)

					if baseFishName then
						local fishBool = fishFolder:FindFirstChild(baseFishName)
						if fishBool and fishBool:IsA("BoolValue") then
							if not fishBool.Value then
								fishBool.Value = true
								print("🎉 새로운 물고기 도감 등록:", baseFishName, "(원본:", fishInfo.fishName, ")")

								-- 🆕 새 물고기 발견 알림 (기본 이름으로)
								game:GetService("ReplicatedStorage"):WaitForChild("DiscoverNoticeEvent"):FireClient(
									player,
									"New Fish Discovered: " .. baseFishName .. "!"
								)
							else
								print("📋 이미 도감에 등록된 물고기:", baseFishName, "(변이:", fishInfo.fishName, ")")
							end
						else
							warn("⚠️ 도감에서 찾을 수 없는 물고기:", baseFishName, "(원본:", fishInfo.fishName, ")")
						end
					else
						warn("⚠️ 기본 물고기 이름 추출 실패:", fishInfo.fishName)
					end
				else
					warn("⚠️ Fish 폴더를 찾을 수 없습니다:", player.Name)
				end
			else
				warn("⚠️ leaderstats를 찾을 수 없습니다:", player.Name)
			end

			-- 🏅 Sans 뱃지 체크 (기본 이름으로)
			local baseName = getBaseFishName(fishInfo.fishName)
			if baseName == "Sans" then

				print("🎯🎯🎯 샌즈 잡음! 뱃지 시스템 시작 🎯🎯🎯")
				print("👤 플레이어:", player.Name)
				print("🆔 UserId:", player.UserId)
				print("🏅 뱃지 ID:", SANS_BADGE_ID)

				local success, hasBadge = pcall(function()
					return BadgeService:UserHasBadgeAsync(player.UserId, SANS_BADGE_ID)
				end)

				if success then
					print("✅ 뱃지 확인 성공:", hasBadge)
					if not hasBadge then
						print("🎁 뱃지 지급 시도 중...")

						local successAward, errorMsg = pcall(function()
							BadgeService:AwardBadge(player.UserId, SANS_BADGE_ID)
						end)

						if successAward then
							print("🏅🏅🏅 샌즈 뱃지 지급 완료! 🏅🏅🏅")
							-- 🆕 뱃지 획득 알림 추가
						else
							warn("❌❌❌ 뱃지 지급 실패:", errorMsg)
						end
					else
						print("📌 이미 뱃지 보유 중")
					end
				else
					warn("❌ 뱃지 확인 API 실패:", hasBadge)
				end
			end

			-- 백팩에 물고기 툴 추가
			local backpackTool = createFishTool(fishInfo)
			backpackTool.Parent = player:FindFirstChild("Backpack")

			-- 낚인 물고기 핸들 처리
			if self.hookedFishHandle then
				local fishHandle = self.hookedFishHandle
				self.hookedFishHandle = nil

				local weld = fishHandle:FindFirstChildOfClass("WeldConstraint")
				if weld then weld:Destroy() end

				local targetPos = self.character and self.character:FindFirstChild("HumanoidRootPart") and self.character.HumanoidRootPart.Position
				if targetPos then
					tweenHandleToPlayerLinear(fishHandle, fishHandle.Position, targetPos, 0.3)
				end
			end

			-- 성공 알림
			game:GetService("ReplicatedStorage"):WaitForChild("FishNoticeEvent"):FireClient(
				player,
				string.format("You got %s [%s] - %.1fkg", fishInfo.fishName, fishInfo.name, fishInfo.weight)
			)
		end

	elseif result == "cancel" then
		-- ✅ 취소된 경우
		print("낚시 취소됨")
		self:_resetPlayer()
		self:_cleanup()
		return

	else
		-- ✅ 실패한 경우 (result == 0 또는 기타)
		print("낚시에 실패했습니다.")

		-- 🔧 클라이언트에 실패 메시지 전송 (UI 닫기용)
		self.remote:FireClient(player, "fail")

		-- 낚인 물고기 제거
		if self.hookedFishHandle then
			self.hookedFishHandle:Destroy()
			self.hookedFishHandle = nil
		end

		-- 실패 알림
		game:GetService("ReplicatedStorage"):WaitForChild("FishNoticeEvent"):FireClient(player, "Nice try! Give it another shot!")
	end

	-- 🔧 사운드 정리
	if self.fishingSoundLoop then
		self.fishingSoundLoop:Stop()
		self.fishingSoundLoop:Destroy()
		self.fishingSoundLoop = nil
	end

	-- 🔧 플레이어 상태 복구 및 정리
	self:_resetPlayer()
	self:_cleanup()
end

function FishingServer:_showFishCaughtNotice()
	if not self.player or not self.player.Character then return end

	local character = self.player.Character
	local head = character:FindFirstChild("Head")
	if not head then return end

	-- 🔊 FishBaitNoticeSound 재생
	local fishBaitNoticeSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("FishBaitNoticeSound")
	if fishBaitNoticeSound then
		local soundClone = fishBaitNoticeSound:Clone()
		soundClone.Parent = head
		soundClone.RollOffMode = Enum.RollOffMode.Linear
		soundClone.EmitterSize = 5
		soundClone.MaxDistance = 50
		soundClone.Volume = 1
		soundClone:Play()

		-- 사운드 재생 후 제거
		game:GetService("Debris"):AddItem(soundClone, 3)
	end

	-- ReplicatedStorage에서 GUI 템플릿 가져오기
	local noticeTemplate = ReplicatedStorage:FindFirstChild("FishingNoticeSurface")
	if not noticeTemplate then
		warn("FishingNoticeSurface를 찾을 수 없습니다")
		return
	end

	-- GUI 복사하여 플레이어 머리에 부착
	local noticeGui = noticeTemplate:Clone()
	noticeGui.Parent = head

	-- BillboardGui 크기 고정 설정
	--noticeGui.Size = UDim2.new(2, 0, 1, 0)
	--noticeGui.StudsOffset = Vector3.new(0, 2, 0)
	--noticeGui.AlwaysOnTop = true

	-- 텍스트를 "!"로 설정
	local textLabel = noticeGui:FindFirstChildOfClass("TextLabel")
	if textLabel then
		textLabel.Text = "!"
		textLabel.TextTransparency = 1

		-- 빠르게 나타나기
		local fadeInTween = TweenService:Create(textLabel,
			TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ TextTransparency = 0 }
		)
		fadeInTween:Play()

		-- 잠시 후 천천히 사라지기
		fadeInTween.Completed:Connect(function()
			task.wait(0.3)

			local fadeOutTween = TweenService:Create(textLabel,
				TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ TextTransparency = 1 }
			)
			fadeOutTween:Play()

			-- 애니메이션 완료 후 GUI 제거
			fadeOutTween.Completed:Connect(function()
				if noticeGui and noticeGui.Parent then
					noticeGui:Destroy()
				end
			end)
		end)
	end
end


function FishingServer:_resetPlayer()
	if self.character then
		local humanoid = self.character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = humanoid:GetAttribute("OriginalWalkSpeed") or 16
			humanoid.UseJumpPower = humanoid:GetAttribute("OriginalUseJumpPower") ~= false
			humanoid.JumpHeight = humanoid:GetAttribute("OriginalJumpHeight") or 7.2
			humanoid.Jump = false
		end
	end
end


return FishingServer