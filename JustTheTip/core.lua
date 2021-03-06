local addon = CreateFrame('Frame','JustTheTip',UIParent)
local kui = LibStub('Kui-1.0')
local kc = LibStub('KuiConfig-1.0')
local LSM = LibStub('LibSharedMedia-3.0')
local RMH

-- settings
local default_config = {
    X_OFFSET          = 0,
    Y_OFFSET          = 14,
    SUBTEXT_Y_OFFSET  = 14,
    FONT              = LSM:GetDefault(LSM.MediaType.FONT),
    FONT_STYLE        = 'THINOUTLINE',
    FONT_SHADOW       = true,
    FONT_SIZE         = 13,
    SUBTEXT_FONT_SIZE = 10,
    BRIGHTEN_CLASS    = .2,
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
        if UnitIsPlayer('mouseover') or kui.UnitIsPet('mouseover') then
           return
        end

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

local function GetUnitColour(u)
    -- resolve name colour (reimplementation of kui.GetUnitColour)
    if UnitIsTapDenied(u) then
        return .75,.75,.75
    elseif UnitIsDeadOrGhost(u) or not UnitIsConnected(u) then
        return .5,.5,.5
    elseif UnitIsPlayer(u) or kui.UnitIsPet(u) then
        -- class colour (w/CUSTOM_CLASS_COLORS support)
        local r,g,b = kui.GetClassColour(u,2)

        if type(addon.profile.BRIGHTEN_CLASS) == 'number' then
            return kui.Brighten(addon.profile.BRIGHTEN_CLASS,r,g,b)
        else
            return r,g,b
        end
    else
        -- reaction colour
        return UnitSelectionColor(u)
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

    local name_r,name_g,name_b = GetUnitColour('mouseover')
    if not name_r then return end

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

    do
        -- colour strings
        local level_hex = format("%02x%02x%02x",levelColour.r*255,levelColour.g*255,levelColour.b*255)
        local name_hex = format("%02x%02x%02x",name_r*255,name_g*255,name_b*255)

        -- resolve status
        local status = (AFK and "[Away] ") or (DND and "[Busy] ") or ""

        -- resolve colour length of name as a percentage of health
        local healthLength = strlen(name) * (health / max)

        -- resolve faction suffix
        local factionSuf = ''
        if faction ~= nil and faction ~= UnitFactionGroup('player') then
            factionSuf = ' |cffff3333!|r'
        end

        addon.text:SetText(
            '|cff'..level_hex..level..cl..'|r '..
            '|cff'..name_hex..status..kui.utf8sub(name, 0, healthLength)..'|r'..
            kui.utf8sub(name, healthLength + 1)..
            (factionSuf or ''))
    end

    if UnitIsVisible("mouseovertarget") then
        -- mouseover's target name
        local name = UnitName("mouseovertarget")

        if name == UnitName("player") then
            addon.subtext:SetTextColor(1,.1,.1)
            addon.subtext:SetText('|cffff0000You')
        else
            addon.subtext:SetTextColor(GetUnitColour('mouseovertarget'))
            addon.subtext:SetText(name)
        end
    else
        -- npc title (or blank)
        local npc_title = GetNPCTitle()
        addon.subtext:SetText(npc_title or '')

        if npc_title then
            -- XXX this won't conflict with brightening in GetUnitColour,
            -- since that doesn't apply to NPCs...
            addon.subtext:SetTextColor(kui.Brighten(.7,name_r,name_g,name_b))
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
function addon:PLAYER_LOGIN()
    self:UnregisterEvent('PLAYER_LOGIN')

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

addon:RegisterEvent('PLAYER_LOGIN')
addon:RegisterEvent('UPDATE_MOUSEOVER_UNIT')
