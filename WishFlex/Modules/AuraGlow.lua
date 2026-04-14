local AddonName, ns = ...
local WF = ns.WF
local L = ns.L

local LSM = LibStub("LibSharedMedia-3.0", true)
local LCG = LibStub("LibCustomGlow-1.0", true)

local AuraGlowMod = {}
WF.AuraGlowAPI = AuraGlowMod 

local BaseSpellCache = {}
local targetAuraCache = {}
local activeSkillFrames = {}
local activeBuffFrames = {}
local playerClass = select(2, UnitClass("player"))

local OverlayFrames = {}       
local IndependentFrames = {}   
AuraGlowMod.trackedAuras = {} 
AuraGlowMod.manualTrackers = {} 

AuraGlowMod._activeIndIcons = {}
AuraGlowMod._activeDirectGlows = {} 
AuraGlowMod._durObj = {}

local SKILL_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer" }
local BUFF_VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }
local AURA_FILTERS = { "HELPFUL", "HARMFUL" }

local updatePending = false
local UpdateDispatcher = CreateFrame("Frame")
UpdateDispatcher:Hide()
UpdateDispatcher:SetScript("OnUpdate", function(self)
    self:Hide()
    updatePending = false
    AuraGlowMod:UpdateGlows()
end)

local function RequestUpdateGlows() 
    if updatePending then return end
    updatePending = true
    UpdateDispatcher:Show() 
end
AuraGlowMod.RequestUpdateGlows = RequestUpdateGlows

local AuraTrackerTicker = CreateFrame("Frame")
local lastTick = 0
AuraTrackerTicker:SetScript("OnUpdate", function(self, elapsed)
    if not AuraGlowMod.manualTrackers or not next(AuraGlowMod.manualTrackers) then return end
    lastTick = lastTick + elapsed
    if lastTick >= 0.1 then
        lastTick = 0
        local now = GetTime()
        local expired = false
        for bID, tracker in pairs(AuraGlowMod.manualTrackers) do
            if now >= (tracker.start + tracker.dur) then
                AuraGlowMod.manualTrackers[bID] = nil
                expired = true
            end
        end
        if expired then RequestUpdateGlows() end
    end
end)

local FrameGlowStates = setmetatable({}, {__mode = "k"})

local DefaultConfig = {
    enable = true,
    independent = { size = 45, gap = 2, growth = "LEFT" },
    text = { font = "Expressway", fontSize = 20, fontOutline = "OUTLINE", color = {r = 1, g = 0.82, b = 0}, textAnchor = "CENTER", offsetX = 0, offsetY = 0 },
    independentText = { enable = false, font = "Expressway", fontSize = 20, fontOutline = "OUTLINE", color = {r = 1, g = 0.82, b = 0}, textAnchor = "CENTER", offsetX = 0, offsetY = 0 },
    glowEnable = true, glowType = "pixel", glowUseCustomColor = false, 
    glowColor = {r = 1, g = 1, b = 1, a = 1},
    glowPixelLines = 8, glowPixelFrequency = 0.25, glowPixelLength = 0, 
    glowPixelThickness = 1,
    glowPixelXOffset = 0, glowPixelYOffset = 0,
    glowAutocastParticles = 4, glowAutocastFrequency = 0.2, glowAutocastScale = 1, glowAutocastXOffset = 0, glowAutocastYOffset = 0,
    glowButtonFrequency = 0, glowProcDuration = 1, glowProcXOffset = 0, glowProcYOffset = 0,
    spells = {} 
}

local dbInitialized = false
local cachedDB = nil

local function GetDB()
    if dbInitialized and cachedDB then return cachedDB end
    
    if not WF.db.auraGlow then WF.db.auraGlow = {} end
    local db = WF.db.auraGlow
    for k, v in pairs(DefaultConfig) do if db[k] == nil then db[k] = v end end
    for k, v in pairs(DefaultConfig.independent) do if db.independent[k] == nil then db.independent[k] = v end end
    for k, v in pairs(DefaultConfig.text) do if db.text[k] == nil then db.text[k] = v end end
    for k, v in pairs(DefaultConfig.independentText) do if db.independentText[k] == nil then db.independentText[k] = v end end
    if type(db.spells) ~= "table" then db.spells = {} end

    if WF.DefaultPresets and not db._presetsInjected then
        db._presetsInjected = true
        local function gather(group) 
            if not group then return end
            for _, p in ipairs(group) do 
                if p.type == "buff" or p.type == "skill" then 
                    local sidStr = tostring(p.id)
                    if not db.spells[sidStr] and not (db.disabledPresets and db.disabledPresets[sidStr]) then
                        db.spells[sidStr] = {
                            class = playerClass,
                            spec = 0,
                            glowEnable = (p.glowEnable ~= false),
                            iconEnable = (p.iconEnable == true),
                            iconGlowEnable = (p.iconGlowEnable ~= false),
                            useOverlay = p.useOverlay or false,
                            buffID = p.buffID,
                            duration = p.duration,
                            hideOriginal = false
                        }
                    elseif db.spells[sidStr] then
                        if db.spells[sidStr].hideOriginal == nil then db.spells[sidStr].hideOriginal = false end
                    end
                end
            end
        end
        if WF.DefaultPresets["ALL"] then gather(WF.DefaultPresets["ALL"][0], 0) end
        if WF.DefaultPresets[playerClass] then 
            for specID, group in pairs(WF.DefaultPresets[playerClass]) do gather(group, specID) end
        end
    end
    
    if not db._hideOriginalMigrated then
        for _, sData in pairs(db.spells) do
            sData.hideOriginal = false
        end
        db._hideOriginalMigrated = true
    end

    if WF.DefaultPresets then
        local function forceSync(group)
            if not group then return end
            for _, p in ipairs(group) do
                if (p.type == "buff" or p.type == "skill") and p.useOverlay ~= nil then
                    local sidStr = tostring(p.id)
                    if db.spells[sidStr] then
                        db.spells[sidStr].useOverlay = p.useOverlay
                    end
                end
            end
        end
        if WF.DefaultPresets["ALL"] then forceSync(WF.DefaultPresets["ALL"][0]) end
        if WF.DefaultPresets[playerClass] then
            for specID, group in pairs(WF.DefaultPresets[playerClass]) do forceSync(group) end
        end
    end

    dbInitialized = true
    cachedDB = db
    return db
