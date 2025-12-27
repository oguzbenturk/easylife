-- RangeIndicator Module
-- Shows distance to closest mob and current target
-- Uses spell/item range checks like LibRangeCheck-3.0 (the proper Classic Era method)
local RangeIndicator = {}

local displayFrame

local DEFAULTS = {
  enabled = true,
  size = 1.0,
  point = "CENTER",
  relativePoint = "CENTER",
  x = 0,
  y = -200,
  locked = false,  -- Start unlocked so user can position it
}

local function ensureDB()
  EasyLifeDB = EasyLifeDB or {}
  EasyLifeDB.rangeIndicator = EasyLifeDB.rangeIndicator or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.rangeIndicator[k] == nil then
      EasyLifeDB.rangeIndicator[k] = v
    end
  end
  if EasyLifeDB.rangeIndicator._firstRunShown == nil then
    EasyLifeDB.rangeIndicator._firstRunShown = false
  end
  return true
end

local function getDB()
  ensureDB()
  return EasyLifeDB.rangeIndicator
end

local function L(key)
  return EasyLife:L(key)
end

-- ============================================================================
-- RANGE CHECKING SYSTEM
-- Uses spell range checks + CheckInteractDistance() for precise ranges
-- Automatically detects your actual spell ranges (including talents!)
-- UnitPosition() is restricted by Blizzard for enemy units
-- ============================================================================

-- Spell IDs by class - we'll read actual range from spellbook (talents included)
local CLASS_HARM_SPELLS = {
  MAGE = {
    133,   -- Fireball
    116,   -- Frostbolt
    5019,  -- Shoot (wand)
    118,   -- Polymorph
    2136,  -- Fire Blast
    120,   -- Cone of Cold
    122,   -- Frost Nova
    2948,  -- Scorch
  },
  WARLOCK = {
    686,   -- Shadow Bolt
    172,   -- Corruption
    348,   -- Immolate
    5019,  -- Shoot (wand)
    5782,  -- Fear
    689,   -- Drain Life
    1120,  -- Drain Soul
    6353,  -- Soul Fire
    17962, -- Conflagrate
  },
  PRIEST = {
    589,   -- Shadow Word: Pain
    585,   -- Smite
    5019,  -- Shoot (wand)
    8092,  -- Mind Blast
    15407, -- Mind Flay
    2944,  -- Devouring Plague
  },
  HUNTER = {
    75,    -- Auto Shot
    2764,  -- Throw
    3044,  -- Arcane Shot
    1978,  -- Serpent Sting
    5116,  -- Concussive Shot
    1513,  -- Scare Beast
    19434, -- Aimed Shot
  },
  DRUID = {
    5176,  -- Wrath
    8921,  -- Moonfire
    770,   -- Faerie Fire
    339,   -- Entangling Roots
    2908,  -- Soothe Animal
    16979, -- Feral Charge
  },
  PALADIN = {
    879,   -- Exorcism
    20271, -- Judgement
    853,   -- Hammer of Justice
    24275, -- Hammer of Wrath
  },
  WARRIOR = {
    355,   -- Taunt
    2764,  -- Throw
    100,   -- Charge
    5246,  -- Intimidating Shout
    6552,  -- Pummel
    1680,  -- Whirlwind
    20252, -- Intercept
  },
  ROGUE = {
    2764,  -- Throw
    1725,  -- Distract
    2094,  -- Blind
    1776,  -- Gouge
    1766,  -- Kick
    53,    -- Backstab
  },
  SHAMAN = {
    403,   -- Lightning Bolt
    8042,  -- Earth Shock
    8050,  -- Flame Shock
    8056,  -- Frost Shock
    370,   -- Purge
    421,   -- Chain Lightning
  },
}

-- Cached spell checkers for player's class
local spellCheckers = {}
local spellCheckersBuilt = false

-- Build spell checker list based on player's known spells with ACTUAL ranges
local function BuildSpellCheckers()
  if spellCheckersBuilt then return end
  
  local _, playerClass = UnitClass("player")
  local classSpells = CLASS_HARM_SPELLS[playerClass]
  
  if not classSpells then
    spellCheckersBuilt = true
    return
  end
  
  wipe(spellCheckers)
  
  -- Use a table to track unique ranges (avoid duplicates)
  local rangesSeen = {}
  
  for _, spellId in ipairs(classSpells) do
    -- GetSpellInfo returns: name, rank, icon, castTime, minRange, maxRange
    local spellName, _, _, _, minRange, maxRange = GetSpellInfo(spellId)
    if spellName and maxRange and maxRange > 0 then
      -- Check if player knows this spell
      if IsSpellKnown(spellId) then
        -- Only add if we don't already have a spell at this exact range
        if not rangesSeen[maxRange] then
          rangesSeen[maxRange] = true
          table.insert(spellCheckers, {
            name = spellName,
            range = maxRange,
            id = spellId
          })
        end
      end
    end
  end
  
  -- Sort by range (closest first for better precision)
  table.sort(spellCheckers, function(a, b) return a.range < b.range end)
  
  spellCheckersBuilt = true
