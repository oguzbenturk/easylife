-- EasyLife AutoHelper Module
-- Auto sell junk, auto repair, auto accept summons, smart junk management

local AutoHelper = {}

local DEFAULTS = {
  enabled = true,
  -- Junk selling
  autoSellJunk = true,
  -- Auto repair
  autoRepair = true,
  useGuildRepair = false,
  -- Auto summon
  autoAcceptSummon = true,
  summonDelay = 0.5,
  -- Smart destroy (when bag is full)
  smartDestroy = true,
  destroyMaxValue = 10000,    -- Maximum value to auto-destroy (default 1g)
  destroyOnlyGray = true,     -- Only destroy gray items
  protectLastSlots = 0,       -- Keep X slots free (don't fill completely)
}

-- ============================================================
-- API Compatibility Layer for Classic Era Anniversary
-- ============================================================
-- C_Container exists in Classic Era 1.15.x but we add fallbacks just in case

local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local GetContainerItemInfo = C_Container and C_Container.GetContainerItemInfo or function(bag, slot)
  -- Legacy API returns: icon, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID, isBound
  local icon, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID, isBound = _G.GetContainerItemInfo(bag, slot)
  if not icon then return nil end
  return {
    iconFileID = icon,
    stackCount = itemCount or 1,
    isLocked = locked,
    quality = quality,
    isReadable = readable,
    hasLoot = lootable,
    hyperlink = itemLink,
    isFiltered = isFiltered,
    hasNoValue = noValue,
    itemID = itemID,
    isBound = isBound,
  }
end
local GetContainerItemLink = C_Container and C_Container.GetContainerItemLink or _G.GetContainerItemLink
local UseContainerItem = C_Container and C_Container.UseContainerItem or _G.UseContainerItem
local PickupContainerItem = C_Container and C_Container.PickupContainerItem or _G.PickupContainerItem

local function L(key)
  return EasyLife:L(key)
end

local function ensureDB()
  if not EasyLifeDB then EasyLifeDB = {} end
  if not EasyLifeDB.autoHelper then EasyLifeDB.autoHelper = {} end
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.autoHelper[k] == nil then
      EasyLifeDB.autoHelper[k] = v
    end
  end
  if EasyLifeDB.autoHelper._firstRunShown == nil then
    EasyLifeDB.autoHelper._firstRunShown = false
  end
  return true
end

local function getDB()
  ensureDB()
  return EasyLifeDB.autoHelper
end

-- Format copper amount to gold/silver/copper string
local function FormatMoney(copper)
  if not copper or copper == 0 then return "|cffB873330c|r" end
  
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local copperRem = copper % 100
  
  local result = ""
  if gold > 0 then result = result .. "|cffFFD700" .. gold .. "g|r " end
  if silver > 0 then result = result .. "|cffC0C0C0" .. silver .. "s|r " end
  if copperRem > 0 or result == "" then result = result .. "|cffB87333" .. copperRem .. "c|r" end
  
  return result:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Get total free bag slots
local function GetFreeBagSlots()
  local freeSlots = 0
  for bag = 0, 4 do
    local numSlots = GetContainerNumSlots(bag)
    for slot = 1, numSlots do
      local info = GetContainerItemInfo(bag, slot)
      if not info then
        freeSlots = freeSlots + 1
      end
    end
  end
  return freeSlots
end

-- Find the cheapest junk item in bags that can be destroyed
local function FindCheapestJunk()
  local db = getDB()
  local cheapestBag, cheapestSlot = nil, nil
  local cheapestValue = math.huge
  local cheapestLink = nil
  local cheapestInfo = nil
  
  for bag = 0, 4 do
    local numSlots = GetContainerNumSlots(bag)
    for slot = 1, numSlots do
      local info = GetContainerItemInfo(bag, slot)
      if info then
        local isJunk = (info.quality == 0) -- Gray item
        local canDestroy = db.destroyOnlyGray and isJunk or (not db.destroyOnlyGray and info.quality <= 1)
        
        if canDestroy then
          local itemLink = GetContainerItemLink(bag, slot)
          if itemLink then
            local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
            local totalValue = (itemSellPrice or 0) * info.stackCount
            
            -- Check if within destroy value range
            if totalValue <= db.destroyMaxValue then
              if totalValue < cheapestValue then
                cheapestValue = totalValue
                cheapestBag = bag
                cheapestSlot = slot
                cheapestLink = itemLink
                cheapestInfo = info
              end
            end
          end
        end
      end
    end
  end
  
  if cheapestBag then
    return {
      bag = cheapestBag,
      slot = cheapestSlot,
      value = cheapestValue,
      link = cheapestLink,
      info = cheapestInfo
    }
  end
  return nil
end

-- Destroy a specific item
local function DestroyItem(bag, slot)
  ClearCursor()
  PickupContainerItem(bag, slot)
  DeleteCursorItem()
end

-- Destroy ALL junk items in bags (manual button)
local function DestroyAllJunk()
  local db = getDB()
  local totalDestroyed = 0
  local itemCount = 0
  local itemsToDestroy = {}
  
  -- First, collect all items to destroy (to avoid issues while iterating)
  for bag = 0, 4 do
    local numSlots = GetContainerNumSlots(bag)
    for slot = 1, numSlots do
      local info = GetContainerItemInfo(bag, slot)
      if info then
        local isJunk = (info.quality == 0) -- Gray item
        local canDestroy = db.destroyOnlyGray and isJunk or (not db.destroyOnlyGray and info.quality <= 1)
        
        if canDestroy then
          local itemLink = GetContainerItemLink(bag, slot)
          if itemLink then
            local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
            local totalValue = (itemSellPrice or 0) * info.stackCount
            
            -- Check if within destroy value range
            if totalValue <= db.destroyMaxValue then
              table.insert(itemsToDestroy, {
                bag = bag,
                slot = slot,
                value = totalValue,
                link = itemLink
              })
            end
          end
        end
      end
    end
  end
  
  -- Now destroy them with a small delay between each
  if #itemsToDestroy == 0 then
    EasyLife:Print(L("AUTOHELPER_NO_JUNK_TO_DESTROY"), "AutoHelper")
    return
  end
  
  for i, item in ipairs(itemsToDestroy) do
    C_Timer.After((i - 1) * 0.1, function()
      DestroyItem(item.bag, item.slot)
      totalDestroyed = totalDestroyed + item.value
      itemCount = itemCount + 1
      
      -- Print summary after last item
      if i == #itemsToDestroy then
        EasyLife:Print(L("AUTOHELPER_DESTROYED_JUNK"):format(#itemsToDestroy, FormatMoney(totalDestroyed)), "AutoHelper")
      end
    end)
  end
end

-- Smart loot: check if we should destroy junk to make room
local function SmartLootCheck(lootSlotIndex)
  local db = getDB()
  if not db.smartDestroy then return false end
  
  local freeSlots = GetFreeBagSlots()
  
  -- Check if we need to make room (accounting for protected slots)
  if freeSlots > db.protectLastSlots then
    return false -- We have room, no need to destroy
  end
  
  -- Get info about the item we're trying to loot
  local lootIcon, lootName, lootQuantity, currencyID, lootQuality, locked, isQuestItem = GetLootSlotInfo(lootSlotIndex)
  if not lootName or locked then return false end
  
  local lootLink = GetLootSlotLink(lootSlotIndex)
  if not lootLink then return false end
  
  local _, _, _, _, _, _, _, _, _, _, lootSellPrice = GetItemInfo(lootLink)
  local lootTotalValue = (lootSellPrice or 0) * (lootQuantity or 1)
  
  -- Find cheapest junk we can destroy
  local cheapestJunk = FindCheapestJunk()
  
  if not cheapestJunk then
    -- No junk to destroy
    return false
  end
  
  -- Compare values: only destroy if loot is worth MORE than junk
  if lootTotalValue > cheapestJunk.value then
    -- Destroy the cheap junk
    DestroyItem(cheapestJunk.bag, cheapestJunk.slot)
    EasyLife:Print(L("AUTOHELPER_DESTROYED_FOR_LOOT"):format(
      cheapestJunk.link, 
      FormatMoney(cheapestJunk.value),
      lootLink,
      FormatMoney(lootTotalValue)
    ), "AutoHelper")
    return true
  else
    -- Loot is worth less, don't destroy
    EasyLife:Print(L("AUTOHELPER_LOOT_NOT_WORTH"):format(
      lootLink,
      FormatMoney(lootTotalValue),
      FormatMoney(cheapestJunk.value)
    ), "AutoHelper")
    return false
  end
end

-- Sell all junk items in bags
local function SellJunk()
  local db = getDB()
  if not db.autoSellJunk then return end
  
  local totalSold = 0
  local itemCount = 0
  
  for bag = 0, 4 do
    local numSlots = GetContainerNumSlots(bag)
    for slot = 1, numSlots do
      local info = GetContainerItemInfo(bag, slot)
      if info and info.quality == 0 then -- 0 = Poor (gray/junk)
        local itemLink = GetContainerItemLink(bag, slot)
        local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
        if itemSellPrice and itemSellPrice > 0 then
          totalSold = totalSold + (itemSellPrice * info.stackCount)
          itemCount = itemCount + 1
          UseContainerItem(bag, slot)
        end
      end
    end
  end
  
  if itemCount > 0 then
    EasyLife:Print(L("AUTOHELPER_SOLD_JUNK"):format(itemCount, FormatMoney(totalSold)), "AutoHelper")
  end
end

-- Repair all gear
local function RepairGear()
  local db = getDB()
  if not db.autoRepair then return end
  if not CanMerchantRepair() then return end
  
  local repairCost, canRepair = GetRepairAllCost()
  if not canRepair or repairCost == 0 then return end
  
  local guildRepairUsed = false
  
  -- Try guild repair if enabled and in guild
  if db.useGuildRepair and IsInGuild() then
    -- Check if CanGuildBankRepair exists (Classic Era compatible)
    local canUseGuild = false
    if CanGuildBankRepair then
      canUseGuild = CanGuildBankRepair()
    elseif GetGuildBankWithdrawMoney then
      local guildBankMoney = GetGuildBankWithdrawMoney()
      canUseGuild = (guildBankMoney == -1 or guildBankMoney >= repairCost)
    end
    
    if canUseGuild then
      RepairAllItems(true)
      guildRepairUsed = true
    end
  end
  
  if not guildRepairUsed then
    local playerMoney = GetMoney()
    if playerMoney >= repairCost then
      RepairAllItems(false)
    else
      EasyLife:Print(L("AUTOHELPER_REPAIR_NO_MONEY"), "AutoHelper")
      return
    end
  end
  
  local source = guildRepairUsed and L("AUTOHELPER_GUILD_BANK") or L("AUTOHELPER_PERSONAL")
  EasyLife:Print(L("AUTOHELPER_REPAIRED"):format(FormatMoney(repairCost), source), "AutoHelper")
end

-- Accept summon (Classic Era compatible)
local function AcceptSummon()
  local db = getDB()
  if not db.autoAcceptSummon then return end
  
  -- Classic Era uses global functions, not C_SummonInfo
  local summoner = GetSummonConfirmSummoner and GetSummonConfirmSummoner()
  local area = GetSummonConfirmAreaName and GetSummonConfirmAreaName()
  
  if summoner and area then
    C_Timer.After(db.summonDelay, function()
      local timeLeft = GetSummonConfirmTimeLeft and GetSummonConfirmTimeLeft() or 0
      if timeLeft > 0 then
        if ConfirmSummon then
          ConfirmSummon()
        end
        EasyLife:Print(L("AUTOHELPER_SUMMON_ACCEPTED"):format(summoner, area), "AutoHelper")
      end
    end)
  end
end

-- Handle loot opened - check for full bags
local function OnLootOpened()
  local db = getDB()
  if not db.enabled or not db.smartDestroy then return end
  
  local freeSlots = GetFreeBagSlots()
  if freeSlots > db.protectLastSlots then return end -- Have room
  
  -- Check each loot slot
  local numLootItems = GetNumLootItems()
  for i = 1, numLootItems do
    local lootIcon, lootName, lootQuantity, currencyID, lootQuality, locked = GetLootSlotInfo(i)
    if lootName and not locked then
      -- Try smart destroy
      if SmartLootCheck(i) then
        -- Successfully destroyed something, try to loot after a tiny delay
        C_Timer.After(0.1, function()
          if GetNumLootItems() >= i then
            LootSlot(i)
          end
        end)
        break -- Only handle one item at a time
      end
    end
  end
end

-- Event frame
local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(self, event, ...)
  local db = getDB()
  
  if event == "PLAYER_ENTERING_WORLD" then
    ensureDB()
    local moduleEnabled = EasyLife_Config_IsModuleEnabled and EasyLife_Config_IsModuleEnabled("AutoHelper")
    if moduleEnabled == nil then moduleEnabled = true end
    if moduleEnabled and db.enabled then
      AutoHelper:Enable()
    end
  elseif event == "MERCHANT_SHOW" then
    if db.enabled then
      C_Timer.After(0.1, function()
        SellJunk()
        RepairGear()
      end)
    end
  elseif event == "CONFIRM_SUMMON" then
    if db.enabled then
      AcceptSummon()
    end
  elseif event == "LOOT_OPENED" then
    if db.enabled and db.smartDestroy then
      OnLootOpened()
    end
  elseif event == "UI_ERROR_MESSAGE" then
    local _, msg = ...
    if db.enabled and db.smartDestroy then
      -- Check for "Inventory is full" type messages
      if msg and (msg:find("full") or msg:find("FULL")) then
        OnLootOpened()
      end
    end
  end
end)

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

function AutoHelper:Enable()
  eventFrame:RegisterEvent("MERCHANT_SHOW")
  eventFrame:RegisterEvent("CONFIRM_SUMMON")
  eventFrame:RegisterEvent("LOOT_OPENED")
  eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
end

function AutoHelper:Disable()
  eventFrame:UnregisterEvent("MERCHANT_SHOW")
  eventFrame:UnregisterEvent("CONFIRM_SUMMON")
  eventFrame:UnregisterEvent("LOOT_OPENED")
  eventFrame:UnregisterEvent("UI_ERROR_MESSAGE")
end

function AutoHelper:UpdateState()
  local db = getDB()
  local moduleEnabled = EasyLife_Config_IsModuleEnabled and EasyLife_Config_IsModuleEnabled("AutoHelper")
  if moduleEnabled == nil then moduleEnabled = true end
  
  if moduleEnabled and db.enabled then
    self:Enable()
  else
    self:Disable()
  end
end

-- ============================================================
-- Beautiful Config UI Helpers
-- ============================================================

-- Helper: Create a styled section header with background
local function CreateSectionHeader(parent, text, yOffset, iconPath)
  local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  container:SetSize(360, 26)
  container:SetPoint("TOPLEFT", 10, yOffset)
  container:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  container:SetBackdropColor(0.1, 0.35, 0.1, 0.7)
  container:SetBackdropBorderColor(0.3, 0.6, 0.3, 0.9)
  
  local header = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("LEFT", 10, 0)
  header:SetText("|cff00FF00" .. text .. "|r")
  
  if iconPath then
    local icon = container:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("RIGHT", -8, 0)
    icon:SetTexture(iconPath)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Remove icon border
  end
  
  return container, yOffset - 30
end

-- Helper: Create a styled checkbox with tooltip
local function CreateStyledCheckbox(parent, x, yOffset, text, tooltip, checked, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", x, yOffset)
  cb:SetChecked(checked)
  cb.Text:SetText(text)
  cb.Text:SetFontObject("GameFontHighlight")
  
  if tooltip then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(text, 1, 1, 1)
      GameTooltip:AddLine(tooltip, 0.7, 0.7, 0.7, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  
  cb:SetScript("OnClick", function(self)
    if onClick then onClick(self:GetChecked()) end
  end)
  
  return cb, yOffset - 26
end

-- Helper: Create a styled slider with value display
local function CreateStyledSlider(parent, x, yOffset, width, label, minVal, maxVal, step, currentVal, formatFunc, onChange)
  local container = CreateFrame("Frame", nil, parent)
  container:SetSize(width, 48)
  container:SetPoint("TOPLEFT", x, yOffset)
  
  -- Label on left
  local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  labelText:SetPoint("TOPLEFT", 0, 0)
  labelText:SetText("|cffCCCCCC" .. label .. "|r")
  
  -- Current value display on right
  local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  valueText:SetPoint("TOPRIGHT", 0, 0)
  valueText:SetText(formatFunc and formatFunc(currentVal) or tostring(currentVal))
  
  -- The slider itself
  local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", 0, -18)
  slider:SetSize(width, 17)
  slider:SetMinMaxValues(minVal, maxVal)
  slider:SetValue(currentVal)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  
  -- Style slider labels
  slider.Low:SetText(formatFunc and formatFunc(minVal) or tostring(minVal))
  slider.High:SetText(formatFunc and formatFunc(maxVal) or tostring(maxVal))
  slider.Low:SetFontObject("GameFontHighlightSmall")
  slider.High:SetFontObject("GameFontHighlightSmall")
  slider.Text:SetText("")
  
  slider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value / step + 0.5) * step
    valueText:SetText(formatFunc and formatFunc(value) or tostring(value))
    if onChange then onChange(value) end
  end)
  
  return container, yOffset - 52
end

-- Helper: Create info/tip box
local function CreateInfoBox(parent, yOffset, text, r, g, b)
  r, g, b = r or 0.6, g or 0.6, b or 0.6
  
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  box:SetSize(360, 50)
  box:SetPoint("TOPLEFT", 10, yOffset)
  box:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  box:SetBackdropColor(r * 0.2, g * 0.2, b * 0.2, 0.85)
  box:SetBackdropBorderColor(r, g, b, 0.7)
  
  -- Info icon
  local icon = box:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("LEFT", 8, 0)
  icon:SetTexture("Interface\\FriendsFrame\\InformationIcon")
  
  local infoText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  infoText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  infoText:SetPoint("RIGHT", -10, 0)
  infoText:SetJustifyH("LEFT")
  infoText:SetText("|cffBBBBBB" .. text .. "|r")
  infoText:SetWordWrap(true)
  
  return box, yOffset - 58
end

-- ============================================================
-- Main Config UI Builder
-- ============================================================

function AutoHelper:BuildConfigUI(parent)
  local db = getDB()
  local yOffset = -10
  
  -- Show first-run popup if needed
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("AutoHelper", "AUTOHELPER_TITLE", "AUTOHELPER_FIRST_RUN_DETAILED", db)
  end
  
  -- ========== TITLE HEADER ==========
  local titleFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  titleFrame:SetSize(360, 44)
  titleFrame:SetPoint("TOPLEFT", 10, yOffset)
  titleFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  titleFrame:SetBackdropColor(0.08, 0.08, 0.18, 0.95)
  titleFrame:SetBackdropBorderColor(0.4, 0.4, 0.9, 1)
  
  local titleIcon = titleFrame:CreateTexture(nil, "ARTWORK")
  titleIcon:SetSize(28, 28)
  titleIcon:SetPoint("LEFT", 10, 0)
  titleIcon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
  titleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  
  local title = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("LEFT", titleIcon, "RIGHT", 10, 2)
  title:SetText("|cff00CED1" .. L("AUTOHELPER_TITLE") .. "|r")
  
  local subtitle = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("LEFT", titleIcon, "RIGHT", 10, -12)
  subtitle:SetText("|cff888888" .. L("AUTOHELPER_DESC") .. "|r")
  
  yOffset = yOffset - 54
  
  -- ========== MASTER ENABLE ==========
  local enableBox = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  enableBox:SetSize(360, 32)
  enableBox:SetPoint("TOPLEFT", 10, yOffset)
  enableBox:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  enableBox:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
  enableBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)
  
  local enableCB = CreateFrame("CheckButton", nil, enableBox, "ChatConfigCheckButtonTemplate")
  enableCB:SetPoint("LEFT", 8, 0)
  enableCB:SetChecked(db.enabled)
  enableCB.Text:SetText("|cffFFFFFF" .. L("AUTOHELPER_ENABLE") .. "|r")
  enableCB.Text:SetFontObject("GameFontNormal")
  enableCB:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
    AutoHelper:UpdateState()
  end)
  
  yOffset = yOffset - 42
  
  -- ========== SECTION: AUTO SELL JUNK ==========
  local _, y1 = CreateSectionHeader(parent, L("AUTOHELPER_JUNK_HEADER"), yOffset, "Interface\\Icons\\INV_Misc_Bag_10")
  yOffset = y1
  
  local junkCB
  junkCB, yOffset = CreateStyledCheckbox(parent, 20, yOffset,
    L("AUTOHELPER_AUTO_SELL_JUNK"),
    L("AUTOHELPER_AUTO_SELL_JUNK_TIP"),
    db.autoSellJunk,
    function(checked) db.autoSellJunk = checked end
  )
  yOffset = yOffset - 8
  
  -- ========== SECTION: AUTO REPAIR ==========
  local _, y2 = CreateSectionHeader(parent, L("AUTOHELPER_REPAIR_HEADER"), yOffset, "Interface\\Icons\\Trade_BlackSmithing")
  yOffset = y2
  
  local repairCB
  repairCB, yOffset = CreateStyledCheckbox(parent, 20, yOffset,
    L("AUTOHELPER_AUTO_REPAIR"),
    L("AUTOHELPER_AUTO_REPAIR_TIP"),
    db.autoRepair,
    function(checked) db.autoRepair = checked end
  )
  
  local guildCB
  guildCB, yOffset = CreateStyledCheckbox(parent, 35, yOffset,
    L("AUTOHELPER_USE_GUILD_REPAIR"),
    L("AUTOHELPER_USE_GUILD_REPAIR_TIP"),
    db.useGuildRepair,
    function(checked) db.useGuildRepair = checked end
  )
  yOffset = yOffset - 8
  
  -- ========== SECTION: AUTO ACCEPT SUMMON ==========
  local _, y3 = CreateSectionHeader(parent, L("AUTOHELPER_SUMMON_HEADER"), yOffset, "Interface\\Icons\\Spell_Shadow_Twilight")
  yOffset = y3
  
  local summonCB
  summonCB, yOffset = CreateStyledCheckbox(parent, 20, yOffset,
    L("AUTOHELPER_AUTO_ACCEPT_SUMMON"),
    L("AUTOHELPER_AUTO_ACCEPT_SUMMON_TIP"),
    db.autoAcceptSummon,
    function(checked) db.autoAcceptSummon = checked end
  )
  
  -- Summon delay slider
  local _, y4 = CreateStyledSlider(parent, 25, yOffset, 180,
    L("AUTOHELPER_SUMMON_DELAY"),
    0.1, 3.0, 0.1,
    db.summonDelay,
    function(v) return string.format("%.1fs", v) end,
    function(value) db.summonDelay = value end
  )
  yOffset = y4 - 3
  
  -- ========== SECTION: SMART DESTROY ==========
  local _, y5 = CreateSectionHeader(parent, L("AUTOHELPER_DESTROY_HEADER"), yOffset, "Interface\\Icons\\Ability_Creature_Cursed_02")
  yOffset = y5
  
  local destroyCB
  destroyCB, yOffset = CreateStyledCheckbox(parent, 20, yOffset,
    L("AUTOHELPER_SMART_DESTROY"),
    L("AUTOHELPER_SMART_DESTROY_TIP"),
    db.smartDestroy,
    function(checked) db.smartDestroy = checked end
  )
  
  local grayOnlyCB
  grayOnlyCB, yOffset = CreateStyledCheckbox(parent, 35, yOffset,
    L("AUTOHELPER_DESTROY_ONLY_GRAY"),
    L("AUTOHELPER_DESTROY_ONLY_GRAY_TIP"),
    db.destroyOnlyGray,
    function(checked) db.destroyOnlyGray = checked end
  )
  
  -- Max destroy value slider
  local _, y6 = CreateStyledSlider(parent, 25, yOffset, 320,
    L("AUTOHELPER_MAX_DESTROY_VALUE"),
    100, 100000, 100,
    db.destroyMaxValue,
    FormatMoney,
    function(value) db.destroyMaxValue = value end
  )
  yOffset = y6
  
  -- Protected slots slider
  local _, y7 = CreateStyledSlider(parent, 25, yOffset, 180,
    L("AUTOHELPER_PROTECT_SLOTS"),
    0, 10, 1,
    db.protectLastSlots,
    function(v) return v .. " " .. L("AUTOHELPER_SLOTS") end,
    function(value) db.protectLastSlots = value end
  )
  yOffset = y7
  
  -- Info box explaining smart destroy
  local _, y8 = CreateInfoBox(parent, yOffset, L("AUTOHELPER_SMART_DESTROY_INFO"), 0.9, 0.7, 0.2)
  yOffset = y8
  
  -- ========== DESTROY JUNK BUTTON ==========
  local destroyBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  destroyBtn:SetSize(160, 28)
  destroyBtn:SetPoint("TOPLEFT", 10, yOffset)
  destroyBtn:SetText(L("AUTOHELPER_DESTROY_JUNK_BTN"))
  destroyBtn:SetScript("OnClick", function()
    DestroyAllJunk()
  end)
  destroyBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L("AUTOHELPER_DESTROY_JUNK_BTN"), 1, 1, 1)
    GameTooltip:AddLine(L("AUTOHELPER_DESTROY_JUNK_BTN_TIP"), 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  destroyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  
  -- Warning text next to button
  local warnText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  warnText:SetPoint("LEFT", destroyBtn, "RIGHT", 10, 0)
  warnText:SetText("|cffFF6666" .. L("AUTOHELPER_DESTROY_WARNING") .. "|r")
  
  yOffset = yOffset - 40
end

function AutoHelper:CleanupUI()
  -- No floating UI to clean up
end

EasyLife:RegisterModule("AutoHelper", AutoHelper)
