-- CastBarAura Module
-- Shows when mobs are casting spells targeting you (like DBM alerts)
local CastBarAura = {}

local displayFrame
local activeCasts = {}  -- Track active casts targeting player
local eventFrame

local DEFAULTS = {
  enabled = true,
  x = 0,
  y = 200,
  locked = true,
  barWidth = 250,
  barHeight = 25,
  showIcon = true,
  playSound = true,
  soundFile = "Interface\\AddOns\\EasyLife\\Sounds\\cast_warning.ogg",
  showAllHostileCasts = true,  -- Show ALL hostile casts (regardless of target)
  onlyWatchedSpells = false,   -- Only show spells from the watchlist
  watchedSpells = {},  -- User can add custom spell IDs
}

-- Dangerous spells to always show (Dire Maul and common dungeon spells)
-- Format: [spellId] = castTime (in seconds), 0 = use default
local DANGEROUS_SPELLS = {
  -- Dire Maul East
  [22478] = 2.0,   -- Zevrim Thornhoof - Intense Pain
  [22651] = 1.5,   -- Zevrim Thornhoof - Sacrifice
  [17228] = 2.0,   -- Shadow Bolt Volley (multiple mobs)
  [22661] = 3.0,   -- Alzzin - Enervate
  [22662] = 2.0,   -- Alzzin - Wither
  [22415] = 2.0,   -- Alzzin - Entangling Roots
  -- Dire Maul West  
  [22950] = 2.0,   -- Immol'thar - Portal of Immol'thar
  [22899] = 0,     -- Immol'thar - Eye of Immol'thar
  [7645] = 3.0,    -- Magister Kalendris - Dominate Mind
  [22995] = 2.0,   -- Prince Tortheldrin - Summon
  -- Dire Maul North
  [22886] = 0,     -- King Gordok - Berserker Charge
  [16740] = 0,     -- War Stomp (multiple mobs)
  [22833] = 2.0,   -- Stomper Kreeg - Booze Spit
  [15578] = 0,     -- Whirlwind
  -- Common dangerous spells
  [5138] = 3.0,    -- Drain Mana
  [11668] = 3.0,   -- Frostbolt (high rank)
  [12466] = 3.5,   -- Fireball (high rank)
  [15232] = 3.0,   -- Shadow Bolt (high rank)
  [16568] = 3.0,   -- Mind Flay
  [14515] = 1.5,   -- Dominate Mind
  [20604] = 1.5,   -- Dominate Mind
  [12098] = 1.5,   -- Sleep
  [15970] = 1.5,   -- Sleep (rank 2)
  [8988] = 0,      -- Silence
  [15487] = 0,     -- Silence
  [17165] = 1.5,   -- Mind Blast
  [6713] = 0,      -- Disarm
  [15708] = 0,     -- Mortal Strike
  [16856] = 0,     -- Mortal Strike (rank 2)
  [11978] = 0,     -- Kick
  [11972] = 0,     -- Shield Bash
  [15655] = 0,     -- Shield Slam
  [8269] = 0,      -- Frenzy
  [8599] = 0,      -- Enrage
  [12795] = 0,     -- Frenzy (rank 2)
  [28747] = 0,     -- Frenzy (rank 3)
  [11876] = 0.5,   -- War Stomp
  [15593] = 0,     -- Stun
  [11428] = 0,     -- Knockdown
  [15618] = 0,     -- Snap Kick
  -- Scholomance
  [17405] = 3.0,   -- Dominate Mind
  [12889] = 2.5,   -- Curse of Tongues
  [18671] = 3.5,   -- Curse of Agony
  [15471] = 2.0,   -- Counterspell - Silence
  -- Stratholme
  [16798] = 3.0,   -- Enchanting Lullaby
  [17405] = 3.0,   -- Dominate Mind
  [16869] = 2.0,   -- Ice Tomb
  [17620] = 3.0,   -- Drain Life
  -- UBRS/LBRS
  [16727] = 0.5,   -- War Stomp
  [15654] = 2.0,   -- Shadow Word: Pain
  [22667] = 2.0,   -- Shadow Word: Pain
  [15587] = 3.0,   -- Mind Blast
  [17194] = 3.0,   -- Mind Blast
}

