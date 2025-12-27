-- IceBlockHelper Module
-- Shows the best moment to cancel Ice Block between mob attack swings
local IceBlockHelper = {}
local displayFrame
local swingBar
local safeZone

-- Track mob attacks
local lastAttackTime = 0
local attackIntervals = {}
local estimatedSwingTimer = 2.0  -- Default mob swing timer
local maxSamples = 5  -- Number of attack samples to average
local inIceBlock = false
local nextAttackTime = 0

-- Defaults
local DEFAULTS = {
  enabled = true,
  x = 0,
  y = -200,
  width = 250,
  height = 30,
  locked = false,
  safeWindowPercent = 0.6,  -- Show safe zone in last 60% before next attack
}

local function ensureDB()
  local db = EasyLife:GetDB()
  if not db then return false end
  db.iceBlockHelper = db.iceBlockHelper or {}
  for k, v in pairs(DEFAULTS) do
    if db.iceBlockHelper[k] == nil then
      db.iceBlockHelper[k] = v
    end
  end
  -- First-run detection
  if db.iceBlockHelper._firstRunShown == nil then
    db.iceBlockHelper._firstRunShown = false
  end
  return true
end

local function getDB()
  ensureDB()
  local db = EasyLife:GetDB()
  return db and db.iceBlockHelper or DEFAULTS
end

-- Create the display frame
local function createDisplayFrame()
  if displayFrame then return displayFrame end
  
  local db = getDB()
  
  local frame = CreateFrame("Frame", "EasyLifeIceBlockHelperFrame", UIParent, "BackdropTemplate")
  frame:SetSize(db.width, db.height + 40)
  frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
  frame:SetFrameStrata("HIGH")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  frame:SetBackdropColor(0, 0, 0, 0.8)
  
  -- Title
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.title:SetPoint("TOP", 0, -6)
  frame.title:SetText("|cff69CCF0Ice Block Helper|r")
  
  -- Status text
  frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.status:SetPoint("TOP", 0, -20)
  frame.status:SetText("Waiting...")
  
  -- Swing timer bar background
  local barBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  barBg:SetSize(db.width - 20, db.height - 10)
  barBg:SetPoint("BOTTOM", 0, 8)
  barBg:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  barBg:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
  barBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  
  -- Safe zone (green area - when it's safe to cancel)
  safeZone = barBg:CreateTexture(nil, "ARTWORK")
  safeZone:SetColorTexture(0, 0.8, 0, 0.5)
  safeZone:SetPoint("RIGHT", barBg, "RIGHT", -1, 0)
  safeZone:SetHeight(db.height - 12)
  safeZone:SetWidth((db.width - 22) * 0.6)
  
  -- Danger zone (red area - attacks incoming)
  local dangerZone = barBg:CreateTexture(nil, "BACKGROUND")
  dangerZone:SetColorTexture(0.8, 0, 0, 0.5)
  dangerZone:SetAllPoints(barBg)
  
  -- Swing bar (shows time until next attack)
  swingBar = barBg:CreateTexture(nil, "OVERLAY")
  swingBar:SetColorTexture(1, 1, 1, 0.9)
  swingBar:SetPoint("LEFT", barBg, "LEFT", 1, 0)
  swingBar:SetHeight(db.height - 12)
  swingBar:SetWidth(3)
  
  -- Labels
  frame.dangerLabel = barBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.dangerLabel:SetPoint("LEFT", 5, 0)
  frame.dangerLabel:SetText("|cffFF0000WAIT|r")
  
  frame.safeLabel = barBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.safeLabel:SetPoint("RIGHT", -5, 0)
  frame.safeLabel:SetText("|cff00FF00CANCEL!|r")
  
  -- Timer text
  frame.timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.timerText:SetPoint("CENTER", barBg, "CENTER", 0, 0)
  frame.timerText:SetText("")
  
  -- Drag functionality
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if not db.locked then
      self:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    db.x = x
    db.y = y
  end)
  
  frame:Hide()
  displayFrame = frame
  return frame
end

