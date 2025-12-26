-- EasyLife: Range Indicator Module
local ADDON_NAME = "RangeIndicator"

local mod = {
  name = ADDON_NAME,
  enabled = false,
  ticker = nil,
}

-- Saved vars defaults
local DEFAULTS = {
  enabled = true,
  updateRate = 0.05,  -- Near real-time by default
  fontScale = 1.0,
  position = { point = "CENTER", x = 0, y = 200 },
}

local displayFrame, displayText
local tracked = {}

local function ensureDB()
  EasyLife_RangeIndicatorDB = EasyLife_RangeIndicatorDB or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLife_RangeIndicatorDB[k] == nil then
      if type(v) == "table" then
        EasyLife_RangeIndicatorDB[k] = {}
        for kk, vv in pairs(v) do
          EasyLife_RangeIndicatorDB[k][kk] = vv
        end
      else
        EasyLife_RangeIndicatorDB[k] = v
      end
    end
  end
end

function mod:GetDB()
  return EasyLife_RangeIndicatorDB
end

local LRC = LibStub and LibStub:GetLibrary("LibRangeCheck-3.0", true)

local function bucketLabel(distance)
  if not distance then return "?" end
  return tostring(distance)
end

local function estimateRange(unit)
  if not UnitExists(unit) then return nil end
  if UnitIsDeadOrGhost(unit) then return nil end
  
  -- Use LibRangeCheck if available
  if LRC and LRC.GetRange then
    local minRange, maxRange = LRC:GetRange(unit)
    if maxRange then
      return maxRange
    elseif minRange and minRange > 0 then
      return minRange  -- Return min if we know they're at least this far
    end
  end
  
  -- Fallback to CheckInteractDistance
  if CheckInteractDistance(unit, 1) then return 10 end
  if CheckInteractDistance(unit, 2) then return 11 end
  if CheckInteractDistance(unit, 3) then return 10 end
  if CheckInteractDistance(unit, 4) then return 28 end
  
  return 40
end

local function isHostileMob(unit)
  if not UnitExists(unit) then return false end
  if UnitIsPlayer(unit) then return false end
  if UnitIsFriend("player", unit) then return false end
  if not UnitCanAttack("player", unit) then return false end
  return true
end

local function ensureDisplay()
  if displayFrame then return end
  
  local db = mod:GetDB()
  
  displayFrame = CreateFrame("Frame", "EasyLife_RangeDisplay", UIParent, "BackdropTemplate")
  displayFrame:SetSize(120, 40)
  displayFrame:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", db.position.x or 0, db.position.y or 200)
  displayFrame:SetFrameStrata("HIGH")
  displayFrame:SetMovable(true)
  displayFrame:EnableMouse(true)
  displayFrame:RegisterForDrag("LeftButton")
  displayFrame:SetClampedToScreen(true)
  
  displayFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  displayFrame:SetBackdropColor(0, 0, 0, 0.6)
  displayFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  
  displayFrame:SetScript("OnDragStart", displayFrame.StartMoving)
  displayFrame:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    local point, _, _, x, y = f:GetPoint()
    local pos = db.position
    pos.point = point
    pos.x = x
    pos.y = y
  end)
  
  displayText = displayFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  displayText:SetPoint("CENTER")
  displayText:SetTextColor(1, 0.82, 0)
  displayText:SetText("? - ?")
  
  mod:ApplyScale()
end

function mod:ApplyScale()
  if not displayFrame or not displayText then return end
  local db = self:GetDB()
  local scale = db.fontScale or 1.0
  displayFrame:SetScale(scale)
end

function mod:ResetPosition()
  local db = self:GetDB()
  db.position = { point = "CENTER", x = 0, y = 200 }
  if displayFrame then
    displayFrame:ClearAllPoints()
    displayFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
  end
end