local function ensureDB()
  EasyLifeDB = EasyLifeDB or {}
  EasyLifeDB.castBarAura = EasyLifeDB.castBarAura or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.castBarAura[k] == nil then
      EasyLifeDB.castBarAura[k] = v
    end
  end
  if EasyLifeDB.castBarAura._firstRunShown == nil then
    EasyLifeDB.castBarAura._firstRunShown = false
  end
  return true
end

local function getDB()
  ensureDB()
  return EasyLifeDB.castBarAura
end

local function L(key)
  return EasyLife:L(key)
end

-- Create a cast bar for a specific cast
local function CreateCastBar(casterGUID, spellName, spellIcon, castTime, startTime)
  local db = getDB()
  
  if not displayFrame then
    displayFrame = CreateFrame("Frame", "EasyLifeCastBarAuraContainer", UIParent)
    displayFrame:SetSize(db.barWidth, 200)
    displayFrame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    displayFrame:SetFrameStrata("HIGH")
    displayFrame:SetMovable(true)
    displayFrame:EnableMouse(true)
    displayFrame:RegisterForDrag("LeftButton")
    displayFrame:SetClampedToScreen(true)
    
    displayFrame:SetScript("OnDragStart", function(self)
      local db = getDB()
      if not db.locked then
        self:StartMoving()
      end
    end)
    
    displayFrame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local db = getDB()
      local point, _, _, x, y = self:GetPoint()
      db.x = x
      db.y = y
    end)
  end
  
  -- Don't create duplicate bars for same caster
  if activeCasts[casterGUID] then
    return activeCasts[casterGUID]
  end
  
  local bar = CreateFrame("Frame", nil, displayFrame, "BackdropTemplate")
  bar:SetSize(db.barWidth, db.barHeight)
  bar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  bar:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
  bar:SetBackdropBorderColor(1, 0.3, 0.3, 1)
  
  -- Position bars vertically
  local barCount = 0
  for _ in pairs(activeCasts) do barCount = barCount + 1 end
  bar:SetPoint("TOP", displayFrame, "TOP", 0, -barCount * (db.barHeight + 5))
  
  -- Spell icon
  if db.showIcon then
    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetSize(db.barHeight - 4, db.barHeight - 4)
    bar.icon:SetPoint("LEFT", 4, 0)
    bar.icon:SetTexture(spellIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  
  -- Progress bar background
  bar.progress = CreateFrame("StatusBar", nil, bar)
  bar.progress:SetPoint("LEFT", db.showIcon and (db.barHeight + 2) or 6, 0)
  bar.progress:SetPoint("RIGHT", -6, 0)
  bar.progress:SetHeight(db.barHeight - 8)
  bar.progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar.progress:SetStatusBarColor(1, 0.4, 0.4, 1)
  bar.progress:SetMinMaxValues(0, castTime)
  bar.progress:SetValue(0)
  
  -- Spell name text
  bar.spellName = bar.progress:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bar.spellName:SetPoint("LEFT", 4, 0)
  bar.spellName:SetText(spellName or "Unknown Spell")
  bar.spellName:SetTextColor(1, 1, 1)
  
  -- Timer text
  bar.timer = bar.progress:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bar.timer:SetPoint("RIGHT", -4, 0)
  bar.timer:SetText(string.format("%.1f", castTime))
  bar.timer:SetTextColor(1, 1, 0)
  
  -- Caster name above bar
  bar.casterName = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bar.casterName:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 2, 2)
  
  -- Try to get caster name from GUID
  local casterName = "Unknown"
  local casterType = strsplit("-", casterGUID)
  if casterType == "Creature" or casterType == "Vehicle" then
    -- Will be updated if we can find the unit
    for i = 1, 40 do
      local unit = "nameplate" .. i
      if UnitExists(unit) and UnitGUID(unit) == casterGUID then
        casterName = UnitName(unit) or "Unknown"
        break
      end
    end
  end
  bar.casterName:SetText("|cffFF6666" .. casterName .. "|r")
  
  -- Store cast info
  bar.startTime = startTime
  bar.castTime = castTime
  bar.casterGUID = casterGUID
  
  -- Update timer
  bar:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    local remaining = self.castTime - (now - self.startTime)
    
    if remaining <= 0 then
      -- Cast finished
      self:SetScript("OnUpdate", nil)
      activeCasts[self.casterGUID] = nil
      self:Hide()
      CastBarAura:RepositionBars()
      return
    end
    
    self.progress:SetValue(now - self.startTime)
    self.timer:SetText(string.format("%.1f", remaining))
  end)
  
  bar:Show()
  activeCasts[casterGUID] = bar
  
  -- Play warning sound
  if db.playSound then
    PlaySoundFile(db.soundFile, "Master")
  end
  
  return bar