end

function AuraGlowMod:InvalidateDB()
    dbInitialized = false
    cachedDB = nil
end

local function IsSafeValue(val) return val ~= nil and (type(issecretvalue) ~= "function" or not issecretvalue(val)) end
local function GetBaseSpellFast(spellID)
    if not IsSafeValue(spellID) then return nil end
    if BaseSpellCache[spellID] == nil then
        local base = spellID
        pcall(function() if C_Spell and C_Spell.GetBaseSpell then base = C_Spell.GetBaseSpell(spellID) or spellID end end)
        BaseSpellCache[spellID] = base
    end
    return BaseSpellCache[spellID]
end

local function MatchesSpellID(info, targetID)
    if not info then return false end
    if IsSafeValue(info.spellID) and (info.spellID == targetID or info.overrideSpellID == targetID) then return true end
    if info.linkedSpellIDs then for i = 1, #info.linkedSpellIDs do if IsSafeValue(info.linkedSpellIDs[i]) and info.linkedSpellIDs[i] == targetID then return true end end end
    return GetBaseSpellFast(info.spellID) == targetID
end

local function VerifyAuraAlive(checkID, checkUnit)
    if not IsSafeValue(checkID) then return false end
    return C_UnitAuras.GetAuraDataByAuraInstanceID(checkUnit, checkID) ~= nil
end

local function GetCropCoords(w, h)
    local l, r, t, b = 0.08, 0.92, 0.08, 0.92
    if not w or not h or h == 0 or w == 0 then return l, r, t, b end
    local ratio = w / h
    if math.abs(ratio - 1) < 0.05 then return l, r, t, b end
    if ratio > 1 then local crop = (1 - (1/ratio)) / 2; return l, r, t + (b - t) * crop, b - (b - t) * crop
    else local crop = (1 - ratio) / 2; return l + (r - l) * crop, r - (r - l) * crop, t, b end
end

local function EnsureAuraGlowHost(frame)
    local target = frame.wishBd or frame
    if frame.Icon and type(frame.Icon) == "table" then
        if frame.Icon.wishBd then target = frame.Icon.wishBd
        elseif frame.Icon.Icon and frame.Icon.Icon.wishBd then target = frame.Icon.Icon.wishBd end
    end

    local host = frame.wfGlowHost
    if not host then
        host = CreateFrame("Frame", nil, target)
        host:SetClampedToScreen(false)
        frame.wfGlowHost = host
    end

    if host:GetParent() ~= target then host:SetParent(target) end
    host:ClearAllPoints()
    host:SetAllPoints(target)
    
    host:SetFrameLevel((target:GetFrameLevel() or 1) + 5)
    return host, target
end

local DEFAULT_GLOW_COLOR = {r=1, g=1, b=1, a=1}
local sharedColorArr = {1, 1, 1, 1}
local sharedProcOpts = {color = nil, duration = 1, xOffset = 0, yOffset = 0, key = "", frameLevel = 0}

local function ApplyCustomGlowToFrame(frame, glowKey)
    local cfg = GetDB()
    if not LCG then return end
    
    local host, target = EnsureAuraGlowHost(frame)
    
    local w, h = target:GetWidth(), target:GetHeight()
    local rectX, rectY, rectW, rectH = target:GetRect()
    
    -- 【核心修复：防小光点】使用 GetRect 抓取屏幕真实的物理渲染尺寸。
    if not rectW or not rectH or rectW < 10 or rectH < 10 then
        frame._agRetries = (frame._agRetries or 0) + 1
        if frame._agRetries < 30 then 
            C_Timer.After(0.2, function()
                if frame and FrameGlowStates[frame] and FrameGlowStates[frame][glowKey] then
                    ApplyCustomGlowToFrame(frame, glowKey)
                end
            end)
        end
        return
    end
    frame._agRetries = 0

    LCG.PixelGlow_Stop(host, glowKey); LCG.AutoCastGlow_Stop(host, glowKey); LCG.ButtonGlow_Stop(host); LCG.ProcGlow_Stop(host, glowKey)
    if not cfg.glowEnable then return end
    
    local c = cfg.glowColor or DEFAULT_GLOW_COLOR
    local colorArr = nil
    if cfg.glowUseCustomColor then
        sharedColorArr[1] = c.r or 1
        sharedColorArr[2] = c.g or 1
        sharedColorArr[3] = c.b or 1
        sharedColorArr[4] = c.a or 1
        colorArr = sharedColorArr
    end
    
    local t = cfg.glowType or "pixel"
    
    if t == "pixel" then
        local len = tonumber(cfg.glowPixelLength) or 0; if len == 0 then len = nil end
        local thick = tonumber(cfg.glowPixelThickness) or 1
        LCG.PixelGlow_Start(host, colorArr, tonumber(cfg.glowPixelLines) or 8, tonumber(cfg.glowPixelFrequency) or 0.25, len, thick, tonumber(cfg.glowPixelXOffset) or 0, tonumber(cfg.glowPixelYOffset) or 0, false, glowKey, 0)
    elseif t == "autocast" then 
        LCG.AutoCastGlow_Start(host, colorArr, tonumber(cfg.glowAutocastParticles) or 4, tonumber(cfg.glowAutocastFrequency) or 0.2, tonumber(cfg.glowAutocastScale) or 1, tonumber(cfg.glowAutocastXOffset) or 0, tonumber(cfg.glowAutocastYOffset) or 0, glowKey, 0)
    elseif t == "button" then 
        local freq = tonumber(cfg.glowButtonFrequency) or 0; if freq == 0 then freq = nil end; LCG.ButtonGlow_Start(host, colorArr, freq, 0)
    elseif t == "proc" then 
        sharedProcOpts.color = colorArr
        sharedProcOpts.duration = tonumber(cfg.glowProcDuration) or 1
        sharedProcOpts.xOffset = tonumber(cfg.glowProcXOffset) or 0
        sharedProcOpts.yOffset = tonumber(cfg.glowProcYOffset) or 0
        sharedProcOpts.key = glowKey
        LCG.ProcGlow_Start(host, sharedProcOpts) 
    end
