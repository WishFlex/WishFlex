local AddonName, ns = ...
local WF = ns.WF
local L = ns.L

local Tracker = CreateFrame("Frame")
WF.CooldownTrackerAPI = Tracker
local DefaultConfig = {
    enable = true,
    isFirstInit = true, 
    enableDesat = true,
    desatSpells = {}, 
    enableResource = true,
    resourceSpells = {},
}

Tracker.desatSpellSet = {}
Tracker.resourceSpellSet = {}

local Wish_FrameData = setmetatable({}, { __mode = "k" })
local function GetFrameData(frame)
    local data = Wish_FrameData[frame]
    if not data then 
        data = {}
        Wish_FrameData[frame] = data 
    end
    return data
end

local function IsSecret(v)
    return type(v) == "number" and type(issecretvalue) == "function" and issecretvalue(v)
end

local function SafeKillRedBorder(frame)
    local function killTex(tex)
        if tex and not tex._wishKilled then
            tex._wishKilled = true
            hooksecurefunc(tex, "SetAlpha", function(s, a) 
                if a > 0 and not s._wLock then 
                    s._wLock = true; s:SetAlpha(0); s._wLock = false 
                end 
            end)
            hooksecurefunc(tex, "Show", function(s) 
                if not s._wLock then 
                    s._wLock = true; s:Hide(); s._wLock = false 
                end 
            end)
            tex:SetAlpha(0)
            tex:Hide()
        end
    end
    killTex(frame.PandemicIcon)
    killTex(frame.CooldownFlash)
    killTex(frame.OutOfRange)
end

local activeResourceFrames = {}

local function ApplyWishVisuals(frame)
    if not frame or not frame.Icon then return end
    local data = GetFrameData(frame)
    if data.isUpdating then return end 

    SafeKillRedBorder(frame)

    local info = frame.cooldownInfo or (frame.GetCooldownInfo and frame:GetCooldownInfo())
    local spellID = info and (info.overrideSpellID or info.spellID)
    if not spellID then return end

    -- 【免死金牌逻辑】：如果该法术已被隐藏（交由沙盒全权代理），则彻底放弃对原生图标颜色的修改！
    local cdb = WF.db.cooldownCustom
    if cdb and cdb.blacklist then
        if cdb.blacklist[spellID] or cdb.blacklist["CD_"..spellID] or cdb.blacklist["BUFF_"..spellID] or cdb.blacklist[tostring(spellID)] then
            frame._wishForcedDesat = false
            return 
        end
    end

    local db = WF.db.cooldownTracker or {}
    local inDesat = Tracker.desatSpellSet[spellID] and db.enableDesat
    local inRes = Tracker.resourceSpellSet[spellID] and db.enableResource
    
    if inRes then
        activeResourceFrames[frame] = true
    else
        activeResourceFrames[frame] = nil
    end
    
    if not inDesat and not inRes then
        if data.wishModified then
            data.isUpdating = true
            if frame.Cooldown then frame.Cooldown:SetDrawSwipe(true) end
            if frame.Icon.SetDesaturation then frame.Icon:SetDesaturation(0) else frame.Icon:SetDesaturated(false) end
            frame.Icon:SetVertexColor(1, 1, 1)
            data.wishModified = false
            data.isUpdating = false
            frame._wishForcedDesat = false 
        end
        return 
    end

    data.wishModified = true
    local isActive = true
    
    if inDesat then
        local swipe = frame.cooldownSwipeColor
        if swipe and type(swipe) ~= "number" and type(swipe.GetRGBA) == "function" then
            local r = swipe:GetRGBA()
            if r and type(r) == "number" and not IsSecret(r) then 
                isActive = (r ~= 0) 
            end
        end
    end

    if isActive and inRes then
        if C_Spell and C_Spell.IsSpellUsable then
            local _, notEnoughPower = C_Spell.IsSpellUsable(spellID)
            if notEnoughPower then isActive = false end
        end
    end

    data.isUpdating = true 
    if not isActive then
        if frame.Cooldown then frame.Cooldown:SetDrawSwipe(false) end
        frame._wishForcedDesat = true 
        if frame.Icon.SetDesaturation then frame.Icon:SetDesaturation(1) else frame.Icon:SetDesaturated(true) end
        frame.Icon:SetVertexColor(0.6, 0.6, 0.6)
    else
        frame._wishForcedDesat = false
        if frame.Cooldown then frame.Cooldown:SetDrawSwipe(true) end
        if frame.Icon.SetDesaturation then frame.Icon:SetDesaturation(0) else frame.Icon:SetDesaturated(false) end
        frame.Icon:SetVertexColor(1, 1, 1)
    end
    data.isUpdating = false 
