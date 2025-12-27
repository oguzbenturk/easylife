-- AggroAlert Module
-- Displays a big warning when you have aggro and warns when mobs are about to target you
local AggroAlert = {}
local alertFrame
local warningFrame
local updateTimer = 0
local UPDATE_INTERVAL = 0.1  -- Check every 100ms

-- Defaults
local DEFAULTS = {
  enabled = true,
  alertText = "AGGRO ON YOU!",
  fontSize = 48,
  fontColor = { r = 1, g = 0, b = 0 },  -- Red
  x = 0,
  y = 150,
  flashSpeed = 0.3,
  showWarning = true,  -- Show threat warning
  warningThreshold = 80,  -- Warn at 80% threat
  warningText = "THREAT WARNING!",
  warningFontSize = 32,
  warningColor = { r = 1, g = 0.5, b = 0 },  -- Orange
  warningX = 0,
  warningY = 100,
  playSound = true,
  soundFile = "Interface\\AddOns\\EasyLife\\Sounds\\aggro.ogg",
  locked = true,
}

local function ensureDB()
  local db = EasyLife:GetDB()
  if not db then return false end
  db.aggroAlert = db.aggroAlert or {}
  for k, v in pairs(DEFAULTS) do
    if db.aggroAlert[k] == nil then
      if type(v) == "table" then
        db.aggroAlert[k] = {}
        for k2, v2 in pairs(v) do
          db.aggroAlert[k][k2] = v2
        end
      else
        db.aggroAlert[k] = v
      end
    end
  end
  -- First-run detection
  if db.aggroAlert._firstRunShown == nil then
    db.aggroAlert._firstRunShown = false
  end
  return true
end

local function getDB()
  ensureDB()
  local db = EasyLife:GetDB()
  return db and db.aggroAlert or DEFAULTS
end

-- Flash animation for the alert text
local flashAlpha = 1
local flashDirection = -1

local function updateFlash(elapsed)
  local db = getDB()
  flashAlpha = flashAlpha + (flashDirection * elapsed / db.flashSpeed)
  
  if flashAlpha <= 0.3 then
    flashAlpha = 0.3
    flashDirection = 1
  elseif flashAlpha >= 1 then
    flashAlpha = 1
    flashDirection = -1
  end
  
  return flashAlpha
end

-- Create the main aggro alert frame
local function createAlertFrame()
  if alertFrame then return alertFrame end
  
  local db = getDB()
  
  local frame = CreateFrame("Frame", "EasyLifeAggroAlertFrame", UIParent)
  frame:SetSize(400, 100)
  frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
  frame:SetFrameStrata("HIGH")
  frame:SetMovable(true)
  frame:EnableMouse(false)
  frame:SetClampedToScreen(true)
  
  -- Alert text with shadow/outline for better visibility
  frame.text = frame:CreateFontString(nil, "OVERLAY")
  frame.text:SetPoint("CENTER")
  frame.text:SetFont("Fonts\\FRIZQT__.TTF", db.fontSize, "OUTLINE")
  frame.text:SetText(db.alertText)
  frame.text:SetTextColor(db.fontColor.r, db.fontColor.g, db.fontColor.b)
  
  -- Shadow text for better visibility
  frame.shadow = frame:CreateFontString(nil, "ARTWORK")
  frame.shadow:SetPoint("CENTER", 2, -2)
  frame.shadow:SetFont("Fonts\\FRIZQT__.TTF", db.fontSize, "OUTLINE")
  frame.shadow:SetText(db.alertText)
  frame.shadow:SetTextColor(0, 0, 0, 0.5)
  
  -- Drag functionality (only when unlocked)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    local settings = getDB()
    if not settings.locked then
      self:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    local settings = getDB()
    settings.x = x
    settings.y = y
  end)
  
  frame:Hide()
  alertFrame = frame
  return frame
end

-- Create the threat warning frame
local function createWarningFrame()
  if warningFrame then return warningFrame end
  
  local db = getDB()
  
  local frame = CreateFrame("Frame", "EasyLifeThreatWarningFrame", UIParent)
  frame:SetSize(350, 80)
  frame:SetPoint("CENTER", UIParent, "CENTER", db.warningX, db.warningY)
  frame:SetFrameStrata("HIGH")
  frame:SetMovable(true)
  frame:EnableMouse(false)
  frame:SetClampedToScreen(true)
  
  -- Warning text
  frame.text = frame:CreateFontString(nil, "OVERLAY")
  frame.text:SetPoint("CENTER")
  frame.text:SetFont("Fonts\\FRIZQT__.TTF", db.warningFontSize, "OUTLINE")
  frame.text:SetText(db.warningText)
  frame.text:SetTextColor(db.warningColor.r, db.warningColor.g, db.warningColor.b)
  
  -- Shadow
  frame.shadow = frame:CreateFontString(nil, "ARTWORK")
  frame.shadow:SetPoint("CENTER", 2, -2)
  frame.shadow:SetFont("Fonts\\FRIZQT__.TTF", db.warningFontSize, "OUTLINE")
  frame.shadow:SetText(db.warningText)
  frame.shadow:SetTextColor(0, 0, 0, 0.5)
  
  -- Mob name display
  frame.mobName = frame:CreateFontString(nil, "OVERLAY")
  frame.mobName:SetPoint("TOP", frame.text, "BOTTOM", 0, -5)
  frame.mobName:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
  frame.mobName:SetTextColor(1, 1, 1)
  
  -- Drag functionality
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    local settings = getDB()
    if not settings.locked then
      self:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    local settings = getDB()
    settings.warningX = x
    settings.warningY = y
  end)
  
  frame:Hide()
  warningFrame = frame
  return frame
