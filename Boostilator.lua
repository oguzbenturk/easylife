-- Boostilator Module
-- Tracks party boosties, runs, and payments
local Boostilator = {}

local L = function(key)
  return EasyLife:L(key)
end

-- Message Queue System (for hardware-triggered chat messages)
local messageQueue = {}
local queueFrame = nil
local pixelFrame = nil

local function InitMessageQueue()
  if queueFrame then return end
  
  -- Create notification frame (more visible than a single pixel)
  pixelFrame = CreateFrame("Frame", "BoostilatorNotifyFrame", UIParent, "BackdropTemplate")
  pixelFrame:SetSize(200, 40)
  pixelFrame:SetPoint("TOP", UIParent, "TOP", 0, -100)
  pixelFrame:SetFrameStrata("TOOLTIP")
  pixelFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  pixelFrame:SetBackdropColor(0.1, 0.08, 0.05, 0.95)
  pixelFrame:SetBackdropBorderColor(0, 1, 0, 1)  -- Green border
  pixelFrame.text = pixelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  pixelFrame.text:SetPoint("CENTER", 0, 0)
  pixelFrame.text:SetText("|cff00FF00Press any key to send|r")
  pixelFrame:Hide()
  
  -- Create queue capture frame
  queueFrame = CreateFrame("Frame", "BoostilatorQueueFrame", UIParent)
  queueFrame:SetAllPoints(UIParent)
  queueFrame:SetFrameStrata("TOOLTIP")
  queueFrame:EnableMouse(true)
  queueFrame:EnableKeyboard(true)
  queueFrame:SetPropagateKeyboardInput(true)
  queueFrame:Hide()
  
  local function processQueue()
    while #messageQueue > 0 do
      local item = table.remove(messageQueue, 1)
      if item then item() end
    end
    queueFrame:Hide()
    pixelFrame:Hide()
  end
  
  queueFrame:SetScript("OnMouseDown", processQueue)
  queueFrame:SetScript("OnKeyDown", processQueue)
end

local function QueueMessage(func)
  InitMessageQueue()
  table.insert(messageQueue, func)
  queueFrame:Show()
  pixelFrame:Show()
  -- Flash the client icon
  if FlashClientIcon then
    FlashClientIcon()
  end
end

local function ClearMessageQueue()
  wipe(messageQueue)
  if queueFrame then queueFrame:Hide() end
  if pixelFrame then pixelFrame:Hide() end
end

local DEFAULTS = {
  enabled = true,
  pricePerRun = 100000,   -- 10g default (1 run)
  price5Runs = 450000,    -- 45g default (5-run pack)
  price10Runs = 800000,   -- 80g default (10-run pack)
  boosties = {},
  clients = {},  -- All-time client history
  removedBoosties = {},  -- Persist removed boosties across reloads
  announceEnabled = false,  -- Auto-announce after reset
  announceChannel = "PARTY",  -- PARTY or RAID
  announceWhisper = false,  -- Also whisper each boostie individually
  maxRuns = 5,  -- Max runs per boostie (for X/Y display)
  -- Configurable balance adjustment amount (in gold)
  balanceAdjust = 10,   -- Quick adjust amount for add/remove balance
  -- Announcement templates (EasyLife: prefix is added automatically)
  announceTemplates = {
    runsStarting = "Starting boost runs! {name} has {runs}/{max} runs.",
    runsRemaining = "{name} {runs}/{max}",
    runsDone = "All runs completed for {name}! Thank you!",
    freeRun = "FREE RUN for everyone! Enjoy!",
    custom = "",  -- Optional footer message after announcements
  },
}

-- Shared layout width for all Boostilator panels and rows
local PANEL_WIDTH = 520

local ui = {
  parent = nil,
  rows = {},
  clientRows = {},
  dropdown = nil,
  activeTab = "session",  -- "session" or "clients"
}

local tradeState = {
  partner = nil,
  targetMoney = 0,
  bothAccepted = false,
}

local function ensureDB()
  EasyLifeDB = EasyLifeDB or {}
  EasyLifeDB.boostilator = EasyLifeDB.boostilator or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.boostilator[k] == nil then
      if type(v) == "table" then
        EasyLifeDB.boostilator[k] = {}
        for kk, vv in pairs(v) do
          EasyLifeDB.boostilator[k][kk] = vv
        end
      else
        EasyLifeDB.boostilator[k] = v
      end
    end
  end
  -- First-run detection
  if EasyLifeDB.boostilator._firstRunShown == nil then
    EasyLifeDB.boostilator._firstRunShown = false
  end
end

local function getDB()
  ensureDB()
  return EasyLifeDB.boostilator
end

local function trimRealm(name)
  if not name then return nil end
  return name:match("([^%-]+)") or name
end

local function formatGold(copper)
  copper = math.floor(copper or 0)
  local gold = math.floor(math.abs(copper) / 10000)
  if copper < 0 then
    return "|cffFF6666-" .. gold .. "g|r"
  elseif copper > 0 then
    return "|cff00FF00" .. gold .. "g|r"
  else
    return "|cff888888" .. gold .. "g|r"
  end
end

-- Get class color and level for a player
local function getPlayerClassInfo(name)
  -- First check if this is our current target
  if UnitExists("target") and UnitIsPlayer("target") then
    local targetName = UnitName("target")
    if targetName then
      local shortTarget = targetName:match("([^%-]+)") or targetName
      local checkName = name:match("([^%-]+)") or name
      if shortTarget == checkName then
        local _, class = UnitClass("target")
        local level = UnitLevel("target")
        local color = class and RAID_CLASS_COLORS[class]
        -- Don't return level 0, return nil instead
        if level and level > 0 then
          return level, color
        else
          return nil, color
        end
      end
    end
  end
  
  -- Try to get info from group
  local numGroup = GetNumGroupMembers()
  local isRaid = IsInRaid()
  
  for i = 1, numGroup do
    local unit = isRaid and ("raid" .. i) or (i == numGroup and "player" or "party" .. i)
    local unitName = UnitName(unit)
    if unitName then
      local shortName = unitName:match("([^%-]+)") or unitName
      local checkName = name:match("([^%-]+)") or name
      if shortName == checkName then
        local _, class = UnitClass(unit)
        local level = UnitLevel(unit)
        local color = class and RAID_CLASS_COLORS[class]
        -- Don't return level 0, return nil instead
        if level and level > 0 then
          return level, color
        else
          return nil, color
        end
      end
    end
  end
  return nil, nil
end

local function ensureBoostie(name)
  local db = getDB()
  -- Don't auto-create if this boostie was manually removed
  if db.removedBoosties and db.removedBoosties[name] then
    return nil
  end
  db.boosties[name] = db.boosties[name] or { runs = 0, pricePerRun = nil }
  return db.boosties[name]
end

local function ensureClient(name)
  local db = getDB()
  db.clients = db.clients or {}
  db.clients[name] = db.clients[name] or { totalRuns = 0, totalGold = 0 }
  return db.clients[name]
end

local function recordClientStats(name, runs, gold)
  if runs <= 0 then return end  -- Only record positive runs
  local client = ensureClient(name)
  client.totalRuns = (client.totalRuns or 0) + runs
  client.totalGold = (client.totalGold or 0) + gold
end

local function getPartyMembers()
  local members = {}
  if IsInRaid() then
    for i = 1, 40 do
      local unit = "raid" .. i
      if UnitExists(unit) then
        local name = trimRealm(UnitName(unit))
        if name and not UnitIsUnit(unit, "player") then
          table.insert(members, name)
        end
      end
    end
  else
    for i = 1, 4 do
      local unit = "party" .. i
      if UnitExists(unit) then
        local name = trimRealm(UnitName(unit))
        if name then
          table.insert(members, name)
        end
      end
    end
  end
  return members
end

local function findTradePartner()
  if TradeFrameRecipientNameText and TradeFrameRecipientNameText.GetText then
    local raw = TradeFrameRecipientNameText:GetText()
    if raw and raw ~= "" then
      return trimRealm(raw)
    end
  end
  return nil
end

-- Get boosties from DB (not auto-adding party members)
function Boostilator:GetBoostiesFromDB()
  local db = getDB()
  local activeBoosties = {}
  for name, data in pairs(db.boosties) do
    if not (db.removedBoosties and db.removedBoosties[name]) then
      table.insert(activeBoosties, name)
    end
  end
  table.sort(activeBoosties)
  return activeBoosties
end

