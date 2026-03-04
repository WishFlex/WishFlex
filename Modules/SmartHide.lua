local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WF = E:GetModule('WishFlex')
local SH = WF:NewModule('SmartHide', 'AceEvent-3.0', 'AceTimer-3.0', 'AceHook-3.0')
local UF = E:GetModule('UnitFrames')

-- ==========================================
-- 1. 默认数据库
-- ==========================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.smarthide = true
P["WishFlex"].smarthide = {
    enable = true, forceShow = false,
    filters = { unitframe = true, buffs = true, cooldowns = true, actionbar = true, minimap = true, friendly = false, actionTimer = true, classResource = true },
}

-- ==========================================
-- 2. 设置面板注入
-- ==========================================
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
                    cooldowns = {order=3, type="toggle", name="冷却管理器(含防守条)"}, -- 提示文本稍微更新一下
                    actionTimer = {order=4, type="toggle", name="动作计时"}, 
                    minimap = {order=5, type="toggle", name="小地图"},
                    classResource = {order=6, type="toggle", name="职业资源与能量条"},
                    friendly = {order=7, type="toggle", name="友方NPC时隐藏", desc = "即使有目标，如果目标是友方NPC，依然保持隐藏状态。"},
                }
            }
        }
    }
end

-- ==========================================
-- 3. 核心隐藏逻辑
-- ==========================================
local BuffHost = CreateFrame("Frame", "WishBuffHost", UIParent)
local DebuffHost = CreateFrame("Frame", "WishDebuffHost", UIParent)
local Bar10Host = CreateFrame("Frame", "WishBar10Host", UIParent)
local BarPetHost = CreateFrame("Frame", "WishBarPetHost", UIParent)
BuffHost:Show(); DebuffHost:Show(); Bar10Host:Show(); BarPetHost:Show()

local HiddenFrame = CreateFrame("Frame")
HiddenFrame:Hide()

local TARGET_FRAMES = {
    "ElvUF_Player.Health", "ElvUF_Player.Portrait", "ElvUF_Player.InfoPanel", "ElvUF_Player.backdrop",
    "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", 
    "ElvUIPlayerBuffs", "ElvUIPlayerDebuffs", "ElvUI_Bar10", "ElvUI_BarPet", "WishFlex_ResurrectIcon",
    "ElvUF_Target", "WishFlex_CooldownRow2_Anchor", "WishFlex_ActionTimer_Anchor",
    "WishFlex_ClassBar", "WishFlex_PowerBar", "WishFlex_TertiaryBar", "WishFlex_ManaBar",
    "WishFlex_DefensiveViewer" -- 注入防守条锚点
}

local function SetFrameAlphaImmediate(frame, targetAlpha)
    if not frame then return end
    
    if frame.isForceHidden then
        if frame:IsShown() then frame:Hide() end
        frame:SetAlpha(0)
        return
    end

    UIFrameFadeRemoveFrame(frame) 
    frame:SetAlpha(targetAlpha)
    
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