end

-- Show the aggro alert
local function showAggroAlert()
  if not alertFrame then createAlertFrame() end
  
  local db = getDB()
  if not db.enabled then return end
  
  alertFrame:Show()
  
  -- Play sound
  if db.playSound and db.soundFile then
    PlaySoundFile(db.soundFile, "Master")
  end
end

-- Hide the aggro alert
local function hideAggroAlert()
  if alertFrame then
    alertFrame:Hide()
  end
end

-- Show threat warning with mob name
local function showThreatWarning(mobName, threatPercent)
  if not warningFrame then createWarningFrame() end
  
  local db = getDB()
  if not db.enabled or not db.showWarning then return end
  
  warningFrame:Show()
  if mobName then
    warningFrame.mobName:SetText(mobName .. " - " .. math.floor(threatPercent) .. "% threat")
  end
end

-- Hide threat warning
local function hideThreatWarning()
  if warningFrame then
    warningFrame:Hide()
  end
end

-- Check if player has aggro on current target
local function checkTargetAggro()
  if not UnitExists("target") or not UnitCanAttack("player", "target") then
    return false, nil
  end
  
  -- Check if target is targeting the player
  if UnitIsUnit("targettarget", "player") then
    return true, UnitName("target")
  end
  
  return false, nil
end

-- Check threat on all nameplates/nearby enemies
local function checkNearbyThreats()
  local db = getDB()
  local highestThreat = 0
  local highestThreatMob = nil
  
  -- Check target's threat if we have one
  if UnitExists("target") and UnitCanAttack("player", "target") then
    local isTanking, status, scaledPercent, rawPercent = UnitDetailedThreatSituation("player", "target")
    
    if scaledPercent then
      -- isTanking = true means we have aggro
      if isTanking then
        return true, UnitName("target"), 100
      elseif scaledPercent >= db.warningThreshold then
        highestThreat = scaledPercent
        highestThreatMob = UnitName("target")
      end
    end
  end
  
  -- Also check nameplates for mobs that might be targeting us
  for i = 1, 40 do
    local unit = "nameplate" .. i
    if UnitExists(unit) and UnitCanAttack("player", unit) then
      local isTanking, status, scaledPercent, rawPercent = UnitDetailedThreatSituation("player", unit)
      
      if isTanking then
        return true, UnitName(unit), 100
      elseif scaledPercent and scaledPercent > highestThreat and scaledPercent >= db.warningThreshold then
        highestThreat = scaledPercent
        highestThreatMob = UnitName(unit)
      end
    end
  end
  
  -- Check if any mob is targeting us via target-of-target
  if UnitExists("targettarget") and UnitIsUnit("targettarget", "player") then
    local targetName = UnitName("target")
    if UnitCanAttack("player", "target") then
      return true, targetName, 100
    end
  end
  
  return false, highestThreatMob, highestThreat
end

-- Main update function
local hasAggro = false
local hasWarning = false
local lastSoundTime = 0