-- Scan party/raid and add members to list
function Boostilator:ScanPartyMembers()
  local db = getDB()
  local members = getPartyMembers()
  local added = 0
  for _, name in ipairs(members) do
    -- Skip if this person was manually removed (respect user's choice)
    if db.removedBoosties and db.removedBoosties[name] then
      -- Don't add them back, they were intentionally removed
    elseif not db.boosties[name] then
      -- Only add if they're not already in the list and not removed
      db.boosties[name] = { runs = 0, pricePerRun = nil }
      added = added + 1
    end
  end
  if added > 0 then
    EasyLife:Print("|cff00FF00Added|r " .. added .. " party member(s) to boostie list", "Boostilator")
  else
    EasyLife:Print("|cff888888No new party members to add|r", "Boostilator")
  end
  self:RefreshUI()
end

function Boostilator:AdjustRuns(name, deltaRuns, cost)
  local db = getDB()
  local entry = ensureBoostie(name)
  
  -- When adding runs, set the price per run for this boostie
  if deltaRuns > 0 and cost and cost > 0 then
    -- Calculate price per run from the package cost
    local pricePerRunForPackage = math.floor(cost / deltaRuns)
    entry.pricePerRun = pricePerRunForPackage
    recordClientStats(name, deltaRuns, cost)
  end
  
  entry.runs = math.max(0, (entry.runs or 0) + deltaRuns)
  
  -- When runs reach 0, reset pricePerRun to default
  if entry.runs == 0 then
    entry.pricePerRun = nil
  end
  
  self:RefreshUI()
end

function Boostilator:AdjustBalance(name, deltaCopper)
  -- Balance is now auto-calculated from runs * pricePerRun
  -- This function now just adds/removes runs based on balance change
  local db = getDB()
  local entry = ensureBoostie(name)
  local pricePerRun = entry.pricePerRun or db.pricePerRun or 100000
  
  -- If adding positive balance (payment received), reduce runs
  if deltaCopper < 0 then
    -- Payment received - calculate runs covered
    local runsCovered = math.floor(math.abs(deltaCopper) / pricePerRun)
    if runsCovered > 0 then
      entry.runs = math.max(0, (entry.runs or 0) - runsCovered)
      if entry.runs == 0 then entry.pricePerRun = nil end
    end
  elseif deltaCopper > 0 then
    -- Adding debt - increase runs
    local runsToAdd = math.ceil(deltaCopper / pricePerRun)
    entry.runs = (entry.runs or 0) + runsToAdd
  end
  
  self:RefreshUI()
end

function Boostilator:ResetBoostie(name)
  local db = getDB()
  db.boosties[name] = { runs = 0, pricePerRun = nil }
  self:RefreshUI()
end

function Boostilator:RemoveBoostie(name)
  local db = getDB()
  db.boosties[name] = nil
  db.removedBoosties = db.removedBoosties or {}
  db.removedBoosties[name] = true  -- Track as removed (persists across reloads)
  EasyLife:Print("|cffFF6666Removed|r |cffFFFFFF" .. name .. "|r from boostie list", "Boostilator")
  CloseDropDownMenus()  -- Close the menu immediately
  self:RefreshUI()
end

function Boostilator:ApplyPayment(name, copper)
  if not name or copper <= 0 then return end
  local db = getDB()
  local entry = ensureBoostie(name)
  if not entry then
    -- Boostie was manually removed, just log the payment
    EasyLife:Print("Payment from |cffFFFFFF" .. name .. "|r: " .. formatGold(copper) .. " (not tracked)", "Boostilator")
    return
  end
  local pricePerRun = entry.pricePerRun or db.pricePerRun or 100000
  
  -- Calculate how many runs this payment covers
  local runsCovered = math.floor(copper / pricePerRun)
  if runsCovered > 0 then
    entry.runs = math.max(0, (entry.runs or 0) - runsCovered)
    if entry.runs == 0 then entry.pricePerRun = nil end
  end
  
  EasyLife:Print("Payment from |cffFFFFFF" .. name .. "|r: " .. formatGold(copper) .. " (" .. runsCovered .. " runs)", "Boostilator")
  self:RefreshUI()
end

-- Check if a player is in the current party/raid
local function isInParty(name)
  local members = getPartyMembers()
  for _, member in ipairs(members) do
    if member == name then return true end
  end
  return false
end

-- Add boostie manually
function Boostilator:AddBoostieManual(name)
  if not name or name == "" then return end
  
  local db = getDB()
  -- Remove from removed list if they were there
  db.removedBoosties = db.removedBoosties or {}
  db.removedBoosties[name] = nil
  -- Create the boostie entry
  db.boosties[name] = db.boosties[name] or { runs = 0, pricePerRun = nil }
  EasyLife:Print("|cff00FF00Added|r |cffFFFFFF" .. name .. "|r to boostie list", "Boostilator")
  self:RefreshUI()
end

-- Dialog for adding boostie
function Boostilator:ShowAddBoostieDialog()
  if ui.addDialog then
    ui.addDialog:Show()
    return
  end
  
  local dialog = CreateFrame("Frame", "EasyLifeBoostilatorAddDialog", UIParent, "BackdropTemplate")
  dialog:SetSize(250, 120)
  dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
  dialog:SetFrameStrata("DIALOG")
  dialog:SetFrameLevel(200)
  dialog:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  dialog:SetBackdropColor(0.1, 0.08, 0.05, 0.98)
  dialog:SetBackdropBorderColor(1, 0.85, 0.3, 1)
  dialog:SetMovable(true)
  dialog:EnableMouse(true)
  dialog:RegisterForDrag("LeftButton")
  dialog:SetScript("OnDragStart", dialog.StartMoving)
  dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
  dialog:SetClampedToScreen(true)
  ui.addDialog = dialog
  
  -- Title
  local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -12)
  title:SetText("|cffFFD700Add Boostie|r")
  
  -- Close button
  local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -2, -2)
  closeBtn:SetScript("OnClick", function() dialog:Hide() end)
  
  -- Name input label
  local nameLabel = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  nameLabel:SetPoint("TOPLEFT", 15, -38)
  nameLabel:SetText("Player name:")
  
  -- Name input
  local nameBg = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
  nameBg:SetPoint("TOPLEFT", 15, -52)
  nameBg:SetSize(218, 24)
  nameBg:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  nameBg:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
  nameBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  
  local nameEdit = CreateFrame("EditBox", nil, nameBg)
  nameEdit:SetPoint("TOPLEFT", 6, -4)
  nameEdit:SetPoint("BOTTOMRIGHT", -6, 4)
  nameEdit:SetFontObject("ChatFontNormal")
  nameEdit:SetAutoFocus(false)
  nameEdit:SetScript("OnEscapePressed", function(self) 
    self:ClearFocus()
    dialog:Hide()
  end)
  nameEdit:SetScript("OnEnterPressed", function(self)
    local name = self:GetText():trim()
    if name ~= "" then
      Boostilator:AddBoostieManual(name)
      self:SetText("")
      dialog:Hide()
    end
  end)
  dialog.nameEdit = nameEdit
  
  -- Add button
  local addBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  addBtn:SetSize(70, 22)
  addBtn:SetPoint("BOTTOMLEFT", 15, 10)
  addBtn:SetText("Add")
  addBtn:SetScript("OnClick", function()
    local name = nameEdit:GetText():trim()
    if name ~= "" then
      Boostilator:AddBoostieManual(name)
      nameEdit:SetText("")
      dialog:Hide()
    end
  end)
  
  -- Invite button
  local inviteBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  inviteBtn:SetSize(90, 22)
  inviteBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
  inviteBtn:SetText("Add & Invite")
  inviteBtn:SetScript("OnClick", function()
    local name = nameEdit:GetText():trim()
    if name ~= "" then
      Boostilator:AddBoostieManual(name)
      -- Invite to party/raid
      if not isInParty(name) then
        InviteUnit(name)
        EasyLife:Print("|cff00FFFF[Invite sent]|r " .. name, "Boostilator")
      end
      nameEdit:SetText("")
      dialog:Hide()
    end
  end)
  inviteBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Add & Invite")
    GameTooltip:AddLine("|cff888888Add to list and send party/raid invite|r")
    GameTooltip:Show()
  end)
  inviteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  
  -- Cancel button
  local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  cancelBtn:SetSize(60, 22)
  cancelBtn:SetPoint("BOTTOMRIGHT", -15, 10)
  cancelBtn:SetText("Cancel")
  cancelBtn:SetScript("OnClick", function()
    nameEdit:SetText("")
    dialog:Hide()
  end)
  
  dialog:Show()
  nameEdit:SetFocus()
end

