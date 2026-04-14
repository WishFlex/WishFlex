local AddonName, ns = ...
local WF = _G.WishFlex

local Fader = CreateFrame("Frame", "WishFlex_SmartFader")
WF.SmartFader = Fader

local GroupToFrame = {
    ["Essential"] = "EssentialCooldownViewer",
    ["Utility"] = "UtilityCooldownViewer",
    ["Defensive"] = "WishFlex_DefensiveCooldownViewer",
    ["BuffIcon"] = "BuffIconCooldownViewer",
    ["BuffBar"] = "BuffBarCooldownViewer",
    ["power"] = "WishFlex_PowerBar",
    ["class"] = "WishFlex_ClassBar",
    ["mana"] = "WishFlex_ManaBar",
    ["vigor"] = "WishFlex_VigorBar",
    ["whirling"] = "WishFlex_WhirlingBar",
    ["ExtraMonitor"] = "WishFlex_ExtraMonitor",
}

local FrameCache = {}
local function GetFrameByCat(cat)
    if FrameCache[cat] then return FrameCache[cat] end
    local f = _G[GroupToFrame[cat]] or _G["WishFlex_" .. cat]
    if f then FrameCache[cat] = f end
    return f
end

-- ==========================================
-- 纯净透明度防篡改 (完美还原逻辑，去除渐变动画)
-- ==========================================
local HookedFrames = {}
local function SecureAlphaHook(frame, alpha)
    if frame.SmartHideTargetAlpha == 0 and alpha ~= 0 then 
        frame:SetAlpha(0) 
    end
end

local function SetFrameAlphaImmediate(frame, targetAlpha)
    if not frame or type(frame) ~= "table" or not frame.SetAlpha then return end
    if frame.SmartHideTargetAlpha == targetAlpha then return end
    
    frame.SmartHideTargetAlpha = targetAlpha

    if not HookedFrames[frame] then
        hooksecurefunc(frame, "SetAlpha", SecureAlphaHook)
        HookedFrames[frame] = true
    end

    -- 停止可能存在的原生渐变
    if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(frame) end
    if frame.wfFadeGroup then frame.wfFadeGroup:Stop() end
    
    -- 瞬间赋值，拒绝闪烁
    frame:SetAlpha(targetAlpha)
end

-- ==========================================
-- 核心可见性判定逻辑
-- ==========================================
local function GetTargetAlpha(db)
    -- 1. 【核心修改】全局最高优先级拦截：载具和宠物对战
    -- 无视用户是否在设置中开启了智能隐藏，只要处于这两种状态，所有被管理的框体强制透明！
    local inPetBattle = C_PetBattles and C_PetBattles.IsInBattle()
    local inVehicle = UnitInVehicle("player") or UnitHasVehicleUI("player")
    if inPetBattle or inVehicle then return 0 end

    -- 2. 如果该模块未开启常规的“脱战隐藏/智能隐藏”功能，则默认显示
    if not db or not db.enable then return 1 end 
    
    -- 3. 细分的智能判定条件
    local inCombat = InCombatLockdown()
    local hasTarget = UnitExists("target")
    local isFlying = type(IsFlying) == "function" and IsFlying()

    if db.dragonriding and isFlying then return 0 end

    if hasTarget and db.friendly then
        hasTarget = UnitCanAttack("player", "target") or UnitIsPlayer("target")
    end

    if db.hideOOC then
        if not inCombat and not hasTarget then return 0 end
    end

    return 1
end