end

local function ToggleGlow(frame, glowKey, shouldGlow, forceRefresh)
    if not frame or not LCG then return end
    
    if not FrameGlowStates[frame] then FrameGlowStates[frame] = {} end
    local currentState = FrameGlowStates[frame][glowKey]
    
    if shouldGlow then 
        if not currentState or forceRefresh then 
            FrameGlowStates[frame][glowKey] = true
            ApplyCustomGlowToFrame(frame, glowKey) 
        end
    else 
        if currentState ~= false then
            FrameGlowStates[frame][glowKey] = false 
            frame._agRetries = 0 
            if LCG and frame.wfGlowHost then 
                LCG.PixelGlow_Stop(frame.wfGlowHost, glowKey)
                LCG.AutoCastGlow_Stop(frame.wfGlowHost, glowKey)
                LCG.ButtonGlow_Stop(frame.wfGlowHost)
                LCG.ProcGlow_Stop(frame.wfGlowHost, glowKey) 
            end
        end
    end
end

local SharedDefaultColor = {r=1, g=0.82, b=0}

function AuraGlowMod:ApplyPreview(frame, spellID, isInd, useOverlay)
    local db = GetDB(); local sDB = db.spells[tostring(spellID)] or {}
    local shouldGlow = isInd and (sDB.iconGlowEnable ~= false) or sDB.glowEnable
    ToggleGlow(frame, "WishAuraPreviewGlow", shouldGlow, true)
    if not frame.agDurationText then frame.agDurationText = frame:CreateFontString(nil, "OVERLAY") end
    if not isInd and not useOverlay then frame.agDurationText:Hide(); return end

    if shouldGlow or isInd then
        local tCfg = (isInd and db.independentText.enable) and db.independentText or db.text
        local fontPath = (LSM and LSM:Fetch("font", tCfg.font or "Expressway")) or STANDARD_TEXT_FONT
        local fSize = tonumber(tCfg.fontSize) or 20
        frame.agDurationText:SetFont(fontPath, fSize, tCfg.fontOutline or "OUTLINE"); frame.agDurationText:SetText("12.5"); frame.agDurationText:Show()
        local c = tCfg.color or SharedDefaultColor; frame.agDurationText:SetTextColor(c.r, c.g, c.b)
        frame.agDurationText:ClearAllPoints(); local anc = tCfg.textAnchor or "CENTER"; local ox, oy = tonumber(tCfg.offsetX) or 0, tonumber(tCfg.offsetY) or 0
        frame.agDurationText:SetPoint(anc, frame, anc, ox, oy)
    else frame.agDurationText:Hide() end
end

local function SnapOverlayToFrame(overlay, sourceFrame)
    if sourceFrame and sourceFrame:GetCenter() then
        local cx, cy = sourceFrame:GetCenter()
        if cx and cy then
            local scale = sourceFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local rawW = sourceFrame:GetWidth() or 45
            local rawH = sourceFrame:GetHeight() or 45
            if rawW < 1 or rawH < 1 then rawW, rawH = 45, 45 end
            
            local targetX, targetY = cx / scale, cy / scale
            local targetLevel = sourceFrame:GetFrameLevel() + 20

            if overlay._lastX ~= targetX or overlay._lastY ~= targetY or overlay._lastW ~= rawW or overlay._lastH ~= rawH or overlay._lastScale ~= scale or overlay._lastLevel ~= targetLevel then
                overlay._lastX, overlay._lastY = targetX, targetY
                overlay._lastW, overlay._lastH = rawW, rawH
                overlay._lastScale = scale
                overlay._lastLevel = targetLevel

                overlay:SetScale(scale); overlay:SetSize(rawW, rawH)
                if overlay.iconTex then overlay.iconTex:SetTexCoord(GetCropCoords(rawW, rawH)) end
                overlay:ClearAllPoints(); overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", targetX, targetY)
                overlay:SetFrameStrata("HIGH"); overlay:SetFrameLevel(targetLevel)
                if overlay.cd then overlay.cd:SetFrameLevel(targetLevel + 1) end
            end
            return true
        end
    end
    return false
end

