-- to-do:
-- make text bigger without distorting
-- make floating text appear at target (long term)

local player = nil
local realm = nil
local healthFont
local version = 0.8

local HealOverTimeSpells = {
  ["Renew"] = true,
  ["Rejuvenation"] = true,
  ["Regrowth"] = true,
  ["Vampiric Embrace"] = true,
}

local function Draggable(self, bool)
  self:SetMovable(bool)
  self:EnableMouse(bool)
end

local function UpdatePosition(pt, rp, xo, yo)
  SHT_SETTINGS.position.point = pt
  SHT_SETTINGS.position.rel_point = rp
  SHT_SETTINGS.position.x_offset = xo
  SHT_SETTINGS.position.y_offset = yo
end

local function ToggleHOTs()
  SHT_SETTINGS.hots = not SHT_SETTINGS.hots
  return SHT_SETTINGS.hots
end

local function ToggleMove()
  SHT_SETTINGS.move = not SHT_SETTINGS.move
  Draggable(SimpleHealingText, SHT_SETTINGS.move)
  return SHT_SETTINGS.move
end

local function ShowHeal(self, event, ...)
  local type, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = ...
  local spellID, spellName, spellSchool
  local amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand

  if type == "SPELL_HEAL" and sourceName == player then
    spellName, _, amount, overheal, _, critical = select(12, ...)
    if not (not SHT_SETTINGS.hots and HealOverTimeSpells[spellName] ~= nil) then
      if critical == true then
        healthFont:SetText("+"..amount.."(Crit) ("..destName..")")
      else
        healthFont:SetText("+"..amount.." ("..destName..")")
      end
    end
  end
end

local function FrameDragStart(self, event, ...)
  self:StartMoving()
end

local function FrameDragStop(self, event, ...)
  local frame = SimpleHealingText
  self:StopMovingOrSizing()

  point, _, rel_point, x_offset, y_offset = self:GetPoint()
  if x_offset < 20 and x_offset > -20 then
      x_offset = 0
  end
  self:SetPoint(point, UIParent, rel_point, x_offset, y_offset)
  UpdatePosition(point, rel_point, x_offset, y_offset)
end

function SimpleHealingText_OnLoad(self, event, ...)
  self:RegisterEvent("ADDON_LOADED")
end

function SimpleHealingText_OnEvent(self, event, ...)
  if event == "ADDON_LOADED" and ... == "SimpleHealingText" then
    self:UnregisterEvent("ADDON_LOADED")

    -- Settings to save between sessions --
    if type(SHT_SETTINGS) ~= "table" then
      -- Default settings initialized the first time the addon is loaded --
      SHT_SETTINGS = {
        move = true,
        hots = true,
        disabled = false,
        position = {
          point = "CENTER",
          rel_point = "CENTER",
          x_offset = 0,
          y_offset = 0
        }
      }
    end

    player, realm = UnitName("player")

    SimpleHealingText:SetSize(100, 25)
    SimpleHealingText:SetPoint(SHT_SETTINGS.position.point, "UIParent", SHT_SETTINGS.position.rel_point, SHT_SETTINGS.position.x_offset, SHT_SETTINGS.position.y_offset)
    healthFont = SimpleHealingText:CreateFontString("SimpleHealingTextFontString", "ARTWORK", "GameFontNormal")
    healthFont:SetPoint("CENTER", "SimpleHealingText", "CENTER", 0, 0)
    healthFont:SetTextColor(0, 1, 0)
    healthFont:SetText("Waiting for a heal...")
    
    if disabled ~= nil then
      disabled = false
    elseif disabled == true then
      SimpleHealingText:Hide()
    else
      SimpleHealingText:Show()
      healthFont:Show()


    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:SetScript("OnEvent",
              function(self, event)
                ShowHeal(event, CombatLogGetCurrentEventInfo())
              end)

    Draggable(self, SHT_SETTINGS.move)
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", FrameDragStart)
    self:SetScript("OnDragStop", FrameDragStop)

    print("SimpleHealingText v"..version.." loaded.")
  end
end

-- SLASH / Commands --
local SHTSlashCommands = {
  enable = function(self)
    SimpleHealingText:Show()
    disabled = false
    return "SHT: Enabled."
  end,

  disable = function(self)
    SimpleHealingText:Hide()
    disabled = true
    return "SHT: Disabled (use '/sht enable' to reenable)."
  end,

  move = function(self)
    if ToggleMove() then
      return "SHT: Moving enabled."
    else
      return "SHT: Moving disabled."
    end
  end,

  hots = function(self)
    if ToggleHOTs() then
      return "SHT: Heal Over Time spells are now enabled."
    else
      return "SHT: Heal Over Time spells are now disabled."
    end
  end,

  help = function(self)
    -- Multiple strings used to make the return statement a bit shorter.
    helpString = "SHT: Use '/sht arg' where 'arg' can be the following:\n"
    enableString = "-- 'enable' enables the addon if disabled.\n"
    disableString = "-- 'disable' disables the addon and hides the text.\n"
    enablemoveString = "-- 'move' toggles the ability to drag/move the text.\n"
    disablemoveString = "-- 'hots' toggles whether it shows heal over time spells."
    return helpString .. enableString .. disableString .. enablemoveString .. disablemoveString
  end,

}

local function HandleSlashCommands(str)
  local s = type(SHTSlashCommands[str]) == "function" and SHTSlashCommands[string.lower(str)]() or "SHT: Unknown command, use '/sht help' to see available commands."
  print(s)
end

-- Actual slash commands to be used and "inserting" them into blizzard's global
-- slash command table/list.
SLASH_SimpleHealingText1 = "/sht"
SLASH_SimpleHealingText2 = "/simplehealingtext"
SlashCmdList.SimpleHealingText = HandleSlashCommands