local function onUpdate(self, elapsed)
  local db = getDB()
  if not db.enabled then
    hideAggroAlert()
    hideThreatWarning()
    return
  end
  
  updateTimer = updateTimer + elapsed
  if updateTimer < UPDATE_INTERVAL then return end
  updateTimer = 0
  
  -- Check for aggro and threats
  local aggro, aggroMob, threatPercent = checkNearbyThreats()
  
  if aggro then
    -- We have aggro!
    if not hasAggro then
      hasAggro = true
      showAggroAlert()
      hideThreatWarning()  -- Hide warning when we have full aggro
      
      -- Play sound (with cooldown)
      local now = GetTime()
      if db.playSound and (now - lastSoundTime) > 2 then
        lastSoundTime = now
        -- Use built-in sound if custom not available
        PlaySound(8959, "Master")  -- RAID WARNING sound
      end
    end
    
    -- Update flash
    if alertFrame and alertFrame:IsShown() then
      local alpha = updateFlash(elapsed)
      alertFrame.text:SetAlpha(alpha)
    end
  else
    -- No aggro
    if hasAggro then
      hasAggro = false
      hideAggroAlert()
    end
    
    -- Check for high threat warning
    if aggroMob and threatPercent >= db.warningThreshold then
      if not hasWarning then
        hasWarning = true
        showThreatWarning(aggroMob, threatPercent)
      else
        -- Update the mob name and threat
        if warningFrame and warningFrame:IsShown() then
          warningFrame.mobName:SetText(aggroMob .. " - " .. math.floor(threatPercent) .. "% threat")
        end
      end
      
      -- Flash the warning too
      if warningFrame and warningFrame:IsShown() then
        local alpha = updateFlash(elapsed)
        warningFrame.text:SetAlpha(alpha)
      end
    else
      if hasWarning then
        hasWarning = false
        hideThreatWarning()
      end
    end
  end
end

-- Create event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Entered combat
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Left combat
eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")

local inCombat = false

-- Update module state (called when enabling/disabling from Module Manager)
function AggroAlert:UpdateState()
  local db = getDB()
  
  if not db.enabled then
    -- Disable: hide alerts and unregister combat events
    hideAggroAlert()
    hideThreatWarning()
    hasAggro = false
    hasWarning = false
    eventFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    eventFrame:UnregisterEvent("UNIT_THREAT_LIST_UPDATE")
    eventFrame:SetScript("OnUpdate", nil)
  else
    -- Enable: register combat events
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
  end
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
  local db = getDB()
  
  if event == "PLAYER_ENTERING_WORLD" then
    ensureDB()
    createAlertFrame()
    createWarningFrame()
    hideAggroAlert()
    hideThreatWarning()
    
  elseif event == "PLAYER_REGEN_DISABLED" then
    if not db.enabled then return end
    -- Entered combat
    inCombat = true
    eventFrame:SetScript("OnUpdate", onUpdate)
    
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Left combat
    inCombat = false
    hasAggro = false
    hasWarning = false
    hideAggroAlert()
    hideThreatWarning()
    eventFrame:SetScript("OnUpdate", nil)
    
  elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
    -- Threat changed, the OnUpdate will handle it
  end
end)

-- Update display settings
local function updateDisplaySettings()
  local db = getDB()
  
  if alertFrame then
    alertFrame:ClearAllPoints()
    alertFrame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    alertFrame.text:SetFont("Fonts\\FRIZQT__.TTF", db.fontSize, "OUTLINE")
    alertFrame.text:SetText(db.alertText)
    alertFrame.text:SetTextColor(db.fontColor.r, db.fontColor.g, db.fontColor.b)
    alertFrame.shadow:SetFont("Fonts\\FRIZQT__.TTF", db.fontSize, "OUTLINE")
    alertFrame.shadow:SetText(db.alertText)
    alertFrame:EnableMouse(not db.locked)
  end
  
  if warningFrame then
    warningFrame:ClearAllPoints()
    warningFrame:SetPoint("CENTER", UIParent, "CENTER", db.warningX, db.warningY)
    warningFrame.text:SetFont("Fonts\\FRIZQT__.TTF", db.warningFontSize, "OUTLINE")
    warningFrame.text:SetText(db.warningText)
    warningFrame.text:SetTextColor(db.warningColor.r, db.warningColor.g, db.warningColor.b)
    warningFrame.shadow:SetFont("Fonts\\FRIZQT__.TTF", db.warningFontSize, "OUTLINE")
    warningFrame.shadow:SetText(db.warningText)
    warningFrame:EnableMouse(not db.locked)
  end
end

