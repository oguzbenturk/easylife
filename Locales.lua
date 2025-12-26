-- EasyLife Locales
local L_enUS = {
  ADDON_NAME = "EasyLife",
  CONFIG_TITLE = "EasyLife Configuration",
  LANGUAGE = "Language",
  LANGUAGE_AUTO = "Auto",
  LANGUAGE_EN = "English",
  LANGUAGE_TR = "Turkish",
  NO_MODULES = "No modules loaded. Enable EasyLife modules in the addon list.",
  MODULE_NOT_LOADED = "Module not loaded",
  CLOSE = "Close",
  
  -- RangeIndicator
  RANGE_TITLE = "Range Indicator",
  RANGE_UPDATE_RATE = "Update rate (sec)",
  RANGE_SIZE = "Size",
  RANGE_RESET = "Reset Position",
  
  -- CastBarAura
  CAST_TITLE = "CastBar Aura",
  
  -- Advertise
  ADS_TITLE = "Advertise",
  ADS_ENABLE = "Enable Advertiser",
  ADS_ENABLE_AUTO_INVITE = "Enable Auto Invite",
  ADS_KEYWORDS = "Keywords (comma separated)",
  ADS_MONITORED_CHANNELS = "Monitored Channels",
  ADS_CHANNEL_WHISPER = "Whisper",
  ADS_CHANNEL_SAY = "Say",
  ADS_CHANNEL_YELL = "Yell",
  ADS_AUTO_INVITED = "Auto invited",
  ADS_ENABLE_AD = "Enable Auto Message",
  ADS_MESSAGE = "Message",
  ADS_INTERVAL = "Interval (sec)",
  
  -- Boostilator
  BOOST_TITLE = "Boostilator",
  
  -- VendorTracker
  VENDOR_TITLE = "Vendor Tracker",
  
  -- IceBlockHelper
  ICEBLOCK_TITLE = "Ice Block Helper",
  
  -- AggroAlert
  AGGRO_TITLE = "Aggro Alert",
  
  -- Module descriptions for module manager
  ADS_DESC = "Auto-invite players, scheduled ads, auto-reply to whispers",
  BOOST_DESC = "Track boosting clients, runs, and payments",
  VENDOR_DESC = "Shows vendor value of looted items",
  ICEBLOCK_DESC = "Shows optimal moment to cancel Ice Block",
  AGGRO_DESC = "Big warning when mobs target you",
  
  -- First-run popup
  FIRST_RUN_GOT_IT = "Got it!",
  FIRST_RUN_DONT_SHOW = "Don't show this again",
  
  -- Detailed first-run content for popup
  ADS_FIRST_RUN_DETAILED = [[|cffFFD700Welcome to Advertiser!|r

This powerful module helps you automate chat advertising and party invites.

|cff00FF00=== AUTO INVITE ===|r
Monitor whispers and channels for keywords like "inv" or custom phrases.
When detected, automatically invite the player to your group.
• Set custom keywords (comma-separated)
• Choose which channels to monitor
• Configurable invite delay

|cff00FF00=== SEND MESSAGE ===|r
Broadcast your message to multiple channels with one click.
• Create your custom ad message
• Select target channels (Trade, LFG, etc.)
• Use the floating button for quick sending
• Set cooldown between messages

|cff00FF00=== AUTO SEND TIMER ===|r
Schedule automatic message broadcasting.
• Set interval between sends
• Messages queue safely to avoid spam detection

|cff00FF00=== AUTO REPLY ===|r
Automatically respond to whispers with custom rules.
• Create keyword-triggered responses
• Set reply cooldowns per player

|cffAAAAAATip: Right-click the floating Ad button to drag it!|r]],

  BOOST_FIRST_RUN_DETAILED = [[|cffFFD700Welcome to Boostilator!|r

The ultimate boosting session tracker for dungeon carries.

|cff00FF00=== SESSION TAB ===|r
Manage your current boosting clients (boosties).
• Click "Add Party" to add all party members as boosties
• Track runs completed for each client (X/Y format)
• Increment/decrement runs with +/- buttons
• Remove clients when done

|cff00FF00=== PRICING ===|r
Configure your run prices in Settings tab:
• Single run price
• 3-run package price
• 5-run package price
• Quick balance adjustment amounts

|cff00FF00=== PAYMENT TRACKING ===|r
Automatic payment detection!
• Trade with a boostie to record their payment
• Balance updates automatically
• See who owes gold at a glance

|cff00FF00=== ANNOUNCEMENTS ===|r
Announce session status to party/raid:
• Runs starting notification
• Runs remaining summary
• Completion messages
• Custom announcement templates

|cffAAAAAATip: Trade window auto-records payments from boosties!|r]],

  VENDOR_FIRST_RUN_DETAILED = [[|cffFFD700Welcome to Vendor Tracker!|r

Track the vendor value of everything you loot.

|cff00FF00=== DISPLAY ===|r
A small frame shows your loot value:
• Session total (current play session)
• Live updates as you loot items

|cff00FF00=== CONTROLS ===|r
• |cffFFD700Drag|r - Move the display anywhere
• |cffFFD700Right-click|r - Lock/unlock position
• |cffFFD700Shift + Right-click|r - Reset session value

|cff00FF00=== SETTINGS ===|r
• Show/hide during combat
• Count party member loot (optional)
• Enable/disable the tracker

|cffAAAAAATip: Great for farming sessions to track gold/hour!|r]],

  ICEBLOCK_FIRST_RUN_DETAILED = [[|cffFFD700Welcome to Ice Block Helper!|r

For Mages: Know exactly when to cancel Ice Block safely.

|cff00FF00=== HOW IT WORKS ===|r
The addon tracks mob attack timing and shows you:
• |cffFF0000RED ZONE|r - Danger! Mob is about to swing
• |cff00FF00GREEN ZONE|r - Safe window to cancel Ice Block

|cff00FF00=== SWING TIMER LEARNING ===|r
The addon automatically learns mob swing timers:
• Observes attacks while you're Ice Blocked
• Builds a prediction for next attack
• More accurate over time

|cff00FF00=== DISPLAY ===|r
• Visual bar shows swing timer progress
• Safe zone highlighted in green
• Status text shows current state

|cff00FF00=== CONTROLS ===|r
• Drag to move the display
• Lock position in settings

|cffAAAAAATip: Cancel Ice Block in the green zone to maximize safety!|r]],

  AGGRO_FIRST_RUN_DETAILED = [[|cffFFD700Welcome to Aggro Alert!|r

Big on-screen warnings when you have threat.

|cff00FF00=== AGGRO ALERT ===|r
A large flashing warning appears when mobs target you:
• Customizable alert text
• Configurable font size and color
• Adjustable flash speed
• Optional sound alert

|cff00FF00=== THREAT WARNING ===|r
Get warned BEFORE you pull aggro:
• Set threat threshold (e.g., 80%)
• Separate warning text and color
• Helps you manage threat proactively

|cff00FF00=== POSITIONING ===|r
• Drag alerts to any screen position
• Lock position when satisfied
• Reset to center anytime

|cff00FF00=== CUSTOMIZATION ===|r
• Change alert text to anything you want
• Pick colors for both alert types
• Enable/disable sound effects

|cffAAAAAATip: Set threat warning to 80% to know when to slow down!|r]],
}

