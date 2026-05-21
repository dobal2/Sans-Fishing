# Sans Fishing — Project Guide

## 필수 규칙

새 스크립트 파일을 만들 때는 **반드시** `default.project.json`에도 등록해야 한다. 등록하지 않으면 Rojo가 Studio에 싱크하지 않아 스크립트가 동작하지 않는다. 파일 생성과 `default.project.json` 수정은 항상 같이 한다.

## 스크립트 편집 규칙 (필수)

Rojo sync 범위 안의 스크립트를 수정할 때는 **파일시스템(Edit)과 스튜디오(multi_edit) 반드시 동시에** 수정한다. 한쪽만 고치면 다음번 Rojo 싱크나 재시작 때 버전이 어긋난다. 이 실수가 반복된 이력이 있으므로 절대 한쪽만 수정하지 말 것.

- 파일시스템만 수정 → Rojo 싱크 후 스튜디오에 반영되긴 하나, 싱크 전까지 스튜디오가 구버전
- 스튜디오만 수정 → Rojo 싱크 시 파일 버전으로 **덮어씌워져 소실**

**예외**: Studio-only 스크립트 (`RodsGui`가 StarterGui 안에 있던 경우처럼 Rojo sync 범위 밖인 것)는 MCP로만 수정.

## MCP / Studio 편집 주의사항