-- Config UI builder
function AggroAlert:BuildConfigUI(parent)
  local db = getDB()
  local yOffset = -15
  
  -- Show first-run popup if needed
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("AggroAlert", "AGGRO_TITLE", "AGGRO_FIRST_RUN_DETAILED", db)
  end
  
  -- Title
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 15, yOffset)
  title:SetText("|cffFF0000Aggro Alert|r")
  yOffset = yOffset - 30
  
  -- Enable checkbox
  local enableCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  enableCB:SetPoint("TOPLEFT", 15, yOffset)
  enableCB:SetChecked(db.enabled)
  enableCB.Text:SetText("Enable Aggro Alert")
  enableCB:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
    if not db.enabled then
      hideAggroAlert()
      hideThreatWarning()
    end
  end)
  yOffset = yOffset - 30
  
  -- Lock position checkbox
  local lockCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  lockCB:SetPoint("TOPLEFT", 15, yOffset)
  lockCB:SetChecked(db.locked)
  lockCB.Text:SetText("Lock Position")
  lockCB:SetScript("OnClick", function(self)
    db.locked = self:GetChecked()
    updateDisplaySettings()
  end)
  yOffset = yOffset - 30
  
  -- Alert Text input
  local alertLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  alertLabel:SetPoint("TOPLEFT", 15, yOffset)
  alertLabel:SetText("Alert Text:")
  
  local alertInput = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  alertInput:SetSize(150, 20)
  alertInput:SetPoint("LEFT", alertLabel, "RIGHT", 10, 0)
  alertInput:SetAutoFocus(false)
  alertInput:SetText(db.alertText)
  alertInput:SetScript("OnEnterPressed", function(self)
    db.alertText = self:GetText()
    updateDisplaySettings()
    self:ClearFocus()
  end)
  yOffset = yOffset - 30
  
  -- Font size slider
  local fontSizeLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fontSizeLabel:SetPoint("TOPLEFT", 15, yOffset)
  fontSizeLabel:SetText("Font Size: " .. db.fontSize)
  
  local fontSizeSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  fontSizeSlider:SetPoint("LEFT", fontSizeLabel, "RIGHT", 20, 0)
  fontSizeSlider:SetSize(150, 20)
  fontSizeSlider:SetMinMaxValues(20, 100)
  fontSizeSlider:SetValue(db.fontSize)
  fontSizeSlider:SetValueStep(2)
  fontSizeSlider:SetObeyStepOnDrag(true)
  fontSizeSlider.Low:SetText("20")
  fontSizeSlider.High:SetText("100")
  fontSizeSlider:SetScript("OnValueChanged", function(self, value)
    db.fontSize = value
    fontSizeLabel:SetText("Font Size: " .. math.floor(value))
    updateDisplaySettings()
  end)
  yOffset = yOffset - 40
  
  -- Warning threshold slider
  local warnLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  warnLabel:SetPoint("TOPLEFT", 15, yOffset)
  warnLabel:SetText("Warning Threshold: " .. db.warningThreshold .. "%")
  
  local warnSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  warnSlider:SetPoint("LEFT", warnLabel, "RIGHT", 20, 0)
  warnSlider:SetSize(120, 20)
  warnSlider:SetMinMaxValues(50, 99)
  warnSlider:SetValue(db.warningThreshold)
  warnSlider:SetValueStep(5)
  warnSlider:SetObeyStepOnDrag(true)
  warnSlider.Low:SetText("50%")
  warnSlider.High:SetText("99%")
  warnSlider:SetScript("OnValueChanged", function(self, value)
    db.warningThreshold = value
    warnLabel:SetText("Warning Threshold: " .. math.floor(value) .. "%")
  end)
  yOffset = yOffset - 40
  
  -- Show warning checkbox
  local warnCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  warnCB:SetPoint("TOPLEFT", 15, yOffset)
  warnCB:SetChecked(db.showWarning)
  warnCB.Text:SetText("Show Threat Warning")
  warnCB:SetScript("OnClick", function(self)
    db.showWarning = self:GetChecked()
  end)
  yOffset = yOffset - 30
  
  -- Play sound checkbox
  local soundCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  soundCB:SetPoint("TOPLEFT", 15, yOffset)
  soundCB:SetChecked(db.playSound)
  soundCB.Text:SetText("Play Sound on Aggro")
  soundCB:SetScript("OnClick", function(self)
    db.playSound = self:GetChecked()
  end)
  yOffset = yOffset - 35
  
  -- Test button
  local testBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  testBtn:SetSize(100, 25)
  testBtn:SetPoint("TOPLEFT", 15, yOffset)
  testBtn:SetText("Test Alert")
  testBtn:SetScript("OnClick", function()
    showAggroAlert()
    C_Timer.After(3, function()
      hideAggroAlert()
    end)
  end)
  
  -- Test warning button
  local testWarnBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  testWarnBtn:SetSize(120, 25)
  testWarnBtn:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
  testWarnBtn:SetText("Test Warning")
  testWarnBtn:SetScript("OnClick", function()
    showThreatWarning("Test Mob", 85)
    C_Timer.After(3, function()
      hideThreatWarning()
    end)
  end)
  yOffset = yOffset - 35
  
  -- Reset position button
  local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  resetBtn:SetSize(120, 25)
  resetBtn:SetPoint("TOPLEFT", 15, yOffset)
  resetBtn:SetText("Reset Positions")
  resetBtn:SetScript("OnClick", function()
    db.x = DEFAULTS.x
    db.y = DEFAULTS.y
    db.warningX = DEFAULTS.warningX
    db.warningY = DEFAULTS.warningY
    updateDisplaySettings()
    EasyLife:Print("Aggro Alert positions reset!", "AggroAlert")
  end)
end

-- Register module
EasyLife:RegisterModule("AggroAlert", AggroAlert)
