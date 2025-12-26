-- ═══════════════════════════════════════════════════════════════════════════
-- ADVERTISER MODULE
-- Auto-invite, channel ads, and auto-reply system
-- ═══════════════════════════════════════════════════════════════════════════

local Advertiser = {}

--------------------------------------------------------------------------------
-- DEFAULTS & STATE
--------------------------------------------------------------------------------

local DEFAULTS = {
    enabled = false,  -- Module starts stopped
    -- Auto Invite (starts disabled)
    autoInvite = false,
    autoInviteDelay = 0.5,
    whisperKeywords = {},  -- Rule-based: list of keywords for whispers
    channelKeywords = {},  -- Rule-based: list of keywords for channels
    monitoredChannels = {},
    -- Send Message
    adMessage = "",
    adTargetChannels = {},
    adCooldown = 30,
    useFloatingButton = false,  -- Starts disabled
    floatingButtonLocked = false,
    floatingX = 200,
    floatingY = -200,
    -- Auto Send Timer (starts disabled)
    autoSendEnabled = false,
    autoSendInterval = 60,
    -- Keybind (starts disabled)
    keybindEnabled = false,
    keybindKey = nil,
    -- Auto Reply (starts disabled)
    autoReplyEnabled = false,
    autoReplyRules = {},
    autoReplyCooldown = 10,
}

local state = {
    adsSent = 0,
    invitesSent = 0,
    repliesSent = 0,
    onCooldown = false,
    cooldownEnds = 0,
    invitedPlayers = {},
    replyCooldowns = {},
    -- Queue system
    messageQueued = false,
    queuedAt = 0,
}

local floatingButton = nil
local cooldownTimer = nil
local autoSendTimer = nil
local keybindFrame = nil
local headerTimer = nil
local pulseAnimation = nil
local anyKeyFrame = nil  -- Frame to detect any key/click when message is queued

--------------------------------------------------------------------------------
-- DATABASE
--------------------------------------------------------------------------------

local function getDB()
    EasyLifeDB = EasyLifeDB or {}
    EasyLifeDB.Advertiser = EasyLifeDB.Advertiser or {}
    local db = EasyLifeDB.Advertiser
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then
            db[k] = type(v) == "table" and {} or v
        end
    end
    -- First-run detection
    if db._firstRunShown == nil then
        db._firstRunShown = false
    end
    
    -- Migration: Convert old comma-separated keywords to new list format
    if db.keywordsWhisper and type(db.keywordsWhisper) == "string" then
        local keywords = {}
        for keyword in db.keywordsWhisper:gmatch("[^,]+") do
            keyword = keyword:gsub("^%s*(.-)%s*$", "%1")  -- trim
            if keyword ~= "" and keyword ~= "inv" and keyword ~= "invite" then
                table.insert(keywords, keyword)
            end
        end
        db.whisperKeywords = keywords
        db.keywordsWhisper = nil
    end
    if db.keywordsChannel and type(db.keywordsChannel) == "string" then
        local keywords = {}
        for keyword in db.keywordsChannel:gmatch("[^,]+") do
            keyword = keyword:gsub("^%s*(.-)%s*$", "%1")  -- trim
            if keyword ~= "" and keyword ~= "inv" and keyword ~= "invite" then
                table.insert(keywords, keyword)
            end
        end
        db.channelKeywords = keywords
        db.keywordsChannel = nil
    end
    
    -- Ensure lists exist
    db.whisperKeywords = db.whisperKeywords or {}
    db.channelKeywords = db.channelKeywords or {}
    
    return db
end

--------------------------------------------------------------------------------
-- UTILITIES
--------------------------------------------------------------------------------

local function GetJoinedChannels()
    local channels = {}
    local list = {GetChannelList()}
    for i = 1, #list, 3 do
        local id, name = list[i], list[i + 1]
        if id and name then
            local clean = name:match("^%d+%.%s*(.+)") or name
            table.insert(channels, {id = id, name = clean})
        end
    end
    return channels
end

local function trim(s)
    return s and s:gsub("^%s*(.-)%s*$", "%1") or ""
end

--------------------------------------------------------------------------------
-- COOLDOWN SYSTEM
--------------------------------------------------------------------------------

local cooldownUpdateTimer = nil

function Advertiser:StartCooldown()
    local db = getDB()
    local duration = db.adCooldown or 30
    
    state.onCooldown = true
    state.cooldownEnds = GetTime() + duration
    
    if cooldownTimer then cooldownTimer:Cancel() end
    cooldownTimer = C_Timer.NewTimer(duration, function()
        state.onCooldown = false
        cooldownTimer = nil
        if cooldownUpdateTimer then cooldownUpdateTimer:Cancel(); cooldownUpdateTimer = nil end
        -- If auto-send enabled, queue next message when cooldown ends
        if getDB().autoSendEnabled and getDB().enabled then
            Advertiser:QueueAutoMessage()
        else
            Advertiser:UpdateFloatingButton()
        end
    end)
    
    -- Update button every second to show countdown
    if cooldownUpdateTimer then cooldownUpdateTimer:Cancel() end
    cooldownUpdateTimer = C_Timer.NewTicker(1, function()
        if not state.onCooldown then
            if cooldownUpdateTimer then cooldownUpdateTimer:Cancel(); cooldownUpdateTimer = nil end
            return
        end
        Advertiser:UpdateFloatingButton()
    end)
    
    self:UpdateFloatingButton()
end

function Advertiser:GetCooldownRemaining()
    if not state.onCooldown then return 0 end
    return math.max(0, math.ceil(state.cooldownEnds - GetTime()))
end

--------------------------------------------------------------------------------
-- FLOATING BUTTON
--------------------------------------------------------------------------------

function Advertiser:CreateFloatingButton()
    -- Return existing if we have one
    if floatingButton then return floatingButton end
    
    -- Destroy any orphaned global button from previous session
    if _G["EasyLifeAdButton"] then
        _G["EasyLifeAdButton"]:Hide()
        _G["EasyLifeAdButton"]:SetParent(nil)
        _G["EasyLifeAdButton"] = nil
    end
    
    local db = getDB()
    local btn = CreateFrame("Button", "EasyLifeAdButton", UIParent, "BackdropTemplate")
    btn:SetSize(44, 44)
    btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.floatingX, db.floatingY)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = {left = 2, right = 2, top = 2, bottom = 2},
    })
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    btn:SetBackdropBorderColor(0.5, 0.45, 0.2, 1)
    
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER", 0, 0)
    btn.text:SetText("Ad")
    
    -- Glow overlay for queued state
    btn.glow = btn:CreateTexture(nil, "OVERLAY")
    btn.glow:SetAllPoints()
    btn.glow:SetColorTexture(1, 0.8, 0, 0.3)
    btn.glow:Hide()
    
    btn:SetMovable(true)
    btn:SetClampedToScreen(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("RightButton")  -- Right-click to drag
    btn:RegisterForClicks("AnyUp")  -- Any click to send
    
    btn:SetScript("OnDragStart", function(self)
        if not getDB().floatingButtonLocked then
            self:StartMoving()
        end
    end)
    
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save absolute position from screen edges
        local d = getDB()
        d.floatingX = self:GetLeft()
        d.floatingY = self:GetTop() - UIParent:GetHeight()  -- Negative from top
    end)
    
    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then return end  -- Right is for drag
        -- Left click is a hardware event - can send!
        if state.messageQueued then
            Advertiser:SendAd()
        elseif not state.onCooldown then
            Advertiser:SendAd()
        else
            EasyLife:Print("|cffFF6600On cooldown:|r " .. Advertiser:GetCooldownRemaining() .. "s")
        end
    end)
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("EasyLife Advertiser")
        if state.messageQueued then
            GameTooltip:AddLine("|cffFFD700MESSAGE READY|r")
            GameTooltip:AddLine("|cff00FF00Left-click to send!|r")
        elseif state.onCooldown then
            GameTooltip:AddLine("|cffFF6600Cooldown:|r " .. Advertiser:GetCooldownRemaining() .. "s")
        else
            GameTooltip:AddLine("|cff888888Left-click to send ad|r")
        end
        GameTooltip:AddLine("|cff666666Right-drag to move|r")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    floatingButton = btn
    return btn