function SH:UpdateMinimap(show)
    local cluster = _G.MinimapCluster
    if not cluster then return end
    local inCombat = InCombatLockdown()
    if show or inCombat then
        if cluster:GetParent() ~= UIParent then cluster:SetParent(UIParent) end
        cluster:SetAlpha(1)
    elseif not inCombat then
        if cluster:GetParent() ~= HiddenFrame then cluster:SetParent(HiddenFrame) end
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
    
    -- 【世纪 BUG 修复】：暴雪底层对武僧的 OverrideActionBar 有毒判断！
    -- 彻底移除 HasOverrideActionBar()，改用极度严谨的 UnitHasVehicleUI！
    local inVehicle = UnitInVehicle("player") or UnitHasVehicleUI("player")

    local shouldShowMinimap = (inCombat or hasTarget or isFlying) and not inPetBattle
    local shouldShowPlayerOnly = (inCombat or hasTarget) and not inPetBattle
    local shouldShowOthers = (inCombat or hasTarget) and not inPetBattle
    if inVehicle then shouldShowOthers = false end

    if db.forceShow then shouldShowMinimap = true; shouldShowPlayerOnly = true; shouldShowOthers = true end

    if db.filters.minimap then self:UpdateMinimap(shouldShowMinimap) else self:UpdateMinimap(true) end

    for _, name in ipairs(TARGET_FRAMES) do
        local f = _G[name]
        if not f and name:find("%.") then
            local parts = {strsplit(".", name)}
            f = _G[parts[1]]
            if f then for i = 2, #parts do if f then f = f[parts[i]] end end end
        end

        if f then
            local targetAlpha = shouldShowOthers and 1 or 0
            if (name == "ElvUF_Player.Health" or name == "ElvUF_Player.Portrait" or name == "ElvUF_Player.backdrop" or name == "ElvUF_Player.InfoPanel") then
                targetAlpha = shouldShowPlayerOnly and 1 or 0
            end
            
            local isControlled = true
            if (name:find("Health") or name:find("Portrait") or name:find("backdrop") or name:find("InfoPanel") or name == "ElvUF_Target") then
                isControlled = db.filters.unitframe
            elseif (name:find("Buffs") or name:find("Debuffs")) then
                isControlled = db.filters.buffs
            -- 注入防守条归类判断
            elseif (name:find("CooldownViewer") or name == "WishFlex_ResurrectIcon" or name == "WishFlex_CooldownRow2_Anchor" or name == "WishFlex_DefensiveViewer") then
                isControlled = db.filters.cooldowns
            elseif name == "WishFlex_ActionTimer_Anchor" then
                isControlled = db.filters.actionTimer
            elseif (name == "ElvUI_Bar10" or name == "ElvUI_BarPet") then
                isControlled = db.filters.actionbar
            elseif (name == "WishFlex_ClassBar" or name == "WishFlex_PowerBar" or name == "WishFlex_TertiaryBar" or name == "WishFlex_ManaBar") then
                isControlled = db.filters.classResource
            end

            if not isControlled then targetAlpha = 1 end
            if name == "WishFlex_ResurrectIcon" and not (inCombat or (hasTarget and IsInValidResEnvironment())) then targetAlpha = 0 end

            if name == "ElvUIPlayerBuffs" then
                if f:GetParent() ~= BuffHost then f:SetParent(BuffHost) end; BuffHost:SetAlpha(targetAlpha)
            elseif name == "ElvUIPlayerDebuffs" then
                if f:GetParent() ~= DebuffHost then f:SetParent(DebuffHost) end; DebuffHost:SetAlpha(targetAlpha)
            elseif name == "ElvUI_Bar10" then
                if f:GetParent() ~= Bar10Host then f:SetParent(Bar10Host) end; Bar10Host:SetAlpha(targetAlpha)
            elseif name == "ElvUI_BarPet" then
                if f:GetParent() ~= BarPetHost then f:SetParent(BarPetHost) end; local finalPetAlpha = (targetAlpha == 1 and UnitExists("pet")) and 1 or 0; BarPetHost:SetAlpha(finalPetAlpha)
            else
                SetFrameAlphaImmediate(f, targetAlpha)
            end
        end
    end

    local playerFrame = _G["ElvUF_Player"]
    if playerFrame and playerFrame.customTexts then
        local textAlpha = (shouldShowPlayerOnly and db.filters.unitframe) and 1 or 0
        if db.forceShow then textAlpha = 1 end
        for _, textFrame in pairs(playerFrame.customTexts) do 
            if textFrame then SetFrameAlphaImmediate(textFrame, textAlpha) end 
        end
    end
end

-- ==========================================
-- 4. 事件注册
-- ==========================================
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
        -- 加入 WishFlex_DefensiveViewer 防止移动时闪烁
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
        local interval = InCombatLockdown() and 0.1 or 0.5
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