local AddonName, ns = ...
local WF = ns.WF

WF.StateEngine = {}
WF.StateEngine.PendingEvents = { COOLDOWN = false, CHARGES = false, AURA = false }

local TrackedSpells = {}      
local CurrentStateCache = {}  
WF.StateEngine.MaxChargeCache = {} 
WF.StateEngine.ViewerCache = { SpellToCD = {}, ActiveBuffFrames = {}, ActiveSkillFrames = {} }
local pendingAura = false
local pendingCD = false
local pendingViewer = false

local function IsSafeValue(val)
    if val == nil then return false end
    if type(issecretvalue) == "function" and issecretvalue(val) then return false end
    return true
end

local function GetBaseSpellFast(spellID)
    if not IsSafeValue(spellID) then return nil end
    local base = spellID
    pcall(function() if C_Spell and C_Spell.GetBaseSpell then base = C_Spell.GetBaseSpell(spellID) or spellID end end)
    return base
end

function WF.StateEngine:ScanViewers()
    wipe(self.ViewerCache.SpellToCD)
    wipe(self.ViewerCache.ActiveBuffFrames)
    wipe(self.ViewerCache.ActiveSkillFrames)

    local function ProcessFrame(frame, isAura)
        if not frame then return end
        local cdID = frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID)
        if cdID then
            local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
            if info then
                if info.spellID then self.ViewerCache.SpellToCD[info.spellID] = cdID end
                if info.overrideSpellID and info.overrideSpellID > 0 then self.ViewerCache.SpellToCD[info.overrideSpellID] = cdID end
                if info.linkedSpellIDs then
                    for i=1, #info.linkedSpellIDs do self.ViewerCache.SpellToCD[info.linkedSpellIDs[i]] = cdID end
                end
                
                local mainID = (info.linkedSpellIDs and info.linkedSpellIDs[1]) or info.overrideSpellID or info.spellID
                local baseID = GetBaseSpellFast(mainID)
                if baseID then self.ViewerCache.SpellToCD[baseID] = cdID end

                if frame:IsShown() then
                    if isAura then self.ViewerCache.ActiveBuffFrames[#self.ViewerCache.ActiveBuffFrames+1] = frame
                    else self.ViewerCache.ActiveSkillFrames[#self.ViewerCache.ActiveSkillFrames+1] = frame end
                end
            end
        end
    end

    local function ProcessViewer(viewerName, isAura)
        local viewer = _G[viewerName]
        if viewer then
            if viewer.itemFramePool then
                for frame in viewer.itemFramePool:EnumerateActive() do ProcessFrame(frame, isAura) end
            else
                for i = 1, viewer:GetNumChildren() do ProcessFrame(select(i, viewer:GetChildren()), isAura) end
            end
        end
    end

    ProcessViewer("EssentialCooldownViewer", false)
    ProcessViewer("UtilityCooldownViewer", false)
    ProcessViewer("BuffIconCooldownViewer", true)
    ProcessViewer("BuffBarCooldownViewer", true)
end

function WF.StateEngine:RegisterTrack(spellID, trackType, cfgMax)
    if not spellID then return end
    if not TrackedSpells[spellID] then
        TrackedSpells[spellID] = { type = trackType, cfgMax = cfgMax or 1 }
    else
        TrackedSpells[spellID].type = trackType
        TrackedSpells[spellID].cfgMax = cfgMax or TrackedSpells[spellID].cfgMax or 1
    end
    self:UpdateSpellState(spellID)
end

function WF.StateEngine:GetState(spellID)
    if not CurrentStateCache[spellID] then self:UpdateSpellState(spellID) end
    return CurrentStateCache[spellID] and CurrentStateCache[spellID].fullState
end

function WF.StateEngine:UpdateSpellState(spellID)
    local config = TrackedSpells[spellID]
    if not config then return end

    if not CurrentStateCache[spellID] then
        CurrentStateCache[spellID] = { initialized = false, fullState = { spellID = spellID } }
    end
    local cache = CurrentStateCache[spellID]
    local state = cache.fullState

    state.trackType = config.type
    state.isActive = false
    state.count = 0
    state.maxVal = 1
    state.durObjC = nil
    state.isCharging = false

    if config.type == "buff" then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura then
            state.isActive = true
            state.count = aura.applications or 0
            if aura.auraInstanceID then state.durObjC = C_UnitAuras.GetAuraDuration("player", aura.auraInstanceID) end
        end
        
        if not state.isActive then
            local cdID = self.ViewerCache.SpellToCD[spellID]
            local instID = nil
            local foundFrame = nil

            if cdID then
                for i = 1, #self.ViewerCache.ActiveBuffFrames do
                    local frame = self.ViewerCache.ActiveBuffFrames[i]
                    if frame.cooldownID == cdID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID == cdID) then
                        instID = frame.auraInstanceID; foundFrame = frame; break
                    end
                end
            end

            if instID and IsSafeValue(instID) then
                local data = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instID)
                if data then
                    state.isActive = true; state.count = data.applications or 0
                    state.durObjC = C_UnitAuras.GetAuraDuration("player", instID)
                end
            end

            if not state.isActive and foundFrame then
                state.isActive = true; state.count = foundFrame.count or 0
                local cInfo = foundFrame.cooldownInfo
                if cInfo and cInfo.startTime and cInfo.duration and cInfo.duration > 0 then
                    if not state._durObjC_table then state._durObjC_table = {} end
                    state._durObjC_table.startTime = cInfo.startTime
                    state._durObjC_table.duration = cInfo.duration
                    state.durObjC = state._durObjC_table
                end
            end
        end
    else
        local chInfo = C_Spell.GetSpellCharges(spellID)
        local isCharge = false
        local mc = chInfo and chInfo.maxCharges
        
        local success, isGreater = pcall(function() return type(mc) == "number" and mc > 1 end)
        
        if success and isGreater then
            isCharge = true; WF.StateEngine.MaxChargeCache[spellID] = mc
        elseif config.type == "charge" or (config.cfgMax and config.cfgMax > 1) then
            isCharge = true
        elseif WF.StateEngine.MaxChargeCache[spellID] and WF.StateEngine.MaxChargeCache[spellID] > 1 then
            isCharge = true
        end

        if isCharge then
            state.trackType = "charge"
            state.maxVal = WF.StateEngine.MaxChargeCache[spellID] or config.cfgMax or 1
            if state.maxVal < 1 then state.maxVal = 1 end
            
            state.count = chInfo and chInfo.currentCharges or 0
            state.durObjC = C_Spell.GetSpellChargeDuration(spellID)
            
            local cSuccess, isLess = pcall(function() return state.count < state.maxVal end)
            if not cSuccess or isLess or (tonumber(state.count) and tonumber(state.count) > 0) then state.isActive = true end
        else
            state.trackType = "cooldown"
            local cInfo = C_Spell.GetSpellCooldown(spellID)
            if cInfo then
                local dur = cInfo.duration
                local dSuccess, isValid = pcall(function() return type(dur) == "number" and dur > 1.5 end)
                if not dSuccess or isValid then
                    state.isActive = true
                    state.durObjC = C_Spell.GetSpellCooldownDuration(spellID)
                end
            end
            
            if not state.isActive then
                local cdID = self.ViewerCache.SpellToCD[spellID]
                if cdID then
                    for i = 1, #self.ViewerCache.ActiveSkillFrames do
                        local frame = self.ViewerCache.ActiveSkillFrames[i]
                        if frame.cooldownID == cdID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID == cdID) then
                            state.isActive = true; state.count = frame.count or 0
                            local cInfo = frame.cooldownInfo
                            if cInfo and cInfo.startTime and cInfo.duration and cInfo.duration > 0 then
                                if not state._durObjC_table then state._durObjC_table = {} end
                                state._durObjC_table.startTime = cInfo.startTime
                                state._durObjC_table.duration = cInfo.duration
                                state.durObjC = state._durObjC_table
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    local isSecretCount = not IsSafeValue(state.count)
    local sCount = isSecretCount and -1 or state.count
    local sMax = IsSafeValue(state.maxVal) and state.maxVal or -1

    local isSecretTime = false
    local st = 0
    if state.durObjC then
        local rawSt = nil
        if type(state.durObjC) == "table" then rawSt = state.durObjC.startTime
        elseif type(state.durObjC) == "userdata" and type(state.durObjC.GetCooldownStartTime) == "function" then
            pcall(function() rawSt = state.durObjC:GetCooldownStartTime() end)
        end
        if rawSt ~= nil and not IsSafeValue(rawSt) then isSecretTime = true
        else st = rawSt or 0 end
    end

    local isChanged = false
    if not cache.initialized then
        isChanged = true
    elseif cache.isActive ~= state.isActive then
        isChanged = true
    elseif isSecretCount or isSecretTime then
        if config.type == "buff" and WF.StateEngine.PendingEvents.AURA then isChanged = true end
        if config.type ~= "buff" and (WF.StateEngine.PendingEvents.COOLDOWN or WF.StateEngine.PendingEvents.CHARGES) then isChanged = true end
    else
        if cache.sCount ~= sCount then isChanged = true
        elseif cache.sMax ~= sMax then isChanged = true
        elseif cache.st ~= st then isChanged = true end
    end

    if isChanged then
        cache.initialized = true
        cache.isActive = state.isActive
        cache.sCount = sCount
        cache.sMax = sMax
        cache.st = st

        WF:FireEvent("WF_SPELL_STATE_CHANGED", spellID, state)
    end
