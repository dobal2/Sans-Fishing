-- FishingServerModule (ModuleScript in ReplicatedStorage.Modules)
local MarketplaceService = game:GetService("MarketplaceService")
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local AnalyticsService = game:GetService("AnalyticsService")

local SANS_BADGE_ID = 2468526859123734
local POWER_X2_GAMEPASS_ID = 1290056221
local FISHING_POINT_X2_GAMEPASS_ID = 1294285302
local FishData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishDataModule"))
local CastSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Fishing Rod Cast")
local FishingSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Fishing Rod Reel")
local GetSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("GetSound")
local FishGetEffect = ReplicatedStorage:WaitForChild("Particle"):WaitForChild("GetFishParticle")
local TweenService = game:GetService("TweenService")

local baitSplashEvent = ReplicatedStorage:FindFirstChild("BaitSplashEvent")
if not baitSplashEvent then
	baitSplashEvent = Instance.new("RemoteEvent")
	baitSplashEvent.Name = "BaitSplashEvent"
	baitSplashEvent.Parent = ReplicatedStorage
end

-- Streak tracking: consecutive successful catches per player
local playerStreaks = {}
local streakUpdateEvent  = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("StreakUpdateEvent")
local streakEndBroadcast = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("StreakEndBroadcast")
local recoverEvent       = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fishing"):WaitForChild("RecoverEvent")

local _streakDM = nil
local function getStreakDM()
	if _streakDM then return _streakDM end
	local ok, dm = pcall(function()
		return require(game:GetService("ServerScriptService"):WaitForChild("leaderstats"):WaitForChild("DataManager"))
	end)
	if ok and dm then _streakDM = dm end
	return _streakDM
end


-- Sent only to the fishing player so their client freezes the bait without lag
local baitLandedEvent = ReplicatedStorage:FindFirstChild("BaitLandedEvent")
if not baitLandedEvent then
	baitLandedEvent = Instance.new("RemoteEvent")
	baitLandedEvent.Name = "BaitLandedEvent"
	baitLandedEvent.Parent = ReplicatedStorage
end

local FishingServer = {}
FishingServer.__index = FishingServer

function FishingServer.init(tool)
	local self = setmetatable({}, FishingServer)
	self.tool = tool

	self.castEvent = tool:FindFirstChild("CastRod") or tool:WaitForChild("CastRod", 5)
	self.remote = tool:FindFirstChild("RemoteEvent") or tool:WaitForChild("RemoteEvent", 5)
	if not self.castEvent or not self.remote then
		warn("FishingServer.init: missing CastRod or RemoteEvent on", tool.Name)
		return
	end
	self.cancelled = false
	self.baitPart = nil
	self.rope = nil
	self.activated = false
	self.isReeling = false
	self.character = nil
	self.player = nil
	self:_bindEvents()

	self.playerLeavingConnection = Players.PlayerRemoving:Connect(function(leavingPlayer)
		playerStreaks[leavingPlayer.UserId] = nil
		if self.player == leavingPlayer then
			if self.hookedFishHandle then
				self.hookedFishHandle:Destroy()
				self.hookedFishHandle = nil
			end
			self:_cleanup()
		end
	end)

	return self
end



-- Cache base fish names for getBaseFishName (built once on first call)
local _baseFishNameCache = nil
local function _buildBaseFishNameCache()
	_baseFishNameCache = {}
	for _, rarity in ipairs(FishData.Rarities) do
		for _, fish in ipairs(rarity.fishes) do
			_baseFishNameCache[fish.fishName] = true
		end
	end
end

-- Auto-remove mutation prefix function
local function getBaseFishName(fishName)
	if not fishName then return nil end
	if not _baseFishNameCache then _buildBaseFishNameCache() end

	local allBaseFishNames = _baseFishNameCache

	-- Check if current name is already a base fish name
	if allBaseFishNames[fishName] then
		return fishName
	end

	-- Auto-match: check if end of name matches a base fish name
	for baseName, _ in pairs(allBaseFishNames) do
		-- "Frozen Bass" -> "Bass" match
		if string.sub(fishName, -(#baseName)) == baseName then
			-- Check for preceding space (exact match)
			local prefixLength = #fishName - #baseName
			if prefixLength > 0 and string.sub(fishName, prefixLength, prefixLength) == " " then
				return baseName
			end
		end
	end

	-- Backup: extract last word(s) by space
	local words = {}
	for word in string.gmatch(fishName, "%S+") do
		table.insert(words, word)
	end

	if #words > 1 then
		local lastWord = words[#words]
		local secondLastWord = words[#words - 1] or ""

		-- Try last two words ("Golden Trout")
		local lastTwoWords = secondLastWord .. " " .. lastWord
		if allBaseFishNames[lastTwoWords] then
			return lastTwoWords
		end

		-- Try last word only ("Bass")
		if allBaseFishNames[lastWord] then
			return lastWord
		end
	end

	-- Return original if no match
	return fishName
end


function FishingServer:_hasPowerX2Gamepass(player)
	local success, hasGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, POWER_X2_GAMEPASS_ID)
	end)
	if success then return hasGamepass end
	warn("Failed to check gamepass:", player.Name)
	return false
end

function FishingServer:_getEffectiveRodPower(player, baseRodPower)
	if self:_hasPowerX2Gamepass(player) then
		return baseRodPower * 2
	end
	return baseRodPower
end


function FishingServer:_bindEvents()
	self.castEvent.OnServerEvent:Connect(function(player, targetPos)
		if typeof(targetPos) ~= "Vector3" then return end
		if self.activated or self.isReeling then return end

		self.player = player
		self.character = player.Character
		if not self.character then return end
		player:SetAttribute("IsFishing", true)

		local humanoid = self.character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		-- Restrict player movement first
		self.isReeling = true
		self.activated = true
		humanoid:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)
		humanoid:SetAttribute("OriginalJumpHeight", humanoid.JumpHeight)
		humanoid:SetAttribute("OriginalUseJumpPower", humanoid.UseJumpPower)
		-- Allow slow movement while waiting for a bite; fully locked when fish bites
		humanoid.WalkSpeed = 4
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = 0
		humanoid.Jump = false

		local newCastSound = CastSound:Clone()
		newCastSound.Parent = self.tool.Handle or self.tool
		newCastSound.RollOffMode = Enum.RollOffMode.Linear
		newCastSound.EmitterSize = 5
		newCastSound.MaxDistance = 100
		newCastSound.Volume = 1
		newCastSound:Play()

		-- Client already plays fishing animation (Raft style: client-first)
		task.spawn(function()
			if not self.cancelled and self.player == player then
				self:_createBait()
				self:_setupRope()
				self:_moveBaitTo(targetPos)

				-- Start waiting animation command (0.5s after cast)
				task.spawn(function()
					task.wait(0.5)
					if not self.cancelled and self.player == player then
						self.remote:FireClient(player, "play_waiting_animation")
					end
				end)

				self:_checkMaterial()
			end
		end)
	end)

	self.remote.OnServerEvent:Connect(function(player, action, payload)
		if action == "progress_success" then
			-- Security validation
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
			if gameTime < 0.3 then
				warn("Security: Game completed too quickly:", gameTime, "seconds by", player.Name)
				self:_resolveFishing(player, "fail")
				return
			end

			self.sessionId = nil -- Prevent replay after first success
			self:_resolveFishing(player, "success")

		elseif action == "fail" then
			self:_resolveFishing(player, "fail")

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
			self.hookedFishHandle:Destroy()
			self.hookedFishHandle = nil
		end

		self:_resetPlayer()
		self:_cleanup()
	end)
end


function FishingServer:_getValidatedToolConfig(player)
	-- Load Config module
	local Config = require(ReplicatedStorage.Modules:WaitForChild("FishingConfigModule"))

	-- Verify player has a character
	if not player.Character then
		warn("Security: Player has no character")
		return nil
	end

	-- Check that equipped tool matches self.tool
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

	-- Use server-stored original tool name (ignore client manipulation)
	local originalToolName = self.originalToolName

	-- Verify tool config exists
	local toolConfig = Config[originalToolName]
	if not toolConfig then
		warn("Security: Invalid tool name:", originalToolName, "from", player.Name)
		return nil
	end

	if toolConfig and toolConfig.RodPower then
		toolConfig = {
			Distance = toolConfig.Distance,
			Rarity = toolConfig.Rarity,
			RodPower = self:_getEffectiveRodPower(player, toolConfig.RodPower),
			DifficultyMod = toolConfig.DifficultyMod,
		}
	end

	return toolConfig, originalToolName
end


local WATER_SURFACE_Y = -3.69   -- actual water surface Y (top of Water part)
local BAIT_REST_Y    = -3.69   -- final resting Y at water surface

function FishingServer:_createBait()
	local ls = self.player:FindFirstChild("leaderstats")
	local equippedBobber = ls and ls:FindFirstChild("EquippedBobber") and ls.EquippedBobber.Value or "Basic Bobber"
	local bobberModels = ReplicatedStorage:FindFirstChild("Bobbers")
	local bobberTemplate = bobberModels and bobberModels:FindFirstChild(equippedBobber)

	if bobberTemplate then
		-- Use equipped bobber model as bait
		local clone = bobberTemplate:Clone()
		clone.Name = "Bait"
		clone.Anchored = false
		clone.CanCollide = false
		clone.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0, 0.3)
		clone.Massless = true
		clone.Parent = workspace
		clone:SetNetworkOwner(nil)
		self.baitPart = clone
	else
		-- Fallback: default red ball
		self.baitPart = Instance.new("Part")
		self.baitPart.Name = "Bait"
		self.baitPart.Size = Vector3.new(0.4, 0.4, 0.4)
		self.baitPart.Shape = Enum.PartType.Ball
		self.baitPart.Anchored = false
		self.baitPart.CanCollide = false
		self.baitPart.BrickColor = BrickColor.new("Bright red")
		self.baitPart.Material = Enum.Material.SmoothPlastic
		self.baitPart.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0, 0.3)
		self.baitPart.Massless = true
		self.baitPart.Parent = workspace
		self.baitPart:SetNetworkOwner(nil)
	end
