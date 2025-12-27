# EasyLife WoW Addon - AI Coding Guidelines

## Architecture Overview

EasyLife is a modular World of Warcraft Classic Era (1.15.x) addon for boosting/dungeon carry helpers. Core-plus-module design with a single `EasyLifeDB` SavedVariables table.

**Load order**: `Core.lua` → `Locales.lua` → `Config.lua` → `Minimap.lua` → Module files (defined in `EasyLife.toc`)

## Module Anatomy (Required Pattern)

Every module follows this exact structure:

```lua
local MyModule = {}

local DEFAULTS = { enabled = true, x = 0, y = 0 }

local function ensureDB()
  EasyLifeDB = EasyLifeDB or {}
  EasyLifeDB.myModule = EasyLifeDB.myModule or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.myModule[k] == nil then EasyLifeDB.myModule[k] = v end
  end
  if EasyLifeDB.myModule._firstRunShown == nil then EasyLifeDB.myModule._firstRunShown = false end
end

local function getDB() ensureDB() return EasyLifeDB.myModule end

-- REQUIRED: Config UI entry point
function MyModule:BuildConfigUI(parent)
  local db = getDB()
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("MyModule", "MY_TITLE", "MY_FIRST_RUN_DETAILED", db)
  end
  -- Build UI controls as children of parent
end

-- REQUIRED: Called when module is enabled/disabled from Config
function MyModule:UpdateState()
  local db = getDB()
  if db.enabled then self:Enable() else self:Disable() end
end

-- OPTIONAL: Hide floating UI when module disabled
function MyModule:CleanupUI() end

EasyLife:RegisterModule("MyModule", MyModule)  -- MUST be at file end
```

## Key Integration Points

| Method | When Called | Purpose |
|--------|-------------|---------|
| `BuildConfigUI(parent)` | User opens module config | Create settings controls |
| `UpdateState()` | Enable/disable toggle in Module Manager | Start/stop event listeners |
| `CleanupUI()` | Module disabled or switching modules | Hide floating frames |

## Localization (Mandatory)

Add ALL user-facing strings to both `L_enUS` and `L_trTR` tables in [Locales.lua](Locales.lua):

```lua
local function L(key) return EasyLife:L(key) end  -- Local shorthand
```

Required keys per module: `*_TITLE`, `*_DESC`, `*_FIRST_RUN_DETAILED`

## Adding a New Module (Checklist)

1. Create `NewModule.lua` with DEFAULTS, ensureDB, getDB, BuildConfigUI, UpdateState
2. Add to `EasyLife.toc` after `Minimap.lua`
3. Add to `MODULE_LIST` in [Config.lua](Config.lua#L8) with name/key/descKey/firstRunKey
4. Add to `MODULE_DB_KEYS` map in [Config.lua](Config.lua#L30) (module name → db key)
5. Add localization keys to both language tables in Locales.lua
6. Register at file end: `EasyLife:RegisterModule("Name", Module)`

## WoW API Notes

- Interface: `11508` (Classic Era Anniversary 1.15.x)
- Timing: `C_Timer.After()` / `C_Timer.NewTicker()` (never `OnUpdate` unless needed)
- Frames: `CreateFrame("Frame", nil, parent, "BackdropTemplate")` for bordered frames
- Chat output: `EasyLife:Print(msg, "ModuleName")` creates clickable [EasyLife] link

## Module Database Inconsistency (Historical)

Some modules use different DB patterns due to evolution:
- `Advertiser`, `Boostilator`, `VendorTracker`: Direct `EasyLifeDB.moduleName`
- `AggroAlert`, `IceBlockHelper`: Via `EasyLife:GetDB().moduleName`

Check `MODULE_USES_GLOBAL_DB` in Config.lua when syncing enabled states.