end

local isUpdateScheduled = false
local function DoTriggerAllUpdates()
    isUpdateScheduled = false
    
    if pendingViewer then
        WF.StateEngine:ScanViewers()
    end
    
    for spellID, config in pairs(TrackedSpells) do
        local shouldUpdate = pendingViewer
        if not shouldUpdate then
            if config.type == "buff" and pendingAura then shouldUpdate = true end
            if config.type ~= "buff" and pendingCD then shouldUpdate = true end
        end
        
        if shouldUpdate then
            WF.StateEngine:UpdateSpellState(spellID)
        end
    end
    
    pendingAura = false
    pendingCD = false
    pendingViewer = false
    WF.StateEngine.PendingEvents.AURA = false
    WF.StateEngine.PendingEvents.COOLDOWN = false
    WF.StateEngine.PendingEvents.CHARGES = false
end

function WF.StateEngine:TriggerAllUpdates()
    if isUpdateScheduled then return end
    isUpdateScheduled = true
    C_Timer.After(0.05, DoTriggerAllUpdates)
end

function WF.StateEngine:TriggerViewerUpdate()
    pendingViewer = true
    self:TriggerAllUpdates()
end

local function SafeHook(object, funcName, callback)
    if object and object[funcName] and type(object[funcName]) == "function" then hooksecurefunc(object, funcName, callback) end
