local EasyLife = {}
EasyLife.modules = {}

function EasyLife:RegisterModule(name, module)
    if not self.modules[name] then
        self.modules[name] = module
        if module.OnInitialize then
            module:OnInitialize()
        end
    end
end

function EasyLife:L(key)
    -- Localization function to retrieve strings based on the key
    return self.locales[key] or key
end

function EasyLife:OnInitialize()
    -- Initialization code for the addon
end

function EasyLife:OnEnable()
    -- Code to run when the addon is enabled
end

function EasyLife:OnDisable()
    -- Code to run when the addon is disabled
end

-- Slash command handling
SLASH_EASYLIFE1 = "/easylife"
function SlashCmdList.EASYLIFE(msg, editBox)
    -- Handle slash commands
end

-- Event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == "EasyLife" then
        EasyLife:OnInitialize()
    end
end)

return EasyLife