end



-- Fix _validateAttempt (resolves DifficultyMod error)

function FishingServer:_validateAttempt(player, payload)
	if not self.fishInfo or not payload or type(payload) ~= "table" then
		return
	end

	-- Session mismatch check
	if payload.SessionId ~= self.sessionId then
		warn("Session mismatch blocked:", player.Name, "expected:", self.sessionId, "received:", payload.SessionId)
		self:_resolveFishing(player, "fail")
		return
	end

	-- Server spam prevention: 0.5s minimum between attempts
	local currentTime = tick()
	if self.lastServerAttempt and (currentTime - self.lastServerAttempt) < 0.5 then
		warn("Server spam blocked:", player.Name)
		return
	end
	self.lastServerAttempt = currentTime

	-- Basic security validation
	if not self:_validateBasicSecurity(player, "attempt") then
		warn("Security validation failed:", player.Name)
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

		-- Get DifficultyMod from Config
		local Config = require(ReplicatedStorage.Modules:WaitForChild("FishingConfigModule"))
		local toolConfig = Config[self.originalToolName or self.tool.Name]
		local difficultyMod = 1  -- Default

		if toolConfig and toolConfig.DifficultyMod then
			difficultyMod = toolConfig.DifficultyMod
		else
			-- Fallback: find on tool directly
			if self.tool:FindFirstChild("DifficultyMod") then
				difficultyMod = self.tool.DifficultyMod.Value
			elseif self.tool:GetAttribute("DifficultyMod") then
				difficultyMod = self.tool:GetAttribute("DifficultyMod")
			end
		end

		-- Save current difficulty for retry
		self.currentDifficultyMod = difficultyMod

		local difficulty = require(ReplicatedStorage.Modules:WaitForChild("FishDifficultyModule"))
			.GetModifiedSetting(self.fishInfo.name, difficultyMod, self.fishInfo.weight, self.fishInfo.minWeight, self.fishInfo.maxWeight)

		if self.successCount >= difficulty.attempts then
			self:_resolveFishing(player, "success")
		else
			local newSessionId = HttpService:GenerateGUID(false)
			self.sessionId = newSessionId

			-- Reset server timer for next attempt
			self.lastServerAttempt = nil

			self.remote:FireClient(player, {
				rarity = self.fishInfo.name,
				sessionId = newSessionId,
				nextAttempt = true,
				toolName = self.tool.Name,
				difficultyMod = difficultyMod,
				fishWeight = self.fishInfo.weight or 0,
				fishMinWeight = self.fishInfo.minWeight or 0,
				fishMaxWeight = self.fishInfo.maxWeight or 0,
			})
		end
	else
		self:_resolveFishing(player, "fail")
	end
end

function FishingServer:_validateBasicSecurity(player, action)
	-- Check player has character
	if not player.Character then
		warn("Security: Player has no character:", player.Name)
		return false
	end

	-- Confirm correct player
	if player ~= self.player then
		warn("Security: Wrong player:", player.Name, "Expected:", self.player and self.player.Name)
		return false
	end

	-- Tool must be equipped in character for fishing actions
	local hasTool = false
	for _, obj in pairs(player.Character:GetChildren()) do
		if obj:IsA("Tool") and obj.Name == self.tool.Name then
			hasTool = true
			break
		end
	end
	if not hasTool then
		warn("Security: Tool not equipped for action", action, "by", player.Name)
		return false
	end

	-- Spam prevention
	local now = tick()
	self.lastAction = self.lastAction or 0
	if now - self.lastAction < 0.3 then
		warn("Security: Too fast action from", player.Name)
		return false
	end
	self.lastAction = now

	return true
end



