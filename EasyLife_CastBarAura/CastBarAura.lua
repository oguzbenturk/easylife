-- EasyLife: CastBar Aura Module
-- Shows incoming spell casts on the player (like DBM alerts)
local ADDON_NAME = "CastBarAura"

local mod = {
  name = ADDON_NAME,
  enabled = false,
}

local DEFAULTS = {
  enabled = true,
  position = { point = "CENTER", x = 0, y = -150 },
  scale = 1.0,
  iconSize = 50,
  barWidth = 280,
  barHeight = 24,
  maxBars = 5,
  flashEffect = true,
}

local function ensureDB()
  EasyLife_CastBarAuraDB = EasyLife_CastBarAuraDB or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLife_CastBarAuraDB[k] == nil then
      if type(v) == "table" then
        EasyLife_CastBarAuraDB[k] = {}
        for kk, vv in pairs(v) do
          EasyLife_CastBarAuraDB[k][kk] = vv
        end
      else
        EasyLife_CastBarAuraDB[k] = v
      end
    end
  end
end

function mod:GetDB()
  return EasyLife_CastBarAuraDB
end

local playerGUID
local activeCasts = {}  -- sourceGUID -> castData
local castFrames = {}   -- reusable frame pool
local anchor
local anchorLocked = true  -- When false, anchor stays visible for positioning

-- Blacklist spells we don't want to show (instant/short attacks)
local SPELL_BLACKLIST = {
  ["Throw"] = true,
  ["Shoot"] = true,
  ["Auto Shot"] = true,
}

local function createAnchor()
  if anchor then return end
  local db = mod:GetDB()
  
  anchor = CreateFrame("Frame", "EasyLife_CastBarAnchor", UIParent, "BackdropTemplate")
  anchor:SetSize(db.barWidth + db.iconSize + 8, 30)
  anchor:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", db.position.x or 0, db.position.y or -150)
  anchor:SetFrameStrata("HIGH")
  anchor:SetMovable(true)
  anchor:EnableMouse(true)
  anchor:RegisterForDrag("LeftButton")
  anchor:SetClampedToScreen(true)
  
  anchor:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  anchor:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
  anchor:SetBackdropBorderColor(0.6, 0.2, 0.2, 1)
  
  anchor:SetScript("OnDragStart", anchor.StartMoving)
  anchor:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    local point, _, _, x, y = f:GetPoint()
    db.position.point = point
    db.position.x = x
    db.position.y = y
  end)
  
  local title = anchor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  title:SetPoint("CENTER")
  title:SetText("CastBar Anchor (drag me)")
  anchor.title = title
  
  anchor:Hide()
end

local function createCastFrame(index)
  local db = mod:GetDB()
  
  local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  f:SetSize(db.barWidth + db.iconSize + 8, db.iconSize)
  f:SetFrameStrata("HIGH")
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  f:SetBackdropColor(0, 0, 0, 0.7)
  f:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
  
  -- Spell icon
  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(db.iconSize - 4, db.iconSize - 4)
  icon:SetPoint("LEFT", 4, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.icon = icon
  
  -- Flash overlay for icon
  local flash = f:CreateTexture(nil, "OVERLAY")
  flash:SetSize(db.iconSize - 4, db.iconSize - 4)
  flash:SetPoint("CENTER", icon, "CENTER", 0, 0)
  flash:SetTexture("Interface\\Buttons\\WHITE8x8")
  flash:SetBlendMode("ADD")
  flash:SetVertexColor(1, 1, 1, 0)
  f.flash = flash
  
  -- Flash animation group
  local flashAG = flash:CreateAnimationGroup()
  flashAG:SetLooping("REPEAT")
  
  local fadeIn = flashAG:CreateAnimation("Alpha")
  fadeIn:SetFromAlpha(0)
  fadeIn:SetToAlpha(0.5)
  fadeIn:SetDuration(0.4)
  fadeIn:SetOrder(1)
  
  local fadeOut = flashAG:CreateAnimation("Alpha")
  fadeOut:SetFromAlpha(0.5)
  fadeOut:SetToAlpha(0)
  fadeOut:SetDuration(0.4)
  fadeOut:SetOrder(2)
  
  f.flashAG = flashAG
  
  -- Spell name
  local name = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -2)
  name:SetPoint("RIGHT", f, "RIGHT", -4, 0)
  name:SetJustifyH("LEFT")
  name:SetTextColor(1, 0.8, 0)
  f.name = name
  
  -- Cast bar background
  local barBg = f:CreateTexture(nil, "BACKGROUND")
  barBg:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 6, 2)
  barBg:SetSize(db.barWidth - 10, db.barHeight - 4)
  barBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
  f.barBg = barBg
  
  -- Cast bar fill
  local bar = f:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("BOTTOMLEFT", barBg, "BOTTOMLEFT", 0, 0)
  bar:SetSize(db.barWidth - 10, db.barHeight - 4)
  bar:SetColorTexture(0.8, 0.2, 0.2, 1)
  f.bar = bar
  
  -- Time text
  local timeText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  timeText:SetPoint("RIGHT", barBg, "RIGHT", -2, 0)
  f.timeText = timeText
  
  -- Caster name
  local caster = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  caster:SetPoint("LEFT", barBg, "LEFT", 2, 0)
  caster:SetTextColor(0.7, 0.7, 0.7)
  f.caster = caster
  
  f:Hide()
  return f