end

function Advertiser:UpdateFloatingButton()
    local db = getDB()
    if not db.useFloatingButton and not db.autoSendEnabled then
        if floatingButton then floatingButton:Hide() end
        return
    end
    
    if not db.enabled then
        if floatingButton then floatingButton:Hide() end
        return
    end
    
    local btn = self:CreateFloatingButton()
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.floatingX, db.floatingY)
    btn:SetMovable(not db.floatingButtonLocked)
    
    -- Update visual state
    if state.messageQueued then
        btn:SetBackdropBorderColor(0, 1, 0, 1)  -- Green border
        btn.glow:Show()
        btn.text:SetText("|cff00FF00SEND|r")
        
        -- Pulse animation
        if not pulseAnimation then
            pulseAnimation = btn.glow:CreateAnimationGroup()
            local fadeIn = pulseAnimation:CreateAnimation("Alpha")
            fadeIn:SetFromAlpha(0.1)
            fadeIn:SetToAlpha(0.4)
            fadeIn:SetDuration(0.5)
            fadeIn:SetOrder(1)
            local fadeOut = pulseAnimation:CreateAnimation("Alpha")
            fadeOut:SetFromAlpha(0.4)
            fadeOut:SetToAlpha(0.1)
            fadeOut:SetDuration(0.5)
            fadeOut:SetOrder(2)
            pulseAnimation:SetLooping("REPEAT")
        end
        pulseAnimation:Play()
    elseif state.onCooldown then
        btn:SetBackdropBorderColor(0.5, 0.3, 0.1, 1)  -- Dim orange
        btn.glow:Hide()
        if pulseAnimation then pulseAnimation:Stop() end
        btn.text:SetText("|cff888888" .. self:GetCooldownRemaining() .. "|r")
    else
        btn:SetBackdropBorderColor(db.floatingButtonLocked and 0.3 or 0.5, 0.45, 0.2, 1)
        btn.glow:Hide()
        if pulseAnimation then pulseAnimation:Stop() end
        btn.text:SetText("Ad")
    end
    
    btn:Show()
end

--------------------------------------------------------------------------------
-- SEND AD
--------------------------------------------------------------------------------

function Advertiser:SendAd()
    local db = getDB()
    
    if not db.enabled then
        EasyLife:Print("|cffFF6666Advertiser is stopped|r")
        return false
    end
    
    if state.onCooldown then
        EasyLife:Print("|cffFF6600On cooldown:|r " .. self:GetCooldownRemaining() .. "s")
        return false
    end
    
    local msg = trim(db.adMessage)
    if msg == "" then
        EasyLife:Print("|cffFF6600No message configured|r")
        return false
    end
    
    -- Get target channels
    local targets = {}
    for name, enabled in pairs(db.adTargetChannels) do
        if enabled then table.insert(targets, name) end
    end
    
    if #targets == 0 then
        EasyLife:Print("|cffFF6600No channels selected|r")
        return false
    end
    
    -- Build channel ID map
    local channelMap = {}
    for _, ch in ipairs(GetJoinedChannels()) do
        channelMap[ch.name] = ch.id
    end
    
    -- Send to each channel
    local sent = 0
    for _, name in ipairs(targets) do
        local id = channelMap[name] or GetChannelName(name)
        if id and id > 0 then
            SendChatMessage(msg, "CHANNEL", nil, id)
            sent = sent + 1
        end
    end
    
    if sent > 0 then
        state.adsSent = state.adsSent + 1
        -- Clear queued state
        state.messageQueued = false
        state.queuedAt = nil
        -- Disable any-key detection until next queue
        self:EnableAnyKeyDetection(false)
        self:StartCooldown()
        self:UpdateFloatingButton()
        EasyLife:Print("|cff00FF00Ad sent|r to " .. sent .. " channel(s)")
        return true
    else
        EasyLife:Print("|cffFF6600No valid channels found|r")
        return false
    end
end

-- Called when user clicks the button while a message is queued
function Advertiser:SendQueuedMessage()
    if not state.messageQueued then return false end
    return self:SendAd()
end

--------------------------------------------------------------------------------
-- AUTO SEND TIMER (Internal Queue System)
-- WoW requires hardware events to send chat. Timer queues message, user clicks to send.
--------------------------------------------------------------------------------

function Advertiser:StartAutoSend()
    local db = getDB()
    
    if autoSendTimer then
        autoSendTimer:Cancel()
        autoSendTimer = nil
    end
    
    if not db.autoSendEnabled or not db.enabled then return end
    
    local msg = trim(db.adMessage)
    if msg == "" then
        EasyLife:Print("|cffFF6600[Auto-Send]|r No message configured")
        return
    end
    
    local hasTargets = false
    for _, enabled in pairs(db.adTargetChannels) do
        if enabled then hasTargets = true; break end
    end
    if not hasTargets then
        EasyLife:Print("|cffFF6600[Auto-Send]|r No channels selected")
        return
    end
    
    local interval = math.max(10, db.autoSendInterval or 60)
    
    -- Queue first message immediately (if not on cooldown)
    if not state.onCooldown then
        self:QueueAutoMessage()
    end
    
    -- Then queue on interval
    autoSendTimer = C_Timer.NewTicker(interval, function()
        if not getDB().autoSendEnabled or not getDB().enabled then
            if autoSendTimer then autoSendTimer:Cancel(); autoSendTimer = nil end
            return
        end
        -- Only queue if not already queued and not on cooldown
        if not state.messageQueued and not state.onCooldown then
            Advertiser:QueueAutoMessage()
        end
    end)
    
    EasyLife:Print("|cff00FF00[Auto-Send]|r Started - queues every " .. interval .. "s")
    EasyLife:Print("|cffFFD700Press ANY key or click when message is ready!|r")
end

function Advertiser:StopAutoSend()
    if autoSendTimer then
        autoSendTimer:Cancel()
        autoSendTimer = nil
    end
    state.messageQueued = false
    state.queuedAt = nil
    -- Disable any-key detection
    self:EnableAnyKeyDetection(false)
    self:UpdateFloatingButton()