function FishingServer:_setupRope()
	-- Tip attachment on the rod handle.
	-- Preference order: pre-existing "RodTip", then rod-specific known attachments, then fallback.
	local handle = self.tool.Handle
	-- Search entire tool recursively so tip attachments in non-Handle parts (e.g. VoidRod) are found
	local tipAtt = self.tool:FindFirstChild("RodTip", true)
	if not tipAtt then
		-- LinePos part anywhere in the tool: convert to Attachment on handle at its world position
		local linePosP = self.tool:FindFirstChild("LinePos", true)
		if linePosP and linePosP:IsA("BasePart") then
			tipAtt = Instance.new("Attachment")
			tipAtt.Name = "RodTip"
			tipAtt.Position = handle.CFrame:PointToObjectSpace(linePosP.Position)
			tipAtt.Parent = handle
		end
	end
	if not tipAtt then
		tipAtt = handle:FindFirstChild("Att0")
	end
	if not tipAtt then
		tipAtt = handle:FindFirstChildOfClass("Attachment")
	end
	if not tipAtt then
		tipAtt = Instance.new("Attachment")
		tipAtt.Name = "RodTip"
		tipAtt.Position = Vector3.new(-handle.Size.X / 2, 0, 0)
		tipAtt.Parent = handle
	end

	-- End attachment on the bait
	local baitAtt = Instance.new("Attachment")
	baitAtt.Name = "LineEnd"
	baitAtt.Parent = self.baitPart

	-- Beam fishing line (no physics weight, always visible, follows both ends)
	local beam = Instance.new("Beam")
	beam.Name = "FishingLine"
	beam.Attachment0 = tipAtt
	beam.Attachment1 = baitAtt
	beam.Width0 = 0.05
	beam.Width1 = 0.05
	beam.Color = ColorSequence.new(Color3.fromRGB(240, 240, 230))
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new(0)
	beam.FaceCamera = true
	beam.Segments = 6
	beam.CurveSize0 = 0
	beam.CurveSize1 = 0
	beam.Parent = self.baitPart

	self.rope = beam  -- stored in self.rope so _cleanup destroys it

	if self.tool.Handle then
		self.originalPhysicalProperties = self.tool.Handle.CustomPhysicalProperties
	end
end

function FishingServer:_cleanup()
	if self.playerLeavingConnection then self.playerLeavingConnection:Disconnect(); self.playerLeavingConnection = nil end
	if self.baitLandConn then self.baitLandConn:Disconnect(); self.baitLandConn = nil end
	if self.baitPart then self.baitPart:Destroy() end
	if self.rope then self.rope:Destroy() end

	-- Restore tool handle physical properties
	if self.tool and self.tool.Handle then
		self.tool.Handle.CustomPhysicalProperties = self.originalPhysicalProperties
	end

	-- Clean up sounds
	if self.fishingSoundLoop then
		self.fishingSoundLoop:Stop()
		self.fishingSoundLoop:Destroy()
		self.fishingSoundLoop = nil
	end

	-- Reset variables
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
	self._resolving = false
end

local CAST_PITCH_DEG = 55
local CAST_SPEED = 80

function FishingServer:_moveBaitTo(targetPos)
	-- Use HumanoidRootPart as origin so repeated casts are consistent
	-- regardless of animation-driven hand/handle position drift
	local hrp = self.character and self.character:FindFirstChild("HumanoidRootPart")
	local origin = hrp and (hrp.Position + Vector3.new(0, 2, 0))
		or (self.tool.Handle.Position + Vector3.new(0, 3, 0))

	-- Project direction onto XZ plane, then apply fixed upward pitch
	local flat = targetPos - origin
	flat = Vector3.new(flat.X, 0, flat.Z)
	local flatDir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
	local pitch = math.rad(CAST_PITCH_DEG)
	local castDir = (flatDir * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)).Unit

	self.baitPart.Position = origin
	self.baitPart.AssemblyLinearVelocity = castDir * CAST_SPEED
end

local function getScaleRatio(weight, minWeight, maxWeight, maxScale)
	local range = maxWeight - minWeight
	if range <= 0 then return 1 end
	local clampedWeight = math.clamp(weight, minWeight, maxWeight)
	local t = (clampedWeight - minWeight) / range
	return 1 + (maxScale - 1) * t
end

-- Update quest progress
function FishingServer:_updateQuestProgress(player, fishName)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local quests = leaderstats:FindFirstChild("Quests")
	if not quests then return end

	local activeQuests = quests:FindFirstChild("ActiveQuests")
	if not activeQuests then return end

	-- Extract base fish name (remove mutation prefix)
	local baseFishName = getBaseFishName(fishName)

	-- Check all active quests
	for _, quest in pairs(activeQuests:GetChildren()) do
		if quest:IsA("Folder") then
			local targetFish = quest:FindFirstChild("TargetFish")
			local currentProgress = quest:FindFirstChild("CurrentProgress")
			local requiredProgress = quest:FindFirstChild("RequiredProgress")
			local isReceived = quest:FindFirstChild("IsReceived")
			local questName = quest:FindFirstChild("QuestName")

			if targetFish and currentProgress and requiredProgress and isReceived and questName then
				-- Quest must be received and not yet complete
				if isReceived.Value and currentProgress.Value < requiredProgress.Value then
					local isMatch = false

					-- 1. Exact name match
					if targetFish.Value == fishName then
						isMatch = true
					-- 2. Base name match (mutation handling)
					elseif targetFish.Value == baseFishName then
						isMatch = true
					-- 3. Target is base name, caught fish is mutation
					elseif baseFishName and getBaseFishName(targetFish.Value) == baseFishName then
						isMatch = true
					end

					if isMatch then
						currentProgress.Value = currentProgress.Value + 1

						-- Notify if quest is complete
						if currentProgress.Value >= requiredProgress.Value then
						end
					end
				end
			end
		end
	end
end

local GROUND_DETECT_ABOVE_WATER = 2.0  -- studs above WATER_SURFACE_Y to consider "ground not water"
local GROUND_RAYCAST_DIST = 0.6        -- downward ray length for ground detection
local BAIT_CHECK_INTERVAL = 0.05       -- seconds between bait position checks (20Hz)
local WATER_DETECT_DIST   = 2.0        -- how far below bait to raycast for water surface
local ROBLOX_GRAVITY       = 196.2     -- workspace.Gravity default
local BOUNCE_ARC_TIME      = 0.8       -- seconds for the bounce arc to reach water