end

local function HookFrame(frame)
    local data = GetFrameData(frame)
    if not frame or data.wishHooked then return end
    data.wishHooked = true

    local function triggerUpdate() ApplyWishVisuals(frame) end
    
    if frame.Cooldown then
        hooksecurefunc(frame.Cooldown, "SetCooldown", triggerUpdate)
        hooksecurefunc(frame.Cooldown, "Clear", triggerUpdate)
        if frame.Cooldown.SetSwipeColor then hooksecurefunc(frame.Cooldown, "SetSwipeColor", triggerUpdate) end
    end
    
    if frame.Icon then
        local function EnforceDesat()
            if frame._wishForcedDesat and not data.isUpdating then
                data.isUpdating = true
                if frame.Icon.SetDesaturation then frame.Icon:SetDesaturation(1) else frame.Icon:SetDesaturated(true) end
                frame.Icon:SetVertexColor(0.6, 0.6, 0.6)
                data.isUpdating = false
            end
        end
        
        if frame.Icon.SetDesaturated then hooksecurefunc(frame.Icon, "SetDesaturated", EnforceDesat) end
        if frame.Icon.SetDesaturation then hooksecurefunc(frame.Icon, "SetDesaturation", EnforceDesat) end
        if frame.Icon.SetVertexColor then hooksecurefunc(frame.Icon, "SetVertexColor", EnforceDesat) end
    end
    
    triggerUpdate()
end

function Tracker:UpdateCache()
    local db = WF.db.cooldownTracker or {}
    wipe(Tracker.desatSpellSet)
    wipe(Tracker.resourceSpellSet)
    if db.desatSpells then for id, v in pairs(db.desatSpells) do if v then Tracker.desatSpellSet[tonumber(id)] = true end end end
    if db.resourceSpells then for id, v in pairs(db.resourceSpells) do if v then Tracker.resourceSpellSet[tonumber(id)] = true end end end
end

function Tracker:RefreshAll(skipCacheUpdate)
    if not WF.db.cooldownTracker then return end
    if not WF.db.cooldownTracker.enable then return end
    
    if not skipCacheUpdate then
        Tracker:UpdateCache()
    end
    
    local viewers = { _G.EssentialCooldownViewer, _G.UtilityCooldownViewer }
    for _, viewer in ipairs(viewers) do
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                HookFrame(frame)
                ApplyWishVisuals(frame)
            end
        end
    end
end

local function DoPowerUpdateRefresh()
    for frame, _ in pairs(activeResourceFrames) do
        if frame:IsVisible() then
            ApplyWishVisuals(frame)
        end
    end
end

local function InitCooldownTracker()
    if not WF.db.cooldownTracker then WF.db.cooldownTracker = {} end
    local db = WF.db.cooldownTracker
    for k, v in pairs(DefaultConfig) do
        if db[k] == nil then db[k] = v end
    end

    if db.isFirstInit then
        db.desatSpells["980"] = true      
        db.desatSpells["589"] = true      
        db.resourceSpells["124467"] = true 
        db.isFirstInit = false
    end

    Tracker:UpdateCache()

    if not db.enable then return end

    Tracker:RegisterEvent("PLAYER_TARGET_CHANGED")
    Tracker:RegisterEvent("UNIT_POWER_UPDATE")
    
    local powerUpdater = CreateFrame("Frame")
    local powerNextUpdate = 0
    local powerUpdatePending = false

    powerUpdater:SetScript("OnUpdate", function(self)
        if powerUpdatePending and GetTime() >= powerNextUpdate then
            powerUpdatePending = false
            DoPowerUpdateRefresh()
        end
    end)

    Tracker:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_TARGET_CHANGED" then
            Tracker:RefreshAll(true) 
        elseif event == "UNIT_POWER_UPDATE" then
            if unit == "player" then
                local throttleTime = (InCombatLockdown() or UnitExists("target")) and 0.1 or 0.5
                powerNextUpdate = GetTime() + throttleTime
                powerUpdatePending = true
            end
        end
    end)

    local watchdog = CreateFrame("Frame")
    local watchdogTimer = 0
    watchdog:SetScript("OnUpdate", function(self, elapsed)
        watchdogTimer = watchdogTimer + elapsed
        if watchdogTimer > 1.0 then
            watchdogTimer = 0
            if UnitExists("target") or InCombatLockdown() then
                Tracker:RefreshAll(true)
            end
        end
    end)

    C_Timer.After(1, function() Tracker:RefreshAll() end)
end

WF:RegisterModule("cooldownTracker", L["Icon Desaturation"] or "自定义图标 (褪色)", InitCooldownTracker)