end

-- Queue a message (sets flag, button will glow)
function Advertiser:QueueAutoMessage()
    local db = getDB()
    local msg = trim(db.adMessage)
    if msg == "" then return end
    
    -- Check we have valid channels
    local hasTargets = false
    for _, enabled in pairs(db.adTargetChannels) do
        if enabled then hasTargets = true; break end
    end
    if not hasTargets then return end
    
    -- Set queued state
    state.messageQueued = true
    state.queuedAt = GetTime()
    
    -- Update button to show queued state
    self:UpdateFloatingButton()
    
    -- Enable any-key detection
    self:EnableAnyKeyDetection(true)
    
    -- Play sound to alert user
    PlaySound(SOUNDKIT.TELL_MESSAGE)
    
    EasyLife:Print("|cffFFD700[Auto]|r Message ready - |cff00FF00press ANY key|r or |cff00FF00click|r to send!")
end

--------------------------------------------------------------------------------
-- ANY KEY/CLICK DETECTION (for Auto-Send)
-- When a message is queued, detect ANY hardware event to send it
--------------------------------------------------------------------------------

function Advertiser:EnableAnyKeyDetection(enable)
    if not anyKeyFrame then
        anyKeyFrame = CreateFrame("Button", nil, UIParent)
        anyKeyFrame:SetSize(1, 1)
        anyKeyFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        anyKeyFrame:EnableKeyboard(true)
        anyKeyFrame:SetPropagateKeyboardInput(true)
        
        -- Detect any key press
        anyKeyFrame:SetScript("OnKeyDown", function(self, key)
            -- Ignore modifier keys alone
            if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
                return
            end
            
            -- Check if we have a queued message
            if state.messageQueued and getDB().enabled and getDB().autoSendEnabled then
                self:SetPropagateKeyboardInput(false)
                Advertiser:SendQueuedMessage()
                C_Timer.After(0.1, function()
                    if anyKeyFrame then
                        anyKeyFrame:SetPropagateKeyboardInput(true)
                    end
                end)
            end
        end)
        
        -- Also detect mouse clicks via a global hook
        anyKeyFrame:RegisterForClicks("AnyUp")
        anyKeyFrame:SetScript("OnClick", function(self, button)
            if state.messageQueued and getDB().enabled and getDB().autoSendEnabled then
                Advertiser:SendQueuedMessage()
            end
        end)
    end
    
    if enable then
        anyKeyFrame:Show()
        anyKeyFrame:EnableKeyboard(true)
    else
        anyKeyFrame:Hide()
        anyKeyFrame:EnableKeyboard(false)
    end
end

--------------------------------------------------------------------------------
-- KEYBIND
--------------------------------------------------------------------------------

function Advertiser:SetupKeybind()
    if not keybindFrame then
        keybindFrame = CreateFrame("Frame", nil, UIParent)
        keybindFrame:SetPropagateKeyboardInput(true)
        keybindFrame:SetScript("OnKeyDown", function(_, key)
            local db = getDB()
            if not db.keybindEnabled or not db.keybindKey then return end
            
            local combo = ""
            if IsControlKeyDown() then combo = combo .. "CTRL-" end
            if IsShiftKeyDown() then combo = combo .. "SHIFT-" end
            if IsAltKeyDown() then combo = combo .. "ALT-" end
            combo = combo .. key
            
            if combo == db.keybindKey then
                keybindFrame:SetPropagateKeyboardInput(false)
                -- Keybind is a hardware event - can send!
                if state.messageQueued then
                    Advertiser:SendQueuedMessage()
                elseif not state.onCooldown then
                    Advertiser:SendAd()
                else
                    EasyLife:Print("|cffFF6600On cooldown:|r " .. Advertiser:GetCooldownRemaining() .. "s")
                end
                C_Timer.After(0.1, function()
                    if keybindFrame then
                        keybindFrame:SetPropagateKeyboardInput(true)
                    end
                end)
            end
        end)
    end
    
    local db = getDB()
    if db.keybindEnabled and db.keybindKey then
        keybindFrame:Show()
    else
        keybindFrame:Hide()
    end
end

--------------------------------------------------------------------------------
-- AUTO INVITE
--------------------------------------------------------------------------------

function Advertiser:CheckAutoInvite(sender, message, chatType, channelName)
    local db = getDB()
    if not db.autoInvite then return end
    
    -- Get keywords based on chat type (rule-based lists)
    local keywords = chatType == "WHISPER" and db.whisperKeywords or db.channelKeywords
    if not keywords or #keywords == 0 then return end
    
    -- Check channel filter
    if chatType == "CHANNEL" and channelName then
        local clean = channelName:match("^%d+%.%s*(.+)") or channelName
        if db.monitoredChannels and next(db.monitoredChannels) then
            if not db.monitoredChannels[clean] then return end
        end
    end
    
    -- Check for keyword match
    local lowerMsg = message:lower()
    for _, keyword in ipairs(keywords) do
        if keyword and keyword ~= "" and lowerMsg:find(keyword:lower(), 1, true) then
            self:InvitePlayer(sender, keyword)
            return
        end
    end
end

function Advertiser:InvitePlayer(player, keyword)
    local now = GetTime()
    if state.invitedPlayers[player] and (now - state.invitedPlayers[player]) < 60 then
        return -- Already invited recently
    end
    
    state.invitedPlayers[player] = now
    state.invitesSent = state.invitesSent + 1
    
    local delay = math.max(0, getDB().autoInviteDelay or 0.5)
    C_Timer.After(delay, function()
        InviteUnit(player)
        EasyLife:Print("|cff00FF00[Invite]|r " .. player .. " (matched: " .. keyword .. ")")
    end)
end

--------------------------------------------------------------------------------
-- AUTO REPLY
--------------------------------------------------------------------------------

function Advertiser:CheckAutoReply(sender, message)
    local db = getDB()
    if not db.autoReplyEnabled then return end
    if not db.autoReplyRules or #db.autoReplyRules == 0 then return end
    
    local now = GetTime()
    local cooldown = db.autoReplyCooldown or 10
    
    -- Check player cooldown
    if state.replyCooldowns[sender] and (now - state.replyCooldowns[sender]) < cooldown then
        return
    end
    
    local lowerMsg = message:lower()
    
    for _, rule in ipairs(db.autoReplyRules) do
        if rule.enabled and rule.keywords and rule.response and rule.response ~= "" then
            for keyword in rule.keywords:gmatch("[^,]+") do
                keyword = trim(keyword)
                if keyword ~= "" and lowerMsg:find(keyword:lower(), 1, true) then
                    state.replyCooldowns[sender] = now
                    state.repliesSent = state.repliesSent + 1
                    SendChatMessage(rule.response, "WHISPER", nil, sender)
                    EasyLife:Print("|cff00FFFF[Reply]|r to " .. sender .. " (matched: " .. keyword .. ")")
                    return
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- EVENT HANDLING
--------------------------------------------------------------------------------

