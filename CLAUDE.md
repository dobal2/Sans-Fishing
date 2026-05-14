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

**Important**: All client scripts now live in `StarterPlayerScripts` (not inside StarterGui ScreenGuis). StarterGui ScreenGuis contain only UI elements (Frames, Labels, Buttons) — no LocalScripts inside them.

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

    RemoteInit.server.luau               # Creates all RemoteEvents/Folders in ReplicatedStorage on start
    WeatherController.server.luau        # Initializes WeatherSystemModule, admin weather commands
    FishingServerStarter.server.luau     # Attaches FishingServerModule to each rod tool
    Shop.server.luau                     # Rod purchases (coins + RobuxRod gamepass)
    FishTrapShopSever.server.luau        # Fish trap purchases (coins + RobuxFishTrap gamepass)
    BubbleShopSever.server.luau          # Bubble buff purchases (coins)
    ProcessReceipt.server.luau           # Robux developer product handler (donations + coin packs)
    FishTrapStole.server.luau            # Robux product handler for harvesting other players' traps
    GiveFish.server.luau                 # ProximityPrompt fish transfer between players
    Lock.server.luau                     # Fish lock/unlock (creates FishLockEvent at RS root)
    LeaderBoard.server.luau              # Coin leaderboard (OrderedDataStore, top 10)
    DonationLeaderBoard.server.luau      # Donation leaderboard (OrderedDataStore, top 10)
    PlayTimeLeaderBoard.server.luau      # Playtime leaderboard (real-time + stored, top 10)
    CoinLeaderboardServer.server.luau    # Coin leaderboard server handler
    PlayTimeLeaderboardServer.server.luau
    Commands.server.luau                 # Admin chat commands (speed, kick, setcoins, announce, DevRod, SlapBattle)
    Ban.server.luau                      # DataStore-based permanent ban system
    plrCodes.server.luau                 # Redeem codes (stored in DataStore)
    Webhook.server.luau                  # Discord webhook on player join/leave
    WelcomeBadge.server.luau             # Awards welcome badge on join
    EscapeTheWorld.server.luau           # Handles "escape the world" badge event
    GetFriendCount.server.luau           # RemoteFunction: count online friends (rate-limited)
    TutorialServerReciver.server.luau    # Sets IsTutorialed flag on tutorial completion
    PlayerCollisionDisable.server.luau   # Disables player-to-player collision via PhysicsService
    server.server.luau                   # Platform detection RemoteEvent/RemoteFunction
    teleport.server.luau                 # Teleports players to fixed CFrame positions (void areas)
    ServerBoostManager.server.luau       # Server boost product handler (creates ServerBoostRemote, GetBoostState at RS root)
    GamblerHandler.server.luau           # Gamble sell handler
    SellShopHandler.server.luau          # Sell shop handler
    UpgradeShopHandler.server.luau       # Upgrade shop handler
    PapHandler.server.luau               # PAP handler
    ChairHandler.server.luau             # Chair sit handler
    LikeCounterHandler.server.luau       # Like counter
    FishDiscoverReward.server.luau       # Fish discovery reward
    BubbleProximityHandler.server.luau   # Bubble proximity prompt
    FishTrapProximityHandler.server.luau # Fish trap proximity prompt
    QuestSaver/                          # (see above)

  StarterPlayer/
    StarterPlayerScripts/
      # --- Fishing ---
      FishingClientStarter.client.luau        # Attaches FishingClientModule to rod tools
      AutoFishing.client.luau                 # Auto fishing controller

      # --- Main GUI ---
      Main.client.luau                        # Main GUI init (shop open, click sound)
      Main_AutoButton_AutoButtonController.client.luau
      Main_DeviceDetect.client.luau           # Detects PC/mobile, fires server
      Main_Fishing_Fishing_Teleport.client.luau
      Main_Sell_Sell_Teleport.client.luau
      Main_Upgrade_Upgrade_Teleport.client.luau
      Main_FreeReward_FreeReward.client.luau
      Main_FreeRewardShop.client.luau
      Main_NoticeFrame_NoticeSystem.client.luau  # ALL notice/announce events → Main.NoticeFrame
      Main_RandomFishClient.client.luau       # Random fish gacha reveal UI
      Main_FriendBonus.client.luau            # Friend bonus text label updater
      Main_Money.client.luau                  # CoinText label updater
      Main_WeatherInfo.client.luau            # Weather icon updater

      # --- Shop / Robux ---
      ShopGui.client.luau                     # Rod shop GUI (arrow buttons, item display)
      RobuxShop.client.luau                   # Robux shop open handler
      RobuxShopButtons.client.luau            # Gamepass buy buttons (Coin x2, Luck x2, Power x2)
      ServerBoostClient.client.luau           # Server boost UI inside RobuxShop

      # --- Sell / Gamble / Quest options ---
      SellOptions.client.luau                 # Sell options GUI open
      SellOptions_Sell.client.luau
      SellOptions_SellHandler.client.luau
      SellOptions_SellOptions.client.luau
      GambleOptions.client.luau               # Gamble options GUI open
      GambleOptions_Sell.client.luau
      QuestOptions.client.luau
      QuestOptions_Sell.client.luau
      OptionButtonTween.client.luau           # Animates SellOptions/GambleOptions/QuestOptions buttons

      # --- Inventory ---
      CustomInventory/                        # Folder → LocalScript with SETTINGS child module
        init.client.luau                      # Custom hotbar + inventory system
        SETTINGS.luau                         # Inventory module (tool slots, drag, lock)

      # --- Index (fish catalog) ---
      Index.client.luau                       # Fish catalog UI

      # --- Quest ---
      QuestGui.client.luau                    # Quest list UI (reads leaderstats.Quests.ActiveQuests)

      # --- Topbar / UI ---
      TopbarController.client.luau            # TopbarPlus icon setup
      UIStrokeScale.client.luau               # Scales UIStroke thickness with screen size
      NpcDialogClient.client.luau             # NPC dialog system
      NpcHighLightAndDistance.client.luau     # NPC highlight and distance label

      # --- World / Environment ---
      ClientWeatherHandler.client.luau        # Weather effects: Rain module, lighting tweens, fireworks
      HideMyFishGive.client.luau              # Controls ReceiveFishPrompt visibility
      FishTrapClientProximityManager.client.luau
      FishTrapBeam.client.luau                # Beam visual for placed fish trap
      DistanceFade.client.luau                # Wall fade effect via DistanceFade module
      DoNotFall.client.luau                   # Teleports player back to spawn if fallen
      DontReset.client.luau                   # Disables the reset button
      TipChat.client.luau                     # Periodic tip messages in chat
      UnderWater.client.luau                  # Underwater visual/lighting effect
      SnowIslandLightEffect.client.luau       # Lighting effect for snow island zone
      ErrorRoom.client.luau                   # Lighting effect for error/void room
      WindController/                         # Third-party wind animation (excluded from refactoring)

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
```

---

## Remote Structure

All Remotes live under `ReplicatedStorage.Remotes.[Category]`:

| Category | Remotes |
|---|---|
| `Fishing` | ShowBeamEvent, BaitLandedEvent, BaitSplashEvent, RandomFishResult, FishDiscoverReward, TriggerRandomFish (Bindable), SetFavoriteRemote |
| `Shop` | BuyFishingRod, OpenShop, OpenBoatShop, OpenRobuxShop, BuyBoat, SpawnBoat, ShopSellerDialog, OpenGearShop, codeEvent, OpenShopLocal (Bindable), BuyFishTrapBindable (Bindable), BuyBubbleBindable (Bindable) |
| `Sell` | SellChoiceEvent, SellGuiEvent, SetPromptEvent, SoldNotification, TalkEvent, GambleChoiceEvent, GambleGuiEvent, GambleNotification |
| `Notice` | ShowNoticeEvent, FishNoticeEvent, NoticeEventForClient (Bindable), TutorialEvent (Bindable), DiscoverNoticeEvent |
| `Quest` | QuestGuiEvent, QuestReceiveEvent, QuestCompleteEvent, QuestNotification, QuestChoiceEvent, Quest Giver |
| `Weather` | WeatherChangedEvent, FireworkEffectEvent |
| `Misc` | EscapeTheWorld, DonationRefresh, ClaimDailyReward, CheckDailyReward |

**RS root (created at runtime by server scripts, not in Remotes folder)**:
- `FishLockEvent` — fish lock toggle (Lock.server.luau)
- `FishReceiveNoticeEvent` — fish give notification (GiveFish.server.luau)
- `CodeResponseEvent` — code redeem result (plrCodes.server.luau)
- `AnnounceRemote` — global announcement (Commands.server.luau)
- `ServerBoostRemote` — server boost purchase (ServerBoostManager.server.luau)
- `GetBoostState` (RemoteFunction) — query current boost state
- `GetFriendsCountRemote` (RemoteFunction) — friend count query
- `VoidQuestEvents/` folder — VoidQuestGuiEvent, VoidQuestChoiceEvent
- `VoidRodEvents/` folder — OpenVoidShop, VoidShopNotice
- `RandomFishResult` — random fish gacha result

---

## Studio GUI Structure

**StarterGui ScreenGuis** (UI elements only, no LocalScripts inside):
- `Main` — main HUD (CoinText, FriendBonusText, WeatherInfo, NoticeFrame, RandomFish, AutoButton, Fishing/Sell/Upgrade frames, etc.)
- `SellOptions` — sell choice popup (Option1~4)
- `GambleOptions` — gamble choice popup (Option1~2)
- `QuestOptions` — quest choice popup (Option1~2)
- `ShopGui` — rod shop UI
- `RobuxShop` — robux shop (Shop/Main/ScrollingFrame/Passes + ServerBoost)
- `Custom Inventory` — hotbar + inventory (contains `toolButton` ImageButton as hidden slot template, `openButton`, `hotBar`, `Inventory`, `FishCount`)
- `ScreenGui` — misc UI
- `Index` — fish catalog UI (IndexFrame, ShadowFrame)
- `QuestGui` — quest list (Frame/ScrollingFrame, Template at root)
- `DailyRewards` — daily reward UI (disabled, not in use)
- `RandomFish` — random fish reveal UI

**Custom Inventory note**: `toolButton` (slot template) lives at `Custom Inventory` root with `Visible = false`. It is cloned for each inventory/hotbar slot and `Visible = true` is set on each clone.

---

## Disabled Systems

These are present in codebase but disabled in `default.project.json`:
- **Boat system** — BoatShopSever, BoatSpawner, BoatDealerHandler, BoatBuoyancy, BoatShop client
- **Daily Reward** — DailyRewardServer, DailyRewards client (UI exists in Studio but unused)

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
- `BaitLandedEvent` listener: receives exact `baitPart` Instance from server, anchors it locally + plays splash effect.
- `BaitSplashEvent` listener: spectators only, plays splash effect at position.
- Animations loaded via `WaitForChild` in `task.spawn` (async) from `ReplicatedStorage.Animations`.
- Animation IDs: Fishing=136011514785364, Finish=85733537741100, Waiting=79818740579248, Holding=71325506664100, FishBaitEat=110856542062910, Reeling=113396780604450, HoldBigFish=131373652396216.
- Inventory expansion gamepass (`INVENTORY_EXPANSION_GAMEPASS_ID = 1294285302`) raises cap from 100 to 200 fish.

### Notice System

All notices route through `Main_NoticeFrame_NoticeSystem.client.luau` → `Main.NoticeFrame`.
Events handled: `FishNoticeEvent`, `ShowNoticeEvent`, `NoticeEventForClient`, `DiscoverNoticeEvent`, `FishReceiveNoticeEvent`, `AnnounceRemote`.
**Do not add LocalScripts inside StarterGui ScreenGuis for notices** — they will duplicate.

### Custom Inventory

- `CustomInventory/init.client.luau` — main script in StarterPlayerScripts
- `CustomInventory/SETTINGS.luau` — child ModuleScript (Rojo folder structure), required via `require(script.SETTINGS)`
- `toolButton` slot template is at `Custom Inventory` GUI root, `Visible = false`; cloned with `Visible = true` for each slot
- Fish lock uses `ReplicatedStorage.FishLockEvent` (RemoteEvent created by `Lock.server.luau`)

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
| Bubble shop | `BubbleShopSever.server.luau` | `BuyBubbleBindable` BindableEvent; validates coins and inventory space |
| Robux shop | `RobuxShopButtons.client.luau` | GamePass buttons: Coin x2 (1293430515), Luck x2 (1289569606), Power x2 (1290056221) |
| Server boost | `ServerBoostClient.client.luau` | 4 tiers; products: 3591613623/3591613620/3591613622/3591613619 |

### Quest System

`QuestSaver` manages quest categories:
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
- **No LocalScripts inside StarterGui**: all client logic lives in StarterPlayerScripts; ScreenGuis contain UI elements only.
