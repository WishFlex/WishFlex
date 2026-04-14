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

local HookedFrames = {}
local function SecureAlphaHook(frame, alpha)
    if frame.SmartHideTargetAlpha == 0 and alpha ~= 0 then 
        frame:SetAlpha(0) 
    end
end

-- 【极致内存优化】：使用函数调用取代原本的临时 Table 分配
local function UpdateHostAlpha(host, alpha)
    if host then
        if alpha == 0 then
            host:SetAlpha(0)
            host:Hide()
        else
            host:SetAlpha(1)
            host:Show()
        end
    end
end

local function SyncGlowState(f, alpha)
    if type(f) ~= "table" then return end
    UpdateHostAlpha(f.cdmGlowHost, alpha)
    UpdateHostAlpha(f.wfGlowHost, alpha)
    if f.Icon and type(f.Icon) == "table" then
        UpdateHostAlpha(f.Icon.cdmGlowHost, alpha)
        UpdateHostAlpha(f.Icon.wfGlowHost, alpha)
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

    if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(frame) end
    if frame.wfFadeGroup then frame.wfFadeGroup:Stop() end
    
    frame:SetAlpha(targetAlpha)
    SyncGlowState(frame, targetAlpha)
    
    if frame.itemFramePool and type(frame.itemFramePool.EnumerateActive) == "function" then
        for child in frame.itemFramePool:EnumerateActive() do
            SyncGlowState(child, targetAlpha)
        end
    elseif frame.activeBars and type(frame.activeBars) == "table" then
        for _, child in pairs(frame.activeBars) do
            SyncGlowState(child, targetAlpha)
        end
    end
end


local function GetTargetAlpha(db)
    local inPetBattle = C_PetBattles and C_PetBattles.IsInBattle()
    local inVehicle = UnitInVehicle("player") or UnitHasVehicleUI("player")
    if inPetBattle or inVehicle then return 0 end
    if not db or not db.enable then return 1 end 
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

local function ProcessCategory(catDB, catName, inEditMode)
    if not catDB or type(catDB) ~= "table" then return end
    
    if catDB.visibility == nil then 
        catDB.visibility = { enable = false, hideOOC = true, dragonriding = false, friendly = false, vehicle = false } 
    end
    
    local targetAlpha = 1
    if not inEditMode then targetAlpha = GetTargetAlpha(catDB.visibility) end
    local frame = GetFrameByCat(catName)
    if frame then SetFrameAlphaImmediate(frame, targetAlpha) end
    local proxyFrame = _G[catName .. "CooldownViewer"]
    if proxyFrame and proxyFrame ~= frame then
        SetFrameAlphaImmediate(proxyFrame, targetAlpha)
    end
end

local MONITOR_FRAMES = { "WishFlex_ExtraMonitor", "ExtraMonitorCooldownViewer", "WishFlex_ExtraMonitorCooldownViewer" }
local EM_VIS_CACHE = { enable = false, hideOOC = true, dragonriding = false, friendly = false, vehicle = false }
local EMPTY_TABLE = {}