local function SyncTextAndVisuals(frame, overrideCfg)
    local db = GetDB(); local cfg = overrideCfg or ((frame.isIndependent and db.independentText.enable) and db.independentText or db.text)
    frame.durationText:SetAlpha(1); frame.cd:SetHideCountdownNumbers(false)
    local fontPath = (LSM and LSM:Fetch('font', cfg.font)) or STANDARD_TEXT_FONT
    local fSize = tonumber(cfg.fontSize) or 20
    if frame.lastFont ~= fontPath or frame.lastSize ~= fSize or frame.lastOutline ~= cfg.fontOutline then
        frame.durationText:SetFont(fontPath, fSize, cfg.fontOutline or "OUTLINE")
        frame.lastFont, frame.lastSize, frame.lastOutline = fontPath, fSize, cfg.fontOutline
    end
    local c = cfg.color or SharedDefaultColor
    if frame.lastR ~= c.r or frame.lastG ~= c.g or frame.lastB ~= c.b then frame.durationText:SetTextColor(c.r, c.g, c.b); frame.lastR, frame.lastG, frame.lastB = c.r, c.g, c.b end
    local anchor = cfg.textAnchor or "CENTER"; local ox, oy = tonumber(cfg.offsetX) or 0, tonumber(cfg.offsetY) or 0
    if frame.lastOffsetX ~= ox or frame.lastOffsetY ~= oy or frame.lastAnchor ~= anchor then
        frame.durationText:ClearAllPoints(); frame.durationText:SetPoint(anchor, frame, anchor, ox, oy)
        frame.lastOffsetX, frame.lastOffsetY, frame.lastAnchor = ox, oy, anchor
    end
end

-- 【核心修复：遮罩图标根据底图透明度隐藏】
local function OverlayOnUpdate(self) 
    if self.sourceFrame then
        local targetAlpha = self.sourceFrame.SmartHideTargetAlpha or self.sourceFrame:GetEffectiveAlpha() or 1
        if self.sourceFrame:IsShown() and targetAlpha > 0 and self.sourceFrame:GetCenter() then
            self:SetAlpha(targetAlpha)
            SnapOverlayToFrame(self, self.sourceFrame)
            SyncTextAndVisuals(self)
        else
            self:SetAlpha(0)
        end
    else 
        self:SetAlpha(0) 
    end 
end

-- 【核心修复：独立图标兼容脱战隐藏设置】
local function IndependentOnUpdate(self) 
    local targetAlpha = 1
    if WF.SmartFader then
        local inEditMode = WF.MoversUnlocked or (WF.MainFrame and WF.MainFrame:IsShown())
        if not inEditMode then
            local inCombat = InCombatLockdown()
            local hasTarget = UnitExists("target")
            if hasTarget then hasTarget = UnitCanAttack("player", "target") or UnitIsPlayer("target") end
            if not inCombat and not hasTarget then targetAlpha = 0 end
        end
    end
    
    self:SetAlpha(targetAlpha)
    if targetAlpha > 0 then 
        SyncTextAndVisuals(self) 
    end 
end

local function CreateBaseFrame(spellID, isIndependent)
    local frame = CreateFrame("Frame", nil, UIParent, isIndependent and "BackdropTemplate" or nil)
    frame:SetFrameStrata("HIGH"); frame.isIndependent = isIndependent
    if isIndependent then frame:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1}); frame:SetBackdropBorderColor(0, 0, 0, 1) end
    local iconTex = frame:CreateTexture(nil, "ARTWORK"); iconTex:SetAllPoints(frame)
    if isIndependent then iconTex:SetPoint("TOPLEFT", 1, -1); iconTex:SetPoint("BOTTOMRIGHT", -1, 1) end
    
    if C_Spell and C_Spell.GetSpellInfo then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo and spellInfo.iconID then iconTex:SetTexture(spellInfo.iconID) end
    end
    frame.iconTex = iconTex
    
    local cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cd:SetAllPoints(); cd:SetDrawSwipe(true); cd:SetReverse(true); cd:SetDrawEdge(false); cd:SetDrawBling(false)
    if not isIndependent then cd.noCooldownCount = true; cd.noOCC = true; cd.skipElvUICooldown = true end
    frame.cd = cd
    
    for _, region in pairs({cd:GetRegions()}) do if region:IsObjectType("FontString") then frame.durationText = region break end end
    if not frame.durationText then frame.durationText = cd:CreateFontString(nil, "OVERLAY") end
    return frame
end

local function GetOverlay(spellID)
    if not OverlayFrames[spellID] then OverlayFrames[spellID] = CreateBaseFrame(spellID, false); OverlayFrames[spellID]:SetScript("OnUpdate", OverlayOnUpdate) end
    return OverlayFrames[spellID]
end
local function GetIndependentIcon(spellID)
    if not IndependentFrames[spellID] then IndependentFrames[spellID] = CreateBaseFrame(spellID, true); IndependentFrames[spellID]:SetScript("OnUpdate", IndependentOnUpdate) end
    return IndependentFrames[spellID]
end

local cacheCurrentActiveDirect = {}

