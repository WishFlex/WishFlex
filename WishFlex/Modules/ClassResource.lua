local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}
local LSM = LibStub("LibSharedMedia-3.0", true)

local math_floor, math_abs, math_max, math_min = math.floor, math.abs, math.max, math.min
local string_format = string.format
local GetTime, tonumber, tostring, type = GetTime, tonumber, tostring, type
local UnitPower, UnitPowerMax, UnitPowerType, UnitStagger, UnitHealthMax = UnitPower, UnitPowerMax, UnitPowerType, UnitStagger, UnitHealthMax
local IsMounted, GetShapeshiftFormID = IsMounted, GetShapeshiftFormID

local CR = CreateFrame("Frame")
WF.ClassResourceAPI = CR

local playerClass = select(2, UnitClass("player"))
local hasHealerSpec = (playerClass == "PALADIN" or playerClass == "PRIEST" or playerClass == "SHAMAN" or playerClass == "MONK" or playerClass == "DRUID" or playerClass == "EVOKER")
CR.playerClass = playerClass
CR.hasHealerSpec = hasHealerSpec

local DEFAULT_COLOR = {r=1, g=1, b=1}
local DEF_TEXT_COLOR = {r=1, g=1, b=1}
local DEF_DIVIDER_COLOR = {r=1, g=1, b=1, a=1}
local POWER_COLORS = { [0]={r=0,g=0.5,b=1}, [1]={r=1,g=0,b=0}, [2]={r=1,g=0.5,b=0.25}, [3]={r=1,g=1,b=0}, [4]={r=1,g=0.96,b=0.41}, [5]={r=0.8,g=0.1,b=0.2}, [7]={r=0.5,g=0.32,b=0.55}, [8]={r=0.3,g=0.52,b=0.9}, [9]={r=0.95,g=0.9,b=0.6}, [11]={r=0,g=0.5,b=1}, [12]={r=0.71,g=1,b=0.92}, [13]={r=0.4,g=0.8,b=0.8}, [16]={r=0.1,g=0.1,b=0.98}, [17]={r=0.79,g=0.26,b=0.99}, [18]={r=1,g=0.61,b=0}, [19]={r=0.4,g=0.8,b=1} }
CR.POWER_COLORS = POWER_COLORS

local PLAYER_CLASS_COLOR = DEFAULT_COLOR
local cc_cache = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass]
if cc_cache then PLAYER_CLASS_COLOR = {r=cc_cache.r, g=cc_cache.g, b=cc_cache.b} end

local DEF_VIGOR_COLOR = {r=0.2, g=0.7, b=1}
local DEF_WHIRLING_COLOR = {r=1, g=0.8, b=0}
local MONK_STAGGER_LOW = {r=0, g=1, b=0.59}
local MONK_STAGGER_MED = {r=1, g=1, b=0}
local MONK_STAGGER_HIGH = {r=1, g=0, b=0}

CR.SPELL_CONSTANTS = { SKYRIDING_SURGE = 372608, VIGOR_RECOVERY_WIND = 425782, WHIRLING_SURGE = 361584 }
CR._vigorCache = { cc = 0, mc = 6, st = 0, dur = 0 }
CR._windCache = 0
CR._whirlingCache = { st = 0, dur = 0 }

function CR:UpdateFlightCaches()
    if not self.isVigorActive then return end
    
    local vData = C_Spell.GetSpellCharges(CR.SPELL_CONSTANTS.SKYRIDING_SURGE)
    if vData then
        CR._vigorCache.cc = vData.currentCharges or 0
        CR._vigorCache.mc = vData.maxCharges or 6
        CR._vigorCache.st = vData.cooldownStartTime or 0
        CR._vigorCache.dur = vData.cooldownDuration or 0
    end

    local wData = C_Spell.GetSpellCharges(CR.SPELL_CONSTANTS.VIGOR_RECOVERY_WIND)
    if wData then
        CR._windCache = wData.currentCharges or 0
    end

    local wsData = C_Spell.GetSpellCooldown(CR.SPELL_CONSTANTS.WHIRLING_SURGE)
    if wsData then
        CR._whirlingCache.st = wsData.startTime or 0
        CR._whirlingCache.dur = wsData.duration or 0
    end
end
-- ==========================================

function CR.IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

CR._powerCache = {}
function CR.GetSafePower(pType)
    local curr = UnitPower("player", pType)
    local maxP = UnitPowerMax("player", pType)
    CR._powerCache[pType] = CR._powerCache[pType] or {c=0, m=100}
    
    if not CR.IsSecret(curr) then CR._powerCache[pType].c = curr end
    if not CR.IsSecret(maxP) then CR._powerCache[pType].m = maxP end
    
    return curr, maxP, CR._powerCache[pType].c, CR._powerCache[pType].m
end

function CR.GetSafeMana()
    local curr = UnitPower("player", 0)
    local maxP = UnitPowerMax("player", 0)
    CR._manaCache = CR._manaCache or {c=0, m=100}
    
    if not CR.IsSecret(curr) then CR._manaCache.c = curr end
    if not CR.IsSecret(maxP) then CR._manaCache.m = maxP end
    
    return curr, maxP, CR._manaCache.c, CR._manaCache.m
end

local function GetPlayerAuraSafe(spellID)
    if not spellID then return nil end
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then return C_UnitAuras.GetPlayerAuraBySpellID(spellID) end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then break end
            if aura.spellId == spellID then return aura end
        end
    end
    return nil
end

function CR.GetClassResourceData()
    local spec = GetSpecializationInfo(GetSpecialization() or 1)
    if WF.db and WF.db.classResource and WF.db.classResource.presets then
        for pidStr, pData in pairs(WF.db.classResource.presets) do
            local spellID = tonumber(pidStr)
            if spellID then
                local aura = GetPlayerAuraSafe(spellID)
                if pData.isDuration then
                    local remain = 0; local maxD = tonumber(pData.maxVal) or 30
                    if aura and aura.expirationTime and aura.expirationTime > 0 then remain = aura.expirationTime - GetTime() end
                    if remain < 0 then remain = 0 end
                    return remain, maxD, PLAYER_CLASS_COLOR, 0
                else
                    local apps = aura and aura.applications or 0; local maxA = tonumber(pData.maxVal) or 5
                    return apps, maxA, PLAYER_CLASS_COLOR, 0
                end
            end
        end
    end

    if playerClass == "ROGUE" then return UnitPower("player", 4), UnitPowerMax("player", 4), PLAYER_CLASS_COLOR, 0
    elseif playerClass == "PALADIN" then return UnitPower("player", 9), 5, PLAYER_CLASS_COLOR, 0
    elseif playerClass == "WARLOCK" then 
        local maxTrue = UnitPowerMax("player", 7, true)
        local currTrue = UnitPower("player", 7, true)
        local maxShards = UnitPowerMax("player", 7)
        local curr = 0
        if not CR.IsSecret(maxTrue) and not CR.IsSecret(currTrue) and not CR.IsSecret(maxShards) then
            if maxTrue > 0 and maxShards > 0 then curr = (currTrue / maxTrue) * maxShards end
        end
        return curr, maxShards, PLAYER_CLASS_COLOR, 0
    elseif playerClass == "EVOKER" then return UnitPower("player", 19), UnitPowerMax("player", 19), PLAYER_CLASS_COLOR, 0
    elseif playerClass == "DEATHKNIGHT" then return 0, UnitPowerMax("player", 5), PLAYER_CLASS_COLOR, 0
    elseif playerClass == "MAGE" and spec == 62 then return UnitPower("player", 16), 4, PLAYER_CLASS_COLOR, 0
    elseif playerClass == "MONK" and spec == 268 then 
        local stagger = UnitStagger("player") or 0; local maxHealth = UnitHealthMax("player") or 1
        if maxHealth <= 0 then maxHealth = 1 end
        local pct = 0
        if not CR.IsSecret(stagger) and not CR.IsSecret(maxHealth) then pct = stagger / maxHealth end
        local cColor = MONK_STAGGER_LOW
        if pct > 0.6 then cColor = MONK_STAGGER_HIGH elseif pct > 0.3 then cColor = MONK_STAGGER_MED end
        return pct, 1, cColor, stagger
    elseif playerClass == "MONK" and spec == 269 then return UnitPower("player", 12), UnitPowerMax("player", 12), PLAYER_CLASS_COLOR, 0
    elseif playerClass == "DRUID" and UnitPowerType("player") == 3 then return UnitPower("player", 4), 5, PLAYER_CLASS_COLOR, 0
    elseif playerClass == "HUNTER" and spec == 255 then local apps = 0; local aura = GetPlayerAuraSafe(260286); if aura then apps = aura.applications or 1 end; return apps, 3, PLAYER_CLASS_COLOR, 0
    end
    return 0, 0, DEFAULT_COLOR, 0