- **Source gsub 편집 위험**: `execute_luau`로 스크립트 Source를 gsub 패턴으로 수정할 때 패턴이 예상보다 일찍 매칭되면 함수 정의가 통째로 잘릴 수 있음. 복잡한 gsub 대신 Source 전체를 새로 쓰는 방식이 안전함. 편집 후 반드시 핵심 함수명 포함 여부 확인.
- **`require()` 캐시**: `execute_luau`로 ModuleScript Source를 수정해도 이미 `require()`된 모듈은 캐시된 결과를 반환함 — 플레이 테스트 재시작 전까지 미반영. Studio-only 스크립트가 stale 캐시를 물고 있을 경우 해당 스크립트에 직접 fallback 코드를 추가하거나 재시작 안내.
- **Studio-only 스크립트**: `RodsGui`, `Main_ServerTime` 등 Rojo sync 범위 밖 스크립트는 파일시스템에 없으므로 MCP로만 편집 가능. 변경사항이 Rojo 싱크에 의해 덮어써지지 않음.

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
    SellShopHandler.server.luau          # Sell shop handler (uses SkillHelper for SellBonus)
    UpgradeShopHandler.server.luau       # Upgrade shop handler
    PapHandler.server.luau               # Pap NPC: fires OpenRobuxShop → NpcDialogClient shows dialog → OpenRobuxShopLocal opens shop
    ChairHandler.server.luau             # Chair sit handler
    LikeCounterHandler.server.luau       # Like counter
    FishDiscoverReward.server.luau       # Fish discovery reward
    BubbleProximityHandler.server.luau   # Bubble proximity prompt
    FishTrapProximityHandler.server.luau # Fish trap proximity prompt
    SkillServer.server.luau              # Skill tree purchase handler (SkillBuyEvent, GetSkillData remotes)
    SkillHelper.luau                     # ModuleScript: GetLuckBonus, GetSellBonus, GetEffect, GetExtraInventory
    Commands.server.luau                 # Admin chat commands (speed, kick, setcoins, announce, DevRod, SlapBattle, skillreset, tutorialreset)
    DeleteFishTrap.server.luau           # Removes a placed fish trap from workspace + data
    HotBarLayoutServer.server.luau       # Saves/loads hotbar slot layout per player (SaveHotBarLayout, GetHotBarLayout remotes)
    QuestSaver/                          # (see above)

  StarterPlayer/
    StarterPlayerScripts/
      # --- Fishing ---
      FishingClientStarter.client.luau        # Attaches FishingClientModule to rod tools
      AutoFishing.client.luau                 # Auto fishing controller; monitors IsFishing attribute; re-casts after AUTO_CAST_COOLDOWN (1.1s) on failure
      RecoverGui.client.luau                  # Recover GUI: shown on fishing failure; Keep button buys RECOVER_PRODUCT_ID to reclaim lost fish

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
      Main_WeatherTimer.client.luau           # Next weather countdown timer label
      Main_StatLabels.client.luau             # LuckLabel (rod+skill+friends luck %) and CoinLabel (sell bonus %) — updates every 5s
      Main_UpdateLog.client.luau              # Shows update log once per session (scale tween, close button, attribute flag)
      Main_SkillTree.client.luau              # Skill Tree topbar button toggle
      Main_ServerTime.client.luau             # Server uptime display
      Main_Invite.client.luau                 # Social invite button (SocialService:PromptGameInvite)

      # --- Shop / Robux ---
      ShopGui.client.luau                     # Rod shop GUI (arrow buttons, item display)
      RodsGui.client.luau                     # Rod stats display GUI (Luck/Power/Weight labels per rod)
      RobuxShop.client.luau                   # Robux shop: listens to OpenRobuxShopLocal (BindableEvent) to open/close
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

      # --- Skill Tree ---
      SkillTreeClient.client.luau             # Skill tree UI: node state refresh, buy tween, GUI hide/restore
      SkillTreeHover.client.luau              # Skill node hover scale tween

      # --- Index (fish catalog) ---
      Index.client.luau                       # Fish catalog UI

      # --- Quest ---
      QuestGui.client.luau                    # Quest list UI (reads leaderstats.Quests.ActiveQuests)

      # --- Leaderboard ---
      LeaderboardYourStats.client.luau        # Shows the local player's own rank/stats on leaderboard GUI

      # --- Notice system ---
      Notice_NoticeText.client.luau           # Routes ShowNoticeEvent / NoticeEventForClient to NoticeFrame
      Notice_AnnounceText.client.luau         # Routes AnnounceRemote global announcements to NoticeFrame
      Notice_DiscoverText.client.luau         # Routes DiscoverNoticeEvent (new fish discovery) to NoticeFrame
      Notice_TutorialText_Tutorial.client.luau # Tutorial step flow (equip → cast → sell → upgrade → skill tree)

      # --- Topbar / UI ---
      TopbarController.client.luau            # TopbarPlus icon setup
      UIStrokeScale.client.luau               # Scales UIStroke thickness with screen size
      NpcDialogClient.client.luau             # NPC dialog system
      NpcHighLightAndDistance.client.luau     # NPC highlight and distance label (Seller, Gambler, UpdateShop, Pap, VoidQuestGiver)
      ScreenGui_Frame_LocalScript.client.luau # Misc ScreenGui frame script (Success sound on event)

      # --- World / Environment ---
      ClientWeatherHandler.client.luau        # Weather effects: Rain module, lighting tweens, fireworks
      BigFishHoldAnimation.client.luau        # Plays hold-big-fish animation when carrying a heavy fish
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
      NameTag.server.luau            # Clones NameTag BillboardGui from ReplicatedStorage into character Head

  ReplicatedStorage/
    Modules/
      FishingServerModule.luau   # Core fishing server: cast, rope, fish selection, minigame, inventory
      FishingClientModule.luau   # Core fishing client: slider minigame, animations, GUI
      FishDataModule.luau        # Fish data tables, random fish selection, ice/festival effects
      FishDifficultyModule.luau  # Difficulty scaling per rarity (hit size, speed, drain); weight penalty normalized to fish's own min-max range: at max weight drain ×1.8, hit zone ×0.80
      FishingConfigModule.luau   # Per-rod config (RodPower, DifficultyMod)
      FishIceEffectModule.luau   # Applies/removes ice block overlay on frozen fish models
      WeatherSystemModule.luau   # Server-authoritative weather state machine
      RodDataModule.luau         # Rod definitions (price, storageName, optional displayName); includes FishingRod (free starter); "RealisticRod" key has storageName="BlockyRod" displayName="BlockyRod"
      BoatDataModule.luau        # Boat definitions (price, storageName)
      DialogModule.luau          # Reusable NPC dialog module (prompt/response flow)
      Rain.luau                  # Third-party rain particle module (excluded from refactoring)
    TopbarPlus/                  # Third-party topbar icon library (excluded from refactoring)
    DistanceFade.luau            # Third-party distance-fade effect module
