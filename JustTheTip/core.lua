local addon = CreateFrame('Frame','JustTheTip',UIParent)
local kui = LibStub('Kui-1.0')
local kc = LibStub('KuiConfig-1.0')
local LSM = LibStub('LibSharedMedia-3.0')
local RMH

-- settings
local default_config = {
    X_OFFSET          = 0,
    Y_OFFSET          = 14,
    SUBTEXT_Y_OFFSET  = 13,
    FONT              = LSM:GetDefault(LSM.MediaType.FONT),
    FONT_STYLE        = 'THINOUTLINE',
    FONT_SHADOW       = false,
    FONT_SIZE         = 13,
    SUBTEXT_FONT_SIZE = 10
}

local UPDATE_PERIOD = .1
local last_update = UPDATE_PERIOD

local function SetPosition()
    local x, y = GetCursorPosition()
    x = (x / UIParent:GetScale()) + addon.profile.X_OFFSET
    y = (y / UIParent:GetScale()) + addon.profile.Y_OFFSET

    addon.text:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
        x, y)
    addon.subtext:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
        x, y + addon.profile.SUBTEXT_Y_OFFSET)
end

local GetNPCTitle
do
    local tooltip = CreateFrame('GameTooltip','JustTheTipNPCTitleTooltip',UIParent,'GameTooltipTemplate')

    -- (borrowed from KNP/plugins/guildtext)
    local function FixPattern(source)
        return "^"..source:gsub("%%.%$?s?",".+").."$"
    end
    local pattern = FixPattern(TOOLTIP_UNIT_LEVEL)
    local pattern_type = FixPattern(TOOLTIP_UNIT_LEVEL_TYPE)
    local pattern_class = FixPattern(TOOLTIP_UNIT_LEVEL_CLASS)
    local pattern_class_type = FixPattern(TOOLTIP_UNIT_LEVEL_CLASS_TYPE)

    GetNPCTitle = function()
        -- extract npc title from tooltip
        if UnitIsPlayer('mouseover') or UnitIsOtherPlayersPet('mouseover') then return end
        tooltip:SetOwner(UIParent,ANCHOR_NONE)
        tooltip:SetUnit('mouseover')

        local gtext = GetCVarBool('colorblindmode') and
                      JustTheTipNPCTitleTooltipTextLeft3:GetText() or
                      JustTheTipNPCTitleTooltipTextLeft2:GetText()

        tooltip:Hide()

        -- ignore strings matching TOOLTIP_UNIT_LEVEL
        if not gtext or
           gtext:find(pattern) or
           gtext:find(pattern_type) or
           gtext:find(pattern_class) or
           gtext:find(pattern_class_type)
        then
            return
        end

        return gtext
    end
end

-- main tooltip update function
local function UpdateDisplay()
    local focus = GetMouseFocus()
    if focus and focus:GetName() ~= "WorldFrame" then
        -- hide when mousing over unit frames and such
        addon:Hide()
        return
    end

    local name = UnitName('mouseover')
    if not name then return end

    local u = 'mouseover'
    local level,cl,levelColour = kui.UnitLevel(u)
    local AFK,DND,faction =
        UnitIsAFK(u),
        UnitIsDND(u),
        UnitIsPlayer(u) and UnitFactionGroup(u) or nil

    local health,max
    if RMH then
        health,max = RMH.GetUnitHealth(u)
    else
        health,max = UnitHealth(u),UnitHealthMax(u)
    end

    -- resolve faction suffix
    local factionSuf = ''
    if faction ~= nil and faction ~= UnitFactionGroup('player') then
        factionSuf = ' |cffff3333!|r'
    end

    -- resolve status
    local status = (AFK and "[Away] ") or (DND and "[Busy] ") or ""

    -- resolve level colour to hex
    levelColour = format("%02x%02x%02x",
        levelColour.r*255,
        levelColour.g*255,
        levelColour.b*255)

    -- resolve name colour
    local unitColour = kui.GetUnitColour(u)
    local nameColour = format("%02x%02x%02x",
        unitColour.r*255,
        unitColour.g*255,
        unitColour.b*255)

    -- resolve colour length of name as a percentage of health
    local healthLength = strlen(name) * (health / max)

    addon.text:SetText(
        '|cff'..levelColour..level..cl..'|r '..
        '|cff'..nameColour..status..kui.utf8sub(name, 0, healthLength)..'|r'..
        kui.utf8sub(name, healthLength + 1)..
        (factionSuf or ''))

    -- mouseover's target (subtext)
    if UnitIsVisible("mouseovertarget") then
        local name = UnitName("mouseovertarget")

        if name == UnitName("player") then
            addon.subtext:SetTextColor(1,.1,.1)
            addon.subtext:SetText('|cffff0000You')
        else
            local nameColour = kui.GetUnitColour('mouseovertarget')
            addon.subtext:SetTextColor(nameColour.r,nameColour.g,nameColour.b)
            addon.subtext:SetText(name)
        end
    else
        local npc_title = GetNPCTitle()
        addon.subtext:SetText(npc_title or '')
        if npc_title then
            addon.subtext:SetTextColor(kui.Brighten(.7,unitColour.r,unitColour.g,unitColour.b))
        end
    end

    SetPosition()
    addon:Show()
end

-- script handlers
local function OnUpdate(self,elap)
    last_update = last_update + elap

    if not UnitExists("mouseover") then
        self:Hide()
        return
    end

    -- update position every frame
    SetPosition()

    if last_update > UPDATE_PERIOD then
        last_update = 0

        local target, health =
            UnitName('mouseovertarget'),
            UnitHealth('mouseover')

        if target ~= self.target or health ~= self.health then
            -- target or health has changed
            UpdateDisplay()
        end
    end
end

function addon:ConfigChanged()
    self.profile = self.config:GetConfig()
    local p = self.profile
    local font = LSM:Fetch(LSM.MediaType.FONT,p.FONT)

    self.text:SetFont(font,p.FONT_SIZE,p.FONT_STYLE)
    self.subtext:SetFont(font,p.SUBTEXT_FONT_SIZE,p.FONT_STYLE)

    if p.FONT_SHADOW then
        self.text:SetShadowColor(0,0,0,1)
        self.subtext:SetShadowColor(0,0,0,1)
        self.text:SetShadowOffset(1,-1)
        self.subtext:SetShadowOffset(1,-1)
    else
        self.text:SetShadowColor(0,0,0,0)
        self.subtext:SetShadowColor(0,0,0,0)
    end
end

-- event handlers
function addon:ADDON_LOADED(name)
    if name ~= 'JustTheTip' then return end

    if kui.CLASSIC and RealMobHealth then
        RMH = RealMobHealth
    end

    self:SetFrameStrata("TOOLTIP")
    self:Hide()

    self.text = self:CreateFontString(nil, "OVERLAY")
    self.text:SetTextColor(.5, .5, .5)

    self.subtext = self:CreateFontString(nil, "OVERLAY")

    self.config = kc:Initialise('JustTheTip',default_config)
    self.config:RegisterConfigChanged(self,'ConfigChanged')
    self:ConfigChanged()

    self:SetScript('OnUpdate', OnUpdate)
end

function addon:UPDATE_MOUSEOVER_UNIT()
    UpdateDisplay()
end

-- initialise
addon:SetScript('OnEvent', function(self,event,...)
    self[event](self,...)
end)

addon:RegisterEvent('ADDON_LOADED')
addon:RegisterEvent('UPDATE_MOUSEOVER_UNIT')
