local EasyLife = EasyLife or {}
local MODULE_LIST = {}

local function CreateModuleButton(parent, moduleName)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(200, 30)
    button:SetText(moduleName)
    button:SetNormalFontObject("GameFontNormal")
    button:SetHighlightFontObject("GameFontHighlight")
    
    button:SetScript("OnClick", function()
        -- Logic to toggle module settings
    end)

    return button
end

function EasyLife:BuildConfigUI(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)
    title:SetText("EasyLife Configuration")

    local moduleListFrame = CreateFrame("Frame", nil, parent)
    moduleListFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    moduleListFrame:SetSize(300, 400)

    for _, moduleName in ipairs(MODULE_LIST) do
        local button = CreateModuleButton(moduleListFrame, moduleName)
        button:SetPoint("TOPLEFT", moduleListFrame, "TOPLEFT", 0, -(#MODULE_LIST * 30))
    end
end

function EasyLife:RegisterModule(moduleName, module)
    MODULE_LIST[#MODULE_LIST + 1] = moduleName
    -- Additional registration logic
end

-- Additional configuration logic can be added here

EasyLife:RegisterModule("Config", EasyLife)