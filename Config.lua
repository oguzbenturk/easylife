-- EasyLife Config Window
local frame
local contentFrame
local moduleSettingsFrame
local currentModule
local moduleRows = {}

local MODULE_LIST = {
  { name = "Advertise", key = "ADS_TITLE", descKey = "ADS_DESC" },
  { name = "Boostilator", key = "BOOST_TITLE", descKey = "BOOST_DESC" },
  { name = "VendorTracker", key = "VENDOR_TITLE", descKey = "VENDOR_DESC" },
  { name = "IceBlockHelper", key = "ICEBLOCK_TITLE", descKey = "ICEBLOCK_DESC" },
  { name = "AggroAlert", key = "AGGRO_TITLE", descKey = "AGGRO_DESC" },
}

local function L(key)
  return EasyLife:L(key)
end

-- Get/set module enabled state
local function isModuleEnabled(name)
  local db = EasyLife:GetDB()
  db.enabledModules = db.enabledModules or {}
  return db.enabledModules[name] == true
end

local function setModuleEnabled(name, enabled)
  local db = EasyLife:GetDB()
  db.enabledModules = db.enabledModules or {}
  db.enabledModules[name] = enabled
end

-- Expose for minimap
function EasyLife_Config_GetModuleList()
  return MODULE_LIST
end

function EasyLife_Config_IsModuleEnabled(name)
  return isModuleEnabled(name)
end

--------------------------------------------------------------------------------
-- MAIN CONFIG WINDOW (Module Selector)
--------------------------------------------------------------------------------

local function createMainFrame()
  if frame then return frame end
  
  frame = CreateFrame("Frame", "EasyLifeConfigFrame", UIParent, "BackdropTemplate")
  frame:SetSize(450, 380)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)
  
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  
  -- Title
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -20)
  title:SetText("|cff00CED1EasyLife|r - Module Manager")
  
  -- Subtitle
  local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
  subtitle:SetText("|cffAAAAAAEnable modules below, then access them from the minimap button|r")
  
  -- Close button
  local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)
  
  -- Module list container
  contentFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  contentFrame:SetPoint("TOPLEFT", 20, -65)
  contentFrame:SetPoint("BOTTOMRIGHT", -20, 20)
  contentFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  contentFrame:SetBackdropColor(0.03, 0.03, 0.03, 0.9)
  
  -- Create module rows
  for i, modInfo in ipairs(MODULE_LIST) do
    local row = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
    row:SetHeight(50)
    row:SetPoint("TOPLEFT", 8, -8 - (i-1) * 54)
    row:SetPoint("TOPRIGHT", -8, -8 - (i-1) * 54)
    row:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      tile = false, edgeSize = 1,
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    row:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
    row:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.5)
    
    -- Enable checkbox
    local cb = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("LEFT", 8, 0)
    cb:SetChecked(isModuleEnabled(modInfo.name))
    cb:SetScript("OnClick", function(self)
      setModuleEnabled(modInfo.name, self:GetChecked())
    end)
    row.checkbox = cb
    
    -- Module name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", cb, "TOPRIGHT", 8, -4)
    nameText:SetText("|cff00CED1" .. L(modInfo.key) .. "|r")
    
    -- Description
    local descText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    descText:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    descText:SetJustifyH("LEFT")
    descText:SetText("|cffAAAAAA" .. L(modInfo.descKey) .. "|r")
    
    moduleRows[modInfo.name] = row
  end
  
  frame:Hide()
  tinsert(UISpecialFrames, "EasyLifeConfigFrame")
  
  return frame
end

function EasyLife_Config_Toggle()
  createMainFrame()
  if frame:IsShown() then
    frame:Hide()
  else
    -- Refresh checkbox states
    for _, modInfo in ipairs(MODULE_LIST) do
      local row = moduleRows[modInfo.name]
      if row and row.checkbox then
        row.checkbox:SetChecked(isModuleEnabled(modInfo.name))
      end
    end
    frame:Show()
  end
end

--------------------------------------------------------------------------------
-- MODULE SETTINGS WINDOW
--------------------------------------------------------------------------------

local function createSettingsFrame()
  if moduleSettingsFrame then return moduleSettingsFrame end
  
  moduleSettingsFrame = CreateFrame("Frame", "EasyLifeModuleSettingsFrame", UIParent, "BackdropTemplate")
  moduleSettingsFrame:SetSize(500, 420)
  moduleSettingsFrame:SetPoint("CENTER")
  moduleSettingsFrame:SetFrameStrata("DIALOG")
  moduleSettingsFrame:SetMovable(true)
  moduleSettingsFrame:EnableMouse(true)
  moduleSettingsFrame:RegisterForDrag("LeftButton")
  moduleSettingsFrame:SetScript("OnDragStart", moduleSettingsFrame.StartMoving)
  moduleSettingsFrame:SetScript("OnDragStop", moduleSettingsFrame.StopMovingOrSizing)
  moduleSettingsFrame:SetClampedToScreen(true)
  
  moduleSettingsFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  moduleSettingsFrame:SetBackdropColor(0.04, 0.04, 0.04, 0.95)
  
  -- Title (will be set dynamically)
  moduleSettingsFrame.title = moduleSettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  moduleSettingsFrame.title:SetPoint("TOP", 0, -16)
  
  -- Close button
  local closeBtn = CreateFrame("Button", nil, moduleSettingsFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)
  
  -- Content area
  moduleSettingsFrame.content = CreateFrame("Frame", nil, moduleSettingsFrame)
  moduleSettingsFrame.content:SetPoint("TOPLEFT", 14, -40)
  moduleSettingsFrame.content:SetPoint("BOTTOMRIGHT", -14, 14)
  
  moduleSettingsFrame:Hide()
  tinsert(UISpecialFrames, "EasyLifeModuleSettingsFrame")
  
  return moduleSettingsFrame
end

local function clearSettingsContent()
  if not moduleSettingsFrame or not moduleSettingsFrame.content then return end
  for _, child in ipairs({moduleSettingsFrame.content:GetChildren()}) do
    child:Hide()
    child:SetParent(nil)
  end
  for _, region in ipairs({moduleSettingsFrame.content:GetRegions()}) do
    if region:GetObjectType() == "FontString" then
      region:SetText("")
    end
  end
end

function EasyLife_Config_OpenModuleSettings(moduleName)
  createSettingsFrame()
  
  -- Cleanup previous module
  if currentModule then
    local prevMod = EasyLife:GetModule(currentModule)
    if prevMod and prevMod.CleanupUI then
      prevMod:CleanupUI()
    end
  end
  
  currentModule = moduleName
  clearSettingsContent()
  
  -- Find module info
  local modInfo
  for _, info in ipairs(MODULE_LIST) do
    if info.name == moduleName then
      modInfo = info
      break
    end
  end
  
  -- Set title
  if modInfo then
    moduleSettingsFrame.title:SetText("|cff00CED1" .. L(modInfo.key) .. "|r Settings")
  else
    moduleSettingsFrame.title:SetText(moduleName .. " Settings")
  end
  
  local mod = EasyLife:GetModule(moduleName)
  if mod and mod.BuildConfigUI then
    mod:BuildConfigUI(moduleSettingsFrame.content)
  else
    local text = moduleSettingsFrame.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText("No settings available for this module")
  end
  
  moduleSettingsFrame:Show()
end

-- Legacy support
function EasyLife_Config_Open()
  EasyLife_Config_Toggle()
end

function EasyLife_Config_SelectModule(moduleName)
  EasyLife_Config_OpenModuleSettings(moduleName)
end
