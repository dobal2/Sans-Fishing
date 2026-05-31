local DialogModule = {}
DialogModule.__index = DialogModule

local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local soundsFolder = ReplicatedStorage:WaitForChild("Sounds")
local tickSound    = soundsFolder:WaitForChild("Talk")

local COMIC_FONT = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)

local function ensureNpcGui(head, npcName)
	local existing = head:FindFirstChildOfClass("BillboardGui")
	if existing then
		-- Ensure it has the right children
		if not existing:FindFirstChild("dialog") then
			local dlg = Instance.new("TextLabel")
			dlg.Name = "dialog"
			dlg.BackgroundTransparency = 1
			dlg.Size = UDim2.new(1, 0, 0, 55)
			dlg.Position = UDim2.new(0, 0, 0, 40)
			dlg.TextColor3 = Color3.fromRGB(255, 255, 255)
			dlg.TextScaled = true
			dlg.FontFace = COMIC_FONT
			dlg.RichText = true
			dlg.TextWrapped = true
			dlg.TextTransparency = 1
			dlg.Parent = existing
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color = Color3.fromRGB(0, 0, 0)
			stroke.Transparency = 1
			stroke.Parent = dlg
		end
		return existing
	end

	local bg = Instance.new("BillboardGui")
	bg.Name        = "NpcGui"
	bg.Size        = UDim2.new(0, 380, 0, 95)
	bg.StudsOffset = Vector3.new(0, 2, 0)
	bg.AlwaysOnTop = false
	bg.Parent      = head

	local function makeLabel(name, posY, sizeY)
		local lbl = Instance.new("TextLabel")
		lbl.Name               = name
		lbl.BackgroundTransparency = 1
		lbl.Size               = UDim2.new(1, 0, 0, sizeY)
		lbl.Position           = UDim2.new(0, 0, 0, posY)
		lbl.TextColor3         = Color3.fromRGB(255, 255, 255)
		lbl.TextScaled         = true
		lbl.FontFace           = COMIC_FONT
		lbl.RichText           = true
		lbl.TextWrapped        = true
		lbl.Parent             = bg
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color     = Color3.fromRGB(0, 0, 0)
		stroke.Parent    = lbl
		return lbl
	end

	local nameLabel  = makeLabel("name",   0, 24)
	nameLabel.Text   = npcName

	local arrowLabel = makeLabel("arrow", 24, 16)
	arrowLabel.Text  = "▼"

	local dialogLabel = makeLabel("dialog", 40, 55)
	dialogLabel.TextTransparency      = 1
	dialogLabel.UIStroke.Transparency = 1

	return bg
end

function DialogModule.new(npcName, npcRoot, npcHead, prompt)
	local self     = setmetatable({}, DialogModule)
	self.npcName   = npcName
	self.npcRoot   = npcRoot
	self.npcHead   = npcHead
	self.prompt    = prompt
	self.dialogs   = {}
	self.active    = false
	self.talking   = false
	self._typewriterGen = 0  -- 타이핑 세대 카운터 (새 대화 시작 시 이전 타이핑 중단용)

	self.npcGui = ensureNpcGui(npcHead, npcName)

	local player    = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local responseScreen = Instance.new("ScreenGui")
	responseScreen.Name         = "DialogResponses_" .. npcName
	responseScreen.ResetOnSpawn = false
	responseScreen.DisplayOrder = -1
	responseScreen.Enabled      = false
	responseScreen.Parent       = playerGui

	local responseFrame = Instance.new("Frame")
	responseFrame.Name                   = "responseFrame"
	responseFrame.Size                   = UDim2.new(0.25, 0, 0.36, 0)
	responseFrame.BackgroundTransparency = 1
	responseFrame.AnchorPoint           = Vector2.new(0, 0.5)
	responseFrame.Parent                = responseScreen

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection     = Enum.FillDirection.Vertical
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.SortOrder         = Enum.SortOrder.LayoutOrder
	listLayout.Padding           = UDim.new(0.005, 0)
	listLayout.Parent            = responseFrame

	self.responseScreen = responseScreen
	self.responseFrame  = responseFrame

	RunService.RenderStepped:Connect(function()
		if not responseScreen.Enabled then return end
		local cam = workspace.CurrentCamera
		local vp  = cam.ViewportSize
		local sp, onScreen = cam:WorldToScreenPoint(npcHead.Position)
		if onScreen then
			responseFrame.Position = UDim2.new(
				(sp.X + vp.X * 0.055) / vp.X, 0,
				(sp.Y + vp.Y * 0.07)  / vp.Y, 0
			)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if self.talking then
			self.npcGui.StudsOffset = Vector3.new(0, 2, 0)
		else
			self.npcGui.StudsOffset = Vector3.new(0, 2 + math.sin(os.clock() * 2) * 0.06, 0)
		end
	end)

	local eventSignal  = Instance.new("BindableEvent")
	self.responded     = eventSignal.Event
	self.fireResponded = eventSignal

	player.CharacterAdded:Connect(function()
		if self.active then self:hideGui() end
	end)

	return self
