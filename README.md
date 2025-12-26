# EasyLife - WoW Classic Era Addon Suite

![Interface](https://img.shields.io/badge/Interface-11508-blue)
![Version](https://img.shields.io/badge/Version-1.2.0-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

A modular helper addon suite for World of Warcraft Classic Era Anniversary (1.15.x).

## Features

| Module | Description |
|--------|-------------|
| **Advertiser** | Auto-invite players by keywords, scheduled channel ads, auto-reply system |
| **Boostilator** | Track boosting clients, runs completed, and payments with auto-detection |
| **Vendor Tracker** | Shows total vendor value of looted items in real-time |
| **Ice Block Helper** | For Mages: Shows optimal moment to cancel Ice Block between mob swings |
| **Aggro Alert** | Big on-screen warning when you have aggro + threat warnings |
| **Range Indicator** | Shows distance to closest mob and target |
| **CastBar Aura** | Shows incoming spell casts targeting you (like DBM alerts) |

## Installation

### Manual Installation
1. Download the latest release
2. Extract to `World of Warcraft/_classic_era_/Interface/AddOns/`
3. You should have these folders:
   - `EasyLife/` (core - required)
   - `EasyLife_Advertiser/` (optional)
   - `EasyLife_AggroAlert/` (optional)
   - `EasyLife_RangeIndicator/` (optional)
   - etc.

### Enable Modules
1. At character select, click "AddOns"
2. Enable `EasyLife` (core)
3. Enable any `EasyLife_*` modules you want

## Usage

- **Open Config**: `/easylife` or `/el`
- **Minimap Button**: Left-click or right-click for module menu

Each module shows a **first-run popup** with detailed instructions when opened for the first time.

## Clean Install / Reset

To reset a module's settings, delete its saved variables:
```
WTF/Account/<ACCOUNT>/SavedVariables/EasyLife.lua
```

Or delete specific module DBs (like `EasyLife_RangeIndicatorDB`) from that file.

## Project Structure

```
EasyLife/                    # Core addon (required)
├── Core.lua                 # Module registry, global table
├── Locales.lua              # English & Turkish translations
├── Config.lua               # Main config window
├── Minimap.lua              # Minimap button
├── Advertiser.lua           # Bundled module
├── Boostilator.lua          # Bundled module
├── VendorTracker.lua        # Bundled module
├── IceBlockHelper.lua       # Bundled module
├── AggroAlert.lua           # Bundled module
└── EasyLife.toc

EasyLife_*/                  # Satellite addons (optional)
├── EasyLife_*.toc           # Stub that loads parent module
└── *.lua                    # Module-specific code (if standalone)
```

## For Developers

See [.github/copilot-instructions.md](.github/copilot-instructions.md) for AI coding guidelines and architecture details.

### Adding a New Module

1. Create `NewModule.lua` in `EasyLife/` with DEFAULTS + ensureDB pattern
2. Add to `EasyLife.toc` file list
3. Add localization keys to `Locales.lua` (both L_enUS and L_trTR)
4. Add to `MODULE_LIST` in `Config.lua`
5. Register at file end: `EasyLife:RegisterModule("NewModule", NewModule)`
6. Create `EasyLife_NewModule/` stub addon for independent enable/disable

## License

MIT License - See [LICENSE](LICENSE) for details.

## Support

Found a bug? Have a feature request? Open an issue on GitHub!
