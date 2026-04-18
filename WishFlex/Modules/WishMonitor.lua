local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}

local WM = CreateFrame("Frame")
WF.WishMonitorAPI = WM

local function GetCurrentSpecID()
    local spec = GetSpecialization()
    return spec and (GetSpecializationInfo(spec) or 0) or 0
end

local function IsSecret(v) return type(v) == "number" and issecretvalue and issecretvalue(v) end
local function IsSafeValue(val)
    if val == nil then return false end
    if type(issecretvalue) == "function" and issecretvalue(val) then return false end
    return true
end

function WM:RegisterEvent(event, func)
    if not self._events then self._events = {} end
    self._events[event] = func or event
    getmetatable(self).__index.RegisterEvent(self, event)
end

WM:SetScript("OnEvent", function(self, event, ...)
    local handler = self._events[event]
    if type(handler) == "function" then handler(self, event, ...)
    elseif type(handler) == "string" and type(self[handler]) == "function" then self[handler](self, event, ...) end
end)

WM.TrackedSkills = {}
WM.TrackedBuffs = {}
WM.SpellToCD = {}
WM.ActiveBuffFrames = {}
WM.ActiveSkillFrames = {}
WM.ScanCacheFrames = {}

WM.LastCDHash = 0 
WM.chargeCache = {}