end

local function typewriter(label, text, getGen, myGen)
	local plain = text:gsub("<[^>]+>", "")
	label.Text = ""
	local cur = ""
	for _, ch in string.split(plain, "") do
		if getGen() ~= myGen then return end  -- 새 대화가 시작되면 즉시 중단
		cur = cur .. ch
		label.Text = cur
		if ch ~= " " then
			tickSound:Play()
		end
		task.wait(0.025)
	end
	if getGen() == myGen then
		label.Text = text
	end
end

function DialogModule:addDialog(text, responses)
	table.insert(self.dialogs, {text = text, responses = responses or {}})
end

function DialogModule:clearResponses()
	for _, c in ipairs(self.responseFrame:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	self.responseScreen.Enabled = false
end

function DialogModule:triggerDialog(player, dialogNum)
	local dialog = self.dialogs[dialogNum or 1]
	if not dialog then return end

	-- 새 대화 세대 번호 부여 → 이전 typewriter 루프가 중단됨
	self._typewriterGen = self._typewriterGen + 1
	local myGen = self._typewriterGen

	-- 이전 대화 상태 강제 종료
	self.active  = false
	self.talking = false
	self:clearResponses()

	self:_showGui()
	TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 65}):Play()

	task.spawn(function()
		self.talking = true
		local dlg = self.npcGui:FindFirstChild("dialog")
		if not dlg then self.talking = false return end
		dlg.Visible = true
		typewriter(dlg, dialog.text, function() return self._typewriterGen end, myGen)
		if self._typewriterGen ~= myGen then return end  -- 도중에 새 대화 시작됐으면 중단
		self.talking = false

		self:clearResponses()
		local responseNum = nil
		local keyBinds    = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five}

		for i, resp in ipairs(dialog.responses) do
			local btn = Instance.new("TextButton")
			btn.Name = tostring(i)
			local vp  = workspace.CurrentCamera.ViewportSize
			local btnH = math.clamp(math.floor(vp.Y * 0.055), 36, 72)
			local txtS = math.clamp(math.floor(vp.Y * 0.028), 18, 36)
			btn.Size                   = UDim2.new(1, 0, 0, btnH)
			btn.BackgroundTransparency = 1
			btn.BorderSizePixel        = 0
			btn.LayoutOrder            = i
			btn.Text                   = "<font color='rgb(255,220,127)'>" .. i .. ".)</font> ['" .. resp .. "']"
			btn.TextColor3             = Color3.fromRGB(255, 255, 255)
			btn.TextXAlignment         = Enum.TextXAlignment.Left
			btn.TextScaled             = false
			btn.TextSize               = txtS
			btn.FontFace               = COMIC_FONT
			btn.RichText               = true
			btn.TextWrapped            = false
			btn.TextTruncate           = Enum.TextTruncate.AtEnd
			btn.Active                 = true
			btn.Parent                 = self.responseFrame

			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color     = Color3.fromRGB(0, 0, 0)
			stroke.Parent    = btn

			local enterCon = btn.MouseEnter:Connect(function()
				TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Size = UDim2.new(1.06, 0, 0, math.floor(btnH * 1.15))}):Play()
				TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.5, BackgroundColor3 = Color3.fromRGB(40, 40, 60)}):Play()
			end)
			local leaveCon = btn.MouseLeave:Connect(function()
				TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.new(1, 0, 0, btnH)}):Play()
				TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 1, BackgroundColor3 = Color3.fromRGB(20, 20, 30)}):Play()
			end)
			local clickCon = btn.MouseButton1Click:Connect(function()
				if not self.active then return end
				self.active  = false
				responseNum  = i
				self.fireResponded:Fire(i, dialogNum)
			end)
			local keyCon = UserInputService.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
				if table.find(keyBinds, input.KeyCode) == i then
					if not self.active then return end
					self.active = false
					responseNum = i
					self.fireResponded:Fire(i, dialogNum)
				end
			end)

			coroutine.wrap(function()
				repeat task.wait() until responseNum ~= nil
				enterCon:Disconnect(); leaveCon:Disconnect()
				clickCon:Disconnect(); keyCon:Disconnect()
			end)()

			task.wait(0.15)
		end

		if #dialog.responses > 0 then self.responseScreen.Enabled = true end
		self.active = true

		while self.active do
			local char = player.Character
			if not char then break end
			local root = char:FindFirstChild("HumanoidRootPart")
			if not root then break end
			if (root.Position - self.npcRoot.Position).Magnitude > 18 then
				self:hideGui(); break
			end
			task.wait()
		end
	end)
