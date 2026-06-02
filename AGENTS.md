# Sans Fishing — Project Guide (Codex)

> Codex용 프로젝트 가이드. Claude용 CLAUDE.md를 기반으로 작성됨.

## 필수 규칙

새 스크립트 파일을 만들 때는 **반드시** `default.project.json`에도 등록해야 한다. 등록하지 않으면 Rojo가 Studio에 싱크하지 않아 스크립트가 동작하지 않는다. 파일 생성과 `default.project.json` 수정은 항상 같이 한다.

### 낚싯대 luck 수치 동기화 규칙

**`RodDataModule.luau`의 `luck` 표시값과 `FishDataModule.luau`의 `ROD_LUCK_BONUS` 테이블은 항상 같이 수정해야 한다.**

- 공식: `luck 표시 숫자 = ROD_LUCK_BONUS 값 × 100`
- 예) `ROD_LUCK_BONUS.VoidRod = 10.00` → `luck = "+1000%"`
- 한쪽만 고치면 상점 표시와 실제 확률이 달라진다. 두 파일을 반드시 동시에 수정할 것.

## 스크립트 편집 규칙 (필수)

Rojo sync 범위 안의 스크립트를 수정할 때는 **파일시스템(Edit)과 스튜디오(multi_edit) 반드시 동시에** 수정한다. 한쪽만 고치면 다음번 Rojo 싱크나 재시작 때 버전이 어긋난다.

- 파일시스템만 수정 → Rojo 싱크 후 스튜디오에 반영되긴 하나, 싱크 전까지 스튜디오가 구버전
- 스튜디오만 수정 → Rojo 싱크 시 파일 버전으로 **덮어씌워져 소실**

**예외**: Studio-only 스크립트 (Rojo sync 범위 밖인 것)는 Studio 직접 수정만 가능.

## MCP / Studio 편집 주의사항