local L_trTR = {
  ADDON_NAME = "EasyLife",
  CONFIG_TITLE = "EasyLife Ayarlari",
  LANGUAGE = "Dil",
  LANGUAGE_AUTO = "Otomatik",
  LANGUAGE_EN = "Ingilizce",
  LANGUAGE_TR = "Turkce",
  NO_MODULES = "Modul yuklenmedi. Addon listesinden EasyLife modullerini etkinlestirin.",
  MODULE_NOT_LOADED = "Modul yuklenmedi",
  CLOSE = "Kapat",
  
  -- RangeIndicator
  RANGE_TITLE = "Mesafe Gostergesi",
  RANGE_UPDATE_RATE = "Guncelleme hizi (sn)",
  RANGE_SIZE = "Boyut",
  RANGE_RESET = "Pozisyonu Sifirla",
  
  -- CastBarAura
  CAST_TITLE = "CastBar Aura",
  
  -- Advertise
  ADS_TITLE = "Reklam",
  ADS_ENABLE = "Reklamciyi Etkinlestir",
  ADS_ENABLE_AUTO_INVITE = "Otomatik Daveti Etkinlestir",
  ADS_KEYWORDS = "Anahtar Kelimeler (virgulle ayrilmis)",
  ADS_MONITORED_CHANNELS = "Izlenen Kanallar",
  ADS_CHANNEL_WHISPER = "Fisilti",
  ADS_CHANNEL_SAY = "Say",
  ADS_CHANNEL_YELL = "Bagirma",
  ADS_AUTO_INVITED = "Otomatik davet edildi",
  ADS_ENABLE_AD = "Otomatik Mesaji Etkinlestir",
  ADS_MESSAGE = "Mesaj",
  ADS_INTERVAL = "Aralik (sn)",
  
  -- Boostilator
  BOOST_TITLE = "Boostilator",
  
  -- VendorTracker
  VENDOR_TITLE = "Vendor Takipci",
  
  -- IceBlockHelper
  ICEBLOCK_TITLE = "Ice Block Yardimcisi",
  
  -- AggroAlert
  AGGRO_TITLE = "Aggro Uyarisi",
  
  -- Module descriptions for module manager
  ADS_DESC = "Otomatik davet, zamanli reklamlar, otomatik cevaplama",
  BOOST_DESC = "Boost musterilerini, kosu sayisini ve odemeleri takip et",
  VENDOR_DESC = "Toplanan esyalarin satici degerini goster",
  ICEBLOCK_DESC = "Ice Block'u iptal etmek icin optimal ani goster",
  AGGRO_DESC = "Canavarlar sizi hedef aldiginda buyuk uyari",
  
  -- First-run popup
  FIRST_RUN_GOT_IT = "Anladim!",
  FIRST_RUN_DONT_SHOW = "Bunu tekrar gosterme",
  
  -- Detailed first-run content (Turkish)
  ADS_FIRST_RUN_DETAILED = [[|cffFFD700Reklamci'ya Hosgeldiniz!|r

Sohbet reklamlarini ve parti davetlerini otomatiklestirin.

|cff00FF00=== OTOMATIK DAVET ===|r
Fisildama ve kanallarda anahtar kelimeleri izleyin.
• Ozel anahtar kelimeler belirleyin
• Izlenecek kanallari secin
• Davet gecikmesi ayarlayin

|cff00FF00=== MESAJ GONDER ===|r
Tek tikla birden fazla kanala mesaj gonderin.
• Reklam mesajinizi olusturun
• Hedef kanallari secin
• Hizli gondermek icin yuzen butonu kullanin

|cff00FF00=== OTOMATIK YANIT ===|r
Fisildalara otomatik yanit verin.
• Anahtar kelime tetikleyicileri
• Oyuncu basina bekleme suresi

|cffAAAAAATip: Ad butonunu suruklemek icin sag tiklayin!|r]],

  BOOST_FIRST_RUN_DETAILED = [[|cffFFD700Boostilator'a Hosgeldiniz!|r

Zindan tasimaciligini takip edin.

|cff00FF00=== OTURUM ===|r
Boost musterilerinizi yonetin.
• Parti uyelerini ekleyin
• Kosu sayisini takip edin
• +/- butonlariyla guncelleme

|cff00FF00=== FIYATLANDIRMA ===|r
Ayarlar sekmesinde fiyatlarinizi belirleyin.

|cff00FF00=== ODEME TAKIBI ===|r
Ticaret penceresi odemeleri otomatik kaydeder!

|cffAAAAAATip: Boostie ile ticaret yapin, odeme otomatik kaydedilsin!|r]],

  VENDOR_FIRST_RUN_DETAILED = [[|cffFFD700Vendor Takipci'ye Hosgeldiniz!|r

Loot ettiginiz esyalarin satici degerini takip edin.

|cff00FF00=== KONTROLLER ===|r
• |cffFFD700Surukleyin|r - Ekrani tasiyin
• |cffFFD700Sag tik|r - Konumu kilitleyin
• |cffFFD700Shift + Sag tik|r - Oturumu sifirlayin

|cffAAAAAATip: Farm seanslari icin ideal!|r]],

  ICEBLOCK_FIRST_RUN_DETAILED = [[|cffFFD700Ice Block Yardimcisi'na Hosgeldiniz!|r

Ice Block'u ne zaman iptal edeceginizi bilin.

|cff00FF00=== NASIL CALISIR ===|r
• |cffFF0000KIRMIZI|r - Tehlike! Mob saldirmak uzere
• |cff00FF00YESIL|r - Guvenli iptal penceresi

Addon mob saldirilarina bakarak ogrenir.

|cffAAAAAATip: Yesil bolgede iptal edin!|r]],

  AGGRO_FIRST_RUN_DETAILED = [[|cffFFD700Aggro Uyarisi'na Hosgeldiniz!|r

Tehdit cekerken ekranda buyuk uyari gosterin.

|cff00FF00=== AGGRO UYARISI ===|r
Mobler sizi hedef aldiginda uyari.
• Ozel uyari metni
• Renk ve boyut ayarlari
• Ses uyarisi

|cff00FF00=== TEHDIT UYARISI ===|r
Aggro cekmeden ONCE uyari alin.
• Esik degeri ayarlayin (orn. %80)

|cffAAAAAATip: %80 uyari esigi oneririz!|r]],
}

function EasyLife:L(key)
  local lang = self:GetLanguage()
  if lang == "trTR" and L_trTR[key] then
    return L_trTR[key]
  end
  return L_enUS[key] or key
end