end

function DialogModule:_showGui()
	local gui = self.npcGui
	local nameLabel  = gui:FindFirstChild("name")
	local arrowLabel = gui:FindFirstChild("arrow")
	local dlgLabel   = gui:FindFirstChild("dialog")
	if nameLabel then
		TweenService:Create(nameLabel,                 TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(nameLabel.UIStroke,        TweenInfo.new(0.3), {Transparency = 1}):Play()
	end
	if arrowLabel then
		TweenService:Create(arrowLabel,                TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(arrowLabel.UIStroke,       TweenInfo.new(0.3), {Transparency = 1}):Play()
	end
	if dlgLabel then
		dlgLabel.TextTransparency      = 0
		dlgLabel.UIStroke.Transparency = 0
	end
end

function DialogModule:hideGui(exitQuip)
	self.active = false
	self:clearResponses()
	TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 70}):Play()

	local dlg = self.npcGui:FindFirstChild("dialog")

	if exitQuip and dlg then
		self._typewriterGen = self._typewriterGen + 1
		local myGen = self._typewriterGen
		dlg.TextTransparency      = 0
		dlg.UIStroke.Transparency = 0
		dlg.Text = ""
		task.spawn(function()
			typewriter(dlg, exitQuip, function() return self._typewriterGen end, myGen)
			if self._typewriterGen ~= myGen then return end
			task.wait(2.5)
			if self._typewriterGen ~= myGen then return end
			self:_fadeToIdle()
		end)
	else
		self:_fadeToIdle()
	end
end

function DialogModule:_fadeToIdle()
	if self.prompt then self.prompt.Enabled = true end
	local gui        = self.npcGui
	local nameLabel  = gui:FindFirstChild("name")
	local arrowLabel = gui:FindFirstChild("arrow")
	local dlgLabel   = gui:FindFirstChild("dialog")
	if nameLabel then
		nameLabel.Visible = true
		nameLabel.TextTransparency      = 0
		nameLabel.UIStroke.Transparency = 0
	end
	if arrowLabel then
		arrowLabel.Visible = true
		arrowLabel.TextTransparency      = 0
		arrowLabel.UIStroke.Transparency = 0
	end
	if dlgLabel then
		TweenService:Create(dlgLabel,          TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(dlgLabel.UIStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
	end
end

return DialogModule