function AuraGlowMod:UpdateGlows(forceUpdate)
    local db = GetDB()
    if not self._activeDirectGlows then self._activeDirectGlows = {} end
    
    wipe(cacheCurrentActiveDirect)
    local currentActiveDirect = cacheCurrentActiveDirect

    if not db.enable then 
        for frame, glowKey in pairs(self._activeDirectGlows) do ToggleGlow(frame, glowKey, false, true) end
        wipe(self._activeDirectGlows)
        for _, f in pairs(OverlayFrames) do ToggleGlow(f, "WishAuraOverlayGlow", false, true); f:Hide() end
        for _, f in pairs(IndependentFrames) do ToggleGlow(f, "WishAuraIndGlow", false, true); f:Hide() end
        return 
    end
    
    wipe(activeSkillFrames); wipe(activeBuffFrames); wipe(targetAuraCache); wipe(AuraGlowMod._activeIndIcons)
    local activeIndependentIcons = AuraGlowMod._activeIndIcons

    for _, vName in ipairs(SKILL_VIEWERS) do
        local viewer = _G[vName]
        if viewer and viewer.itemFramePool then
            for f in viewer.itemFramePool:EnumerateActive() do 
                if f.cooldownInfo then activeSkillFrames[#activeSkillFrames+1] = f end 
            end
        end
    end
    for _, vName in ipairs(BUFF_VIEWERS) do
        local viewer = _G[vName]
        if viewer and viewer.itemFramePool then
            for f in viewer.itemFramePool:EnumerateActive() do 
                if f.cooldownInfo then activeBuffFrames[#activeBuffFrames+1] = f end 
            end
        end
    end

    local targetScanned = false
    local currentSpecID = 0
    if GetSpecialization then
        local spec = GetSpecialization()
        if spec then currentSpecID = GetSpecializationInfo(spec) or 0 end
    end

    for spellIDStr, spellData in pairs(db.spells) do
        local spellID = tonumber(spellIDStr)
        if (not spellData.class or spellData.class == "ALL" or spellData.class == playerClass) then
            local sSpec = tonumber(spellData.spec) or 0
            if sSpec == 0 or sSpec == currentSpecID then
                local wantGlow = spellData.glowEnable; local wantIcon = spellData.iconEnable; local wantIconGlow = spellData.iconGlowEnable ~= false 
                local useOverlay = spellData.useOverlay
                if wantGlow or wantIcon then
                    local buffID = tonumber(spellData.buffID) or spellID
                    local customDuration = tonumber(spellData.duration) or 0
                    
                    local skillFrame = nil
                    local buffGlowFrame = nil
                    
                    if wantGlow then 
                        for i = 1, #activeSkillFrames do if MatchesSpellID(activeSkillFrames[i].cooldownInfo, spellID) then skillFrame = activeSkillFrames[i]; break end end
                        for i = 1, #activeBuffFrames do if MatchesSpellID(activeBuffFrames[i].cooldownInfo, buffID) then buffGlowFrame = activeBuffFrames[i]; break end end
                    end

                    if wantIcon or (wantGlow and (skillFrame or buffGlowFrame)) then
                        local auraActive, auraInstanceID, unit = false, nil, "player"
                        if customDuration > 0 then
                            local tracker = self.manualTrackers[buffID]
                            if tracker and GetTime() < (tracker.start + tracker.dur) then auraActive = true else self.manualTrackers[buffID] = nil end
                        else
                            local buffFrame = nil
                            for i = 1, #activeBuffFrames do if MatchesSpellID(activeBuffFrames[i].cooldownInfo, buffID) then buffFrame = activeBuffFrames[i]; break end end
                            if buffFrame then
                                local tempID = buffFrame.auraInstanceID; local tempUnit = buffFrame.auraDataUnit or "player"
                                if IsSafeValue(tempID) and VerifyAuraAlive(tempID, tempUnit) then auraInstanceID, unit, auraActive = tempID, tempUnit, true; self.trackedAuras[buffID] = self.trackedAuras[buffID] or {}; self.trackedAuras[buffID].id = auraInstanceID; self.trackedAuras[buffID].unit = unit end
                            end
                            if not auraActive and self.trackedAuras[buffID] then
                                local t = self.trackedAuras[buffID]; if VerifyAuraAlive(t.id, t.unit) then auraActive, auraInstanceID, unit = true, t.id, t.unit else self.trackedAuras[buffID] = nil end
                            end
                            if not auraActive then
                                local auraData = C_UnitAuras.GetPlayerAuraBySpellID(buffID)
                                if auraData and IsSafeValue(auraData.auraInstanceID) then
                                    auraActive, auraInstanceID, unit = true, auraData.auraInstanceID, "player"
                                    self.trackedAuras[buffID] = self.trackedAuras[buffID] or {}; self.trackedAuras[buffID].id = auraInstanceID; self.trackedAuras[buffID].unit = unit
                                elseif UnitExists("target") then
                                    if not targetScanned then targetScanned = true; for _, filter in ipairs(AURA_FILTERS) do for i = 1, 40 do local aura = C_UnitAuras.GetAuraDataByIndex("target", i, filter); if not aura then break end; if IsSafeValue(aura.spellId) and IsSafeValue(aura.auraInstanceID) then targetAuraCache[aura.spellId] = aura.auraInstanceID end end end end
                                    if targetAuraCache[buffID] then auraActive, auraInstanceID, unit = true, targetAuraCache[buffID], "target"; self.trackedAuras[buffID] = self.trackedAuras[buffID] or {}; self.trackedAuras[buffID].id = auraInstanceID; self.trackedAuras[buffID].unit = unit end
                                end
                            end
                        end
                        
                        if auraActive then
                            local durObj = nil
                            if customDuration > 0 then
                                local tracker = self.manualTrackers[buffID]
                                if tracker then durObj = AuraGlowMod._durObj; durObj.start = tracker.start; durObj.dur = tracker.dur end
                            elseif auraInstanceID then durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID) end

                            if wantIcon then
                                local indIcon = GetIndependentIcon(spellID)
                                local s = tonumber(db.independent.size) or 45
                                indIcon:SetSize(s, s) 
                                indIcon:Show()
                                if durObj and durObj.dur then indIcon.cd:SetCooldown(durObj.start, durObj.dur) elseif durObj and indIcon.cd.SetCooldownFromDurationObject then indIcon.cd:SetCooldownFromDurationObject(durObj) end
                                ToggleGlow(indIcon, "WishAuraIndGlow", wantIconGlow, forceUpdate); activeIndependentIcons[#activeIndependentIcons+1] = indIcon
                            else if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end end

                            if wantGlow then
                                if skillFrame then
                                    if useOverlay then
                                        local overlay = GetOverlay(spellID); overlay.sourceFrame = skillFrame
                                        overlay:Show()
                                        if durObj and durObj.dur then overlay.cd:SetCooldown(durObj.start, durObj.dur) elseif durObj and overlay.cd.SetCooldownFromDurationObject then overlay.cd:SetCooldownFromDurationObject(durObj) end
                                        ToggleGlow(overlay, "WishAuraOverlayGlow", true, forceUpdate)
                                    else
                                        if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                                        currentActiveDirect[skillFrame] = "WishAuraDirectGlow"
                                        ToggleGlow(skillFrame, "WishAuraDirectGlow", true, forceUpdate)
                                    end
                                else
                                    if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end 
                                end
                                
                                if buffGlowFrame then
                                    currentActiveDirect[buffGlowFrame] = "WishAuraDirectGlow"
                                    ToggleGlow(buffGlowFrame, "WishAuraDirectGlow", true, forceUpdate)
                                end
                            else
                                if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end 
                            end
                        else
                            if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); if OverlayFrames[spellID].cd then OverlayFrames[spellID].cd:Clear() end; OverlayFrames[spellID]:Hide() end
                            if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); if IndependentFrames[spellID].cd then IndependentFrames[spellID].cd:Clear() end; IndependentFrames[spellID]:Hide() end
                        end
                    else
                        if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                        if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
                    end
                else
                    if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                    if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
                end
            else
                if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
            end
        else
            if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
            if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
        end
    end

    for frame, glowKey in pairs(self._activeDirectGlows) do
        if not currentActiveDirect[frame] then
            ToggleGlow(frame, glowKey, false, forceUpdate)
            self._activeDirectGlows[frame] = nil
        end
    end
    
    for frame, glowKey in pairs(currentActiveDirect) do
        self._activeDirectGlows[frame] = glowKey
    end

    if self.AuraGlowAnchor then
        local cfg = db.independent
        local s = tonumber(cfg.size) or 45; local gap = tonumber(cfg.gap) or 2; local growth = cfg.growth or "LEFT"
        local numIcons = #activeIndependentIcons; local startX = 0
        if growth == "CENTER_HORIZONTAL" and numIcons > 0 then local totalWidth = (numIcons * s) + ((numIcons - 1) * gap); startX = - (totalWidth / 2) + (s / 2) end
        
        for i, icon in ipairs(activeIndependentIcons) do
            icon:ClearAllPoints(); icon:SetScale(1); icon:SetSize(s, s)
            if icon.iconTex then icon.iconTex:SetTexCoord(GetCropCoords(s, s)) end
            
            if growth == "CENTER_HORIZONTAL" then 
                local idealX = startX + (i - 1) * (s + gap)
                local leftEdge = math.floor(idealX - s/2 + 0.5) 
                local snappedX = leftEdge + s/2
                icon:SetPoint("CENTER", self.AuraGlowAnchor, "CENTER", snappedX, 0)
            else
                if i == 1 then 
                    local leftEdge = math.floor(0 - s/2 + 0.5)
                    local snappedX = leftEdge + s/2
                    icon:SetPoint("CENTER", self.AuraGlowAnchor, "CENTER", snappedX, 0)
                else
                    local prev = activeIndependentIcons[i-1]
                    if growth == "LEFT" then icon:SetPoint("RIGHT", prev, "LEFT", -gap, 0) 
                    elseif growth == "RIGHT" then icon:SetPoint("LEFT", prev, "RIGHT", gap, 0) 
                    elseif growth == "UP" then icon:SetPoint("BOTTOM", prev, "TOP", 0, gap) 
                    elseif growth == "DOWN" then icon:SetPoint("TOP", prev, "BOTTOM", 0, -gap) end
                end
            end
        end
    end