-- Show input dialog for adding/removing balance (gold + runs)
local function showBalanceInputDialog(name, isAdd)
  local db = getDB()
  local entry = ensureBoostie(name)
  if not entry then return end
  
  local dialog = _G["BoostilatorBalanceInputDialog"]
  if not dialog then
    dialog = CreateFrame("Frame", "BoostilatorBalanceInputDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(280, 150)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(200)
    dialog:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dialog:SetBackdropColor(0.1, 0.08, 0.05, 0.98)
    dialog:SetBackdropBorderColor(1, 0.85, 0.3, 1)
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:SetClampedToScreen(true)
    
    dialog.title = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    dialog.title:SetPoint("TOP", 0, -12)
    
    dialog.label = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dialog.label:SetPoint("TOP", dialog.title, "BOTTOM", 0, -8)
    
    -- Gold input row
    dialog.goldLabel = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dialog.goldLabel:SetPoint("TOPLEFT", 40, -55)
    dialog.goldLabel:SetText("Gold:")
    
    dialog.goldInput = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    dialog.goldInput:SetSize(60, 22)
    dialog.goldInput:SetPoint("LEFT", dialog.goldLabel, "RIGHT", 8, 0)
    dialog.goldInput:SetAutoFocus(false)
    dialog.goldInput:SetNumeric(true)
    dialog.goldInput:SetMaxLetters(5)
    dialog.goldInput:SetJustifyH("CENTER")
    
    -- Runs input row
    dialog.runsLabel = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dialog.runsLabel:SetPoint("LEFT", dialog.goldInput, "RIGHT", 15, 0)
    dialog.runsLabel:SetText("Runs:")
    
    dialog.runsInput = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    dialog.runsInput:SetSize(40, 22)
    dialog.runsInput:SetPoint("LEFT", dialog.runsLabel, "RIGHT", 8, 0)
    dialog.runsInput:SetAutoFocus(false)
    dialog.runsInput:SetNumeric(true)
    dialog.runsInput:SetMaxLetters(3)
    dialog.runsInput:SetJustifyH("CENTER")
    
    -- Per-run price display
    dialog.priceInfo = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dialog.priceInfo:SetPoint("TOP", dialog.goldLabel, "BOTTOM", 60, -8)
    dialog.priceInfo:SetText("|cff888888= 0g per run|r")
    
    -- Update price info when inputs change
    local function updatePriceInfo()
      local gold = tonumber(dialog.goldInput:GetText()) or 0
      local runs = tonumber(dialog.runsInput:GetText()) or 0
      if runs > 0 and gold > 0 then
        local perRun = math.floor(gold / runs)
        dialog.priceInfo:SetText("|cff888888= " .. perRun .. "g per run|r")
      else
        dialog.priceInfo:SetText("|cff888888= 0g per run|r")
      end
    end
    
    dialog.goldInput:SetScript("OnTextChanged", updatePriceInfo)
    dialog.runsInput:SetScript("OnTextChanged", updatePriceInfo)
    
    dialog.okBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.okBtn:SetSize(60, 22)
    dialog.okBtn:SetPoint("BOTTOMLEFT", 40, 10)
    dialog.okBtn:SetText("OK")
    
    dialog.cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.cancelBtn:SetSize(60, 22)
    dialog.cancelBtn:SetPoint("BOTTOMRIGHT", -40, 10)
    dialog.cancelBtn:SetText("Cancel")
    dialog.cancelBtn:SetScript("OnClick", function()
      dialog:Hide()
    end)
    
    dialog.goldInput:SetScript("OnEnterPressed", function()
      dialog.runsInput:SetFocus()
    end)
    dialog.runsInput:SetScript("OnEnterPressed", function()
      dialog.okBtn:Click()
    end)
    dialog.goldInput:SetScript("OnEscapePressed", function()
      dialog:Hide()
    end)
    dialog.runsInput:SetScript("OnEscapePressed", function()
      dialog:Hide()
    end)
    
    local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() dialog:Hide() end)
  end
  
  dialog.boostieName = name
  dialog.isAdd = isAdd
  
  if isAdd then
    dialog.title:SetText("|cff00FF00+ Add Balance|r")
    dialog.label:SetText("Add for " .. name .. ":")
  else
    dialog.title:SetText("|cffFF6666- Remove Balance|r")
    dialog.label:SetText("Remove from " .. name .. ":")
  end
  
  dialog.goldInput:SetText("")
  dialog.runsInput:SetText("")
  dialog.priceInfo:SetText("|cff888888= 0g per run|r")
  
  dialog.okBtn:SetScript("OnClick", function()
    local gold = tonumber(dialog.goldInput:GetText()) or 0
    local runs = tonumber(dialog.runsInput:GetText()) or 0
    
    if runs > 0 then
      local copper = gold * 10000  -- Convert gold to copper
      local pricePerRun = runs > 0 and gold > 0 and math.floor(copper / runs) or (db.pricePerRun or 100000)
      
      if dialog.isAdd then
        -- Add runs with custom price per run
        entry.runs = (entry.runs or 0) + runs
        entry.pricePerRun = pricePerRun
        recordClientStats(name, runs, copper)
        EasyLife:Print("|cff00FF00Added " .. runs .. " runs (" .. gold .. "g)|r to " .. dialog.boostieName, "Boostilator")
      else
        -- Remove runs
        entry.runs = math.max(0, (entry.runs or 0) - runs)
        if entry.runs == 0 then entry.pricePerRun = nil end
        EasyLife:Print("|cffFF6666Removed " .. runs .. " runs|r from " .. dialog.boostieName, "Boostilator")
      end
      Boostilator:RefreshUI()
    end
    dialog:Hide()
  end)
  
  dialog:Show()
  dialog.goldInput:SetFocus()
end

-- Dropdown menu for boostie
local function initBoostieDropdown(self, level)
  local name = self.boostieName
  if not name then return end
  
  local db = getDB()
  local entry = ensureBoostie(name)
  
  level = level or 1
  
  if level == 1 then
    -- Header
    local info = UIDropDownMenu_CreateInfo()
    info.text = "|cffFFD700" .. name .. "|r"
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
    
    -- Current status (balance is auto-calculated)
    local pricePerRun = entry.pricePerRun or db.pricePerRun or 100000
    local calculatedBalance = (entry.runs or 0) * pricePerRun
    info = UIDropDownMenu_CreateInfo()
    info.text = "Runs: " .. (entry.runs or 0) .. " left  |  Balance: " .. formatGold(calculatedBalance)
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
    
    -- Separator
    info = UIDropDownMenu_CreateInfo()
    info.text = ""
    info.disabled = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
    
    -- Add balance (+)
    info = UIDropDownMenu_CreateInfo()
    info.text = "|cff00FF00+|r  Add Balance"
    info.notCheckable = true
    info.func = function()
      CloseDropDownMenus()
      showBalanceInputDialog(name, true)
    end
    UIDropDownMenu_AddButton(info, level)
    
    -- Remove balance (-)
    info = UIDropDownMenu_CreateInfo()
    info.text = "|cffFF6666-|r  Remove Balance"
    info.notCheckable = true
    info.func = function()
      CloseDropDownMenus()
      showBalanceInputDialog(name, false)
    end
    UIDropDownMenu_AddButton(info, level)
    
    -- Separator
    info = UIDropDownMenu_CreateInfo()
    info.text = ""
    info.disabled = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
    
    -- Reset
    info = UIDropDownMenu_CreateInfo()
    info.text = "|cffFF0000Reset|r"
    info.notCheckable = true
    info.func = function() Boostilator:ResetBoostie(name) end
    UIDropDownMenu_AddButton(info, level)
    
    -- Remove from list
    info = UIDropDownMenu_CreateInfo()
    info.text = "|cffFF0000Remove from List|r"
    info.notCheckable = true
    info.func = function() Boostilator:RemoveBoostie(name) end
    UIDropDownMenu_AddButton(info, level)
    
    -- Invite to party (only show if not in party)
    if not isInParty(name) then
      info = UIDropDownMenu_CreateInfo()
      info.text = ""
      info.disabled = true
      info.notCheckable = true
      UIDropDownMenu_AddButton(info, level)
      
      info = UIDropDownMenu_CreateInfo()
      info.text = "|cff00FFFFInvite to Party|r"
      info.notCheckable = true
      info.func = function() 
        InviteUnit(name)
        EasyLife:Print("|cff00FFFF[Invite sent]|r " .. name, "Boostilator")
        CloseDropDownMenus()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end
end

local function showBoostieMenu(row, name)
  if not ui.dropdown then
    ui.dropdown = CreateFrame("Frame", "EasyLifeBoostilatorDropdown", UIParent, "UIDropDownMenuTemplate")
  end
  ui.dropdown.boostieName = name
  ui.dropdown.displayMode = "MENU"
  UIDropDownMenu_Initialize(ui.dropdown, initBoostieDropdown, "MENU")
  ToggleDropDownMenu(1, nil, ui.dropdown, row, 0, 0)
  
  -- Auto-close when clicking elsewhere
  if not ui.closeHandler then
    ui.closeHandler = CreateFrame("Frame", nil, UIParent)
    ui.closeHandler:EnableMouse(true)
    ui.closeHandler:SetFrameStrata("FULLSCREEN_DIALOG")
    ui.closeHandler:SetFrameLevel(0)
    ui.closeHandler:SetAllPoints(UIParent)
    ui.closeHandler:SetScript("OnMouseDown", function(self)
      CloseDropDownMenus()
      self:Hide()
    end)
  end
  ui.closeHandler:Show()
  ui.closeHandler:SetFrameLevel(math.max(0, DropDownList1:GetFrameLevel() - 1))
end

-- Hook dropdown hide to also hide the close handler
hooksecurefunc("CloseDropDownMenus", function()
  if ui.closeHandler then
    ui.closeHandler:Hide()
  end
end)

-- Hide all globally-named floating frames (called on PLAYER_ENTERING_WORLD)
local function hideAllGlobalFrames()
  -- These frames are parented to UIParent and may persist across reloads
  local globalFrames = {
    "EasyLifeBoostilatorSettings",
    "EasyLifeBoostilatorAddDialog",
    "EasyLifeBoostilatorResetDialog",
    "EasyLifeBoostilatorDropdown",
    "BoostilatorNotifyFrame",
    "BoostilatorQueueFrame",
  }
  for _, frameName in ipairs(globalFrames) do
    local frame = _G[frameName]
    if frame and frame.Hide then
      frame:Hide()
    end
  end
  -- Also hide local ui references if they exist
  if ui.settingsPanel then ui.settingsPanel:Hide() end
  if ui.addDialog then ui.addDialog:Hide() end
  if ui.closeHandler then ui.closeHandler:Hide() end
  if ui.dropdown then CloseDropDownMenus() end
end

function Boostilator:RefreshUI()
  if not ui.parent or not ui.rows then return end
  local db = getDB()
  
  -- Handle tab visibility
  local isSession = (ui.activeTab == "session")
  
  if ui.sessionHeaders then ui.sessionHeaders:SetShown(isSession) end
  if ui.clientHeaders then ui.clientHeaders:SetShown(not isSession) end
  if ui.emptyText then ui.emptyText:Hide() end
  if ui.emptyClientsText then ui.emptyClientsText:Hide() end
  
  -- Hide all rows first
  for _, row in ipairs(ui.rows) do
    if row then row:Hide() end
  end
  for _, row in ipairs(ui.clientRows) do
    if row then row:Hide() end
  end
  
  if isSession then
    self:RefreshSessionUI()
  else
    self:RefreshClientsUI()
  end
end

