local IceBlockHelper = {}
local DEFAULTS = { enabled = false, x = 0, y = 0 }

local function ensureDB()
  EasyLifeDB.IceBlockHelper = EasyLifeDB.IceBlockHelper or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.IceBlockHelper[k] == nil then
      EasyLifeDB.IceBlockHelper[k] = v
    end
  end
end

function IceBlockHelper:BuildConfigUI(parent)
  local db = EasyLifeDB.IceBlockHelper
  ensureDB()

  -- Show first-run popup if needed
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("IceBlockHelper", "ICEBLOCK_TITLE", "ICEBLOCK_FIRST_RUN_DETAILED", db)
  end

  -- Create controls as children of parent
  local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
  checkbox:SetChecked(db.enabled)
  checkbox.text:SetText("Enable IceBlock Helper")
  checkbox:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
  end)
end

function IceBlockHelper:CleanupUI()
  -- Hide any floating frames created by this module
end

EasyLife:RegisterModule("IceBlockHelper", IceBlockHelper)