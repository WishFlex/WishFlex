local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WF = E:GetModule('WishFlex')
local SH = WF:NewModule('SmartHide', 'AceEvent-3.0', 'AceTimer-3.0', 'AceHook-3.0')
local UF = E:GetModule('UnitFrames')

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.smarthide = true
P["WishFlex"].smarthide = {
    enable = true, forceShow = false,
    filters = { unitframe = true, buffs = true, cooldowns = true, actionbar = true, minimap = true, friendly = false, actionTimer = true, classResource = true },
}

local function InjectOptions()
    WF.OptionsArgs = WF.OptionsArgs or {}
    WF.OptionsArgs.smarthide = WF.OptionsArgs.smarthide or { order = 10, type = "group", name = "|cff00ffcc智能隐藏|r", childGroups = "tab", args = {} }
    
    local args = WF.OptionsArgs.smarthide.args
    args.general = {
        order = 1, type = "group", name = "基础设置",
        args = {
            enable = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.modules.smarthide end, set = function(_, v) E.db.WishFlex.modules.smarthide = v; E:StaticPopup_Show("CONFIG_RL") end },
            force = { order = 2, type = "toggle", name = "强制显示全部", get = function() return E.db.WishFlex.smarthide.forceShow end, set = function(_, v) E.db.WishFlex.smarthide.forceShow = v; SH:UpdateVisibility() end }
        }
    }
    args.filters = {
        order = 2, type = "group", name = "隐藏模块 (脱战无目标时隐藏)",
        args = {
            group = {
                order = 1, type = "group", name = "应用范围", guiInline = true,
                get = function(i) return E.db.WishFlex.smarthide.filters[i[#i]] end,
                set = function(i, v) E.db.WishFlex.smarthide.filters[i[#i]] = v; SH:UpdateVisibility() end,
                args = {
                    unitframe = {order=1, type="toggle", name="玩家框体"}, 
                    buffs = {order=2, type="toggle", name="增益减益"}, 
                    cooldowns = {order=3, type="toggle", name="冷却管理器(含防守条)"}, 
                    actionTimer = {order=4, type="toggle", name="动作计时"}, 
                    minimap = {order=5, type="toggle", name="小地图"},
                    classResource = {order=6, type="toggle", name="职业资源与能量条"},
                    friendly = {order=7, type="toggle", name="友方NPC时隐藏", desc = "即使有目标，如果目标是友方NPC，依然保持隐藏状态。"},
                }
            }
        }
    }
end

local BuffHost = CreateFrame("Frame", "WishBuffHost", UIParent)
local DebuffHost = CreateFrame("Frame", "WishDebuffHost", UIParent)
local Bar10Host = CreateFrame("Frame", "WishBar10Host", UIParent)
local BarPetHost = CreateFrame("Frame", "WishBarPetHost", UIParent)
BuffHost:Show(); DebuffHost:Show(); Bar10Host:Show(); BarPetHost:Show()

local HiddenFrame = CreateFrame("Frame")
HiddenFrame:Hide()

local FRAME_CATEGORIES = {
    ["ElvUF_Player.Health"] = { cat = "unitframe", isPlayerOnly = true },
    ["ElvUF_Player.Portrait"] = { cat = "unitframe", isPlayerOnly = true },
    ["ElvUF_Player.InfoPanel"] = { cat = "unitframe", isPlayerOnly = true },
    ["ElvUF_Player.backdrop"] = { cat = "unitframe", isPlayerOnly = true },
    ["ElvUF_Target"] = { cat = "unitframe", isPlayerOnly = false },
    ["EssentialCooldownViewer"] = { cat = "cooldowns", isPlayerOnly = false },
    ["UtilityCooldownViewer"] = { cat = "cooldowns", isPlayerOnly = false },
    
    -- 已移除 BuffIconCooldownViewer 的拦截，移交给 CooldownCustom.lua 处理
    -- ["BuffIconCooldownViewer"] = { cat = "cooldowns", isPlayerOnly = false }, 
    
    ["WishFlex_CooldownRow2_Anchor"] = { cat = "cooldowns", isPlayerOnly = false },
    ["WishFlex_DefensiveViewer"] = { cat = "cooldowns", isPlayerOnly = false },
    ["WishFlex_ResurrectIcon"] = { cat = "cooldowns", isPlayerOnly = false, isResIcon = true },
    ["WishFlex_ActionTimer_Anchor"] = { cat = "actionTimer", isPlayerOnly = false },
    ["WishFlex_ClassBar"] = { cat = "classResource", isPlayerOnly = false },
    ["WishFlex_PowerBar"] = { cat = "classResource", isPlayerOnly = false },
    ["WishFlex_TertiaryBar"] = { cat = "classResource", isPlayerOnly = false },
    ["WishFlex_ManaBar"] = { cat = "classResource", isPlayerOnly = false },
    ["ElvUIPlayerBuffs"] = { cat = "buffs", isSpecialHost = "BuffHost" },
    ["ElvUIPlayerDebuffs"] = { cat = "buffs", isSpecialHost = "DebuffHost" },
    ["ElvUI_Bar10"] = { cat = "actionbar", isSpecialHost = "Bar10Host" },
    ["ElvUI_BarPet"] = { cat = "actionbar", isSpecialHost = "BarPetHost" }
}

local FrameCache = {}
local function GetCachedFrame(name)
    if FrameCache[name] then return FrameCache[name] end
    
    local f = _G[name]
    if not f and name:find("%.") then
        local parts = {strsplit(".", name)}
        f = _G[parts[1]]
        if f then 
            for i = 2, #parts do 
                f = f[parts[i]] 
                if not f then break end
            end 
        end
    end
    
    if f then FrameCache[name] = f end
    return f
end

local function SetFrameAlphaImmediate(frame, targetAlpha)
    if not frame then return end
    if frame.isForceHidden then
        if frame:IsShown() then frame:Hide() end
        if frame:GetAlpha() ~= 0 then frame:SetAlpha(0) end
        return
    end

    UIFrameFadeRemoveFrame(frame) 
    if frame:GetAlpha() ~= targetAlpha then frame:SetAlpha(targetAlpha) end
    
    local name = frame:GetName() or ""
    if name:find("ElvUF_") then return end
    if InCombatLockdown() then return end

    if targetAlpha == 0 then 
        if frame:IsShown() then frame:Hide() end 
    else 
        if not frame:IsShown() then frame:Show() end 
    end
end

local function IsInValidResEnvironment()
    local _, instanceType = GetInstanceInfo()
    return (instanceType == "party" or instanceType == "raid" or UnitExists("boss1"))
end

local function IsPlayerFlying() return type(IsFlying) == "function" and IsFlying() end

-- 替换后的核心小地图隐藏逻辑
function SH:UpdateMinimap(show)
    local inCombat = InCombatLockdown()
    local targetAlpha = show and 1 or 0
    
    -- 核心修复：连带小地图相关的所有底层面板、按钮框体、原生框架一网打尽
    local frames = {
        _G.MinimapCluster,
        _G.Minimap,
        _G.MinimapBackdrop,
        _G.MinimapPanel,
        _G.MMHolder,
    }
    
    for _, f in ipairs(frames) do
        if f then
            UIFrameFadeRemoveFrame(f)
            if f:GetAlpha() ~= targetAlpha then f:SetAlpha(targetAlpha) end
            
            if not inCombat then
                -- 脱战时：直接使用强力的 Hide 砍掉父层渲染，完美隐去所有刁钻插件按钮
                if targetAlpha == 0 then
                    if f:IsShown() then f:Hide() end
                else
                    if not f:IsShown() then f:Show() end
                end
            else
                -- 战斗时：无法随意 Hide 被保护的小地图，如果是透明状态就禁用鼠标防止点到空气
                if f.EnableMouse then f:EnableMouse(targetAlpha == 1) end
            end
        end
    end
end

function SH:UpdateVisibility()
    local db = E.db.WishFlex.smarthide
    if not db or not db.enable then return end

    local inCombat = InCombatLockdown()
    local hasTarget = false
    
    if UnitExists("target") then
        if db.filters.friendly then hasTarget = UnitCanAttack("player", "target") or UnitIsPlayer("target") 
        else hasTarget = true end
    end
    
    local isFlying = IsPlayerFlying() 
    local inPetBattle = C_PetBattles and C_PetBattles.IsInBattle()
    local inVehicle = UnitInVehicle("player") or UnitHasVehicleUI("player")

    local shouldShowMinimap = (inCombat or hasTarget or isFlying) and not inPetBattle
    local shouldShowPlayerOnly = (inCombat or hasTarget) and not inPetBattle
    local shouldShowOthers = (inCombat or hasTarget) and not inPetBattle
    if inVehicle then shouldShowOthers = false end

    if db.forceShow then shouldShowMinimap = true; shouldShowPlayerOnly = true; shouldShowOthers = true end

    -- 【修复核心】：避开 Lua 逻辑陷阱，确保隐藏选项真实生效
    local finalMinimapShow = true
    if db.filters.minimap then 
        finalMinimapShow = shouldShowMinimap 
    end
    self:UpdateMinimap(finalMinimapShow)

    for name, info in pairs(FRAME_CATEGORIES) do
        local f = GetCachedFrame(name)
        if f then
            local targetAlpha
            if info.isPlayerOnly then
                targetAlpha = shouldShowPlayerOnly and 1 or 0
            else
                targetAlpha = shouldShowOthers and 1 or 0
            end

            local isControlled = db.filters[info.cat]
            if not isControlled then targetAlpha = 1 end

            if info.isResIcon and not (inCombat or (hasTarget and IsInValidResEnvironment())) then targetAlpha = 0 end

            if info.isSpecialHost == "BuffHost" then
                if f:GetParent() ~= BuffHost then f:SetParent(BuffHost) end; BuffHost:SetAlpha(targetAlpha)
            elseif info.isSpecialHost == "DebuffHost" then
                if f:GetParent() ~= DebuffHost then f:SetParent(DebuffHost) end; DebuffHost:SetAlpha(targetAlpha)
            elseif info.isSpecialHost == "Bar10Host" then
                if f:GetParent() ~= Bar10Host then f:SetParent(Bar10Host) end; Bar10Host:SetAlpha(targetAlpha)
            elseif info.isSpecialHost == "BarPetHost" then
                if f:GetParent() ~= BarPetHost then f:SetParent(BarPetHost) end; BarPetHost:SetAlpha((targetAlpha == 1 and UnitExists("pet")) and 1 or 0)
            else
                SetFrameAlphaImmediate(f, targetAlpha)
            end
        end
    end

    local playerFrame = _G["ElvUF_Player"]
    if playerFrame and playerFrame.customTexts then
        local textAlpha = 1
        if db.filters.unitframe and not shouldShowPlayerOnly then
            textAlpha = 0
        end
        if db.forceShow then textAlpha = 1 end
        
        for _, textFrame in pairs(playerFrame.customTexts) do 
            if textFrame then SetFrameAlphaImmediate(textFrame, textAlpha) end 
        end
    end
end

function SH:OnEnable()
    InjectOptions()
    if not E.db.WishFlex.modules.smarthide then return end
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateVisibility")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "UpdateVisibility")
    
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() 
        self:UpdateVisibility() 
        C_Timer.After(5, function() collectgarbage("collect") end)
    end)
    
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "UpdateVisibility")
    self:RegisterEvent("UNIT_PET", "UpdateVisibility") 
    self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR", "UpdateVisibility")
    self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR", "UpdateVisibility")
    self:RegisterEvent("UNIT_ENTERED_VEHICLE", "UpdateVisibility")
    self:RegisterEvent("UNIT_EXITED_VEHICLE", "UpdateVisibility")
    
    self:UpdateVisibility()
    
    E:Delay(2, function()
        if UF and UF.PostUpdateVisibility then self:SecureHook(UF, "PostUpdateVisibility", "UpdateVisibility") end
        local centers = {"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "WishFlex_ActionTimer_Anchor", "WishFlex_CooldownRow2_Anchor", "WishFlex_DefensiveViewer"}
        for _, n in ipairs(centers) do
            local f = _G[n]
            if f then
                f:HookScript("OnDragStart", function(s) s.isMoving = true end)
                f:HookScript("OnDragStop", function(s) s.isMoving = false end)
            end
        end
    end)
    
    local tickerFrame = CreateFrame("Frame")
    local tickElapsed = 0
    tickerFrame:SetScript("OnUpdate", function(_, delta)
        tickElapsed = tickElapsed + delta
        local interval = InCombatLockdown() and 0.5 or 1.0
        if tickElapsed >= interval then
            tickElapsed = 0
            SH:UpdateVisibility()
        end
    end)
end

SLASH_CMC_CVS1 = "/cds"; SlashCmdList["CMC_CVS"] = function()
    if not InCombatLockdown() and CooldownViewerSettings then CooldownViewerSettings:ShowUIPanel(false) end
end
SLASH_QUICKEDITMODE1 = "/em"; SlashCmdList["QUICKEDITMODE"] = function()
    if InCombatLockdown() then return end
    if EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) else ShowUIPanel(EditModeManagerFrame) end
end