end

function CastBarAura:RepositionBars()
  local db = getDB()
  local index = 0
  for guid, bar in pairs(activeCasts) do
    if bar and bar:IsShown() then
      bar:ClearAllPoints()
      bar:SetPoint("TOP", displayFrame, "TOP", 0, -index * (db.barHeight + 5))
      index = index + 1
    end
  end
end

function CastBarAura:RemoveCast(casterGUID)
  local bar = activeCasts[casterGUID]
  if bar then
    bar:SetScript("OnUpdate", nil)
    bar:Hide()
    activeCasts[casterGUID] = nil
    self:RepositionBars()
  end
end

function CastBarAura:ClearAllCasts()
  for guid, bar in pairs(activeCasts) do
    if bar then
      bar:SetScript("OnUpdate", nil)
      bar:Hide()
    end
  end
  wipe(activeCasts)
end

-- Helper: Check if a unit flag indicates hostile NPC
local function IsHostileNPC(flags)
  if not flags then return false end
  -- COMBATLOG_OBJECT_TYPE_NPC = 0x800
  -- COMBATLOG_OBJECT_REACTION_HOSTILE = 0x40
  local isNPC = bit.band(flags, 0x800) > 0
  local isHostile = bit.band(flags, 0x40) > 0
  return isNPC and isHostile
end

-- Helper: Try to find unit from GUID (best effort - may return nil for distant mobs)
local function TryFindUnitFromGUID(guid)
  -- Check target first (most common case - player targeting the caster)
  if UnitExists("target") and UnitGUID("target") == guid then
    return "target"
  end
  -- Check focus
  if UnitExists("focus") and UnitGUID("focus") == guid then
    return "focus"
  end
  -- Check boss frames (for dungeon/raid bosses)
  for i = 1, 5 do
    local unit = "boss" .. i
    if UnitExists(unit) and UnitGUID(unit) == guid then
      return unit
    end
  end
  -- Check nameplates (limited range ~20-40 yards)
  for i = 1, 40 do
    local unit = "nameplate" .. i
    if UnitExists(unit) and UnitGUID(unit) == guid then
      return unit
    end
  end
  return nil
end

-- Helper: Get cast time - from spell table, unit, or default
local function GetCastTime(spellId, unit)
  -- First check our spell database
  local knownCastTime = DANGEROUS_SPELLS[spellId]
  if knownCastTime and knownCastTime > 0 then
    return knownCastTime
  end
  
  -- Try to get from unit if available
  if unit and UnitExists(unit) then
    local _, _, _, startTimeMs, endTimeMs = UnitCastingInfo(unit)
    if endTimeMs and startTimeMs then
      return (endTimeMs - startTimeMs) / 1000
    end
  end
  
  -- Default fallback
  return 2.5
end

-- Helper: Check if a spell is on our watchlist
local function IsWatchedSpell(spellId)
  if DANGEROUS_SPELLS[spellId] ~= nil then return true end
  local db = getDB()
  if db.watchedSpells and db.watchedSpells[spellId] then return true end
  return false
end

-- Helper: Check if unit is targeting player (best effort)
local function IsUnitTargetingPlayer(unit)
  if not unit or not UnitExists(unit) then return false end
  local targetUnit = unit .. "target"
  if UnitExists(targetUnit) and UnitIsUnit(targetUnit, "player") then
    return true
  end
  return false
end