- **Source gsub 편집 위험**: `execute_luau`로 스크립트 Source를 gsub 패턴으로 수정할 때 패턴이 예상보다 일찍 매칭되면 함수 정의가 통째로 잘릴 수 있음. 복잡한 gsub 대신 Source 전체를 새로 쓰는 방식이 안전함. 편집 후 반드시 핵심 함수명 포함 여부 확인.
- **`require()` 캐시**: `execute_luau`로 ModuleScript Source를 수정해도 이미 `require()`된 모듈은 캐시된 결과를 반환함 — 플레이 테스트 재시작 전까지 미반영.
- **Studio-only 스크립트**: `RodsGui`, `Main_ServerTime` 등 Rojo sync 범위 밖 스크립트는 파일시스템에 없으므로 Studio로만 편집 가능.

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
    PapHandler.server.luau               # Pap NPC handler
    ChairHandler.server.luau             # Chair sit handler
    LikeCounterHandler.server.luau       # Like counter
    FishDiscoverReward.server.luau       # Fish discovery reward
    BubbleProximityHandler.server.luau   # Bubble proximity prompt
    FishTrapProximityHandler.server.luau # Fish trap proximity prompt
    SkillServer.server.luau              # Skill tree purchase handler (SkillBuyEvent, GetSkillData remotes)
    SkillHelper.luau                     # ModuleScript: GetLuckBonus, GetSellBonus, GetEffect, GetExtraInventory
    Commands.server.luau                 # Admin chat commands
    DeleteFishTrap.server.luau           # Removes a placed fish trap from workspace + data
    HotBarLayoutServer.server.luau       # Saves/loads hotbar slot layout per player

  StarterPlayer/
    StarterPlayerScripts/
      FishingClientStarter.client.luau
      AutoFishing.client.luau
      RecoverGui.client.luau
      Main.client.luau
      Main_AutoButton_AutoButtonController.client.luau
      Main_DeviceDetect.client.luau
      Main_Fishing_Fishing_Teleport.client.luau
      Main_Sell_Sell_Teleport.client.luau
      Main_Upgrade_Upgrade_Teleport.client.luau
      Main_FreeReward_FreeReward.client.luau
      Main_FreeRewardShop.client.luau
      Main_NoticeFrame_NoticeSystem.client.luau
      Main_RandomFishClient.client.luau
      Main_FriendBonus.client.luau
      Main_Money.client.luau
      Main_WeatherInfo.client.luau
      Main_WeatherTimer.client.luau
      Main_StatLabels.client.luau
      Main_UpdateLog.client.luau
      Main_SkillTree.client.luau
      Main_ServerTime.client.luau
      Main_Invite.client.luau
      ShopGui.client.luau
      RodsGui.client.luau
      RobuxShop.client.luau
      RobuxShopButtons.client.luau
      ServerBoostClient.client.luau
      SellOptions.client.luau
      SellOptions_Sell.client.luau
      SellOptions_SellHandler.client.luau
      SellOptions_SellOptions.client.luau
      GambleOptions.client.luau
      GambleOptions_Sell.client.luau
      QuestOptions.client.luau
      QuestOptions_Sell.client.luau
      OptionButtonTween.client.luau
      CustomInventory/
        init.client.luau
        SETTINGS.luau
      SkillTreeClient.client.luau
      SkillTreeHover.client.luau
      Index.client.luau
      QuestGui.client.luau
      LeaderboardYourStats.client.luau
      Notice_NoticeText.client.luau
      Notice_AnnounceText.client.luau
      Notice_DiscoverText.client.luau
      Notice_TutorialText_Tutorial.client.luau
      TopbarController.client.luau
      UIStrokeScale.client.luau
      NpcDialogClient.client.luau
      NpcHighLightAndDistance.client.luau
      ScreenGui_Frame_LocalScript.client.luau
      ClientWeatherHandler.client.luau
      BigFishHoldAnimation.client.luau
      HideMyFishGive.client.luau
      FishTrapClientProximityManager.client.luau
      FishTrapBeam.client.luau
      DistanceFade.client.luau
      DoNotFall.client.luau
      DontReset.client.luau
      TipChat.client.luau
      UnderWater.client.luau
      SnowIslandLightEffect.client.luau
      ErrorRoom.client.luau
      WindController/

    StarterCharacterScripts/
      HeadFollow.client.luau
      PreLoadAnimatins.client.luau
      PromptFavorite.client.luau
      NameTag.server.luau

  ReplicatedStorage/
    Modules/
      FishingServerModule.luau
      FishingClientModule.luau
      FishDataModule.luau
      FishDifficultyModule.luau
      FishingConfigModule.luau
      FishIceEffectModule.luau
      WeatherSystemModule.luau
      RodDataModule.luau
      BoatDataModule.luau
      DialogModule.luau
      Rain.luau
    TopbarPlus/
    DistanceFade.luau
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

**RS root (created at runtime)**:
- `FishLockEvent` — fish lock toggle
- `SetPendingRecover` (BindableEvent) — recover flow
- `FishReceiveNoticeEvent` — fish give notification
- `CodeResponseEvent` — code redeem result
- `AnnounceRemote` — global announcement
- `ServerBoostRemote` — server boost purchase
- `GetBoostState` (RemoteFunction) — query current boost state
- `GetFriendsCountRemote` (RemoteFunction) — friend count query
- `VoidQuestEvents/` folder — VoidQuestGuiEvent, VoidQuestChoiceEvent
- `VoidRodEvents/` folder — OpenVoidShop, VoidShopNotice
- `RandomFishResult` — random fish gacha result

---

## Studio GUI Structure

**StarterGui ScreenGuis** (UI elements only, no LocalScripts inside):
- `Main` — main HUD
- `SellOptions` — sell choice popup
- `GambleOptions` — gamble choice popup
- `QuestOptions` — quest choice popup
- `ShopGui` — rod shop UI
- `RobuxShop` — robux shop
- `Custom Inventory` — hotbar + inventory
- `ScreenGui` — misc UI
- `Index` — fish catalog UI
- `QuestGui` — quest list
- `DailyRewards` — daily reward UI (disabled)
- `RandomFish` — random fish reveal UI
- `SkillTree` — skill tree UI

