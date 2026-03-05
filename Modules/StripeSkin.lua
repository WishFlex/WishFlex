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

-- 【性能优化】：通过 Lua 栈迭代解决 {win:GetChildren()} 带来的疯狂建表内存泄漏
local function SafeSkinChildren(...)
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if child and child.backdrop then ApplyWishStyle(child) end
    end
end

local function HeartbeatScan()
    if not E.db.WishFlex.modules.stripeSkin then return end
    if LeftChatPanel then ApplyWishStyle(LeftChatPanel) end
    if RightChatPanel then ApplyWishStyle(RightChatPanel) end

    local windows = { _G["ElvConfigFrame"], _G["WorldMapFrame"], _G["CharacterFrame"], _G["PVEFrame"], _G["SpellBookFrame"], _G["MacroFrame"], _G["ElvUI_CopyChatFrame"], _G["UIMurlokExport"] }
    for _, win in ipairs(windows) do
        if win and win:IsVisible() then
            ApplyWishStyle(win)
            if win.backdrop then ApplyWishStyle(win.backdrop) end
            SafeSkinChildren(win:GetChildren()) -- 0 表分配，彻底解决 GC 暴涨
        end
    end
    
    -- 【性能优化】：精准命中 Baganator 常用框体，废除 UIParent 的全局深层扫描
    if C_AddOns.IsAddOnLoaded("Baganator") then
        local bagFrames = { "Baganator_BackpackViewFrame", "Baganator_BankViewFrame", "Baganator_GuildViewFrame" }
        for _, name in ipairs(bagFrames) do
            local win = _G[name]
            if win then ApplyWishStyle(win) end
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

    -- 将心跳扫描频率稍微放宽至 2 秒，因为这是辅助美化，不需要毫秒级反应
    C_Timer.NewTicker(2, HeartbeatScan)
end