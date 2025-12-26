local CastBarAura = {}
local DEFAULTS = { enabled = false, x = 0, y = 0 }

local function ensureDB()
  EasyLifeDB.CastBarAura = EasyLifeDB.CastBarAura or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.CastBarAura[k] == nil then
      EasyLifeDB.CastBarAura[k] = v
    end
  end
end

function CastBarAura:BuildConfigUI(parent)
  local db = EasyLifeDB.CastBarAura
  ensureDB()

  -- Show first-run popup if needed
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("CastBarAura", "CASTBAR_TITLE", "CASTBAR_FIRST_RUN_DETAILED", db)
  end

  -- Create controls as children of parent
  local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
  checkbox:SetChecked(db.enabled)
  checkbox.text:SetText("Enable CastBarAura")
  checkbox:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
  end)
end

function CastBarAura:CleanupUI()
  -- Hide any floating frames created by this module
end

EasyLife:RegisterModule("CastBarAura", CastBarAura)