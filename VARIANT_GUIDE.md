# 새 변이(Variant) 추가 가이드

새 변이를 추가할 때 수정해야 할 파일 목록과 수정 내용.

---

## 예시: "Storm" 변이를 새로 추가한다고 가정

---

## 1. `src2/ReplicatedStorage/Modules/FishingServerModule.luau`

변이가 낚이는 로직. 두 곳 수정.

**① 변이 도감 등록 (TRACKED_PREFIXES)**
```lua
local TRACKED_PREFIXES = { "Gold", "Sans", "Frozen", "Festival", "Storm" }  -- Storm 추가
```

**② 변이 적용 로직** — Gold/Sans/Frozen처럼 확률 체크 + fishInfo 업데이트:
```lua
-- Storm variant
local BASE_STORM_CHANCE = 0.005
if math.random() < BASE_STORM_CHANCE then
    fishInfo.fishName = "Storm " .. fishInfo.fishName
    fishInfo.value = math.floor((fishInfo.value or 0) * 2.0)
    fishInfo.isStormVariant = true
end
```

**③ 알림 확률 표시 (Success notification 블록)**
```lua
if fishInfo.isStormVariant then pct = pct * 0.05 end  -- 확률 보정
```

---

## 2. `src2/ServerScriptService/leaderstats/init.server.luau`

FishVariant BoolValues 생성 목록.

```lua
local VARIANT_PREFIXES = { "Gold", "Frozen", "Festival", "Sans", "Storm" }  -- Storm 추가
```

---

## 3. `src2/ServerScriptService/ItemSave/init.server.luau`

변이 prefix 제거 함수.

```lua
local VARIANT_PREFIXES_ORDERED = { "Gold", "Sans", "Frozen", "Festival", "Storm" }  -- Storm 추가
```

Name 변경 감지 블록에서 플래그 추가:
```lua
fishItem.isStormVariant = prefixPart:find("Storm") ~= nil
```

`buildFishItemData` 함수에서:
```lua
local isStormVariant = fishInfo.isStormVariant == true
-- ...
if isStormVariant then adjustedValue = math.floor(adjustedValue * 2.0) end
-- ...
isStormVariant = isStormVariant,
```

`saveCurrentInventory` 함수에서:
```lua
isStormVariant = fishItem.isStormVariant or false,
```

`PlayerAdded` 로드 블록 (hasSavedFlags 분기):
```lua
hasStorm = itemEntry.isStormVariant == true
-- ...
if hasStorm then adjustedValue = math.floor(adjustedValue * 2.0) end
```

---

## 4. `src2/ServerScriptService/SellShopHandler.server.luau`

prefix 제거 함수와 가격 계산.

```lua
local VARIANT_PREFIXES_STRIP = { "Gold", "Sans", "Frozen", "Festival", "Storm" }  -- Storm 추가
```

`calcTrueFishValue` 안에서:
```lua
local hasStorm = prefixPart:find("Storm") ~= nil
-- ...
if hasStorm then adjusted = math.floor(adjusted * 2.0) end
```

---

## 5. `src2/ServerScriptService/GamblerHandler.server.luau`

갬블 재롤 로직.

```lua
local VARIANT_PREFIXES_ALL = { "Gold", "Sans", "Frozen", "Festival", "Storm" }  -- Storm 추가
```

상수:
```lua
local STORM_CHANCE = 0.005
```

`applyMutations` 안에서:
```lua
local willBeStorm = rng:NextNumber() <= STORM_CHANCE
if willBeStorm then prefix = prefix .. "Storm " end
```

`calculateUnifiedPrice` 안에서:
```lua
if willBeStorm then newMutMult = newMutMult * 2.0 end
```

`applyMutations` 반환값 추가:
```lua
return newName, willBeFrozen, willBeFestival, willBeGold, willBeSans, willBeStorm
```

---

## 6. `src2/ServerScriptService/FishDiscoverReward.server.luau`

도감 보상 지급.

```lua
local VARIANT_PREFIXES = { "Gold", "Frozen", "Festival", "Sans", "Storm" }  -- Storm 추가
```

---

## 7. `src2/StarterPlayer/StarterPlayerScripts/Index.client.luau`

도감 UI.

```lua
local VARIANT_PREFIXES = { "Gold", "Frozen", "Festival", "Sans", "Storm" }  -- Storm 추가
```

```lua
local catAccentColors = {
    -- ...
    Storm = Color3.fromRGB(100, 150, 255),  -- Storm 색 추가
}
```

`setupModelInViewport` 호출부:
```lua
setupModelInViewport(vp, fishModel,
    currentCategory == "Gold" and isDiscovered,
    currentCategory == "Sans" and isDiscovered,
    currentCategory == "Storm" and isDiscovered)  -- Storm 추가
```

`setupModelInViewport` 함수 안:
```lua
elseif isStorm then
    clone.Color = Color3.fromRGB(100, 150, 255)
    clone.Material = Enum.Material.Neon
end
```

카테고리 루프:
```lua
for _, catName in ipairs({ "Normal", "Gold", "Frozen", "Festival", "Sans", "Storm" }) do
```

Studio에서 Categories 프레임 안에 Storm 버튼 Frame 추가 (기존 버튼 복제 후 이름/라벨 변경).

---

## 8. Studio 전용 (Rojo sync 밖)

- **StarterGui.Index.Index.Categories** — Storm 버튼 Frame 추가 (MCP `execute_luau`로 이름 수정)

---

## 체크리스트 요약

| 파일 | 수정 내용 |
|------|----------|
| `FishingServerModule.luau` | TRACKED_PREFIXES, 낚시 확률 로직, 알림 확률 보정 |
| `leaderstats/init.server.luau` | VARIANT_PREFIXES (BoolValue 생성) |
| `ItemSave/init.server.luau` | VARIANT_PREFIXES_ORDERED, buildFishItemData, saveCurrentInventory, PlayerAdded 로드, Name변경 감지 |
| `SellShopHandler.server.luau` | VARIANT_PREFIXES_STRIP, calcTrueFishValue 가격 계산 |
| `GamblerHandler.server.luau` | VARIANT_PREFIXES_ALL, 확률 상수, applyMutations, calculateUnifiedPrice |
| `FishDiscoverReward.server.luau` | VARIANT_PREFIXES |
| `Index.client.luau` | VARIANT_PREFIXES, catAccentColors, 카테고리 루프, setupModelInViewport |
| Studio Categories Frame | 버튼 추가 (MCP) |

---

## 변이 이름 규칙

- 이름 형식: `"변이1 변이2 베이스이름 [레어리티] - X.Xkg"`
- prefix 순서: Gold → Sans → Frozen/Festival (갬블 기준)
- 새 변이는 맨 앞 또는 Sans 뒤에 추가 권장
- `stripAllVariantPrefixes` 계열 함수는 루프로 순서 무관하게 제거하므로 순서 달라도 파싱은 정상 동작
