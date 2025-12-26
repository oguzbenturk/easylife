local Advertiser = {}
local DEFAULTS = { enabled = false, x = 0, y = 0 }

local function ensureDB()
  EasyLifeDB.Advertiser = EasyLifeDB.Advertiser or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.Advertiser[k] == nil then
      EasyLifeDB.Advertiser[k] = v
    end
  end
end

function Advertiser:OnInitialize()
  ensureDB()
  -- Additional initialization code can go here
end

function Advertiser:BuildConfigUI(parent)
  local db = EasyLifeDB.Advertiser
  
  -- Create controls as children of parent
  local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
  checkbox:SetChecked(db.enabled)
  checkbox.text:SetText("Enable Advertiser")
  
  checkbox:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
  end)
  
  -- Show first-run popup if needed
  if EasyLife:ShouldShowFirstRun(db) then
    EasyLife:ShowFirstRunPopup("Advertiser", "ADVERTISER_TITLE", "ADVERTISER_FIRST_RUN_DETAILED", db)
  end
end

function Advertiser:CleanupUI()
  -- Hide any floating frames created by this module
end

EasyLife:RegisterModule("Advertiser", Advertiser)