function FishingServer:_checkMaterial()
	local landed = false
	local groundCancelled = false
	local bouncing = false         -- true while arc animation is running (pause landing checks)
	local lastCheckTime = 0
	local lastBounceTime = -math.huge  -- cooldown to prevent double-trigger after arc

	-- Two separate raycast params: one that includes Water, one that excludes it for ground check
	local waterParams = RaycastParams.new()
	waterParams.FilterType = Enum.RaycastFilterType.Exclude
	waterParams.FilterDescendantsInstances = {self.baitPart, self.character}

	-- Pre-calculate exact water surface Y (top face of Water part) + bait radius offset
	-- so the bait center sits flush on the surface, not half-submerged.
	local waterPart = workspace:FindFirstChild("Water", true)
	local BAIT_RADIUS = 0.2  -- half of bait Size (0.4)
	local waterSurfaceY = waterPart
		and (waterPart.Position.Y + waterPart.Size.Y / 2 + BAIT_RADIUS)
		or  (BAIT_REST_Y + BAIT_RADIUS)

	-- groundParams excludes bait, character, and water so water surface isn't treated as ground
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	do
		local excludeList = {self.baitPart, self.character}
		if waterPart then table.insert(excludeList, waterPart) end
		groundParams.FilterDescendantsInstances = excludeList
	end

	-- Returns the nearest XZ point on the Water part surface to the given position.
	-- Used to aim the bounce arc.
	local function nearestWaterPoint(fromPos)
		if not waterPart then
			return Vector3.new(fromPos.X, waterSurfaceY, fromPos.Z)
		end
		local wp = waterPart.Position
		local ws = waterPart.Size
		local clampedX = math.clamp(fromPos.X, wp.X - ws.X / 2, wp.X + ws.X / 2)
		local clampedZ = math.clamp(fromPos.Z, wp.Z - ws.Z / 2, wp.Z + ws.Z / 2)
		-- If already inside the water XZ bounds, keep XZ and just target the surface
		return Vector3.new(clampedX, waterSurfaceY, clampedZ)
	end

	-- Calculates initial velocity for a parabolic arc from `from` to `to` in `arcTime` seconds.
	local function calcBounceVelocity(from, to)
		local t = BOUNCE_ARC_TIME
		local g = workspace.Gravity or ROBLOX_GRAVITY
		local vx = (to.X - from.X) / t
		local vy = (to.Y - from.Y) / t + 0.5 * g * t
		local vz = (to.Z - from.Z) / t
		return Vector3.new(vx, vy, vz)
	end

	local prevBaitPos = nil

	local conn
	conn = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastCheckTime < BAIT_CHECK_INTERVAL then return end
		lastCheckTime = now

		local bait = self.baitPart
		if not bait or not bait.Parent then conn:Disconnect(); return end
		if landed or groundCancelled then return end
		if bouncing then return end
		if not self.activated then conn:Disconnect(); return end

		local pos = bait.Position
		local vel = bait.AssemblyLinearVelocity

		-- Ground detection: above water zone, continuous segment cast prevPos→pos
		if pos.Y > waterSurfaceY + GROUND_DETECT_ABOVE_WATER or
			(prevBaitPos and prevBaitPos.Y > waterSurfaceY + GROUND_DETECT_ABOVE_WATER) then

			local rayOrigin = prevBaitPos or pos
			local rayDelta  = pos - rayOrigin
			local hit
			if rayDelta.Magnitude > 0.01 then
				hit = workspace:Raycast(rayOrigin, rayDelta, groundParams)
			end
			-- Fallback short downward ray when bait is nearly stationary above ground
			if not hit then
				hit = workspace:Raycast(pos, Vector3.new(0, -(BAIT_RADIUS + 0.15), 0), groundParams)
			end

			if hit and hit.Instance and hit.Position.Y >= waterSurfaceY - BAIT_RADIUS then
				-- Ignore hits too soon after previous bounce to prevent double-trigger
				if tick() - lastBounceTime < 0.3 then
					prevBaitPos = pos
					return
				end

				-- Every ground hit: bounce forward (player look direction) via parabolic arc
				bouncing = true
				lastBounceTime = tick()
				prevBaitPos = nil

				local showNotice = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("ShowNoticeEvent")
				if showNotice and self.player then
					showNotice:FireClient(self.player, "Bait is bouncing...")
				end

				local arcStart = hit.Position + Vector3.new(0, BAIT_RADIUS + 0.1, 0)

				-- Forward direction from player's HumanoidRootPart, projected onto XZ plane
				local char = self.player and self.player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local forward = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
				forward = Vector3.new(forward.X, 0, forward.Z)
				if forward.Magnitude < 0.01 then forward = Vector3.new(0, 0, -1) end
				forward = forward.Unit

				local BOUNCE_DIST = 12
				local arcTarget = Vector3.new(
					arcStart.X + forward.X * BOUNCE_DIST,
					arcStart.Y,
					arcStart.Z + forward.Z * BOUNCE_DIST
				)

				local t = BOUNCE_ARC_TIME
				local g = workspace.Gravity or ROBLOX_GRAVITY
				local elapsed = 0

				bait.Anchored = true
				bait.AssemblyLinearVelocity = Vector3.zero
				bait.CFrame = CFrame.new(arcStart)

				local arcConn
				arcConn = RunService.Heartbeat:Connect(function(dt)
					if not bait or not bait.Parent then arcConn:Disconnect(); bouncing = false; return end
					elapsed += dt
					local frac = math.min(elapsed / t, 1)

					local lerpPos = arcStart:Lerp(arcTarget, frac)
					local arcY = arcStart.Y + (arcTarget.Y - arcStart.Y) * frac
						+ 0.5 * g * (frac * t) * (t - frac * t)
					bait.CFrame = CFrame.new(lerpPos.X, arcY, lerpPos.Z)

					if frac >= 1 then
						arcConn:Disconnect()
						bait.Anchored = false
						prevBaitPos = arcTarget
						bouncing = false
					end
				end)

				prevBaitPos = pos
				return
			end

			prevBaitPos = pos
			return
		end

		-- Slow approach: dampen velocity near surface
		if pos.Y > waterSurfaceY + 1.0 then
			if vel.Y < 0 then
				bait.AssemblyLinearVelocity = Vector3.new(vel.X * 0.7, math.max(vel.Y * 0.55, -6), vel.Z * 0.7)
			end
			return
		end

		-- Catch bait 0.3 studs above the rest point to absorb the 50ms check lag
		if pos.Y > waterSurfaceY + 0.3 then return end

		-- Snap here
		local restY = waterSurfaceY

		landed = true
		conn:Disconnect()

		if not self.player then return end
		self.activated = false

		task.spawn(function()
			local baitRef = self.baitPart
			if not baitRef or not baitRef.Parent then return end

			local landX = baitRef.Position.X
			local landZ = baitRef.Position.Z

			-- Anchor first to kill physics, then snap to exact water surface
			baitRef.Anchored = true
			baitRef.AssemblyLinearVelocity = Vector3.zero
			baitRef.AssemblyAngularVelocity = Vector3.zero
			baitRef.CFrame = CFrame.new(landX, restY, landZ)

			if not self.player then return end

			-- Fishing player: gets BaitLandedEvent (splash effect)
			baitLandedEvent:FireClient(self.player, Vector3.new(landX, restY, landZ), self.baitPart)

			-- Everyone else: gets BaitSplashEvent for spectator splash effect
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= self.player then
					baitSplashEvent:FireClient(p, Vector3.new(landX, restY, landZ))
				end
			end

			-- Start minigame after random wait (fish biting delay)
			task.spawn(function()
			local sessionId = HttpService:GenerateGUID(false)
			self.sessionId = sessionId
			self.successCount = 0

			-- QuickBite skill reduces bite wait time
			local quickBiteReduction = 0
			do
				local ok_qb, SkillHelper_qb = pcall(function()
					return require(game:GetService("ServerScriptService"):WaitForChild("SkillHelper"))
				end)
				if ok_qb and SkillHelper_qb then
					quickBiteReduction = SkillHelper_qb.GetEffect(self.player, "QuickBite")
				end
			end
			local minWait = math.max(0.5, 3 - quickBiteReduction)
			local maxWait = math.max(minWait + 0.5, 5 - quickBiteReduction)
			task.wait(minWait + math.random() * (maxWait - minWait))

			if self.cancelled then return end
			if self.sessionId ~= sessionId then return end
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

			local isTutorialed = self.player:FindFirstChild("IsTutorialed")
			if isTutorialed and isTutorialed.Value == false then
				self.player:SetAttribute("ForcedRarity", "Common")
			end
			local fishInfo = FishData.GetRandomFish(self.tool.Name, self.player)
			fishInfo.rarity = fishInfo.name

			-- Apply equipped bobber effects
			if not self.player or not self.player:IsDescendantOf(game.Players) then return end
			do
				local ls = self.player:FindFirstChild("leaderstats")
				local equippedBobber = ls and ls:FindFirstChild("EquippedBobber") and ls.EquippedBobber.Value or "Basic Bobber"
				local BobberData = require(ReplicatedStorage.Modules:WaitForChild("BobberDataModule"))
				local fx = BobberData.GetEffects(equippedBobber)

				-- Gold variant (forced by admin command, or 2% base chance)
				local GOLD_CHANCE = 0.02
				local forcedGold = self.player:GetAttribute("ForcedGoldVariant")
				if forcedGold or math.random() < GOLD_CHANCE then
					if forcedGold then self.player:SetAttribute("ForcedGoldVariant", nil) end
					fishInfo.fishName = "Gold " .. fishInfo.fishName
					fishInfo.value = math.floor((fishInfo.value or 0) * 2.0)
					fishInfo.isGoldVariant = true
				end

				-- Sans variant (forced by admin command, bobber chance, or base 0.2% chance)
				local BASE_SANS_CHANCE = 0.002
				local forcedSans = self.player:GetAttribute("ForcedSansVariant")
				local totalSansChance = math.max(fx.sansChance, BASE_SANS_CHANCE)
				if forcedSans then
					self.player:SetAttribute("ForcedSansVariant", nil)
					fishInfo.fishName = "Sans " .. fishInfo.fishName
					fishInfo.value = math.floor((fishInfo.value or 0) * (fx.sansMultiplier > 0 and fx.sansMultiplier or 2))
					fishInfo.isSansVariant = true
				elseif math.random() < totalSansChance then
					fishInfo.fishName = "Sans " .. fishInfo.fishName
					fishInfo.value = math.floor((fishInfo.value or 0) * (fx.sansMultiplier > 0 and fx.sansMultiplier or 2))
					fishInfo.isSansVariant = true
				end

				-- Frozen variant (bobber chance OR base 0.8% chance, skip if already Frozen from weather)
				local alreadyFrozen = fishInfo.isFrozen == true
				local BASE_FROZEN_CHANCE = 0.008
				if not alreadyFrozen and (fx.frozenChance > 0 and math.random() < fx.frozenChance or math.random() < BASE_FROZEN_CHANCE) then
					fishInfo.fishName = "Frozen " .. fishInfo.fishName
					fishInfo.value = math.floor((fishInfo.value or 0) * (fx.frozenMultiplier or 2.0))
					fishInfo.isFrozen = true
				end

				-- Festival variant (bobber festivalBonus OR base 0.5% chance, skip if already Festival from weather)
				local alreadyFestival = fishInfo.isFestival == true
				local BASE_FESTIVAL_CHANCE = 0.005
				if not alreadyFestival and (fx.festivalBonus > 0 and math.random() < fx.festivalBonus or math.random() < BASE_FESTIVAL_CHANCE) then
					fishInfo.fishName = "Festival " .. fishInfo.fishName
					fishInfo.value = math.floor((fishInfo.value or 0) * 1.5)
					fishInfo.isFestival = true
				end

				fishInfo.bobberFx = fx
			end

			self.fishInfo = fishInfo

			local toolModel = fishInfo.model
			local handle = toolModel:FindFirstChild("Handle")

			if handle then
				-- Use the actual fish model as silhouette (black fill, white outline)
				local fakeHandle = handle:Clone()
				local ratio = getScaleRatio(fishInfo.weight, fishInfo.minWeight, fishInfo.maxWeight, 5)
				if self.player and self.player:GetAttribute("SizeBubbleBuff") == true then
					ratio = ratio * 1.35
				end

				-- Fish has bitten — lock movement fully for the minigame
				local hum = self.character and self.character:FindFirstChildOfClass("Humanoid")
				if hum then hum.WalkSpeed = 0 end

				if not self.player or not self.player:IsDescendantOf(game:GetService("Players")) then return end
				self.remote:FireClient(self.player, "keep_waiting_animation")
				fakeHandle.Size = fakeHandle.Size * ratio
				self._hookedBaseSize = fakeHandle.Size

				-- Gold 변이 비주얼 적용
				if fishInfo.isGoldVariant then
					fakeHandle.Color = Color3.fromRGB(255, 235, 60)
					fakeHandle.Material = Enum.Material.Metal
					fakeHandle.Reflectance = 0.6
				end

				-- 미발견 물고기일 때만 검정 실루엣 처리
				local baseFishName = fishInfo.fishName
					:gsub("Gold ", "")
					:gsub("Frozen ", "")
					:gsub("Festival ", "")
					:gsub("Sans ", "")
				local fishFolder = self.player:FindFirstChild("leaderstats")
					and self.player.leaderstats:FindFirstChild("Fish")
				local discovered = fishFolder
					and fishFolder:FindFirstChild(baseFishName)
					and fishFolder[baseFishName].Value == true

				if not discovered then
					local highLight = Instance.new("Highlight")
					highLight.DepthMode = Enum.HighlightDepthMode.Occluded
					highLight.FillColor = Color3.new(0, 0, 0)
					highLight.FillTransparency = 0
					highLight.OutlineTransparency = 0
					highLight.OutlineColor = Color3.new(1, 1, 1)
					highLight.Parent = fakeHandle
				end

				fakeHandle.Anchored = false
				fakeHandle.CanCollide = false
				fakeHandle.Massless = true
				fakeHandle.Name = "FlyingFish"
				fakeHandle.CFrame = self.baitPart.CFrame
				fakeHandle.Parent = workspace
				fakeHandle.AssemblyLinearVelocity = Vector3.new(0, -10, 0)

				local weatherInfo = FishData.GetWeatherInfo()
				if weatherInfo and weatherInfo.isActive and weatherInfo.currentWeather == "Snow" then
					if fishInfo.fishName and string.find(fishInfo.fishName, "Frozen") then
						local function createHookedFishIceBlock(targetPart, fishWeight)
							local sizeMultiplier = 1.05
							if fishWeight then
								local weightMultiplier = math.max(0.9, math.min(1.5, 1.0 + (fishWeight - 1) * 0.01))
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
							return iceBlock
						end
						createHookedFishIceBlock(fakeHandle, fishInfo.weight)
					end
				end

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = self.baitPart
				weld.Part1 = fakeHandle
				weld.Parent = fakeHandle

				self:_showFishCaughtNotice(fishInfo.name)
				self.hookedFishHandle = fakeHandle
			end

			local Config = require(ReplicatedStorage.Modules:WaitForChild("FishingConfigModule"))
			local toolConfig = Config[self.tool.Name]
			local difficultyMod = 1
			if toolConfig and toolConfig.DifficultyMod then
				difficultyMod = toolConfig.DifficultyMod
			elseif self.tool:FindFirstChild("DifficultyMod") then
				difficultyMod = self.tool.DifficultyMod.Value
			elseif self.tool:GetAttribute("DifficultyMod") then
				difficultyMod = self.tool:GetAttribute("DifficultyMod")
			end
			self.currentDifficultyMod = difficultyMod

			self.gameStartTime = tick()
			self.remote:FireClient(self.player, {
				rarity = fishInfo.rarity,
				sessionId = sessionId,
				toolName = self.tool.Name,
				difficultyMod = difficultyMod,
				fishWeight = fishInfo.weight or 0,
				fishMinWeight = fishInfo.minWeight or 0,
				fishMaxWeight = fishInfo.maxWeight or 0,
			})
		end) -- end minigame task.spawn
		end) -- end settle task.spawn
	end) -- end Heartbeat
	self.baitLandConn = conn
