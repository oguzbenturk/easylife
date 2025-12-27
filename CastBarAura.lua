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
    
    -- Flash when almost done
    if remaining < 1 then
      local alpha = 0.5 + 0.5 * math.sin(now * 10)
      self:SetAlpha(alpha)
    end
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

local function OnCombatLogEvent()
  local db = getDB()
  if not db.enabled then return end
  
  local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
        destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
  
  -- Check if spell is targeting the player
  local playerGUID = UnitGUID("player")
  if destGUID ~= playerGUID then return end
  
  if subevent == "SPELL_CAST_START" then
    local spellId, spellName = select(12, CombatLogGetCurrentEventInfo())
    local spellIcon = GetSpellTexture(spellId)
    
    -- Get cast time from the caster unit
    local castTime = 3  -- Default fallback
    for i = 1, 40 do
      local unit = "nameplate" .. i
      if UnitExists(unit) and UnitGUID(unit) == sourceGUID then
        local name, _, _, startTimeMs, endTimeMs = UnitCastingInfo(unit)
        if endTimeMs and startTimeMs then
          castTime = (endTimeMs - startTimeMs) / 1000
        end
        break
      end
    end
    
    CreateCastBar(sourceGUID, spellName, spellIcon, castTime, GetTime())
    
  elseif subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_CAST_FAILED" 
      or subevent == "SPELL_INTERRUPT" then
    CastBarAura:RemoveCast(sourceGUID)
  end
end

function CastBarAura:Enable()
  if not eventFrame then
    eventFrame = CreateFrame("Frame")
  end
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
  
  -- Enable checkbox
  local enableCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  enableCB:SetPoint("TOPLEFT", 10, yOffset)
  enableCB.Text:SetText(L("CAST_ENABLE") or "Enable CastBar Aura")
  enableCB:SetChecked(db.enabled)
  enableCB:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
    CastBarAura:UpdateState()
  end)
  yOffset = yOffset - 30
  
  -- Show icon checkbox
  local iconCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  iconCB:SetPoint("TOPLEFT", 10, yOffset)
  iconCB.Text:SetText(L("CAST_SHOW_ICON") or "Show Spell Icon")
  iconCB:SetChecked(db.showIcon)
  iconCB:SetScript("OnClick", function(self)
    db.showIcon = self:GetChecked()
  end)
  yOffset = yOffset - 30
  
  -- Play sound checkbox
  local soundCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  soundCB:SetPoint("TOPLEFT", 10, yOffset)
  soundCB.Text:SetText(L("CAST_PLAY_SOUND") or "Play Warning Sound")
  soundCB:SetChecked(db.playSound)
  soundCB:SetScript("OnClick", function(self)
    db.playSound = self:GetChecked()
  end)
  yOffset = yOffset - 30
  
  -- Lock position checkbox
  local lockCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  lockCB:SetPoint("TOPLEFT", 10, yOffset)
  lockCB.Text:SetText(L("CAST_LOCKED") or "Lock Position")
  lockCB:SetChecked(db.locked)
  lockCB:SetScript("OnClick", function(self)
    db.locked = self:GetChecked()
  end)
  yOffset = yOffset - 30
  
  -- Bar width slider
  local widthLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  widthLabel:SetPoint("TOPLEFT", 10, yOffset)
  widthLabel:SetText((L("CAST_BAR_WIDTH") or "Bar Width") .. ": " .. db.barWidth)
  yOffset = yOffset - 20
  
  local widthSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  widthSlider:SetPoint("TOPLEFT", 15, yOffset)
  widthSlider:SetWidth(200)
  widthSlider:SetMinMaxValues(150, 400)
  widthSlider:SetValueStep(10)
  widthSlider:SetObeyStepOnDrag(true)
  widthSlider:SetValue(db.barWidth)
  widthSlider.Low:SetText("150")
  widthSlider.High:SetText("400")
  widthSlider:SetScript("OnValueChanged", function(self, value)
    db.barWidth = math.floor(value)
    widthLabel:SetText((L("CAST_BAR_WIDTH") or "Bar Width") .. ": " .. db.barWidth)
  end)
  yOffset = yOffset - 40
  
  -- Reset position button
  local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  resetBtn:SetPoint("TOPLEFT", 10, yOffset)
  resetBtn:SetSize(120, 24)
  resetBtn:SetText(L("CAST_RESET") or "Reset Position")
  resetBtn:SetScript("OnClick", function()
    db.x = DEFAULTS.x
    db.y = DEFAULTS.y
    if displayFrame then
      displayFrame:ClearAllPoints()
      displayFrame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    end
  end)
  yOffset = yOffset - 40
  
  -- Test button
  local testBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  testBtn:SetPoint("TOPLEFT", 140, yOffset + 40)
  testBtn:SetSize(100, 24)
  testBtn:SetText(L("CAST_TEST") or "Test Cast")
  testBtn:SetScript("OnClick", function()
    if db.enabled then
      CreateCastBar("Test-0-000-000-00000001", "Test Spell", "Interface\\Icons\\Spell_Shadow_ShadowBolt", 3, GetTime())
    end
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