end

function CR.GetSafeClassResource()
    local curr, maxP, col, extra = CR.GetClassResourceData()
    CR._clsCache = CR._clsCache or {c=0, m=1, ext=0}
    
    if not CR.IsSecret(curr) then CR._clsCache.c = curr end
    if not CR.IsSecret(maxP) then CR._clsCache.m = maxP end
    if not CR.IsSecret(extra) then CR._clsCache.ext = extra end
    
    return curr, maxP, CR._clsCache.c, CR._clsCache.m, col, CR._clsCache.ext
end

CR._powerColorCurves = {}
CR._threshCache = {} 

function CR._SortThresholds(a, b)
    return (tonumber(a.value) or 0) < (tonumber(b.value) or 0)
end

function CR.GetSecretThresholdColor(pType, rawMax, baseColor, specCfg)
    if not specCfg.power.enableThreshold or not C_CurveUtil or not C_CurveUtil.CreateColorCurve then
        return baseColor
    end

    wipe(CR._threshCache)
    local hasAny = false
    
    if type(specCfg.power.colorThresholds) == "table" then
        for i = 1, 5 do
            local t = specCfg.power.colorThresholds[i]
            if type(t) == "table" and t.enable and (tonumber(t.value) or 0) > 0 then
                local safeColor = type(t.color) == "table" and t.color or {r=1, g=1, b=1, a=1}
                CR._threshCache[#CR._threshCache + 1] = { value = tonumber(t.value), color = safeColor }
                hasAny = true
            end
        end
    else
        local singleVal = tonumber(specCfg.power.thresholdValue)
        if singleVal and singleVal > 0 then
            local safeColor = type(specCfg.power.thresholdColor) == "table" and specCfg.power.thresholdColor or {r=1, g=0, b=0, a=1}
            CR._threshCache[1] = { value = singleVal, color = safeColor }
            hasAny = true
        end
    end

    if not hasAny then return baseColor end
    table.sort(CR._threshCache, CR._SortThresholds)

    local hash = pType .. "_" .. rawMax .. "_" .. baseColor.r .. "_" .. baseColor.g .. "_" .. baseColor.b
    for i = 1, #CR._threshCache do
        local t = CR._threshCache[i]
        hash = hash .. "_" .. t.value .. "_" .. (t.color.r or 1) .. "_" .. (t.color.g or 1) .. "_" .. (t.color.b or 1)
    end
    
    if not CR._powerColorCurves[hash] then
        local curve = C_CurveUtil.CreateColorCurve()
        local lastPct = 0
        local lastColor = baseColor
        curve:AddPoint(0.0, CreateColor(baseColor.r, baseColor.g, baseColor.b, baseColor.a or 1))

        for i = 1, #CR._threshCache do
            local t = CR._threshCache[i]
            local pct = t.value / (rawMax > 0 and rawMax or 1)
            if pct > 1 then pct = 1 end
            if pct < 0 then pct = 0 end
            if pct > lastPct then curve:AddPoint(pct - 0.0001, CreateColor(lastColor.r or 1, lastColor.g or 1, lastColor.b or 1, lastColor.a or 1)) end
            curve:AddPoint(pct, CreateColor(t.color.r or 1, t.color.g or 1, t.color.b or 1, t.color.a or 1))
            lastPct = pct
            lastColor = t.color
        end

        if lastPct < 1.0 then curve:AddPoint(1.0, CreateColor(lastColor.r or 1, lastColor.g or 1, lastColor.b or 1, lastColor.a or 1)) end
        CR._powerColorCurves[hash] = curve
    end

    local ok, res = pcall(UnitPowerPercent, "player", pType, false, CR._powerColorCurves[hash])
    if ok and res and res.GetRGBA then
        local r, g, b, a = res:GetRGBA()
        return {r=r, g=g, b=b, a=a}
    end

    return baseColor
end

function CR:RegisterEvent(event, func)
    if not self._events then self._events = {} end
    self._events[event] = func or event
    getmetatable(self).__index.RegisterEvent(self, event)
end
CR:SetScript("OnEvent", function(self, event, ...)
    local handler = self._events[event]
    if type(handler) == "function" then handler(self, event, ...)
    elseif type(handler) == "string" and type(self[handler]) == "function" then self[handler](self, event, ...) end
end)

local barDefaults = {
    power = { independent = false, barXOffset = 0, barYOffset = 0, height = 10, textEnable = true, textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = false, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", useCustomBgColor = false, bgColor = {r=0, g=0, b=0, a=0.5}, enableThreshold = false, thresholdValue = 100, thresholdColor = {r=1, g=0, b=0}, thresholdPowerType = "ALL" },
    class = { independent = false, barXOffset = 0, barYOffset = 0, height = 10, textEnable = false, textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = false, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=1, g=0.96, b=0.41}, useCustomColors = {}, customColors = {}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", useCustomBgColor = false, bgColor = {r=0, g=0, b=0, a=0.5} },
    mana = { independent = false, barXOffset = 0, barYOffset = 0, height = 10, textEnable = true, textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = false, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", useCustomBgColor = false, bgColor = {r=0, g=0, b=0, a=0.5} },
    vigor = { independent = false, barXOffset = 0, barYOffset = 0, height = 10, textEnable = false, textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = false, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0.2, g=0.7, b=1}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", useCustomBgColor = false, bgColor = {r=0, g=0, b=0, a=0.5} },
    whirling = { independent = false, barXOffset = 0, barYOffset = 0, height = 4, textEnable = false, textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = false, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=1, g=0.8, b=0}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", useCustomBgColor = false, bgColor = {r=0, g=0, b=0, a=0.5} },
}

local defaults = { 
    enable = true, attachToResource = true, alignWithCD = true, alignYOffset = 1, widthOffset = 0, 
    texture = "Wish2", font = "Expressway", specConfigs = {}, sortOrder = {"class", "power", "mana", "vigor", "whirling"}, 
    globalBgColor = {r=0, g=0, b=0, a=0.5}, fadeOOC = false, fadeAlpha = 0
}

function CR.GetOnePixelSize()
    local screenHeight = select(2, GetPhysicalScreenSize()); if not screenHeight or screenHeight == 0 then return 1 end
    local uiScale = UIParent:GetEffectiveScale(); if not uiScale or uiScale == 0 then return 1 end
    return 768.0 / screenHeight / uiScale
end

function CR.PixelSnap(value)
    if not value then return 0 end
    local onePixel = CR.GetOnePixelSize()
    if onePixel == 0 then return value end
    return math_floor(value / onePixel + 0.5) * onePixel
end

function CR.GetDurationTextSafe(remaining)
    if not remaining then return "" end
    local num = tonumber(remaining); if not num then return tostring(remaining) end
    if num >= 60 then return string_format("%dm", math_floor(num / 60))
    elseif num >= 10 then return string_format("%d", math_floor(num))
    else return string_format("%.1f", num) end
end

function CR.GetSafeJustify(anchorStr)
    if type(anchorStr) ~= "string" then return "CENTER" end
    if string.match(anchorStr, "LEFT") then return "LEFT" elseif string.match(anchorStr, "RIGHT") then return "RIGHT" else return "CENTER" end
end

function CR.SafeFormatNum(num)
    if type(num) == "number" then
        if num >= 1000000 then return string_format("%.1fm", num / 1000000)
        elseif num >= 1000 then return string_format("%.1fk", num / 1000)
        else return string_format("%d", math_floor(num)) end
    end
    return tostring(num)
end

function CR.UpdateBarValueSafe(sb, rawCurr, rawMax)
    pcall(sb.SetMinMaxValues, sb, 0, rawMax)
    sb._targetValue = rawCurr
    if not sb._currentValue then
        sb._currentValue = rawCurr
        pcall(sb.SetValue, sb, rawCurr)
    end
end

local function DeepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then if type(target[k]) ~= "table" then target[k] = {} end; DeepMerge(target[k], v) else if target[k] == nil then target[k] = v end end
    end
end

local dbInitialized = false
local cachedDB = nil

function CR.GetDB()
    if dbInitialized and cachedDB then return cachedDB end
    
    if not WF.db.classResource then WF.db.classResource = {} end
    DeepMerge(WF.db.classResource, defaults)

    local uniqueSort = {}
    local seenUnique = {}
    if type(WF.db.classResource.sortOrder) == "table" then
        for _, key in ipairs(WF.db.classResource.sortOrder) do
            if key ~= "monitor" and not seenUnique[key] then 
                table.insert(uniqueSort, key) 
                seenUnique[key] = true
            end
        end
    end
    
    local seenKeys = {}; for _, k in ipairs(uniqueSort) do seenKeys[k] = true end
    for _, key in ipairs({"class", "power", "mana", "vigor", "whirling"}) do 
        if not seenKeys[key] then table.insert(uniqueSort, key) end 
    end
    WF.db.classResource.sortOrder = uniqueSort
    
    dbInitialized = true
    cachedDB = WF.db.classResource
    return cachedDB
end

function CR:InvalidateDB()
    dbInitialized = false
    cachedDB = nil
end

function CR.GetCurrentContextID()
    local specIndex = GetSpecialization()
    return specIndex and GetSpecializationInfo(specIndex) or 0
end

local function GetDefaultVisibility(pClass, specID)
    if pClass == "DRUID" then return true, true, false end
    local sPower, sClass, sMana = false, false, false

    if pClass == "WARRIOR" then 
        sPower = true
    elseif pClass == "PALADIN" then if specID == 70 then sClass = true else sPower = true; sClass = true end
    elseif pClass == "HUNTER" then sPower = true
    elseif pClass == "ROGUE" then sPower = true; sClass = true
    elseif pClass == "PRIEST" then sPower = true
    elseif pClass == "DEATHKNIGHT" then sPower = true; sClass = true
    elseif pClass == "SHAMAN" then sPower = true
    elseif pClass == "MAGE" then if specID == 62 then sPower = true; sClass = true end
    elseif pClass == "WARLOCK" then sClass = true
    elseif pClass == "MONK" then sPower = true; sClass = true
    elseif pClass == "DEMONHUNTER" then sPower = true
    elseif pClass == "EVOKER" then sPower = true; sClass = true end

    return sPower, sClass, sMana
end

function CR.GetCurrentSpecConfig(ctxId)
    local db = CR.GetDB(); ctxId = ctxId or CR.GetCurrentContextID()
    if not db.specConfigs then db.specConfigs = {} end
    if type(db.specConfigs[ctxId]) ~= "table" then db.specConfigs[ctxId] = {} end
    local cfg = db.specConfigs[ctxId]
    
    if cfg.width == nil then cfg.width = db.width or 250 end
    if cfg.yOffset == nil then cfg.yOffset = 1 end
    
    local defPower, defClass, defMana = GetDefaultVisibility(playerClass, ctxId)
    if cfg.showPower == nil then cfg.showPower = defPower end
    if cfg.showClass == nil then cfg.showClass = defClass end
    if cfg.showMana == nil then cfg.showMana = defMana end
    if db.showVigor == nil then db.showVigor = true end
    if db.showWhirling == nil then db.showWhirling = true end

    if type(cfg.power) ~= "table" then cfg.power = {} end; DeepMerge(cfg.power, barDefaults.power)
    if type(cfg.class) ~= "table" then cfg.class = {} end; DeepMerge(cfg.class, barDefaults.class)
    if type(cfg.mana) ~= "table" then cfg.mana = {} end; DeepMerge(cfg.mana, barDefaults.mana)
    if type(db.vigor) ~= "table" then db.vigor = {} end; DeepMerge(db.vigor, barDefaults.vigor)
    if type(db.whirling) ~= "table" then db.whirling = {} end; DeepMerge(db.whirling, barDefaults.whirling)

    cfg.vigor = db.vigor; cfg.whirling = db.whirling; cfg.showVigor = db.showVigor; cfg.showWhirling = db.showWhirling
    return cfg
end

function CR:GetTopVisibleCDViewer()
    local ess = _G.EssentialCooldownViewer; local util = _G.UtilityCooldownViewer
    local essActive = ess and ess:IsShown() and (ess:GetWidth() or 0) > 5 and (ess:GetHeight() or 0) > 5
    if essActive then return ess, "Essential" end
    local utilActive = util and util:IsShown() and (util:GetWidth() or 0) > 5 and (util:GetHeight() or 0) > 5
    if utilActive then return util, "Utility" end
    return ess, "Essential" 
end

function CR:GetActiveWidth()
    local db = CR.GetDB()
    if db.alignWithCD then return self.baseAnchor and self.baseAnchor:GetWidth() or 250 end
    local specCfg = CR.GetCurrentSpecConfig(CR.GetCurrentContextID())
    return CR.PixelSnap(CR.PixelSnap(tonumber(specCfg.width) or 250) + CR.PixelSnap(tonumber(db.widthOffset) or 0))
end

function CR.GetSafeColor(cfg, defColor, isClassBar)
    if not cfg then return defColor or DEFAULT_COLOR end

    if isClassBar then 
        if type(cfg.useCustomColors) == "table" and cfg.useCustomColors[CR.playerClass] then
            if type(cfg.customColors) == "table" and cfg.customColors[CR.playerClass] then
                return cfg.customColors[CR.playerClass]
            end
        end
        if cfg.useCustomColor then
            if type(cfg.customColor) == "table" and type(cfg.customColor.r) == "number" then
                return cfg.customColor
            end
        end
    else 
        if cfg.useCustomColor then
            if type(cfg.customColor) == "table" and type(cfg.customColor.r) == "number" then
                return cfg.customColor
            end
        end
    end

    if type(defColor) == "table" and type(defColor.r) == "number" then return defColor end
    return DEFAULT_COLOR
end

function CR.GetPowerColor(pType) return POWER_COLORS[pType] or DEFAULT_COLOR end

function CR:DoStackLayout()
    local db = CR.GetDB(); local specCfg = self.cachedSpecCfg
    local isConfigOpen = false
    if WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown() then isConfigOpen = true end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then isConfigOpen = true end

    local activeKeys = {}; local stackDict = {}
    local nativeItems = {
        { key = "class", frame = self.classBar, show = self.showClass, cfg = specCfg.class, anchor = self.classAnchor },
        { key = "power", frame = self.powerBar, show = self.showPower, cfg = specCfg.power, anchor = self.powerAnchor },
        { key = "vigor", frame = self.vigorBar, show = self.showVigor, cfg = specCfg.vigor, anchor = self.vigorAnchor },
        { key = "whirling", frame = self.whirlingBar, show = self.showWhirling, cfg = specCfg.whirling, anchor = self.whirlingAnchor },
    }
    
    if hasHealerSpec then
        table.insert(nativeItems, 3, { key = "mana",  frame = self.manaBar, show = self.showMana, cfg = specCfg.mana, anchor = self.manaAnchor })
    else
        self.manaBar.isForceHidden = true; self.manaBar:Hide()
    end

    for _, item in ipairs(nativeItems) do
        local shouldStack = item.show
        if isConfigOpen and CR.Sandbox and CR.Sandbox.popupTarget == item.key then shouldStack = true end
        
        if shouldStack then
            item.frame.isForceHidden = false
            if not self.sleepMode or db.fadeOOC == false then item.frame:Show() end
            
            if not item.cfg.independent then
                stackDict[item.key] = { frame = item.frame, height = tonumber(item.cfg.height) or 10, xOff = tonumber(item.cfg.barXOffset) or 0, yOff = tonumber(item.cfg.barYOffset) or 0 }
                activeKeys[item.key] = true
            else
                item.frame:ClearAllPoints()
                item.frame:SetPoint("CENTER", item.anchor.mover or item.anchor, "CENTER", CR.PixelSnap(item.cfg.barXOffset or 0), CR.PixelSnap(item.cfg.barYOffset or 0))
                item.frame:SetSize(self:GetActiveWidth(), tonumber(item.cfg.height) or 10)
            end
        else item.frame.isForceHidden = true; item.frame:Hide() end
    end

    if self.ActiveMonitorFrames then
        for _, f in ipairs(self.ActiveMonitorFrames) do
            if not f.cfg.independent and f.cfg.displayMode ~= "text" then
                local key = "WM_" .. (f.spellIDStr or tostring(f.spellID))
                stackDict[key] = { frame = f, height = f.calcHeight, xOff = 0, yOff = 0 }; activeKeys[key] = true
            end
        end
    end

    local orderedStack = {}; local sortOrder = db.sortOrder or {}
    local existingKeys = {}; for _, k in ipairs(sortOrder) do existingKeys[k] = true end
    
    local addedNew = false
    for k in pairs(activeKeys) do if not existingKeys[k] then table.insert(sortOrder, 1, k); existingKeys[k] = true; addedNew = true end end
    if addedNew then db.sortOrder = sortOrder end

    local addedFrames = {}
    for i = #sortOrder, 1, -1 do 
        local key = sortOrder[i]; 
        if activeKeys[key] then 
            local f = stackDict[key].frame
            if not addedFrames[f] then
                table.insert(orderedStack, stackDict[key]) 
                addedFrames[f] = true
            end
        end 
    end

    self.lastStackedFrame = nil
    local targetWidth = self:GetActiveWidth() or 250
    local topViewer = self:GetTopVisibleCDViewer()
    local globalSpacing = CR.PixelSnap(specCfg.yOffset or 1)

    for _, item in ipairs(orderedStack) do
        local f = item.frame; f:ClearAllPoints(); local finalH = item.height; local targetX = CR.PixelSnap(item.xOff)
        if not self.lastStackedFrame then
            if db.alignWithCD and topViewer then
                local baseTY = CR.PixelSnap((tonumber(db.alignYOffset) or 1) + item.yOff)
                f:SetPoint("BOTTOMLEFT", topViewer, "TOPLEFT", targetX, baseTY)
                f:SetPoint("BOTTOMRIGHT", topViewer, "TOPRIGHT", targetX, baseTY)
                f:SetHeight(finalH)
            else
                local targetY = CR.PixelSnap(item.yOff)
                f:SetPoint("CENTER", self.baseAnchor.mover or self.baseAnchor, "CENTER", targetX, targetY)
                f:SetSize(CR.PixelSnap(targetWidth), finalH)
            end
        else
            local stackGap = CR.PixelSnap(globalSpacing + item.yOff)
            f:SetPoint("BOTTOMLEFT", self.lastStackedFrame, "TOPLEFT", targetX, stackGap)
            f:SetPoint("BOTTOMRIGHT", self.lastStackedFrame, "TOPRIGHT", targetX, stackGap)
            f:SetHeight(finalH)
        end
        self.lastStackedFrame = f
    end
end

function CR:GetTopStackedFrame() return self.lastStackedFrame or self:GetTopVisibleCDViewer() end

function CR:IsSkyridingCapableState()
    if IsMounted() then return true end
    if playerClass == "DRUID" then local form = GetShapeshiftFormID(); if form == 3 or form == 27 or form == 29 then return true end end
    if playerClass == "EVOKER" then if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then if C_UnitAuras.GetPlayerAuraBySpellID(369536) then return true end end end
    return false
end

function CR:CheckVigorState()
    local isSkyriding = false
    if self:IsSkyridingCapableState() then
        local isSteadyFlight = false
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            if C_UnitAuras.GetPlayerAuraBySpellID(404468) then
                isSteadyFlight = true
            end
        end
        
        if not isSteadyFlight then
            local isUsable = false
            if C_Spell and C_Spell.IsSpellUsable then
                local usable, noMana = C_Spell.IsSpellUsable(CR.SPELL_CONSTANTS.SKYRIDING_SURGE)
                isUsable = usable or noMana
            elseif IsUsableSpell then
                local usable, noMana = IsUsableSpell(CR.SPELL_CONSTANTS.SKYRIDING_SURGE)
                isUsable = usable or noMana
            end

            if isUsable then
                local chInfo = C_Spell.GetSpellCharges(CR.SPELL_CONSTANTS.SKYRIDING_SURGE)
                if chInfo then
                    local rawMax = chInfo.maxCharges
                    if not CR.IsSecret(rawMax) and rawMax > 0 then 
                        isSkyriding = true 
                    end
                end
            end
        end
    end
    
    if self.isVigorActive ~= isSkyriding then
        self.isVigorActive = isSkyriding
        self:UpdateLayout()
        if WF.WishMonitorAPI and WF.WishMonitorAPI.TriggerUpdate then 
            WF.WishMonitorAPI:TriggerUpdate() 
        end
    end
end

function CR:TriggerVigorCheck()
    self:CheckVigorState()
    C_Timer.After(0.2, function() self:CheckVigorState() end)
    C_Timer.After(0.6, function() self:CheckVigorState() end)
    C_Timer.After(1.5, function() self:CheckVigorState() end)
end

function CR:ApplyBarGraphics(bar, barCfg, db)
    if not bar or not bar.statusBar or not barCfg then return end
    
    local globalTex = (type(db.texture) == "string" and db.texture ~= "") and db.texture or "Wish2"
    local finalTexture = globalTex
    if barCfg.useCustomTexture and type(barCfg.texture) == "string" and barCfg.texture ~= "" then
        finalTexture = barCfg.texture
    end

    local finalBgTexture = finalTexture 
    if barCfg.useCustomBgTexture and type(barCfg.bgTexture) == "string" and barCfg.bgTexture ~= "" then
        finalBgTexture = barCfg.bgTexture
    end

    local globalBg = db.globalBgColor or {r=0, g=0, b=0, a=0.5}
    local bgc = globalBg
    if barCfg.useCustomBgColor and type(barCfg.bgColor) == "table" then
        bgc = barCfg.bgColor
    end

    local hash = finalTexture .. "_" .. finalBgTexture .. "_" .. (bgc.r or 0) .. "_" .. (bgc.g or 0) .. "_" .. (bgc.b or 0) .. "_" .. (bgc.a or 0.5)
    if bar._graphicsHash == hash then return end
    bar._graphicsHash = hash

    local texPath = LSM:Fetch("statusbar", finalTexture) or "Interface\\TargetingFrame\\UI-StatusBar"
    bar.statusBar:SetStatusBarTexture(texPath)

    if bar.statusBar:GetStatusBarTexture() then
        bar.statusBar:GetStatusBarTexture():SetTexture(texPath)
        bar.statusBar:GetStatusBarTexture():SetHorizTile(false)
        bar.statusBar:GetStatusBarTexture():SetVertTile(false)
    end
    
    if bar.statusBar.bg then
        local bgTexPath = LSM:Fetch("statusbar", finalBgTexture) or "Interface\\TargetingFrame\\UI-StatusBar"
        bar.statusBar.bg:SetTexture(bgTexPath)
        bar.statusBar.bg:SetVertexColor(bgc.r or 0, bgc.g or 0, bgc.b or 0, bgc.a or 0.5)
    end
end

function CR:UpdateDividers(bar, maxVal)
    bar.dividers = bar.dividers or {}
    local numMax = (CR.IsSecret(maxVal) and 1) or (tonumber(maxVal) or 1)
    if numMax <= 0 then numMax = 1 end; if numMax > 20 then numMax = 20 end 
    local width = bar.gridFrame:GetWidth() or 250
    if bar._lastDividerMax == numMax and bar._lastDividerWidth == width then return end
    bar._lastDividerMax = numMax; bar._lastDividerWidth = width
    local numDividers = numMax > 1 and (numMax - 1) or 0
    local segWidth = width / numMax
    local targetFrame = bar.gridFrame
    
    local pSize = CR.GetOnePixelSize()
    for i = 1, numDividers do
        if not bar.dividers[i] then 
            local tex = targetFrame:CreateTexture(nil, "OVERLAY", nil, 7); tex:SetColorTexture(0, 0, 0, 1); bar.dividers[i] = tex 
        end
        bar.dividers[i]:SetWidth(pSize); local offset = CR.PixelSnap(segWidth * i)
        bar.dividers[i]:ClearAllPoints()
        bar.dividers[i]:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", offset, 0)
        bar.dividers[i]:SetPoint("BOTTOMLEFT", targetFrame, "BOTTOMLEFT", offset, 0)
        bar.dividers[i]:Show()
    end
    for i = numDividers + 1, #bar.dividers do if bar.dividers[i] then bar.dividers[i]:Hide() end end

    if bar == self.powerBar and self.cachedSpecCfg and self.cachedSpecCfg.power and self.cachedSpecCfg.power.thresholdLines then
        if not bar.thresholdLines then bar.thresholdLines = {} end
        local activeLines = 0
        for lineIdx = 1, 5 do
            local tLineCfg = self.cachedSpecCfg.power.thresholdLines[lineIdx]
            if type(tLineCfg) == "table" and tLineCfg.enable and (tonumber(tLineCfg.value) or 0) > 0 then
                activeLines = activeLines + 1; local tLine = bar.thresholdLines[activeLines]
                if not tLine then tLine = bar.statusBar:CreateTexture(nil, "OVERLAY", nil, 7); bar.thresholdLines[activeLines] = tLine end
                local lineVal = tonumber(tLineCfg.value) or 0; local realMax = UnitPowerMax("player", UnitPowerType("player"))
                if not realMax or realMax <= 0 then realMax = 100 end; local pct = lineVal / realMax; if pct > 1 then pct = 1 end
                local posX = pct * width
                local tColor = type(tLineCfg.color) == "table" and tLineCfg.color or DEF_DIVIDER_COLOR
                local tThick = tonumber(tLineCfg.thickness) or 2
                tLine:SetColorTexture(tColor.r or 1, tColor.g or 1, tColor.b or 1, tColor.a or 1); tLine:SetWidth(tThick); tLine:ClearAllPoints(); tLine:SetPoint("TOPLEFT", bar.statusBar, "TOPLEFT", posX - (tThick/2), 0); tLine:SetPoint("BOTTOMLEFT", bar.statusBar, "BOTTOMLEFT", posX - (tThick/2), 0); tLine:Show()
            end
        end
        for idx = activeLines + 1, #(bar.thresholdLines or {}) do if bar.thresholdLines[idx] then bar.thresholdLines[idx]:Hide() end end
    end
end

function CR:UpdateMonitorDividers(f, numMax, width)
    local parentFrame = f.chargeBar or f
    f.dividerFrame = f.dividerFrame or CreateFrame("Frame", nil, parentFrame)
    f.dividerFrame:SetParent(parentFrame); f.dividerFrame:ClearAllPoints(); f.dividerFrame:SetAllPoints(parentFrame); f.dividerFrame:SetFrameLevel(parentFrame:GetFrameLevel() + 15)
    f.dividers = f.dividers or {}
    local pixelSize = CR.GetOnePixelSize()
    if f.cfg and f.cfg.displayMode == "text" then numMax = 1 end
    
    numMax = tonumber(numMax) or 1
    if numMax <= 1 then for _, d in ipairs(f.dividers) do d:Hide() end; return end 
    local exactSeg = width / numMax
    for i = 1, numMax - 1 do
        if not f.dividers[i] then local tex = f.dividerFrame:CreateTexture(nil, "OVERLAY", nil, 7); tex:SetColorTexture(0, 0, 0, 1); f.dividers[i] = tex end
        f.dividers[i]:SetWidth(pixelSize); local offset = CR.PixelSnap(exactSeg * i)
        f.dividers[i]:ClearAllPoints(); f.dividers[i]:SetPoint("TOPLEFT", f.dividerFrame, "TOPLEFT", offset, 0); f.dividers[i]:SetPoint("BOTTOMLEFT", f.dividerFrame, "BOTTOMLEFT", offset, 0); f.dividers[i]:Show()
    end
    for i = numMax, #f.dividers do if f.dividers[i] then f.dividers[i]:Hide() end end
end

function CR:UpdateVigorPulse(bar, currentVigor, maxVigor, recoveryWindCharges)
    if not bar.windHighlights then bar.windHighlights = {} end
    local width = bar.gridFrame:GetWidth() or 250
    local mV = (maxVigor and maxVigor > 0) and maxVigor or 6
    local cellWidth = width / mV
    local fullCharges = math_floor(tonumber(currentVigor) or 0)
    
    for i = 1, 6 do
        if not bar.windHighlights[i] then local hl = bar.statusBar:CreateTexture(nil, "BACKGROUND", nil, 2); hl:SetColorTexture(0.4, 0.8, 1, 0.35); bar.windHighlights[i] = hl end
        local hl = bar.windHighlights[i]
        if UnitLevel("player") >= 20 and not CR.IsSecret(recoveryWindCharges) and (recoveryWindCharges or 0) > 0 and i > fullCharges and (i - fullCharges) <= recoveryWindCharges and i <= mV then
            hl:ClearAllPoints(); hl:SetPoint("TOPLEFT", bar.statusBar, "TOPLEFT", (i - 1) * cellWidth, 0); hl:SetPoint("BOTTOMLEFT", bar.statusBar, "BOTTOMLEFT", (i - 1) * cellWidth, 0); hl:SetWidth(cellWidth); hl:Show()
        else hl:Hide() end
    end
end

function CR:FormatSafeText(bar, textCfg, current, maxVal, isTime, pType, showText, durObj, barKey)
    if not bar.text or not bar.timerText then return end
    local fontPath = LSM:Fetch("font", CR.GetDB().font or "Expressway") or STANDARD_TEXT_FONT
    local fontSize = tonumber(textCfg.fontSize) or 12; if fontSize < 1 then fontSize = 1 end
    local fontOutline = textCfg.outline or "OUTLINE"
    
    if bar._lastFont ~= fontPath or bar._lastSize ~= fontSize or bar._lastOutline ~= fontOutline then
        bar.text:SetFont(fontPath, fontSize, fontOutline); bar.timerText:SetFont(fontPath, fontSize, fontOutline)
        if bar.cdText then bar.cdText:SetFont(fontPath, math_max(1, fontSize - 2), fontOutline); bar.cdText:SetTextColor(1, 0.82, 0); bar.cdText:ClearAllPoints(); bar.cdText:SetPoint("RIGHT", bar.textFrame, "RIGHT", -4, 0) end
        bar._lastFont = fontPath; bar._lastSize = fontSize; bar._lastOutline = fontOutline
    end
    
    local c = textCfg.color or DEF_TEXT_COLOR
    if bar._lastColorR ~= c.r or bar._lastColorG ~= c.g or bar._lastColorB ~= c.b then bar.text:SetTextColor(c.r, c.g, c.b); bar.timerText:SetTextColor(c.r, c.g, c.b); bar._lastColorR = c.r; bar._lastColorG = c.g; bar._lastColorB = c.b end
    
    local mainAnchor = textCfg.textAnchor or "CENTER"; local timerAnchor = textCfg.timerAnchor or "CENTER"

    if bar._lastMainAnchor ~= mainAnchor or bar._lastXOff ~= textCfg.xOffset or bar._lastYOff ~= textCfg.yOffset then
        bar.text:ClearAllPoints(); bar.text:SetPoint(mainAnchor, bar.textFrame, mainAnchor, tonumber(textCfg.xOffset) or 0, tonumber(textCfg.yOffset) or 0); bar.text:SetJustifyH(CR.GetSafeJustify(mainAnchor))
        bar._lastMainAnchor = mainAnchor; bar._lastXOff = textCfg.xOffset; bar._lastYOff = textCfg.yOffset
    end
    if bar._lastTimerAnchor ~= timerAnchor or bar._lastTXOff ~= textCfg.timerXOffset or bar._lastTYOff ~= textCfg.timerYOffset then
        bar.timerText:ClearAllPoints(); bar.timerText:SetPoint(timerAnchor, bar.textFrame, timerAnchor, tonumber(textCfg.timerXOffset) or 0, tonumber(textCfg.timerYOffset) or 0); bar.timerText:SetJustifyH(CR.GetSafeJustify(timerAnchor))
        bar._lastTimerAnchor = timerAnchor; bar._lastTXOff = textCfg.timerXOffset; bar._lastTYOff = textCfg.timerYOffset
    end

    local newMainText = ""; local newTimerText = ""

    if durObj and type(current) == "number" then
        local remain = nil
        if type(durObj.GetRemainingDuration) == "function" then remain = durObj:GetRemainingDuration() 
        elseif durObj.expirationTime then remain = durObj.expirationTime - GetTime() end
        if remain then if showText ~= false then newMainText = CR.IsSecret(current) and current or string_format("%d", current) end; if textCfg.timerEnable ~= false then newTimerText = CR.GetDurationTextSafe(remain) end end
    else
        if showText ~= false then
            if pType == 0 then local scale = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or 100; local perc = UnitPowerPercent("player", pType, false, scale); newMainText = string_format("%d", tonumber(perc) or 0)
            elseif CR.IsSecret(current) or CR.IsSecret(maxVal) then newMainText = current
            else if isTime then newMainText = CR.GetDurationTextSafe(current) else newMainText = CR.SafeFormatNum(current) end end
        end
    end

    local isConfigOpen = false
    if WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown() then isConfigOpen = true end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then isConfigOpen = true end

    if showText == false then
        if isConfigOpen and CR.Sandbox and CR.Sandbox.popupTarget == barKey then bar.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); bar.text:SetText("[文本已隐藏]"); bar.text:SetAlpha(0.3); bar.text:Show(); bar._isMainShown = true
        else bar.text:Hide(); bar._isMainShown = false end
    else
        bar.text:SetAlpha(1)
        if CR.IsSecret(newMainText) then pcall(bar.text.SetText, bar.text, newMainText); bar._lastMainString = nil
        else if type(bar._lastMainString) ~= "string" or bar._lastMainString ~= newMainText then bar.text:SetText(newMainText); bar._lastMainString = newMainText end end
        if not bar._isMainShown then bar.text:Show(); bar._isMainShown = true end
    end

    if textCfg.timerEnable ~= false then
        if CR.IsSecret(newTimerText) then pcall(bar.timerText.SetText, bar.timerText, newTimerText); bar._lastTimerString = nil
        else if type(bar._lastTimerString) ~= "string" or bar._lastTimerString ~= newTimerText then bar.timerText:SetText(newTimerText); bar._lastTimerString = newTimerText end end
        if not bar._isTimerShown then bar.timerText:Show(); bar._isTimerShown = true end
    else if bar._isTimerShown then bar.timerText:Hide(); bar._isTimerShown = false end end
end

function CR:UpdateLayout()
    if self.isRendering then return end
    self.isRendering = true
    
    local db = CR.GetDB(); local currentContextID = CR.GetCurrentContextID(); local specCfg = CR.GetCurrentSpecConfig(currentContextID)
    self.cachedSpecCfg = specCfg

    if self.isVigorActive and specCfg.vigor and specCfg.showVigor then
        self.showPower = false; self.showClass = false; self.showMana = false; self.showVigor = true
    else
        self.showVigor = false
        local pType = UnitPowerType("player")
        local _, _, _, sMax = CR.GetSafePower(pType)
        self.showPower = specCfg.power and (sMax > 0) and specCfg.showPower
        
        local _, _, _, cMax = CR.GetSafeClassResource()
        self.showClass = specCfg.class and (cMax > 0) and specCfg.showClass
        
        local _, _, _, mMax = CR.GetSafeMana()
        self.showMana = hasHealerSpec and specCfg.mana and (mMax > 0) and specCfg.showMana
    end
    self.showWhirling = self.isVigorActive and specCfg.whirling and specCfg.showWhirling

    self:DoStackLayout()
    self:DynamicTick()
    self.isRendering = false
end

function CR.GetVigorSmooth()
    local cc, mc = CR._vigorCache.cc, CR._vigorCache.mc
    local st, dur = CR._vigorCache.st, CR._vigorCache.dur
    
    if not CR.IsSecret(cc) and not CR.IsSecret(mc) and cc < mc then
        if dur and st and dur > 0 then 
            local p = (GetTime() - st) / dur
            if p > 0 and p < 1 then cc = cc + p end 
        end
    end
    return cc, mc
end

function CR:DynamicTick()
    if not self.baseAnchor then return end
    local specCfg = self.cachedSpecCfg or CR.GetCurrentSpecConfig(CR.GetCurrentContextID()); if not specCfg then return end
    self.hasActiveTimer = false
    
    local isConfigOpen = false
    if WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown() then isConfigOpen = true end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then isConfigOpen = true end

    local db = CR.GetDB()
    if self.ApplyBarGraphics then
        self:ApplyBarGraphics(self.powerBar, specCfg.power, db)
        self:ApplyBarGraphics(self.classBar, specCfg.class, db)
        self:ApplyBarGraphics(self.manaBar, specCfg.mana, db)
        self:ApplyBarGraphics(self.vigorBar, specCfg.vigor, db)
        self:ApplyBarGraphics(self.whirlingBar, specCfg.whirling, db)
    end

    if self.vigorBar and self.vigorBar.text then self.vigorBar.text:Hide() end
    if self.vigorBar and self.vigorBar.timerText then self.vigorBar.timerText:Hide() end
    if self.whirlingBar and self.whirlingBar.text then self.whirlingBar.text:Hide() end
    if self.whirlingBar and self.whirlingBar.timerText then self.whirlingBar.timerText:Hide() end
    if self.classBar and self.classBar.text then self.classBar.text:Hide() end
    if self.classBar and self.classBar.timerText then self.classBar.timerText:Hide() end

    if (self.showVigor or (isConfigOpen and CR.Sandbox and CR.Sandbox.popupTarget == "vigor")) and specCfg.vigor then
        local rawCurr, rawMax = CR.GetVigorSmooth()
        if not CR.IsSecret(rawMax) and rawMax <= 0 then rawMax = 6 end
        
        if CR.IsSecret(rawCurr) or CR.IsSecret(rawMax) then self.hasActiveTimer = true
        elseif rawCurr < rawMax then self.hasActiveTimer = true end
        
        local vColor = CR.GetSafeColor(specCfg.vigor, DEF_VIGOR_COLOR, false)
        CR.UpdateBarValueSafe(self.vigorBar.statusBar, rawCurr, rawMax); self.vigorBar.statusBar:SetStatusBarColor(vColor.r, vColor.g, vColor.b)
        if self.UpdateDividers then self:UpdateDividers(self.vigorBar, rawMax) end
        local windCharges = CR._windCache
        if self.UpdateVigorPulse then self:UpdateVigorPulse(self.vigorBar, rawCurr, rawMax, windCharges) end
    end

    if (self.showWhirling or (isConfigOpen and CR.Sandbox and CR.Sandbox.popupTarget == "whirling")) and specCfg.whirling then
        local rawCurr, rawMax = 1, 1
        local st, dur = CR._whirlingCache.st, CR._whirlingCache.dur
        if not CR.IsSecret(dur) and dur > 1.5 then
            rawMax = dur
            local remain = (st + dur) - GetTime()
            if remain > 0 then rawCurr = rawMax - remain else rawCurr = rawMax end
        end
        
        if CR.IsSecret(rawCurr) or CR.IsSecret(rawMax) then self.hasActiveTimer = true
        elseif rawCurr < rawMax then self.hasActiveTimer = true end
        
        local wColor = CR.GetSafeColor(specCfg.whirling, DEF_WHIRLING_COLOR, false)
        CR.UpdateBarValueSafe(self.whirlingBar.statusBar, rawCurr, rawMax); self.whirlingBar.statusBar:SetStatusBarColor(wColor.r, wColor.g, wColor.b)
        if self.UpdateDividers then self:UpdateDividers(self.whirlingBar, 1) end
    end

    if (self.showPower or (isConfigOpen and CR.Sandbox and CR.Sandbox.popupTarget == "power")) and specCfg.power then
        local pType = UnitPowerType("player")
        local rawCurr, rawMax, safeCurr, safeMax = CR.GetSafePower(pType)
        if safeMax <= 0 then safeMax = 1 end
        if safeCurr < safeMax then self.hasActiveTimer = true end
        
        local pColor = CR.GetSafeColor(specCfg.power, CR.GetPowerColor(pType), false)
        
        local tPType = specCfg.power.thresholdPowerType
        local applyThresholds = (not tPType or tPType == "ALL" or tonumber(tPType) == pType)
        
        if specCfg.power.enableThreshold and applyThresholds then
            pColor = CR.GetSecretThresholdColor(pType, rawMax, pColor, specCfg)
        end

        CR.UpdateBarValueSafe(self.powerBar.statusBar, rawCurr, rawMax)
        self.powerBar.statusBar:SetStatusBarColor(pColor.r, pColor.g, pColor.b)

        if specCfg.power.thresholdLines and applyThresholds then
            if not self.powerBar.thresholdLines then self.powerBar.thresholdLines = {} end
            local activeLines = 0
            for lineIdx = 1, 5 do
                local tLineCfg = specCfg.power.thresholdLines[lineIdx]
                if type(tLineCfg) == "table" and tLineCfg.enable and (tonumber(tLineCfg.value) or 0) > 0 then
                    activeLines = activeLines + 1
                    local tLine = self.powerBar.thresholdLines[activeLines]
                    if not tLine then 
                        tLine = self.powerBar.statusBar:CreateTexture(nil, "OVERLAY", nil, 7)
                        self.powerBar.thresholdLines[activeLines] = tLine 
                    end
                    local lineVal = tonumber(tLineCfg.value) or 0
                    local pct = lineVal / safeMax
                    if pct > 1 then pct = 1 end
                    local posX = pct * self:GetActiveWidth()
                    local tColor = type(tLineCfg.color) == "table" and tLineCfg.color or {r=1,g=1,b=1,a=1}
                    local tThick = tonumber(tLineCfg.thickness) or 2
                    tLine:SetColorTexture(tColor.r or 1, tColor.g or 1, tColor.b or 1, tColor.a or 1)
                    tLine:SetWidth(tThick)
                    tLine:ClearAllPoints()
                    tLine:SetPoint("TOPLEFT", self.powerBar.statusBar, "TOPLEFT", posX - (tThick/2), 0)
                    tLine:SetPoint("BOTTOMLEFT", self.powerBar.statusBar, "BOTTOMLEFT", posX - (tThick/2), 0)
                    tLine:Show()
                end
            end
            for idx = activeLines + 1, #(self.powerBar.thresholdLines or {}) do
                if self.powerBar.thresholdLines[idx] then self.powerBar.thresholdLines[idx]:Hide() end
            end
        elseif self.powerBar.thresholdLines then
            for _, tl in ipairs(self.powerBar.thresholdLines) do tl:Hide() end
        end

        if self.UpdateDividers then self:UpdateDividers(self.powerBar, 1) end
        
        if self.FormatSafeText then 
            local displayCurr = CR.IsSecret(rawCurr) and rawCurr or math_floor(safeCurr)
            self:FormatSafeText(self.powerBar, specCfg.power, displayCurr, rawMax, false, pType, specCfg.power.textEnable ~= false, nil, "power") 
        end
    end

    if (self.showClass or (isConfigOpen and CR.Sandbox and CR.Sandbox.popupTarget == "class")) and specCfg.class then
        local rawCurr, rawMax, safeCurr, safeMax, cDefColor, safeExtra = CR.GetSafeClassResource()
        if safeMax <= 0 then safeMax = 1 end

        if playerClass == "EVOKER" then
            if not CR.evokerEssence then CR.evokerEssence = { count = safeCurr, partial = 0, lastTick = GetTime() } end
            local now = GetTime()
            local elapsed = now - CR.evokerEssence.lastTick
            CR.evokerEssence.lastTick = now
            
            if safeCurr > CR.evokerEssence.count then CR.evokerEssence.partial = 0 end
            CR.evokerEssence.count = safeCurr
            
            if safeCurr < safeMax then
                local activeRegen = 0.2
                if GetPowerRegenForPowerType then local _, act = GetPowerRegenForPowerType(19); if type(act)=="number" then activeRegen = act end end
                CR.evokerEssence.partial = CR.evokerEssence.partial + (activeRegen * elapsed)
                if CR.evokerEssence.partial >= 1 then CR.evokerEssence.partial = 0.99 end
            else
                CR.evokerEssence.partial = 0
            end
            rawCurr = rawCurr + CR.evokerEssence.partial
            safeCurr = safeCurr + CR.evokerEssence.partial
        elseif playerClass == "DEATHKNIGHT" then
            local readyRunes = 0; local highestPartial = 0
            for i=1, 6 do
                local start, duration, runeReady = GetRuneCooldown(i)
                if runeReady then readyRunes = readyRunes + 1
                elseif type(start)=="number" and type(duration)=="number" and start > 0 and duration > 0 then
                    local partial = math.max(0, math.min(0.99, (GetTime() - start) / duration))
                    if partial > highestPartial then highestPartial = partial end
                end
            end
            rawCurr = readyRunes + highestPartial
            safeCurr = rawCurr
        end

        if safeCurr < safeMax then 
            if playerClass ~= "WARLOCK" and playerClass ~= "ROGUE" and playerClass ~= "PALADIN" and playerClass ~= "MONK" then
                self.hasActiveTimer = true 
            end
        end
        
        local cColor = CR.GetSafeColor(specCfg.class, cDefColor, true)
        CR.UpdateBarValueSafe(self.classBar.statusBar, rawCurr, rawMax); self.classBar.statusBar:SetStatusBarColor(cColor.r, cColor.g, cColor.b)
        if self.UpdateDividers then self:UpdateDividers(self.classBar, rawMax) end
        
        if self.FormatSafeText then self:FormatSafeText(self.classBar, specCfg.class, math_floor(safeCurr), rawMax, false, 0, specCfg.class.textEnable ~= false, nil, "class") end
        
        local isBrewmaster = (playerClass == "MONK" and GetSpecializationInfo(GetSpecialization() or 1) == 268)
        if isBrewmaster and self.classBar.text then
            if isConfigOpen then
                self.classBar.text:Show()
                self.classBar.text:SetText("醉拳: 500k (50.0%)")
            elseif safeExtra > 0 then
                self.classBar.text:Show()
                local maxHealth = UnitHealthMax("player")
                if not CR.IsSecret(maxHealth) then
                    if maxHealth <= 0 then maxHealth = 1 end
                    local pct = (safeExtra / maxHealth) * 100
                    local stText = CR.SafeFormatNum(safeExtra)
                    self.classBar.text:SetText(string.format("%s | %.1f%%", stText, pct))
                end
            else
                self.classBar.text:Hide()
            end
        end
    end
    
    if hasHealerSpec and (self.showMana or (isConfigOpen and CR.Sandbox and CR.Sandbox.popupTarget == "mana")) and specCfg.mana then
        local rawCurr, rawMax, safeCurr, safeMax = CR.GetSafeMana()
        if safeMax <= 0 then safeMax = 1 end
        
        if safeCurr < safeMax then self.hasActiveTimer = true end

        local mColor = CR.GetSafeColor(specCfg.mana, POWER_COLORS[0], false)
        CR.UpdateBarValueSafe(self.manaBar.statusBar, rawCurr, rawMax); self.manaBar.statusBar:SetStatusBarColor(mColor.r, mColor.g, mColor.b)
        if self.UpdateDividers then self:UpdateDividers(self.manaBar, 1) end
        if self.FormatSafeText then self:FormatSafeText(self.manaBar, specCfg.mana, math_floor(safeCurr), rawMax, false, 0, specCfg.mana.textEnable ~= false, nil, "mana") end
    end
end

function CR:CreateAnchor(name, title, defaultY, height)
    local anchor = CreateFrame("Frame", name, UIParent)
    anchor:SetPoint("CENTER", UIParent, "CENTER", 0, defaultY); anchor:SetSize(250, height)
    if WF.CreateMover then WF:CreateMover(anchor, name.."Mover", {"CENTER", UIParent, "CENTER", 0, defaultY}, 250, height, title) end
    local moverName = name.."Mover"; local mover = _G[moverName]
    if mover then
        if WF.db.movers and WF.db.movers[moverName] then local p = WF.db.movers[moverName]; mover:ClearAllPoints(); mover:SetPoint(p.point, UIParent, p.relativePoint, p.xOfs, p.yOfs) end
        if not mover._wishSaveHooked then mover:HookScript("OnDragStop", function(self) if not WF.db.movers then WF.db.movers = {} end; local point, _, relativePoint, xOfs, yOfs = self:GetPoint(); WF.db.movers[self:GetName()] = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs } end); mover._wishSaveHooked = true end
    end
    return anchor
end

function CR:OnContextChanged()
    self.selectedSpecForConfig = CR.GetCurrentContextID()
    self.cachedSpecCfg = CR.GetCurrentSpecConfig(self.selectedSpecForConfig)
    self:UpdateLayout()
end

function CR:GoToSleep()
    if self.sleepMode then return end
    if self.isVigorActive then return end

    local isConfigOpen = false
    if WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown() then isConfigOpen = true end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then isConfigOpen = true end
    if isConfigOpen then return end 

    self.sleepMode = true; self.baseAnchor:SetScript("OnUpdate", nil)

    local db = CR.GetDB()
    if db.fadeOOC ~= false then
        local alpha = tonumber(db.fadeAlpha) or 0
        for i = 1, #self.AllBars do
            local bar = self.AllBars[i]
            if self.isVigorActive and (bar == self.vigorBar or bar == self.whirlingBar) then bar:SetAlpha(1)
            else bar:SetAlpha(alpha); if alpha <= 0 then if bar and bar.text then bar.text:SetAlpha(0) end; if bar and bar.timerText then bar.timerText:SetAlpha(0) end end end
        end
    end
end

function CR:WakeUp()
    self.idleTimer = 0
    if self.sleepMode then
        self.sleepMode = false; self.baseAnchor:SetScript("OnUpdate", self.ResourceOnUpdate)
        for i = 1, #self.AllBars do
            local bar = self.AllBars[i]; bar:SetAlpha(1)
            if not bar.isForceHidden then bar:Show(); if bar.text then bar.text:SetAlpha(1) end; if bar.timerText then bar.timerText:SetAlpha(1) end end
        end
        self:DynamicTick()
    end
end

function CR:CreateBarContainer(name, parent)
    local bar = _G[name] or CreateFrame("Frame", name, parent)
    if not bar.statusBar then
        local sb = CreateFrame("StatusBar", nil, bar); sb:SetAllPoints(bar); bar.statusBar = sb
        local sbBg = sb:CreateTexture(nil, "BACKGROUND", nil, -1); sbBg:SetAllPoints(); sb.bg = sbBg
        local bd = CreateFrame("Frame", nil, bar); bd:SetAllPoints(bar); bd:SetFrameLevel(sb:GetFrameLevel() + 2)
        local m = CR.GetOnePixelSize()
        local function DrawEdge(p1, p2, x, y, w, h)
            local t = bd:CreateTexture(nil, "OVERLAY"); t:SetColorTexture(0, 0, 0, 1)
            t:SetPoint(p1, bd, p1, x, y); t:SetPoint(p2, bd, p2, x, y)
            if w then t:SetWidth(m) end; if h then t:SetHeight(m) end
            return t
        end
        bd.top = DrawEdge("TOPLEFT", "TOPRIGHT", 0, 0, nil, 1); bd.bottom = DrawEdge("BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, nil, 1)
        bd.left = DrawEdge("TOPLEFT", "BOTTOMLEFT", 0, 0, 1, nil); bd.right = DrawEdge("TOPRIGHT", "BOTTOMRIGHT", 0, 0, 1, nil)
        bar.bdFrame = bd
    end
    if not bar.gridFrame then
        local gridFrame = CreateFrame("Frame", nil, bar); gridFrame:SetAllPoints(bar.statusBar); gridFrame:SetFrameLevel(bar.statusBar:GetFrameLevel() + 5); bar.gridFrame = gridFrame
    end
    if not bar.textFrame then
        local textFrame = CreateFrame("Frame", nil, bar); textFrame:SetAllPoints(bar); textFrame:SetFrameLevel(bar.statusBar:GetFrameLevel() + 10); bar.textFrame = textFrame
        bar.text = textFrame:CreateFontString(nil, "OVERLAY"); bar.timerText = textFrame:CreateFontString(nil, "OVERLAY") 
    end
    return bar
end

local function InitClassResource()
    CR.GetDB()
    CR.baseAnchor = CR:CreateAnchor("WishFlex_BaseAnchor", "WishFlex: " .. (L["Global Layout Anchor"] or "全局排版起点"), -180, 10)
    CR.manaAnchor = CR:CreateAnchor("WishFlex_ManaAnchor", "WishFlex: [独立] " .. (L["Extra Mana Bar"] or "专属法力条"), -220, 10)
    CR.powerAnchor = CR:CreateAnchor("WishFlex_PowerAnchor", "WishFlex: [独立] " .. (L["Power Bar"] or "能量条"), -160, 10)
    CR.classAnchor = CR:CreateAnchor("WishFlex_ClassAnchor", "WishFlex: [独立] " .. (L["Class Resource Bar"] or "主资源条"), -140, 10)
    CR.vigorAnchor = CR:CreateAnchor("WishFlex_VigorAnchor", "WishFlex: [独立] " .. (L["Vigor Bar"] or "驭空术资源条"), -150, 10)
    CR.whirlingAnchor = CR:CreateAnchor("WishFlex_WhirlingAnchor", "WishFlex: [独立] " .. (L["Whirling Surge Bar"] or "回旋冲刺条"), -145, 4)

    CR.powerBar = CR:CreateBarContainer("WishFlex_PowerBar", UIParent)
    CR.classBar = CR:CreateBarContainer("WishFlex_ClassBar", UIParent)
    CR.manaBar = CR:CreateBarContainer("WishFlex_ManaBar", UIParent)
    CR.vigorBar = CR:CreateBarContainer("WishFlex_VigorBar", UIParent)
    CR.whirlingBar = CR:CreateBarContainer("WishFlex_WhirlingBar", UIParent)
    
    CR.AllBars = {CR.powerBar, CR.classBar, CR.manaBar, CR.vigorBar, CR.whirlingBar}
    CR.showPower, CR.showClass, CR.showMana, CR.showVigor, CR.showWhirling = false, false, false, false, false
    CR.isRendering = false; CR.idleTimer = 0; CR.sleepMode = false
    
    if not WF.db.classResource.enable then for i = 1, #CR.AllBars do if CR.AllBars[i] then CR.AllBars[i]:Hide() end end end
    
    if WF.RegisterEvent then
        WF:RegisterEvent("PLAYER_ENTERING_WORLD", function() CR:WakeUp(); CR:UpdateLayout(); CR:TriggerVigorCheck() end)
        WF:RegisterEvent("UNIT_DISPLAYPOWER", function() CR:WakeUp(); CR:UpdateLayout() end)
        WF:RegisterEvent("UNIT_MAXPOWER", function() CR:WakeUp(); CR:UpdateLayout() end)
        WF:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() CR:WakeUp(); CR:OnContextChanged() end)
        WF:RegisterEvent("PLAYER_REGEN_DISABLED", function() CR:WakeUp() end)
        WF:RegisterEvent("PLAYER_TARGET_CHANGED", function() CR:WakeUp() end)
        WF:RegisterEvent("UNIT_POWER_UPDATE", function(e, unit) if unit == "player" then CR:WakeUp() end end)
        WF:RegisterEvent("UNIT_POWER_FREQUENT", function(e, unit) if unit == "player" then CR:WakeUp() end end)
        WF:RegisterEvent("SPELL_UPDATE_CHARGES", function() CR:UpdateFlightCaches(); CR:CheckVigorState(); CR:WakeUp() end)
        WF:RegisterEvent("SPELL_UPDATE_COOLDOWN", function() CR:UpdateFlightCaches(); CR:CheckVigorState(); CR:WakeUp() end)
        WF:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", function() CR:TriggerVigorCheck(); CR:WakeUp() end)
        
        if playerClass == "DRUID" then 
            WF:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function() CR:TriggerVigorCheck(); CR:WakeUp() end)
        elseif playerClass == "EVOKER" then 
            WF:RegisterEvent("UNIT_AURA", function(e, unit) if unit == "player" then CR:TriggerVigorCheck(); CR:WakeUp() end end) 
        end
    end

    C_Timer.After(0.8, function() CR:UpdateLayout() end); CR:OnContextChanged()
    
    local ticker = 0; CR.frameTick = 0
    local function SmoothBar(bar, elapsed)
        local isMoving = false
        if bar and bar.statusBar and not bar.isForceHidden then
            local sb = bar.statusBar
            if CR.IsSecret(sb._targetValue) then
                sb._currentValue = sb._targetValue
                sb:SetValue(sb._targetValue)
            else
                local target = sb._targetValue or 0
                local current = sb._currentValue or sb:GetValue() or 0
                local diff = target - current
                if math_abs(diff) < 0.01 then 
                    sb._currentValue = target 
                else 
                    sb._currentValue = current + diff * 15 * elapsed
                    isMoving = true 
                end
                sb:SetValue(sb._currentValue)
            end
        end
        return isMoving 
    end

    CR.ResourceOnUpdate = function(_, elapsed)
        local isConfigOpen = false
        if WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown() then isConfigOpen = true end
        if EditModeManagerFrame and EditModeManagerFrame:IsShown() then isConfigOpen = true end
        
        CR.frameTick = (CR.frameTick or 0) + 1; local isAnimating = false
        for i = 1, #CR.AllBars do if SmoothBar(CR.AllBars[i], elapsed) then isAnimating = true end end
        
        ticker = ticker + elapsed
        local interval = InCombatLockdown() and 0.05 or 0.15
        if ticker >= interval then 
            ticker = 0; CR:DynamicTick()
            local hasActiveMonitors = (CR.ActiveMonitorFrames and #CR.ActiveMonitorFrames > 0)
            
            if not InCombatLockdown() and not isConfigOpen and not UnitExists("target") and not CR.hasActiveTimer and not isAnimating and not hasActiveMonitors and not CR.isVigorActive then 
                CR.idleTimer = CR.idleTimer + interval
                if CR.idleTimer >= 2.0 then CR:GoToSleep() end
            else CR.idleTimer = 0 end 
        end
    end
    CR.baseAnchor:SetScript("OnUpdate", CR.ResourceOnUpdate)
end

WF:RegisterModule("classResource", L["Class Resource"] or "资源条", InitClassResource)