end

-- Webhook send function (commented out)
local function sendSansWebhook(playerName, fishWeight)
	--local data = {
	--	["username"] = "Sans Fisher Alert",
	--	["embeds"] = {{
	--		["title"] = "SANS CAUGHT!",
	--		["description"] = string.format("**%s** just caught **Sans**!\nWeight: **%.1fkg**\nThis is a Fantasy rarity fish!",
	--			playerName, fishWeight),
	--		["color"] = 16776960, -- Yellow
	--		["thumbnail"] = {
	--			["url"] = "https://i.imgur.com/YourSansImage.png"
	--		},
	--		["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
	--	}}
	--}

	--local jsonData = HttpService:JSONEncode(data)

	--pcall(function()
	--	HttpService:PostAsync(SANS_WEBHOOK_URL, jsonData, Enum.HttpContentType.ApplicationJson)
	--end)
end


function FishingServer:_resolveFishing(player, result)
	-- Prevent concurrent re-entry (two progress_success packets arriving in the same frame)
	if self._resolving then return end
	self._resolving = true

	-- Grab and immediately nil fishInfo/sessionId so any concurrent re-entry
	-- (from packet replay during BadgeService/WaitForChild yields) finds nothing.
	local fishInfo = self.fishInfo
	local sessionId = self.sessionId
	self.fishInfo = nil
	self.sessionId = nil

	if player then
		player:SetAttribute("IsFishing", false)
	end

	-- success path: client handles animations itself (Finish → Holding)
	-- only send stop_all_animations for fail/cancel so other anims get cleaned up
	if result ~= "success" then
		self.remote:FireClient(player, "stop_all_animations")
	end

	-- Define scale functions
	local function scaleHandleByRatio(handle, scaleRatio)
		if not handle or not handle:IsA("BasePart") then
			warn("Invalid handle")
			return
		end
		if scaleRatio == 1 then return end

		-- Adjust size while keeping position
		local originalCFrame = handle.CFrame
		local originalSize = handle.Size

		handle.Size = originalSize * scaleRatio
		handle.CFrame = originalCFrame

		-- Set massless to stabilize center of mass
		handle.Massless = true
	end

	-- Tween handle to player linearly
	local function tweenHandleToPlayerLinear(handle, startPos, targetPos, duration)
		if not handle then return end

		-- Find ice block
		local iceBlock = handle:FindFirstChild("IceBlock")

		-- Remove WeldConstraints (not needed when Anchored)
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

		-- Also anchor ice block and save relative offset
		local iceOffset = nil
		if iceBlock then
			iceOffset = iceBlock.CFrame:ToObjectSpace(handle.CFrame)
			iceBlock.Anchored = true
			iceBlock.CanCollide = false
			iceBlock.Massless = true
			iceBlock.CanTouch = false
		end

		local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(handle, tweenInfo, {Position = targetPos})

		-- Sync ice block position during tween
		local connection = nil
		if iceBlock and iceOffset then
			connection = RunService.Heartbeat:Connect(function()
				if handle and handle.Parent and iceBlock and iceBlock.Parent then
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

					Debris:AddItem(newGetSound, 1)
					Debris:AddItem(attachment, 1)
				end
			end
		end)

		task.delay(duration - 0.1, function()
			-- Disconnect
			if connection then
				connection:Disconnect()
			end
			if handle then
				handle:Destroy()  -- Ice block is also destroyed as child
			end
		end)
	end

	-- Create fish tool
	local function createFishTool(fishInfo)
		-- Clone base model (not using FishData.CreateFishModel)
		local toolClone = fishInfo.model:Clone()
		toolClone.CanBeDropped = false

		-- Apply ice effect manually (for inventory)
		if fishInfo.fishName and string.find(fishInfo.fishName, "Frozen") then
			-- Check for Snow weather
			local weatherInfo = FishData.GetWeatherInfo()
			if weatherInfo and weatherInfo.isActive and weatherInfo.currentWeather == "Snow" then
				-- Load FishIceEffect module
				local success, FishIceEffect = pcall(function()
					return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishIceEffectModule"))
				end)

				if success then
					FishIceEffect.ApplyIceEffect(toolClone, fishInfo)
				else
					warn("FishIceEffect module load failed")
				end
			end
		end


		-- Apply festival effect manually (for inventory)
		if fishInfo.fishName and string.find(fishInfo.fishName, "Festival") then
			-- Check for Firework weather
			local weatherInfo = FishData.GetWeatherInfo()
			if weatherInfo and weatherInfo.isActive and weatherInfo.currentWeather == "Firework" then
				local success = pcall(function()
					FishData.ApplyFestivalEffect(toolClone, fishInfo)
				end)

				if not success then
					warn("Festival effect application failed")
				end
			end
		end

		-- Apply Sans variant particle effect
		if fishInfo.isSansVariant then
			local handle = toolClone:FindFirstChild("Handle")
			if handle then
				local sansParticles = ReplicatedStorage:FindFirstChild("Particle") and ReplicatedStorage.Particle:FindFirstChild("Sans")
				if sansParticles then
					for _, p in ipairs(sansParticles:GetChildren()) do
						if p:IsA("ParticleEmitter") then
							p:Clone().Parent = handle
						end
					end
				end
			end
		end

		-- Apply Gold variant visual
		if fishInfo.isGoldVariant then
			for _, part in ipairs(toolClone:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Color = Color3.fromRGB(255, 235, 60)
					part.Material = Enum.Material.Metal
					part.Reflectance = 0.6
					if part:IsA("UnionOperation") then
						part.UsePartColor = true
					end
				end
			end
		end

		-- Handle setup and size adjustment
		local handle = toolClone:FindFirstChild("Handle")
		if handle then
			handle.Anchored = false

			-- Size adjustment (keep 5x)
			local ratio = getScaleRatio(fishInfo.weight, fishInfo.minWeight, fishInfo.maxWeight, 5)

			if player and player:GetAttribute("SizeBubbleBuff") == true then
				ratio = ratio * 1.35  -- +35% size
			end

			scaleHandleByRatio(handle, ratio)

			-- Stabilize after size adjustment
			handle.AssemblyLinearVelocity = Vector3.zero
			handle.AssemblyAngularVelocity = Vector3.zero

			-- Tool event connections (physics stabilization)
			toolClone.Equipped:Connect(function()
				-- Fully stop on equip
				handle.AssemblyLinearVelocity = Vector3.zero
				handle.AssemblyAngularVelocity = Vector3.zero

				-- Remove all physics objects
				for _, obj in pairs(handle:GetChildren()) do
					if obj:IsA("BodyPosition") or obj:IsA("BodyVelocity") or obj:IsA("BodyAngularVelocity") or
						obj:IsA("BodyThrust") or obj:IsA("BodyForce") or obj:IsA("BodyGyro") then
						obj:Destroy()
					end
				end

				-- Clean up again after delay (catch delayed physics objects)
				task.wait(0.1)
				handle.AssemblyLinearVelocity = Vector3.zero
				handle.AssemblyAngularVelocity = Vector3.zero
			end)

			toolClone.Unequipped:Connect(function()
				-- Natural physics on unequip
			end)
		end

		-- Calculate price
		local minW, maxW = fishInfo.minWeight or 1, fishInfo.maxWeight or 1
		local baseValue = fishInfo.value or 0
		local valueRatio = math.clamp((fishInfo.weight - minW) / math.max(maxW - minW, 0.001), 0, 1)
		local adjustedValue = math.floor(baseValue * (1.2 + math.pow(valueRatio, 0.8) * 7.0))

		toolClone.Name = string.format("%s [%s] - %.1fkg", fishInfo.fishName, fishInfo.name, fishInfo.weight)

		-- Save values
		local valueObj = toolClone:FindFirstChild("FishValue") or Instance.new("IntValue")
		valueObj.Name = "FishValue"
		valueObj.Value = adjustedValue
		-- Store original base so GamblerHandler never needs reverse-calculation
		valueObj:SetAttribute("OriginalBaseValue", baseValue)
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

	-- Handle result
	if result == "success" then
		if fishInfo then
			self.remote:FireClient(player, "success")

			self:_updateQuestProgress(player, fishInfo.fishName)

			-- Register fish in fish catalog (auto mutation removal)
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local fishFolder = leaderstats:FindFirstChild("Fish")
				if fishFolder then
					local baseFishName = getBaseFishName(fishInfo.fishName)

					if baseFishName then
						local fishBool = fishFolder:FindFirstChild(baseFishName)
						local newFishDiscovered = false
						if fishBool and fishBool:IsA("BoolValue") then
							if not fishBool.Value then
								fishBool.Value = true
								newFishDiscovered = true
								ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("DiscoverNoticeEvent"):FireClient(
									player,
									"New Fish Discovered: " .. baseFishName .. "!"
								)
							end
						else
							warn("Fish not found in catalog:", baseFishName, "(original:", fishInfo.fishName, ")")
						end
					else
						warn("Failed to extract base fish name:", fishInfo.fishName)
					end
				else
					warn("Fish folder not found:", player.Name)
				end

				-- 변이 도감 등록
				local variantFolder = leaderstats:FindFirstChild("FishVariant")
				local newVariant = false
				if variantFolder then
					local TRACKED_PREFIXES = { "Gold", "Frozen", "Festival", "Sans" }
					local baseFishName2 = getBaseFishName(fishInfo.fishName)
					if baseFishName2 then
						for _, prefix in ipairs(TRACKED_PREFIXES) do
							if fishInfo.fishName:find(prefix .. " ") then
								local variantKey = prefix .. " " .. baseFishName2
								local vBool = variantFolder:FindFirstChild(variantKey)
								if vBool and not vBool.Value then
									vBool.Value = true
									newVariant = true
								end
							end
						end
					end
				end

				-- 새 도감 발견 시 즉시 저장
				if newFishDiscovered or newVariant then
					local dm = getStreakDM()
					if dm then task.spawn(function() dm:SaveData(player) end) end
				end
			else
				warn("leaderstats not found:", player.Name)
			end

			-- Sans badge check (using base name)
			local baseName = getBaseFishName(fishInfo.fishName)
			if baseName == "Sans" then

				local success, hasBadge = pcall(function()
					return BadgeService:UserHasBadgeAsync(player.UserId, SANS_BADGE_ID)
				end)

				if success then
					if not hasBadge then

						local successAward, errorMsg = pcall(function()
							BadgeService:AwardBadge(player.UserId, SANS_BADGE_ID)
						end)

						if not successAward then
							warn("Badge award failed:", errorMsg)
						end
					end
				else
					warn("Badge check API failed:", hasBadge)
				end
			end

			-- Notify ItemSave to record fish data (no longer adding Tool to Backpack here)
			local FishCaughtBindable = game:GetService("ServerScriptService"):FindFirstChild("FishCaughtBindable")
			if FishCaughtBindable then
				FishCaughtBindable:Fire(player, fishInfo)
			else
				-- Fallback: create tool and add to backpack if BindableEvent not found
				local backpackTool = createFishTool(fishInfo)
				backpackTool.Parent = player:FindFirstChild("Backpack")
			end

			-- Update consecutive catch streak
			local userId = player.UserId
			playerStreaks[userId] = (playerStreaks[userId] or 0) + 1
			streakUpdateEvent:FireAllClients(userId, playerStreaks[userId])
			local dm = getStreakDM()
			if dm then dm:UpdateData(player, "FishStreak", playerStreaks[userId]) end

			-- Increment total catch counter
			local leaderstats = player:FindFirstChild("leaderstats")
			local totalCatches = leaderstats and leaderstats:FindFirstChild("TotalCatches")
			if totalCatches then
				totalCatches.Value = totalCatches.Value + 1
				local ok_lc, LeaderstatsDataManager_lc = pcall(function()
					return require(game:GetService("ServerScriptService"):WaitForChild("leaderstats"):WaitForChild("DataManager"))
				end)
				if ok_lc and LeaderstatsDataManager_lc then
					LeaderstatsDataManager_lc:UpdateData(player, "TotalCatches", totalCatches.Value)
				end
			end

			-- Award SkillPoints per successful catch (base 1 + PointBoost bonus, x2 with gamepass)
			local skillPointsVal = player:FindFirstChild("SkillPoints")
			if skillPointsVal then
				local ok_p, SkillHelper_p = pcall(function()
					return require(game:GetService("ServerScriptService"):WaitForChild("SkillHelper"))
				end)
				local bonus = (ok_p and SkillHelper_p) and SkillHelper_p.GetEffect(player, "PointBoost") or 0
				local basePoints = 1 + bonus
				local ok_gp, hasX2 = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, FISHING_POINT_X2_GAMEPASS_ID)
				if ok_gp and hasX2 then basePoints = basePoints * 2 end
				local EventState = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EventStateModule"))
				basePoints = math.floor(basePoints * EventState.FPMultiplier)
				skillPointsVal.Value = skillPointsVal.Value + basePoints
			end

			-- Economy: fish caught (sink — player receives item worth adjustedValue coins)
			local minW2, maxW2 = fishInfo.minWeight or 1, fishInfo.maxWeight or 1
			local vRatio2 = math.clamp((fishInfo.weight - minW2) / math.max(maxW2 - minW2, 0.001), 0, 1)
			local caughtValue = math.floor((fishInfo.value or 0) * (1.2 + math.pow(vRatio2, 0.8) * 7.0))
			pcall(function()
				AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, "Coins",
					caughtValue, 0, "FishCaught", fishInfo.name or "Unknown")
			end)

			-- 5% chance to trigger free random fish gacha (disabled)
			--[[
			local didTriggerGacha = math.random() < 0.05
			if didTriggerGacha then
				local triggerEvt = game.ReplicatedStorage:FindFirstChild("Remotes") and
					game.ReplicatedStorage.Remotes:FindFirstChild("Fishing") and
					game.ReplicatedStorage.Remotes.Fishing:FindFirstChild("TriggerRandomFish")
				if triggerEvt then
					triggerEvt:Fire(player)
				end
				if self.hookedFishHandle then
					local pulsePart = self.hookedFishHandle
					local baseSize = self._hookedBaseSize or pulsePart.Size
					local bigSize = baseSize * 1.4
					task.spawn(function()
						for _ = 1, 4 do
							if not pulsePart or not pulsePart.Parent then break end
							TweenService:Create(pulsePart, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {Size = bigSize}):Play()
							task.wait(0.25)
							if not pulsePart or not pulsePart.Parent then break end
							TweenService:Create(pulsePart, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {Size = baseSize}):Play()
							task.wait(0.25)
						end
					end)
				end
			end
			--]]

			-- Handle hooked fish
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

			-- Success notification
			do
				local fn = fishInfo.fishName or ""
				local pct = (fishInfo.chance or 0) / 100
				-- Divide by fish count within rarity (each fish equally probable within rarity)
				local rarityName = fishInfo.name
				for _, rarity in ipairs(FishData.Rarities) do
					if rarity.name == rarityName then
						local n = #rarity.fishes
						if n > 1 then pct = pct / n end
						break
					end
				end
				if fishInfo.isGoldVariant then pct = pct * 0.02 end
				if fishInfo.isFrozen then pct = pct * 0.25 end
				if fishInfo.isFestival then pct = pct * 0.25 end
				if fishInfo.isSansVariant then pct = pct * 0.05 end
				local oneIn = pct > 0 and math.round(1 / pct) or 0
				local chanceStr = oneIn > 0 and ("1 in " .. tostring(oneIn)) or "???"
				ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("FishNoticeEvent"):FireClient(
					player,
					string.format("You got %s [%s] - %.1fkg (%s)", fn, fishInfo.name, fishInfo.weight, chanceStr)
				)
			end
		end

	elseif result == "cancel" then
		-- Cancelled — reset streak
		local userId = player.UserId
		playerStreaks[userId] = 0
		streakUpdateEvent:FireAllClients(userId, 0)
		local dmc = getStreakDM()
		if dmc then dmc:UpdateData(player, "FishStreak", 0) end
		self:_resetPlayer()
		self:_cleanup()
		return

	else
		-- Failed (result == 0 or other)

		-- Reset streak on fail; broadcast if it was >= 100
		local userId = player.UserId
		local prevStreak = playerStreaks[userId] or 0
		playerStreaks[userId] = 0
		streakUpdateEvent:FireAllClients(userId, 0)
		local dm2 = getStreakDM()
		if dm2 then dm2:UpdateData(player, "FishStreak", 0) end
		if prevStreak >= 100 then
			streakEndBroadcast:FireAllClients(player.DisplayName, prevStreak)
		end

		-- Send fail message to client (to close UI)
		self.remote:FireClient(player, "fail")

		-- Remove hooked fish
		if self.hookedFishHandle then
			self.hookedFishHandle:Destroy()
			self.hookedFishHandle = nil
		end

		-- Send recover prompt with lost fish info
		if fishInfo then
			local fi = fishInfo
			-- 서버 테이블에 저장 (클라이언트 Attribute 조작 방지)
			local setPendingRecover = game:GetService("ServerScriptService"):FindFirstChild("SetPendingRecover")
			if setPendingRecover then
				setPendingRecover:Fire(player.UserId, fi.fishName or "", fi.name or "Common", fi.weight or 1, fi.minWeight or 1, fi.maxWeight or 1)
			end
			recoverEvent:FireClient(player, {
				fishName  = fi.fishName,
				rarity    = fi.name,
				weight    = fi.weight,
				minWeight = fi.minWeight,
				maxWeight = fi.maxWeight,
			})
		end

		-- Fail notification
		ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice"):WaitForChild("FishNoticeEvent"):FireClient(player, "Nice try! Give it another shot!")
	end

	-- Clean up sounds
	if self.fishingSoundLoop then
		self.fishingSoundLoop:Stop()
		self.fishingSoundLoop:Destroy()
		self.fishingSoundLoop = nil
	end

	-- Restore player state and clean up
	self:_resetPlayer()
	self:_cleanup()