end

local function updateFrameBarWidth(f)
  local db = mod:GetDB()
  local totalWidth = db.iconSize + db.barWidth
  f:SetWidth(totalWidth)
  f.barBg:SetSize(db.barWidth - 10, db.barHeight - 4)
  f.bar:SetSize(db.barWidth - 10, db.barHeight - 4)
end

local function updateAllFrameWidths()
  for _, f in ipairs(castFrames) do
    updateFrameBarWidth(f)
  end
end

local function getCastFrame(index)
  if not castFrames[index] then
    castFrames[index] = createCastFrame(index)
  end
  return castFrames[index]
end

local function positionCastFrames()
  createAnchor()
  local db = mod:GetDB()
  local yOffset = 0
  local count = 0
  
  for sourceGUID, data in pairs(activeCasts) do
    count = count + 1
    if count > db.maxBars then break end
    
    local f = getCastFrame(count)
    f:ClearAllPoints()
    f:SetPoint("TOP", anchor, "BOTTOM", 0, -yOffset - 5)
    yOffset = yOffset + db.iconSize + 4
  end
end

local function updateCastFrames()
  local db = mod:GetDB()
  local now = GetTime()
  local count = 0
  
  -- Remove expired casts
  for sourceGUID, data in pairs(activeCasts) do
    if now > data.endTime then
      activeCasts[sourceGUID] = nil
    end
  end
  
  -- Update/show active casts
  for sourceGUID, data in pairs(activeCasts) do
    count = count + 1
    if count > db.maxBars then break end
    
    local f = getCastFrame(count)
    local remaining = data.endTime - now
    local elapsed = now - data.startTime
    local duration = data.endTime - data.startTime
    local progress = elapsed / duration
    
    f.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.name:SetText(data.spellName or "Unknown")
    f.caster:SetText(data.sourceName or "")
    f.timeText:SetText(string.format("%.1f", remaining))
    
    -- Flash effect
    if db.flashEffect and f.flashAG then
      if not f.flashAG:IsPlaying() then
        f.flashAG:Play()
      end
    elseif f.flashAG and f.flashAG:IsPlaying() then
      f.flashAG:Stop()
    end
    
    local barWidth = db.barWidth - 10
    f.bar:SetWidth(math.max(1, barWidth * (1 - progress)))
    
    f:ClearAllPoints()
    f:SetPoint("TOP", anchor, "BOTTOM", 0, -(count - 1) * (db.iconSize + 4) - 5)
    f:Show()
  end
  
  -- Hide unused frames
  for i = count + 1, #castFrames do
    if castFrames[i] then
      castFrames[i]:Hide()
      if castFrames[i].flashAG then
        castFrames[i].flashAG:Stop()
      end
    end
  end
  
  -- Show anchor if any casts active or if unlocked for positioning
  if count > 0 then
    anchor:Show()
    anchor.title:Hide()  -- Hide title when showing actual casts
  elseif not anchorLocked then
    anchor:Show()
    anchor.title:Show()  -- Show title when positioning
  else
    anchor:Hide()
  end
