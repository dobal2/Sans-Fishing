local clone = game.ReplicatedStorage:WaitForChild("NameTag"):Clone()
clone.Parent = script.Parent.Head
script.Parent = clone

local plr = game.Players:GetPlayerFromCharacter(script.Parent.Parent.Parent)
script.Parent.Parent.Parent:WaitForChild("Humanoid").DisplayDistanceType = "None"

script.Parent.name.Text = plr.DisplayName

local creator = "tallmo_bim"
local creator2 = "mkdoingsu"
local stupid = "Domald_tlump"

if plr.Name == creator then
	script.Parent.player.Text = "Developer"
elseif plr.Name == creator2 then
	script.Parent.player.Text = "Modeler"
elseif plr.Name == stupid then
	script.Parent.player.Text = "Stupid"
elseif plr.Name ~= creator and plr.Name ~= creator2 then
	script.Parent.player.Text = ""
end