-- Update the swing bar
local function updateSwingBar()
  if not displayFrame or not displayFrame:IsShown() then return end
  if not inIceBlock then return end
  
  local db = getDB()
  local now = GetTime()
  local timeUntilAttack = nextAttackTime - now
  local barWidth = db.width - 22
  
  if timeUntilAttack < 0 then
    -- Attack should have happened, estimate next one
    nextAttackTime = now + estimatedSwingTimer
    timeUntilAttack = estimatedSwingTimer
  end
  
  local progress = 1 - (timeUntilAttack / estimatedSwingTimer)
  progress = math.max(0, math.min(1, progress))
  
  -- Move the indicator bar
  local xPos = progress * barWidth
  swingBar:SetPoint("LEFT", swingBar:GetParent(), "LEFT", 1 + xPos, 0)
  
  -- Update timer text
  displayFrame.timerText:SetText(string.format("%.1f", timeUntilAttack))
  
  -- Update status based on position
  local safeThreshold = 1 - db.safeWindowPercent
  if progress >= safeThreshold then
    displayFrame.status:SetText("|cff00FF00>> CANCEL NOW! <<|r")
    displayFrame.status:SetTextColor(0, 1, 0)
  else
    displayFrame.status:SetText("|cffFF0000Wait...|r")
    displayFrame.status:SetTextColor(1, 0, 0)
  end
end

-- Process an incoming attack
local function onMobAttack()
  local now = GetTime()
  
  if lastAttackTime > 0 then
    local interval = now - lastAttackTime
    
    -- Only track reasonable intervals (0.5s to 5s)
    if interval > 0.5 and interval < 5 then
      table.insert(attackIntervals, interval)
      
      -- Keep only last N samples
      while #attackIntervals > maxSamples do
        table.remove(attackIntervals, 1)
      end
      
      -- Calculate average swing timer
      if #attackIntervals > 0 then
        local sum = 0
        for _, v in ipairs(attackIntervals) do
          sum = sum + v
        end
        estimatedSwingTimer = sum / #attackIntervals
      end
    end
  end
  
  lastAttackTime = now
  nextAttackTime = now + estimatedSwingTimer
end

-- Check if player has Ice Block buff
local function hasIceBlock()
  for i = 1, 40 do
    local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
    if not name then break end
    -- Ice Block spell IDs: 45438 (main), 41425 (arena), 27619 (rank 1)
    if name == "Ice Block" or spellId == 45438 or spellId == 27619 or spellId == 41425 then
      return true
    end
  end
  return false
end

-- Combat log handler
local function onCombatLogEvent()
  if not inIceBlock then return end
  
  local _, subEvent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
  
  -- Check if player is the target
  if destGUID ~= UnitGUID("player") then return end
  
  -- Track swing attacks (melee hits/misses)
  if subEvent == "SWING_DAMAGE" or subEvent == "SWING_MISSED" then
    onMobAttack()
  end
end

-- Show the helper
function IceBlockHelper:Show()
  local frame = createDisplayFrame()
  frame:Show()
  
  -- Reset tracking data
  lastAttackTime = 0
  attackIntervals = {}
  estimatedSwingTimer = 2.0
  nextAttackTime = GetTime() + estimatedSwingTimer
end

function IceBlockHelper:Hide()
  if displayFrame then
    displayFrame:Hide()
  end
end

function IceBlockHelper:Toggle()
  local db = getDB()
  db.enabled = not db.enabled
end

function IceBlockHelper:ResetPosition()
  local db = getDB()
  db.x = DEFAULTS.x
  db.y = DEFAULTS.y
  
  if displayFrame then
    displayFrame:ClearAllPoints()
    displayFrame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
  end
end

