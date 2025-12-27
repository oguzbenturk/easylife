-- RangeIndicator Module
-- Shows distance to closest mob and current target
local RangeIndicator = {}

local displayFrame
local updateTicker

local DEFAULTS = {
  enabled = true,
  updateMs = 50,  -- Update every 50ms (very fast)
  size = 1.0,
  point = "CENTER",
  relativePoint = "CENTER",
  x = 0,
  y = -200,
  locked = false,  -- Start unlocked so user can position it
  showClosestMob = true,
  showTarget = true,
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

-- Calculate distance to a unit (yards)
local function GetDistanceToUnit(unit)
  if not unit or not UnitExists(unit) then return nil end
  
  local playerY, playerX, _, playerInstance = UnitPosition("player")
  local unitY, unitX, _, unitInstance = UnitPosition(unit)
  
  if not playerX or not unitX then return nil end
  if playerInstance ~= unitInstance then return nil end
  
  local dx = playerX - unitX
  local dy = playerY - unitY
  return math.sqrt(dx * dx + dy * dy)
end

-- Find closest hostile mob
local function GetClosestMob()
  local closestUnit = nil
  local closestDist = math.huge
  
  -- Check nameplates for hostile units
  for i = 1, 40 do
    local unit = "nameplate" .. i
    if UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsDead(unit) then
      local dist = GetDistanceToUnit(unit)
      if dist and dist < closestDist then
        closestDist = dist
        closestUnit = unit
      end
    end
  end
  
  return closestUnit, closestDist
end

local function CreateDisplayFrame()
  if displayFrame then return displayFrame end
  
  local db = getDB()
  
  displayFrame = CreateFrame("Frame", "EasyLifeRangeIndicator", UIParent, "BackdropTemplate")
  displayFrame:SetSize(180, 60)
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
  displayFrame.title:SetText("|cff00CED1Range Indicator|r")
  
  -- Closest mob line
  displayFrame.closestLabel = displayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  displayFrame.closestLabel:SetPoint("TOPLEFT", 10, -22)
  displayFrame.closestLabel:SetText("Closest:")
  
  displayFrame.closestValue = displayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  displayFrame.closestValue:SetPoint("TOPRIGHT", -10, -22)
  displayFrame.closestValue:SetText("--")
  
  -- Target line
  displayFrame.targetLabel = displayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  displayFrame.targetLabel:SetPoint("TOPLEFT", 10, -38)
  displayFrame.targetLabel:SetText("Target:")
  
  displayFrame.targetValue = displayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  displayFrame.targetValue:SetPoint("TOPRIGHT", -10, -38)
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
  
  local db = getDB()
  
  -- Update closest mob
  if db.showClosestMob then
    local closestUnit, closestDist = GetClosestMob()
    if closestUnit and closestDist < math.huge then
      local name = UnitName(closestUnit) or "Unknown"
      displayFrame.closestValue:SetText("|cff00FF00" .. string.format("%.1f yd|r", closestDist))
      displayFrame.closestLabel:SetText("Closest: |cffFFFFFF" .. (string.sub(name, 1, 10)) .. "|r")
    else
      displayFrame.closestValue:SetText("|cff888888--|r")
      displayFrame.closestLabel:SetText("Closest:")
    end
  end
  
  -- Update target distance
  if db.showTarget then
    if UnitExists("target") then
      local dist = GetDistanceToUnit("target")
      if dist then
        local color = UnitCanAttack("player", "target") and "|cffFFFF00" or "|cff00FF00"
        displayFrame.targetValue:SetText(color .. string.format("%.1f yd|r", dist))
      else
        displayFrame.targetValue:SetText("|cff888888?|r")
      end
    else
      displayFrame.targetValue:SetText("|cff888888--|r")
    end
  end
end

local function StopUpdating()
  if updateTicker then
    updateTicker:Cancel()
    updateTicker = nil
  end
end

local function StartUpdating()
  if updateTicker then return end
  
  local db = getDB()
  local updateRate = (db.updateMs or 50) / 1000  -- Convert ms to seconds
  updateTicker = C_Timer.NewTicker(updateRate, UpdateDisplay)
end

-- Restart ticker with new update rate
function RangeIndicator:RestartTicker()
  StopUpdating()
  local db = getDB()
  if db.enabled then
    StartUpdating()
  end
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
  
  -- Show closest mob checkbox
  local closestCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  closestCB:SetPoint("TOPLEFT", 10, yOffset)
  closestCB.Text:SetText(L("RANGE_SHOW_CLOSEST") or "Show Closest Mob")
  closestCB:SetChecked(db.showClosestMob)
  closestCB:SetScript("OnClick", function(self)
    db.showClosestMob = self:GetChecked()
  end)
  yOffset = yOffset - 30
  
  -- Show target checkbox
  local targetCB = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  targetCB:SetPoint("TOPLEFT", 10, yOffset)
  targetCB.Text:SetText(L("RANGE_SHOW_TARGET") or "Show Target Distance")
  targetCB:SetChecked(db.showTarget)
  targetCB:SetScript("OnClick", function(self)
    db.showTarget = self:GetChecked()
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
  
  -- Update rate slider (in milliseconds)
  local updateLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  updateLabel:SetPoint("TOPLEFT", 10, yOffset)
  updateLabel:SetText((L("RANGE_UPDATE_MS") or "Update Rate") .. ": " .. db.updateMs .. " ms")
  yOffset = yOffset - 20
  
  local updateSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  updateSlider:SetPoint("TOPLEFT", 15, yOffset)
  updateSlider:SetWidth(200)
  updateSlider:SetMinMaxValues(20, 500)
  updateSlider:SetValueStep(10)
  updateSlider:SetObeyStepOnDrag(true)
  updateSlider:SetValue(db.updateMs)
  updateSlider.Low:SetText("20ms")
  updateSlider.High:SetText("500ms")
  updateSlider:SetScript("OnValueChanged", function(self, value)
    db.updateMs = math.floor(value)
    updateLabel:SetText((L("RANGE_UPDATE_MS") or "Update Rate") .. ": " .. db.updateMs .. " ms")
    RangeIndicator:RestartTicker()
  end)
  yOffset = yOffset - 40
  
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
        RangeIndicator:Enable()
      end
    end)
  end
end)

EasyLife:RegisterModule("RangeIndicator", RangeIndicator)
