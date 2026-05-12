-- FishingConfigModule (ModuleScript in ReplicatedStorage.Modules)
return {
	FishingRod = {
		Distance = 60,
		Rarity = "Common",
		RodPower = 1.2,        -- Base power (raised from 1.0 to 1.2)
		DifficultyMod = 1.0    -- Base difficulty
	},
	SliverRod = {
		Distance = 80,
		Rarity = "Uncommon",
		RodPower = 1.38,       -- +15% power (1.2 x 1.15)
		DifficultyMod = 0.85   -- 15% easier
	},
	GoldRod = {
		Distance = 85,
		Rarity = "Rare",
		RodPower = 1.41,       -- +17.5% power (1.2 x 1.175)
		DifficultyMod = 0.825  -- 17.5% easier
	},
	CrystalRod = {
		Distance = 90,
		Rarity = "Epic",
		RodPower = 1.44,       -- +20% power (1.2 x 1.2)
		DifficultyMod = 0.8    -- 20% easier
	},
	MagneticRod = {
		Distance = 95,
		Rarity = "Epic",
		RodPower = 1.5,        -- +25% power (1.2 x 1.25)
		DifficultyMod = 0.75   -- 25% easier
	},
	BoneRod = {
		Distance = 100,
		Rarity = "Fantasy",
		RodPower = 1.56,       -- +30% power (1.2 x 1.3)
		DifficultyMod = 0.7    -- 30% easier
	},
	CloverRod = {
		Distance = 105,
		Rarity = "Mystic",
		RodPower = 1.65,       -- +37.5% power (1.2 x 1.375)
		DifficultyMod = 0.625  -- 37.5% easier
	},
	RainbowRod = {
		Distance = 110,
		Rarity = "Legendary",
		RodPower = 1.74,       -- +45% power (1.2 x 1.45)
		DifficultyMod = 0.55   -- 45% easier
	},
	UnknownRod = {
		Distance = 115,
		Rarity = "Unknown",
		RodPower = 1.86,       -- +55% power (1.2 x 1.55)
		DifficultyMod = 0.45   -- 55% easier
	},
	RobuxRod = {
		Distance = 115,
		Rarity = "Unknown",
		RodPower = 1.92,
		DifficultyMod = 0.45
	},
	ElectricRod = {
		Distance = 120,
		Rarity = "Unknown",
		RodPower = 1.98,       -- +65% power (1.2 x 1.65)
		DifficultyMod = 0.35   -- 65% easier
	},
	RealisticRod = {
		Distance = 120,
		Rarity = "Unknown",
		RodPower = 2.16,       -- +80% power (1.2 x 1.8)
		DifficultyMod = 0.2    -- 80% easier
	},
	ArcaneRod = {
		Distance = 125,
		Rarity = "Unobtainable",
		RodPower = 2.22,       -- +85% power (1.2 x 1.85)
		DifficultyMod = 0.15   -- 85% easier
	},
	VoidRod = {
		Distance = 125,
		Rarity = "Unobtainable",
		RodPower = 3.0,       -- +85% power (1.2 x 1.85)
		DifficultyMod = 0.15   -- 85% easier
	},
	FriendRod = {
		Distance = 120,
		Rarity = "Special",
		RodPower = 2.2,       -- Special rod (1.2 x 2.2)
		DifficultyMod = 0.1    -- 90% easier
	},
	DevRod = {
		Distance = 150,
		Rarity = "Unobtainable",
		RodPower = 1972,       -- Developer rod
		DifficultyMod = 0.1
	}
}