function Advertiser:OnEvent(event, message, sender, _, _, _, _, _, _, channelName)
    local db = getDB()
    if not db.enabled then return end
    
    local cleanSender = sender:match("([^%-]+)") or sender
    if cleanSender == UnitName("player") then return end
    
    if event == "CHAT_MSG_WHISPER" then
        self:CheckAutoReply(cleanSender, message)
        self:CheckAutoInvite(cleanSender, message, "WHISPER")
    elseif event == "CHAT_MSG_CHANNEL" then
        self:CheckAutoInvite(cleanSender, message, "CHANNEL", channelName)
    end
end

function Advertiser:UpdateState()
    local db = getDB()
    
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, event, ...)
            self:OnEvent(event, ...)
        end)
    end
    
    self.frame:UnregisterAllEvents()
    
    if not db.enabled then
        self:StopAutoSend()
        if floatingButton then floatingButton:Hide() end
        return
    end
    
    -- Register events
    if db.autoInvite or db.autoReplyEnabled then
        self.frame:RegisterEvent("CHAT_MSG_WHISPER")
    end
    if db.autoInvite then
        self.frame:RegisterEvent("CHAT_MSG_CHANNEL")
    end
    
    self:UpdateFloatingButton()
    self:SetupKeybind()
end

--------------------------------------------------------------------------------
-- MODULE INIT
--------------------------------------------------------------------------------

function Advertiser:OnRegister()
    -- Register for PLAYER_LOGIN to reset features AFTER SavedVariables are loaded
    -- OnRegister runs before SavedVariables load, so any resets here get overwritten
    if not self.loginFrame then
        self.loginFrame = CreateFrame("Frame")
        self.loginFrame:RegisterEvent("PLAYER_LOGIN")
        self.loginFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_LOGIN" then
                -- Now SavedVariables are fully loaded, reset all auto features
                local db = getDB()
                db.autoInvite = false
                db.autoSendEnabled = false
                db.autoReplyEnabled = false
                Advertiser:UpdateState()
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- UI HELPERS
--------------------------------------------------------------------------------

local function CreateCheckbox(parent, x, y, label, checked, onClick)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(20, 20)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb:SetChecked(checked)
    
    cb.text = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.text:SetText(label)
    
    cb:SetScript("OnClick", onClick)
    return cb
end

local function CreateEditBox(parent, x, y, width, height, text, multiLine)
    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", x, y)
    bg:SetSize(width, height)
    bg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = {left = 2, right = 2, top = 2, bottom = 2},
    })
    bg:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    bg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    local edit = CreateFrame("EditBox", nil, bg)
    edit:SetPoint("TOPLEFT", 6, -4)
    edit:SetPoint("BOTTOMRIGHT", -6, 4)
    edit:SetFontObject("ChatFontNormal")
    edit:SetAutoFocus(false)
    edit:SetMultiLine(multiLine or false)
    edit:SetText(text or "")
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    return bg, edit
end

local function CreateNumberBox(parent, x, y, width, value)
    local bg, edit = CreateEditBox(parent, x, y, width, 24, tostring(value or 0), false)
    edit:SetNumeric(true)
    return bg, edit
end

--------------------------------------------------------------------------------
-- TAB: AUTO INVITE
--------------------------------------------------------------------------------

-- Helper to create keyword list UI with scrolling
local function CreateKeywordList(parent, x, y, title, keywordTable, dbKey, width, height)
    height = height or 140  -- Default height
    
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetPoint("TOPLEFT", x, y)
    container:SetSize(width, height)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = {left = 2, right = 2, top = 2, bottom = 2},
    })
    container:SetBackdropColor(0.03, 0.03, 0.03, 0.9)
    container:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    -- Title
    local titleText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", 8, -6)
    titleText:SetText(title)
    
    -- Add keyword input at TOP (fixed position, always visible)
    local addBg = CreateFrame("Frame", nil, container, "BackdropTemplate")
    addBg:SetPoint("TOPLEFT", 6, -24)
    addBg:SetSize(width - 70, 22)
    addBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2},
    })
    addBg:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    addBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    
    local addEdit = CreateFrame("EditBox", nil, addBg)
    addEdit:SetPoint("TOPLEFT", 4, -3)
    addEdit:SetPoint("BOTTOMRIGHT", -4, 3)
    addEdit:SetFontObject("ChatFontSmall")
    addEdit:SetAutoFocus(false)
    
    local addBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    addBtn:SetSize(50, 22)
    addBtn:SetPoint("TOPRIGHT", -6, -24)
    addBtn:SetText("Add")
    
    -- Scrollable list area BELOW the input
    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)
    
    local listFrame = CreateFrame("Frame", nil, scrollFrame)
    listFrame:SetSize(width - 32, 1)  -- Width, height will be dynamic
    scrollFrame:SetScrollChild(listFrame)
    
    local rows = {}
    
    local function RefreshList()
        -- Hide all existing rows
        for _, row in ipairs(rows) do
            row:Hide()
        end
        
        local db = getDB()
        local keywords = db[dbKey] or {}
        
        local yOff = 0
        for i, keyword in ipairs(keywords) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, listFrame, "BackdropTemplate")
                row:SetHeight(22)
                row:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                })
                row:SetBackdropColor(0.08, 0.08, 0.08, 0.6)
                
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.text:SetPoint("LEFT", 6, 0)
                row.text:SetJustifyH("LEFT")
                
                row.removeBtn = CreateFrame("Button", nil, row)
                row.removeBtn:SetSize(16, 16)
                row.removeBtn:SetPoint("RIGHT", -4, 0)
                row.removeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
                row.removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                
                rows[i] = row
            end
            
            row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, yOff)
            row:SetPoint("RIGHT", listFrame, "RIGHT", 0, 0)
            row.text:SetText("|cffFFFFFF" .. keyword .. "|r")
            row.removeBtn:SetScript("OnClick", function()
                table.remove(keywords, i)
                db[dbKey] = keywords
                RefreshList()
                EasyLife:Print("|cffFF6600Removed keyword:|r " .. keyword)
            end)
            row:Show()
            
            yOff = yOff - 24
        end
        
        -- Update list frame height for scrolling
        listFrame:SetHeight(math.max(1, math.abs(yOff)))
    end
    
    local function AddKeyword()
        local keyword = addEdit:GetText()
        keyword = keyword and keyword:match("^%s*(.-)%s*$") or ""  -- trim
        if keyword ~= "" then
            local db = getDB()
            db[dbKey] = db[dbKey] or {}
            -- Check for duplicates
            for _, existing in ipairs(db[dbKey]) do
                if existing:lower() == keyword:lower() then
                    EasyLife:Print("|cffFF6600Keyword already exists:|r " .. keyword)
                    return
                end
            end
            table.insert(db[dbKey], keyword)
            addEdit:SetText("")
            RefreshList()
            EasyLife:Print("|cff00FF00[Auto-Invite]|r Added keyword: |cffFFD700" .. keyword .. "|r")
        end
    end
    
    addEdit:SetScript("OnEnterPressed", function()
        AddKeyword()
        addEdit:ClearFocus()
    end)
    addEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    addBtn:SetScript("OnClick", AddKeyword)
    
    RefreshList()
    container.RefreshList = RefreshList
    
    return container