function Fader:UpdateVisibility()
    local inEditMode = WF.MoversUnlocked or (WF.MainFrame and WF.MainFrame:IsShown())
    
    local function ProcessCategory(catDB, catName)
        if not catDB or type(catDB) ~= "table" then return end
        
        if catDB.visibility == nil then catDB.visibility = { enable = false, hideOOC = true, dragonriding = false, friendly = false, vehicle = false } end
        
        local targetAlpha = 1
        if not inEditMode then targetAlpha = GetTargetAlpha(catDB.visibility) end
        
        -- 1. 隐藏原生框体
        local frame = GetFrameByCat(catName)
        if frame then SetFrameAlphaImmediate(frame, targetAlpha) end
        
        -- 2. 如果冷却系统给它生成了同名的代理排版框体，同步拔管隐藏
        local proxyFrame = _G[catName .. "CooldownViewer"]
        if proxyFrame and proxyFrame ~= frame then
            SetFrameAlphaImmediate(proxyFrame, targetAlpha)
        end
    end

    -- 1. 冷却排版组
    local cdDB = WF.db.cooldownCustom
    if cdDB then
        ProcessCategory(cdDB.Essential, "Essential")
        ProcessCategory(cdDB.Utility, "Utility")
        ProcessCategory(cdDB.Defensive, "Defensive")
        ProcessCategory(cdDB.BuffIcon, "BuffIcon")
        ProcessCategory(cdDB.BuffBar, "BuffBar")
        if cdDB.CustomRows then for _, cat in ipairs(cdDB.CustomRows) do ProcessCategory(cdDB[cat], cat) end end
        if cdDB.CustomBuffRows then for _, cat in ipairs(cdDB.CustomBuffRows) do ProcessCategory(cdDB[cat], cat) end end
    end

    -- 2. 职业资源条组
    local crAPI = WF.ClassResourceAPI
    if crAPI then
        local specID = crAPI.GetCurrentContextID()
        local specCfg = crAPI.GetCurrentSpecConfig(specID)
        if specCfg then
            ProcessCategory(specCfg.power, "power")
            ProcessCategory(specCfg.class, "class")
            ProcessCategory(specCfg.mana, "mana")
        end
        local crDB = crAPI.GetDB()
        if crDB then
            ProcessCategory(crDB.vigor, "vigor")
            ProcessCategory(crDB.whirling, "whirling")
        end
    end

    -- 3. 额外监控组 (终极拦截：无视父级断裂，直击图标)
    local emDB = WF.db.extraMonitor
    local emVis = { enable = false, hideOOC = true, dragonriding = false, friendly = false, vehicle = false }
    
    if cdDB and cdDB.ExtraMonitor and cdDB.ExtraMonitor.visibility and cdDB.ExtraMonitor.visibility.enable then
        for k, v in pairs(cdDB.ExtraMonitor.visibility) do emVis[k] = v end
    elseif emDB and emDB.visibility and emDB.visibility.enable then
        for k, v in pairs(emDB.visibility) do emVis[k] = v end
    end
    
    local targetAlpha = 1
    if not inEditMode then targetAlpha = GetTargetAlpha(emVis) end
    
    local frames = { "WishFlex_ExtraMonitor", "ExtraMonitorCooldownViewer", "WishFlex_ExtraMonitorCooldownViewer" }
    for _, name in ipairs(frames) do
        if _G[name] then SetFrameAlphaImmediate(_G[name], targetAlpha) end
    end
    
    -- 强行接管监控池里的具体图标
    local emFrames = (WF.ExtraMonitorAPI and WF.ExtraMonitorAPI.FramePool) or (WF.ExtraMonitorAPI and WF.ExtraMonitorAPI.pool) or {}
    for _, btn in pairs(emFrames) do
        if not btn.isCrossGrouped then
            SetFrameAlphaImmediate(btn, targetAlpha)
        end
    end

    -- 4. 自定义监控条组 (WishMonitor)
    local wmDB = WF.db.wishMonitor
    if wmDB and crAPI and crAPI.ActiveMonitorFrames then
        for _, f in ipairs(crAPI.ActiveMonitorFrames) do
            local spellIDStr = f.spellIDStr or tostring(f.spellID)
            local cfg = (wmDB.skills and wmDB.skills[spellIDStr]) or (wmDB.buffs and wmDB.buffs[spellIDStr])
            if cfg then
                if cfg.visibility == nil then cfg.visibility = { enable = false, hideOOC = true, dragonriding = false, friendly = false, vehicle = false } end
                local targetAlpha = 1
                if not inEditMode then targetAlpha = GetTargetAlpha(cfg.visibility) end
                SetFrameAlphaImmediate(f, targetAlpha)
            end
        end
    end
end

-- ==========================================
-- 引入原版事件监听机制
-- ==========================================
Fader:RegisterEvent("PLAYER_TARGET_CHANGED")
Fader:RegisterEvent("PLAYER_REGEN_DISABLED")
Fader:RegisterEvent("PLAYER_REGEN_ENABLED")
Fader:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
Fader:RegisterEvent("UNIT_PET")

-- 载具事件
Fader:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
Fader:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
Fader:RegisterEvent("UNIT_ENTERED_VEHICLE")
Fader:RegisterEvent("UNIT_EXITED_VEHICLE")

-- 【新增】宠物对战进出事件
Fader:RegisterEvent("PET_BATTLE_OPENING_START")
Fader:RegisterEvent("PET_BATTLE_CLOSE")

Fader:SetScript("OnEvent", function(self, event, ...)
    self:UpdateVisibility()
end)

local tickElapsed = 0
Fader:SetScript("OnUpdate", function(_, delta)
    tickElapsed = tickElapsed + delta
    if tickElapsed >= 1.0 then
        tickElapsed = 0
        Fader:UpdateVisibility()
    end
end)

C_Timer.After(2, function()
    if WF.ClassResourceAPI and WF.ClassResourceAPI.RenderMonitors then
        hooksecurefunc(WF.ClassResourceAPI, "RenderMonitors", function()
            Fader:UpdateVisibility()
        end)
    end
end)