function WM:ScanViewers(isFromUI)
    if WF.db and WF.db.classResource and WF.db.classResource.enable == false then return end
    if WF.db and WF.db.wishMonitor and WF.db.wishMonitor.enable == false then return end

    local currentHash = 0
    local viewers = {"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer"}
    for _, vName in ipairs(viewers) do
        local v = _G[vName]
        if v and v.itemFramePool then
            for frame in v.itemFramePool:EnumerateActive() do
                currentHash = currentHash + (frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID) or 0)
            end
        end
    end
    
    if not isFromUI and WM.LastCDHash == currentHash then return end
    WM.LastCDHash = currentHash
    WM.HasScanned = true
    
    wipe(WM.TrackedSkills)
    wipe(WM.TrackedBuffs)
    wipe(WM.SpellToCD)
    wipe(WM.ActiveBuffFrames)
    wipe(WM.ActiveSkillFrames)

    local function ProcessViewer(viewerName, isAura)
        local viewer = _G[viewerName]
        if viewer then
            wipe(WM.ScanCacheFrames)
            if viewer.itemFramePool then
                for frame in viewer.itemFramePool:EnumerateActive() do table.insert(WM.ScanCacheFrames, frame) end
            else
                for _, child in ipairs({ viewer:GetChildren() }) do table.insert(WM.ScanCacheFrames, child) end
            end

            for _, frame in ipairs(WM.ScanCacheFrames) do
                local cdID = frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID)
                if cdID then
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                    if info then
                        if info.spellID then WM.SpellToCD[info.spellID] = cdID end
                        if info.overrideSpellID and info.overrideSpellID > 0 then WM.SpellToCD[info.overrideSpellID] = cdID end
                        if info.linkedSpellIDs then
                            for _, lID in ipairs(info.linkedSpellIDs) do WM.SpellToCD[lID] = cdID end
                        end
                        
                        local mainID = (info.linkedSpellIDs and info.linkedSpellIDs[1]) or info.overrideSpellID or info.spellID
                        if mainID and type(mainID) == "number" and not IsSecret(mainID) and mainID > 0 then
                            local sInfo = C_Spell.GetSpellInfo(mainID)
                            if sInfo and sInfo.name then
                                if isAura then WM.TrackedBuffs[tostring(mainID)] = { name = sInfo.name, icon = sInfo.iconID }
                                else WM.TrackedSkills[tostring(mainID)] = { name = sInfo.name, icon = sInfo.iconID } end
                            end
                        end
                        if frame:IsShown() or frame._wishFlexHidden then
                            if isAura then WM.ActiveBuffFrames[#WM.ActiveBuffFrames+1] = frame
                            else WM.ActiveSkillFrames[#WM.ActiveSkillFrames+1] = frame end
                        end
                    end
                end
            end
        end
    end
    ProcessViewer("EssentialCooldownViewer", false)
    ProcessViewer("UtilityCooldownViewer", false)
    ProcessViewer("BuffIconCooldownViewer", true)
    ProcessViewer("BuffBarCooldownViewer", true)
end

local defaults = {
    skills = {}, buffs = {}, enable = true,
    width = 250, height = 14, showStack = true, showTimer = true,
    freeLayout = { spacing = 1, yOffset = 0, height = 0 },
    globalLayout = { growth = "UP", spacing = 2 }, sortOrder = {}
}

local function DeepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then if type(target[k]) ~= "table" then target[k] = {} end; DeepMerge(target[k], v)
        else if target[k] == nil then target[k] = v end end
    end
end

local dbInitialized = false
local function GetDB()
    if not WF.db.wishMonitor then WF.db.wishMonitor = {} end
    if not dbInitialized then DeepMerge(WF.db.wishMonitor, defaults); dbInitialized = true end
    return WF.db.wishMonitor
end

WM.ItemTablePool = {}
WM.ActiveDataArray = {}
WM.SortedSkillIDsArray = {}
WM.SortedBuffIDsArray = {}

local function safeNum(str)
    local n = string.match(tostring(str), "^(%d+)")
    return tonumber(n) or 0
end

-- 【极限优化 3】：单次 O(1) 汇总映射，杜绝光环循环时产生海量查询垃圾
local currentAuraTally = {}
local currentAuraData = {}
local auraCacheBuilt = false

local function BuildAuraCache()
    wipe(currentAuraTally)
    wipe(currentAuraData)
    auraCacheBuilt = true
    
    local function Scan(filter)
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
            if not aura then break end
            local sid = aura.spellId
            if type(sid) == "number" and not IsSecret(sid) then
                if not currentAuraData[sid] then
                    currentAuraData[sid] = aura
                end
                local apps = aura.applications or 0
                if type(apps) == "number" and not IsSecret(apps) and apps > 0 then
                    currentAuraTally[sid] = apps
                else
                    currentAuraTally[sid] = (currentAuraTally[sid] or 0) + 1
                end
            end
        end
    end
    Scan("HELPFUL")
    Scan("HARMFUL")
end

function WM:UpdateData()
    if WF.db and WF.db.classResource and WF.db.classResource.enable == false then return end
    if WF.db and WF.db.wishMonitor and WF.db.wishMonitor.enable == false then return end

    local isConfigOpen = false
    if WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown() then isConfigOpen = true end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then isConfigOpen = true end
    if WF.MoversUnlocked then isConfigOpen = true end
    
    if not isConfigOpen and WF.ClassResourceAPI and WF.ClassResourceAPI.isVigorActive then
        if WF.ClassResourceAPI.ClearMonitors then WF.ClassResourceAPI:ClearMonitors() end
        return
    end
    
    auraCacheBuilt = false
    local db = GetDB()
    local currentSpecID = GetCurrentSpecID()
    WM.spellMaxChargeCache = WM.spellMaxChargeCache or {}
    
    local activeData = WM.ActiveDataArray
    wipe(activeData)
    local itemPoolIdx = 0
    
    local function ProcessItem(spellIDStr, cfg, isBuff)
        if not cfg.enable then return end
        
        local actualQueryID = spellIDStr
        if cfg.realSpellID then actualQueryID = tostring(cfg.realSpellID) end
        
        if cfg.alignWithResource == nil then cfg.alignWithResource = true end
        if cfg.alwaysShow == nil then cfg.alwaysShow = false end
        if cfg.hideOriginal == nil then cfg.hideOriginal = false end

        local exactKey = (isBuff and "BUFF_" or "CD_") .. actualQueryID
        local cdDB = WF.db.cooldownCustom
        if cdDB then
            if not cdDB.blacklist then cdDB.blacklist = {} end
            local isBlacklisted = cdDB.blacklist[exactKey] or cdDB.blacklist[actualQueryID]
            if isBlacklisted and not cfg.hideOriginal then cfg.hideOriginal = true
            elseif cfg.hideOriginal and not isBlacklisted then cdDB.blacklist[exactKey] = true end
        end
        
        local matchSpec = false
        if cfg.allSpecs or not cfg.specID or cfg.specID == 0 or cfg.specID == currentSpecID then matchSpec = true end
        if not matchSpec then return end
        
        local spellID = tonumber(actualQueryID)
        local isActive, rawCount, maxVal, durObjC = false, 0, 1, nil
        local tType = isBuff and "buff" or "cooldown"
        
        if WM.chargeCache[spellID] == nil then
            local testChInfo = C_Spell.GetSpellCharges(spellID)
            WM.chargeCache[spellID] = (testChInfo and type(testChInfo.maxCharges) == "number" and testChInfo.maxCharges > 1) or false
        end
        
        local isChargeSpell = false
        if cfg.trackType == "charge" or WM.chargeCache[spellID] then
            isChargeSpell = true
            tType = "charge"
        end
        
        if isBuff then
            local cdID = WM.SpellToCD[spellID]
            local instID, foundFrame = nil, nil
            local auraUnit = "player"

            if not auraCacheBuilt then BuildAuraCache() end
            local aura = currentAuraData[spellID]
            local totalCount = currentAuraTally[spellID] or 0
            
            if aura then
                isActive = true
                rawCount = totalCount
                if aura.auraInstanceID then durObjC = C_UnitAuras.GetAuraDuration("player", aura.auraInstanceID) end
            end

            if not isActive and cdID then
                for _, vName in ipairs({"BuffIconCooldownViewer", "BuffBarCooldownViewer", "EssentialCooldownViewer", "UtilityCooldownViewer"}) do
                    local viewer = _G[vName]
                    if viewer and viewer.itemFramePool then
                        for frame in viewer.itemFramePool:EnumerateActive() do
                            local frameCdID = frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID)
                            if frameCdID == cdID and (frame:IsShown() or frame._wishFlexHidden or cfg.hideOriginal) then
                                foundFrame = frame
                                instID = frame.auraInstanceID
                                if type(instID) == "table" and instID.auraInstanceID ~= nil then instID = instID.auraInstanceID end
                                if type(frame.auraDataUnit) == "string" and frame.auraDataUnit ~= "" then auraUnit = frame.auraDataUnit end
                                break
                            end
                        end
                    end
                    if foundFrame then break end
                end
            end

            if not isActive and instID and IsSafeValue(instID) then
                local data = C_UnitAuras.GetAuraDataByAuraInstanceID(auraUnit, instID)
                if data then 
                    isActive = true
                    rawCount = data.applications or 0
                    durObjC = C_UnitAuras.GetAuraDuration(auraUnit, instID) 
                end
            end

            if not isActive and foundFrame then
                isActive = true
                rawCount = foundFrame.count or (foundFrame.state and foundFrame.state.count) or (foundFrame.cooldownInfo and foundFrame.cooldownInfo.count) or 0
                local cInfo = foundFrame.cooldownInfo
                if cInfo and cInfo.startTime and cInfo.duration and cInfo.duration > 0 then durObjC = { startTime = cInfo.startTime, duration = cInfo.duration } end
            end
            
            maxVal = (cfg.mode == "stack") and (tonumber(cfg.maxStacks) or 5) or 1
        else
            if isChargeSpell then 
                local chInfo = C_Spell.GetSpellCharges(spellID)
                if chInfo then 
                    if type(chInfo.maxCharges) == "number" and not IsSecret(chInfo.maxCharges) then WM.spellMaxChargeCache[spellID] = chInfo.maxCharges end
                    maxVal = WM.spellMaxChargeCache[spellID] or chInfo.maxCharges or 1
                    rawCount = chInfo.currentCharges or 0
                    durObjC = C_Spell.GetSpellChargeDuration(spellID)
                    if IsSecret(rawCount) or (tonumber(rawCount) or 0) > 0 or durObjC then isActive = true end 
                end 
            else
                local cInfo = C_Spell.GetSpellCooldown(spellID)
                if cInfo then 
                    local dur = cInfo.duration
                    if IsSecret(dur) or (tonumber(dur) and tonumber(dur) > 1.5) then isActive = true; durObjC = C_Spell.GetSpellCooldownDuration(spellID) end 
                end
            end
        end
        
        local isConfigPreview = isConfigOpen and (not isActive)

        if isActive or cfg.alwaysShow or isConfigPreview then
            itemPoolIdx = itemPoolIdx + 1
            local data = WM.ItemTablePool[itemPoolIdx]
            if not data then data = { state = {} }; WM.ItemTablePool[itemPoolIdx] = data end
            
            data.spellIDStr = spellIDStr; data.spellID = spellID; data.cfg = cfg
            data.isBuff = isBuff; data.isConfigPreview = isConfigPreview
            
            data.state.spellID = spellID; data.state.isActive = isActive; data.state.count = rawCount
            data.state.maxVal = maxVal; data.state.durObjC = durObjC; data.state.trackType = tType
            
            table.insert(activeData, data)
        end
    end

    local sortedSkillIDs = WM.SortedSkillIDsArray
    wipe(sortedSkillIDs)
    for id in pairs(db.skills) do table.insert(sortedSkillIDs, id) end
    table.sort(sortedSkillIDs, function(a,b) return safeNum(a) < safeNum(b) end)
    for _, idStr in ipairs(sortedSkillIDs) do ProcessItem(idStr, db.skills[idStr], false) end

    local sortedBuffIDs = WM.SortedBuffIDsArray
    wipe(sortedBuffIDs)
    for id in pairs(db.buffs) do table.insert(sortedBuffIDs, id) end
    table.sort(sortedBuffIDs, function(a,b) return safeNum(a) < safeNum(b) end)
    for _, idStr in ipairs(sortedBuffIDs) do ProcessItem(idStr, db.buffs[idStr], true) end

    if WF.ClassResourceAPI and WF.ClassResourceAPI.RenderMonitors then
        WF.ClassResourceAPI:RenderMonitors(activeData, db)
    end
end

local isUpdateScheduled = false
function WM:TriggerUpdate()
    if WF.db and WF.db.classResource and WF.db.classResource.enable == false then return end
    if WF.db and WF.db.wishMonitor and WF.db.wishMonitor.enable == false then return end

    if isUpdateScheduled then return end
    isUpdateScheduled = true
    
    C_Timer.After(0.3, function()
        isUpdateScheduled = false
        WM:ScanViewers(false)
        WM:UpdateData() 
        if WF.CooldownCustomAPI then
            if WF.CooldownCustomAPI.BuildHiddenCache then WF.CooldownCustomAPI:BuildHiddenCache() end
            if WF.CooldownCustomAPI.MarkLayoutDirty then WF.CooldownCustomAPI:MarkLayoutDirty() end
        end
    end)
end

local function InitWishMonitor()
    GetDB()
    if WF.db and WF.db.classResource and WF.db.classResource.enable == false then return end
    if WF.db and WF.db.wishMonitor and WF.db.wishMonitor.enable == false then return end

    WM:RegisterEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(0.5, function() WM:TriggerUpdate() end) end)
    WM:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() C_Timer.After(0.5, function() WM:TriggerUpdate() end) end)
    WM:RegisterEvent("TRAIT_CONFIG_UPDATED", function() WM:TriggerUpdate() end)
    
    WM:RegisterEvent("UNIT_AURA", function(self, e, unit) if unit == "player" then WM:TriggerUpdate() end end)
    WM:RegisterEvent("SPELL_UPDATE_COOLDOWN", "TriggerUpdate")
    WM:RegisterEvent("SPELL_UPDATE_CHARGES", "TriggerUpdate")
    
    C_Timer.After(1, function()
        for _, vName in ipairs({"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer"}) do
            local viewer = _G[vName]; if viewer and viewer.UpdateLayout then hooksecurefunc(viewer, "UpdateLayout", function() WM:TriggerUpdate() end) end
        end
    end)