```

---

## Remote Structure

All Remotes live under `ReplicatedStorage.Remotes.[Category]`:

| Category | Remotes |
|---|---|
| `Fishing` | ShowBeamEvent, BaitLandedEvent, BaitSplashEvent, RandomFishResult, FishDiscoverReward, TriggerRandomFish (Bindable), SetFavoriteRemote, RecoverEvent |
| `Shop` | BuyFishingRod, OpenShop, OpenBoatShop, OpenRobuxShop, BuyBoat, SpawnBoat, ShopSellerDialog, OpenGearShop, codeEvent, OpenShopLocal (Bindable), OpenRobuxShopLocal (Bindable), BuyFishTrapBindable (Bindable), BuyBubbleBindable (Bindable) |
| `Sell` | SellChoiceEvent, SellGuiEvent, SetPromptEvent, SoldNotification, TalkEvent, GambleChoiceEvent, GambleGuiEvent, GambleNotification |
| `Notice` | ShowNoticeEvent, FishNoticeEvent, NoticeEventForClient (Bindable), TutorialEvent (Bindable), DiscoverNoticeEvent |
| `Quest` | QuestGuiEvent, QuestReceiveEvent, QuestCompleteEvent, QuestNotification, QuestChoiceEvent, Quest Giver |
| `Weather` | WeatherChangedEvent, FireworkEffectEvent |
| `Misc` | EscapeTheWorld, DonationRefresh, ClaimDailyReward, CheckDailyReward, SaveHotBarLayout, GetHotBarLayout (RemoteFunction), GetServerAge (RemoteFunction) |

**RS root (created at runtime by server scripts, not in Remotes folder)**:
- `FishLockEvent` — fish lock toggle (Lock.server.luau)
- `SetPendingRecover` (BindableEvent) — fired by FishingServerModule on fail; ProcessReceipt listens and stores pending recover data in server-side `pendingRecoverData[userId]` table (prevents client Attribute exploit)
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
- `SkillTree` — skill tree UI (BackGround > Viewport > Canvas contains `SkillNode_SkillName_Stage` ImageButtons)

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
- After landing: waits 2–3 seconds, selects fish via `FishDataModule`, fires fish data to client, starts minigame session. `gameStartTime` is set just before `FireClient` (not at bait landing).
- On `progress_success`: validates timing and inventory, awards fish tool to backpack.
- On fail: fires `SetPendingRecover` BindableEvent with fish info → ProcessReceipt stores in `pendingRecoverData[userId]`; fires `RecoverEvent` to client to show RecoverGui.
- Security checks: session ID validation, minimum game time, inventory limit, player ownership. `typeof(targetPos) ~= "Vector3"` guard on cast.
- Retry gamepass (`RETRY_GAMEPASS_ID = 1290056221`): grants one retry per catch attempt.
- `_resolveFishing` grabs `local fishInfo = self.fishInfo` then immediately sets `self.fishInfo = nil`; all downstream code uses the local variable.
- `getScaleRatio` guards against division by zero: `if range <= 0 then return 1 end`.
- Notice billboard (`FishingNoticeSurface`): studs-based Size (not pixel), `AlwaysOnTop = false` so it scales naturally with camera distance.

**Client** (`FishingClientModule.luau`):
- Slider minigame: a tween-animated slider must land inside a hit zone.
- Hit zones: normal zone (+15 progress) and strong zone (+20 progress); miss subtracts 15.
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
| `leaderstats/DataManager` | `"PlayerData7"` | Coins, Rods, Fish catalog, Boats, FishTraps, Playtime, Donations, SkillPoints, Skills |
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
| Rod shop | `Shop.server.luau` | `BuyFishingRod` RemoteEvent; validates coin balance and gamepass for RobuxRod; immediately calls `datamanager:UpdateData` for CurrentRod and Rods after purchase |
| Fish trap shop | `FishTrapShopSever.server.luau` | `BuyFishTrapBindable` BindableEvent; validates coins or `ROBUX_FISHTRAP_GAMEPASS_ID = 1423175879` |
| Bubble shop | `BubbleShopSever.server.luau` | `BuyBubbleBindable` BindableEvent; validates coins and inventory space |
| Robux shop | `RobuxShopButtons.client.luau` | GamePass buttons: Coin x2 (1293430515), Luck x2 (1289569606), Power x2 (1290056221) |
| Server boost | `ServerBoostClient.client.luau` | 4 tiers; products: 3591613623/3591613620/3591613622/3591613619 |

### Quest System

`QuestSaver` manages quest categories:
- **Normal quests**: catch N of a specific fish; progress updated by `FishingServerModule` on catch.
- **Daily playtime quest**: earn coins based on minutes played that day; tracked via `Playtime` value.
- **Void quest**: one-time challenge to unlock the VoidRod.

### Skill Tree System

Skills are split into two currencies: **Coins** and **FishingPoints** (earned 1 per successful catch, stored as `SkillPoints` IntValue on player).

**Server** (`SkillServer.server.luau`):
- Creates `SkillBuyEvent` (RemoteEvent) and `GetSkillData` (RemoteFunction) at RS root.
- Validates purchase: Root must be unlocked first; FriendBonus requires LuckUp Lv2; must buy stages sequentially (no skipping); currency balance check.
- Per-skill cooldown (`skillBuyCooldowns[player][skillName]`) prevents concurrent purchase exploits making balance negative.
- On success: deducts currency, increments `player.Skills.[SkillName]` IntValue, fires `"success"` to client.

**Shared helper** (`SkillHelper.luau` — ModuleScript, required by FishDataModule and SellShopHandler):
- `GetLuckBonus(player)` — returns total LuckUp effect value
- `GetEffect(player, skillName)` — returns current effect value for any skill
- `GetSellBonus(player)` — returns SellBonus effect value
- `GetExtraInventory(player)` — returns InvenUp extra slot count

**Skills table**:
| Skill | Currency | Max Lv | Costs | Effect | Requires |
|---|---|---|---|---|---|
| Root | Coins | 1 | 1,000 | unlocks all other skills | — |
| AutoFish | Coins | 1 | 10,000 | shows AutoFish button | Root |
| LuckUp | Coins | 7 | 2K/10K/100K/500K/2.5M/7.5M/22.5M | +10/30/60/100/150/200/250% luck | Root |
| SellBonus | Coins | 6 | 10K/80K/500K/2.5M/5M/15M | +10/20/30/40/50/65% sell value | Root |
| FriendBonus | Coins | 3 | 10K/50K/200K | +15/30/50% luck per online friend | LuckUp Lv2 |
| QuickBite | Coins | 3 | 50K/300K/1.5M | fish bite wait -0.5/1.5/2.5s | AutoFish |
| AutoUp (Rapid Auto) | Coins | 3 | 100K/1M/5M | auto click cooldown -0.1/0.4/0.8s | AutoFish |
| PointBoost | Coins | 3 | 5M/20M/100M | +1/2/3 FishingPoints per catch | — |
| HitZoneUp | FishingPoints | 3 | 20/50/100 | hit zone size +6/10/15% | PowerUp Lv1 |
| WeightUp | FishingPoints | 4 | 40/160/400/1000 | heavy fish chance +4/10/18/28% | FishingPoint Lv1 |
| PowerUp | FishingPoints | 3 | 40/160/400 | rod power +5/10/20% | FishingPoint Lv1 |

**Client** (`SkillTreeClient.client.luau`):
- Node naming: `SkillNode_SkillName_Stage` (e.g. `SkillNode_LuckUp_2`) inside `SkillTree > BackGround > Viewport > Canvas`
- Purchased node image: `rbxassetid://125922144537144`; locked (not yet reachable) node image: `rbxassetid://102739874658337` + all children `Visible = false`
- On open: hides all other ScreenGuis; restores on close; blocks other GUIs from enabling while open
- On buy success: plays `RobuxBuySound`, scale tween 1→1.3→1, refreshUI

