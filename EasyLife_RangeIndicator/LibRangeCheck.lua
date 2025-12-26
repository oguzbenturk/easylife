-- LibRangeCheck-3.0 Lite for Classic Era
-- Simplified range checking using class spells

local MAJOR_VERSION = "LibRangeCheck-3.0"
local MINOR_VERSION = 1

if not LibStub then
  -- Minimal LibStub
  LibStub = LibStub or {
    libs = {},
    NewLibrary = function(self, name, version)
      self.libs[name] = self.libs[name] or {}
      self.libs[name].version = version
      return self.libs[name]
    end,
  }
  function LibStub:GetLibrary(name, silent)
    return self.libs[name]
  end
end

local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

-- Spell range data for Classic Era
-- Format: spellID = maxRange
local HOSTILE_SPELLS = {
  -- Warrior
  [100] = 8,    -- Charge (min 8, max 25)
  [355] = 30,   -- Taunt
  [2764] = 30,  -- Throw
  
  -- Paladin
  [20271] = 30, -- Judgement
  [879] = 30,   -- Exorcism
  
  -- Hunter
  [75] = 35,    -- Auto Shot
  [2974] = 5,   -- Wing Clip
  [19503] = 20, -- Scatter Shot
  
  -- Rogue
  [2098] = 5,   -- Eviscerate
  [1752] = 5,   -- Sinister Strike
  [2094] = 10,  -- Blind
  [26679] = 25, -- Deadly Throw
  
  -- Priest
  [589] = 30,   -- Shadow Word: Pain
  [8092] = 30,  -- Mind Blast
  [15407] = 30, -- Mind Flay
  
  -- Shaman
  [403] = 30,   -- Lightning Bolt
  [8042] = 5,   -- Earth Shock
  
  -- Mage
  [133] = 35,   -- Fireball
  [116] = 35,   -- Frostbolt
  [5019] = 30,  -- Shoot (wand)
  [2136] = 20,  -- Fire Blast
  
  -- Warlock
  [686] = 30,   -- Shadow Bolt
  [172] = 30,   -- Corruption
  [5782] = 20,  -- Fear
  
  -- Druid
  [5176] = 30,  -- Wrath
  [8921] = 30,  -- Moonfire
  [6795] = 5,   -- Growl (bear form taunt, melee range technically but usable)
}

local FRIENDLY_SPELLS = {
  -- Priest
  [2050] = 40,  -- Lesser Heal
  [17] = 30,    -- Power Word: Shield
  
  -- Paladin
  [635] = 40,   -- Holy Light
  [19740] = 30, -- Blessing of Might
  
  -- Shaman
  [331] = 40,   -- Healing Wave
  
  -- Druid
  [774] = 40,   -- Rejuvenation
  [5185] = 40,  -- Healing Touch
}

local playerClass
local checkers = {}

local function initCheckers()
  playerClass = select(2, UnitClass("player"))
  
  -- Build list of spells we know for range checking
  checkers = {}
  
  for spellID, range in pairs(HOSTILE_SPELLS) do
    if IsSpellKnown(spellID) then
      table.insert(checkers, { spellID = spellID, range = range, type = "hostile" })
    end
  end
  
  for spellID, range in pairs(FRIENDLY_SPELLS) do
    if IsSpellKnown(spellID) then
      table.insert(checkers, { spellID = spellID, range = range, type = "friendly" })
    end
  end
  
  -- Sort by range ascending
  table.sort(checkers, function(a, b) return a.range < b.range end)
end

function lib:GetRange(unit)
  if not unit or not UnitExists(unit) then return nil, nil end
  
  -- Initialize on first call
  if not playerClass then
    initCheckers()
  end
  
  local minRange, maxRange = 0, nil
  local isHostile = UnitCanAttack("player", unit)
  
  -- Use spell range checks
  for _, checker in ipairs(checkers) do
    -- Only use appropriate spell type
    if (isHostile and checker.type == "hostile") or (not isHostile and checker.type == "friendly") then
      local inRange = IsSpellInRange(checker.spellID, unit)
      if inRange == 1 then
        -- Unit is in range of this spell
        maxRange = checker.range
        return minRange, maxRange
      elseif inRange == 0 then
        -- Unit is out of range, update minimum
        minRange = checker.range
      end
      -- nil means spell not usable on this target, skip
    end
  end
  
  -- Fallback to interact distance
  if CheckInteractDistance(unit, 1) then return 0, 10 end
  if CheckInteractDistance(unit, 2) then return 0, 11 end
  if CheckInteractDistance(unit, 3) then return 0, 10 end
  if CheckInteractDistance(unit, 4) then return 0, 28 end
  
  return minRange, nil  -- nil maxRange = very far
end

-- Refresh checkers on talent/spec changes
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:SetScript("OnEvent", function()
  initCheckers()
end)
