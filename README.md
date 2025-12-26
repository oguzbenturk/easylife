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

### From GitHub
```bash
cd "World of Warcraft/_classic_era_/Interface/AddOns"
git clone https://github.com/oguzbenturk/easylife.git
```

### Manual Download
1. Download and extract the ZIP
2. Copy ALL folders to `World of Warcraft/_classic_era_/Interface/AddOns/`

### Enable Modules
1. At character select, click "AddOns"
2. Enable `EasyLife` (core - required)
3. Enable any `EasyLife_*` modules you want

## Usage

- **Open Config**: `/easylife` or `/el`
- **Minimap Button**: Left-click or right-click for module menu

Each module shows a **first-run popup** with detailed instructions when opened for the first time.

## Project Structure

```
easylife/                         <- Clone this repo into AddOns folder
├── EasyLife/                     <- Core addon (required)
│   ├── Core.lua                  # Module registry, global table
│   ├── Locales.lua               # English & Turkish translations
│   ├── Config.lua                # Main config window
│   ├── Minimap.lua               # Minimap button
│   ├── Advertiser.lua            # Bundled module
│   ├── Boostilator.lua           # Bundled module
│   ├── VendorTracker.lua         # Bundled module
│   ├── IceBlockHelper.lua        # Bundled module
│   ├── AggroAlert.lua            # Bundled module
│   └── EasyLife.toc
│
├── EasyLife_Advertiser/          <- Stub addon (enables Advertiser separately)
├── EasyLife_Boostilator/         <- Stub addon
├── EasyLife_AggroAlert/          <- Stub addon
├── EasyLife_IceBlockHelper/      <- Stub addon
├── EasyLife_VendorTracker/       <- Stub addon
├── EasyLife_RangeIndicator/      <- Standalone addon
├── EasyLife_CastBarAura/         <- Standalone addon
│
├── README.md
├── LICENSE
└── .gitignore
```

## Clean Install / Reset

To reset all settings:
```
Delete: WTF/Account/<ACCOUNT>/SavedVariables/EasyLife.lua
```

## For Developers

See [EasyLife/.github/copilot-instructions.md](EasyLife/.github/copilot-instructions.md) for AI coding guidelines.

## License

MIT License - See [LICENSE](LICENSE) for details.
