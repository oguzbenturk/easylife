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
  RANGE_DESC = "Shows distance to closest mob and target",
  RANGE_ENABLE = "Enable Range Indicator",
  RANGE_SHOW_CLOSEST = "Show Closest Mob",
  RANGE_SHOW_TARGET = "Show Target Distance",
  RANGE_LOCKED = "Lock Position",
  RANGE_UPDATE_MS = "Update Rate",
  RANGE_RESET = "Reset Position",
  RANGE_FIRST_RUN_DETAILED = [[|cffFFD700Welcome to Range Indicator!|r

Track distances to mobs in real-time.

|cff00FF00=== DISPLAY ===|r
A compact frame shows:
• Distance to your current target
• Distance to the closest hostile mob

|cff00FF00=== SETTINGS ===|r
• Adjust update rate (lower = faster)
• Toggle closest mob / target display
• Lock/unlock frame position

|cffAAAAAATip: Great for kiting and maintaining safe distance!|r]],

  -- CastBarAura
  CAST_TITLE = "CastBar Aura",
  CAST_DESC = "Shows incoming spell casts targeting you",
  CAST_ENABLE = "Enable CastBar Aura",
  CAST_SHOW_ICON = "Show Spell Icon",
  CAST_PLAY_SOUND = "Play Warning Sound",
  CAST_LOCKED = "Lock Position",
  CAST_BAR_WIDTH = "Bar Width",
  CAST_BAR_HEIGHT = "Bar Height",
  CAST_APPEARANCE_HEADER = "Bar Appearance",
  CAST_RESET = "Reset Position",
  CAST_TEST = "Test Cast",
  CAST_COMBAT_LOG_HEADER = "Combat Logging",
  CAST_LOG_ENABLED = "Combat Logging: ENABLED",
  CAST_LOG_DISABLED = "Combat Logging: DISABLED",
  CAST_ENABLE_LOG = "Enable Combat Logging",
  CAST_DISABLE_LOG = "Disable Combat Logging",
  CAST_LOG_STATUS_ON = "Status: Combat Logging is ON",
  CAST_LOG_STATUS_OFF = "Status: Combat Logging is OFF",
  CAST_LOG_ENABLED_MSG = "Combat logging enabled!",
  CAST_LOG_DISABLED_MSG = "Combat logging disabled.",
  CAST_LOG_HELP = "Note: Combat logging must be enabled for this module to detect enemy casts. You can also use /combatlog command.",
  CAST_SHOW_ALL_HOSTILE = "Show ALL Hostile Casts",
  CAST_ONLY_WATCHED = "Only Show Dangerous Spells (from list)",
  CAST_FIRST_RUN_DETAILED = [[|cffFFD700Welcome to CastBar Aura!|r

See when mobs are casting spells on YOU.

|cff00FF00=== HOW IT WORKS ===|r
When an enemy starts casting a spell targeting you:
• A cast bar appears showing the spell
• Spell icon and caster name displayed
• Timer counts down to cast completion
• Bar flashes red when cast is almost done

|cff00FF00=== ALERTS ===|r
• Optional sound warning on cast start
• Multiple simultaneous casts supported
• Auto-removes when cast completes/interrupts

|cff00FF00=== CUSTOMIZATION ===|r
• Adjust bar width
• Toggle spell icons
• Enable/disable sound alerts
• Lock frame position

|cffAAAAAATip: Use this to know when to interrupt or avoid damage!|r]],

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

  -- AutoHelper
  AUTOHELPER_TITLE = "Auto Helper",
  AUTOHELPER_DESC = "Auto sell junk, repair gear, accept summons",
  AUTOHELPER_ENABLE = "Enable Auto Helper",
  AUTOHELPER_JUNK_HEADER = "Auto Sell Junk",
  AUTOHELPER_AUTO_SELL_JUNK = "Automatically sell gray items at vendors",
  AUTOHELPER_AUTO_SELL_JUNK_TIP = "When you open a vendor window, all gray quality items in your bags will be sold automatically.",
  AUTOHELPER_REPAIR_HEADER = "Auto Repair",
  AUTOHELPER_AUTO_REPAIR = "Automatically repair gear at vendors",
  AUTOHELPER_AUTO_REPAIR_TIP = "When you visit a vendor that can repair, your gear will be repaired automatically.",
  AUTOHELPER_USE_GUILD_REPAIR = "Use guild bank funds first",
  AUTOHELPER_USE_GUILD_REPAIR_TIP = "Try to use guild bank for repairs before using personal gold. Falls back to personal gold if guild funds unavailable.",
  AUTOHELPER_SUMMON_HEADER = "Auto Accept Summon",
  AUTOHELPER_AUTO_ACCEPT_SUMMON = "Automatically accept summons",
  AUTOHELPER_AUTO_ACCEPT_SUMMON_TIP = "When you receive a summon, it will be accepted automatically after a short delay.",
  AUTOHELPER_SUMMON_DELAY = "Summon Accept Delay",
  AUTOHELPER_INFO = "Features activate automatically when visiting vendors or receiving summons.",
  AUTOHELPER_SOLD_JUNK = "Sold %d junk item(s) for %s",
  AUTOHELPER_REPAIRED = "Repaired all gear for %s (%s)",
  AUTOHELPER_REPAIR_NO_MONEY = "Not enough money to repair!",
  AUTOHELPER_GUILD_BANK = "guild bank",
  AUTOHELPER_PERSONAL = "personal",
  AUTOHELPER_SUMMON_ACCEPTED = "Accepted summon from %s to %s",
  -- Smart Destroy
  AUTOHELPER_DESTROY_HEADER = "Smart Bag Management",
  AUTOHELPER_SMART_DESTROY = "Enable smart junk destroy when looting",
  AUTOHELPER_SMART_DESTROY_TIP = "When your bags are full while looting, automatically destroy the cheapest junk item to make room - but only if the new item is worth more.",
  AUTOHELPER_DESTROY_ONLY_GRAY = "Only destroy gray items",
  AUTOHELPER_DESTROY_ONLY_GRAY_TIP = "When enabled, only gray (poor) quality items can be destroyed. Disable to also consider white (common) items.",
  AUTOHELPER_MAX_DESTROY_VALUE = "Maximum item value to destroy",
  AUTOHELPER_PROTECT_SLOTS = "Reserved bag slots",
  AUTOHELPER_SLOTS = "slots",
  AUTOHELPER_DESTROYED_FOR_LOOT = "Destroyed %s (%s) to loot %s (%s)",
  AUTOHELPER_LOOT_NOT_WORTH = "Skipped %s (%s) - not worth destroying junk (%s)",
  AUTOHELPER_SMART_DESTROY_INFO = "Smart Destroy compares item values when bags are full. It only destroys a junk item if the loot is worth MORE than the cheapest junk in your bags.",
  AUTOHELPER_DESTROY_JUNK_BTN = "Destroy All Junk",
  AUTOHELPER_DESTROY_JUNK_BTN_TIP = "Immediately destroy all gray items in your bags that are below the maximum value threshold. This cannot be undone!",
  AUTOHELPER_DESTROYED_JUNK = "Destroyed %d junk item(s) worth %s",
  AUTOHELPER_NO_JUNK_TO_DESTROY = "No junk items to destroy!",
  AUTOHELPER_DESTROY_WARNING = "⚠ Cannot be undone!",
  AUTOHELPER_FIRST_RUN_DETAILED = [[|cffFFD700Welcome to Auto Helper!|r

Automate common tasks to save time.

|cff00FF00=== AUTO SELL JUNK ===|r
When visiting any vendor:
• Automatically sells all gray items
• Shows total gold earned
• No more manual bag cleaning!

|cff00FF00=== AUTO REPAIR ===|r
When visiting a repair vendor:
• Automatically repairs all gear
• Option to use guild bank funds
• Falls back to personal gold if needed

|cff00FF00=== AUTO SUMMON ===|r
When someone summons you:
• Automatically accepts after short delay
• Shows who summoned and destination

|cff00FF00=== SMART BAG MANAGEMENT ===|r
When your bags are full:
• Compares new loot vs cheapest junk
• Auto-destroys junk if loot is worth more
• Protects valuable items from deletion
• Set max value limit for safety

|cffAAAAAATip: All features can be toggled individually!|r]],
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
  RANGE_DESC = "En yakin mob ve hedefe mesafeyi goster",
  RANGE_ENABLE = "Mesafe Gostergesi Etkinlestir",
  RANGE_SHOW_CLOSEST = "En Yakin Mobu Goster",
  RANGE_SHOW_TARGET = "Hedef Mesafesini Goster",
  RANGE_LOCKED = "Konumu Kilitle",
  RANGE_UPDATE_MS = "Guncelleme Hizi",
  RANGE_RESET = "Pozisyonu Sifirla",
  RANGE_FIRST_RUN_DETAILED = [[|cffFFD700Mesafe Gostergesi'ne Hosgeldiniz!|r

Moblara olan mesafeyi gercek zamanli takip edin.

|cff00FF00=== GOSTERGE ===|r
• Hedefinize olan mesafe
• En yakin dusman moba mesafe

|cff00FF00=== AYARLAR ===|r
• Guncelleme hizi (dusuk = hizli)
• En yakin mob / hedef gosterimi

|cffAAAAAATip: Kiting icin harika!|r]],

  -- CastBarAura
  CAST_TITLE = "CastBar Aura",
  CAST_DESC = "Sizi hedef alan buyu atislarini goster",
  CAST_ENABLE = "CastBar Aura Etkinlestir",
  CAST_SHOW_ICON = "Buyu Ikonunu Goster",
  CAST_PLAY_SOUND = "Uyari Sesi Cal",
  CAST_LOCKED = "Konumu Kilitle",
  CAST_BAR_WIDTH = "Bar Genisligi",
  CAST_BAR_HEIGHT = "Bar Yuksekligi",
  CAST_APPEARANCE_HEADER = "Bar Gorunumu",
  CAST_RESET = "Pozisyonu Sifirla",
  CAST_TEST = "Test Et",
  CAST_COMBAT_LOG_HEADER = "Savas Kaydi",
  CAST_LOG_ENABLED = "Savas Kaydi: AKTIF",
  CAST_LOG_DISABLED = "Savas Kaydi: KAPALI",
  CAST_ENABLE_LOG = "Savas Kaydini Ac",
  CAST_DISABLE_LOG = "Savas Kaydini Kapat",
  CAST_LOG_STATUS_ON = "Durum: Savas Kaydi ACIK",
  CAST_LOG_STATUS_OFF = "Durum: Savas Kaydi KAPALI",
  CAST_LOG_ENABLED_MSG = "Savas kaydi etkinlestirildi!",
  CAST_LOG_DISABLED_MSG = "Savas kaydi kapatildi.",
  CAST_LOG_HELP = "Not: Bu modulun dusman buyulerini algilamasi icin savas kaydi etkin olmalidir. /combatlog komutu da kullanabilirsiniz.",
  CAST_SHOW_ALL_HOSTILE = "TUM Dusman Buyulerini Goster",
  CAST_ONLY_WATCHED = "Sadece Tehlikeli Buyuleri Goster (listeden)",
  CAST_FIRST_RUN_DETAILED = [[|cffFFD700CastBar Aura'ya Hosgeldiniz!|r

Dusmanlar size buyu atarken gorun.

|cff00FF00=== NASIL CALISIR ===|r
• Duman size buyu atarken bar gosterilir
• Buyu ikonu ve atan ismi gosterilir
• Zamanlayici tamamlanmaya sayar

|cff00FF00=== UYARILAR ===|r
• Opsiyonel ses uyarisi
• Birden fazla buyu destegi

|cffAAAAAATip: Interrupt zamanlamaniz icin kullanin!|r]],

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

  -- AutoHelper
  AUTOHELPER_TITLE = "Oto Yardimci",
  AUTOHELPER_DESC = "Otomatik cop sat, onar, cagriya kabul et",
  AUTOHELPER_ENABLE = "Oto Yardimci'yi Etkinlestir",
  AUTOHELPER_JUNK_HEADER = "Otomatik Cop Satisi",
  AUTOHELPER_AUTO_SELL_JUNK = "Saticida gri esyalari otomatik sat",
  AUTOHELPER_AUTO_SELL_JUNK_TIP = "Satici penceresini actiginizda, cantanizdaki tum gri kalitedeki esyalar otomatik olarak satilir.",
  AUTOHELPER_REPAIR_HEADER = "Otomatik Onarim",
  AUTOHELPER_AUTO_REPAIR = "Saticida ekipmani otomatik onar",
  AUTOHELPER_AUTO_REPAIR_TIP = "Onarim yapabilen bir saticiyi ziyaret ettiginizde, ekipmaniniz otomatik olarak onarilir.",
  AUTOHELPER_USE_GUILD_REPAIR = "Once lonca bankasini kullan",
  AUTOHELPER_USE_GUILD_REPAIR_TIP = "Onarim icin once lonca bankasini kullanmayi dene. Lonca parasi yoksa kisisel altina gecer.",
  AUTOHELPER_SUMMON_HEADER = "Otomatik Cagri Kabul",
  AUTOHELPER_AUTO_ACCEPT_SUMMON = "Cagrilari otomatik kabul et",
  AUTOHELPER_AUTO_ACCEPT_SUMMON_TIP = "Bir cagri aldiginizda, kisa bir gecikmeden sonra otomatik olarak kabul edilir.",
  AUTOHELPER_SUMMON_DELAY = "Cagri Kabul Gecikmesi",
  AUTOHELPER_INFO = "Ozellikler satici ziyaretinde veya cagri aldiginda otomatik calisir.",
  AUTOHELPER_SOLD_JUNK = "%d cop esya satildi: %s",
  AUTOHELPER_REPAIRED = "Tum ekipman onarildi: %s (%s)",
  AUTOHELPER_REPAIR_NO_MONEY = "Onarim icin yeterli para yok!",
  AUTOHELPER_GUILD_BANK = "lonca bankasi",
  AUTOHELPER_PERSONAL = "kisisel",
  AUTOHELPER_SUMMON_ACCEPTED = "%s tarafindan %s'e cagri kabul edildi",
  -- Smart Destroy
  AUTOHELPER_DESTROY_HEADER = "Akilli Canta Yonetimi",
  AUTOHELPER_SMART_DESTROY = "Loot alirken akilli cop silme",
  AUTOHELPER_SMART_DESTROY_TIP = "Loot alirken cantaniz doluysa, yer acmak icin en ucuz cop esyayi otomatik siler - ancak yeni esya daha degerli ise.",
  AUTOHELPER_DESTROY_ONLY_GRAY = "Sadece gri esyalari sil",
  AUTOHELPER_DESTROY_ONLY_GRAY_TIP = "Etkinlestirildiginde, sadece gri (zayif) kalitedeki esyalar silinebilir. Beyaz (siradan) esyalari da dahil etmek icin devre disi birakin.",
  AUTOHELPER_MAX_DESTROY_VALUE = "Silinecek maksimum esya degeri",
  AUTOHELPER_PROTECT_SLOTS = "Ayrilmis canta yerleri",
  AUTOHELPER_SLOTS = "yer",
  AUTOHELPER_DESTROYED_FOR_LOOT = "%s (%s) silindi, %s (%s) icin",
  AUTOHELPER_LOOT_NOT_WORTH = "%s (%s) atlanidi - cop silmeye degmez (%s)",
  AUTOHELPER_SMART_DESTROY_INFO = "Akilli Silme, cantaniz doluyken esya degerlerini karsilastirir. Sadece loot, cantanizdaki en ucuz coptan DAHA DEGERLI ise cop esyayi siler.",
  AUTOHELPER_DESTROY_JUNK_BTN = "Tum Coplari Sil",
  AUTOHELPER_DESTROY_JUNK_BTN_TIP = "Cantanizdaki maksimum deger esiginin altindaki tum gri esyalari hemen siler. Bu geri alinamaz!",
  AUTOHELPER_DESTROYED_JUNK = "%d cop esya silindi, degeri: %s",
  AUTOHELPER_NO_JUNK_TO_DESTROY = "Silinecek cop esya yok!",
  AUTOHELPER_DESTROY_WARNING = "⚠ Geri alinamaz!",
  AUTOHELPER_FIRST_RUN_DETAILED = [[|cffFFD700Oto Yardimci'ya Hosgeldiniz!|r

Zaman kazanmak icin gorevleri otomatiklestirin.

|cff00FF00=== OTO COP SATISI ===|r
Herhangi bir saticiyi ziyaret ettiginde:
• Tum gri esyalari otomatik satar
• Kazanilan altini gosterir
• Elle canta temizligi yok!

|cff00FF00=== OTO ONARIM ===|r
Onarim saticisini ziyaret ettiginde:
• Tum ekipmani otomatik onarir
• Lonca bankasi kullanimi secenegi
• Gerekirse kisisel altina gecer

|cff00FF00=== OTO CAGRI ===|r
Biri sizi cagirdiginda:
• Kisa gecikmeden sonra otomatik kabul
• Cagirani ve hedefi gosterir

|cff00FF00=== AKILLI CANTA YONETIMI ===|r
Cantaniz doluyken:
• Yeni loot vs en ucuz copu karsilastirir
• Loot daha degerliyse copu otomatik siler
• Degerli esyalari silinmekten korur
• Guvenlik icin maksimum deger siniri

|cffAAAAAATip: Tum ozellikler ayri ayri acilip kapatilabilir!|r]],
}

function EasyLife:L(key)
  local lang = self:GetLanguage()
  if lang == "trTR" and L_trTR[key] then
    return L_trTR[key]
  end
  return L_enUS[key] or key
end
