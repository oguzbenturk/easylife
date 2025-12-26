-- EasyLife Single Minimap Button
local button
local dropdown

local function initDropdown(self, level)
  level = level or 1
  local menu = self.easyLifeMenu or {}
  for _, item in ipairs(menu) do
    local info = UIDropDownMenu_CreateInfo()
    for k, v in pairs(item) do
      info[k] = v
    end
    UIDropDownMenu_AddButton(info, level)
  end
end

local function buildMenu()
  local list = EasyLife_Config_GetModuleList and EasyLife_Config_GetModuleList() or {}
  local menu = {
    { text = "EasyLife", isTitle = true, notCheckable = true },
  }

  for _, modInfo in ipairs(list) do
    local moduleName = modInfo.name
    local label = moduleName
    if modInfo.key and EasyLife and EasyLife.L then
      label = EasyLife:L(modInfo.key)
    end
    table.insert(menu, {
      text = label,
      notCheckable = true,
      func = function()
        if EasyLife_Config_OpenSingle then
          EasyLife_Config_OpenSingle(moduleName)
        elseif EasyLife_Config_OpenTo then
          EasyLife_Config_OpenTo(moduleName)
        else
          EasyLife_Config_Open()
          EasyLife_Config_SelectModule(moduleName)
        end
      end,
    })
  end

  table.insert(menu, { text = " ", disabled = true, notCheckable = true })
  table.insert(menu, {
    text = EasyLife and EasyLife.L and EasyLife:L("CONFIG_TITLE") or "Settings",
    notCheckable = true,
    func = function()
      EasyLife_Config_Open()
    end,
  })

  return menu
end

local function angleToXY(angle, radius)
  local rad = math.rad(angle)
  return math.cos(rad) * radius, math.sin(rad) * radius
end

local function placeButton()
  if not button then return end
  local db = EasyLife:GetDB()
  local angle = db.minimapAngle or 45
  local x, y = angleToXY(angle, 80)
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function EasyLife_Minimap_Init()
  if button then return end

  if not dropdown then
    dropdown = CreateFrame("Frame", "EasyLifeMinimapDropdown", UIParent, "UIDropDownMenuTemplate")
    dropdown.displayMode = "MENU"
  end
  
  button = CreateFrame("Button", "EasyLifeMinimapButton", Minimap)
  button:SetSize(32, 32)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  
  local overlay = button:CreateTexture(nil, "OVERLAY")
  overlay:SetSize(53, 53)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetPoint("TOPLEFT")
  
  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetTexture("Interface\\Icons\\Spell_Holy_AuraOfLight")
  icon:SetPoint("CENTER", 0, 1)
  button.icon = icon
  
  button:SetScript("OnClick", function(self, btn)
    if btn == "LeftButton" or btn == "RightButton" then
      dropdown.easyLifeMenu = buildMenu()
      UIDropDownMenu_Initialize(dropdown, initDropdown, "MENU")
      ToggleDropDownMenu(1, nil, dropdown, self, 0, 0)
    end
  end)
  
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("EasyLife")
    GameTooltip:AddLine("Click: Open menu", 1, 1, 1)
    GameTooltip:AddLine("Drag: Move button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local cx, cy = Minimap:GetCenter()
      local mx, my = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      mx, my = mx / scale, my / scale
      local angle = math.deg(math.atan2(my - cy, mx - cx))
      EasyLife:GetDB().minimapAngle = angle
      placeButton()
    end)
  end)
  
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  
  placeButton()
  button:Show()
end
