local AggroAlert = {}
local DEFAULTS = { enabled = false, alertThreshold = 80 }

local function ensureDB()
  EasyLifeDB.AggroAlert = EasyLifeDB.AggroAlert or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.AggroAlert[k] == nil then
      EasyLifeDB.AggroAlert[k] = v
    end
  end
end

function AggroAlert:OnInitialize()
  ensureDB()
end

function AggroAlert:OnEvent(event, ...)
  -- Handle aggro-related events here
end

function AggroAlert:BuildConfigUI(parent)
  local db = EasyLifeDB.AggroAlert
  
  -- Create controls for configuration
  local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  checkbox:SetChecked(db.enabled)
  checkbox:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
  end)

  -- Additional configuration controls can be added here
end

EasyLife:RegisterModule("AggroAlert", AggroAlert)