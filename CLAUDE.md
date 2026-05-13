# Sans Fishing — Project Guide

## Rojo Sync Scope

This project uses **Rojo** (`default.project.json`) to sync `src2/` into Roblox Studio.

| Source path | Roblox service / location |
|---|---|
| `src2/ServerScriptService/**` | ServerScriptService |
| `src2/StarterPlayer/StarterPlayerScripts/**` | StarterPlayer > StarterPlayerScripts |
| `src2/StarterPlayer/StarterCharacterScripts/**` | StarterPlayer > StarterCharacterScripts |
| `src2/ReplicatedStorage/Modules/` | ReplicatedStorage > Modules |
| `src2/ReplicatedStorage/TopbarPlus/` | ReplicatedStorage > TopbarPlus (excluded from refactoring) |
| `src2/ReplicatedStorage/DistanceFade.luau` | ReplicatedStorage > DistanceFade |
| `src2/StarterGui/**` | StarterGui (synced separately) |

Files **excluded from refactoring**: `ProfileService.luau`, TopbarPlus library, WindController library, Rain module.

---

## Project Structure

```
src2/
  ServerScriptService/
    leaderstats/               # Player data bootstrap + leaderstats init
      init.server.luau
      DataManager/             # ProfileService wrapper (coins, rods, fish, boats, traps, playtime, donations)
    ItemSave/                  # Fish inventory persistence
      init.server.luau
      DataManager/
      ChangedItemName.luau     # Rename mapping for legacy item names
    FishTrapManager/           # Fish trap placement, restoration, offline logic
      init.server.luau
      DataManager/             # ProfileService wrapper (trap positions + stored fish)
    QuestSaver/                # Quest state persistence
      init.server.luau
      DataManager/             # ProfileService wrapper (quest data)

    WeatherController.server.luau     # Initializes WeatherSystemModule, admin weather commands
    FishingServerStarter.server.luau  # Attaches FishingServerModule to each rod tool
    Shop.server.luau                  # Rod purchases (coins + RobuxRod gamepass)
    FishTrapShopSever.server.luau     # Fish trap purchases (coins + RobuxFishTrap gamepass)
    BoatShopSever.server.luau         # Boat purchases (coins)
    BoatSpawner.server.luau           # Spawns personal boats at designated spawn points
    BubbleShopSever.server.luau       # Bubble buff purchases (coins)
    ProcessReceipt.server.luau        # Robux developer product handler (donations + coin packs)
    FishTrapStole.server.luau         # Robux product handler for harvesting other players' traps
    GiveFish.server.luau              # ProximityPrompt fish transfer between players
    Lock.server.luau                  # Fish lock/unlock remote (server-side BoolValue)
    DailyRewardServer.server.luau     # 7-day rotating daily reward system
    LeaderBoard.server.luau           # Coin leaderboard (OrderedDataStore, top 10)
    DonationLeaderBoard.server.luau   # Donation leaderboard (OrderedDataStore, top 10)
    PlayTimeLeaderBoard.server.luau   # Playtime leaderboard (real-time + stored, top 10)
    Commands.server.luau              # Admin chat commands (speed, kick, setcoins, announce, DevRod, SlapBattle)
    Ban.server.luau                   # DataStore-based permanent ban system
    plrCodes.server.luau              # Redeem codes (stored in DataStore)
    Webhook.server.luau               # Discord webhook on player join/leave
    WelcomeBadge.server.luau          # Awards welcome badge on join
    EscapeTheWorld.server.luau        # Handles "escape the world" badge event
    GetFriendCount.server.luau        # RemoteFunction: count online friends (rate-limited)
    TutorialServerReciver.server.luau # Sets IsTutorialed flag on tutorial completion
    PlayerCollisionDisable.server.luau # Disables player-to-player collision via PhysicsService
    server.server.luau                # Platform detection RemoteEvent/RemoteFunction
    teleport.server.luau              # Teleports players to fixed CFrame positions (void areas)
    DeleteFishTrap.server.luau        # (All logic commented out, retained as placeholder)

  StarterPlayer/
    StarterPlayerScripts/
      FishingClientStarter.client.luau      # Attaches FishingClientModule to rod tools
      ClientWeatherHandler.client.luau      # Weather effects: Rain module, lighting tweens, fireworks
      HideMyFishGive.client.luau            # Controls ReceiveFishPrompt visibility based on held tool
      FishTrapClientProximityManager.client.luau  # Proximity prompt text for fish trap shop
      NpcHighLightAndDistance.client.luau   # NPC highlight and distance label
      DistanceFade.client.luau              # Wall fade effect via DistanceFade module
      DoNotFall.client.luau                 # Teleports player back to spawn if they fall/wander too far
      DontReset.client.luau                 # Disables the reset button
      TipChat.client.luau                   # Sends periodic tip messages in chat
      UnderWater.client.luau                # Underwater visual/lighting effect
      SnowIslandLightEffect.client.luau     # Lighting effect for snow island zone
      ErrorRoom.client.luau                 # Lighting effect for error/void room
      FishTrapBeam.client.luau              # Beam visual for placed fish trap
      WindController/                       # Third-party wind animation (excluded from refactoring)

    StarterCharacterScripts/
      HeadFollow.client.luau         # Head tracking toward cursor
      PreLoadAnimatins.client.luau   # Preloads character animations
      PromptFavorite.client.luau     # Shows favorite prompt on equip

  ReplicatedStorage/
    Modules/
      FishingServerModule.luau   # Core fishing server: cast, rope, fish selection, minigame, inventory
      FishingClientModule.luau   # Core fishing client: slider minigame, animations, GUI
      FishDataModule.luau        # Fish data tables, random fish selection, ice/festival effects
      FishDifficultyModule.luau  # Difficulty scaling per rarity (hit size, speed, attempts)
      FishingConfigModule.luau   # Per-rod config (RodPower, DifficultyMod)
      FishIceEffectModule.luau   # Applies/removes ice block overlay on frozen fish models
      WeatherSystemModule.luau   # Server-authoritative weather state machine
      RodDataModule.luau         # Rod definitions (price, storageName)
      BoatDataModule.luau        # Boat definitions (price, storageName)
      Rain.luau                  # Third-party rain particle module (excluded from refactoring)
    TopbarPlus/                  # Third-party topbar icon library (excluded from refactoring)
    DistanceFade.luau            # Third-party distance-fade effect module

  StarterGui/                    # All GUI client scripts (sell, shop, inventory, quests, notices, etc.)
```

