-- to-do:
-- make text bigger without distorting
-- make floating text appear at target (long term)

local player = nil
local realm = nil
local healthFont
local version = 0.8
local elapsedTime = 0.0

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

local function SHT_OnUpdate(self, elapsed)
  elapsedTime = elapsedTime + elapsed
  if elapsedTime >= SHT_SETTINGS.hide and SHT_SETTINGS.hide > 0.0 then
    --UIFrameFadeOut(SimpleHealingText, 1.0, 1, 0)
    SimpleHealingText:Hide()
    elapsedTime = 0.0
  end
end

local function ToggleAutoHide()
  if SHT_SETTINGS.hide > 0.0 then
    SHT_SETTINGS.hide = 0.0
    SimpleHealingText:Show()
    return false
  else
    elapsedTime = 0.0
    SHT_SETTINGS.hide = 5.0
    return true
  end
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

  if (type == "SPELL_HEAL" or type == "SPELL_PERIODIC_HEAL") and sourceName == player then
    spellName, _, amount, overheal, _, critical = select(12, ...)
    if not (not SHT_SETTINGS.hots and HealOverTimeSpells[spellName] ~= nil) then
      if critical == true then
        healthFont:SetText("+"..amount.."(Crit) ("..spellName.." > "..destName..")")
      else
        healthFont:SetText("+"..amount.." ("..spellName.." > "..destName..")")
      end
      SimpleHealingText:Show()
      elapsedTime = 0.0
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
        hide = 0.0,
        position = {
          point = "CENTER",
          rel_point = "CENTER",
          x_offset = 0,
          y_offset = 0
        }
      }
    end

    if SHT_SETTINGS.hide == nil then
      SHT_SETTINGS.hide = 0.0
    end
    elapsedTime = 0.0

    player, realm = UnitName("player")

    SimpleHealingText:SetSize(100, 25)
    SimpleHealingText:SetPoint(SHT_SETTINGS.position.point, "UIParent", SHT_SETTINGS.position.rel_point, SHT_SETTINGS.position.x_offset, SHT_SETTINGS.position.y_offset)
    healthFont = SimpleHealingText:CreateFontString("SimpleHealingTextFontString", "ARTWORK", "GameFontNormal")
    healthFont:SetPoint("CENTER", "SimpleHealingText", "CENTER", 0, 0)
    healthFont:SetTextColor(0, 1, 0)
    healthFont:SetText("Waiting for a heal...")

    if SHT_SETTINGS.disabled == nil then
      SHT_SETTINGS.disabled = false
    end
    if SHT_SETTINGS.disabled == true then
      SimpleHealingText:Hide()
    else
      SimpleHealingText:Show()
      healthFont:Show()
    end

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:SetScript("OnEvent",
              function(self, event)
                ShowHeal(event, CombatLogGetCurrentEventInfo())
              end)
    self:SetScript("OnUpdate", SHT_OnUpdate)
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
    SHT_SETTINGS.disabled = false
    return "SHT: Enabled."
  end,

  disable = function(self)
    SimpleHealingText:Hide()
    SHT_SETTINGS.disabled = true
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

  autohide = function(self)
    if ToggleAutoHide() then
      return "Hiding Text after 5 seconds with no heal."
    else
      return "Auto hiding text disabled."
    end
  end,

  help = function(self)
    -- Multiple strings used to make the return statement a bit shorter.
    helpString = "SHT: Use '/sht arg' where 'arg' can be the following:\n"
    enableString = "-- 'enable' enables the addon if disabled.\n"
    disableString = "-- 'disable' disables the addon and hides the text.\n"
    enablemoveString = "-- 'move' toggles the ability to drag/move the text.\n"
    disablemoveString = "-- 'hots' toggles whether it shows heal over time spells.\n"
    autohideString = "-- 'autohide' toggles whether there is a 5 second auto hide when no heal is detected.\n"
    return helpString .. enableString .. disableString .. enablemoveString .. disablemoveString .. autohideString
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
