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

CR.currentSpecID = 0
CR._minColorObj = CreateColor and CreateColor(1,1,1,1) or nil
CR._maxColorObj = CreateColor and CreateColor(1,1,1,1) or nil
CR._defaultColorObj = CreateColor and CreateColor(1,1,1,1) or nil
CR._tempWColor = {r=1, g=1, b=1, a=1}
local DEF_W_COL = {r=1, g=1, b=1, a=1}

local DEFAULT_COLOR = {r=1, g=1, b=1}
local DEF_TEXT_COLOR = {r=1, g=1, b=1}
local DEF_DIVIDER_COLOR = {r=1, g=1, b=1, a=1}
local POWER_COLORS = { [0]={r=0,g=0.5,b=1}, [1]={r=1,g=0,b=0}, [2]={r=1,g=0.5,b=0.25}, [3]={r=1,g=1,b=0}, [4]={r=1,g=0.96,b=0.41}, [5]={r=0.8,g=0.1,b=0.2}, [7]={r=0.5,g=0.32,b=0.55}, [8]={r=0.3,g=0.52,b=0.9}, [9]={r=0.95,g=0.9,b=0.6}, [11]={r=0,g=0.5,b=1}, [12]={r=0.71,g=1,b=0.92}, [13]={r=0.4,g=0.8,b=0.8}, [16]={r=0.1,g=0.1,b=0.98}, [17]={r=0.79,g=0.26,b=0.99}, [18]={r=1,g=0.61,b=0}, [19]={r=0.4,g=0.8,b=1} }
CR.POWER_COLORS = POWER_COLORS

local PLAYER_CLASS_COLOR = DEFAULT_COLOR
local cc_cache = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass]
if cc_cache then PLAYER_CLASS_COLOR = {r=cc_cache.r, g=cc_cache.g, b=cc_cache.b} end

POWER_COLORS[6] = PLAYER_CLASS_COLOR

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
        CR._vigorCache.cc = vData.currentCharges or 0; CR._vigorCache.mc = vData.maxCharges or 6
        CR._vigorCache.st = vData.cooldownStartTime or 0; CR._vigorCache.dur = vData.cooldownDuration or 0
    end
    local wData = C_Spell.GetSpellCharges(CR.SPELL_CONSTANTS.VIGOR_RECOVERY_WIND)
    if wData then CR._windCache = wData.currentCharges or 0 end
    local wsData = C_Spell.GetSpellCooldown(CR.SPELL_CONSTANTS.WHIRLING_SURGE)
    if wsData then CR._whirlingCache.st = wsData.startTime or 0; CR._whirlingCache.dur = wsData.duration or 0 end
end

function CR.IsSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) end

function CR.GetVigorSmooth()
    local cc = CR._vigorCache.cc or 0; local mc = CR._vigorCache.mc or 6
    local st = CR._vigorCache.st or 0; local dur = CR._vigorCache.dur or 0
    if CR.IsSecret(cc) or CR.IsSecret(mc) or CR.IsSecret(st) or CR.IsSecret(dur) then return cc, mc end
    if dur > 0 and st > 0 and cc < mc then
        local elapsed = GetTime() - st; if elapsed > dur then elapsed = dur end; if elapsed < 0 then elapsed = 0 end
        return cc + (elapsed / dur), mc
    end
    return cc, mc
end

CR._powerCache = {}
function CR.GetSafePower(pType)
    pType = pType or 0
    local curr = UnitPower("player", pType); local maxP = UnitPowerMax("player", pType)
    CR._powerCache[pType] = CR._powerCache[pType] or {c=0, m=100}
    if not CR.IsSecret(curr) then CR._powerCache[pType].c = curr end; if not CR.IsSecret(maxP) then CR._powerCache[pType].m = maxP end
    return curr, maxP, CR._powerCache[pType].c, CR._powerCache[pType].m
end

function CR.GetSafeMana()
    local curr = UnitPower("player", 0); local maxP = UnitPowerMax("player", 0)
    CR._manaCache = CR._manaCache or {c=0, m=100}
    if not CR.IsSecret(curr) then CR._manaCache.c = curr end; if not CR.IsSecret(maxP) then CR._manaCache.m = maxP end
    return curr, maxP, CR._manaCache.c, CR._manaCache.m
end

CR._auraCacheDirty = true
CR._auraValues = {}
local function GetPlayerAuraSafe(spellID)
    if not spellID then return nil end
    if CR._auraCacheDirty then
        wipe(CR._auraValues)
        CR._auraCacheDirty = false
    end
    if CR._auraValues[spellID] == nil then
        local res = false
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then 
            res = C_UnitAuras.GetPlayerAuraBySpellID(spellID) or false
        elseif C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            for i = 1, 40 do
                local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
                if not aura then break end
                if aura.spellId == spellID then res = aura; break end
            end
        end
        CR._auraValues[spellID] = res
    end
    return CR._auraValues[spellID] == false and nil or CR._auraValues[spellID]
end

CR._activePresetsArray = {}
function CR.RebuildPresetsCache()
    wipe(CR._activePresetsArray)
    if WF.db and WF.db.classResource and WF.db.classResource.presets then
        for pidStr, pData in pairs(WF.db.classResource.presets) do
            local spellID = tonumber(pidStr)
            if spellID then
                table.insert(CR._activePresetsArray, { id = spellID, data = pData })
            end
        end
    end
end

function CR.GetClassResourceData()
    local spec = CR.currentSpecID
    
    for i = 1, #CR._activePresetsArray do
        local item = CR._activePresetsArray[i]
        local aura = GetPlayerAuraSafe(item.id)
        if item.data.isDuration then
            local remain = 0; local maxD = tonumber(item.data.maxVal) or 30
            if aura and aura.expirationTime and aura.expirationTime > 0 then remain = aura.expirationTime - GetTime() end
            if remain < 0 then remain = 0 end; return remain, maxD, PLAYER_CLASS_COLOR, 0
        else
            local apps = aura and aura.applications or 0; local maxA = tonumber(item.data.maxVal) or 5
            return apps, maxA, PLAYER_CLASS_COLOR, 0
        end
    end

    if playerClass == "ROGUE" then return UnitPower("player", 4), UnitPowerMax("player", 4), PLAYER_CLASS_COLOR, 0
    elseif playerClass == "PALADIN" then return UnitPower("player", 9), 5, PLAYER_CLASS_COLOR, 0
    elseif playerClass == "WARLOCK" then 
        local maxTrue = UnitPowerMax("player", 7, true); local currTrue = UnitPower("player", 7, true)
        local maxShards = UnitPowerMax("player", 7); local curr = 0
        if not CR.IsSecret(maxTrue) and not CR.IsSecret(currTrue) and not CR.IsSecret(maxShards) then
            if maxTrue > 0 and maxShards > 0 then curr = (currTrue / maxTrue) * maxShards end
        end
        return curr, maxShards, PLAYER_CLASS_COLOR, 0
    elseif playerClass == "EVOKER" then return UnitPower("player", 19), UnitPowerMax("player", 19), PLAYER_CLASS_COLOR, 0
    elseif playerClass == "DEATHKNIGHT" then 
        local runeCol = {r=1, g=0.2, b=0.2} -- 默认/鲜血: 红色
        if spec == 251 then runeCol = {r=0, g=0.8, b=1} -- 冰霜: 蓝色
        elseif spec == 252 then runeCol = {r=0.2, g=1, b=0.2} end -- 邪恶: 绿色
        local readyRunes = 0
        for i = 1, 6 do 
            local _, _, ready = GetRuneCooldown(i)
            if ready then readyRunes = readyRunes + 1 end 
        end
        return readyRunes, 6, runeCol, 0
    elseif playerClass == "MAGE" and spec == 62 then return UnitPower("player", 16), 4, PLAYER_CLASS_COLOR, 0
    elseif playerClass == "MONK" and spec == 268 then 
        local stagger = UnitStagger("player") or 0; local maxHealth = UnitHealthMax("player") or 1
        if maxHealth <= 0 then maxHealth = 1 end; local pct = 0
        if not CR.IsSecret(stagger) and not CR.IsSecret(maxHealth) then pct = stagger / maxHealth end
        local cColor = MONK_STAGGER_LOW; if pct > 0.6 then cColor = MONK_STAGGER_HIGH elseif pct > 0.3 then cColor = MONK_STAGGER_MED end
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
    if not CR.IsSecret(curr) then CR._clsCache.c = curr end; if not CR.IsSecret(maxP) then CR._clsCache.m = maxP end; if not CR.IsSecret(extra) then CR._clsCache.ext = extra end
    return curr, maxP, CR._clsCache.c, CR._clsCache.m, col, CR._clsCache.ext
