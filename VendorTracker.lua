-- VendorTracker Module
local VendorTracker = {}
local totalValue = 0
local sessionValue = 0
local sessionItems = {}  -- Track items in current session
local displayFrame
local recentLoot = {}  -- Track recent loot to prevent duplicate counting
local LOOT_DEDUP_TIME = 0.5  -- Time window to consider same loot as duplicate (seconds)

-- Defaults
local DEFAULTS = {
  enabled = false,
  point = "TOPLEFT",
  relativePoint = "TOPLEFT",
  x = 100,
  y = -100,
  locked = false,
  showInCombat = true,
  countPartyLoot = false,
}

local function ensureDB()
  -- Only initialize if EasyLifeDB exists (set by WoW when SavedVariables load)
  if not EasyLifeDB then
    EasyLifeDB = {}
  end
  if not EasyLifeDB.vendorTracker then
    EasyLifeDB.vendorTracker = {}
  end
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.vendorTracker[k] == nil then
      EasyLifeDB.vendorTracker[k] = v
    end
  end
  -- First-run detection
  if EasyLifeDB.vendorTracker._firstRunShown == nil then
    EasyLifeDB.vendorTracker._firstRunShown = false
  end
  return true
end

local function getDB()
  ensureDB()
  return EasyLifeDB.vendorTracker
end

-- Format copper value to gold/silver/copper display
local function formatMoney(copper)
  if not copper or copper == 0 then
    return "0|cffC7C7CFC|r"
  end
  
  local gold = floor(copper / 10000)
  local silver = floor((copper % 10000) / 100)
  local cop = copper % 100
  
  local str = ""
  if gold > 0 then
    str = str .. gold .. "|cffFFD700G|r "
  end
  if silver > 0 or gold > 0 then
    str = str .. silver .. "|cffC7C7CFS|r "
  end
  str = str .. cop .. "|cffC7C7CFC|r"
  
  return str
end

