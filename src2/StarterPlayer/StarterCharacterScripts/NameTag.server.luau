local ReplicatedStorage = game:GetService("ReplicatedStorage")

local clone = ReplicatedStorage:WaitForChild("NameTag"):Clone()
clone.Parent = script.Parent.Head
script.Parent = clone

local nameTag = script.Parent
local character = nameTag.Parent.Parent  -- Head.NameTag → Head → Character
local plr = game.Players:GetPlayerFromCharacter(character)
character:WaitForChild("Humanoid").DisplayDistanceType = "None"

nameTag.name.Text = plr.DisplayName

local creator = "tallmo_bim"
local creator2 = "mkdoingsu"
local stupid = "Domald_tlump"

if plr.Name == creator then
	nameTag.player.Text = "Developer"
elseif plr.Name == creator2 then
	nameTag.player.Text = "Modeler"
elseif plr.Name == stupid then
	nameTag.player.Text = "Stupid"
else
	nameTag.player.Text = ""
end
