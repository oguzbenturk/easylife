# EasyLife WoW Addon - AI Coding Guidelines

## Architecture Overview

EasyLife is a modular World of Warcraft Classic Era (1.15.x) addon suite with a core-plus-satellite design:

- **Core addon** (`EasyLife/`): Provides global `EasyLife` table, module registry, localization, config UI, and minimap button
- **Satellite addons** (`EasyLife_*/`): Optional modules that depend on Core and register via `EasyLife:RegisterModule()`
- **Bundled modules**: Advertiser, Boostilator, VendorTracker, IceBlockHelper, AggroAlert live inside Core but can be individually enabled via separate `.toc` stub addons

### Module Registration Pattern

All modules must register with Core at file end:
```lua
local MyModule = {}
-- module implementation...
EasyLife:RegisterModule("ModuleName", MyModule)
```

Standalone addons (like RangeIndicator, CastBarAura) conditionally register:
```lua
if EasyLife and EasyLife.RegisterModule then
  EasyLife:RegisterModule(ADDON_NAME, mod)
end
```

## Key Patterns

### Database & Defaults

Each module manages its own SavedVariables with this pattern:
```lua
local DEFAULTS = { enabled = false, x = 0, y = 0 }

local function ensureDB()
  EasyLifeDB.myModule = EasyLifeDB.myModule or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.myModule[k] == nil then
      EasyLifeDB.myModule[k] = v
    end
  end
end
```

### Localization

Use `EasyLife:L(key)` for all user-facing strings. Add new keys to both `L_enUS` and `L_trTR` tables in [Locales.lua](EasyLife/Locales.lua):
```lua
local function L(key) return EasyLife:L(key) end
```

### Config UI

Modules expose settings via `BuildConfigUI(parent)` method. The parent is a content frame inside the main config window:
```lua
function MyModule:BuildConfigUI(parent)
  -- Create controls as children of parent
  local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  -- ...
end
```

Optional cleanup method for floating UI elements:
```lua
function MyModule:CleanupUI()
  -- Hide any floating frames created by this module
end
```

### First-Run Welcome Popup

Modules show a one-time welcome popup when opened for the first time. Use the centralized popup system in Core.lua:

```lua
function MyModule:BuildConfigUI(parent)
  local db = getDB()
  
  -- Show first-run popup if needed (at start of BuildConfigUI)
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("ModuleName", "TITLE_KEY", "DETAILED_CONTENT_KEY", db)
  end
  
  -- ... rest of config UI
end
```

**Required localization keys** (add to both L_enUS and L_trTR in Locales.lua):
- `TITLE_KEY` - Module title (e.g., "AGGRO_TITLE")  
- `DETAILED_CONTENT_KEY` - Multi-line detailed description (e.g., "AGGRO_FIRST_RUN_DETAILED")

The popup includes:
- Scrollable content area for detailed instructions
- "Don't show this again" checkbox (checked by default)
- "Got it!" button to dismiss
- Sets `db._firstRunShown = true` when user clicks with checkbox checked

## File Organization

| Path | Purpose |
|------|---------|
| `Core.lua` | Global `EasyLife` table, module registry, slash commands |
| `Locales.lua` | L_enUS/L_trTR tables, `EasyLife:L()` function |
| `Config.lua` | Main config window, module selection sidebar |
| `Minimap.lua` | Minimap button with dropdown menu |
| `*.lua` | Individual module implementations |
| `EasyLife_*/` | Stub addons that just include parent module via `..\EasyLife\*.lua` |

## WoW API Considerations

- Target Interface: `11508` (Classic Era Anniversary)
- Use `C_Timer.After()` / `C_Timer.NewTicker()` for timing
- Use `BackdropTemplate` mixin for frames with backdrops
- Prefer `CreateFrame("Frame", nil, parent, "BackdropTemplate")` pattern
- Event handling: `frame:RegisterEvent()` + `frame:SetScript("OnEvent", handler)`

## Adding a New Module

1. Create `NewModule.lua` in `EasyLife/` with DEFAULTS, ensureDB, and module table
2. Add to `EasyLife.toc` file list
3. Add localization keys to [Locales.lua](EasyLife/Locales.lua)
4. Add to `MODULE_LIST` in [Config.lua](EasyLife/Config.lua#L9)
5. Register at file end: `EasyLife:RegisterModule("NewModule", NewModule)`
6. Optionally create `EasyLife_NewModule/` stub addon for independent enable/disable