end

local autoInviteStatusTimer = nil

local function BuildAutoInviteTab(content, db)
    local y = -8
    local W = 330
    
    -- Create a centered container for all content
    local container = CreateFrame("Frame", nil, content)
    container:SetWidth(W + 8)
    container:SetPoint("TOP", content, "TOP", 0, 0)
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- STATUS HEADER
    -- ═══════════════════════════════════════════════════════════════════════
    local header = CreateFrame("Frame", nil, container, "BackdropTemplate")
    header:SetPoint("TOP", 0, y)
    header:SetSize(W + 8, 55)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    header:SetBackdropColor(0.08, 0.07, 0.05, 1)
    header:SetBackdropBorderColor(0.3, 0.25, 0.15, 1)
    
    -- Title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -6)
    title:SetText("|cffFFD700Auto-Invite|r")
    
    -- Status text
    local statusText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", 10, -8)
    
    -- Stats
    local statsText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("RIGHT", -80, -8)
    
    -- Toggle button
    local toggleBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    toggleBtn:SetSize(60, 20)
    toggleBtn:SetPoint("RIGHT", -8, -8)
    
    local function RefreshHeader()
        local d = getDB()
        if not d.enabled then
            statusText:SetText("|cffFF6666Module Stopped|r")
            header:SetBackdropBorderColor(0.4, 0.2, 0.2, 0.8)
            toggleBtn:SetText("Start")
            toggleBtn:Disable()
        elseif d.autoInvite then
            statusText:SetText("|cff00FF00● Listening|r")
            header:SetBackdropBorderColor(0.2, 0.5, 0.2, 0.8)
            toggleBtn:SetText("Disable")
            toggleBtn:Enable()
        else
            statusText:SetText("|cff888888● Disabled|r")
            header:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
            toggleBtn:SetText("Enable")
            toggleBtn:Enable()
        end
        statsText:SetText("|cff888888Invites:|r " .. state.invitesSent)
    end
    
    toggleBtn:SetScript("OnClick", function()
        local d = getDB()
        d.autoInvite = not d.autoInvite
        Advertiser:UpdateState()
        RefreshHeader()
        if d.autoInvite then
            EasyLife:Print("|cff00FF00[Auto-Invite]|r Enabled - listening for keywords")
        else
            EasyLife:Print("|cffFF6600[Auto-Invite]|r Disabled")
        end
    end)
    
    RefreshHeader()
    if autoInviteStatusTimer then autoInviteStatusTimer:Cancel() end
    autoInviteStatusTimer = C_Timer.NewTicker(1, RefreshHeader)
    header:SetScript("OnHide", function()
        if autoInviteStatusTimer then autoInviteStatusTimer:Cancel(); autoInviteStatusTimer = nil end
    end)
    
    y = y - 65
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- SETTINGS
    -- ═══════════════════════════════════════════════════════════════════════
    
    -- Invite delay
    local delayLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    delayLabel:SetPoint("TOPLEFT", 4, y)
    delayLabel:SetText("Invite delay (sec):")
    
    local _, delayEdit = CreateNumberBox(container, 132, y - 2, 50, db.autoInviteDelay)
    delayEdit:SetScript("OnTextChanged", function(self)
        getDB().autoInviteDelay = math.max(0, tonumber(self:GetText()) or 0)
    end)
    y = y - 34
    
    -- Whisper keywords list (with scrolling, input at top)
    CreateKeywordList(container, 4, y, "|cffFFD700Whisper Keywords|r (triggers on /whisper)", db.whisperKeywords, "whisperKeywords", W, 140)
    y = y - 150
    
    -- Channel keywords list (with scrolling, input at top)
    CreateKeywordList(container, 4, y, "|cffFFD700Channel Keywords|r (triggers in chat channels)", db.channelKeywords, "channelKeywords", W, 140)
    y = y - 150
    
    -- Channels to monitor
    local chanLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    chanLabel:SetPoint("TOPLEFT", 4, y)
    chanLabel:SetText("Channels to monitor:")
    y = y - 22
    
    local channels = GetJoinedChannels()
    if #channels == 0 then
        local noText = container:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        noText:SetPoint("TOPLEFT", 8, y)
        noText:SetText("|cff666666No channels joined|r")
        y = y - 20
    else
        local col, xPos = 0, 4
        for _, ch in ipairs(channels) do
            if col >= 3 then
                col, xPos = 0, 4
                y = y - 26
            end
            if db.monitoredChannels[ch.name] == nil then
                db.monitoredChannels[ch.name] = true
            end
            local cb = CreateCheckbox(container, xPos, y, ch.name, db.monitoredChannels[ch.name], function(self)
                getDB().monitoredChannels[ch.name] = self:GetChecked()
            end)
            cb.text:SetWidth(90)
            xPos = xPos + 110
            col = col + 1
        end
        y = y - 30
    end
    
    container:SetHeight(math.abs(y) + 20)
    content:SetHeight(math.abs(y) + 20)
end

--------------------------------------------------------------------------------
-- TAB: SEND MESSAGE
--------------------------------------------------------------------------------

local sendMessageStatusTimer = nil