---

## Bobber System

### Data & Config
- **`ReplicatedStorage.Modules.BobberDataModule`** — all bobber definitions (`BobberData.Bobbers`) and shop rotation list (`BobberData.ShopList`). `BobberData.GetEffects(name)` returns a full effect table with defaults filled in.
- Bobber effects: `luckBonus`, `sellBonus`, `heavyBonus`, `rodPowerBonus`, `frozenChance`, `sansChance`, `festivalBonus`, `stormLuckBonus`, `doubleCatchChance`

### Studio Assets (NOT in Rojo sync)
- **`ReplicatedStorage.Bobbers`** — folder containing one `Part` per bobber
- **`ReplicatedStorage.Particle.Sans`** — folder with 3 `ParticleEmitter` children

### Workspace
- **`workspace.BobberShop`** — shop model with `gui`, `BobberPos1/2/3`, `BobberPos4`

### Server
- **`ServerScriptService.BobberShopServer`** — rotating bobber shop (600s restock, MessagingService sync)
- Creates remotes at RS root: `EquipBobberRemote`, `BuyBobberRemote`, `OpenBobberShopRemote`
- Robux Bobber gamepass: `ROBUX_BOBBER_GAMEPASS_ID = 1853589181`

### Leaderstats
- `player.leaderstats.EquippedBobber` (StringValue)
- `player.leaderstats.OwnedBobbers` (Folder) — one `BoolValue` per owned bobber
- Default: `"Basic Bobber"`

---

## Major Systems

### Fishing

**Server** (`FishingServerModule.luau`):
- `FishingServerStarter` attaches one `FishingServer` instance per rod tool.
- On `CastRod` fire: creates bait `Part` in workspace, sets up `Beam` fishing line.
- Bait landing: Heartbeat loop detects `bait.Position.Y <= WATER_SURFACE_Y (-3.4)`.
- After landing: waits 2–3 seconds, selects fish via `FishDataModule`, starts minigame.
- On `progress_success`: validates timing and inventory, awards fish tool.
- On fail: fires `SetPendingRecover` BindableEvent → ProcessReceipt stores recover data.
- Security: session ID validation, minimum game time, inventory limit, `typeof(targetPos) ~= "Vector3"` guard.

**Client** (`FishingClientModule.luau`):
- Slider minigame: normal zone (+15 progress), strong zone (+20 progress), miss (-15).
- Starts at 30% progress. Passive drain: 4/s. Fail at 0.
- Animation IDs: Fishing=136011514785364, Finish=85733537741100, Waiting=79818740579248, Holding=71325506664100, FishBaitEat=110856542062910, Reeling=113396780604450, HoldBigFish=131373652396216.

### Notice System

All notices route through `Main_NoticeFrame_NoticeSystem.client.luau` → `Main.NoticeFrame`.
**Do not add LocalScripts inside StarterGui ScreenGuis for notices.**

### Fish Data

`FishDataModule.luau` — fish definitions organized by rarity.
- Weather modifiers: Snow → "Frozen " prefix + 2× value; Firework → "Festival " prefix + 1.5× value; Rain → 1.2× size.
- Fish tool name format: `"FishName [Rarity] - X.Xkg"`.

### Data Storage (ProfileService)

| DataManager | Store key | Data |
|---|---|---|
| `leaderstats/DataManager` | `"PlayerData7"` | Coins, Rods, Fish catalog, Boats, FishTraps, Playtime, Donations, SkillPoints, Skills |
| `ItemSave/DataManager` | `"PlayerItems3"` | Fish inventory (tool name, value, weight, rarity, lock state) |
| `FishTrapManager/DataManager` | `"FishTrapData2"` | Trap position, stored fish list |
| `QuestSaver/DataManager` | `"QuestData4"` | Active quests, completed quests, daily playtime quest |