-- Create display frame
local function createDisplayFrame()
  if displayFrame then return displayFrame end
  
  local db = getDB()
  
  local frame = CreateFrame("Frame", "EasyLifeVendorTrackerFrame", UIParent, "BackdropTemplate")
  frame:SetSize(220, 60)
  frame:SetPoint(db.point or "TOPLEFT", UIParent, db.relativePoint or db.point or "TOPLEFT", db.x, db.y)
  frame:SetFrameStrata("MEDIUM")
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
  frame.title:SetPoint("TOP", 0, -8)
  frame.title:SetText("|cff33ff99Vendor Value|r")
  
  -- Session value
  frame.sessionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.sessionLabel:SetPoint("TOPLEFT", 8, -24)
  frame.sessionLabel:SetText("Session:")
  
  frame.sessionValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.sessionValue:SetPoint("TOPRIGHT", -8, -24)
  frame.sessionValue:SetText(formatMoney(0))
  
  -- Total value
  frame.totalLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.totalLabel:SetPoint("TOPLEFT", 8, -42)
  frame.totalLabel:SetText("Total:")
  
  frame.totalValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.totalValue:SetPoint("TOPRIGHT", -8, -42)
  frame.totalValue:SetText(formatMoney(0))
  
  -- Drag functionality
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    local currentDB = getDB()
    if not currentDB.locked then
      self:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Get fresh DB reference and save position
    local currentDB = getDB()
    local point, relativeTo, relativePoint, x, y = self:GetPoint()
    currentDB.point = point
    currentDB.relativePoint = relativePoint
    currentDB.x = x
    currentDB.y = y
  end)
  
  -- Mouse behavior: left-drag to move; right-click toggles lock; Shift-Right resets session
  frame:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" and IsShiftKeyDown() then
      sessionValue = 0
      sessionItems = {}
      VendorTracker:UpdateDisplay()
      return
    end
    if button == "RightButton" then
      local d = getDB()
      d.locked = not d.locked
      local point, relativeTo, relativePoint, x, y = self:GetPoint()
      d.point = point
      d.relativePoint = relativePoint
      d.x = x
      d.y = y
    end
  end)
  
  -- Tooltip
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("|cff33ff99Vendor Tracker|r", 1, 1, 1)
    GameTooltip:AddLine(" ")
    
    -- Show session items
    if #sessionItems > 0 then
      GameTooltip:AddLine("|cffFFFF00Session Items:|r", 1, 1, 1)
      local maxShow = 15  -- Show last 15 items
      local startIdx = math.max(1, #sessionItems - maxShow + 1)
      
      for i = startIdx, #sessionItems do
        local item = sessionItems[i]
        local moneyStr = formatMoney(item.value)
        GameTooltip:AddDoubleLine(item.name, moneyStr, 1, 1, 1, 1, 1, 1)
      end
      
      if #sessionItems > maxShow then
        GameTooltip:AddLine("|cff888888... and " .. (#sessionItems - maxShow) .. " more items|r", 0.5, 0.5, 0.5)
      end
      GameTooltip:AddLine(" ")
    else
      GameTooltip:AddLine("No items looted this session.", 0.7, 0.7, 0.7)
      GameTooltip:AddLine(" ")
    end
    
    GameTooltip:AddLine("|cffFFFFFFDrag:|r Move frame", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("|cffFFFFFFRight-click:|r Reset session", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  
  displayFrame = frame
  return frame
end

function VendorTracker:UpdateDisplay()
  if not displayFrame then return end
  
  displayFrame.sessionValue:SetText(formatMoney(sessionValue))
  displayFrame.totalValue:SetText(formatMoney(totalValue))
end

function VendorTracker:Show()
  local frame = createDisplayFrame()
  -- Update position from DB (in case frame was created before DB was ready)
  local db = getDB()
  frame:ClearAllPoints()
  frame:SetPoint(db.point or "TOPLEFT", UIParent, db.relativePoint or db.point or "TOPLEFT", db.x, db.y)
  frame:Show()
  self:UpdateDisplay()
end

function VendorTracker:Hide()
  if displayFrame then
    displayFrame:Hide()
  end
end

function VendorTracker:Toggle()
  local db = getDB()
  db.enabled = not db.enabled
  
  if db.enabled then
    self:Show()
  else
    self:Hide()
  end
end

function VendorTracker:ResetPosition()
  local db = getDB()
  db.x = DEFAULTS.x
  db.y = DEFAULTS.y
  
  if displayFrame then
    displayFrame:ClearAllPoints()
    displayFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.x, db.y)
  end
end

-- Event handling
local function onLootReceived(_, message)
  local db = getDB()
  
  -- Check if we should count this loot
  if not db.countPartyLoot then
    -- Only count player's own loot (messages starting with "You")
    if not message:match("^You") then return end
  end
  
  -- Parse loot message for item links
  local itemLink = message:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
  if not itemLink then return end
  
  -- Validate item link format first
  if type(itemLink) ~= "string" or itemLink == "" then return end
  
  -- Extract item ID from link for safer lookup
  local itemID = itemLink:match("item:(%d+)")
  if not itemID then return end
  
  -- Extract looter name from message to create unique key
  -- Messages are like "You receive loot: [Item]" or "PlayerName receives loot: [Item]"
  local looterName = message:match("^(.+) receives? loot")
  if not looterName then
    looterName = "You"
  end
  
  -- Create a unique key for this loot event (looter + item)
  local lootKey = looterName .. ":" .. itemID
  local currentTime = GetTime()
  
  -- Clean up old entries from recentLoot table
  for key, timestamp in pairs(recentLoot) do
    if currentTime - timestamp > LOOT_DEDUP_TIME then
      recentLoot[key] = nil
    end
  end
  
  -- Check if we've already processed this loot event recently
  if recentLoot[lootKey] then
    return  -- Skip duplicate
  end
  
  -- Mark this loot as processed
  recentLoot[lootKey] = currentTime
  
  -- Get item info using item ID
  local itemName, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(tonumber(itemID))
  
  -- Item data not cached yet or invalid
  if not itemName then return end
  
  if vendorPrice and vendorPrice > 0 then
    sessionValue = sessionValue + vendorPrice
    totalValue = totalValue + vendorPrice
    
    -- Track the item
    table.insert(sessionItems, {
      name = itemName or "Unknown Item",
      value = vendorPrice,
      link = itemLink
    })
    
    VendorTracker:UpdateDisplay()
  end
end

local function onZoneChanged()
  local inInstance, instanceType = IsInInstance()
  
  if inInstance then
    -- Reset session value when entering instance
    sessionValue = 0
    sessionItems = {}
    VendorTracker:UpdateDisplay()
  end
end

-- Build config UI
function VendorTracker:BuildConfigUI(parent)
  local db = getDB()
  local yOffset = -10
  
  -- Show first-run popup if needed
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("VendorTracker", "VENDOR_TITLE", "VENDOR_FIRST_RUN_DETAILED", db)
  end
  
  -- Title
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, yOffset)
  title:SetText("Vendor Tracker")
  yOffset = yOffset - 30
  
  -- Enable checkbox
  local enableCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  enableCheck:SetPoint("TOPLEFT", 10, yOffset)
  enableCheck:SetChecked(db.enabled)
  enableCheck.text = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  enableCheck.text:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
  enableCheck.text:SetText("Enable Vendor Tracker")
  enableCheck:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
    if db.enabled then
      VendorTracker:Show()
    else
      VendorTracker:Hide()
    end
  end)
  yOffset = yOffset - 35
  
  -- Count party loot checkbox
  local partyLootCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  partyLootCheck:SetPoint("TOPLEFT", 10, yOffset)
  partyLootCheck:SetChecked(db.countPartyLoot)
  partyLootCheck.text = partyLootCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  partyLootCheck.text:SetPoint("LEFT", partyLootCheck, "RIGHT", 5, 0)
  partyLootCheck.text:SetText("Count party members' loot")
  partyLootCheck:SetScript("OnClick", function(self)
    db.countPartyLoot = self:GetChecked()
  end)
  yOffset = yOffset - 35
  
  -- Reset position button
  local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  resetBtn:SetSize(140, 24)
  resetBtn:SetPoint("TOPLEFT", 10, yOffset)
  resetBtn:SetText("Reset Position")
  resetBtn:SetScript("OnClick", function()
    VendorTracker:ResetPosition()
  end)
  yOffset = yOffset - 35
  
  -- Reset session button
  local resetSessionBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  resetSessionBtn:SetSize(140, 24)
  resetSessionBtn:SetPoint("TOPLEFT", 10, yOffset)
  resetSessionBtn:SetText("Reset Session")
  resetSessionBtn:SetScript("OnClick", function()
    sessionItems = {}
    sessionValue = 0
    VendorTracker:UpdateDisplay()
  end)
  yOffset = yOffset - 35
  
  -- Reset total button
  local resetTotalBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  resetTotalBtn:SetSize(140, 24)
  resetTotalBtn:SetPoint("TOPLEFT", 10, yOffset)
  resetTotalBtn:SetText("Reset Total")
  resetTotalBtn:SetScript("OnClick", function()
    totalValue = 0
    VendorTracker:UpdateDisplay()
  end)
  yOffset = yOffset - 50
  
  -- Current values display
  local infoText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  infoText:SetPoint("TOPLEFT", 10, yOffset)
  infoText:SetText("|cffFFFFFFCurrent Values:|r\n\nSession: " .. formatMoney(sessionValue) .. "\nTotal: " .. formatMoney(totalValue))
  infoText:SetJustifyH("LEFT")
end

-- Initialize
function VendorTracker:OnRegister()
  -- Create event frame
  local eventFrame = CreateFrame("Frame")
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  eventFrame:RegisterEvent("CHAT_MSG_LOOT")
  
  eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
      -- Ensure DB is initialized on first login
      if ensureDB() then
        local db = getDB()
        if db.enabled then
          VendorTracker:Show()
        end
      end
      onZoneChanged()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
      onZoneChanged()
    elseif event == "CHAT_MSG_LOOT" then
      onLootReceived(self, ...)
    end
  end)
end

-- Register module
EasyLife:RegisterModule("VendorTracker", VendorTracker)