end

-- Invalidate spell cache (called on talent/spell changes)
local function InvalidateSpellCache()
  spellCheckersBuilt = false
end

-- CheckInteractDistance for melee range detection
local INTERACT_CHECKS = {
  { index = 3, range = 8 },   -- Duel range ~8 yards
  { index = 2, range = 11 },  -- Trade range ~11 yards
}

-- Get range to unit using spell checks + interact distance
local function GetRangeToUnit(unit)
  if not unit or not UnitExists(unit) then return nil, nil end
  if not UnitIsVisible(unit) then return nil, nil end
  
  BuildSpellCheckers()
  
  local minRange, maxRange = nil, nil
  
  -- Only use interact distance for living hostile units (melee range detection)
  if not UnitIsDeadOrGhost(unit) and UnitCanAttack("player", unit) then
    for _, check in ipairs(INTERACT_CHECKS) do
      if CheckInteractDistance(unit, check.index) then
        maxRange = check.range
        break
      else
        minRange = check.range
      end
    end
  end
  
  -- Use spell range checks for more precision
  for _, spell in ipairs(spellCheckers) do
    local inRange = IsSpellInRange(spell.name, unit)
    if inRange == 1 then
      -- Spell is in range - target is within this range
      if not maxRange or spell.range < maxRange then
        maxRange = spell.range
      end
      break  -- Found closest range
    elseif inRange == 0 then
      -- Spell out of range - target is beyond this range
      if not minRange or spell.range > minRange then
        minRange = spell.range
      end
    end
    -- inRange == nil means spell can't be used on this target
  end
  
  return minRange, maxRange
end

-- Format range display
local function FormatRange(minRange, maxRange)
  if not minRange and not maxRange then
    return "|cff888888?|r"
  elseif maxRange and not minRange then
    return string.format("|cff00FF00<%d|r", maxRange)
  elseif minRange and not maxRange then
    return string.format("|cffFF6666%d+|r", minRange)
  else
    -- Both min and max
    if maxRange <= 10 then
      return string.format("|cffFF0000%d-%d|r", minRange or 0, maxRange)  -- Red = very close
    elseif maxRange <= 20 then
      return string.format("|cffFFFF00%d-%d|r", minRange or 0, maxRange)  -- Yellow = medium
    else
      return string.format("|cff00FF00%d-%d|r", minRange or 0, maxRange)  -- Green = far
    end
  end
end



local function CreateDisplayFrame()
  if displayFrame then return displayFrame end
  
  local db = getDB()
  
  displayFrame = CreateFrame("Frame", "EasyLifeRangeIndicator", UIParent, "BackdropTemplate")
  displayFrame:SetSize(140, 45)
  displayFrame:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.x, db.y)
  displayFrame:SetFrameStrata("HIGH")
  displayFrame:SetMovable(true)
  displayFrame:EnableMouse(true)
  displayFrame:RegisterForDrag("LeftButton")
  displayFrame:SetClampedToScreen(true)
  
  displayFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  displayFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
  displayFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  
  -- Title
  displayFrame.title = displayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  displayFrame.title:SetPoint("TOP", 0, -6)
  displayFrame.title:SetText("|cff00CED1Range|r")
  
  -- Target line
  displayFrame.targetLabel = displayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  displayFrame.targetLabel:SetPoint("TOPLEFT", 10, -22)
  displayFrame.targetLabel:SetText("Target:")
  
  displayFrame.targetValue = displayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  displayFrame.targetValue:SetPoint("TOPRIGHT", -10, -22)
  displayFrame.targetValue:SetText("--")
  
  -- Drag handlers
  displayFrame:SetScript("OnDragStart", function(self)
    local db = getDB()
    if not db.locked then
      self:StartMoving()
    end
  end)
  
  displayFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local db = getDB()
    local point, relativeTo, relativePoint, x, y = self:GetPoint()
    db.x = x
    db.y = y
    db.point = point
    db.relativePoint = relativePoint
  end)
  
  -- Right-click to toggle lock
  displayFrame:SetScript("OnMouseDown", function(self, button)
    if button == "RightButton" then
      local db = getDB()
      db.locked = not db.locked
      if db.locked then
        EasyLife:Print("|cff00FF00Range Indicator locked|r", "RangeIndicator")
      else
        EasyLife:Print("|cffFFFF00Range Indicator unlocked - drag to move|r", "RangeIndicator")
      end
    end
  end)
  
  return displayFrame