local function OnCombatLogEvent()
  local db = getDB()
  if not db.enabled then return end
  
  local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
        destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
  
  if subevent == "SPELL_CAST_START" then
    -- Only track hostile NPCs
    if not IsHostileNPC(sourceFlags) then return end
    
    local spellId, spellName = select(12, CombatLogGetCurrentEventInfo())
    
    -- Get spell info - combat log name may be nil in Classic Era
    -- Use GetSpellInfo as fallback for both name and icon
    local spellInfoName, _, spellInfoIcon = GetSpellInfo(spellId)
    if not spellName or spellName == "" then
      spellName = spellInfoName or ("Spell " .. tostring(spellId))
    end
    local spellIcon = spellInfoIcon or GetSpellTexture(spellId)
    
    -- Check if this is a watched dangerous spell
    local isWatched = IsWatchedSpell(spellId)
    
    -- Decide whether to show this cast:
    -- If onlyWatchedSpells is true, ONLY show watched spells
    -- If showAllHostileCasts is true, show ALL hostile casts
    -- Otherwise, only show watched spells
    if db.onlyWatchedSpells then
      if not isWatched then return end
    elseif not db.showAllHostileCasts then
      if not isWatched then return end
    end
    -- If showAllHostileCasts is true and onlyWatchedSpells is false, show everything
    
    -- Try to find the unit (may fail for distant mobs - that's OK for cast time)
    local casterUnit = TryFindUnitFromGUID(sourceGUID)
    
    -- Get cast time from our database or the unit
    local castTime = GetCastTime(spellId, casterUnit)
    
    -- Only show casts with meaningful cast time (ignore instant casts)
    if castTime < 0.3 then return end
    
    CreateCastBar(sourceGUID, spellName, spellIcon, castTime, GetTime())
    
  -- Handle cast completions/interrupts
  elseif subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_CAST_FAILED" 
      or subevent == "SPELL_INTERRUPT" then
    -- Remove cast bar when cast ends (for any reason)
    if activeCasts[sourceGUID] then
      CastBarAura:RemoveCast(sourceGUID)
    end
  end
end

function CastBarAura:Enable()
  if not eventFrame then
    eventFrame = CreateFrame("Frame")
  end
  
  -- Combat log is the primary detection method
  eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  
  eventFrame:SetScript("OnEvent", function(_, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
      OnCombatLogEvent()
    end
  end)
  
  -- Create container frame
  if displayFrame then
    displayFrame:Show()
  end
end

function CastBarAura:Disable()
  if eventFrame then
    eventFrame:UnregisterAllEvents()
  end
  self:ClearAllCasts()
  if displayFrame then
    displayFrame:Hide()
  end
end

function CastBarAura:UpdateState()
  local db = getDB()
  if db.enabled then
    self:Enable()
  else
    self:Disable()
  end
end

function CastBarAura:CleanupUI()
  self:Disable()
end

function CastBarAura:BuildConfigUI(parent)
  local db = getDB()
  
  -- First-run popup
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("CastBarAura", "CAST_TITLE", "CAST_FIRST_RUN_DETAILED", db)
  end
  
  local yOffset = -10
  
  -- Important note at top
  local noteText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  noteText:SetPoint("TOPLEFT", 10, yOffset)
  noteText:SetWidth(340)
  noteText:SetJustifyH("LEFT")
  noteText:SetText("|cffFFFF00Note:|r Enable |cff00FF00Advanced Combat Logging|r in WoW Settings |cffAAAAAA(Esc > Options > Network)|r")
  yOffset = yOffset - 28
  
  -- ===== RIGHT SIDE: BAR APPEARANCE (compact) =====
  local rightX = 250
  local rightY = -38
  
  local appearanceHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  appearanceHeader:SetPoint("TOPLEFT", rightX, rightY)
  appearanceHeader:SetText("|cffFFD700Bar Appearance|r")
  rightY = rightY - 16
  
  -- Bar width slider (compact)
  local widthLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  widthLabel:SetPoint("TOPLEFT", rightX, rightY)
  widthLabel:SetText("Width: " .. db.barWidth)
  rightY = rightY - 14
  
  local widthSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  widthSlider:SetPoint("TOPLEFT", rightX, rightY)
  widthSlider:SetWidth(110)
  widthSlider:SetHeight(14)
  widthSlider:SetMinMaxValues(150, 400)
  widthSlider:SetValueStep(10)
  widthSlider:SetObeyStepOnDrag(true)
  widthSlider:SetValue(db.barWidth)
  widthSlider.Low:SetText("150")
  widthSlider.High:SetText("400")
  widthSlider.Low:SetFontObject("GameFontNormalSmall")
  widthSlider.High:SetFontObject("GameFontNormalSmall")
  widthSlider:SetScript("OnValueChanged", function(self, value)
    db.barWidth = math.floor(value)
    widthLabel:SetText("Width: " .. db.barWidth)
  end)
  rightY = rightY - 28
  
  -- Bar height slider (compact)
  local heightLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  heightLabel:SetPoint("TOPLEFT", rightX, rightY)
  heightLabel:SetText("Height: " .. db.barHeight)
  rightY = rightY - 14
  
  local heightSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  heightSlider:SetPoint("TOPLEFT", rightX, rightY)
  heightSlider:SetWidth(110)
  heightSlider:SetHeight(14)
  heightSlider:SetMinMaxValues(15, 50)
  heightSlider:SetValueStep(1)
  heightSlider:SetObeyStepOnDrag(true)
  heightSlider:SetValue(db.barHeight)
  heightSlider.Low:SetText("15")
  heightSlider.High:SetText("50")
  heightSlider.Low:SetFontObject("GameFontNormalSmall")
  heightSlider.High:SetFontObject("GameFontNormalSmall")
  heightSlider:SetScript("OnValueChanged", function(self, value)
    db.barHeight = math.floor(value)
    heightLabel:SetText("Height: " .. db.barHeight)
  end)
  rightY = rightY - 28
  
  -- Test button (compact)
  local testBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  testBtn:SetPoint("TOPLEFT", rightX, rightY)
  testBtn:SetSize(110, 18)
  testBtn:SetText("Test Cast")
  testBtn:GetFontString():SetFont(testBtn:GetFontString():GetFont(), 10)
  testBtn:SetScript("OnClick", function()
    if db.enabled then
      CreateCastBar("Test-0-000-000-00000001", "Test Spell", "Interface\\Icons\\Spell_Shadow_ShadowBolt", 3, GetTime())
    end
  end)
  
  -- ===== LEFT SIDE: CHECKBOXES =====
  -- Enable checkbox
  local enableCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  enableCB:SetPoint("TOPLEFT", 10, yOffset)
  enableCB.Text:SetText(L("CAST_ENABLE") or "Enable CastBar Aura")
  enableCB:SetChecked(db.enabled)
  enableCB:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
    CastBarAura:UpdateState()
  end)
  yOffset = yOffset - 26
  
  -- Show icon checkbox
  local iconCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  iconCB:SetPoint("TOPLEFT", 10, yOffset)
  iconCB.Text:SetText(L("CAST_SHOW_ICON") or "Show Spell Icon")
  iconCB:SetChecked(db.showIcon)
  iconCB:SetScript("OnClick", function(self)
    db.showIcon = self:GetChecked()
  end)
  yOffset = yOffset - 26
  
  -- Play sound checkbox
  local soundCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  soundCB:SetPoint("TOPLEFT", 10, yOffset)
  soundCB.Text:SetText(L("CAST_PLAY_SOUND") or "Play Warning Sound")
  soundCB:SetChecked(db.playSound)
  soundCB:SetScript("OnClick", function(self)
    db.playSound = self:GetChecked()
  end)
  yOffset = yOffset - 26
  
  -- Show all hostile casts checkbox
  local hostileCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  hostileCB:SetPoint("TOPLEFT", 10, yOffset)
  hostileCB.Text:SetText(L("CAST_SHOW_ALL_HOSTILE") or "Show ALL Hostile Casts")
  hostileCB:SetChecked(db.showAllHostileCasts)
  hostileCB:SetScript("OnClick", function(self)
    db.showAllHostileCasts = self:GetChecked()
  end)
  yOffset = yOffset - 26
  
  -- Lock position checkbox
  local lockCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  lockCB:SetPoint("TOPLEFT", 10, yOffset)
  lockCB.Text:SetText(L("CAST_LOCKED") or "Lock Position")
  lockCB:SetChecked(db.locked)
  lockCB:SetScript("OnClick", function(self)
    db.locked = self:GetChecked()
  end)
end

-- Initialize on load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, event, addon)
  if event == "ADDON_LOADED" and addon == "EasyLife" then
    ensureDB()
    C_Timer.After(0.5, function()
      local db = getDB()
      if db.enabled then
        CastBarAura:Enable()
      end
    end)
  end
end)

EasyLife:RegisterModule("CastBarAura", CastBarAura)