end

WF:RegisterModule("wishMonitor", L["Custom Monitor"] or "自定义监控", InitWishMonitor)

function WM:GetPreviewData(editSpecID)
    local db = GetDB()
    local currentSpec = editSpecID or GetCurrentSpecID()
    if currentSpec >= 1000 then currentSpec = GetCurrentSpecID() end
    local list = {}
    
    local function AddItems(source, isBuff)
        for idStr, cfg in pairs(source) do
            local matchSpec = false
            if cfg.allSpecs or not cfg.specID or cfg.specID == 0 or cfg.specID == currentSpec then matchSpec = true end
            if cfg.enable and matchSpec then
                if cfg.hideOriginal == nil then cfg.hideOriginal = false end
                local actualID = cfg.realSpellID or tostring(idStr):gsub("_TXT", "")
                local si = C_Spell.GetSpellInfo(tonumber(actualID))
                
                local passStack = (cfg.textEnable ~= false)
                local passTimer = (cfg.timerEnable ~= false)
                
                table.insert(list, {
                    idStr = idStr, spellID = tonumber(actualID), name = si and si.name or idStr,
                    height = cfg.height, color = cfg.color or {r=0,g=0.8,b=1,a=1},
                    hideOriginal = cfg.hideOriginal,
                    showStack = passStack, showTimer = passTimer,
                    fontSize = cfg.fontSize, stackAnchor = cfg.textAnchor, timerAnchor = cfg.timerAnchor,
                    mode = cfg.mode, maxStacks = cfg.maxStacks, inFreeLayout = cfg.inFreeLayout, reverseFill = cfg.reverseFill, bgColor = cfg.bgColor
                })
            end
        end
    end
    AddItems(db.skills, false); AddItems(db.buffs, true)
    
    local function GetSortIndex(spellID)
        local targetID = tostring(spellID); for i, id in ipairs(db.sortOrder) do if tostring(id) == targetID then return i end end; return 9999
    end
    table.sort(list, function(a, b)
        local idxA = GetSortIndex(a.spellID); local idxB = GetSortIndex(b.spellID)
        if idxA == idxB then return (a.spellID or 0) < (b.spellID or 0) end; return idxA < idxB
    end)
    return list, db.globalLayout.growth or "UP", db.globalLayout.spacing or 2
end