---

## Major Systems

### Fishing

The fishing system is split across server and client modules.

**Server** (`FishingServerModule.luau`):
- `FishingServerStarter` attaches one `FishingServer` instance per rod tool.
- On `CastRod` fire: creates a bait `Part` (name `"Bait"`) in workspace, sets up a `Beam` fishing line, launches bait toward target.
- Bait landing: Heartbeat loop detects `bait.Position.Y <= WATER_SURFACE_Y (-3.4)`. On landing: anchors bait, fires `BaitLandedEvent:FireClient(player, restPos, baitPart)` to fishing player, fires `BaitSplashEvent` to all others.
- After landing: waits 2–3 seconds, selects fish via `FishDataModule`, fires fish data to client, starts minigame session.
- On `progress_success`: validates timing and inventory, awards fish tool to backpack.
- Security checks: session ID validation, minimum game time, inventory limit, player ownership.
- Retry gamepass (`RETRY_GAMEPASS_ID = 1290056221`): grants one retry per catch attempt.

**Client** (`FishingClientModule.luau`):
- Slider minigame: a tween-animated slider must land inside a hit zone.
- Hit zones: normal zone (+10 progress) and strong zone (+20 progress); miss subtracts 15.
- Minigame starts at 30% progress. Passive drain: 4 progress/second. Fail when progress hits 0.
- `_drainFired` flag prevents double-fire from drain + miss click.
- `BaitLandedEvent` listener: receives exact `baitPart` Instance from server, anchors it locally + plays splash effect (no Name collision with Workspace.Bait Model).
- `BaitSplashEvent` listener: spectators only, plays splash effect at position.
- Animations loaded via `WaitForChild` in `task.spawn` (async) from `ReplicatedStorage.Animations`.
- Animation IDs: Fishing=136011514785364, Finish=85733537741100, Waiting=79818740579248, Holding=71325506664100, FishBaitEat=110856542062910, Reeling=113396780604450, HoldBigFish=131373652396216.
- Finish animation: `_playFinishAnimation()` is self-contained — stops all tracks, plays Finish (Action4 priority), waits for Ended, then plays Holding. No external race condition.
- Inventory expansion gamepass (`INVENTORY_EXPANSION_GAMEPASS_ID = 1294285302`) raises cap from 100 to 200 fish.

**Known issues (as of 2026-05-14)**:
- Finish animation may still not play — root cause was `preloadedFinishAnimation = nil` due to `FindFirstChild` timing. Fixed with `WaitForChild` async preload + direct fallback in `_playFinishAnimation`. Needs verification.
- Bait landing position: actual water surface Y ≈ -3.69, `WATER_SURFACE_Y = BAIT_REST_Y = -3.4`. Small discrepancy may cause slight imprecision. Splash sound/effect asset IDs have authorization errors in Studio test mode (not a code bug).

### Fish Data