local function BuildSendMessageTab(content, db)
    local y = -8
    local W = 330
    
    -- Create a centered container for all content
    local container = CreateFrame("Frame", nil, content)
    container:SetWidth(W + 8)
    container:SetPoint("TOP", content, "TOP", 0, 0)
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- STATUS HEADER
    -- ═══════════════════════════════════════════════════════════════════════
    local header = CreateFrame("Frame", nil, container, "BackdropTemplate")
    header:SetPoint("TOP", 0, y)
    header:SetSize(W + 8, 55)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    header:SetBackdropColor(0.08, 0.07, 0.05, 1)
    header:SetBackdropBorderColor(0.3, 0.25, 0.15, 1)
    
    -- Title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -6)
    title:SetText("|cffFFD700Send Message|r")
    
    -- Status text
    local statusText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", 10, -8)
    
    -- Cooldown/Stats
    local cooldownText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cooldownText:SetPoint("RIGHT", -80, -2)
    
    local statsText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("RIGHT", -80, -14)
    
    -- Send button in header
    local sendBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    sendBtn:SetSize(60, 20)
    sendBtn:SetPoint("RIGHT", -8, -8)
    sendBtn:SetText("Send")
    sendBtn:SetScript("OnClick", function()
        Advertiser:SendAd()
    end)
    
    local function RefreshHeader()
        local d = getDB()
        local cd = Advertiser:GetCooldownRemaining()
        
        if not d.enabled then
            statusText:SetText("|cffFF6666Module Stopped|r")
            header:SetBackdropBorderColor(0.4, 0.2, 0.2, 0.8)
            sendBtn:Disable()
        elseif state.messageQueued then
            statusText:SetText("|cff00FF00● READY TO SEND|r")
            header:SetBackdropBorderColor(0.2, 0.6, 0.2, 1)
            sendBtn:Enable()
            sendBtn:SetText("SEND!")
        elseif state.onCooldown then
            statusText:SetText("|cffFFD700● On Cooldown|r")
            header:SetBackdropBorderColor(0.5, 0.4, 0.1, 0.8)
            sendBtn:Disable()
            sendBtn:SetText("Wait")
        elseif d.autoSendEnabled then
            statusText:SetText("|cff00FF00● Auto-Send ON|r")
            header:SetBackdropBorderColor(0.2, 0.5, 0.2, 0.8)
            sendBtn:Enable()
            sendBtn:SetText("Send")
        else
            statusText:SetText("|cff888888● Manual Mode|r")
            header:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
            sendBtn:Enable()
            sendBtn:SetText("Send")
        end
        
        cooldownText:SetText(cd > 0 and ("|cffFFD700CD:|r " .. cd .. "s") or "|cff00FF00Ready|r")
        statsText:SetText("|cff888888Sent:|r " .. state.adsSent)
    end
    
    RefreshHeader()
    if sendMessageStatusTimer then sendMessageStatusTimer:Cancel() end
    sendMessageStatusTimer = C_Timer.NewTicker(0.5, RefreshHeader)
    header:SetScript("OnHide", function()
        if sendMessageStatusTimer then sendMessageStatusTimer:Cancel(); sendMessageStatusTimer = nil end
    end)
    
    y = y - 65
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- ENABLE AUTO-SEND
    -- ═══════════════════════════════════════════════════════════════════════
    local autoSendCb = CreateCheckbox(container, 4, y, "Enable Auto-Send", db.autoSendEnabled, function(self)
        local d = getDB()
        d.autoSendEnabled = self:GetChecked()
        Advertiser:UpdateState()
        RefreshHeader()
        if d.autoSendEnabled then
            EasyLife:Print("|cff00FF00[Auto-Send]|r Enabled - messages will queue and send on any key/click")
        else
            EasyLife:Print("|cffFF6600[Auto-Send]|r Disabled - manual mode")
        end
    end)
    autoSendCb.text:SetTextColor(1, 0.82, 0)  -- Gold color for emphasis
    y = y - 28
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- MESSAGE CONFIGURATION
    -- ═══════════════════════════════════════════════════════════════════════
    
    -- Message
    local msgLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    msgLabel:SetPoint("TOPLEFT", 4, y)
    msgLabel:SetText("Message:")
    y = y - 18
    
    local _, msgEdit = CreateEditBox(container, 4, y, W, 50, db.adMessage, true)
    msgEdit:SetScript("OnTextChanged", function(self)
        getDB().adMessage = self:GetText()
    end)
    y = y - 58
    
    -- Target channels
    local targetLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    targetLabel:SetPoint("TOPLEFT", 4, y)
    targetLabel:SetText("Send to channels:")
    y = y - 22
    
    local channels = GetJoinedChannels()
    if #channels == 0 then
        local noText = container:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        noText:SetPoint("TOPLEFT", 8, y)
        noText:SetText("|cff666666No channels joined|r")
        y = y - 20
    else
        local col, xPos = 0, 4
        for _, ch in ipairs(channels) do
            if col >= 3 then
                col, xPos = 0, 4
                y = y - 26
            end
            local cb = CreateCheckbox(container, xPos, y, ch.name, db.adTargetChannels[ch.name], function(self)
                getDB().adTargetChannels[ch.name] = self:GetChecked()
            end)
            cb.text:SetWidth(90)
            xPos = xPos + 110
            col = col + 1
        end
        y = y - 32
    end
    
    -- Cooldown setting
    local cdLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cdLabel:SetPoint("TOPLEFT", 4, y)
    cdLabel:SetText("Cooldown (sec):")
    
    local _, cdEdit = CreateNumberBox(container, 122, y - 2, 50, db.adCooldown)
    cdEdit:SetScript("OnTextChanged", function(self)
        getDB().adCooldown = math.max(1, tonumber(self:GetText()) or 30)
    end)
    y = y - 34
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- AUTO-SEND SECTION
    -- ═══════════════════════════════════════════════════════════════════════
    local sep1 = container:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOPLEFT", 4, y)
    sep1:SetSize(W, 1)
    sep1:SetColorTexture(0.4, 0.4, 0.4, 0.5)
    y = y - 12
    
    local autoHeader = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    autoHeader:SetPoint("TOPLEFT", 4, y)
    autoHeader:SetText("|cffFFD700Auto-Send Timer|r")
    y = y - 22
    
    CreateCheckbox(container, 4, y, "Enable auto-send", db.autoSendEnabled, function(cb)
        local d = getDB()
        d.autoSendEnabled = cb:GetChecked()
        if d.autoSendEnabled then
            Advertiser:StartAutoSend()
            EasyLife:Print("|cff00FF00[Auto-Send]|r Enabled")
        else
            Advertiser:StopAutoSend()
            EasyLife:Print("|cffFF6600[Auto-Send]|r Disabled")
        end
    end)
    
    local intLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    intLabel:SetPoint("LEFT", 172, y + 2)
    intLabel:SetText("Interval:")
    
    local _, intEdit = CreateNumberBox(container, 222, y, 50, db.autoSendInterval)
    intEdit:SetScript("OnTextChanged", function(self)
        getDB().autoSendInterval = math.max(10, tonumber(self:GetText()) or 60)
    end)
    
    local secLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    secLabel:SetPoint("LEFT", 277, y + 2)
    secLabel:SetText("sec")
    y = y - 28
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- FLOATING BUTTON & KEYBIND
    -- ═══════════════════════════════════════════════════════════════════════
    local sep2 = container:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("TOPLEFT", 4, y)
    sep2:SetSize(W, 1)
    sep2:SetColorTexture(0.4, 0.4, 0.4, 0.5)
    y = y - 12
    
    local floatHeader = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    floatHeader:SetPoint("TOPLEFT", 4, y)
    floatHeader:SetText("|cffFFD700Quick Access|r")
    y = y - 22
    
    CreateCheckbox(container, 4, y, "Show floating button", db.useFloatingButton, function(cb)
        getDB().useFloatingButton = cb:GetChecked()
        Advertiser:UpdateFloatingButton()
    end)
    
    CreateCheckbox(container, 172, y, "Lock position", db.floatingButtonLocked, function(cb)
        getDB().floatingButtonLocked = cb:GetChecked()
        Advertiser:UpdateFloatingButton()
    end)
    y = y - 26
    
    CreateCheckbox(container, 4, y, "Enable keybind", db.keybindEnabled, function(cb)
        getDB().keybindEnabled = cb:GetChecked()
        Advertiser:SetupKeybind()
    end)
    
    -- Keybind button
    local keyBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
    keyBtn:SetPoint("LEFT", 132, y + 2)
    keyBtn:SetSize(80, 20)
    keyBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2},
    })
    keyBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    keyBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    local keyText = keyBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    keyText:SetPoint("CENTER")
    keyText:SetText(db.keybindKey or "|cff666666Set key|r")
    
    local capturing = false
    keyBtn:EnableKeyboard(false)
    
    keyBtn:SetScript("OnClick", function(self)
        if not capturing then
            capturing = true
            keyText:SetText("|cffFFFF00...|r")
            self:SetBackdropBorderColor(1, 0.8, 0, 1)
            self:EnableKeyboard(true)
        end
    end)
    
    keyBtn:SetScript("OnKeyDown", function(self, key)
        if not capturing then return end
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then return end
        
        if key == "ESCAPE" then
            capturing = false
            keyText:SetText(db.keybindKey or "|cff666666Set key|r")
            self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            self:EnableKeyboard(false)
            return
        end
        
        local combo = ""
        if IsControlKeyDown() then combo = combo .. "CTRL-" end
        if IsShiftKeyDown() then combo = combo .. "SHIFT-" end
        if IsAltKeyDown() then combo = combo .. "ALT-" end
        combo = combo .. key
        
        getDB().keybindKey = combo
        keyText:SetText("|cff00FF00" .. combo .. "|r")
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        self:EnableKeyboard(false)
        capturing = false
        Advertiser:SetupKeybind()
    end)
    
    local clearKeyBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    clearKeyBtn:SetPoint("LEFT", keyBtn, "RIGHT", 4, 0)
    clearKeyBtn:SetSize(40, 20)
    clearKeyBtn:SetText("Clear")
    clearKeyBtn:SetScript("OnClick", function()
        getDB().keybindKey = nil
        keyText:SetText("|cff666666Set key|r")
        Advertiser:SetupKeybind()
    end)
    y = y - 30
    
    container:SetHeight(math.abs(y) + 20)
    content:SetHeight(math.abs(y) + 20)