function Boostilator:RefreshSessionUI()
  local db = getDB()
  local members = self:GetBoostiesFromDB()

  local layout = (function()
    local width = (ui.sessionHeaders and ui.sessionHeaders:GetWidth()) or PANEL_WIDTH
    width = math.max(360, width)
    local padding = 10
    local gap = 8  -- consistent gap between columns
    local nameWidth = 120
    local runsWidth = 70
    local priceWidth = 60
    local balanceWidth = 70
    local runsX = padding + nameWidth + gap
    local priceX = runsX + runsWidth + gap
    local balanceX = priceX + priceWidth + gap
    return {
      width = width,
      padding = padding,
      nameWidth = nameWidth,
      runsWidth = runsWidth,
      priceWidth = priceWidth,
      balanceWidth = balanceWidth,
      runsX = runsX,
      priceX = priceX,
      balanceX = balanceX,
    }
  end)()

  if ui.sessionHeaderLabels then
    local h = ui.sessionHeaderLabels
    h.name:ClearAllPoints()
    h.name:SetPoint("LEFT", ui.sessionHeaders, "LEFT", layout.padding, 0)
    h.name:SetWidth(layout.nameWidth)
    h.name:SetJustifyH("LEFT")

    h.runs:ClearAllPoints()
    h.runs:SetPoint("LEFT", ui.sessionHeaders, "LEFT", layout.runsX, 0)
    h.runs:SetWidth(layout.runsWidth)
    h.runs:SetJustifyH("CENTER")

    h.price:ClearAllPoints()
    h.price:SetPoint("LEFT", ui.sessionHeaders, "LEFT", layout.priceX, 0)
    h.price:SetWidth(layout.priceWidth)
    h.price:SetJustifyH("CENTER")

    h.owes:ClearAllPoints()
    h.owes:SetPoint("LEFT", ui.sessionHeaders, "LEFT", layout.balanceX, 0)
    h.owes:SetWidth(layout.balanceWidth)
    h.owes:SetJustifyH("RIGHT")
  end

  -- Update summary
  if ui.summaryText then
    local totalOwed = 0
    for _, name in ipairs(members) do
      local e = db.boosties[name]
      if e then
        local pricePerRun = e.pricePerRun or db.pricePerRun or 100000
        totalOwed = totalOwed + ((e.runs or 0) * pricePerRun)
      end
    end
    ui.summaryText:SetText("|cffFFD700" .. #members .. "|r boosties  |  Total owed: " .. formatGold(totalOwed))
  end

  for i = 1, #members do
    local name = members[i]
    local entry = db.boosties[name] or { runs = 0, pricePerRun = nil }
    local row = ui.rows[i]
    
    if not row then
      -- Create row
      row = CreateFrame("Button", nil, ui.parent)
      row:SetHeight(32)
      if i == 1 then
        row:SetPoint("TOPLEFT", ui.sessionHeaders, "BOTTOMLEFT", 0, -6)
        row:SetPoint("TOPRIGHT", ui.sessionHeaders, "BOTTOMRIGHT", 0, -6)
      else
        row:SetPoint("TOPLEFT", ui.rows[i - 1], "BOTTOMLEFT", 0, -1)
        row:SetPoint("TOPRIGHT", ui.rows[i - 1], "BOTTOMRIGHT", 0, -1)
      end
      row:EnableMouse(true)
      row:RegisterForClicks("RightButtonUp")
      
      -- Background - Blizzard list style
      row.bg = row:CreateTexture(nil, "BACKGROUND")
      row.bg:SetAllPoints()
      row.bg:SetColorTexture(0.06, 0.06, 0.06, 0.75)
      
      -- Border line at bottom
      row.border = row:CreateTexture(nil, "BORDER")
      row.border:SetPoint("BOTTOMLEFT", 2, 0)
      row.border:SetPoint("BOTTOMRIGHT", -2, 0)
      row.border:SetHeight(1)
      row.border:SetColorTexture(0.25, 0.25, 0.25, 0.45)
      
      -- Highlight - subtle light overlay
      row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
      row.highlight:SetAllPoints()
      row.highlight:SetColorTexture(1, 1, 1, 0.12)
      
      -- Name
      row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      row.nameText:SetJustifyH("LEFT")

      -- Runs
      row.runsText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      row.runsText:SetJustifyH("CENTER")

      -- Price per run
      row.priceText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      row.priceText:SetJustifyH("CENTER")

      -- Balance
      row.balanceText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      row.balanceText:SetJustifyH("RIGHT")
      
      -- Right-click hint
      row.hint = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      row.hint:SetPoint("RIGHT", -12, 0)
      row.hint:SetText("|cff666666>>|r")
      
      ui.rows[i] = row
    end
    
    row.nameText:ClearAllPoints()
    row.nameText:SetPoint("LEFT", layout.padding, 0)
    row.nameText:SetWidth(layout.nameWidth)
    row.runsText:ClearAllPoints()
    row.runsText:SetPoint("LEFT", layout.runsX, 0)
    row.runsText:SetWidth(layout.runsWidth)
    row.priceText:ClearAllPoints()
    row.priceText:SetPoint("LEFT", layout.priceX, 0)
    row.priceText:SetWidth(layout.priceWidth)
    row.balanceText:ClearAllPoints()
    row.balanceText:SetPoint("LEFT", layout.balanceX, 0)
    row.balanceText:SetWidth(layout.balanceWidth)

    -- Update row data
    local level, classColor = getPlayerClassInfo(name)
    local nameDisplay
    if classColor then
      local r, g, b = classColor.r, classColor.g, classColor.b
      local hexColor = string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
      if level then
        nameDisplay = "|cff" .. hexColor .. name .. "|r |cff888888[" .. level .. "]|r"
      else
        nameDisplay = "|cff" .. hexColor .. name .. "|r"
      end
    else
      if level then
        nameDisplay = "|cffFFFFFF" .. name .. "|r |cff888888[" .. level .. "]|r"
      else
        nameDisplay = "|cffFFFFFF" .. name .. "|r"
      end
    end
    row.nameText:SetText(nameDisplay)
    row.runsText:SetText("|cffFFD700" .. (entry.runs or 0) .. " left|r")
    
    -- Price per run (default to global setting if not set)
    local pricePerRun = entry.pricePerRun or db.pricePerRun or 100000
    row.priceText:SetText("|cff888888" .. math.floor(pricePerRun / 10000) .. "g|r")
    
    -- Balance = runs * pricePerRun (auto-calculated)
    local calculatedBalance = (entry.runs or 0) * pricePerRun
    row.balanceText:SetText(formatGold(calculatedBalance))
    
    -- Row background color based on balance status
    if calculatedBalance > 0 then
      row.bg:SetColorTexture(0.10, 0.06, 0.06, 0.78)  -- Reddish - owes money
    elseif calculatedBalance < 0 then
      row.bg:SetColorTexture(0.06, 0.10, 0.06, 0.78)  -- Greenish - overpaid
    else
      row.bg:SetColorTexture(0.06, 0.06, 0.06, 0.75)  -- Neutral - settled
    end
    
    -- Click handler
    row:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        showBoostieMenu(self, name)
      end
    end)
    
    -- Tooltip
    local entryPrice = entry.pricePerRun or db.pricePerRun or 100000
    local entryBalance = (entry.runs or 0) * entryPrice
    row:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("|cffFFD700" .. name .. "|r")
      GameTooltip:AddLine(" ")
      GameTooltip:AddDoubleLine("Runs left:", tostring(entry.runs or 0), 1,1,1, 1,0.8,0)
      GameTooltip:AddDoubleLine("Price/run:", math.floor(entryPrice / 10000) .. "g", 1,1,1, 0.6,0.6,0.6)
      GameTooltip:AddDoubleLine("Balance:", formatGold(entryBalance), 1,1,1, 1,1,1)
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("|cff888888Right-click for options|r")
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    row:Show()
  end
  
  -- Show empty message if no members
  if ui.emptyText then
    if #members == 0 then
      ui.emptyText:Show()
    end
  end
end

