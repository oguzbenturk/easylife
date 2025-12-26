local VendorTracker = {}
local DEFAULTS = { enabled = false, trackVendors = true }

local function ensureDB()
  EasyLifeDB.VendorTracker = EasyLifeDB.VendorTracker or {}
  for k, v in pairs(DEFAULTS) do
    if EasyLifeDB.VendorTracker[k] == nil then
      EasyLifeDB.VendorTracker[k] = v
    end
  end
end

function VendorTracker:OnInitialize()
  ensureDB()
end

function VendorTracker:TrackVendor(vendorID)
  if EasyLifeDB.VendorTracker.trackVendors then
    -- Logic to track vendor activities
  end
end

function VendorTracker:BuildConfigUI(parent)
  local db = EasyLifeDB.VendorTracker
  
  -- Create controls for enabling/disabling vendor tracking
  local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  checkbox:SetChecked(db.enabled)
  checkbox:SetScript("OnClick", function(self)
    db.enabled = self:GetChecked()
  end)

  -- Additional configuration options can be added here
end

EasyLife:RegisterModule("VendorTracker", VendorTracker)