end

--------------------------------------------------------------------------------
-- TAB: AUTO REPLY
--------------------------------------------------------------------------------

local autoReplyStatusTimer = nil

local function BuildAutoReplyTab(content, db)
    local y = -8
    local W = 330
    local ruleRows = {}
    
    -- Create a centered container for all content
    local container = CreateFrame("Frame", nil, content)
    container:SetWidth(W + 8)
    container:SetPoint("TOP", content, "TOP", 0, 0)
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- STATUS HEADER
    -- ═══════════════════════════════════════════════════════════════════════
    local header = CreateFrame("Frame", nil, container, "BackdropTemplate")
    header:SetPoint("TOP", 0, y)
    header:SetSize(W + 8, 55)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    header:SetBackdropColor(0.08, 0.07, 0.05, 1)
    header:SetBackdropBorderColor(0.3, 0.25, 0.15, 1)
    
    -- Title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -6)
    title:SetText("|cffFFD700Auto-Reply|r")
    
    -- Status text
    local statusText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", 10, -8)
    
    -- Stats
    local statsText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("RIGHT", -80, -8)
    
    -- Toggle button
    local toggleBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    toggleBtn:SetSize(60, 20)
    toggleBtn:SetPoint("RIGHT", -8, -8)
    
    local function RefreshHeader()
        local d = getDB()
        if not d.enabled then
            statusText:SetText("|cffFF6666Module Stopped|r")
            header:SetBackdropBorderColor(0.4, 0.2, 0.2, 0.8)
            toggleBtn:SetText("Start")
            toggleBtn:Disable()
        elseif d.autoReplyEnabled then
            statusText:SetText("|cff00FF00● Listening|r")
            header:SetBackdropBorderColor(0.2, 0.5, 0.2, 0.8)
            toggleBtn:SetText("Disable")
            toggleBtn:Enable()
        else
            statusText:SetText("|cff888888● Disabled|r")
            header:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
            toggleBtn:SetText("Enable")
            toggleBtn:Enable()
        end
        statsText:SetText("|cff888888Replies:|r " .. state.repliesSent)
    end
    
    toggleBtn:SetScript("OnClick", function()
        local d = getDB()
        d.autoReplyEnabled = not d.autoReplyEnabled
        Advertiser:UpdateState()
        RefreshHeader()
        if d.autoReplyEnabled then
            EasyLife:Print("|cff00FF00[Auto-Reply]|r Enabled - will respond to keyword whispers")
        else
            EasyLife:Print("|cffFF6600[Auto-Reply]|r Disabled")
        end
    end)
    
    RefreshHeader()
    if autoReplyStatusTimer then autoReplyStatusTimer:Cancel() end
    autoReplyStatusTimer = C_Timer.NewTicker(1, RefreshHeader)
    header:SetScript("OnHide", function()
        if autoReplyStatusTimer then autoReplyStatusTimer:Cancel(); autoReplyStatusTimer = nil end
    end)
    
    y = y - 65
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- SETTINGS
    -- ═══════════════════════════════════════════════════════════════════════
    
    -- Cooldown
    local cdLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cdLabel:SetPoint("TOPLEFT", 4, y)
    cdLabel:SetText("Cooldown per player (sec):")
    
    local _, cdEdit = CreateNumberBox(container, 182, y - 2, 50, db.autoReplyCooldown)
    cdEdit:SetScript("OnTextChanged", function(self)
        getDB().autoReplyCooldown = math.max(1, tonumber(self:GetText()) or 10)
    end)
    y = y - 34
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- RESPONSE RULES
    -- ═══════════════════════════════════════════════════════════════════════
    local sep = container:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 4, y)
    sep:SetSize(W, 1)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.5)
    y = y - 12
    
    -- Add rule button
    local addBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    addBtn:SetPoint("TOPLEFT", 4, y)
    addBtn:SetSize(90, 22)
    addBtn:SetText("+ Add Rule")
    y = y - 30
    
    db.autoReplyRules = db.autoReplyRules or {}
    
    local rulesContainer = CreateFrame("Frame", nil, container)
    rulesContainer:SetPoint("TOPLEFT", 4, y)
    rulesContainer:SetSize(W, 100)
    
    local function RefreshRules()
        for _, row in ipairs(ruleRows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(ruleRows)
        
        local ruleY = 0
        for i, rule in ipairs(db.autoReplyRules) do
            local row = CreateFrame("Frame", nil, rulesContainer, "BackdropTemplate")
            row:SetPoint("TOPLEFT", 0, ruleY)
            row:SetSize(W, 80)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10,
                insets = {left = 2, right = 2, top = 2, bottom = 2},
            })
            row:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
            row:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            
            -- Enable checkbox
            local cb = CreateFrame("CheckButton", nil, row)
            cb:SetPoint("TOPLEFT", 4, -6)
            cb:SetSize(18, 18)
            cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
            cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
            cb:SetChecked(rule.enabled ~= false)
            cb:SetScript("OnClick", function(self) rule.enabled = self:GetChecked() end)
            
            -- Rule number
            local num = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            num:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            num:SetText("|cffFFD700#" .. i .. "|r")
            
            -- Delete button
            local del = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            del:SetPoint("TOPRIGHT", -2, -2)
            del:SetSize(18, 18)
            del:SetScript("OnClick", function()
                table.remove(db.autoReplyRules, i)
                RefreshRules()
            end)
            
            -- Keywords
            local kwLabel = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            kwLabel:SetPoint("TOPLEFT", 26, -6)
            kwLabel:SetText("Keywords:")
            
            local kwBg = CreateFrame("Frame", nil, row, "BackdropTemplate")
            kwBg:SetPoint("TOPLEFT", 80, -2)
            kwBg:SetPoint("TOPRIGHT", -24, -2)
            kwBg:SetHeight(20)
            kwBg:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 8,
                insets = {left = 2, right = 2, top = 2, bottom = 2},
            })
            kwBg:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
            kwBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            
            local kwEdit = CreateFrame("EditBox", nil, kwBg)
            kwEdit:SetPoint("TOPLEFT", 4, -2)
            kwEdit:SetPoint("BOTTOMRIGHT", -4, 2)
            kwEdit:SetFontObject("ChatFontSmall")
            kwEdit:SetAutoFocus(false)
            kwEdit:SetText(rule.keywords or "")
            kwEdit:SetScript("OnTextChanged", function(self) rule.keywords = self:GetText() end)
            kwEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            
            -- Response
            local respLabel = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            respLabel:SetPoint("TOPLEFT", 26, -26)
            respLabel:SetText("Response:")
            
            local respBg = CreateFrame("Frame", nil, row, "BackdropTemplate")
            respBg:SetPoint("TOPLEFT", 80, -22)
            respBg:SetPoint("TOPRIGHT", -6, -22)
            respBg:SetHeight(50)
            respBg:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 8,
                insets = {left = 2, right = 2, top = 2, bottom = 2},
            })
            respBg:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
            respBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            
            local respEdit = CreateFrame("EditBox", nil, respBg)
            respEdit:SetPoint("TOPLEFT", 4, -4)
            respEdit:SetPoint("BOTTOMRIGHT", -4, 4)
            respEdit:SetFontObject("ChatFontSmall")
            respEdit:SetAutoFocus(false)
            respEdit:SetMultiLine(true)
            respEdit:SetText(rule.response or "")
            respEdit:SetScript("OnTextChanged", function(self) rule.response = self:GetText() end)
            respEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            
            table.insert(ruleRows, row)
            ruleY = ruleY - 84
        end
        
        rulesContainer:SetHeight(math.max(math.abs(ruleY), 10))
    end
    
    addBtn:SetScript("OnClick", function()
        table.insert(db.autoReplyRules, {enabled = true, keywords = "", response = ""})
        RefreshRules()
    end)
    
    RefreshRules()
    
    y = y - math.max(#db.autoReplyRules * 84, 10) - 20
    
    container:SetHeight(math.abs(y) + 20)
    content:SetHeight(math.abs(y) + 20)
end

--------------------------------------------------------------------------------
-- MAIN UI
--------------------------------------------------------------------------------

function Advertiser:BuildConfigUI(parent)
    local db = getDB()
    
    -- Show first-run popup if needed
    if EasyLife:ShouldShowFirstRun(db) then
        EasyLife:ShowFirstRunPopup("Advertise", "ADS_TITLE", "ADS_FIRST_RUN_DETAILED", db)
    end
    
    -- Tab data
    local tabInfo = {
        {id = "invite", text = "Auto Invite", build = BuildAutoInviteTab},
        {id = "message", text = "Send Message", build = BuildSendMessageTab},
        {id = "reply", text = "Auto Reply", build = BuildAutoReplyTab},
    }
    
    local tabs = {}
    local tabContents = {}
    local selectedTab = 1
    
    -- Tab bar at TOP
    local tabBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    tabBar:SetPoint("TOPLEFT", 0, 0)
    tabBar:SetPoint("TOPRIGHT", 0, 0)
    tabBar:SetHeight(30)
    tabBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    tabBar:SetBackdropColor(0.15, 0.12, 0.08, 1)
    tabBar:SetBackdropBorderColor(0.3, 0.25, 0.15, 1)
    
    -- Create tab buttons
    local tabWidth = 100
    for i, info in ipairs(tabInfo) do
        local tab = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
        tab:SetSize(tabWidth, 26)
        tab:SetPoint("LEFT", tabBar, "LEFT", 4 + (i-1) * (tabWidth + 4), 0)
        tab:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = {left = 0, right = 0, top = 0, bottom = 0},
        })
        
        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tab.text:SetPoint("CENTER", 0, 0)
        tab.text:SetText(info.text)
        
        tab:SetScript("OnEnter", function(self)
            if selectedTab ~= i then
                self:SetBackdropColor(0.25, 0.22, 0.15, 1)
            end
        end)
        tab:SetScript("OnLeave", function(self)
            if selectedTab ~= i then
                self:SetBackdropColor(0.12, 0.1, 0.06, 1)
            end
        end)
        
        tabs[i] = tab
    end
    
    -- Update tab appearance
    local function UpdateTabs()
        for i, tab in ipairs(tabs) do
            if i == selectedTab then
                tab:SetBackdropColor(0.35, 0.3, 0.2, 1)
                tab:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
                tab.text:SetTextColor(1, 0.9, 0.6)
            else
                tab:SetBackdropColor(0.12, 0.1, 0.06, 1)
                tab:SetBackdropBorderColor(0.25, 0.2, 0.1, 1)
                tab.text:SetTextColor(0.7, 0.65, 0.5)
            end
        end
    end
    
    -- Content area (directly below tabs - each tab has its own header now)
    local contentArea = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    contentArea:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, 0)
    contentArea:SetPoint("BOTTOMRIGHT", 0, 0)
    contentArea:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    contentArea:SetBackdropColor(0.06, 0.05, 0.04, 1)
    
    -- Create content for each tab
    for i, info in ipairs(tabInfo) do
        local scroll = CreateFrame("ScrollFrame", nil, contentArea, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 4, -4)
        scroll:SetPoint("BOTTOMRIGHT", -26, 4)
        scroll:Hide()
        
        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(scroll:GetWidth() > 0 and scroll:GetWidth() or 440)  -- Use available width
        scroll:SetScrollChild(content)
        
        -- Store scroll reference for centering
        content.scrollFrame = scroll
        
        info.build(content, db)
        tabContents[i] = scroll
    end
    
    -- Tab switching
    local function SelectTab(index)
        selectedTab = index
        UpdateTabs()
        for i, scroll in ipairs(tabContents) do
            scroll:SetShown(i == index)
        end
    end
    
    for i, tab in ipairs(tabs) do
        tab:SetScript("OnClick", function() SelectTab(i) end)
    end
    
    UpdateTabs()
    SelectTab(1)
end

-- Cleanup when settings window is closed or module is switched
function Advertiser:CleanupUI()
    if headerTimer then
        headerTimer:Cancel()
        headerTimer = nil
    end
    if sendMessageStatusTimer then
        sendMessageStatusTimer:Cancel()
        sendMessageStatusTimer = nil
    end
    if autoInviteStatusTimer then
        autoInviteStatusTimer:Cancel()
        autoInviteStatusTimer = nil
    end
    if autoReplyStatusTimer then
        autoReplyStatusTimer:Cancel()
        autoReplyStatusTimer = nil
    end
end

--------------------------------------------------------------------------------
-- REGISTER MODULE
--------------------------------------------------------------------------------

EasyLife:RegisterModule("Advertise", Advertiser)