end

local function UpdateDisplay()
  if not displayFrame or not displayFrame:IsShown() then return end
  
  -- Update target distance
  if UnitExists("target") then
    local minRange, maxRange = GetRangeToUnit("target")
    displayFrame.targetValue:SetText(FormatRange(minRange, maxRange) .. " yd")
  else
    displayFrame.targetValue:SetText("|cff888888--|r")
  end
end

local function StopUpdating()
  if displayFrame then
    displayFrame:SetScript("OnUpdate", nil)
  end
end

local updateElapsed = 0
local UPDATE_INTERVAL = 0.1  -- Update 10 times per second (smooth enough)

local function StartUpdating()
  if not displayFrame then return end
  
  updateElapsed = 0
  displayFrame:SetScript("OnUpdate", function(self, elapsed)
    updateElapsed = updateElapsed + elapsed
    if updateElapsed >= UPDATE_INTERVAL then
      updateElapsed = 0
      UpdateDisplay()
    end
  end)
end

function RangeIndicator:Enable()
  local frame = CreateDisplayFrame()
  frame:Show()
  StartUpdating()
end

function RangeIndicator:Disable()
  StopUpdating()
  if displayFrame then
    displayFrame:Hide()
  end
end

function RangeIndicator:UpdateState()
  local db = getDB()
  if db.enabled then
    self:Enable()
  else
    self:Disable()
  end
end

function RangeIndicator:CleanupUI()
  self:Disable()
end

function RangeIndicator:BuildConfigUI(parent)
  local db = getDB()
  
  -- First-run popup
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("RangeIndicator", "RANGE_TITLE", "RANGE_FIRST_RUN_DETAILED", db)
  end
  
  local yOffset = -10
  
  -- Enable checkbox
  local enableCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  enableCB:SetPoint("TOPLEFT", 10, yOffset)
  enableCB.Text:SetText(L("RANGE_ENABLE") or "Enable Range Indicator")
  enableCB:SetChecked(db.enabled)
  enableCB:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
    RangeIndicator:UpdateState()
  end)
  yOffset = yOffset - 30
  
  -- Lock position checkbox
  local lockCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  lockCB:SetPoint("TOPLEFT", 10, yOffset)
  lockCB.Text:SetText(L("RANGE_LOCKED") or "Lock Position")
  lockCB:SetChecked(db.locked)
  lockCB:SetScript("OnClick", function(self)
    db.locked = self:GetChecked()
  end)
  yOffset = yOffset - 30
  
  -- Reset position button
  local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  resetBtn:SetPoint("TOPLEFT", 10, yOffset)
  resetBtn:SetSize(120, 24)
  resetBtn:SetText(L("RANGE_RESET") or "Reset Position")
  resetBtn:SetScript("OnClick", function()
    db.x = DEFAULTS.x
    db.y = DEFAULTS.y
    db.point = DEFAULTS.point
    db.relativePoint = DEFAULTS.relativePoint
    if displayFrame then
      displayFrame:ClearAllPoints()
      displayFrame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    end
  end)
  yOffset = yOffset - 40
  
  -- Info text explaining range detection
  local infoText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  infoText:SetPoint("TOPLEFT", 10, yOffset)
  infoText:SetWidth(280)
  infoText:SetJustifyH("LEFT")
  infoText:SetText("|cff888888Uses your class spells for range detection.\nRanges shown as brackets (e.g. 20-30 yd).\nRight-click to lock/unlock position.|r")
end

-- Initialize on load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("SPELLS_CHANGED")
initFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
initFrame:SetScript("OnEvent", function(_, event, addon)
  if event == "ADDON_LOADED" and addon == "EasyLife" then
    ensureDB()
    C_Timer.After(0.5, function()
      local db = getDB()
      if db.enabled then
        RangeIndicator:Enable()
      end
    end)
  elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
    -- Rebuild spell checkers when spells change
    InvalidateSpellCache()
  end
end)

EasyLife:RegisterModule("RangeIndicator", RangeIndicator)