-- Build config UI
function IceBlockHelper:BuildConfigUI(parent)
  local db = getDB()
  local yOffset = -10
  
  -- Show first-run popup if needed
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("IceBlockHelper", "ICEBLOCK_TITLE", "ICEBLOCK_FIRST_RUN_DETAILED", db)
  end
  
  -- Title
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, yOffset)
  title:SetText("Ice Block Helper")
  yOffset = yOffset - 30
  
  -- Description
  local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  desc:SetPoint("TOPLEFT", 10, yOffset)
  desc:SetWidth(350)
  desc:SetJustifyH("LEFT")
  desc:SetText("|cffAAAAAAShows a bar when you're in Ice Block that tracks mob attack patterns. Cancel in the GREEN zone for safety!|r")
  yOffset = yOffset - 45
  
  -- Enable checkbox
  local enableCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  enableCheck:SetPoint("TOPLEFT", 10, yOffset)
  enableCheck:SetChecked(db.enabled)
  enableCheck.text = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  enableCheck.text:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
  enableCheck.text:SetText("Enable Ice Block Helper")
  enableCheck:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
  end)
  yOffset = yOffset - 35
  
  -- Lock frame checkbox
  local lockCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  lockCheck:SetPoint("TOPLEFT", 10, yOffset)
  lockCheck:SetChecked(db.locked)
  lockCheck.text = lockCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lockCheck.text:SetPoint("LEFT", lockCheck, "RIGHT", 5, 0)
  lockCheck.text:SetText("Lock frame position")
  lockCheck:SetScript("OnClick", function(self)
    db.locked = self:GetChecked()
  end)
  yOffset = yOffset - 35
  
  -- Reset position button
  local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  resetBtn:SetSize(140, 24)
  resetBtn:SetPoint("TOPLEFT", 10, yOffset)
  resetBtn:SetText("Reset Position")
  resetBtn:SetScript("OnClick", function()
    IceBlockHelper:ResetPosition()
  end)
  yOffset = yOffset - 35
  
  -- Test button
  local testBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  testBtn:SetSize(140, 24)
  testBtn:SetPoint("TOPLEFT", 10, yOffset)
  testBtn:SetText("Test Display")
  testBtn:SetScript("OnClick", function()
    inIceBlock = true
    IceBlockHelper:Show()
    C_Timer.After(10, function()
      inIceBlock = false
      IceBlockHelper:Hide()
    end)
  end)
  yOffset = yOffset - 50
  
  -- Instructions
  local instructions = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  instructions:SetPoint("TOPLEFT", 10, yOffset)
  instructions:SetWidth(350)
  instructions:SetJustifyH("LEFT")
  instructions:SetText("|cffFFFF00How to use:|r\n\n1. When you Ice Block with mobs hitting you, this bar appears\n2. The white line moves from left to right\n3. |cffFF0000RED zone|r = mobs about to attack, DON'T cancel\n4. |cff00FF00GREEN zone|r = safe window, CANCEL now!\n5. The addon learns mob attack speed as they hit you")
end

-- Store event frame reference for UpdateState
local iceBlockEventFrame = nil

-- Update module state (called when enabling/disabling from Module Manager)
function IceBlockHelper:UpdateState()
  local db = getDB()
  
  if not db.enabled then
    -- Disable: hide display and unregister events
    self:Hide()
    if iceBlockEventFrame then
      iceBlockEventFrame:UnregisterEvent("UNIT_AURA")
      iceBlockEventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
  else
    -- Enable: register events
    if iceBlockEventFrame then
      iceBlockEventFrame:RegisterEvent("UNIT_AURA")
      iceBlockEventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
  end
end

-- Initialize
function IceBlockHelper:OnRegister()
  iceBlockEventFrame = CreateFrame("Frame")
  iceBlockEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  iceBlockEventFrame:RegisterEvent("UNIT_AURA")
  iceBlockEventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  
  iceBlockEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
      ensureDB()
    elseif event == "UNIT_AURA" then
      local unit = ...
      if unit == "player" then
        local db = getDB()
        if not db.enabled then return end
        
        local wasInIceBlock = inIceBlock
        inIceBlock = hasIceBlock()
        
        if inIceBlock and not wasInIceBlock then
          -- Just entered Ice Block
          IceBlockHelper:Show()
        elseif not inIceBlock and wasInIceBlock then
          -- Just left Ice Block
          IceBlockHelper:Hide()
        end
      end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
      local db = getDB()
      if db.enabled then
        onCombatLogEvent()
      end
    end
  end)
  
  -- Update ticker
  C_Timer.NewTicker(0.02, updateSwingBar)
end

-- Register module
EasyLife:RegisterModule("IceBlockHelper", IceBlockHelper)
