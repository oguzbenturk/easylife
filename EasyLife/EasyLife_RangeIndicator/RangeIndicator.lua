local RangeIndicator = {}
local DEFAULTS = { enabled = false, range = 30 }

local function ensureDB()
  EasyLifeDB.RangeIndicator = EasyLifeDB.RangeIndicator or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.RangeIndicator[k] == nil then
      EasyLifeDB.RangeIndicator[k] = v
    end
  end
end

function RangeIndicator:OnInitialize()
  ensureDB()
  -- Additional initialization code can go here
end

function RangeIndicator:BuildConfigUI(parent)
  local db = EasyLifeDB.RangeIndicator
  
  -- Create controls as children of parent
  local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
  checkbox:SetChecked(db.enabled)
  checkbox.text:SetText("Enable Range Indicator")
  
  checkbox:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
  end)

  -- Show first-run popup if needed
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("RangeIndicator", "RANGE_INDICATOR_TITLE", "RANGE_INDICATOR_FIRST_RUN_DETAILED", db)
  end
end

function RangeIndicator:CleanupUI()
  -- Hide any floating frames created by this module
end

EasyLife:RegisterModule("RangeIndicator", RangeIndicator)