local addon = CreateFrame('Frame','JustTheTip',UIParent)
local kui = LibStub('Kui-1.0')
local RMH

-- globals
local len,format = string.len,string.format

-- settings
local c = {
    X_OFFSET          = 0,
    Y_OFFSET          = 14,
    SUBTEXT_Y_OFFSET  = 13,
    FONT              = 'Fonts\\FRIZQT__.TTF',
    FONT_STYLE        = 'THINOUTLINE',
    FONT_SHADOW       = false,
    FONT_SIZE         = 13,
    SUBTEXT_FONT_SIZE = 10
}

local UPDATE_PERIOD = .1
local last_update = UPDATE_PERIOD

local function SetPosition()
    local x, y = GetCursorPosition()
    x = (x / UIParent:GetScale()) + c.X_OFFSET
    y = (y / UIParent:GetScale()) + c.Y_OFFSET

    addon.text:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
        x, y)
    addon.subtext:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
        x, y + c.SUBTEXT_Y_OFFSET)
end

-- main tooltip update function
local function UpdateDisplay()
    local focus = GetMouseFocus()
    if focus and focus:GetName() ~= "WorldFrame" then
        -- hide when mousing over unit frames and such
        addon:Hide()
        return
    end

    local u = 'mouseover'
    local level,cl,levelColour = kui.UnitLevel(u)
    local name,AFK,DND,health,max,faction =
        UnitName(u),
        UnitIsAFK(u),
        UnitIsDND(u),
        UnitHealth(u),
        UnitHealthMax(u),
        UnitIsPlayer(u) and UnitFactionGroup(u) or nil

    -- resolve faction suffix
    local factionSuf = ''
    if faction ~= nil and faction ~= UnitFactionGroup('player') then
        factionSuf = ' |cffff3333!|r'
    end

    -- resolve status
    local status = (AFK and "[Away] ") or (DND and "[Busy] ") or ""

    -- resolve level to hex string
    levelColour = format("%02x%02x%02x",
        levelColour.r*255,
        levelColour.g*255,
        levelColour.b*255)

    -- resolve name colour
    local nameColour = kui.GetUnitColour(u)
    nameColour = format("%02x%02x%02x",
        nameColour.r*255,
        nameColour.g*255,
        nameColour.b*255)

    -- resolve colour length of name as a percentage of health
    local healthLength = len(name) * (health / max)

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
        addon.subtext:SetText("")
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

-- event handlers
function addon:ADDON_LOADED(name)
    if name ~= 'JustTheTip' then return end

    if kui.CLASSIC and RealMobHealth then
        RMH = RealMobHealth
    end

    self:SetFrameStrata("TOOLTIP")
    self:Hide()

    self.text = self:CreateFontString(nil, "OVERLAY")
    self.text:SetFont(c.FONT, c.FONT_SIZE, c.FONT_STYLE)

    self.subtext = self:CreateFontString(nil, "OVERLAY")
    self.subtext:SetFont(c.FONT, c.SUBTEXT_FONT_SIZE, c.FONT_STYLE)

    if c.FONT_SHADOW then
        self.text:SetShadowOffset(1,-1)
        self.subtext:SetShadowOffset(1,-1)
    end

    self.text:SetTextColor(.5, .5, .5)

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