function Fader:UpdateVisibility()
    local inEditMode = WF.MoversUnlocked or (WF.MainFrame and WF.MainFrame:IsShown())
    
    local cdDB = WF.db.cooldownCustom
    if cdDB then
        ProcessCategory(cdDB.Essential, "Essential", inEditMode)
        ProcessCategory(cdDB.Utility, "Utility", inEditMode)
        ProcessCategory(cdDB.Defensive, "Defensive", inEditMode)
        ProcessCategory(cdDB.BuffIcon, "BuffIcon", inEditMode)
        ProcessCategory(cdDB.BuffBar, "BuffBar", inEditMode)
        if cdDB.CustomRows then for _, cat in ipairs(cdDB.CustomRows) do ProcessCategory(cdDB[cat], cat, inEditMode) end end
        if cdDB.CustomBuffRows then for _, cat in ipairs(cdDB.CustomBuffRows) do ProcessCategory(cdDB[cat], cat, inEditMode) end end
    end

    local crAPI = WF.ClassResourceAPI
    if crAPI then
        local specID = crAPI.GetCurrentContextID()
        local specCfg = crAPI.GetCurrentSpecConfig(specID)
        if specCfg then
            ProcessCategory(specCfg.power, "power", inEditMode)
            ProcessCategory(specCfg.class, "class", inEditMode)
            ProcessCategory(specCfg.mana, "mana", inEditMode)
        end
        local crDB = crAPI.GetDB()
        if crDB then
            ProcessCategory(crDB.vigor, "vigor", inEditMode)
            ProcessCategory(crDB.whirling, "whirling", inEditMode)
        end
    end

    local emDB = WF.db.extraMonitor
    EM_VIS_CACHE.enable, EM_VIS_CACHE.hideOOC, EM_VIS_CACHE.dragonriding, EM_VIS_CACHE.friendly, EM_VIS_CACHE.vehicle = false, true, false, false, false
    
    if cdDB and cdDB.ExtraMonitor and cdDB.ExtraMonitor.visibility and cdDB.ExtraMonitor.visibility.enable then
        for k, v in pairs(cdDB.ExtraMonitor.visibility) do EM_VIS_CACHE[k] = v end
    elseif emDB and emDB.visibility and emDB.visibility.enable then
        for k, v in pairs(emDB.visibility) do EM_VIS_CACHE[k] = v end
    end
    
    local targetAlpha = 1
    if not inEditMode then targetAlpha = GetTargetAlpha(EM_VIS_CACHE) end
    
    for _, name in ipairs(MONITOR_FRAMES) do
        if _G[name] then SetFrameAlphaImmediate(_G[name], targetAlpha) end
    end
    
    local emFrames = (WF.ExtraMonitorAPI and WF.ExtraMonitorAPI.FramePool) or (WF.ExtraMonitorAPI and WF.ExtraMonitorAPI.pool) or EMPTY_TABLE
    for _, btn in pairs(emFrames) do
        if type(btn) == "table" and not btn.isCrossGrouped then
            SetFrameAlphaImmediate(btn, targetAlpha)
        end
    end

    local wmDB = WF.db.wishMonitor
    if wmDB and crAPI and crAPI.ActiveMonitorFrames then
        for _, f in ipairs(crAPI.ActiveMonitorFrames) do
            local spellIDStr = f.spellIDStr or tostring(f.spellID)
            local cfg = (wmDB.skills and wmDB.skills[spellIDStr]) or (wmDB.buffs and wmDB.buffs[spellIDStr])
            if cfg then
                if cfg.visibility == nil then cfg.visibility = { enable = false, hideOOC = true, dragonriding = false, friendly = false, vehicle = false } end
                local tAlpha = 1
                if not inEditMode then tAlpha = GetTargetAlpha(cfg.visibility) end
                SetFrameAlphaImmediate(f, tAlpha)
            end
        end
    end
end

Fader:RegisterEvent("PLAYER_REGEN_DISABLED")
Fader:RegisterEvent("PLAYER_REGEN_ENABLED")
Fader:RegisterEvent("PLAYER_TARGET_CHANGED") 
Fader:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
Fader:RegisterEvent("UNIT_PET")

Fader:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
Fader:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
Fader:RegisterEvent("UNIT_ENTERED_VEHICLE")
Fader:RegisterEvent("UNIT_EXITED_VEHICLE")

Fader:RegisterEvent("PET_BATTLE_OPENING_START")
Fader:RegisterEvent("PET_BATTLE_CLOSE")

Fader:SetScript("OnEvent", function(self, event, ...)
    self:UpdateVisibility()
end)

local tickElapsed = 0
Fader:SetScript("OnUpdate", function(_, delta)
    tickElapsed = tickElapsed + delta
    if tickElapsed >= 0.3 then 
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
    
    if WF.GlowAPI and type(WF.GlowAPI.Show) == "function" then
        hooksecurefunc(WF.GlowAPI, "Show", function(self, frame)
            if not frame then return end
            if frame:GetEffectiveAlpha() == 0 or frame.SmartHideTargetAlpha == 0 then
                local host = frame.cdmGlowHost or (frame.Icon and type(frame.Icon) == "table" and frame.Icon.cdmGlowHost)
                if host then
                    host:SetAlpha(0)
                    host:Hide()
                end
            end
        end)
    end
end)