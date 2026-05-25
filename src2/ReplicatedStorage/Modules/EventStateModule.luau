-- Server-wide event multipliers. Modified at runtime by admin commands.
-- All server scripts share the same table instance (module cache), so
-- writing to this table from Commands.server immediately affects all readers.
local EventState = {
	CoinMultiplier   = 1,  -- multiplies final fish sell value
	LuckMultiplier   = 1,  -- multiplies accumulated luckBonus in GetRandomFish
	WeightMultiplier = 1,  -- multiplies fish weight (clamped to per-fish maxWeight)
	FPMultiplier     = 1,  -- multiplies fishing points earned per catch
}

return EventState