end

local function SafeHook(object, funcName, callback)
    if object and object[funcName] and type(object[funcName]) == "function" then hooksecurefunc(object, funcName, callback) end
end

AuraGlowMod.ExpandState = { global = false, edit = false }
AuraGlowMod.CurrentSelectedSpell = nil

function AuraGlowMod:RenderOptions(scrollChild, rightX, rightY, rightColW, callback)
    local db = GetDB()
    local y = rightY
    local ColW = rightColW

    local btnGlobal, cy = WF.UI.Factory:CreateGroupHeader(scrollChild, rightX, y, ColW, "高亮核心设定", AuraGlowMod.ExpandState.global, function() AuraGlowMod.ExpandState.global = not AuraGlowMod.ExpandState.global; callback("UI_REFRESH") end)

    if AuraGlowMod.ExpandState.global then
        local globalOpts = {
            { type = "toggle", key = "enable", db = db, text = "启用技能状态高亮" },
            { type = "dropdown", key = "glowType", db = db, text = "默认高亮样式", options = { {text="像素框", value="pixel"}, {text="自闭动画", value="autocast"}, {text="暴雪默认边框", value="button"} } },
            { type = "color", key = "glowColor", db = db, text = "默认像素框颜色" },
        }
        cy = WF.UI:RenderOptionsGroup(scrollChild, rightX, cy, ColW, globalOpts, function() callback("GLOW_UPDATE") end)
    end

    local list = {}
    for spellID, cfg in pairs(db.spells) do
        local si; pcall(function() si = C_Spell.GetSpellInfo(tonumber(spellID)) end)
        table.insert(list, { id = spellID, name = si and si.name or spellID, icon = si and si.iconID or 134400 })
    end
    table.sort(list, function(a, b) return a.name < b.name end)

    local ICON_SIZE, PADDING = 36, 6
    local MAX_COLS = math.floor(ColW / (ICON_SIZE + PADDING))

    if not scrollChild.AG_GridPool then scrollChild.AG_GridPool = {} end
    for _, btn in ipairs(scrollChild.AG_GridPool) do btn:Hide() end

    local row, col = 0, 0
    for i, item in ipairs(list) do
        local btn = scrollChild.AG_GridPool[i]
        if not btn then
            btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            btn:SetSize(ICON_SIZE, ICON_SIZE); btn:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
            local tex = btn:CreateTexture(nil, "BACKGROUND"); tex:SetPoint("TOPLEFT", 1, -1); tex:SetPoint("BOTTOMRIGHT", -1, 1)
            tex:SetTexCoord(0.1, 0.9, 0.1, 0.9); btn.tex = tex; btn:RegisterForClicks("AnyUp")
            scrollChild.AG_GridPool[i] = btn
        end
        btn:ClearAllPoints(); btn:SetPoint("TOPLEFT", rightX + col * (ICON_SIZE + PADDING), cy - row * (ICON_SIZE + PADDING))
        btn.tex:SetTexture(item.icon)
        if AuraGlowMod.CurrentSelectedSpell == item.id then btn:SetBackdropBorderColor(0.2, 0.6, 1, 1) else btn:SetBackdropBorderColor(0, 0, 0, 1) end

        btn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then db.spells[item.id] = nil; if AuraGlowMod.CurrentSelectedSpell == item.id then AuraGlowMod.CurrentSelectedSpell = nil end
            else AuraGlowMod.CurrentSelectedSpell = item.id end
            callback("GLOW_UPDATE"); C_Timer.After(0.05, function() callback("UI_REFRESH") end)
        end)
        btn:SetScript("OnEnter", function() GameTooltip:SetOwner(btn, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(tonumber(item.id)); GameTooltip:AddLine(" "); GameTooltip:AddLine("|cff00ffcc[左键]|r 编辑", 1,1,1); GameTooltip:AddLine("|cffffaa00[右键]|r 删除", 1,1,1); GameTooltip:Show() end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:Show()
        col = col + 1; if col >= MAX_COLS then col = 0; row = row + 1 end
    end

    local gridH = (#list > 0) and ((col == 0 and row or row + 1) * (ICON_SIZE + PADDING)) or 0
    cy = cy - gridH - 15

    local editBox = scrollChild.AG_EditBox
    if not editBox then
        editBox = CreateFrame("EditBox", nil, scrollChild, "BackdropTemplate"); editBox:SetSize(120, 24); editBox:SetAutoFocus(false)
        editBox:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); editBox:SetTextInsets(5, 5, 0, 0); editBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        editBox:SetBackdropColor(0.05, 0.05, 0.05, 1); editBox:SetBackdropBorderColor(0, 0, 0, 1)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end); editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        scrollChild.AG_EditBox = editBox
    end
    editBox:SetParent(scrollChild); editBox:ClearAllPoints(); editBox:SetPoint("TOPLEFT", rightX, cy); editBox:Show()

    local btnAddID = scrollChild.AG_AddBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Manual Add ID"] or "添加高亮法术ID", function()
        local id = tonumber(editBox:GetText()); if id then
            local idStr = tostring(id)
            if not db.spells[idStr] then db.spells[idStr] = { class = "ALL", spec = 0, glowEnable = true, useOverlay = false, iconEnable = false, iconGlowEnable = true } end
            AuraGlowMod.CurrentSelectedSpell = idStr; editBox:SetText("")
            AuraGlowMod:InvalidateDB() 
            callback("GLOW_UPDATE"); C_Timer.After(0.05, function() callback("UI_REFRESH") end)
        end
    end)
    scrollChild.AG_AddBtn = btnAddID; btnAddID:SetParent(scrollChild); btnAddID:ClearAllPoints(); btnAddID:SetPoint("LEFT", editBox, "RIGHT", 10, 0); btnAddID:SetWidth(120); btnAddID:Show()
    cy = cy - 40

    if AuraGlowMod.CurrentSelectedSpell and db.spells[AuraGlowMod.CurrentSelectedSpell] then
        local d = db.spells[AuraGlowMod.CurrentSelectedSpell]
        local name = "Unknown"; pcall(function() name = C_Spell.GetSpellName(tonumber(AuraGlowMod.CurrentSelectedSpell)) or "Unknown" end)
        local sOpts = {
            { type = "group", key = "ag_edit", text = "编辑法术: " .. name, childs = {
                { type = "toggle", key = "glowEnable", db = d, text = "启用动作条边框高亮" },
                { type = "toggle", key = "useOverlay", db = d, text = "启用实体遮罩层 (修复变暗图标)" },
                { type = "toggle", key = "iconEnable", db = d, text = "启用屏幕中央独立图标提示" },
                { type = "toggle", key = "iconGlowEnable", db = d, text = "独立图标启用边框高亮" },
            }}
        }
        cy = WF.UI:RenderOptionsGroup(scrollChild, rightX, cy, ColW, sOpts, function() AuraGlowMod:InvalidateDB(); callback("GLOW_UPDATE") end)
        
        local delBtn = scrollChild.AG_DelBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Delete This Config"] or "彻底删除此配置", function() 
            db.spells[AuraGlowMod.CurrentSelectedSpell] = nil; AuraGlowMod.CurrentSelectedSpell = nil
            AuraGlowMod:InvalidateDB()
            callback("GLOW_UPDATE"); C_Timer.After(0.05, function() callback("UI_REFRESH") end) 
        end)
        scrollChild.AG_DelBtn = delBtn; delBtn:SetParent(scrollChild); delBtn:ClearAllPoints(); delBtn:SetPoint("TOPLEFT", rightX, cy - 10); delBtn:Show()
        cy = cy - 50
    else
        if scrollChild.AG_DelBtn then scrollChild.AG_DelBtn:Hide() end
    end

    return cy
