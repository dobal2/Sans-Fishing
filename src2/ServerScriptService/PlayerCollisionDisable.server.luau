local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local GROUP = "Players"

-- RegisterCollisionGroup replaces the deprecated CreateCollisionGroup
PhysicsService:RegisterCollisionGroup(GROUP)
PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)

local function setCollisionGroup(object)
	if object:IsA("BasePart") then
		object.CollisionGroup = GROUP
	end
end

local function setCollisionGroupRecursive(object)
	setCollisionGroup(object)
	for _, child in ipairs(object:GetChildren()) do
		setCollisionGroupRecursive(child)
	end
end

local function onCharacterAdded(character)
	setCollisionGroupRecursive(character)
	character.DescendantAdded:Connect(setCollisionGroup)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacterAdded)
end)