function Boostilator:RefreshClientsUI()
  local db = getDB()
  db.clients = db.clients or {}

  local layout = (function()
    local width = (ui.clientHeaders and ui.clientHeaders:GetWidth()) or PANEL_WIDTH
    width = math.max(360, width)
    local padding = 14
    local nameWidth = math.max(180, math.floor(width * 0.46))
    local runsWidth = 90
    local used = padding + nameWidth + 14 + runsWidth + 14
    local remaining = width - used - 30
    local goldWidth = math.max(90, remaining)
    local runsX = padding + nameWidth + 14
    local goldX = runsX + runsWidth + 14
    return {
      width = width,
      padding = padding,
      nameWidth = nameWidth,
      runsWidth = runsWidth,
      goldWidth = goldWidth,
      runsX = runsX,
      goldX = goldX,
    }
  end)()

  if ui.clientHeaderLabels then
    local h = ui.clientHeaderLabels
    h.name:ClearAllPoints()
    h.name:SetPoint("LEFT", ui.clientHeaders, "LEFT", layout.padding, 0)
    h.name:SetWidth(layout.nameWidth)
    h.name:SetJustifyH("LEFT")

    h.runs:ClearAllPoints()
    h.runs:SetPoint("LEFT", ui.clientHeaders, "LEFT", layout.runsX, 0)
    h.runs:SetWidth(layout.runsWidth)
    h.runs:SetJustifyH("CENTER")

    h.gold:ClearAllPoints()
    h.gold:SetPoint("LEFT", ui.clientHeaders, "LEFT", layout.goldX, 0)
    h.gold:SetWidth(layout.goldWidth)
    h.gold:SetJustifyH("RIGHT")
  end
  
  -- Sort clients by total gold (descending)
  local sortedClients = {}
  for name, data in pairs(db.clients) do
    table.insert(sortedClients, { name = name, totalRuns = data.totalRuns or 0, totalGold = data.totalGold or 0 })
  end
  table.sort(sortedClients, function(a, b) return a.totalGold > b.totalGold end)
  
  -- Update summary
  if ui.summaryText then
    local totalGold = 0
    local totalRuns = 0
    for _, c in ipairs(sortedClients) do
      totalGold = totalGold + c.totalGold
      totalRuns = totalRuns + c.totalRuns
    end
    ui.summaryText:SetText("|cffFFD700" .. #sortedClients .. "|r clients  |  " .. totalRuns .. " runs  |  " .. formatGold(totalGold) .. " total")
  end
  
  for i, client in ipairs(sortedClients) do
    local row = ui.clientRows[i]
    
    if not row then
      -- Create client row
      row = CreateFrame("Button", nil, ui.parent)
      row:SetHeight(28)
      if i == 1 then
        row:SetPoint("TOPLEFT", ui.clientHeaders, "BOTTOMLEFT", 0, -6)
        row:SetPoint("TOPRIGHT", ui.clientHeaders, "BOTTOMRIGHT", 0, -6)
      else
        row:SetPoint("TOPLEFT", ui.clientRows[i - 1], "BOTTOMLEFT", 0, -1)
        row:SetPoint("TOPRIGHT", ui.clientRows[i - 1], "BOTTOMRIGHT", 0, -1)
      end
      row:EnableMouse(true)
      
      -- Background - Blizzard list style
      row.bg = row:CreateTexture(nil, "BACKGROUND")
      row.bg:SetAllPoints()
      row.bg:SetColorTexture(0.06, 0.06, 0.06, 0.75)
      
      -- Border line at bottom
      row.border = row:CreateTexture(nil, "BORDER")
      row.border:SetPoint("BOTTOMLEFT", 2, 0)
      row.border:SetPoint("BOTTOMRIGHT", -2, 0)
      row.border:SetHeight(1)
      row.border:SetColorTexture(0.25, 0.25, 0.25, 0.45)
      
      -- Highlight - subtle light overlay
      row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
      row.highlight:SetAllPoints()
      row.highlight:SetColorTexture(1, 1, 1, 0.12)
      
      -- Name
      row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      row.nameText:SetJustifyH("LEFT")
      
      -- Total Runs
      row.runsText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      row.runsText:SetJustifyH("CENTER")
      
      -- Total Gold
      row.goldText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      row.goldText:SetJustifyH("RIGHT")
      
      -- Rank indicator
      row.rank = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      row.rank:SetPoint("RIGHT", -12, 0)
      
      ui.clientRows[i] = row
    end
    
    row.nameText:ClearAllPoints()
    row.nameText:SetPoint("LEFT", layout.padding, 0)
    row.nameText:SetWidth(layout.nameWidth)
    row.runsText:ClearAllPoints()
    row.runsText:SetPoint("LEFT", layout.runsX, 0)
    row.runsText:SetWidth(layout.runsWidth)
    row.goldText:ClearAllPoints()
    row.goldText:SetPoint("LEFT", layout.goldX, 0)
    row.goldText:SetWidth(layout.goldWidth)

    -- Update row data
    row.nameText:SetText("|cffFFFFFF" .. client.name .. "|r")
    row.runsText:SetText("|cffFFD700" .. client.totalRuns .. "|r")
    row.goldText:SetText(formatGold(client.totalGold))
    
    -- Rank badge - WoW themed colors
    if i == 1 then
      row.rank:SetText("|cffFFD700#1|r")  -- Gold
      row.bg:SetColorTexture(0.18, 0.15, 0.05, 0.8)
    elseif i == 2 then
      row.rank:SetText("|cffC0C0C0#2|r")  -- Silver
      row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.8)
    elseif i == 3 then
      row.rank:SetText("|cffCD7F32#3|r")  -- Bronze
      row.bg:SetColorTexture(0.12, 0.08, 0.04, 0.8)
    else
      row.rank:SetText("|cff888888#" .. i .. "|r")
      row.bg:SetColorTexture(0.08, 0.07, 0.05, 0.8)
    end
    
    -- Tooltip
    local cName = client.name
    local cRuns = client.totalRuns
    local cGold = client.totalGold
    row:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("|cffFFD700" .. cName .. "|r")
      GameTooltip:AddLine(" ")
      GameTooltip:AddDoubleLine("Total Runs:", tostring(cRuns), 1,1,1, 1,0.8,0)
      GameTooltip:AddDoubleLine("Total Gold:", formatGold(cGold), 1,1,1, 1,1,1)
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("|cff888888Right-click to remove|r")
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Right-click to remove client
    row:RegisterForClicks("RightButtonUp")
    row:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        -- Show confirmation dialog
        StaticPopupDialogs["BOOSTILATOR_REMOVE_CLIENT"] = {
          text = "Remove |cffFFD700" .. cName .. "|r from All Clients?\n\nTotal: " .. cRuns .. " runs, " .. formatGold(cGold),
          button1 = "Remove",
          button2 = "Cancel",
          OnAccept = function()
            db.clients[cName] = nil
            EasyLife:Print("|cffFF6666Removed " .. cName .. " from All Clients|r", "Boostilator")
            Boostilator:RefreshUI()
          end,
          timeout = 0,
          whileDead = true,
          hideOnEscape = true,
          preferredIndex = 3,
        }
        StaticPopup_Show("BOOSTILATOR_REMOVE_CLIENT")
      end
    end)
    
    row:Show()
  end
  
  -- Show empty message if no clients
  if ui.emptyClientsText then
    if #sortedClients == 0 then
      ui.emptyClientsText:Show()
    end
  end
end

-- Cleanup function to hide UI elements parented to UIParent
function Boostilator:CleanupUI()
  if ui.settingsPanel then
    ui.settingsPanel:Hide()
  end
  if ui.closeHandler then
    ui.closeHandler:Hide()
  end
  if ui.dropdown then
    CloseDropDownMenus()
  end
  if ui.addDialog then
    ui.addDialog:Hide()
  end
  -- Hide header frames
  if ui.sessionHeaders then
    ui.sessionHeaders:Hide()
  end
  if ui.clientHeaders then
    ui.clientHeaders:Hide()
  end
  if ui.emptyText then
    ui.emptyText:Hide()
  end
  -- Also hide all rows explicitly and unparent them
  for _, row in ipairs(ui.rows or {}) do
    if row then 
      row:Hide()
      row:SetParent(nil)
    end
  end
  for _, row in ipairs(ui.clientRows or {}) do
    if row then 
      row:Hide()
      row:SetParent(nil)
    end
  end
  -- Clear the arrays
  ui.rows = {}
  ui.clientRows = {}
end

