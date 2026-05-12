local Char = game.Players.LocalPlayer.Character
local Head : BasePart = Char:WaitForChild("Head")
local Camera = workspace.CurrentCamera
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local Hum : Humanoid = Char:WaitForChild("Humanoid")
local Root : BasePart = Char:WaitForChild("HumanoidRootPart")
local Time = 0.1
RS.RenderStepped:Connect(function()
	if Camera.CameraType == Enum.CameraType.Custom then
	if Head and Root and Hum.Health > 0 then
		local pos = Vector3.new(Head.Position.X - Root.Position.X,Head.Position.Y - Root.Position.Y,Head.Position.Z - Root.Position.Z)
		local tween = game:GetService("TweenService"):Create(Hum,TweenInfo.new(0.1,Enum.EasingStyle.Linear),{
			CameraOffset = Root.CFrame:ToObjectSpace(Head.CFrame).Position - Vector3.new(0,1.25,0)
		})
		tween:Play()
	elseif Hum.Health <= 0 then
		Hum.CameraOffset = Vector3.zero
		end
	end
end)
