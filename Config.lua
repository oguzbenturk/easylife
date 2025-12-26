-- EasyLife Config Window
local frame
local contentFrame
local moduleSettingsFrame
local currentModule
local moduleRows = {}

local MODULE_LIST = {
  { name = "Advertise", key = "ADS_TITLE", descKey = "ADS_DESC", firstRunKey = "ADS_FIRST_RUN_DETAILED" },
  { name = "Boostilator", key = "BOOST_TITLE", descKey = "BOOST_DESC", firstRunKey = "BOOST_FIRST_RUN_DETAILED" },
  { name = "VendorTracker", key = "VENDOR_TITLE", descKey = "VENDOR_DESC", firstRunKey = "VENDOR_FIRST_RUN_DETAILED" },
  { name = "IceBlockHelper", key = "ICEBLOCK_TITLE", descKey = "ICEBLOCK_DESC", firstRunKey = "ICEBLOCK_FIRST_RUN_DETAILED" },
  { name = "AggroAlert", key = "AGGRO_TITLE", descKey = "AGGRO_DESC", firstRunKey = "AGGRO_FIRST_RUN_DETAILED" },
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
  frame:SetFrameStrata("HIGH")  -- Lower than settings window
  frame:SetFrameLevel(10)
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
    descText:SetPoint("RIGHT", row, "RIGHT", -50, 0)
    descText:SetJustifyH("LEFT")
    descText:SetText("|cffAAAAAA" .. L(modInfo.descKey) .. "|r")
    
    -- Preview popup button (question mark icon)
    local previewBtn = CreateFrame("Button", nil, row)
    previewBtn:SetSize(20, 20)
    previewBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    previewBtn:SetNormalTexture("Interface\\GossipFrame\\ActiveQuestIcon")
    previewBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    previewBtn:SetScript("OnClick", function()
      -- Force show the first-run popup for this module
      EasyLife:ShowFirstRunPopup(modInfo.name, modInfo.key, modInfo.firstRunKey, {})
    end)
    previewBtn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Preview Info Popup")
      GameTooltip:AddLine("|cff888888Click to preview the module info popup|r")
      GameTooltip:Show()
    end)
    previewBtn:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    
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
  moduleSettingsFrame:SetFrameStrata("HIGH")  -- Allow game interaction while open
  moduleSettingsFrame:SetFrameLevel(50)
  moduleSettingsFrame:SetMovable(true)
  moduleSettingsFrame:EnableMouse(true)
  moduleSettingsFrame:RegisterForDrag("LeftButton")
  moduleSettingsFrame:SetScript("OnDragStart", moduleSettingsFrame.StartMoving)
  moduleSettingsFrame:SetScript("OnDragStop", moduleSettingsFrame.StopMovingOrSizing)
  moduleSettingsFrame:SetClampedToScreen(true)
  
  moduleSettingsFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  moduleSettingsFrame:SetBackdropColor(0.1, 0.08, 0.05, 1)
  
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
  
  -- Hide and orphan all child frames
  for _, child in ipairs({moduleSettingsFrame.content:GetChildren()}) do
    child:Hide()
    child:ClearAllPoints()
    child:SetParent(nil)
  end
  
  -- Clear all font strings and textures
  for _, region in ipairs({moduleSettingsFrame.content:GetRegions()}) do
    region:Hide()
    if region.SetText then region:SetText("") end
    if region.SetTexture then region:SetTexture(nil) end
  end
end

function EasyLife_Config_OpenModuleSettings(moduleName)
  createSettingsFrame()
  
  -- Cleanup previous module UI first
  if currentModule then
    local prevMod = EasyLife:GetModule(currentModule)
    if prevMod and prevMod.CleanupUI then
      prevMod:CleanupUI()
    end
  end
  
  -- If reopening same module, treat it as a fresh open
  -- (force rebuild UI from scratch)
  clearSettingsContent()
  currentModule = moduleName
  
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