`FishDataModule.luau` contains all fish definitions organized by rarity. Each fish has `fishName`, `value`, `minWeight`, `maxWeight`, `model` reference, and rarity metadata.

- Weather modifiers: Snow adds "Frozen " prefix and 2× value; Firework adds "Festival " prefix and 1.5× value; Rain adds 1.2× size.
- Luck gamepass (`LuckGamePassId = 1289569606`) boosts rare fish probability.
- Fish tool names follow the format: `"FishName [Rarity] - X.Xkg"`.

### Data Storage (ProfileService)

All persistent data uses ProfileService. Each system has its own `DataManager` module:

| DataManager | Store key | Data |
|---|---|---|
| `leaderstats/DataManager` | `"PlayerData7"` | Coins, Rods, Fish catalog, Boats, FishTraps, Playtime, Donations |
| `ItemSave/DataManager` | `"PlayerItems3"` | Fish inventory (tool name, value, weight, rarity, lock state) |
| `FishTrapManager/DataManager` | `"FishTrapData2"` | Trap position (TrapId, CFrame), stored fish list |
| `QuestSaver/DataManager` | `"QuestData4"` | Active quests, completed quests, daily playtime quest |

Leaderboards use `OrderedDataStore` (coins, donations, playtime) updated on data save.

### Weather System

`WeatherSystemModule.luau` runs server-authoritatively. Weather types: Clear, Rain, Snow, Firework.

- Cycle: 600-second period, 300-second duration, 300-second cooldown.
- Firework only occurs between 18:00 and 06:00 game time (Lighting.TimeOfDay).
- `WeatherChangedEvent` (RemoteEvent) broadcasts changes to all clients.
- `FireworkEffectEvent` (RemoteEvent) triggers additional client-side firework bursts during active firework weather.
- Client-side handler (`ClientWeatherHandler.client.luau`) controls the Rain module, lighting tweens (Atmosphere density, Blur, SunRays), and particle firework effects.

### Shop Systems

All shops communicate via BindableEvent or RemoteEvent from GUI scripts to server scripts.

| Shop | Script | Mechanism |
|---|---|---|
| Rod shop | `Shop.server.luau` | `BuyFishingRod` RemoteEvent; validates coin balance and gamepass for RobuxRod |
| Fish trap shop | `FishTrapShopSever.server.luau` | `BuyFishTrapBindable` BindableEvent; validates coins or `ROBUX_FISHTRAP_GAMEPASS_ID = 1423175879` |
| Boat shop | `BoatShopSever.server.luau` | `BuyBoat` RemoteEvent; validates coin balance |
| Bubble shop | `BubbleShopSever.server.luau` | `BuyBubbleBindable` BindableEvent; validates coins and inventory space |

### Fish Trap System

- Players place up to one fish trap at a time.
- `FishTrapManager` restores trap position from DataStore on join and saves on leave.
- Traps accumulate fish offline based on elapsed time since placement.
- Harvesting another player's trap requires purchasing a Robux developer product (`FishTrapStole.server.luau`).

### Quest System

`QuestSaver` manages three quest categories:
- **Normal quests**: catch N of a specific fish; progress updated by `FishingServerModule` on catch.
- **Daily playtime quest**: earn coins based on minutes played that day; tracked via `Playtime` value.
- **Void quest**: one-time challenge to unlock the VoidRod.

### Admin System

`Commands.server.luau` uses a rank table (`Developer`, `Moderator`) checked by username. Commands are prefixed with `:`. Cross-server messaging uses `MessagingService` for `GlobalAnnouncement`, `GlobalCoinGive`, `GlobalSlapBattleGive`, `GlobalDevRodGive`.

---

## Coding Conventions

- **Service declarations**: all `game:GetService()` calls at the top of the file; never inline.
- **Scheduler**: always use `task.wait()`, `task.spawn()`, `task.delay()`, `task.cancel()` — never bare `wait()` or `spawn()`.
- **Comments**: English only; keep only comments that explain non-obvious logic; remove noise comments.
- **Early returns**: validate and return early rather than deep nesting.
- **Constants**: magic numbers go in named constants at the top of the file (e.g. `RETRY_GAMEPASS_ID`, `WEATHER_CYCLE_TIME`).
- **Security**: all purchases and fishing events are server-validated; client input is never trusted for economy changes.
- **OOP pattern**: `FishingServerModule` and `FishingClientModule` use `setmetatable({}, Class)` instances with `__index`, one instance per tool.
- **ProfileService**: data is accessed via `DataManager:GetData(player)` and modified via `DataManager:UpdateData(player, key, value)`.
- **File naming**: server scripts end in `.server.luau`, client scripts in `.client.luau`, module scripts in `.luau`.