function Boostilator:BuildConfigUI(parent)
  ensureDB()
  
  -- Auto-scan party/raid members when UI opens
  if IsInGroup() or IsInRaid() then
    local db = getDB()
    local members = getPartyMembers()
    local added = 0
    for _, name in ipairs(members) do
      -- Only add if not in removed list and not already tracked
      if not (db.removedBoosties and db.removedBoosties[name]) then
        if not db.boosties[name] then
          db.boosties[name] = { runs = 0, pricePerRun = nil }
          added = added + 1
        end
      end
    end
    if added > 0 then
      EasyLife:Print("|cff00FF00Auto-added|r " .. added .. " party member(s) to boostie list", "Boostilator")
    end
  end
  
  -- Hide and clear ALL old rows before doing anything else
  if ui.rows then
    for _, row in ipairs(ui.rows) do
      if row then 
        row:Hide()
        row:SetParent(nil)  -- Unparent to fully release
      end
    end
  end
  if ui.clientRows then
    for _, row in ipairs(ui.clientRows) do
      if row then 
        row:Hide()
        row:SetParent(nil)
      end
    end
  end
  
  ui.parent = parent
  ui.rows = {}
  ui.clientRows = {}

  local db = getDB()
  local yStart = -8
  
  -- Show first-run popup if needed
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("Boostilator", "BOOST_TITLE", "BOOST_FIRST_RUN_DETAILED", db)
  end
  
  -- Hook parent hide to cleanup floating UI elements (only once per parent)
  if not parent.boostilatorHooked then
    parent.boostilatorHooked = true
    parent:HookScript("OnHide", function()
      Boostilator:CleanupUI()
    end)
  end
  
  -- Header - Blizzard panel styling
  local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yStart)
  header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yStart)
  header:SetHeight(50)
  header:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  header:SetBackdropColor(0.04, 0.04, 0.04, 0.98)
  header:SetBackdropBorderColor(0.8, 0.7, 0.4, 1)
  
  local title = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -8)
  title:SetText("|cffFFD700Boostilator|r")
  
  -- Price display (stored in ui for updating when settings change)
  ui.priceText = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  ui.priceText:SetPoint("TOP", title, "BOTTOM", 0, -4)
  local p1 = math.floor((db.pricePerRun or 100000) / 10000)
  local p5 = math.floor((db.price5Runs or 450000) / 10000)
  local p10 = math.floor((db.price10Runs or 800000) / 10000)
  ui.priceText:SetText("|cff888888x1:|r " .. p1 .. "g  |cff888888x5:|r " .. p5 .. "g  |cff888888x10:|r " .. p10 .. "g")
  
  -- Settings button
  local settingsBtn = CreateFrame("Button", nil, header)
  settingsBtn:SetSize(20, 20)
  settingsBtn:SetPoint("TOPRIGHT", -8, -8)
  settingsBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  settingsBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  settingsBtn:SetScript("OnClick", function()
    if ui.settingsPanel then
      ui.settingsPanel:SetShown(not ui.settingsPanel:IsShown())
    end
  end)
  settingsBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Edit Prices")
    GameTooltip:Show()
  end)
  settingsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  
  -- Settings panel (hidden by default) - WoW themed
  -- Reuse existing global frame if it exists (persists across reloads)
  local settings = _G["EasyLifeBoostilatorSettings"]
  if not settings then
    settings = CreateFrame("Frame", "EasyLifeBoostilatorSettings", UIParent, "BackdropTemplate")
    settings:SetSize(340, 420)
    settings:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    settings:SetFrameStrata("DIALOG")
    settings:SetFrameLevel(100)
    settings:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    settings:SetBackdropColor(0.1, 0.08, 0.05, 0.98)
    settings:SetBackdropBorderColor(1, 0.85, 0.3, 1)
    settings:SetMovable(true)
    settings:EnableMouse(true)
    settings:EnableKeyboard(false)  -- Don't capture keyboard input
    settings:SetPropagateKeyboardInput(true)  -- Let keyboard input pass through
    settings:RegisterForDrag("LeftButton")
    settings:SetScript("OnDragStart", settings.StartMoving)
    settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
    settings:SetClampedToScreen(true)
  end
  settings:Hide()  -- Always hide on UI build
  ui.settingsPanel = settings
  
  -- Settings title
  local settingsTitle = settings:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  settingsTitle:SetPoint("TOP", 0, -12)
  settingsTitle:SetText("|cffFFD700Settings|r")
  
  -- Close button for settings
  local closeSettings = CreateFrame("Button", nil, settings, "UIPanelCloseButton")
  closeSettings:SetPoint("TOPRIGHT", -2, -2)
  closeSettings:SetScript("OnClick", function() settings:Hide() end)
  
  -- Price inputs in settings panel
  local function makeInput(labelText, x, y, defaultVal)
    local lbl = settings:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", x, y)
    lbl:SetText(labelText)
    
    local input = CreateFrame("EditBox", nil, settings, "InputBoxTemplate")
    input:SetSize(50, 20)
    input:SetPoint("TOPLEFT", x + 35, y + 2)
    input:SetAutoFocus(false)
    input:SetNumeric(true)
    input:SetMaxLetters(4)
    input:SetText(tostring(defaultVal))
    input:SetJustifyH("CENTER")
    return input
  end
  
  local input1 = makeInput("x1:", 15, -32, p1)
  local input5 = makeInput("x5:", 115, -32, p5)
  local input10 = makeInput("x10:", 215, -32, p10)
  
  -- Separator
  local sep = settings:CreateTexture(nil, "ARTWORK")
  sep:SetSize(310, 1)
  sep:SetPoint("TOP", 0, -58)
  sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)
  
  -- Announce section title
  local announceLbl = settings:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  announceLbl:SetPoint("TOPLEFT", 15, -68)
  announceLbl:SetText("|cffFFD700Announce Settings|r")
  
  -- Announce enabled checkbox (using UICheckButtonTemplate like Party/Raid)
  local announceCheck = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")
  announceCheck:SetSize(22, 22)
  announceCheck:SetPoint("TOPLEFT", 15, -85)
  announceCheck:SetChecked(db.announceEnabled or false)
  
  local announceCheckLbl = settings:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  announceCheckLbl:SetPoint("LEFT", announceCheck, "RIGHT", 2, 0)
  announceCheckLbl:SetText("Auto-announce on reset")
  
  -- Channel selection
  local channelLbl = settings:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  channelLbl:SetPoint("TOPLEFT", 15, -108)
  channelLbl:SetText("Channel:")
  
  local partyBtn = CreateFrame("CheckButton", nil, settings, "UIRadioButtonTemplate")
  partyBtn:SetSize(20, 20)
  partyBtn:SetPoint("TOPLEFT", 65, -105)
  partyBtn:SetChecked((db.announceChannel or "PARTY") == "PARTY")
  
  local partyBtnLbl = settings:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  partyBtnLbl:SetPoint("LEFT", partyBtn, "RIGHT", 2, 0)
  partyBtnLbl:SetText("Party")
  
  local raidBtn = CreateFrame("CheckButton", nil, settings, "UIRadioButtonTemplate")
  raidBtn:SetSize(20, 20)
  raidBtn:SetPoint("TOPLEFT", 130, -105)
  raidBtn:SetChecked((db.announceChannel or "PARTY") == "RAID")
  
  local raidBtnLbl = settings:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  raidBtnLbl:SetPoint("LEFT", raidBtn, "RIGHT", 2, 0)
  raidBtnLbl:SetText("Raid")
  
  -- Radio button behavior
  partyBtn:SetScript("OnClick", function()
    partyBtn:SetChecked(true)
    raidBtn:SetChecked(false)
  end)
  raidBtn:SetScript("OnClick", function()
    raidBtn:SetChecked(true)
    partyBtn:SetChecked(false)
  end)
  
  -- Whisper each boostie checkbox
  local whisperCheck = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")
  whisperCheck:SetSize(22, 22)
  whisperCheck:SetPoint("TOPLEFT", 15, -122)
  whisperCheck:SetChecked(db.announceWhisper or false)
  
  local whisperCheckLbl = settings:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  whisperCheckLbl:SetPoint("LEFT", whisperCheck, "RIGHT", 2, 0)
  whisperCheckLbl:SetText("Also whisper each boostie")
  
  -- Separator 2
  local sep2 = settings:CreateTexture(nil, "ARTWORK")
  sep2:SetPoint("TOPLEFT", 10, -148)
  sep2:SetSize(320, 1)
  sep2:SetColorTexture(0.3, 0.3, 0.3, 0.8)
  
  -- Announcement Templates section
  local templateLbl = settings:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  templateLbl:SetPoint("TOPLEFT", 15, -158)
  templateLbl:SetText("|cffFFD700Announcement Templates|r")
  
  local templateHint = settings:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  templateHint:SetPoint("TOPLEFT", 15, -172)
  templateHint:SetText("|cff888888Use: {name}, {runs}, {max} - All messages start with '[EasyLife]:'|r")
  
  -- Ensure templates exist in db
  db.announceTemplates = db.announceTemplates or {}
  for k, v in pairs(DEFAULTS.announceTemplates) do
    if not db.announceTemplates[k] then
      db.announceTemplates[k] = v
    end
  end
  
  -- Helper function to create template editbox
  local function CreateTemplateEdit(parent, y, label, key, width)
    local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 15, y)
    lbl:SetText(label .. ":")
    lbl:SetWidth(90)
    lbl:SetJustifyH("LEFT")
    
    -- Use InputBoxTemplate for proper text rendering/clearing behavior
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(width or 210, 20)
    edit:SetPoint("TOPLEFT", 105, y + 2)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetTextColor(1, 1, 1)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(200)
    edit:SetText(db.announceTemplates[key] or "")
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    -- Fix text rendering when cursor moves or text changes
    edit:SetScript("OnTextChanged", function(self)
      self:SetCursorPosition(self:GetCursorPosition())
    end)
    return edit
  end
  
  local templateStarting = CreateTemplateEdit(settings, -190, "Starting", "runsStarting")
  local templateRemaining = CreateTemplateEdit(settings, -215, "Remaining", "runsRemaining")
  local templateDone = CreateTemplateEdit(settings, -240, "Done", "runsDone")
  local templateFree = CreateTemplateEdit(settings, -265, "Free Run", "freeRun")
  local templateCustom = CreateTemplateEdit(settings, -290, "Footer (opt)", "custom")
  
  local saveBtn = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
  saveBtn:SetSize(80, 22)
  saveBtn:SetPoint("BOTTOM", 0, 10)
  saveBtn:SetText("Save")
  saveBtn:SetScript("OnClick", function()
    db.pricePerRun = (tonumber(input1:GetText()) or 10) * 10000
    db.price5Runs = (tonumber(input5:GetText()) or 45) * 10000
    db.price10Runs = (tonumber(input10:GetText()) or 80) * 10000
    db.announceEnabled = announceCheck:GetChecked()
    db.announceChannel = raidBtn:GetChecked() and "RAID" or "PARTY"
    db.announceWhisper = whisperCheck:GetChecked()
    -- Save templates
    db.announceTemplates = db.announceTemplates or {}
    db.announceTemplates.runsStarting = templateStarting:GetText()
    db.announceTemplates.runsRemaining = templateRemaining:GetText()
    db.announceTemplates.runsDone = templateDone:GetText()
    db.announceTemplates.freeRun = templateFree:GetText()
    db.announceTemplates.custom = templateCustom:GetText()
    -- Update the price text in header
    local np1 = math.floor(db.pricePerRun / 10000)
    local np5 = math.floor(db.price5Runs / 10000)
    local np10 = math.floor(db.price10Runs / 10000)
    if ui.priceText then
      ui.priceText:SetText("|cff888888x1:|r " .. np1 .. "g  |cff888888x5:|r " .. np5 .. "g  |cff888888x10:|r " .. np10 .. "g")
    end
    EasyLife:Print("|cff00FF00Settings saved!|r", "Boostilator")
    settings:Hide()
  end)
  
  -- Tab buttons - Blizzard panel styling
  local tabBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  tabBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 4)
  tabBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 4)
  tabBar:SetHeight(26)
  tabBar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  tabBar:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
  tabBar:SetBackdropBorderColor(0.5, 0.45, 0.25, 0.9)
  
  local function updateTabStyle()
    if ui.activeTab == "session" then
      ui.sessionTab:SetBackdropColor(0.18, 0.18, 0.18, 1)
      ui.sessionTab:SetBackdropBorderColor(0.9, 0.75, 0.35, 0.9)
      ui.sessionTab.text:SetTextColor(1, 0.9, 0.5)
      ui.clientsTab:SetBackdropColor(0.07, 0.07, 0.07, 0.85)
      ui.clientsTab:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.5)
      ui.clientsTab.text:SetTextColor(0.7, 0.7, 0.7)
    else
      ui.clientsTab:SetBackdropColor(0.18, 0.18, 0.18, 1)
      ui.clientsTab:SetBackdropBorderColor(0.9, 0.75, 0.35, 0.9)
      ui.clientsTab.text:SetTextColor(1, 0.9, 0.5)
      ui.sessionTab:SetBackdropColor(0.07, 0.07, 0.07, 0.85)
      ui.sessionTab:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.5)
      ui.sessionTab.text:SetTextColor(0.7, 0.7, 0.7)
    end
  end
  
  -- Session tab - WoW style
  ui.sessionTab = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
  ui.sessionTab:SetSize(165, 22)
  ui.sessionTab:SetPoint("LEFT", 4, 0)
  ui.sessionTab:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  ui.sessionTab.text = ui.sessionTab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  ui.sessionTab.text:SetPoint("CENTER", 0, 0)
  ui.sessionTab.text:SetText("Session")
  ui.sessionTab:SetScript("OnClick", function()
    ui.activeTab = "session"
    updateTabStyle()
    Boostilator:RefreshUI()
  end)
  
  -- Clients tab - WoW style
  ui.clientsTab = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
  ui.clientsTab:SetSize(165, 22)
  ui.clientsTab:SetPoint("LEFT", ui.sessionTab, "RIGHT", 2, 0)
  ui.clientsTab:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  ui.clientsTab.text = ui.clientsTab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  ui.clientsTab.text:SetPoint("CENTER", 0, 0)
  ui.clientsTab.text:SetText("All Clients")
  ui.clientsTab:SetScript("OnClick", function()
    ui.activeTab = "clients"
    updateTabStyle()
    Boostilator:RefreshUI()
  end)
  
  updateTabStyle()
  
  -- Summary bar - Blizzard pane
  local summaryBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  summaryBar:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, 1)
  summaryBar:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, 1)
  summaryBar:SetHeight(22)
  summaryBar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  summaryBar:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
  summaryBar:SetBackdropBorderColor(0.5, 0.45, 0.25, 0.7)
  
  ui.summaryText = summaryBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  ui.summaryText:SetPoint("CENTER", 0, 0)
  ui.summaryText:SetText("|cffFFD7000|r boosties")
  
  -- Button bar - Blizzard pane
  local buttonBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  buttonBar:SetPoint("TOPLEFT", summaryBar, "BOTTOMLEFT", 0, 1)
  buttonBar:SetPoint("TOPRIGHT", summaryBar, "BOTTOMRIGHT", 0, 1)
  buttonBar:SetHeight(26)
  buttonBar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  buttonBar:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
  buttonBar:SetBackdropBorderColor(0.5, 0.45, 0.25, 0.7)
  
  -- Scan party button (now at left since + is removed - auto-add happens on party join)
  local scanBtn = CreateFrame("Button", nil, buttonBar, "UIPanelButtonTemplate")
  scanBtn:SetSize(52, 20)
  scanBtn:SetPoint("LEFT", 8, 0)
  scanBtn:SetText("Scan")
  scanBtn:SetScript("OnClick", function() Boostilator:ScanPartyMembers() end)
  scanBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Scan Party")
    GameTooltip:AddLine("|cff888888Add current party/raid\nmembers to the list|r")
    GameTooltip:Show()
  end)
  scanBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  
  -- Announce button (dropdown)
  local announceBtn = CreateFrame("Button", nil, buttonBar, "UIPanelButtonTemplate")
  announceBtn:SetSize(80, 20)
  announceBtn:SetPoint("LEFT", scanBtn, "RIGHT", 4, 0)
  announceBtn:SetText("Announce")
  announceBtn:SetScript("OnClick", function(self) Boostilator:ShowAnnounceMenu(self) end)
  announceBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Announce")
    GameTooltip:AddLine("|cff888888Click for announcement options|r")
    GameTooltip:Show()
  end)
  announceBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  
  -- Session: Column headers
  ui.sessionHeaders = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  ui.sessionHeaders:SetPoint("TOPLEFT", buttonBar, "BOTTOMLEFT", 0, 1)
  ui.sessionHeaders:SetPoint("TOPRIGHT", buttonBar, "BOTTOMRIGHT", 0, 1)
  ui.sessionHeaders:SetHeight(22)
  ui.sessionHeaders:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  ui.sessionHeaders:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
  ui.sessionHeaders:SetBackdropBorderColor(0.45, 0.4, 0.25, 0.7)
  
  ui.sessionHeaderLabels = {
    name = ui.sessionHeaders:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"),
    runs = ui.sessionHeaders:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"),
    price = ui.sessionHeaders:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"),
    owes = ui.sessionHeaders:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"),
  }
  ui.sessionHeaderLabels.name:SetText("|cffD2B48CName|r")
  ui.sessionHeaderLabels.runs:SetText("|cffD2B48CRuns|r")
  ui.sessionHeaderLabels.price:SetText("|cffD2B48CPrice|r")
  ui.sessionHeaderLabels.owes:SetText("|cffD2B48CBalance|r")
  
  -- Clients: Column headers - WoW themed
  ui.clientHeaders = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  ui.clientHeaders:SetPoint("TOPLEFT", buttonBar, "BOTTOMLEFT", 0, 1)
  ui.clientHeaders:SetPoint("TOPRIGHT", buttonBar, "BOTTOMRIGHT", 0, 1)
  ui.clientHeaders:SetHeight(22)
  ui.clientHeaders:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  ui.clientHeaders:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
  ui.clientHeaders:SetBackdropBorderColor(0.45, 0.4, 0.25, 0.7)
  ui.clientHeaders:Hide()
  
  ui.clientHeaderLabels = {
    name = ui.clientHeaders:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"),
    runs = ui.clientHeaders:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"),
    gold = ui.clientHeaders:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"),
  }
  ui.clientHeaderLabels.name:SetText("|cffD2B48CName|r")
  ui.clientHeaderLabels.runs:SetText("|cffD2B48CTotal Runs|r")
  ui.clientHeaderLabels.gold:SetText("|cffD2B48CTotal Gold|r")
  
  -- Empty state messages
  ui.emptyText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  ui.emptyText:SetPoint("TOP", ui.sessionHeaders, "BOTTOM", 0, -40)
  ui.emptyText:SetText("|cff888888No party members\nJoin a group to track boosties|r")
  ui.emptyText:Hide()
  
  ui.emptyClientsText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  ui.emptyClientsText:SetPoint("TOP", ui.clientHeaders, "BOTTOM", 0, -40)
  ui.emptyClientsText:SetText("|cff888888No clients yet\nAdd runs to boosties to record them|r")
  ui.emptyClientsText:Hide()
  
  -- Initial refresh
  self:RefreshUI()
