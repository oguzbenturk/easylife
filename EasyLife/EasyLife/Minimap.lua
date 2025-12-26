local MinimapModule = {}

function MinimapModule:Initialize()
    self.minimapButton = CreateFrame("Button", "EasyLifeMinimapButton", Minimap)
    self.minimapButton:SetSize(32, 32)
    self.minimapButton:SetFrameStrata("MEDIUM")
    self.minimapButton:SetNormalTexture("Interface\\AddOns\\EasyLife\\Textures\\MinimapButton")
    self.minimapButton:SetHighlightTexture("Interface\\AddOns\\EasyLife\\Textures\\MinimapButton_Highlight")
    
    self.minimapButton:SetScript("OnClick", function()
        self:ToggleDropdownMenu()
    end)

    self.minimapButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(self.minimapButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("EasyLife", 1, 1, 1)
        GameTooltip:AddLine("Click to open the menu", nil, nil, nil, true)
        GameTooltip:Show()
    end)

    self.minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self:UpdatePosition()
end

function MinimapModule:UpdatePosition()
    local db = EasyLifeDB.minimap or {}
    if db.x and db.y then
        self.minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", db.x, db.y)
    else
        self.minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -5, -5)
    end
end

function MinimapModule:ToggleDropdownMenu()
    -- Logic to toggle the dropdown menu
end

function MinimapModule:CleanupUI()
    if self.minimapButton then
        self.minimapButton:Hide()
    end
end

EasyLife:RegisterModule("Minimap", MinimapModule)