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

> ⚠️ **IMPORTANT**: The addon folder MUST be named `EasyLife` (capital E and L) for WoW to detect it!

### From GitHub (Recommended)
```bash
cd "World of Warcraft/_classic_era_/Interface/AddOns"
git clone https://github.com/oguzbenturk/easylife.git EasyLife
```
> Note: The `EasyLife` at the end renames the folder correctly.

### Manual Download (ZIP)
1. Download ZIP from [Releases](https://github.com/oguzbenturk/easylife/releases) or click "Code" → "Download ZIP"
2. Extract the ZIP file
3. **Rename** the extracted folder from `easylife-main` to `EasyLife`
4. Move the `EasyLife` folder to `World of Warcraft/_classic_era_/Interface/AddOns/`

Your final path should look like:
```
World of Warcraft/_classic_era_/Interface/AddOns/EasyLife/EasyLife.toc
```

### Enable Modules
1. At character select, click "AddOns"
2. Enable `EasyLife` (core - required)
3. Open config with `/el` and enable the modules you want

## Usage

- **Open Config**: `/easylife` or `/el`
- **Minimap Button**: Left-click or right-click for module menu

Each module shows a **first-run popup** with detailed instructions when opened for the first time.

## Project Structure

```
EasyLife/                         <- This folder goes in AddOns/
├── Core.lua                      # Module registry, global table
├── Locales.lua                   # English & Turkish translations
├── Config.lua                    # Main config window
├── Minimap.lua                   # Minimap button
├── Advertiser.lua                # Auto-invite & messaging module
├── Boostilator.lua               # Boost tracking module
├── VendorTracker.lua             # Loot value tracker module
├── IceBlockHelper.lua            # Mage Ice Block helper module
├── AggroAlert.lua                # Aggro warning module
├── EasyLife.toc                  # Addon manifest
├── MessageQueue/                 # Bundled library
├── README.md
└── LICENSE
```

## Clean Install / Reset

To reset all settings:
```
Delete: WTF/Account/<ACCOUNT>/SavedVariables/EasyLife.lua
```

## For Developers

See [.github/copilot-instructions.md](.github/copilot-instructions.md) for AI coding guidelines.

## License

MIT License - See [LICENSE](LICENSE) for details.