**Admin command**: `:skillreset [player]` — zeros all Skills IntValues and SkillPoints, clears ProfileService data.

### Admin System

`Commands.server.luau` uses a rank table (`Developer`, `Moderator`) checked by username. Commands are prefixed with `:`. Cross-server messaging uses `MessagingService` for `GlobalAnnouncement`, `GlobalCoinGive`, `GlobalSlapBattleGive`, `GlobalDevRodGive`.

---

## Coding Conventions

- **Service declarations**: all `game:GetService()` calls at the top of the file; never inline.
- **Scheduler**: always use `task.wait()`, `task.spawn()`, `task.delay()`, `task.cancel()` — never bare `wait()` or `spawn()`.
- **Comments**: English only; keep only comments that explain non-obvious logic; remove noise comments.
- **Early returns**: validate and return early rather than deep nesting.
- **Constants**: magic numbers go in named constants at the top of the file (e.g. `RETRY_GAMEPASS_ID`, `WEATHER_CYCLE_TIME`).
- **Security**: all purchases and fishing events are server-validated; client input is never trusted for economy changes. Recover pending data is stored in a server-side table (not Player Attributes) to prevent client exploitation.
- **FriendRod equip**: the FriendRod branch in `Shop.server.luau` must `return` after equipping — it does not go through normal rod logic below.
- **OOP pattern**: `FishingServerModule` and `FishingClientModule` use `setmetatable({}, Class)` instances with `__index`, one instance per tool.
- **ProfileService**: data is accessed via `DataManager:GetData(player)` and modified via `DataManager:UpdateData(player, key, value)`. Economy-changing purchases (rods, skills) must call `UpdateData` immediately — not just at `PlayerRemoving`.
- **File naming**: server scripts end in `.server.luau`, client scripts in `.client.luau`, module scripts in `.luau`.
- **No LocalScripts inside StarterGui**: all client logic lives in StarterPlayerScripts; ScreenGuis contain UI elements only.
- **Rod storageName vs key**: RodData table keys are the canonical names (e.g. `"RealisticRod"`), but `storageName` is the actual tool/BoolValue name (e.g. `"BlockyRod"`). Always use `rodData.storageName` for inventory/backpack lookups, never the key. `ShopGui.hasRod()` already resolves storageName.
- **Rod display name**: use `rodData.displayName or rodName` when showing the rod name in UI.