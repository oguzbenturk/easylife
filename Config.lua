-- EasyLife Config Window
local frame
local contentFrame
local sidebar
local moduleButtons = {}
local currentModule
local singleMode = false

local MODULE_LIST = {
  { name = "Advertise", key = "ADS_TITLE" },
  { name = "Boostilator", key = "BOOST_TITLE" },
  { name = "VendorTracker", key = "VENDOR_TITLE" },
  { name = "IceBlockHelper", key = "ICEBLOCK_TITLE" },
  { name = "AggroAlert", key = "AGGRO_TITLE" },
}

local function L(key)
  return EasyLife:L(key)
end

local function updateLayout()
  if not frame or not contentFrame or not sidebar then return end
  if singleMode then
    sidebar:Hide()
    contentFrame:ClearAllPoints()
    contentFrame:SetPoint("TOPLEFT", 14, -14)
    contentFrame:SetPoint("BOTTOMRIGHT", -14, 14)
  else
    sidebar:Show()
    contentFrame:ClearAllPoints()
    contentFrame:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
    contentFrame:SetPoint("BOTTOMRIGHT", -14, 14)
  end
end

local function createFrame()
  if frame then return end
  
  frame = CreateFrame("Frame", "EasyLifeConfigFrame", UIParent, "BackdropTemplate")
  frame:SetSize(550, 400)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)
  
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  frame:SetBackdropColor(0.04, 0.04, 0.04, 0.92)
  
  -- Close button
  local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)
  
  -- Left sidebar for module buttons
  sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  sidebar:SetPoint("TOPLEFT", 14, -18)
  sidebar:SetPoint("BOTTOMLEFT", 14, 14)
  sidebar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  sidebar:SetBackdropColor(0.07, 0.07, 0.07, 0.9)
  
  -- Module buttons
  for i, modInfo in ipairs(MODULE_LIST) do
    local btn = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    btn:SetSize(130, 24)
    btn:SetPoint("TOP", 0, -8 - (i - 1) * 28)
    btn:SetText(L(modInfo.key))
    btn:SetScript("OnClick", function()
      EasyLife_Config_SelectModule(modInfo.name)
    end)
    moduleButtons[modInfo.name] = btn
  end
  
  -- Content area
  contentFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  contentFrame:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
  contentFrame:SetPoint("BOTTOMRIGHT", -14, 14)
  contentFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  contentFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
  
  frame:Hide()
  tinsert(UISpecialFrames, "EasyLifeConfigFrame")
  updateLayout()
end

local function clearContent()
  if not contentFrame then return end
  for _, child in ipairs({contentFrame:GetChildren()}) do
    child:Hide()
    child:SetParent(nil)
  end
  for _, region in ipairs({contentFrame:GetRegions()}) do
    if region:GetObjectType() == "FontString" then
      region:SetText("")
    end
  end
end

local function showModuleNotLoaded(moduleName)
  clearContent()
  local text = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  text:SetPoint("CENTER")
  text:SetText(L("MODULE_NOT_LOADED") .. "\n\n" .. moduleName)
end

-- Expose the module list for other UI (e.g. minimap dropdown)
function EasyLife_Config_GetModuleList()
  return MODULE_LIST
end

function EasyLife_Config_SelectModule(moduleName)
  createFrame()
  
  -- Cleanup previous module's floating UI elements before switching
  if currentModule then
    local prevMod = EasyLife:GetModule(currentModule)
    if prevMod and prevMod.CleanupUI then
      prevMod:CleanupUI()
    end
  end
  
  currentModule = moduleName
  
  -- Highlight selected button
  for name, btn in pairs(moduleButtons) do
    if name == moduleName then
      btn:LockHighlight()
    else
      btn:UnlockHighlight()
    end
  end
  
  local mod = EasyLife:GetModule(moduleName)
  if not mod then
    showModuleNotLoaded(moduleName)
    return
  end
  
  clearContent()
  
  if mod.BuildConfigUI then
    mod:BuildConfigUI(contentFrame)
  else
    local text = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText(moduleName .. " - No options")
  end

  -- end of EasyLife_Config_SelectModule
end

-- Cleanup all module floating UIs
local function cleanupAllModules()
  for _, modInfo in ipairs(MODULE_LIST) do
    local mod = EasyLife:GetModule(modInfo.name)
    if mod and mod.CleanupUI then
      mod:CleanupUI()
    end
  end
end

function EasyLife_Config_Toggle()
  createFrame()
  singleMode = false
  updateLayout()
  if frame:IsShown() then
    cleanupAllModules()
    frame:Hide()
  else
    frame:Show()
    -- Select first loaded module or first in list
    local first = MODULE_LIST[1].name
    for _, modInfo in ipairs(MODULE_LIST) do
      if EasyLife:IsModuleLoaded(modInfo.name) then
        first = modInfo.name
        break
      end
    end
    EasyLife_Config_SelectModule(currentModule or first)
  end
end

-- Open config and directly show a given module panel
function EasyLife_Config_OpenTo(moduleName)
  createFrame()
  singleMode = false
  updateLayout()
  frame:Show()

  local target = moduleName
  if not target or target == "" then
    -- Select first loaded module or first in list
    target = MODULE_LIST[1].name
    for _, modInfo in ipairs(MODULE_LIST) do
      if EasyLife:IsModuleLoaded(modInfo.name) then
        target = modInfo.name
        break
      end
    end
  end

  EasyLife_Config_SelectModule(target)
end

function EasyLife_Config_Open()
  createFrame()
  singleMode = false
  updateLayout()
  frame:Show()
  local first = MODULE_LIST[1].name
  for _, modInfo in ipairs(MODULE_LIST) do
    if EasyLife:IsModuleLoaded(modInfo.name) then
      first = modInfo.name
      break
    end
  end
  EasyLife_Config_SelectModule(currentModule or first)
end

-- Open only the requested module, hiding the sidebar
function EasyLife_Config_OpenSingle(moduleName)
  createFrame()
  singleMode = true
  updateLayout()
  frame:Show()

  local target = moduleName
  if not target or target == "" then
    target = MODULE_LIST[1].name
  end
  EasyLife_Config_SelectModule(target)
end
