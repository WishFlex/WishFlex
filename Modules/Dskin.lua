local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')
local WUI = E:GetModule('WishFlex')
local MOD = WUI:NewModule('WishFlex_Dskin', 'AceEvent-3.0')

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.dskin = true

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.misc = WUI.OptionsArgs.misc or { order = 40, type = "group", name = "|cff00b3cc杂项|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.misc.args.general = WUI.OptionsArgs.misc.args.general or { order = 1, type = "group", name = "基础美化", args = {} }
    WUI.OptionsArgs.misc.args.general.args.dskin = { order = 4, type = "toggle", name = "Details伤害面板美化", get = function() return E.db.WishFlex.modules.dskin end, set = function(_, v) E.db.WishFlex.modules.dskin = v; E:StaticPopup_Show("CONFIG_RL") end }
end

local _G = _G
local hooksecurefunc = hooksecurefunc
local WishFlex_TEXTURE = [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\WishFlex-g1.tga]]

local function ShouldShowWindows()
    local inCombat = InCombatLockdown()
    local db = E.db.WishFlex.smarthide 
    
    local hasTarget = false
    if UnitExists("target") then
        if db and db.filters and db.filters.friendly then
            hasTarget = UnitCanAttack("player", "target") or UnitIsPlayer("target")
        else
            hasTarget = true
        end
    end
    
    local isCasting = UnitCastingInfo("player") or UnitChannelInfo("player")
    return (inCombat or hasTarget)
end

local function FadeItemIn(item)
    if item then E:UIFrameFadeIn(item, 0.2, item:GetAlpha(), 1) end
end

local function FadeItemOut(item)
    if item and item:GetAlpha() > 0 then E:UIFrameFadeOut(item, 0.5, item:GetAlpha(), 0) end
end

local function Window_OnEnter(self)
    if self:GetAlpha() > 0.5 then
        FadeItemIn(self.Header)
        FadeItemIn(self.DamageMeterTypeDropdown)
        FadeItemIn(self.SessionDropdown)
        FadeItemIn(self.SettingsDropdown)
    end
end

local function HandleStatusBar(bar)
    if not bar then return end
    if bar.SetStatusBarTexture then bar:SetStatusBarTexture(WishFlex_TEXTURE) end
    if bar.Background then bar.Background:SetVertexColor(0, 0, 0, 0.3) end
    bar.IsWishSkinned = true
end

local function HandleWindow(window)
    if not window or window.IsWishSkinned then return end
    if window.Background then window.Background:Hide() end
    window:CreateBackdrop('Transparent')
    if window.backdrop then 
        window.backdrop:SetAlpha(0) 
        hooksecurefunc(window.backdrop, "SetAlpha", function(self, alpha) if alpha > 0 then self:SetAlpha(0) end end)
    end

    if window.Header then window.Header:SetAlpha(0) end
    if window.DamageMeterTypeDropdown then window.DamageMeterTypeDropdown:SetAlpha(0) end
    if window.SessionDropdown then window.SessionDropdown:SetAlpha(0) end
    if window.SettingsDropdown then window.SettingsDropdown:SetAlpha(0) end

    window:HookScript('OnEnter', Window_OnEnter)

    local ScrollBox = window.GetScrollBox and window:GetScrollBox()
    if ScrollBox then
        if ScrollBox.ForEachFrame then ScrollBox:ForEachFrame(function(frame) if frame.StatusBar then HandleStatusBar(frame.StatusBar) end end) end
        hooksecurefunc(ScrollBox, 'Update', function(sb) if sb.ForEachFrame then sb:ForEachFrame(function(frame) if frame.StatusBar then HandleStatusBar(frame.StatusBar) end end) end end)
    end
    window.IsWishSkinned = true
end

local function UpdateDskin()
    if not _G.DamageMeter then return end
    local DM = _G.DamageMeter
    local shouldShow = ShouldShowWindows()
    local targetAlpha = shouldShow and 1 or 0
    
    DM:ForEachSessionWindow(function(window)
        if not window then return end
        if not window.IsWishSkinned then HandleWindow(window) end
        
        if window:GetAlpha() ~= targetAlpha then
            if targetAlpha == 0 then E:UIFrameFadeOut(window, 0.5, window:GetAlpha(), 0) else E:UIFrameFadeIn(window, 0.2, window:GetAlpha(), 1) end
        end
        
        if window.IsWishSkinned then
            if not window:IsMouseOver() then
                FadeItemOut(window.Header)
                FadeItemOut(window.DamageMeterTypeDropdown)
                FadeItemOut(window.SessionDropdown)
                FadeItemOut(window.SettingsDropdown)
            end
        end

        local ScrollBox = window.GetScrollBox and window:GetScrollBox()
        if ScrollBox and ScrollBox.ForEachFrame then
            ScrollBox:ForEachFrame(function(frame)
                if frame.StatusBar and frame.StatusBar:GetStatusBarTexture():GetTexture() ~= WishFlex_TEXTURE then HandleStatusBar(frame.StatusBar) end
            end)
        end
    end)
end

function MOD:OnEnable()
    InjectOptions()
    if not E.db.WishFlex.modules.dskin then return end
    E:Delay(1.5, function()
        if not _G.DamageMeter then return end
        local f = CreateFrame("Frame")
        local lastUpdate = 0
        f:SetScript("OnUpdate", function(self, elapsed)
            lastUpdate = lastUpdate + elapsed
            if lastUpdate > 0.1 then UpdateDskin(); lastUpdate = 0 end
        end)
    end)
end