end

CR._secretDecoders = {}
function CR.DecodeSecretValue(secretVal, maxVal)
    if not CR.IsSecret(secretVal) then return tonumber(secretVal) or 0 end
    local mVal = tonumber(maxVal) or 10
    if mVal <= 0 then mVal = 10 end; if mVal > 100 then mVal = 100 end
    local count = 0
    for i = 1, mVal do
        local det = CR._secretDecoders[i]
        if not det then det = CreateFrame("StatusBar", nil, UIParent); det:SetSize(1, 1); det:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0); det:SetAlpha(0); det:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8"); CR._secretDecoders[i] = det end
        det:SetMinMaxValues(i - 1, i); local ok = pcall(det.SetValue, det, secretVal); if not ok then break end
        local tex = det:GetStatusBarTexture(); if tex and tex:IsShown() then count = i else break end
    end
    return count
end

CR._gradColorCache = { isGradient = true, startC = nil, endC = nil }

function CR.GetDynamicBarColor(val, maxVal, cfg, baseColor)
    if not cfg then return baseColor end
    if CR.IsSecret and CR.IsSecret(val) then return baseColor end
    local currentVal = tonumber(val)
    if not currentVal then return baseColor end

    if cfg.enableGradient then
        CR._gradColorCache.startC = cfg.gradientStart or {r=0, g=1, b=0, a=1}
        CR._gradColorCache.endC = cfg.gradientEnd or {r=1, g=0, b=0, a=1}
        return CR._gradColorCache
    elseif cfg.enableThreshold and cfg.colorThresholds then
        local evalVal = math_floor(currentVal) + 0.001
        local highestMatchedColor = nil
        local highestTriggerVal = -999999

        for i = 1, 5 do
            local stage = cfg.colorThresholds[i]
            if type(stage) == "table" and stage.enable then
                local triggerVal = tonumber(stage.value) or 0
                if evalVal >= triggerVal and triggerVal > highestTriggerVal then highestTriggerVal = triggerVal; highestMatchedColor = stage.color end
            end
        end
        if highestMatchedColor then return highestMatchedColor end
    end
    return baseColor
end

CR._powerColorCurves = {}
CR._threshCache = {} 
CR._rgbaCache = {r=1, g=1, b=1, a=1}

function CR._SortThresholds(a, b) return (tonumber(a.value) or 0) < (tonumber(b.value) or 0) end

