local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local AddonName, addonTable = ...

-- 注册 Media 资源 (路径已更新为 WishFlex)
local LSM = E.Libs.LSM
if LSM then
    LSM:Register("statusbar", "WishMouseover", [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\WishMouseover.tga]])
    LSM:Register("statusbar", "WishTarget", [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\WishTarget.tga]])
    LSM:Register("statusbar", "WishFlex-g1", [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\WishUI-g1.tga]])
    LSM:Register("statusbar", "WishFlex-clean", [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\WishUI-clean.tga]])
    LSM:Register("statusbar", "WishFlex-grad", [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\WishUI-grad.tga]])
    LSM:Register("statusbar", "WishFlex-g2", [[Interface\AddOns\ElvUI_WishFlex\Media\Textures\WishUI-g2.tga]])
end

-- 核心模块名称变更为 WishFlex，使用缩写 WF
local WF = E:NewModule('WishFlex', 'AceEvent-3.0', 'AceHook-3.0')
WF.Title = "|cff00ffccWishFlex|r"

function WF:Initialize()
    self.db = E.db.WishFlex
    
    -- 模块映射表
    local moduleMapping = {
        ["chatSetup"] = "WishFlex_ChatSetup",  
        ["keybinder"] = "WishFlex_KeyBinder",
        ["actionTimer"] = "ActionTimer", 
        ["worldMarker"] = "WorldMarker", 
        ["combatAlert"] = "CombatAlert",
        ["cooldownCustom"] = "CooldownCustom", 
        ["spellAlpha"] = "WishFlex_SpellAlpha", 
        ["teleport"] = "WishFlex_Teleport",    
        ["lustMonitor"] = "LustMonitor", 
        ["rareAlert"]   = "RareAlert", 
        ["smarthide"] = "SmartHide",
        ["cooldownTracker"] = "CooldownTracker",
        ["vehiclebar"] = "VehicleBar",
        ["glow"] = "Glow",
        ["wishtargetAlert"] = "WishTargetAlert",
        ["macroui"] = "macroui",
        ["RightClick"] = "RightClick",
        ["dialogueSkin"] = "WishFlex_DialogueSkin",
        ["dskin"] = "WishFlex_Dskin",
        ["silvermoon"] = "WishFlex_Silvermoon",
        ["stripeSkin"] = "WishFlex_StripeSkin",
        -- [新增] 职业资源进度条模块
        ["classResource"] = "ClassResource" 
    }

    for configKey, moduleName in pairs(moduleMapping) do
        local mod = WF:GetModule(moduleName, true)
        if mod and type(mod.Initialize) == "function" then
            mod:Initialize()
        end
    end
end

function WF:OnEnable()
    -- 预留位
end

E:RegisterModule(WF:GetName())