local function updateDisplay()
  if not mod.enabled then return end
  
  ensureDisplay()
  
  local targetRange = nil
  if UnitExists("target") and UnitCanAttack("player", "target") then
    targetRange = estimateRange("target")
  end
  
  local closestRange = nil
  
  -- Check tracked nameplates
  for unit in pairs(tracked) do
    if UnitExists(unit) and isHostileMob(unit) then
      local r = estimateRange(unit)
      if r and (not closestRange or r < closestRange) then
        closestRange = r
      end
    end
  end
  
  -- Check target of target
  if UnitExists("targettarget") and isHostileMob("targettarget") then
    local r = estimateRange("targettarget")
    if r and (not closestRange or r < closestRange) then
      closestRange = r
    end
  end
  
  -- Fallback: use target as closest if nothing else
  if not closestRange and targetRange then
    closestRange = targetRange
  end
  
  local closestText = bucketLabel(closestRange)
  local targetText = bucketLabel(targetRange)
  
  displayText:SetText(closestText .. " - " .. targetText)
  displayFrame:Show()
end

function mod:Enable()
  if self.enabled then return end
  self.enabled = true
  
  ensureDisplay()
  displayFrame:Show()
  
  -- Track nameplates
  tracked = {}
  
  local eventFrame = CreateFrame("Frame")
  eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
  eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
      tracked[unit] = true
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
      tracked[unit] = nil
    end
  end)
  self.eventFrame = eventFrame
  
  local db = self:GetDB()
  self.ticker = C_Timer.NewTicker(db.updateRate or 0.3, updateDisplay)
  
  updateDisplay()
  EasyLife:Print("Range Indicator enabled")
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
  
  if displayFrame then
    displayFrame:Hide()
  end
  
  tracked = {}
  EasyLife:Print("Range Indicator disabled")
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

function mod:BuildConfigUI(parent)
  local db = self:GetDB()
  local L = function(k) return EasyLife:L(k) end
  
  -- Enable checkbox
  local enableCB = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  enableCB:SetPoint("TOPLEFT", 16, -16)
  enableCB.Text:SetText("Enable Range Indicator")
  enableCB:SetChecked(self.enabled)
  enableCB:SetScript("OnClick", function(self)
    mod:Toggle()
    self:SetChecked(mod.enabled)
  end)
  
  -- Update rate slider
  local rateSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  rateSlider:SetPoint("TOPLEFT", 16, -70)
  rateSlider:SetWidth(200)
  rateSlider:SetMinMaxValues(0.02, 1.0)
  rateSlider:SetValueStep(0.02)
  rateSlider:SetObeyStepOnDrag(true)
  rateSlider:SetValue(db.updateRate or 0.05)
  if rateSlider.Text then rateSlider.Text:SetText(L("RANGE_UPDATE_RATE")) end
  if rateSlider.Low then rateSlider.Low:SetText("0.02") end
  if rateSlider.High then rateSlider.High:SetText("1.0") end
  rateSlider:SetScript("OnValueChanged", function(_, v)
    db.updateRate = v
    if mod.enabled then
      mod:Disable()
      mod:Enable()
    end
  end)
  
  -- Size slider
  local sizeSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  sizeSlider:SetPoint("TOPLEFT", 16, -140)
  sizeSlider:SetWidth(200)
  sizeSlider:SetMinMaxValues(0.5, 2.5)
  sizeSlider:SetValueStep(0.1)
  sizeSlider:SetObeyStepOnDrag(true)
  sizeSlider:SetValue(db.fontScale or 1.0)
  if sizeSlider.Text then sizeSlider.Text:SetText(L("RANGE_SIZE")) end
  if sizeSlider.Low then sizeSlider.Low:SetText("0.5") end
  if sizeSlider.High then sizeSlider.High:SetText("2.5") end
  sizeSlider:SetScript("OnValueChanged", function(_, v)
    db.fontScale = v
    mod:ApplyScale()
  end)
  
  -- Reset position button
  local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  resetBtn:SetPoint("TOPLEFT", 16, -200)
  resetBtn:SetSize(140, 24)
  resetBtn:SetText(L("RANGE_RESET"))
  resetBtn:SetScript("OnClick", function()
    mod:ResetPosition()
  end)
end

-- Init
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, event, addon)
  -- Load when either EasyLife or EasyLife_RangeIndicator loads
  if event == "ADDON_LOADED" and (addon == "EasyLife_RangeIndicator" or addon == "EasyLife") then
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
