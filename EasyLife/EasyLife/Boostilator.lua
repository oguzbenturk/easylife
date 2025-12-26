local Boostilator = {}
local DEFAULTS = { enabled = false, boostAmount = 0 }

local function ensureDB()
  EasyLifeDB.boostilator = EasyLifeDB.boostilator or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.boostilator[k] == nil then
      EasyLifeDB.boostilator[k] = v
    end
  end
end

function Boostilator:OnInitialize()
  ensureDB()
end

function Boostilator:OnEnable()
  -- Code to enable the Boostilator functionality
end

function Boostilator:OnDisable()
  -- Code to disable the Boostilator functionality
end

function Boostilator:BuildConfigUI(parent)
  local db = EasyLifeDB.boostilator
  
  -- Create controls for configuration
  local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  checkbox:SetChecked(db.enabled)
  checkbox:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
  end)

  -- Additional configuration controls can be added here
end

EasyLife:RegisterModule("Boostilator", Boostilator)