### Weather System

Types: Clear, Rain, Snow, Firework.
- Cycle: 600s total, 300s active, 300s cooldown.
- Firework only between 18:00 and 06:00 game time.

### Skill Tree System

Skills split into **Coins** and **FishingPoints** (1 per catch, stored as `SkillPoints` IntValue).

| Skill | Currency | Max Lv | Costs | Effect | Requires |
|---|---|---|---|---|---|
| Root | Coins | 1 | 1,000 | unlocks all | — |
| AutoFish | Coins | 1 | 10,000 | auto button | Root |
| LuckUp | Coins | 7 | 2K/10K/100K/500K/2.5M/7.5M/22.5M | +10~250% luck | Root |
| SellBonus | Coins | 6 | 10K/80K/500K/2.5M/5M/15M | +10~65% sell | Root |
| FriendBonus | Coins | 3 | 10K/50K/200K | +15/30/50% luck per friend | LuckUp Lv2 |
| QuickBite | Coins | 3 | 50K/300K/1.5M | bite wait -0.5/1.5/2.5s | AutoFish |
| AutoUp | Coins | 3 | 100K/1M/5M | auto cooldown -0.1/0.4/0.8s | AutoFish |
| PointBoost | Coins | 3 | 5M/20M/100M | +1/2/3 FP per catch | — |
| HitZoneUp | FishingPoints | 3 | 20/50/100 | hit zone +6/10/15% | PowerUp Lv1 |
| WeightUp | FishingPoints | 4 | 40/160/400/1000 | heavy chance +4/10/18/28% | FishingPoint Lv1 |
| PowerUp | FishingPoints | 3 | 40/160/400 | rod power +5/10/20% | FishingPoint Lv1 |

---

## Coding Conventions

- **Service declarations**: all `game:GetService()` calls at the top of the file; never inline.
- **Scheduler**: always `task.wait()`, `task.spawn()`, `task.delay()`, `task.cancel()` — never bare `wait()` or `spawn()`.
- **Comments**: English only; only non-obvious logic.
- **Early returns**: validate and return early.
- **Constants**: magic numbers in named constants at top of file.
- **Security**: all purchases and fishing events server-validated; client input never trusted for economy.
- **OOP pattern**: `FishingServerModule` and `FishingClientModule` use `setmetatable({}, Class)` with `__index`.
- **ProfileService**: `DataManager:GetData(player)` / `DataManager:UpdateData(player, key, value)`. Economy purchases must call `UpdateData` immediately.
- **File naming**: `.server.luau` / `.client.luau` / `.luau`.
- **No LocalScripts inside StarterGui**.
- **Rod storageName vs key**: always use `rodData.storageName` for inventory/backpack lookups, never the table key.
- **Rod display name**: use `rodData.displayName or rodName` in UI.

---

## Workflow Notes (Important)

- **파일 수정 + Studio 주입 항상 쌍으로**: 파일시스템 수정 후 Studio에도 반영해야 함 (Rojo 싱크 타이밍 문제).
- **ReplicatedFirst는 Rojo 밖**: `ReplicatedFirst.LocalScript` (로딩 스크린)는 Studio 직접 수정만 가능.
- **UI 구조 확인**: `StarterGui` 기준 — `PlayerGui`는 런타임에만 존재.
- **코드 수정 전 게임 종료 필수**: 플레이 중 수정 시 변경사항 충돌.
- **tool.Activated:Fire() 불가**: `RBXScriptSignal`은 `:Fire()` 없음. 오토 캐스팅은 BindableEvent 사용.
- **Font 주의**: `Enum.Font.ComicNeueAngular` 없음. TextLabel은 `Font.new("rbxasset://fonts/families/ComicNeueAngular.json", ...)`, ChatMakeSystemMessage 등은 `Enum.Font.Cartoon`.