end

local function onCombatLogEvent()
  if not mod.enabled then return end
  
  local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
  
  if subevent == "SPELL_CAST_START" then
    -- In Classic, SPELL_CAST_START often has destGUID as empty or nil for targeted spells
    -- We need to check if the source is targeting us OR if we're the dest
    local isTargetingUs = false
    
    -- Direct target check
    if destGUID == playerGUID then
      isTargetingUs = true
    end
    
    -- Check if source unit is targeting us (for casts where dest isn't filled in yet)
    if not isTargetingUs and sourceGUID then
      -- Try to find the unit by GUID and check their target
      for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitGUID(unit) == sourceGUID then
          if UnitGUID(unit .. "target") == playerGUID then
            isTargetingUs = true
          end
          break
        end
      end
      -- Also check target and focus
      if UnitExists("target") and UnitGUID("target") == sourceGUID then
        if UnitGUID("targettarget") == playerGUID then
          isTargetingUs = true
        end
      end
    end
    
    if not isTargetingUs then return end
    
    -- Check blacklist
    local spellDisplayName = spellName or ""
    if SPELL_BLACKLIST[spellDisplayName] then return end
    
    -- Get spell info for icon and cast time
    local name, _, icon, castTime = GetSpellInfo(spellID)
    
    -- Default cast time if not available (1.5 sec fallback)
    local duration = (castTime and castTime > 0) and (castTime / 1000) or 1.5
    
    activeCasts[sourceGUID] = {
      spellID = spellID,
      spellName = spellName or name or "Unknown",
      icon = icon,
      sourceName = sourceName,
      sourceGUID = sourceGUID,
      startTime = GetTime(),
      endTime = GetTime() + duration,
    }
    
    positionCastFrames()
    
  elseif subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_CAST_FAILED" or 
         subevent == "SPELL_INTERRUPT" or subevent == "SPELL_CAST_STOP" then
    -- Cast finished/interrupted - only remove if it was targeting us
    if activeCasts[sourceGUID] then
      activeCasts[sourceGUID] = nil
    end
  end
end

function mod:Enable()
  if self.enabled then return end
  self.enabled = true
  playerGUID = UnitGUID("player")
  
  createAnchor()
  
  -- Register combat log
  self.eventFrame = CreateFrame("Frame")
  self.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  self.eventFrame:SetScript("OnEvent", function()
    onCombatLogEvent()
  end)
  
  -- Update ticker for smooth bar animation
  self.ticker = C_Timer.NewTicker(0.05, updateCastFrames)
  
  EasyLife:Print("CastBar Aura enabled - incoming casts will show when enemies target you")
end

function mod:Disable()
  if not self.enabled then return end
  self.enabled = false
  
  if self.ticker then
    self.ticker:Cancel()
    self.ticker = nil
  end
  
  if self.eventFrame then
    self.eventFrame:UnregisterAllEvents()
    self.eventFrame = nil
  end
  
  -- Hide all frames
  wipe(activeCasts)
  for _, f in ipairs(castFrames) do
    f:Hide()
  end
  if anchor then anchor:Hide() end
  
  EasyLife:Print("CastBar Aura disabled")
end

function mod:Toggle()
  if self.enabled then
    self:Disable()
    self:GetDB().enabled = false
  else
    self:Enable()
    self:GetDB().enabled = true
  end
end

function mod:ShowAnchor()
  createAnchor()
  anchorLocked = false
  anchor:Show()
  anchor.title:Show()
  EasyLife:Print("Anchor unlocked - drag to position, then click Lock Anchor")
end

function mod:LockAnchor()
  anchorLocked = true
  if anchor and next(activeCasts) == nil then
    anchor:Hide()
  end
  EasyLife:Print("Anchor locked")
end

function mod:ResetPosition()
  local db = self:GetDB()
  db.position = { point = "CENTER", x = 0, y = -150 }
  if anchor then
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
  end
end

function mod:BuildConfigUI(parent)
  local db = self:GetDB()
  local L = function(k) return EasyLife:L(k) end
  
  -- Enable checkbox
  local enableCB = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  enableCB:SetPoint("TOPLEFT", 16, -16)
  enableCB.Text:SetText("Enable CastBar Aura")
  enableCB:SetChecked(self.enabled)
  enableCB:SetScript("OnClick", function(self)
    mod:Toggle()
    self:SetChecked(mod.enabled)
  end)
  
  -- Show anchor button
  local showBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  showBtn:SetPoint("TOPLEFT", 16, -50)
  showBtn:SetSize(120, 24)
  showBtn:SetText("Unlock Anchor")
  showBtn:SetScript("OnClick", function()
    mod:ShowAnchor()
  end)
  
  -- Lock anchor button
  local lockBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  lockBtn:SetPoint("TOPLEFT", 145, -50)
  lockBtn:SetSize(100, 24)
  lockBtn:SetText("Lock Anchor")
  lockBtn:SetScript("OnClick", function()
    mod:LockAnchor()
  end)
  
  -- Reset position button
  local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  resetBtn:SetPoint("TOPLEFT", 255, -50)
  resetBtn:SetSize(100, 24)
  resetBtn:SetText("Reset Position")
  resetBtn:SetScript("OnClick", function()
    mod:ResetPosition()
  end)
  
  -- Scale slider
  local scaleSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  scaleSlider:SetPoint("TOPLEFT", 16, -110)
  scaleSlider:SetWidth(200)
  scaleSlider:SetMinMaxValues(0.5, 2.0)
  scaleSlider:SetValueStep(0.1)
  scaleSlider:SetObeyStepOnDrag(true)
  scaleSlider:SetValue(db.scale or 1.0)
  if scaleSlider.Text then scaleSlider.Text:SetText("Scale") end
  if scaleSlider.Low then scaleSlider.Low:SetText("0.5") end
  if scaleSlider.High then scaleSlider.High:SetText("2.0") end
  scaleSlider:SetScript("OnValueChanged", function(_, v)
    db.scale = v
    if anchor then anchor:SetScale(v) end
    for _, f in ipairs(castFrames) do
      f:SetScale(v)
    end
  end)
  
  -- Bar width slider
  local widthSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  widthSlider:SetPoint("TOPLEFT", 16, -170)
  widthSlider:SetWidth(200)
  widthSlider:SetMinMaxValues(150, 400)
  widthSlider:SetValueStep(10)
  widthSlider:SetObeyStepOnDrag(true)
  widthSlider:SetValue(db.barWidth or 280)
  if widthSlider.Text then widthSlider.Text:SetText("Bar Width") end
  if widthSlider.Low then widthSlider.Low:SetText("150") end
  if widthSlider.High then widthSlider.High:SetText("400") end
  widthSlider:SetScript("OnValueChanged", function(_, v)
    db.barWidth = v
    updateAllFrameWidths()
  end)
  
  -- Flash effect checkbox
  local flashCB = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  flashCB:SetPoint("TOPLEFT", 16, -220)
  flashCB.Text:SetText("Flash Effect on Icon")
  flashCB:SetChecked(db.flashEffect)
  flashCB:SetScript("OnClick", function(self)
    db.flashEffect = self:GetChecked()
  end)
  
  -- Info text
  local info = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  info:SetPoint("TOPLEFT", 16, -260)
  info:SetWidth(340)
  info:SetJustifyH("LEFT")
  info:SetText("Shows spell icons with countdown bars when enemies are casting spells at you. Drag the anchor to reposition.")
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, event, addon)
  if event == "ADDON_LOADED" and (addon == "EasyLife_CastBarAura" or addon == "EasyLife") then
    if EasyLife and EasyLife.RegisterModule then
      ensureDB()
      EasyLife:RegisterModule(ADDON_NAME, mod)
      
      local db = mod:GetDB()
      if db.enabled then
        C_Timer.After(0.5, function()
          mod:Enable()
        end)
      end
      initFrame:UnregisterEvent("ADDON_LOADED")
    end
  end
end)
