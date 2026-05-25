local BobberData = {}

local DEFAULTS = {
	price = 0,
	luckBonus = 0,
	sellBonus = 0,
	heavyBonus = 0,
	rodPowerBonus = 0,
	frozenChance = 0,
	frozenMultiplier = 2.0,
	sansChance = 0,
	sansMultiplier = 3.0,
	festivalBonus = 0,
	stormLuckBonus = 0,
	doubleCatchChance = 0,
}

BobberData.Bobbers = {
	["Basic Bobber"] = {
		desc = "No effect",
	},
	["Lucky Bobber"] = {
		price = 500000,
		luckBonus = 0.30,
		desc = "Luck +30%",
	},
	["Frost Bobber"] = {
		price = 800000,
		frozenChance = 0.10,
		desc = "10% chance: Frozen variant (×2.0 value)",
	},
	["Heavyweight Bobber"] = {
		price = 1200000,
		heavyBonus = 0.18,
		sellBonus = 0.10,
		desc = "Heavy fish +18%  |  Sell +10%",
	},
	["Festival Bobber"] = {
		price = 1500000,
		festivalBonus = 0.30,
		desc = "Festival fish +30% (always)",
	},
	["Gold Bobber"] = {
		price = 2000000,
		sellBonus = 0.20,
		desc = "Sell value +20%",
	},
	["Coin Bobber"] = {
		price = 6000000,
		sellBonus = 0.35,
		desc = "Sell value +35%",
	},
	["Sans Bobber"] = {
		price = 3000000,
		sansChance = 0.05,
		desc = "5% chance: Sans variant (×3.0 value)",
	},
	["Storm Bobber"] = {
		price = 4000000,
		stormLuckBonus = 2.0,
		desc = "During Rain: Luck +200%",
	},
	["Black Hole Bobber"] = {
		price = 20000000,
		rodPowerBonus = 0.25,
		desc = "Rod Power +25%",
	},
	["Double Catch Bobber"] = {
		price = 50000000,
		doubleCatchChance = 0.40,
		desc = "40% chance to catch 2 fish",
	},
	["Robux Bobber"] = {
		price = 0,
		luckBonus = 0.80,
		sellBonus = 0.40,
		heavyBonus = 0.15,
		doubleCatchChance = 0.10,
		desc = "Luck +80%  |  Sell +40%  |  Heavy +15%  |  2x catch 10%",
	},
}

BobberData.ShopList = {
	{ name = "Lucky Bobber",        weight = 100 },
	{ name = "Frost Bobber",        weight = 80  },
	{ name = "Heavyweight Bobber",  weight = 70  },
	{ name = "Festival Bobber",     weight = 60  },
	{ name = "Gold Bobber",         weight = 45  },
	{ name = "Coin Bobber",         weight = 20  },
	{ name = "Sans Bobber",         weight = 30  },
	{ name = "Storm Bobber",        weight = 20  },
	{ name = "Black Hole Bobber",   weight = 8   },
	{ name = "Double Catch Bobber", weight = 3   },
}

-- Returns full effect table with defaults filled in
function BobberData.GetEffects(bobberName)
	local raw = BobberData.Bobbers[bobberName] or {}
	local result = {}
	for k, v in pairs(DEFAULTS) do
		result[k] = raw[k] ~= nil and raw[k] or v
	end
	return result
end

return BobberData