end

local RARITY_EXCLAMATION_COLOR = {
	Common    = Color3.fromRGB(255, 255, 255),
	Uncommon  = Color3.fromRGB(80, 220, 80),
	Rare      = Color3.fromRGB(80, 140, 255),
	Epic      = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 235, 60),
	Mystic    = Color3.fromRGB(255, 80, 80),
	Fantasy   = Color3.fromRGB(100, 220, 255),
	Unknown   = Color3.fromRGB(255, 255, 255),
}

local RARITY_SCALE = {
	Common = 1.0, Uncommon = 1.1, Rare = 1.2,
	Epic = 1.3, Legendary = 1.5, Mystic = 1.6, Fantasy = 1.8, Unknown = 2.0,
}

function FishingServer:_showFishCaughtNotice(rarity)
	if not self.player or not self.player.Character then return end

	local character = self.player.Character
	local head = character:FindFirstChild("Head")
	if not head then return end

	-- Play FishBaitNoticeSound
	local fishBaitNoticeSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("FishBaitNoticeSound")
	if fishBaitNoticeSound then
		local soundClone = fishBaitNoticeSound:Clone()
		soundClone.Parent = head
		soundClone.RollOffMode = Enum.RollOffMode.Linear
		soundClone.EmitterSize = 5
		soundClone.MaxDistance = 50
		soundClone.Volume = 1
		soundClone:Play()
		Debris:AddItem(soundClone, 3)
	end

	-- Get GUI template from ReplicatedStorage
	local noticeTemplate = ReplicatedStorage:FindFirstChild("FishingNoticeSurface")
	if not noticeTemplate then
		warn("FishingNoticeSurface not found")
		return
	end

	-- Clone GUI and attach to player's head
	local noticeGui = noticeTemplate:Clone()
	noticeGui.Parent = head

	-- Pixel-based size so the billboard appears the same size regardless of distance.
	-- Rarity scale boosts the pixel size slightly for rarer fish.
	local scale = RARITY_SCALE[rarity] or 1.0
	if noticeGui:IsA("BillboardGui") then
		local studs = 2.4 * scale
		noticeGui.Size = UDim2.new(studs, 0, studs * 1.25, 0)
		noticeGui.StudsOffset = Vector3.new(0, 6, 0)
		noticeGui.MaxDistance = 40
		noticeGui.AlwaysOnTop = false
	end

	local startColor = RARITY_EXCLAMATION_COLOR[rarity] or Color3.fromRGB(255, 255, 255)
	-- Unknown: fades from white to black; all others: stay same color
	local endColor = (rarity == "Unknown") and Color3.fromRGB(0, 0, 0) or startColor

	local textLabel = noticeGui:FindFirstChildOfClass("TextLabel")
	if textLabel then
		textLabel.Text = "!"
		textLabel.TextColor3 = startColor
		textLabel.TextTransparency = 1

		-- Fade in
		local fadeInTween = TweenService:Create(textLabel,
			TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ TextTransparency = 0 }
		)
		fadeInTween:Play()

		fadeInTween.Completed:Connect(function()
			task.wait(0.3)

			-- Fade out (+ color transition for Unknown)
			local fadeOutTween = TweenService:Create(textLabel,
				TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ TextTransparency = 1, TextColor3 = endColor }
			)
			fadeOutTween:Play()

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


FishingServer.playerStreaks = playerStreaks

return FishingServer