end
WF:RegisterEvent("UNIT_AURA", function(e, unit, updateInfo) 
    if unit == "player" then 
        if not InCombatLockdown() and not UnitExists("target") and updateInfo then
            local isRelevant = false
            
            if updateInfo.addedAuras then
                for _, aura in ipairs(updateInfo.addedAuras) do 
                    -- 【修复】：拦截 issecretvalue 报错
                    if IsSafeValue(aura.spellId) and TrackedSpells[aura.spellId] then 
                        isRelevant = true; break 
                    end 
                end
            end
            
            if not isRelevant and updateInfo.updatedAuraInstanceIDs then
                for _, instanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
                    local aura = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instanceID)
                    if aura and IsSafeValue(aura.spellId) and TrackedSpells[aura.spellId] then 
                        isRelevant = true; break 
                    end
                end
            end
            
            if not isRelevant then return end 
        end
        
        pendingAura = true
        WF.StateEngine.PendingEvents.AURA = true
        WF.StateEngine:TriggerAllUpdates() 
    end 
end)

WF:RegisterEvent("SPELL_UPDATE_COOLDOWN", function() pendingCD = true; WF.StateEngine.PendingEvents.COOLDOWN = true; WF.StateEngine:TriggerAllUpdates() end)
WF:RegisterEvent("SPELL_UPDATE_CHARGES", function() pendingCD = true; WF.StateEngine.PendingEvents.CHARGES = true; WF.StateEngine:TriggerAllUpdates() end)
WF:RegisterEvent("PLAYER_ENTERING_WORLD", function() pendingViewer = true; WF.StateEngine:TriggerAllUpdates() end)

C_Timer.After(1, function()
    local viewers = { _G.BuffIconCooldownViewer, _G.EssentialCooldownViewer, _G.UtilityCooldownViewer, _G.BuffBarCooldownViewer }
    for _, viewer in ipairs(viewers) do
        if viewer and viewer.itemFramePool then 
            SafeHook(viewer.itemFramePool, "Acquire", function() WF.StateEngine:TriggerViewerUpdate() end)
            SafeHook(viewer.itemFramePool, "Release", function() WF.StateEngine:TriggerViewerUpdate() end) 
        end
    end
    
    local mixins = { _G.CooldownViewerBuffIconItemMixin, _G.CooldownViewerEssentialItemMixin, _G.CooldownViewerUtilityItemMixin, _G.CooldownViewerBuffBarItemMixin }
    for _, mixin in ipairs(mixins) do 
        if mixin then 
            if mixin.OnCooldownIDSet then SafeHook(mixin, "OnCooldownIDSet", function() WF.StateEngine:TriggerViewerUpdate() end) end 
            if mixin.OnActiveStateChanged then SafeHook(mixin, "OnActiveStateChanged", function() WF.StateEngine:TriggerViewerUpdate() end) end 
        end 
    end
end)