function CR.GetSecretThresholdColor(pType, rawMax, baseColor, specCfg)
    if not specCfg.power.enableThreshold or not C_CurveUtil or not C_CurveUtil.CreateColorCurve then return baseColor end
    if specCfg.power._cachedCurve and specCfg.power._cachedCurveMax == rawMax then
        local ok, res = pcall(UnitPowerPercent, "player", pType, false, specCfg.power._cachedCurve)
        if ok and res and res.GetRGBA then 
            local r, g, b, a = res:GetRGBA()
            CR._rgbaCache.r = r; CR._rgbaCache.g = g; CR._rgbaCache.b = b; CR._rgbaCache.a = a
            return CR._rgbaCache 
        end
        return baseColor
    end

    wipe(CR._threshCache); local hasAny = false
    if type(specCfg.power.colorThresholds) == "table" then
        for i = 1, 5 do
            local t = specCfg.power.colorThresholds[i]
            if type(t) == "table" and t.enable and (tonumber(t.value) or 0) > 0 then
                local safeColor = type(t.color) == "table" and t.color or {r=1, g=1, b=1, a=1}
                CR._threshCache[#CR._threshCache + 1] = { value = tonumber(t.value), color = safeColor }; hasAny = true
            end
        end
    else
        local singleVal = tonumber(specCfg.power.thresholdValue)
        if singleVal and singleVal > 0 then
            local safeColor = type(specCfg.power.thresholdColor) == "table" and specCfg.power.thresholdColor or {r=1, g=0, b=0, a=1}
            CR._threshCache[1] = { value = singleVal, color = safeColor }; hasAny = true
        end
    end

    if not hasAny then return baseColor end
    table.sort(CR._threshCache, CR._SortThresholds)

    local curve = C_CurveUtil.CreateColorCurve(); local lastPct = 0; local lastColor = baseColor
    curve:AddPoint(0.0, CreateColor(baseColor.r, baseColor.g, baseColor.b, baseColor.a or 1))

    for i = 1, #CR._threshCache do
        local t = CR._threshCache[i]; local pct = t.value / (rawMax > 0 and rawMax or 1)
        if pct > 1 then pct = 1 end; if pct < 0 then pct = 0 end
        if pct > lastPct then curve:AddPoint(pct - 0.0001, CreateColor(lastColor.r or 1, lastColor.g or 1, lastColor.b or 1, lastColor.a or 1)) end
        curve:AddPoint(pct, CreateColor(t.color.r or 1, t.color.g or 1, t.color.b or 1, t.color.a or 1))
        lastPct = pct; lastColor = t.color
    end

    if lastPct < 1.0 then curve:AddPoint(1.0, CreateColor(lastColor.r or 1, lastColor.g or 1, lastColor.b or 1, lastColor.a or 1)) end
    specCfg.power._cachedCurve = curve; specCfg.power._cachedCurveMax = rawMax

    local ok, res = pcall(UnitPowerPercent, "player", pType, false, curve)
    if ok and res and res.GetRGBA then 
        local r, g, b, a = res:GetRGBA()
        CR._rgbaCache.r = r; CR._rgbaCache.g = g; CR._rgbaCache.b = b; CR._rgbaCache.a = a
        return CR._rgbaCache 
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

function CR.GetOnePixelSize()
    local screenHeight = select(2, GetPhysicalScreenSize()); if not screenHeight or screenHeight == 0 then return 1 end
    local uiScale = UIParent:GetEffectiveScale(); if not uiScale or uiScale == 0 then return 1 end
    return 768.0 / screenHeight / uiScale
end
function CR.PixelSnap(value)
    if not value then return 0 end; local onePixel = CR.GetOnePixelSize(); if onePixel == 0 then return value end
    return math_floor(value / onePixel + 0.5) * onePixel
end
function CR.GetDurationTextSafe(remaining)
    if not remaining then return "" end; local num = tonumber(remaining); if not num then return tostring(remaining) end
    if num >= 60 then return string_format("%dm", math_floor(num / 60)) elseif num >= 10 then return string_format("%d", math_floor(num)) else return string_format("%.1f", num) end
end
function CR.GetSafeJustify(anchorStr)
    if type(anchorStr) ~= "string" then return "CENTER" end
    if string.match(anchorStr, "LEFT") then return "LEFT" elseif string.match(anchorStr, "RIGHT") then return "RIGHT" else return "CENTER" end
end
function CR.SafeFormatNum(num)
    if type(num) == "number" then
        if num >= 1000000 then return string_format("%.1fm", num / 1000000) elseif num >= 1000 then return string_format("%.1fk", num / 1000) else return string_format("%d", math_floor(num)) end
    end
    return tostring(num)
end
function CR.UpdateBarValueSafe(sb, rawCurr, rawMax)
    pcall(sb.SetMinMaxValues, sb, 0, rawMax); sb._targetValue = rawCurr
    if Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut then pcall(sb.SetValue, sb, rawCurr, Enum.StatusBarInterpolation.ExponentialEaseOut); sb._currentValue = rawCurr
    else if not sb._currentValue then sb._currentValue = rawCurr; pcall(sb.SetValue, sb, rawCurr) end end
end

local barDefaults = {
    power = { independent = false, width = 250, barXOffset = 0, barYOffset = 0, height = 10, textEnable = true, textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = false, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", useCustomBgColor = false, bgColor = {r=0, g=0, b=0, a=0.5}, enableThreshold = false, thresholdValue = 100, thresholdColor = {r=1, g=0, b=0}, thresholdPowerType = "ALL", borderEnable = true, borderSize = 1, borderColor = {r=0, g=0, b=0, a=1}, orientation = "HORIZONTAL" },
    class = { independent = false, width = 250, barXOffset = 0, barYOffset = 0, height = 10, textEnable = false, textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = false, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=1, g=0.96, b=0.41}, useCustomColors = {}, customColors = {}, useChargeColor = false, chargeColor = {r=0.5, g=0.5, b=0.5, a=0.8}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", useCustomBgColor = false, bgColor = {r=0, g=0, b=0, a=0.5}, borderEnable = true, borderSize = 1, borderColor = {r=0, g=0, b=0, a=1}, orientation = "HORIZONTAL" },
    mana = { independent = false, width = 250, barXOffset = 0, barYOffset = 0, height = 10, textEnable = true, textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = false, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", useCustomBgColor = false, bgColor = {r=0, g=0, b=0, a=0.5}, borderEnable = true, borderSize = 1, borderColor = {r=0, g=0, b=0, a=1}, orientation = "HORIZONTAL" },
    vigor = { independent = false, width = 250, barXOffset = 0, barYOffset = 0, height = 10, textEnable = false, textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = false, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0.2, g=0.7, b=1}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", useCustomBgColor = false, bgColor = {r=0, g=0, b=0, a=0.5}, borderEnable = true, borderSize = 1, borderColor = {r=0, g=0, b=0, a=1}, orientation = "HORIZONTAL" },
    whirling = { independent = false, width = 250, barXOffset = 0, barYOffset = 0, height = 4, textEnable = false, textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = false, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=1, g=0.8, b=0}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", useCustomBgColor = false, bgColor = {r=0, g=0, b=0, a=0.5}, borderEnable = true, borderSize = 1, borderColor = {r=0, g=0, b=0, a=1}, orientation = "HORIZONTAL" },
}

local defaults = { enable = true, attachToResource = true, alignWithCD = true, alignYOffset = 1, widthOffset = 0, texture = "Wish2", font = "Expressway", specConfigs = {}, sortOrder = {"class", "power", "mana", "vigor", "whirling"}, globalBgColor = {r=0, g=0, b=0, a=0.5}, fadeOOC = false, fadeAlpha = 0, sandboxSpacing = 15 }

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

    local uniqueSort = {}; local seenUnique = {}
    if type(WF.db.classResource.sortOrder) == "table" then
        for _, key in ipairs(WF.db.classResource.sortOrder) do
            if key ~= "monitor" and not seenUnique[key] then table.insert(uniqueSort, key); seenUnique[key] = true end
        end
    end
    
    local seenKeys = {}; for _, k in ipairs(uniqueSort) do seenKeys[k] = true end
    for _, key in ipairs({"class", "power", "mana", "vigor", "whirling"}) do 
        if not seenKeys[key] then table.insert(uniqueSort, key) end 
    end
    WF.db.classResource.sortOrder = uniqueSort
    
    dbInitialized = true; cachedDB = WF.db.classResource
    CR.RebuildPresetsCache() 
    return cachedDB
end

function CR:InvalidateDB() dbInitialized = false; cachedDB = nil end
function CR.GetCurrentContextID() local specIndex = GetSpecialization(); return specIndex and GetSpecializationInfo(specIndex) or 0 end

local function GetDefaultVisibility(pClass, specID)
    if pClass == "DRUID" then return true, true, false end
    local sPower, sClass, sMana = false, false, false
    if pClass == "WARRIOR" then sPower = true
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
            if type(cfg.customColors) == "table" and cfg.customColors[CR.playerClass] then return cfg.customColors[CR.playerClass] end
        end
        if cfg.useCustomColor then if type(cfg.customColor) == "table" and type(cfg.customColor.r) == "number" then return cfg.customColor end end
    else 
        if cfg.useCustomColor then if type(cfg.customColor) == "table" and type(cfg.customColor.r) == "number" then return cfg.customColor end end
    end
    if type(defColor) == "table" and type(defColor.r) == "number" then return defColor end
    return DEFAULT_COLOR
end

function CR.GetPowerColor(pType) if not pType then return DEFAULT_COLOR end; return POWER_COLORS[pType] or DEFAULT_COLOR end

function CR:SetupBarMover(bar, cfg, barKey, name)
    if not bar.moverOverlay then
        local moverName = "WishFlex_CR_IndMover_" .. barKey
        local mover = CreateFrame("Button", moverName, bar, "BackdropTemplate")
        mover:SetAllPoints(); mover:SetFrameStrata("HIGH"); mover:SetFrameLevel(bar:GetFrameLevel() + 20)
        mover:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
        bar.moverOverlay = mover
        
        local label = mover:CreateFontString(nil, "OVERLAY")
        label:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        label:SetPoint("BOTTOM", mover, "TOP", 0, 4)
        label:SetTextColor(1, 0.82, 0)
        bar.moverLabel = label

        local pText = mover:CreateFontString(nil, "OVERLAY")
        pText:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
        pText:SetPoint("CENTER", mover, "CENTER", 0, 0)
        pText:SetTextColor(1, 1, 1, 0.7)
        bar.moverPreviewText = pText

        mover:RegisterForDrag("LeftButton"); mover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        mover.isCRIndMover = true; mover.targetFrame = bar; mover.barKey = barKey

        mover:SetScript("OnDragStart", function(self)
            if not WF.MoversUnlocked then return end
            WF:SelectMover(self, false); bar:StartMoving(); bar._isDragging = true
        end)
        
        mover:SetScript("OnDragStop", function(self)
            if not bar._isDragging then return end
            bar:StopMovingOrSizing(); bar._isDragging = false
            
            local sCfg = CR.GetCurrentSpecConfig()
            local targetCfg = (self.barKey == "vigor" or self.barKey == "whirling") and CR.GetDB()[self.barKey] or sCfg[self.barKey]
            if string.sub(self.barKey or "", 1, 3) == "WM_" then
                local spellID = string.sub(self.barKey, 4); local wmDB = WF.db.wishMonitor or {}
                targetCfg = (wmDB.skills and wmDB.skills[spellID]) or (wmDB.buffs and wmDB.buffs[spellID])
            end

            if targetCfg and targetCfg.independent then
                local ax, ay = bar.myAnchor:GetCenter(); local bx, by = bar:GetCenter()
                if ax and ay and bx and by then targetCfg.barXOffset = CR.PixelSnap(bx - ax); targetCfg.barYOffset = CR.PixelSnap(by - ay) end
                CR:UpdateLayout()
            end
            
            local cx, cy = bar:GetCenter(); local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
            if WF.EditModeControlPanel and WF.EditModeControlPanel:IsShown() and WF.SelectedMover == self then
                WF.EditModeControlPanel.xInput:SetText(tostring(math.floor((cx - pw/2) + 0.5)))
                WF.EditModeControlPanel.yInput:SetText(tostring(math.floor((cy - ph/2) + 0.5)))
            end
        end)
        
        mover:SetScript("OnClick", function(self, button) if button == "LeftButton" and WF.MoversUnlocked then WF:SelectMover(self, false) end end)
        
        if not CR.MoverHooked then
            local origUpdateMoverPos = WF.UpdateMoverPos
            WF.UpdateMoverPos = function(wf_self, targetMover, baseCenterX, baseCenterY)
                if targetMover and targetMover.isCRIndMover then
                    local barFrame = targetMover.targetFrame; if not barFrame or not barFrame.myAnchor then return end
                    local ax, ay = barFrame.myAnchor:GetCenter(); local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
                    local absX = baseCenterX + pw/2; local absY = baseCenterY + ph/2
                    
                    local sCfg = CR.GetCurrentSpecConfig()
                    local targetCfg = (targetMover.barKey == "vigor" or targetMover.barKey == "whirling") and CR.GetDB()[targetMover.barKey] or sCfg[targetMover.barKey]
                    if string.sub(targetMover.barKey or "", 1, 3) == "WM_" then
                        local spellID = string.sub(targetMover.barKey, 4); local wmDB = WF.db.wishMonitor or {}
                        targetCfg = (wmDB.skills and wmDB.skills[spellID]) or (wmDB.buffs and wmDB.buffs[spellID])
                    end

                    if targetCfg and targetCfg.independent then
                        targetCfg.barXOffset = CR.PixelSnap(absX - ax); targetCfg.barYOffset = CR.PixelSnap(absY - ay); CR:UpdateLayout()
                        if WF.EditModeControlPanel and WF.EditModeControlPanel:IsShown() and WF.SelectedMover == targetMover then
                            WF.EditModeControlPanel.xInput:SetText(tostring(math.floor(baseCenterX + 0.5)))
                            WF.EditModeControlPanel.yInput:SetText(tostring(math.floor(baseCenterY + 0.5)))
                        end
                    end
                    return 
                end
                if origUpdateMoverPos then origUpdateMoverPos(wf_self, targetMover, baseCenterX, baseCenterY) end
            end
            CR.MoverHooked = true
        end
        if WF.Movers then table.insert(WF.Movers, mover) end
    end
    
    bar.moverOverlay.titleText = name or barKey; bar.moverLabel:SetText(name or barKey)
    
    local isInd = cfg and (cfg.independent or cfg.displayMode == "text")
    if bar.moverPreviewText then
        if isInd then
            local isStack = cfg.mode == "stack" or cfg.trackType == "charge"
            bar.moverPreviewText:SetText(isStack and "3" or "12.5s")
            local fontPath = LSM:Fetch("font", CR.GetDB().font or "Expressway") or STANDARD_TEXT_FONT
            local fontSize = tonumber(cfg.fontSize) or 14
            bar.moverPreviewText:SetFont(fontPath, fontSize, "OUTLINE")
            bar.moverPreviewText:Show()
        else
            bar.moverPreviewText:Hide()
        end
    end

    bar.moverOverlay:SetBackdropColor(0, 0.5, 1, 0.4)
    bar.moverOverlay:SetBackdropBorderColor(0, 0.8, 1, 0.8)

    if WF.MoversUnlocked and isInd then 
        bar:SetMovable(true); bar.moverOverlay:Show() 
    else 
        bar:SetMovable(false); if bar.moverOverlay then bar.moverOverlay:Hide() end 
    end
end

function CR:DoStackLayout()
    if not self.powerBar or not self.manaBar or not self.classBar or not self.baseAnchor then return end
    
    local db = CR.GetDB(); local specCfg = self.cachedSpecCfg
    local isConfigOpen = (WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown()) or (EditModeManagerFrame and EditModeManagerFrame:IsShown())
    local isEditMode = WF.MoversUnlocked

    local nativeItems = {
        { key = "class", frame = self.classBar, show = self.showClass, cfg = specCfg.class, anchor = self.classAnchor, name = L["Class Resource Bar"] or "主资源条" },
        { key = "power", frame = self.powerBar, show = self.showPower, cfg = specCfg.power, anchor = self.powerAnchor, name = L["Power Bar"] or "能量条" },
        { key = "vigor", frame = self.vigorBar, show = self.showVigor, cfg = db.vigor, anchor = self.vigorAnchor, name = L["Vigor Bar"] or "驭空术资源条" },
        { key = "whirling", frame = self.whirlingBar, show = self.showWhirling, cfg = db.whirling, anchor = self.whirlingAnchor, name = L["Whirling Surge Bar"] or "回旋冲刺条" },
    }
    
    if hasHealerSpec then table.insert(nativeItems, 3, { key = "mana",  frame = self.manaBar, show = self.showMana, cfg = specCfg.mana, anchor = self.manaAnchor, name = L["Extra Mana Bar"] or "额外法力条" }) else self.manaBar.isForceHidden = true; self.manaBar:Hide() end

    local activeKeys = {}; local stackDict = {}
    for _, item in ipairs(nativeItems) do
        local shouldShow = item.show
        if isConfigOpen and CR.Sandbox and CR.Sandbox.popupTarget == item.key then shouldShow = true end
        if isEditMode and item.cfg.independent then shouldShow = true end
        
        item.frame.myAnchor = item.anchor.mover or item.anchor; self:SetupBarMover(item.frame, item.cfg, item.key, item.name)
        
        if shouldShow then
            item.frame.isForceHidden = false; if not self.sleepMode or db.fadeOOC == false then item.frame:Show() end
            if not item.cfg.independent then
                stackDict[item.key] = { frame = item.frame, height = tonumber(item.cfg.height) or 10, xOff = 0, yOff = 0 }; activeKeys[item.key] = true
                if item.frame.statusBar then pcall(function() item.frame.statusBar:SetOrientation("HORIZONTAL") end) end
            elseif not item.frame._isDragging then
                item.frame:ClearAllPoints()
                item.frame:SetPoint("CENTER", item.frame.myAnchor, "CENTER", CR.PixelSnap(item.cfg.barXOffset or 0), CR.PixelSnap(item.cfg.barYOffset or 0))
                local indWidth = tonumber(item.cfg.width) or self:GetActiveWidth()
                local indHeight = tonumber(item.cfg.height) or 10
                
                if item.cfg.orientation == "VERTICAL" then
                    item.frame:SetSize(indHeight, CR.PixelSnap(indWidth))
                    if item.frame.statusBar then item.frame.statusBar:SetOrientation("VERTICAL") end
                else
                    item.frame:SetSize(CR.PixelSnap(indWidth), indHeight)
                    if item.frame.statusBar then item.frame.statusBar:SetOrientation("HORIZONTAL") end
                end
                
                if item.frame.moverOverlay then item.frame.moverOverlay:SetSize(item.frame:GetSize()) end
            end
        else item.frame.isForceHidden = true; item.frame:Hide() end
    end

    if self.ActiveMonitorFrames then
        for _, f in ipairs(self.ActiveMonitorFrames) do
            local key = "WM_" .. (f.spellIDStr or tostring(f.spellID))
            f.barKey = key
            
            local isTextMode = (f.cfg.displayMode == "text")
            local isInd = (f.cfg.independent or isTextMode)
            
            local globalMover = nil
            if isInd then
                local anchorName = "WishFlex_WM_Anchor_" .. f.spellIDStr
                globalMover = _G[anchorName.."Mover"] or _G[anchorName]
            end
            
            f.myAnchor = globalMover or self.baseAnchor.mover or self.baseAnchor
            
            local realName = f.spellName
            if not realName and f.spellID then
                local actualID = f.cfg.realSpellID or tostring(f.spellID):gsub("_TXT", "")
                local sInfo = C_Spell.GetSpellInfo(tonumber(actualID))
                if sInfo then realName = sInfo.name end
            end
            local displayName = "[监控] - " .. (realName or f.spellIDStr or key)
            self:SetupBarMover(f, f.cfg, key, displayName)
            
            if isEditMode and isInd then
                f.isForceHidden = false
                f:Show()
                f:SetAlpha(1)
            end
            
            if not isInd then
                stackDict[key] = { frame = f, height = f.calcHeight, xOff = 0, yOff = 0 }; activeKeys[key] = true
                if f.chargeBar then pcall(function() f.chargeBar:SetOrientation("HORIZONTAL") end) end
                if f.refreshCharge then pcall(function() f.refreshCharge:SetOrientation("HORIZONTAL") end) end
            elseif not f._isDragging then
                f:ClearAllPoints()
                f:SetPoint("CENTER", f.myAnchor, "CENTER", CR.PixelSnap(f.cfg.barXOffset or 0), CR.PixelSnap(f.cfg.barYOffset or 0))
                
                if isTextMode then
                    f:SetSize(60, 40)
                    if f.moverOverlay then f.moverOverlay:SetSize(60, 40) end
                else
                    local indWidth = tonumber(f.cfg.width) or self:GetActiveWidth()
                    local indHeight = f.calcHeight or 10
                    
                    if f.cfg.orientation == "VERTICAL" then
                        f:SetSize(indHeight, CR.PixelSnap(indWidth))
                        if f.chargeBar then f.chargeBar:SetOrientation("VERTICAL") end
                    else
                        f:SetSize(CR.PixelSnap(indWidth), indHeight)
                        if f.chargeBar then f.chargeBar:SetOrientation("HORIZONTAL") end
                    end

                    if f.moverOverlay then f.moverOverlay:SetSize(f:GetSize()) end
                end
            end
        end
    end

    local orderedStack = {}; local sortOrder = db.sortOrder or {}; local existingKeys = {}
    for _, k in ipairs(sortOrder) do existingKeys[k] = true end
    local addedNew = false
    for k in pairs(activeKeys) do if not existingKeys[k] then table.insert(sortOrder, 1, k); existingKeys[k] = true; addedNew = true end end
    if addedNew then db.sortOrder = sortOrder end

    local addedFrames = {}
    for i = #sortOrder, 1, -1 do 
        local key = sortOrder[i]
        if activeKeys[key] then 
            local f = stackDict[key].frame
            if not addedFrames[f] then table.insert(orderedStack, stackDict[key]); addedFrames[f] = true end
        end 
    end

    self.lastStackedFrame = nil
    local targetWidth = self:GetActiveWidth() or 250; local topViewer = self:GetTopVisibleCDViewer()
    local globalSpacing = CR.PixelSnap(specCfg.yOffset or 1)

    for _, item in ipairs(orderedStack) do
        local f = item.frame; if f._isDragging then return end
        f:ClearAllPoints(); local finalH = item.height; local targetX = CR.PixelSnap(item.xOff)
        if not self.lastStackedFrame then
            if db.alignWithCD and topViewer then
                local baseTY = CR.PixelSnap((tonumber(db.alignYOffset) or 1) + item.yOff)
                f:SetPoint("BOTTOMLEFT", topViewer, "TOPLEFT", targetX, baseTY)
                f:SetPoint("BOTTOMRIGHT", topViewer, "TOPRIGHT", targetX, baseTY)
                f:SetHeight(finalH)
            else
                local targetY = CR.PixelSnap(item.yOff)
                f:SetPoint("CENTER", self.baseAnchor.mover or self.baseAnchor, "CENTER", targetX, targetY); f:SetSize(CR.PixelSnap(targetWidth), finalH)
            end
        else
            local stackGap = CR.PixelSnap(globalSpacing + item.yOff)
            f:SetPoint("BOTTOMLEFT", self.lastStackedFrame, "TOPLEFT", targetX, stackGap)
            f:SetPoint("BOTTOMRIGHT", self.lastStackedFrame, "TOPRIGHT", targetX, stackGap); f:SetHeight(finalH)
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
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then if C_UnitAuras.GetPlayerAuraBySpellID(404468) then isSteadyFlight = true end end
        if not isSteadyFlight then
            local isUsable = false
            if C_Spell and C_Spell.IsSpellUsable then local usable, noMana = C_Spell.IsSpellUsable(CR.SPELL_CONSTANTS.SKYRIDING_SURGE); isUsable = usable or noMana
            elseif IsUsableSpell then local usable, noMana = IsUsableSpell(CR.SPELL_CONSTANTS.SKYRIDING_SURGE); isUsable = usable or noMana end
            
            if isUsable then
                local chInfo = C_Spell.GetSpellCharges(CR.SPELL_CONSTANTS.SKYRIDING_SURGE)
                if chInfo then 
                    local rawMax = chInfo.maxCharges
                    if not CR.IsSecret(rawMax) and rawMax > 0 then isSkyriding = true end 
                else
                    isSkyriding = true
                end
            end
        end
    end
    if self.isVigorActive ~= isSkyriding then
        self.isVigorActive = isSkyriding; self:UpdateLayout()
        if WF.WishMonitorAPI and WF.WishMonitorAPI.TriggerUpdate then WF.WishMonitorAPI:TriggerUpdate() end
    end
end

function CR:TriggerVigorCheck()
    self:UpdateFlightCaches()
    self:CheckVigorState()
    C_Timer.After(0.2, function() self:UpdateFlightCaches(); self:CheckVigorState() end)
    C_Timer.After(0.6, function() self:UpdateFlightCaches(); self:CheckVigorState() end)
    C_Timer.After(1.5, function() self:UpdateFlightCaches(); self:CheckVigorState() end)
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

function CR:UpdateLayout()
    if not self.powerBar or not self.baseAnchor then return end

    if self.isRendering then return end
    self.isRendering = true
    
    local db = CR.GetDB(); local currentContextID = CR.GetCurrentContextID(); local specCfg = CR.GetCurrentSpecConfig(currentContextID)
    self.cachedSpecCfg = specCfg
    if self.cachedSpecCfg and self.cachedSpecCfg.power then self.cachedSpecCfg.power._cachedCurve = nil end

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

    self:DoStackLayout(); self:DynamicTick(); self.isRendering = false
end

function CR:OnContextChanged()
    self.selectedSpecForConfig = CR.GetCurrentContextID()
    CR.currentSpecID = self.selectedSpecForConfig
    self.cachedSpecCfg = CR.GetCurrentSpecConfig(self.selectedSpecForConfig)
    self:UpdateLayout()
end

function CR:GoToSleep()
    if not self.baseAnchor then return end
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
        if self.AllBars then
            for i = 1, #self.AllBars do
                local bar = self.AllBars[i]
                if self.isVigorActive and (bar == self.vigorBar or bar == self.whirlingBar) then bar:SetAlpha(1)
                else bar:SetAlpha(alpha); if alpha <= 0 then if bar and bar.text then bar.text:SetAlpha(0) end; if bar and bar.timerText then bar.timerText:SetAlpha(0) end end end
            end
        end
    end
end

function CR:WakeUp()
    if not self.baseAnchor then return end
    self.idleTimer = 0
    if self.sleepMode then
        self.sleepMode = false; self.baseAnchor:SetScript("OnUpdate", self.ResourceOnUpdate)
        if self.AllBars then
            for i = 1, #self.AllBars do
                local bar = self.AllBars[i]; bar:SetAlpha(1)
                if not bar.isForceHidden then bar:Show(); if bar.text then bar.text:SetAlpha(1) end; if bar.timerText then bar.timerText:SetAlpha(1) end end
            end
        end
        self:DynamicTick()
    end
end

function CR:DynamicTick()
    if not self.baseAnchor or not self.powerBar then return end
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

    if (self.showVigor or (isConfigOpen and CR.Sandbox and CR.Sandbox.popupTarget == "vigor")) and specCfg.vigor then
        local rawCurr, rawMax = CR.GetVigorSmooth()
        if not CR.IsSecret(rawMax) and rawMax <= 0 then rawMax = 6 end
        if CR.IsSecret(rawCurr) or CR.IsSecret(rawMax) then self.hasActiveTimer = true elseif rawCurr < rawMax then self.hasActiveTimer = true end
        
        local vColor = CR.GetSafeColor(specCfg.vigor, DEF_VIGOR_COLOR, false)
        CR.UpdateBarValueSafe(self.vigorBar.statusBar, rawCurr, rawMax); self.vigorBar.statusBar:SetStatusBarColor(vColor.r, vColor.g, vColor.b)
        if self.UpdateDividers then self:UpdateDividers(self.vigorBar, rawMax) end
        if self.UpdateVigorPulse then self:UpdateVigorPulse(self.vigorBar, rawCurr, rawMax, CR._windCache) end
    end

    if (self.showWhirling or (isConfigOpen and CR.Sandbox and CR.Sandbox.popupTarget == "whirling")) and specCfg.whirling then
        local rawCurr, rawMax = 1, 1; local st, dur = CR._whirlingCache.st, CR._whirlingCache.dur
        if not CR.IsSecret(dur) and dur > 1.5 then
            rawMax = dur; local remain = (st + dur) - GetTime()
            if remain > 0 then rawCurr = rawMax - remain else rawCurr = rawMax end
        end
        if CR.IsSecret(rawCurr) or CR.IsSecret(rawMax) then self.hasActiveTimer = true elseif rawCurr < rawMax then self.hasActiveTimer = true end
        
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
        local tPType = specCfg.power.thresholdPowerType; local applyThresholds = (not tPType or tPType == "ALL" or tonumber(tPType) == pType)
        
        if specCfg.power.enableThreshold and applyThresholds then pColor = CR.GetSecretThresholdColor(pType, rawMax, pColor, specCfg) end
        CR.UpdateBarValueSafe(self.powerBar.statusBar, rawCurr, rawMax); self.powerBar.statusBar:SetStatusBarColor(pColor.r, pColor.g, pColor.b)

        if specCfg.power.thresholdLines and applyThresholds then
            if not self.powerBar.thresholdLines then self.powerBar.thresholdLines = {} end; local activeLines = 0
            for lineIdx = 1, 5 do
                local tLineCfg = specCfg.power.thresholdLines[lineIdx]
                if type(tLineCfg) == "table" and tLineCfg.enable and (tonumber(tLineCfg.value) or 0) > 0 then
                    activeLines = activeLines + 1; local tLine = self.powerBar.thresholdLines[activeLines]
                    if not tLine then tLine = self.powerBar.statusBar:CreateTexture(nil, "OVERLAY", nil, 7); self.powerBar.thresholdLines[activeLines] = tLine end
                    local lineVal = tonumber(tLineCfg.value) or 0; local pct = lineVal / safeMax; if pct > 1 then pct = 1 end
                    local posX = pct * self:GetActiveWidth(); local tColor = type(tLineCfg.color) == "table" and tLineCfg.color or DEF_DIVIDER_COLOR; local tThick = tonumber(tLineCfg.thickness) or 2
                    tLine:SetColorTexture(tColor.r or 1, tColor.g or 1, tColor.b or 1, tColor.a or 1); tLine:SetWidth(tThick); tLine:ClearAllPoints(); tLine:SetPoint("TOPLEFT", self.powerBar.statusBar, "TOPLEFT", posX - (tThick/2), 0); tLine:SetPoint("BOTTOMLEFT", self.powerBar.statusBar, "BOTTOMLEFT", posX - (tThick/2), 0); tLine:Show()
                end
            end
            for idx = activeLines + 1, #(self.powerBar.thresholdLines or {}) do if self.powerBar.thresholdLines[idx] then self.powerBar.thresholdLines[idx]:Hide() end end
        elseif self.powerBar.thresholdLines then for _, tl in ipairs(self.powerBar.thresholdLines) do tl:Hide() end end

        if self.UpdateDividers then self:UpdateDividers(self.powerBar, 1) end
        if self.FormatSafeText then local displayCurr = CR.IsSecret(rawCurr) and rawCurr or math_floor(safeCurr); self:FormatSafeText(self.powerBar, specCfg.power, displayCurr, rawMax, false, pType, specCfg.power.textEnable ~= false, nil, "power") end
    end

    if (self.showClass or (isConfigOpen and CR.Sandbox and CR.Sandbox.popupTarget == "class")) and specCfg.class then
        local rawCurr, rawMax, safeCurr, safeMax, cDefColor, safeExtra = CR.GetSafeClassResource()
        if safeMax <= 0 then safeMax = 1 end

if playerClass == "EVOKER" then
            if not CR.evokerEssence then CR.evokerEssence = { count = safeCurr, partial = 0, lastTick = GetTime() } end
            local now = GetTime(); local elapsed = now - CR.evokerEssence.lastTick; CR.evokerEssence.lastTick = now
            if safeCurr > CR.evokerEssence.count then CR.evokerEssence.partial = 0 end; CR.evokerEssence.count = safeCurr
            
            if safeCurr < safeMax then
                local activeRegen = 0.2
                if GetPowerRegenForPowerType then 
                    local _, act = GetPowerRegenForPowerType(19)
                    if type(act) == "number" and not CR.IsSecret(act) then 
                        activeRegen = act 
                    end 
                end
                CR.evokerEssence.partial = CR.evokerEssence.partial + (activeRegen * elapsed)
                if CR.evokerEssence.partial >= 1 then CR.evokerEssence.partial = 0.99 end
            else 
                CR.evokerEssence.partial = 0 
            end
            
            rawCurr = rawCurr + CR.evokerEssence.partial; safeCurr = safeCurr + CR.evokerEssence.partial
        elseif playerClass == "DEATHKNIGHT" then
            local readyRunes = 0
            for i=1, 6 do
                local _, _, runeReady = GetRuneCooldown(i)
                if runeReady then readyRunes = readyRunes + 1 end
            end
            rawCurr = readyRunes; safeCurr = readyRunes

            if not self.classBar.runes then
                self.classBar.runes = {}
                for i = 1, 6 do
                    local rBar = CreateFrame("StatusBar", nil, self.classBar.statusBar)
                    rBar:SetMinMaxValues(0, 1)
                    self.classBar.runes[i] = rBar
                end
            end
        end

        if safeCurr < safeMax then if playerClass ~= "WARLOCK" and playerClass ~= "ROGUE" and playerClass ~= "PALADIN" and playerClass ~= "MONK" then self.hasActiveTimer = true end end
        local cColor = CR.GetSafeColor(specCfg.class, cDefColor, true)
        
        local applyGrad = false
        if CR.GetDynamicBarColor then
            local decodedCurr = CR.DecodeSecretValue(rawCurr, rawMax)
            local matchedColor = CR.GetDynamicBarColor(decodedCurr, rawMax, specCfg.class, cColor)
            if matchedColor then 
                if matchedColor.isGradient then
                    applyGrad = true
                    if not CR._tempWColor then CR._tempWColor = {r=1, g=1, b=1, a=1} end
                    cColor = CR._tempWColor
                else
                    cColor = matchedColor 
                end
            end
        end


        local isFractional = playerClass ~= "DEATHKNIGHT" and (rawCurr - math_floor(rawCurr)) > 0.001
        local useGeneralCharge = specCfg.class.useChargeColor and specCfg.class.chargeColor
        local targetVal = rawCurr
        if useGeneralCharge and isFractional then
            targetVal = math_floor(rawCurr)
        end
        
        CR.UpdateBarValueSafe(self.classBar.statusBar, targetVal, rawMax)
        if useGeneralCharge and self.classBar.statusBar._lastTargetVal ~= targetVal then
            self.classBar.statusBar._currentValue = targetVal
            self.classBar.statusBar:SetValue(targetVal)
            self.classBar.statusBar._lastTargetVal = targetVal
        end

        self.classBar.statusBar:SetStatusBarColor(cColor.r, cColor.g, cColor.b)

        
        local tex = self.classBar.statusBar:GetStatusBarTexture()
        if tex then
            tex:SetHorizTile(false)
            tex:SetVertTile(false)
        end
        
        if applyGrad and tex then
            local matchedColor = CR.GetDynamicBarColor(CR.DecodeSecretValue(rawCurr, rawMax), rawMax, specCfg.class, cColor)
            local sC = matchedColor.startC or DEF_W_COL
            local eC = matchedColor.endC or DEF_W_COL
            local orient = (specCfg.class.independent and specCfg.class.orientation == "VERTICAL") and "VERTICAL" or "HORIZONTAL"
            if CR._minColorObj and CR._maxColorObj then 
                CR._minColorObj:SetRGBA(sC.r, sC.g, sC.b, sC.a or 1)
                CR._maxColorObj:SetRGBA(eC.r, eC.g, eC.b, eC.a or 1)
                tex:SetGradient(orient, CR._minColorObj, CR._maxColorObj)
            else 
                tex:SetGradient(orient, sC.r,sC.g,sC.b,sC.a or 1, eC.r,eC.g,eC.b,eC.a or 1) 
            end
        elseif tex then
            local orient = (specCfg.class.independent and specCfg.class.orientation == "VERTICAL") and "VERTICAL" or "HORIZONTAL"
            if CR._defaultColorObj then 
                CR._defaultColorObj:SetRGBA(cColor.r, cColor.g, cColor.b, cColor.a or 1)
                tex:SetGradient(orient, CR._defaultColorObj, CR._defaultColorObj)
            else 
                tex:SetGradient(orient, cColor.r, cColor.g, cColor.b, cColor.a or 1, cColor.r, cColor.g, cColor.b, cColor.a or 1) 
            end
        end
        
        if self.UpdateDividers then self:UpdateDividers(self.classBar, rawMax) end
        if self.FormatSafeText then self:FormatSafeText(self.classBar, specCfg.class, math_floor(safeCurr), rawMax, false, 0, specCfg.class.textEnable ~= false, nil, "class") end
        
        -- ▼▼▼ 新增：DK 并发切片逻辑 ▼▼▼
        if playerClass == "DEATHKNIGHT" and self.classBar.runes then
            -- 隐藏主条的填充材质，保留底色背景
            local mainTex = self.classBar.statusBar:GetStatusBarTexture()
            if mainTex then mainTex:SetAlpha(0) end
            
            local texPath = LSM:Fetch("statusbar", specCfg.class.texture or CR.GetDB().texture or "Wish2") or "Interface\\TargetingFrame\\UI-StatusBar"
            if specCfg.class.useCustomTexture and specCfg.class.texture then texPath = LSM:Fetch("statusbar", specCfg.class.texture) end
            
            local width = self.classBar.statusBar:GetWidth() or 250
            local height = self.classBar.statusBar:GetHeight() or 10
            local isVert = (self.classBar.statusBar:GetOrientation() == "VERTICAL")
            local segW = isVert and (height / 6) or (width / 6)
            
            local runeData = {}
            for i = 1, 6 do
                local start, duration, runeReady = GetRuneCooldown(i)
                table.insert(runeData, { id = i, start = start or 0, duration = duration or 0, ready = runeReady })
            end
            table.sort(runeData, function(a, b)
                if a.ready ~= b.ready then return a.ready end
                if a.start ~= b.start then return a.start < b.start end
                return a.id < b.id
            end)
            
            local sC = cColor; local eC = cColor
            if applyGrad and CR._gradColorCache then
                sC = CR._gradColorCache.startC or cColor
                eC = CR._gradColorCache.endC or cColor
            end
            local function LerpColor(c1, c2, t)
                return {
                    r = c1.r + (c2.r - c1.r) * t,
                    g = c1.g + (c2.g - c1.g) * t,
                    b = c1.b + (c2.b - c1.b) * t,
                    a = (c1.a or 1) + ((c2.a or 1) - (c1.a or 1)) * t
                }
            end
            
            for i = 1, 6 do
                local rBar = self.classBar.runes[i]
                local data = runeData[i]
                
                local val = 0
                if data.ready then
                    val = 1
                elseif data.start > 0 and data.duration > 0 then
                    val = math.max(0, math.min(1, (GetTime() - data.start) / data.duration))
                    self.hasActiveTimer = true
                end
                
                if rBar:GetStatusBarTexture() then rBar:GetStatusBarTexture():SetAlpha(0) end
                
                if not rBar.globalTex then
                    rBar.globalTex = rBar:CreateTexture(nil, "ARTWORK")
                end
                local gTex = rBar.globalTex
                gTex:SetTexture(texPath)
                gTex:SetHorizTile(false)
                gTex:SetVertTile(false)
                
                rBar:ClearAllPoints()
                if isVert then
                    rBar:SetSize(width, segW)
                    rBar:SetPoint("BOTTOMLEFT", self.classBar.statusBar, "BOTTOMLEFT", 0, (i-1)*segW)
                    
                    local curH = math.max(0.0001, val * segW)
                    gTex:SetSize(width, curH)
                    gTex:ClearAllPoints()
                    gTex:SetPoint("BOTTOMLEFT", rBar, "BOTTOMLEFT", 0, 0)
                    
                    local globalStartRatio = (i - 1) / 6
                    local globalEndRatio = (i - 1) / 6 + (val / 6)
                    gTex:SetTexCoord(0, 1, 1 - globalEndRatio, 1 - globalStartRatio)
                else
                    rBar:SetSize(segW, height)
                    rBar:SetPoint("BOTTOMLEFT", self.classBar.statusBar, "BOTTOMLEFT", (i-1)*segW, 0)
                    
                    local curW = math.max(0.0001, val * segW)
                    gTex:SetSize(curW, height)
                    gTex:ClearAllPoints()
                    gTex:SetPoint("BOTTOMLEFT", rBar, "BOTTOMLEFT", 0, 0)
                    
                    local globalStartRatio = (i - 1) / 6
                    local globalEndRatio = (i - 1) / 6 + (val / 6)
                    gTex:SetTexCoord(globalStartRatio, globalEndRatio, 0, 1)
                end
                
                local globalStartRatio = (i - 1) / 6
                local globalEndRatio = (i - 1) / 6 + (val / 6)
                local segStartC = LerpColor(sC, eC, globalStartRatio)
                local segEndC = LerpColor(sC, eC, globalEndRatio)
                
                -- 充能颜色覆盖逻辑
                if not data.ready and specCfg.class.useChargeColor and specCfg.class.chargeColor then
                    local chC = specCfg.class.chargeColor
                    segStartC = { r = chC.r, g = chC.g, b = chC.b, a = chC.a or 1 }
                    segEndC = { r = chC.r, g = chC.g, b = chC.b, a = chC.a or 1 }
                end
                
                local orient = isVert and "VERTICAL" or "HORIZONTAL"
                if CreateColor then
                    gTex:SetGradient(orient, CreateColor(segStartC.r, segStartC.g, segStartC.b, segStartC.a), CreateColor(segEndC.r, segEndC.g, segEndC.b, segEndC.a))
                else
                    gTex:SetGradient(orient, segStartC.r, segStartC.g, segStartC.b, segStartC.a, segEndC.r, segEndC.g, segEndC.b, segEndC.a)
                end
                
                if val > 0 then gTex:Show() else gTex:Hide() end
                rBar:Show()
            end
-- ▼▼▼ 替换为下面这段 ▼▼▼
        elseif self.classBar.statusBar:GetStatusBarTexture() then
            self.classBar.statusBar:GetStatusBarTexture():SetAlpha(1)
            if self.classBar.runes then
                for i = 1, 6 do 
                    self.classBar.runes[i]:Hide() 
                    if self.classBar.runes[i].globalTex then self.classBar.runes[i].globalTex:Hide() end
                end
            end
            
            -- 【核心魔法：为唤魔师、术士等生成专属的充能碎片贴图】
            if useGeneralCharge and isFractional then
                if not self.classBar.chargeTex then
                    self.classBar.chargeTex = self.classBar.statusBar:CreateTexture(nil, "ARTWORK")
                end
                local cTex = self.classBar.chargeTex
                
                local texPath = LSM:Fetch("statusbar", specCfg.class.texture or CR.GetDB().texture or "Wish2") or "Interface\\TargetingFrame\\UI-StatusBar"
                if specCfg.class.useCustomTexture and specCfg.class.texture then texPath = LSM:Fetch("statusbar", specCfg.class.texture) end
                cTex:SetTexture(texPath)
                cTex:SetHorizTile(false); cTex:SetVertTile(false)
                
                local chColor = specCfg.class.chargeColor
                cTex:SetVertexColor(chColor.r, chColor.g, chColor.b, chColor.a or 1)
                
                local width = self.classBar.statusBar:GetWidth() or 250
                local height = self.classBar.statusBar:GetHeight() or 10
                local isVert = (self.classBar.statusBar:GetOrientation() == "VERTICAL")
                
                local maxVal = rawMax > 0 and rawMax or 1
                local intPart = math_floor(rawCurr)
                local fracPart = rawCurr - intPart
                
                cTex:ClearAllPoints()
                if isVert then
                    local segH = height / maxVal
                    local curH = fracPart * segH
                    cTex:SetSize(width, curH)
                    -- 将充能贴图精准放置在已充满的整数点之上
                    cTex:SetPoint("BOTTOMLEFT", self.classBar.statusBar, "BOTTOMLEFT", 0, intPart * segH)
                    -- 切割对应的材质 UV，防止与主条材质产生割裂感
                    local startRatio = intPart / maxVal
                    local endRatio = startRatio + (fracPart / maxVal)
                    cTex:SetTexCoord(0, 1, 1 - endRatio, 1 - startRatio)
                else
                    local segW = width / maxVal
                    local curW = fracPart * segW
                    cTex:SetSize(curW, height)
                    -- 将充能贴图精准放置在已充满的整数点之右侧
                    cTex:SetPoint("BOTTOMLEFT", self.classBar.statusBar, "BOTTOMLEFT", intPart * segW, 0)
                    -- 切割对应的材质 UV
                    local startRatio = intPart / maxVal
                    local endRatio = startRatio + (fracPart / maxVal)
                    cTex:SetTexCoord(startRatio, endRatio, 0, 1)
                end
                cTex:Show()
            else
                -- 满资源或不需要充能色时隐藏贴片
                if self.classBar.chargeTex then self.classBar.chargeTex:Hide() end
            end
        end
        -- ▲▲▲ 替换结束 ▲▲▲
        -- ▲▲▲ 结束 ▲▲▲
        
        local isBrewmaster = (playerClass == "MONK" and CR.currentSpecID == 268)
        if isBrewmaster and self.classBar.text then
            if isConfigOpen then self.classBar.text:Show(); self.classBar.text:SetText("醉拳: 500k (50.0%)")
            elseif safeExtra > 0 then
                self.classBar.text:Show(); local maxHealth = UnitHealthMax("player")
                if not CR.IsSecret(maxHealth) then if maxHealth <= 0 then maxHealth = 1 end; local pct = (safeExtra / maxHealth) * 100; local stText = CR.SafeFormatNum(safeExtra); self.classBar.text:SetText(string.format("%s | %.1f%%", stText, pct)) end
            else self.classBar.text:Hide() end
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

local function InitClassResource()
    CR.GetDB()
    CR.baseAnchor = CR:CreateAnchor("WishFlex_BaseAnchor", "WishFlex: " .. (L["Global Layout Anchor"] or "全局排版起点"), -180, 10)
    CR.manaAnchor = CR:CreateAnchor("WishFlex_ManaAnchor", "WishFlex: [独立] " .. (L["Extra Mana Bar"] or "专属法力条"), -220, 10)
    CR.powerAnchor = CR:CreateAnchor("WishFlex_PowerAnchor", "WishFlex: [独立] " .. (L["Power Bar"] or "能量条"), -160, 10)
    CR.classAnchor = CR:CreateAnchor("WishFlex_ClassAnchor", "WishFlex: [独立] " .. (L["Class Resource Bar"] or "主资源条"), -140, 10)
    CR.vigorAnchor = CR:CreateAnchor("WishFlex_VigorAnchor", "WishFlex: [独立] " .. (L["Vigor Bar"] or "驭空术资源条"), -150, 10)
    CR.whirlingAnchor = CR:CreateAnchor("WishFlex_WhirlingAnchor", "WishFlex: [独立] " .. (L["Whirling Surge Bar"] or "回旋冲刺条"), -145, 4)

    if CR.CreateBarContainer then
        CR.powerBar = CR:CreateBarContainer("WishFlex_PowerBar", UIParent)
        CR.classBar = CR:CreateBarContainer("WishFlex_ClassBar", UIParent)
        CR.manaBar = CR:CreateBarContainer("WishFlex_ManaBar", UIParent)
        CR.vigorBar = CR:CreateBarContainer("WishFlex_VigorBar", UIParent)
        CR.whirlingBar = CR:CreateBarContainer("WishFlex_WhirlingBar", UIParent)
        CR.AllBars = {CR.powerBar, CR.classBar, CR.manaBar, CR.vigorBar, CR.whirlingBar}
    end
    
    CR.showPower, CR.showClass, CR.showMana, CR.showVigor, CR.showWhirling = false, false, false, false, false
    CR.isRendering = false; CR.idleTimer = 0; CR.sleepMode = false
    
    if not WF.db.classResource.enable then if CR.AllBars then for i = 1, #CR.AllBars do if CR.AllBars[i] then CR.AllBars[i]:Hide() end end end end
    
    if WF.RegisterEvent then
        WF:RegisterEvent("PLAYER_ENTERING_WORLD", function() 
            CR:WakeUp()
            CR:UpdateLayout()
            CR:TriggerVigorCheck()
            C_Timer.After(1.0, function() CR:UpdateFlightCaches(); CR:TriggerVigorCheck() end)
            C_Timer.After(2.5, function() CR:UpdateFlightCaches(); CR:TriggerVigorCheck() end)
            C_Timer.After(5.0, function() CR:UpdateFlightCaches(); CR:TriggerVigorCheck() end)
        end)
        
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
        
        WF:RegisterEvent("UNIT_AURA", function(e, unit) 
            if unit == "player" then 
                CR._auraCacheDirty = true
                if playerClass == "EVOKER" then CR:TriggerVigorCheck() end
                CR:WakeUp() 
            end 
        end)

        if playerClass == "DRUID" then WF:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function() CR:TriggerVigorCheck(); CR:WakeUp() end) end
    end

    C_Timer.After(0.8, function() CR:UpdateLayout() end); CR:OnContextChanged()
    
    local ticker = 0; CR.frameTick = 0
    local function SmoothBar(bar, elapsed)
        local isMoving = false
        if bar and bar.statusBar and not bar.isForceHidden then
            local sb = bar.statusBar
            if Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut then return false end
            if CR.IsSecret(sb._targetValue) then sb._currentValue = sb._targetValue; sb:SetValue(sb._targetValue)
            else
                local target = sb._targetValue or 0; local current = sb._currentValue or sb:GetValue() or 0; local diff = target - current
                if math_abs(diff) < 0.01 then sb._currentValue = target else local speed = (diff > 0) and 7 or 14; local safeElapsed = math_min(elapsed, 0.033); sb._currentValue = current + diff * speed * safeElapsed; isMoving = true end
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
        if CR.AllBars then for i = 1, #CR.AllBars do if SmoothBar(CR.AllBars[i], elapsed) then isAnimating = true end end end
        
        ticker = ticker + elapsed
        local interval = InCombatLockdown() and 0.02 or 0.04
        
        if WF.MoversUnlocked ~= CR._lastMoversState then
            CR._lastMoversState = WF.MoversUnlocked
            if WF.WishMonitorAPI and WF.WishMonitorAPI.TriggerUpdate then
                WF.WishMonitorAPI:TriggerUpdate()
            end
        end
        
        if WF.MoversUnlocked then CR:UpdateLayout() end

        if ticker >= interval then 
            ticker = 0; CR:DynamicTick()
            local hasActiveMonitors = (CR.ActiveMonitorFrames and #CR.ActiveMonitorFrames > 0)
            if not InCombatLockdown() and not isConfigOpen and not UnitExists("target") and not CR.hasActiveTimer and not isAnimating and not hasActiveMonitors and not CR.isVigorActive then 
                CR.idleTimer = CR.idleTimer + interval; if CR.idleTimer >= 2.0 then CR:GoToSleep() end
            else CR.idleTimer = 0 end 
        end
    end
    CR.baseAnchor:SetScript("OnUpdate", CR.ResourceOnUpdate)
end

function CR:RepositionMonitors()
    if WF.db and WF.db.classResource and WF.db.classResource.enable == false then return end
    if not self.ActiveMonitorFrames or not self.baseAnchor then return end 
    
    local isConfigOpen = false
    if WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown() then isConfigOpen = true end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then isConfigOpen = true end
    
    CR.AllCreatedAnchors = CR.AllCreatedAnchors or {}
    local activeAnchors = {}
    
    for _, f in ipairs(self.ActiveMonitorFrames) do
        if f.cfg.independent or f.cfg.displayMode == "text" then
            local anchorName = "WishFlex_WM_Anchor_" .. f.spellIDStr
            CR.AllCreatedAnchors[anchorName] = true
            activeAnchors[anchorName] = true
            
            if not _G[anchorName] then
                local actualID = f.cfg.realSpellID or tostring(f.spellID):gsub("_TXT", "")
                local spellInfo = nil; pcall(function() spellInfo = C_Spell.GetSpellInfo(tonumber(actualID)) end)
                local nameStr = spellInfo and spellInfo.name or f.spellIDStr
                CR:CreateAnchor(anchorName, "WishFlex: [独立/文本] " .. nameStr, 80, f.calcHeight or 20)
            end
            
            local mover = _G[anchorName.."Mover"] or _G[anchorName]
            if mover then
                mover._isDeletedMonitor = false
                if mover.textOverlayFrame then mover.textOverlayFrame:Hide() end
                
                mover:EnableMouse(false)
                mover:SetAlpha(0)
                if mover.SetBackdrop then pcall(mover.SetBackdrop, mover, nil) end
                for i=1, mover:GetNumRegions() do
                    local reg = select(i, mover:GetRegions())
                    if reg:IsObjectType("FontString") or reg:IsObjectType("Texture") then
                        reg:SetAlpha(0); reg:Hide()
                    end
                end
                
                if isConfigOpen then mover:Show() else mover:Hide() end
            end
            f:ClearAllPoints(); f:SetPoint("CENTER", mover, "CENTER", 0, 0)
            if f.cfg.displayMode ~= "text" then 
                f:SetSize(f.calcWidth, f.calcHeight) 
                if mover then mover:SetSize(f.calcWidth, f.calcHeight) end
            else 
                f:SetSize(60, 40)
                if mover then mover:SetSize(60, 40) end
            end
        end
    end
    
    local wmDB = WF.db and WF.db.wishMonitor or {}
    
    for anchorName, _ in pairs(CR.AllCreatedAnchors) do
        if not activeAnchors[anchorName] then
            local spellIDStr = anchorName:match("WishFlex_WM_Anchor_(.+)")
            if spellIDStr then
                local cfg = (wmDB.skills and wmDB.skills[spellIDStr]) or (wmDB.buffs and wmDB.buffs[spellIDStr])
                local mover = _G[anchorName.."Mover"] or _G[anchorName]
                
                if mover then
                    if cfg and (cfg.independent or cfg.displayMode == "text") then
                        mover._isDeletedMonitor = false
                        mover:EnableMouse(false)
                        mover:SetAlpha(0)
                        for i=1, mover:GetNumRegions() do
                            local reg = select(i, mover:GetRegions())
                            if reg:IsObjectType("FontString") or reg:IsObjectType("Texture") then reg:SetAlpha(0); reg:Hide() end
                        end
                        if isConfigOpen then mover:Show() else mover:Hide() end
                    else
                        mover._isDeletedMonitor = true; mover:Hide(); mover:SetAlpha(0); mover:EnableMouse(false)
                        if mover.textOverlayFrame then mover.textOverlayFrame:Hide() end
                        if not mover._WishFlexHookedShow then hooksecurefunc(mover, "Show", function(self) if self._isDeletedMonitor then self:Hide() end end); mover._WishFlexHookedShow = true end
                    end
                end
            end
        end
    end
    self:UpdateLayout()
end

WF:RegisterModule("classResource", L["Class Resource"] or "资源条", InitClassResource)