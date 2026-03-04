local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')
local WUI = E:GetModule('WishFlex')
local MOD = WUI:NewModule('WishFlex_StripeSkin', 'AceEvent-3.0')

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.stripeSkin = true

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.misc = WUI.OptionsArgs.misc or { order = 40, type = "group", name = "|cff00b3cc杂项|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.misc.args.general = WUI.OptionsArgs.misc.args.general or { order = 1, type = "group", name = "基础美化", args = {} }
    WUI.OptionsArgs.misc.args.general.args.stripeSkin = { order = 5, type = "toggle", name = "全局斜纹背景纹理", get = function() return E.db.WishFlex.modules.stripeSkin end, set = function(_, v) E.db.WishFlex.modules.stripeSkin = v; E:StaticPopup_Show("CONFIG_RL") end }
end

local STRIPE_TEX = [[Interface\AddOns\ElvUI_WishFlex\Media\stripes.blp]]

local function ApplyWishStyle(f)
    if not f or type(f) ~= "table" or f:IsForbidden() then return end
    local name = f:GetName()
    if name and (name:find("DamageMeter") or name:find("SharedScrollBox")) then return end
    if f:GetParent() then
        local pName = f:GetParent():GetName()
        if pName and pName:find("DamageMeter") then return end
    end
    local target = f.backdrop or f
    if not target or not target.CreateTexture or target.WishStripe then return end
    
    local stripe = target:CreateTexture(nil, "OVERLAY", nil, 7)
    stripe:SetAllPoints(target)
    stripe:SetTexture(STRIPE_TEX, "REPEAT", "REPEAT")
    stripe:SetHorizTile(true); stripe:SetVertTile(true)
    stripe:SetAlpha(1); stripe:SetBlendMode("ADD") 
    stripe:SetVertexColor(1, 1, 1, 1)
    stripe:SetTexCoord(0, 6, 0, 6) 
    target.WishStripe = stripe
end

local function HeartbeatScan()
    if not E.db.WishFlex.modules.stripeSkin then return end
    if LeftChatPanel then ApplyWishStyle(LeftChatPanel) end
    if RightChatPanel then ApplyWishStyle(RightChatPanel) end

    local windows = { _G["ElvConfigFrame"], _G["WorldMapFrame"], _G["CharacterFrame"], _G["PVEFrame"], _G["SpellBookFrame"], _G["MacroFrame"], _G["ElvUI_CopyChatFrame"], _G["UIMurlokExport"] }
    for _, win in pairs(windows) do
        if win and win:IsVisible() then
            ApplyWishStyle(win)
            if win.backdrop then ApplyWishStyle(win.backdrop) end
            local children = {win:GetChildren()}
            for _, child in ipairs(children) do if child.backdrop then ApplyWishStyle(child) end end
        end
    end
    
    if C_AddOns.IsAddOnLoaded("Baganator") then
        local children = {UIParent:GetChildren()}
        for _, child in ipairs(children) do
            if not child:IsForbidden() then
                local name = child:GetName()
                if name and name:find("Baganator") then ApplyWishStyle(child) end
            end
        end
    end
end

function MOD:OnEnable()
    InjectOptions()
    if not E.db.WishFlex.modules.stripeSkin then return end
    local mt = getmetatable(CreateFrame("Frame")).__index
    if mt.SetTemplate then
        hooksecurefunc(mt, "SetTemplate", function(f) C_Timer.After(0.05, function() ApplyWishStyle(f) end) end)
    end
    
    local skinFunctions = {"HandleFrame", "HandleButton", "HandlePanel", "HandleScrollBar"}
    for _, func in pairs(skinFunctions) do
        if S[func] then hooksecurefunc(S, func, function(_, frame) if frame then ApplyWishStyle(frame) end end) end
    end

    C_Timer.NewTicker(1, HeartbeatScan)
end