end

-- Deduct 1 run from all current party members (completing a run)
function Boostilator:AddRunToAll()
  local db = getDB()
  local members = getPartyMembers()
  local count = 0
  for _, name in ipairs(members) do
    -- Skip players who were manually removed
    if db.removedBoosties and db.removedBoosties[name] then
      -- Skip this player, they were removed
    else
      if db.boosties[name] and db.boosties[name].runs and db.boosties[name].runs > 0 then
        local entry = db.boosties[name]
        entry.runs = entry.runs - 1
        -- Balance is auto-calculated, no need to update
        if entry.runs == 0 then entry.pricePerRun = nil end
        count = count + 1
      end
    end
  end
  if count > 0 then
    EasyLife:Print("|cffFFD700Run completed!|r Deducted 1 run from |cff00FF00" .. count .. "|r boosties", "Boostilator")
    self:RefreshUI()
    -- Auto-announce if enabled
    if db.announceEnabled then
      self:AnnounceRuns("runsRemaining")
    end
  end
end

-- Format a template string with placeholders
local function formatTemplate(template, name, runs, maxRuns)
  local msg = template
  msg = msg:gsub("{name}", name or "")
  msg = msg:gsub("{runs}", tostring(runs or 0))
  msg = msg:gsub("{max}", tostring(maxRuns or 5))
  return msg
end

-- Announce runs to party/raid with template type (sends immediately)
function Boostilator:AnnounceRuns(templateType)
  local db = getDB()
  local members = getPartyMembers()
  local maxRuns = db.maxRuns or 5
  local channel = db.announceChannel or "PARTY"
  templateType = templateType or "runsRemaining"
  
  -- Ensure templates exist
  db.announceTemplates = db.announceTemplates or DEFAULTS.announceTemplates
  local template = db.announceTemplates[templateType] or "{name} {runs}/{max}"
  local customFooter = db.announceTemplates.custom or ""
  
  -- Check if we're in the right group type
  if channel == "RAID" and not IsInRaid() then
    channel = "PARTY"
  end
  if not IsInGroup() then
    EasyLife:Print("|cffFF6666Not in a group!|r", "Boostilator")
    return
  end
  
  -- Free run is a single message for everyone, no names
  if templateType == "freeRun" then
    local msg = "[EasyLife]: " .. template
    SendChatMessage(msg, channel)
    EasyLife:Print("|cff00FF00[Free Run]|r Announced!", "Boostilator")
    return
  end
  
  -- Build message parts for other announcement types
  local parts = {}
  for _, name in ipairs(members) do
    local entry = ensureBoostie(name)
    if entry then
      local runs = entry.runs or 0
      -- For "runsDone" only include those with 0 runs
      if templateType == "runsDone" then
        if runs == 0 then
          table.insert(parts, { name = name, runs = runs, msg = formatTemplate(template, name, runs, maxRuns) })
        end
      else
        table.insert(parts, { name = name, runs = runs, msg = formatTemplate(template, name, runs, maxRuns) })
      end
    end
  end
  
  if #parts == 0 then
    EasyLife:Print("|cffFF6666No boosties to announce!|r", "Boostilator")
    return
  end
  
  -- Send each boostie message immediately with EasyLife prefix
  local messageDelay = 0
  for i, part in ipairs(parts) do
    local msg = "[EasyLife]: " .. part.msg
    local ch = channel
    C_Timer.After(messageDelay, function()
      SendChatMessage(msg, ch)
    end)
    messageDelay = messageDelay + 0.3  -- Small delay between messages to avoid spam
  end
  
  -- Send footer message if configured
  if customFooter and customFooter ~= "" then
    C_Timer.After(messageDelay, function()
      SendChatMessage("[EasyLife]: " .. customFooter, channel)
    end)
    messageDelay = messageDelay + 0.3
  end
  
  -- Also whisper each boostie if enabled
  if db.announceWhisper then
    for _, part in ipairs(parts) do
      local entry = db.boosties[part.name]
      if entry then
        local runs = entry.runs or 0
        local whisperMsg = "[EasyLife]: You have " .. runs .. "/" .. maxRuns .. " runs remaining."
        if entry.balance and entry.balance > 0 then
          whisperMsg = whisperMsg .. " Balance: " .. math.floor(entry.balance / 10000) .. "g"
        end
        local targetName = part.name
        C_Timer.After(messageDelay, function()
          SendChatMessage(whisperMsg, "WHISPER", nil, targetName)
        end)
        messageDelay = messageDelay + 0.3
      end
    end
  end
  
  -- Show confirmation to user
  local typeNames = {
    runsStarting = "Starting",
    runsRemaining = "Remaining",
    runsDone = "Done",
  }
  local typeName = typeNames[templateType] or templateType
  EasyLife:Print("|cff00FF00[" .. typeName .. "]|r Sent " .. #parts .. " announcement(s)!", "Boostilator")
end

-- Show announce dropdown menu
local announceMenuFrame = nil
function Boostilator:ShowAnnounceMenu(anchorFrame)
  if not announceMenuFrame then
    announceMenuFrame = CreateFrame("Frame", "EasyLifeAnnounceMenuFrame", UIParent, "UIDropDownMenuTemplate")
  end
  
  UIDropDownMenu_Initialize(announceMenuFrame, function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    
    info.text = "|cffFFD700Announce Type|r"
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info)
    
    info = UIDropDownMenu_CreateInfo()
    info.text = "Runs Starting"
    info.notCheckable = true
    info.func = function() 
      CloseDropDownMenus()
      Boostilator:AnnounceRuns("runsStarting") 
    end
    UIDropDownMenu_AddButton(info)
    
    info = UIDropDownMenu_CreateInfo()
    info.text = "Runs Remaining"
    info.notCheckable = true
    info.func = function() 
      CloseDropDownMenus()
      Boostilator:AnnounceRuns("runsRemaining") 
    end
    UIDropDownMenu_AddButton(info)
    
    info = UIDropDownMenu_CreateInfo()
    info.text = "Runs Done"
    info.notCheckable = true
    info.func = function() 
      CloseDropDownMenus()
      Boostilator:AnnounceRuns("runsDone") 
    end
    UIDropDownMenu_AddButton(info)
    
    info = UIDropDownMenu_CreateInfo()
    info.text = "|cff00FF00Free Run|r"
    info.notCheckable = true
    info.func = function() 
      CloseDropDownMenus()
      Boostilator:AnnounceRuns("freeRun") 
    end
    UIDropDownMenu_AddButton(info)
    
    -- Cancel option
    info = UIDropDownMenu_CreateInfo()
    info.text = "|cff888888Cancel|r"
    info.notCheckable = true
    info.func = function() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info)
  end, "MENU")
  
  ToggleDropDownMenu(1, nil, announceMenuFrame, anchorFrame, 0, 0)