end

local function InitAuraGlow()
    GetDB()
    if not WF.db.auraGlow.enable then return end

    AuraGlowMod.AuraGlowAnchor = CreateFrame("Frame", "WishFlex_AuraGlowIconAnchor", UIParent)
    AuraGlowMod.AuraGlowAnchor:SetPoint("CENTER", UIParent, "CENTER", 180, 0); AuraGlowMod.AuraGlowAnchor:SetSize(45, 45)
    if WF.CreateMover then WF:CreateMover(AuraGlowMod.AuraGlowAnchor, "WishFlexAuraGlowIconMover", {"CENTER", UIParent, "CENTER", 180, 0}, 45, 45, "WishFlex: " .. (L["Independent Aura Icon"] or "独立图标实体组")) end
    local mover = _G["WishFlexAuraGlowIconMover"]; if mover then AuraGlowMod.AuraGlowAnchor.mover = mover; AuraGlowMod.AuraGlowAnchor:SetPoint("CENTER", mover, "CENTER") end

    if WF.RegisterEvent then
        WF:RegisterEvent("UNIT_AURA", function(e, unit)
            if not InCombatLockdown() and unit ~= "player" then return end
            if unit == "player" or unit == "target" then RequestUpdateGlows() end
        end)
        WF:RegisterEvent("PLAYER_TARGET_CHANGED", RequestUpdateGlows)
        WF:RegisterEvent("PLAYER_REGEN_DISABLED", RequestUpdateGlows)
        WF:RegisterEvent("PLAYER_REGEN_ENABLED", RequestUpdateGlows)
        WF:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", RequestUpdateGlows)
        
        WF:RegisterEvent("PLAYER_ENTERING_WORLD", function(e, isInitialLogin, isReloading)
            if not InCombatLockdown() then RequestUpdateGlows() end
            if isInitialLogin or isReloading then
                C_Timer.After(1.5, function() AuraGlowMod:UpdateGlows(true) end)
                C_Timer.After(3.0, function() AuraGlowMod:UpdateGlows(true) end)
            end
        end)

        WF:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(e, unit, _, spellID)
            if unit ~= "player" or not WF.db.auraGlow.enable then return end
            local triggered = false; local currentSpecID = 0
            pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)
            for sIDStr, spellData in pairs(GetDB().spells) do
                if (spellData.glowEnable or spellData.iconEnable) then
                    local sSpec = tonumber(spellData.spec) or 0
                    if sSpec == 0 or sSpec == currentSpecID then
                        local sID = tonumber(sIDStr); local bID = tonumber(spellData.buffID) or sID; local dur = tonumber(spellData.duration) or 0
                        if dur > 0 and (spellID == sID or spellID == bID) then AuraGlowMod.manualTrackers = AuraGlowMod.manualTrackers or {}; AuraGlowMod.manualTrackers[bID] = { start = GetTime(), dur = dur }; triggered = true end
                    end
                end
            end
            if triggered then RequestUpdateGlows() end
        end)
    end
    
    C_Timer.After(1, function()
        for _, vName in ipairs(SKILL_VIEWERS) do
            local viewer = _G[vName]
            if viewer and viewer.itemFramePool then
                SafeHook(viewer.itemFramePool, "Acquire", RequestUpdateGlows)
                SafeHook(viewer.itemFramePool, "Release", RequestUpdateGlows) 
            end
        end
        for _, vName in ipairs(BUFF_VIEWERS) do
            local viewer = _G[vName]
            if viewer and viewer.itemFramePool then
                SafeHook(viewer.itemFramePool, "Acquire", RequestUpdateGlows)
                SafeHook(viewer.itemFramePool, "Release", RequestUpdateGlows) 
            end
        end
        
        local mixins = { _G.CooldownViewerBuffIconItemMixin, _G.CooldownViewerEssentialItemMixin, _G.CooldownViewerUtilityItemMixin, _G.CooldownViewerBuffBarItemMixin }
        for _, mixin in ipairs(mixins) do 
            if mixin then 
                if mixin.OnCooldownIDSet then SafeHook(mixin, "OnCooldownIDSet", RequestUpdateGlows) end 
                if mixin.OnActiveStateChanged then SafeHook(mixin, "OnActiveStateChanged", RequestUpdateGlows) end 
            end 
        end
        
        AuraGlowMod:UpdateGlows(true)
    end)

    RequestUpdateGlows()
end

WF:RegisterModule("auraGlow", L["Aura Glow"] or "技能状态高亮", InitAuraGlow)