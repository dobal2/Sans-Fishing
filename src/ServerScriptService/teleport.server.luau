local RS = game:GetService("ReplicatedStorage")
local plr = game:GetService("Players")

local Playerposition = {
	[1] = CFrame.new(50000, 0, -50000),
	[2] = CFrame.new(-50000, -50000, -70000),
	[3] = CFrame.new(50000, 50000, -90000)

	-- Add more if you want
}

local function position(player, Positionindex)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local RootPart = RS.UnlimitedVoid.RootPart:Clone()
		RootPart.Parent = workspace.Visuals
		RootPart.CFrame = hrp.CFrame * Playerposition[Positionindex]
	end
end

for i, player in ipairs(plr:GetPlayers()) do
	if player.Character then
		position(player, i)
	end
end
