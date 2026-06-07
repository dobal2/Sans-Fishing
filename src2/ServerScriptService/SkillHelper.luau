local SKILL_EFFECTS = {
	LuckUp      = { 0.10, 0.30, 0.60, 1.00, 1.50, 2.00, 2.50 },
	SellBonus   = { 0.10, 0.20, 0.30, 0.40, 0.50, 0.65 },
	FriendBonus = { 0.15, 0.30, 0.50 },
	HitZoneUp   = { 0.06, 0.10, 0.15 },
	WeightUp    = { 0.04, 0.10, 0.18, 0.28 },
	PowerUp     = { 0.05, 0.10, 0.20 },
	AutoUp      = { 0.1, 0.4, 0.8 },
	PointBoost  = { 1, 2, 3 },
	QuickBite   = { 0.5, 1.5, 2.5 },
}

local SkillHelper = {}

function SkillHelper.GetLevel(player, skillName)
	local folder = player:FindFirstChild("Skills")
	local sv = folder and folder:FindFirstChild(skillName)
	return sv and sv.Value or 0
end

function SkillHelper.GetEffect(player, skillName)
	local level = SkillHelper.GetLevel(player, skillName)
	if level == 0 then return 0 end
	local effects = SKILL_EFFECTS[skillName]
	return effects and (effects[level] or 0) or 0
end

function SkillHelper.GetLuckBonus(player)
	return SkillHelper.GetEffect(player, "LuckUp")
end

function SkillHelper.GetSellBonus(player)
	return SkillHelper.GetEffect(player, "SellBonus")
end

function SkillHelper.GetFriendBonusPerFriend(player)
	return SkillHelper.GetEffect(player, "FriendBonus")
end

function SkillHelper.GetHitZoneBonus(player)
	return SkillHelper.GetEffect(player, "HitZoneUp")
end

function SkillHelper.GetWeightMultiplier(player)
	return 1.0 + SkillHelper.GetEffect(player, "WeightUp")
end

function SkillHelper.GetPowerMultiplier(player)
	return 1.0 + SkillHelper.GetEffect(player, "PowerUp")
end

return SkillHelper