end

-- Confirmation dialog for instance reset
function Boostilator:ShowResetConfirmDialog()
  if ui.resetDialog then
    ui.resetDialog:Show()
    return
  end
  
  local dialog = CreateFrame("Frame", "EasyLifeBoostilatorResetDialog", UIParent, "BackdropTemplate")
  dialog:SetSize(280, 100)
  dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
  dialog:SetFrameStrata("DIALOG")
  dialog:SetFrameLevel(200)
  dialog:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  dialog:SetBackdropColor(0.1, 0.08, 0.05, 0.98)
  dialog:SetBackdropBorderColor(1, 0.85, 0.3, 1)
  dialog:EnableMouse(true)
  dialog:SetMovable(true)
  dialog:RegisterForDrag("LeftButton")
  dialog:SetScript("OnDragStart", dialog.StartMoving)
  dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
  
  ui.resetDialog = dialog
  
  -- Title
  local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -12)
  title:SetText("|cffFFD700Instance Reset!|r")
  
  -- Question
  local question = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  question:SetPoint("TOP", title, "BOTTOM", 0, -8)
  question:SetText("Count this run for boosties?")
  
  -- Yes button
  local yesBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  yesBtn:SetSize(80, 24)
  yesBtn:SetPoint("BOTTOMLEFT", 30, 12)
  yesBtn:SetText("Yes")
  yesBtn:SetScript("OnClick", function()
    dialog:Hide()
    Boostilator:AddRunToAll()
  end)
  
  -- No button
  local noBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  noBtn:SetSize(80, 24)
  noBtn:SetPoint("BOTTOMRIGHT", -30, 12)
  noBtn:SetText("No")
  noBtn:SetScript("OnClick", function()
    dialog:Hide()
    EasyLife:Print("|cff888888Run not counted.|r", "Boostilator")
  end)
  
  dialog:Show()
end

function Boostilator:OnEvent(event, ...)
  if event == "PLAYER_ENTERING_WORLD" then
    -- Hide all globally-named floating frames on zone change/reload
    hideAllGlobalFrames()
    self:RefreshUI()
  elseif event == "GROUP_ROSTER_UPDATE" then
    -- Auto-add new party/raid members when they join
    local db = getDB()
    if db.enabled then
      local members = getPartyMembers()
      for _, name in ipairs(members) do
        -- Only add if not removed and not already in list
        if not (db.removedBoosties and db.removedBoosties[name]) and not db.boosties[name] then
          db.boosties[name] = { runs = 0, pricePerRun = nil }
          EasyLife:Print("|cff00FF00Auto-added|r |cffFFFFFF" .. name .. "|r to boostie list", "Boostilator")
        end
      end
    end
    self:RefreshUI()
  elseif event == "CHAT_MSG_SYSTEM" then
    local msg = ...
    -- DEBUG: Print all system messages to help identify reset patterns
    if msg and (msg:lower():find("reset") or msg:lower():find("instance") or msg:lower():find("dungeon")) then
      EasyLife:Print("|cffFF00FF[DEBUG] System msg:|r " .. msg, "Boostilator")
    end
    
    -- Detect instance reset messages (both success and failure)
    -- English success: "X has been reset."
    -- English fail: "Cannot reset X. There are players still inside the instance."
    -- German: "wurde zurückgesetzt" / "kann nicht zurückgesetzt werden"
    -- Turkish: "sıfırlandı" / "sıfırlanamıyor"
    if msg then
      local isResetAttempt = false
      -- Success messages
      if msg:find("has been reset") or msg:find("wurde zurückgesetzt") or msg:find("sıfırlandı") then
        isResetAttempt = true
      end
      -- Failure messages (players still inside, etc.)
      if msg:find("Cannot reset") or msg:find("kann nicht zurückgesetzt") or msg:find("sıfırlanamıyor") then
        isResetAttempt = true
      end
      -- Alternative patterns
      if msg:find("players still inside") or msg:find("Spieler.*drin") or msg:find("inside the instance") then
        isResetAttempt = true
      end
      -- Catch-all for "reset" keyword in instance context
      if msg:find("instance") and msg:lower():find("reset") then
        isResetAttempt = true
      end
      -- Additional catch-all: any message containing "reset" as a word
      if msg:lower():find("reset") then
        isResetAttempt = true
      end
      
      if isResetAttempt then
        self:ShowResetConfirmDialog()
      end
    end
  elseif event == "TRADE_SHOW" then
    tradeState.partner = findTradePartner()
    tradeState.targetMoney = 0
    tradeState.bothAccepted = false
  elseif event == "TRADE_MONEY_CHANGED" then
    tradeState.targetMoney = GetTargetTradeMoney() or tradeState.targetMoney or 0
  elseif event == "TRADE_ACCEPT_UPDATE" then
    local playerAccepted, targetAccepted = ...
    tradeState.bothAccepted = (playerAccepted == 1 and targetAccepted == 1)
    if tradeState.bothAccepted then
      tradeState.targetMoney = GetTargetTradeMoney() or tradeState.targetMoney or 0
    end
  elseif event == "TRADE_CLOSED" then
    if tradeState.partner and tradeState.bothAccepted and tradeState.targetMoney and tradeState.targetMoney > 0 then
      self:ApplyPayment(tradeState.partner, tradeState.targetMoney)
    end
    tradeState.partner = nil
    tradeState.targetMoney = 0
    tradeState.bothAccepted = false
  elseif event == "TRADE_REQUEST_CANCEL" then
    tradeState.partner = nil
    tradeState.targetMoney = 0
    tradeState.bothAccepted = false
  end
end

-- Store event frame reference for UpdateState
local boostEventFrame = nil

-- Update module state (called when enabling/disabling from Module Manager)
function Boostilator:UpdateState()
  local db = getDB()
  
  if not db.enabled then
    -- Disable: unregister trade events (keep roster update for data integrity)
    if boostEventFrame then
      boostEventFrame:UnregisterEvent("TRADE_SHOW")
      boostEventFrame:UnregisterEvent("TRADE_MONEY_CHANGED")
      boostEventFrame:UnregisterEvent("TRADE_ACCEPT_UPDATE")
      boostEventFrame:UnregisterEvent("TRADE_CLOSED")
      boostEventFrame:UnregisterEvent("TRADE_REQUEST_CANCEL")
      boostEventFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
    end
  else
    -- Enable: register all trade events
    if boostEventFrame then
      boostEventFrame:RegisterEvent("TRADE_SHOW")
      boostEventFrame:RegisterEvent("TRADE_MONEY_CHANGED")
      boostEventFrame:RegisterEvent("TRADE_ACCEPT_UPDATE")
      boostEventFrame:RegisterEvent("TRADE_CLOSED")
      boostEventFrame:RegisterEvent("TRADE_REQUEST_CANCEL")
      boostEventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    end
  end
end

function Boostilator:OnRegister()
  ensureDB()
  boostEventFrame = CreateFrame("Frame")
  boostEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  boostEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
  boostEventFrame:RegisterEvent("TRADE_SHOW")
  boostEventFrame:RegisterEvent("TRADE_MONEY_CHANGED")
  boostEventFrame:RegisterEvent("TRADE_ACCEPT_UPDATE")
  boostEventFrame:RegisterEvent("TRADE_CLOSED")
  boostEventFrame:RegisterEvent("TRADE_REQUEST_CANCEL")
  boostEventFrame:RegisterEvent("CHAT_MSG_SYSTEM")  -- For instance reset detection
  boostEventFrame:SetScript("OnEvent", function(_, event, ...)
    Boostilator:OnEvent(event, ...)
  end)
end

EasyLife:RegisterModule("Boostilator", Boostilator)
