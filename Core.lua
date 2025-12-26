-- EasyLife Core
EasyLife = EasyLife or {}
EasyLife.version = "1.3.0"
EasyLife.modules = EasyLife.modules or {}

-- Defaults
local DEFAULTS = {
  language = "auto",
  minimapAngle = 45,
}

local function ensureDB()
  EasyLifeDB = EasyLifeDB or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB[k] == nil then
      EasyLifeDB[k] = v
    end
  end
end

function EasyLife:GetDB()
  return EasyLifeDB
end

function EasyLife:GetLanguage()
  local db = self:GetDB()
  local lang = db.language or "auto"
  if lang == "auto" then
    local locale = GetLocale()
    if locale == "trTR" then return "trTR" end
    return "enUS"
  end
  return lang
end

function EasyLife:RegisterModule(name, mod)
  self.modules[name] = mod
  if mod.OnRegister then
    mod:OnRegister()
  end
end

function EasyLife:GetModule(name)
  return self.modules[name]
end

function EasyLife:IsModuleLoaded(name)
  return self.modules[name] ~= nil
end

function EasyLife:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EasyLife|r: " .. tostring(msg))
end

--------------------------------------------------------------------------------
-- FIRST-RUN POPUP SYSTEM
-- Displays a one-time welcome popup when a module is opened for the first time
--------------------------------------------------------------------------------

local firstRunPopup = nil

local function createFirstRunPopup()
  if firstRunPopup then return firstRunPopup end
  
  local popup = CreateFrame("Frame", "EasyLifeFirstRunPopup", UIParent, "BackdropTemplate")
  popup:SetSize(450, 350)
  popup:SetPoint("CENTER")
  popup:SetFrameStrata("FULLSCREEN_DIALOG")
  popup:SetMovable(true)
  popup:EnableMouse(true)
  popup:RegisterForDrag("LeftButton")
  popup:SetScript("OnDragStart", popup.StartMoving)
  popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
  popup:SetClampedToScreen(true)
  
  popup:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  popup:SetBackdropColor(0.08, 0.06, 0.03, 0.98)
  
  -- Title bar
  local titleBar = CreateFrame("Frame", nil, popup, "BackdropTemplate")
  titleBar:SetHeight(32)
  titleBar:SetPoint("TOPLEFT", 12, -12)
  titleBar:SetPoint("TOPRIGHT", -12, -12)
  titleBar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
  })
  titleBar:SetBackdropColor(0.15, 0.12, 0.05, 0.9)
  
  -- Title text
  popup.title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  popup.title:SetPoint("CENTER")
  popup.title:SetTextColor(1, 0.82, 0)
  
  -- Close button (X)
  local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -8, -8)
  closeBtn:SetScript("OnClick", function()
    popup:Hide()
  end)
  
  -- Scrollable content area
  local scrollFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 4, -8)
  scrollFrame:SetPoint("BOTTOMRIGHT", -32, 70)
  
  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(380, 200)
  scrollFrame:SetScrollChild(content)
  
  popup.content = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  popup.content:SetPoint("TOPLEFT", 8, -8)
  popup.content:SetPoint("TOPRIGHT", -8, -8)
  popup.content:SetJustifyH("LEFT")
  popup.content:SetJustifyV("TOP")
  popup.content:SetSpacing(3)
  popup.content:SetTextColor(0.9, 0.9, 0.8)
  
  -- "Don't show again" checkbox
  popup.dontShowCB = CreateFrame("CheckButton", nil, popup, "ChatConfigCheckButtonTemplate")
  popup.dontShowCB:SetPoint("BOTTOMLEFT", 20, 20)
  popup.dontShowCB.Text:SetText(EasyLife:L("FIRST_RUN_DONT_SHOW"))
  popup.dontShowCB:SetChecked(true) -- Default to checked (don't show again)
  
  -- "Got it!" button
  popup.gotItBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
  popup.gotItBtn:SetSize(120, 28)
  popup.gotItBtn:SetPoint("BOTTOMRIGHT", -20, 18)
  popup.gotItBtn:SetText(EasyLife:L("FIRST_RUN_GOT_IT"))
  
  popup:Hide()
  firstRunPopup = popup
  return popup
end

-- Show first-run popup for a module
-- @param moduleName: Internal module name (e.g., "Advertise")
-- @param titleKey: Localization key for title (e.g., "ADS_TITLE")
-- @param contentKey: Localization key for detailed content (e.g., "ADS_FIRST_RUN_DETAILED")
-- @param dbTable: The module's database table where _firstRunShown is stored
function EasyLife:ShowFirstRunPopup(moduleName, titleKey, contentKey, dbTable)
  if not dbTable then return end
  
  -- Already shown, skip
  if dbTable._firstRunShown then return end
  
  local popup = createFirstRunPopup()
  
  -- Set title
  popup.title:SetText(self:L(titleKey) or moduleName)
  
  -- Set content
  local contentText = self:L(contentKey) or ""
  popup.content:SetText(contentText)
  
  -- Adjust content frame height based on text
  local textHeight = popup.content:GetStringHeight() or 200
  popup.content:GetParent():SetHeight(textHeight + 20)
  
  -- Reset checkbox
  popup.dontShowCB:SetChecked(true)
  
  -- Configure button
  popup.gotItBtn:SetScript("OnClick", function()
    if popup.dontShowCB:GetChecked() then
      dbTable._firstRunShown = true
    end
    popup:Hide()
  end)
  
  popup:Show()
end

-- Check if first-run should be shown for a module
function EasyLife:ShouldShowFirstRun(dbTable)
  if not dbTable then return false end
  return not dbTable._firstRunShown
end

-- Init
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, addon)
  if event == "ADDON_LOADED" and addon == "EasyLife" then
    ensureDB()
    
    -- Init minimap after a short delay to ensure UI is ready
    C_Timer.After(0.1, function()
      if EasyLife_Minimap_Init then
        EasyLife_Minimap_Init()
      end
    end)
  end
end)

-- Slash command
SLASH_EASYLIFE1 = "/easylife"
SLASH_EASYLIFE2 = "/el"
SlashCmdList["EASYLIFE"] = function()
  if EasyLife_Config_Toggle then
    EasyLife_Config_Toggle()
  end
end
