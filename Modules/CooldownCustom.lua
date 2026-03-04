local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')
local LSM = E.Libs.LSM
local WUI = E:GetModule('WishFlex')
local mod = WUI:NewModule('CooldownCustom', 'AceHook-3.0', 'AceEvent-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

mod.itemSpellMap = {} 
mod.buffDurationCache = {} 
mod.activeBuffs = {} 
mod.defensiveIcons = {}
mod.activeDefensives = {}
mod.spellMaxChargesCache = {}

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.cooldownCustom = true
P["WishFlex"].cdManager = {
    swipeColor = {r = 0, g = 0, b = 0, a = 0.8}, 
    activeAuraColor = {r = 1, g = 0.95, b = 0.57, a = 0.69}, 
    reverseSwipe = true,
    Defensives = { 
        enable = true, attachToPlayer = true, customSpells = "",
        width = 45, height = 45, iconGap = 2, growth = "LEFT", desaturate = true,
        buffFontSize = 18, buffFontColor = {r = 0, g = 1, b = 0}, buffXOffset = 0, buffYOffset = 0,
        cdFontSize = 18, cdFontColor = {r = 1, g = 0.82, b = 0}, cdXOffset = 0, cdYOffset = 0,
        stackFontSize = 14, stackFontColor = {r = 1, g = 1, b = 1}, stackXOffset = 12, stackYOffset = -12,
        glowEnable = true, glowColor = {r = 0, g = 1, b = 0.5, a = 1}, glowLines = 8, glowFreq = 0.25, glowThick = 2 
    },
    Utility = { 
        width = 45, height = 30, iconGap = 2, growth = "CENTER", 
        cdFontSize = 18, cdFontColor = {r = 1, g = 0.82, b = 0}, cdXOffset = 0, cdYOffset = 0,
        stackFontSize = 14, stackFontColor = {r = 1, g = 1, b = 1}, stackXOffset = 12, stackYOffset = -12 
    },
    BuffBar = { 
        width = 120, height = 30, iconGap = 2, growth = "DOWN", glowEnable = false, glowColor = {r = 1, g = 0.8, b = 0, a = 1}, glowLines = 8, glowFreq = 0.25, glowThick = 2,
        cdFontSize = 18, cdFontColor = {r = 1, g = 0.82, b = 0}, cdXOffset = 0, cdYOffset = 0,
        stackFontSize = 14, stackFontColor = {r = 1, g = 1, b = 1}, stackXOffset = 12, stackYOffset = -12
    },
    BuffIcon = { 
        width = 45, height = 45, iconGap = 2, growth = "CENTER", glowEnable = false, glowColor = {r = 1, g = 0.8, b = 0, a = 1}, glowLines = 8, glowFreq = 0.25, glowThick = 2,
        cdFontSize = 18, cdFontColor = {r = 1, g = 0.82, b = 0}, cdXOffset = 0, cdYOffset = 0,
        stackFontSize = 14, stackFontColor = {r = 1, g = 1, b = 1}, stackXOffset = 12, stackYOffset = -12
    }, 
    Essential = { 
        enableCustomLayout = true, injectActionTimer = false, maxPerRow = 7, iconGap = 2, glowEnable = true, glowColor = {r = 1, g = 0.8, b = 0, a = 1}, glowLines = 8, glowFreq = 0.25, glowLength = 10, glowThick = 2,
        row1Width = 45, row1Height = 45, 
        row1CdFontSize = 18, row1CdFontColor = {r = 1, g = 0.82, b = 0}, row1CdXOffset = 0, row1CdYOffset = 0, 
        row1StackFontSize = 14, row1StackFontColor = {r = 1, g = 1, b = 1}, row1StackXOffset = 12, row1StackYOffset = -12, 
        row2Width = 40, row2Height = 40, row2IconGap = 2, 
        row2CdFontSize = 18, row2CdFontColor = {r = 1, g = 0.82, b = 0}, row2CdXOffset = 0, row2CdYOffset = 0, 
        row2StackFontSize = 14, row2StackFontColor = {r = 1, g = 1, b = 1}, row2StackXOffset = 12, row2StackYOffset = -12 
    },
    countFont = "Expressway", countFontOutline = "OUTLINE", countFontColor = { r = 1, g = 1, b = 1 },
}

-- =======================================================
-- 【全职业防御技能库与基础时长兜底】
-- =======================================================
local DefensiveSpells = {
    WARRIOR = { 118038, 97462, 184364, 871, 12975, 23920, 386029 },
    PALADIN = { 642, 498, 31850, 86659, 184662, 205191 },
    HUNTER = { 186265, 109304, 264735, 281195 },
    ROGUE = { 5277, 31224, 1966, 199754 },
    PRIEST = { 19236, 33206, 47536, 47588, 64843, 65081 },
    DEATHKNIGHT = { 48707, 48792, 49039, 55233, 48743 },
    SHAMAN = { 108271, 210643, 114052 },
    MAGE = { 45438, 110909, 198065, 235313, 342245, 414658 },
    WARLOCK = { 104773, 108416, 389831 },
    MONK = { 115203, 122278, 122470, 115176, 115310, 322507 },
    DRUID = { 22812, 61336, 102342, 108238 },
    DEMONHUNTER = { 196718, 198589, 204021 },
    EVOKER = { 363916, 374348, 374227, 357170 },
}

local DefensiveDurations = {
    [118038] = 8, [97462] = 10, [184364] = 8, [871] = 8, [12975] = 15, [23920] = 5, [386029] = 2,
    [642] = 8, [498] = 8, [31850] = 10, [86659] = 8, [184662] = 15, [205191] = 10,
    [186265] = 8, [109304] = 10, [264735] = 6, [281195] = 10,
    [5277] = 10, [31224] = 5, [1966] = 6, [199754] = 10,
    [19236] = 8, [33206] = 8, [47536] = 10, [47588] = 10, [64843] = 8, [65081] = 4,
    [48707] = 5, [48792] = 8, [49039] = 10, [55233] = 10, [48743] = 10,
    [108271] = 12, [210643] = 60, [114052] = 15,
    [45438] = 10, [110909] = 10, [198065] = 15, [235313] = 10, [342245] = 10, [414658] = 12,
    [104773] = 8, [108416] = 8, [389831] = 10,
    [115203] = 15, [122278] = 10, [122470] = 10, [115176] = 6, [115310] = 10, [322507] = 10,
    [22812] = 12, [61336] = 6, [102342] = 12, [108238] = 10,
    [196718] = 8, [198589] = 10, [204021] = 8,
    [363916] = 12, [374348] = 8, [374227] = 5, [357170] = 8,
}

local function GetKeyFromFrame(frame)
    local parent = frame:GetParent()
    while parent do
        local name = parent:GetName() or ""
        if name:find("UtilityCooldownViewer") then return "Utility" end
        if name:find("BuffBarCooldownViewer") then return "BuffBar" end
        if name:find("BuffIconCooldownViewer") then return "BuffIcon" end
        if name:find("EssentialCooldownViewer") then return "Essential" end
        parent = parent:GetParent()
    end
    return nil
end

function mod.ApplyTexCoord(texture, width, height)
    if not texture or not texture.SetTexCoord then return end
    local ratio = width / height
    local offset = 0.08
    local left, right, top, bottom = offset, 1-offset, offset, 1-offset
    if ratio > 1 then
        local vH = (1 - 2*offset) / ratio; top, bottom = 0.5 - (vH/2), 0.5 + (vH/2)
    elseif ratio < 1 then
        local vW = (1 - 2*offset) * ratio; left, right = 0.5 - (vW/2), 0.5 + (vW/2)
    end
    texture:SetTexCoord(left, right, top, bottom)
end

-- =======================================================
-- 【底层安全拦截】：完美粉碎暴雪原生“快消失红框”(Pandemic)
-- =======================================================
local HookedFrames = {}
local function SuppressDebuffBorder(f)
    if not f or HookedFrames[f] then return end
    HookedFrames[f] = true
    
    local borders = {
        f.DebuffBorder, f.Border, f.IconBorder, f.IconOverlay, f.overlay, f.ExpireBorder,
        f.Icon and f.Icon.Border, f.Icon and f.Icon.IconBorder, f.Icon and f.Icon.DebuffBorder
    }
    for _, border in pairs(borders) do
        if border then
            border:Hide()
            border:SetAlpha(0)
            if type(border.Show) == "function" then
                hooksecurefunc(border, "Show", function(self) self:Hide(); self:SetAlpha(0) end)
            end
            if type(border.UpdateFromAuraData) == "function" then
                hooksecurefunc(border, "UpdateFromAuraData", function(self) self:Hide(); self:SetAlpha(0) end)
            end
        end
    end

    if f.PandemicIcon then f.PandemicIcon:SetAlpha(0); f.PandemicIcon:Hide() end
    if type(f.ShowPandemicStateFrame) == "function" then
        hooksecurefunc(f, "ShowPandemicStateFrame", function(self)
            if self.PandemicIcon then self.PandemicIcon:Hide(); self.PandemicIcon:SetAlpha(0) end
        end)
    end

    if f.CooldownFlash then
        f.CooldownFlash:SetAlpha(0)
        f.CooldownFlash:Hide()
        if type(f.CooldownFlash.Show) == "function" then
            hooksecurefunc(f.CooldownFlash, "Show", function(self) self:Hide(); self:SetAlpha(0); if self.FlashAnim then self.FlashAnim:Stop() end end)
        end
        if f.CooldownFlash.FlashAnim and type(f.CooldownFlash.FlashAnim.Play) == "function" then
            hooksecurefunc(f.CooldownFlash.FlashAnim, "Play", function(self) self:Stop(); f.CooldownFlash:Hide() end)
        end
    end

    if f.SpellActivationAlert then
        f.SpellActivationAlert:SetAlpha(0); f.SpellActivationAlert:Hide()
        if type(f.SpellActivationAlert.Show) == "function" then hooksecurefunc(f.SpellActivationAlert, "Show", function(self) self:Hide(); self:SetAlpha(0) end) end
    end

    local bg = f.backdrop or f
    if bg and type(bg.SetBackdropBorderColor) == "function" then
        hooksecurefunc(bg, "SetBackdropBorderColor", function(self, r, g, b, a)
            if self.isHookingColor then return end
            local dr, dg, db = 0, 0, 0
            if E.media and E.media.bordercolor then dr, dg, db = unpack(E.media.bordercolor) end
            if math.abs((r or 0) - dr) > 0.01 or math.abs((g or 0) - dg) > 0.01 or math.abs((b or 0) - db) > 0.01 then
                self.isHookingColor = true; self:SetBackdropBorderColor(dr, dg, db, a or 1); self.isHookingColor = false
            end
        end)
        local dr, dg, db = 0, 0, 0
        if E.media and E.media.bordercolor then dr, dg, db = unpack(E.media.bordercolor) end
        bg.isHookingColor = true; bg:SetBackdropBorderColor(dr, dg, db, 1); bg.isHookingColor = false
    end
end

-- =======================================================
-- 【核心：智能遮罩色分离与安全下发】
-- =======================================================
function mod:ApplySwipeSettings(frame)
    if not frame or not frame.Cooldown then return end
    
    local db = E.db.WishFlex.cdManager
    local rev = db.reverseSwipe
    if rev == nil then rev = true end
    frame.Cooldown:SetReverse(rev)

    if not frame.Cooldown._wishSwipeHooked then
        local function UpdateSwipeColor(self)
            local b = self:GetParent()
            local cddb = E.db.WishFlex.cdManager
            if b.wasSetFromAura then
                local ac = cddb.activeAuraColor or {r=1, g=0.95, b=0.57, a=0.69}
                self:SetSwipeColor(ac.r, ac.g, ac.b, ac.a)
            else
                local sc = cddb.swipeColor or {r=0, g=0, b=0, a=0.8}
                self:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
            end
        end

        hooksecurefunc(frame.Cooldown, "SetCooldown", UpdateSwipeColor)
        if frame.Cooldown.SetCooldownFromDurationObject then
            hooksecurefunc(frame.Cooldown, "SetCooldownFromDurationObject", UpdateSwipeColor)
        end
        frame.Cooldown._wishSwipeHooked = true
    end

    if frame.wasSetFromAura then
        local ac = db.activeAuraColor or {r=1, g=0.95, b=0.57, a=0.69}
        frame.Cooldown:SetSwipeColor(ac.r, ac.g, ac.b, ac.a)
    else
        local sc = db.swipeColor or {r=0, g=0, b=0, a=0.8}
        frame.Cooldown:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
    end
end

local function FormatTime(time)
    if not time or time < 0 then return "" end
    if time >= 60 then return string.format("%dm", math.floor(time / 60))
    elseif time > 5 then return tostring(math.ceil(time)) 
    else return string.format("%.1f", time) end
end

local ScannerTooltip = CreateFrame("GameTooltip", "WishFlex_BuffScanner", UIParent, "GameTooltipTemplate")
function mod:CacheAllSpells()
    if InCombatLockdown() then return end
    wipe(self.buffDurationCache)
    wipe(self.itemSpellMap)
    local patterns = { "持续%s*(%d+)%s*秒", "lasts%s*(%d+)%s*sec", "(%d+)%s*秒", "(%d+)%s*sec" }
    
    local function ScanTooltip(id, isItem)
        if self.buffDurationCache[id] then return end
        if isItem then
            local _, sID = C_Item.GetItemSpell(id)
            if sID then self.itemSpellMap[sID] = id end
        end
        ScannerTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        ScannerTooltip:ClearLines()
        local ok
        if isItem then ok = pcall(function() ScannerTooltip:SetItemByID(id) end)
        else ok = pcall(function() ScannerTooltip:SetSpellByID(id) end) end
        
        if ok then
            for i = 1, 10 do
                local line = _G["WishFlex_BuffScannerTextLeft" .. i]
                local okText, text = pcall(function() return line and line:GetText() end)
                if okText and text and type(text) == "string" and not issecretvalue(text) then
                    if not text:match("充能") and not text:match("冷却") and not string.lower(text):match("recharge") and not string.lower(text):match("cooldown") then
                        for _, p in ipairs(patterns) do
                            local val = text:match(p)
                            if val then self.buffDurationCache[id] = tonumber(val); return end
                        end
                    end
                end
            end
        end
    end

    for i = 1, 19 do
        local itemID = GetInventoryItemID("player", i)
        if itemID then ScanTooltip(itemID, true) end
    end
    for i = 1, 120 do
        local actionType, id = GetActionInfo(i)
        if actionType == "spell" and id then ScanTooltip(id, false)
        elseif actionType == "item" and id then ScanTooltip(id, true) end
    end
    
    if self.activeDefensives then
        for _, id in ipairs(self.activeDefensives) do
            ScanTooltip(id, false)
        end
    end
end

local function GetEffectiveSpellID(spellID)
    if C_Spell and C_Spell.GetOverrideSpell then
        local override = C_Spell.GetOverrideSpell(spellID)
        if override and override > 0 then return override end
    end
    return spellID
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, unit, _, spellID)
    if unit ~= "player" then return end
    local itemID = self.itemSpellMap[spellID]
    local id = itemID or spellID
    local effectiveID = GetEffectiveSpellID(spellID)
    
    local defDur = self.buffDurationCache[effectiveID] or self.buffDurationCache[spellID] or DefensiveDurations[effectiveID] or DefensiveDurations[spellID]
    if defDur and defDur > 0 then
        self.activeBuffs[effectiveID] = { endTime = GetTime() + defDur, duration = defDur }
        self.activeBuffs[spellID] = { endTime = GetTime() + defDur, duration = defDur }
    end
end

local function IsEqual(a, b) return a == b end

local function CheckAuraValid(id, isItem)
    local sName, sID = nil, id
    if isItem then
        local _, spID = C_Item.GetItemSpell(id)
        if spID then 
            sID = spID
            local sInfo = C_Spell.GetSpellInfo(sID)
            if sInfo then sName = sInfo.name end
        end
    else
        local sInfo = C_Spell.GetSpellInfo(id)
        if sInfo then sName = sInfo.name end
    end
    
    if not sName and not sID then return true end 
    
    local hasSecret = false
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        
        if sName and aura.name then
            local ok, match = pcall(IsEqual, aura.name, sName)
            if ok and match then return true end
            if not ok then hasSecret = true end
        end
        
        if sID and aura.spellId then
            local ok, match = pcall(IsEqual, aura.spellId, sID)
            if ok and match then return true end
            if not ok then hasSecret = true end
        end
    end
    return hasSecret
end

local DesaturationCurve
if C_CurveUtil and C_CurveUtil.CreateCurve then
    DesaturationCurve = C_CurveUtil.CreateCurve()
    DesaturationCurve:SetType(Enum.LuaCurveType.Step)
    DesaturationCurve:AddPoint(0, 0)
    DesaturationCurve:AddPoint(1.501, 1) 
end

function mod:GetDefensiveIcon(index)
    if not self.defensiveIcons[index] then
        local f = CreateFrame("Frame", "WishFlex_DefensiveIcon"..index, _G.WishFlex_DefensiveViewer)
        f:SetTemplate("Transparent")
        
        f.Icon = f:CreateTexture(nil, "ARTWORK")
        f.Icon:SetInside()
        
        f.Cooldown = CreateFrame("Cooldown", "$parentCooldown", f, "CooldownFrameTemplate")
        f.Cooldown:SetInside()
        f.Cooldown:SetDrawEdge(false)
        f.Cooldown:SetHideCountdownNumbers(false)
        
        -- ✅ 修复：创建一个专门的文本层 Frame，确保其层级始终高于 Cooldown 遮罩
        f.OverlayFrame = CreateFrame("Frame", nil, f)
        f.OverlayFrame:SetAllPoints()
        f.OverlayFrame:SetFrameLevel(f.Cooldown:GetFrameLevel() + 5)
        
        -- 将层数文本挂载到这个绝对处于最上层的 OverlayFrame 上
        f.Count = f.OverlayFrame:CreateFontString(nil, "OVERLAY")
        f.Count:SetPoint("BOTTOMRIGHT", -2, 2)
        
        self.defensiveIcons[index] = f
    end
    return self.defensiveIcons[index]
end

function mod:UpdateKnownDefensives()
    if InCombatLockdown() then return end
    table.wipe(self.activeDefensives)
    table.wipe(self.spellMaxChargesCache)
    
    local _, playerClass = UnitClass("player")
    local spellList = DefensiveSpells[playerClass] or {}
    
    local seen = {}
    for _, spellID in ipairs(spellList) do
        if IsPlayerSpell(spellID) then
            table.insert(self.activeDefensives, spellID)
            seen[spellID] = true
            
            local effectiveID = GetEffectiveSpellID(spellID)
            local cInfo = C_Spell and C_Spell.GetSpellCharges(effectiveID)
            if cInfo and type(cInfo.maxCharges) == "number" then
                self.spellMaxChargesCache[effectiveID] = cInfo.maxCharges
            end
        end
    end

    local customStr = E.db.WishFlex.cdManager.Defensives.customSpells or ""
    for idStr in string.gmatch(customStr, "[%d]+") do
        local spellID = tonumber(idStr)
        local sInfo = C_Spell and C_Spell.GetSpellInfo(spellID) or GetSpellInfo(spellID)
        if spellID and not seen[spellID] and sInfo and IsPlayerSpell(spellID) then
            table.insert(self.activeDefensives, spellID)
            seen[spellID] = true
            
            local effectiveID = GetEffectiveSpellID(spellID)
            local cInfo = C_Spell and C_Spell.GetSpellCharges(effectiveID)
            if cInfo and type(cInfo.maxCharges) == "number" then
                self.spellMaxChargesCache[effectiveID] = cInfo.maxCharges
            end
        end
    end

    self:LayoutDefensives()
    self:UpdateDefensiveCooldowns()
    self:CacheAllSpells()
end

function mod:LayoutDefensives()
    local db = E.db.WishFlex.cdManager.Defensives
    local container = _G.WishFlex_DefensiveViewer
    if not db.enable or #self.activeDefensives == 0 then
        container:Hide()
        return
    end
    
    container:Show()
    local w, h = db.width or 45, db.height or 45
    local gap = db.iconGap or 2
    local growth = db.growth or "LEFT"
    
    if db.attachToPlayer then growth = "LEFT" end
    
    local totalW = (#self.activeDefensives * w) + math.max(0, (#self.activeDefensives - 1) * gap)
    container:SetSize(math.max(w, totalW), h)

    if db.attachToPlayer and _G.ElvUF_Player then
        container:ClearAllPoints()
        container:SetPoint("BOTTOMRIGHT", _G.ElvUF_Player, "TOPRIGHT", 0, 1)
        if container.mover then container.mover:SetAlpha(0) end 
    else
        if container.mover then 
            container.mover:SetSize(math.max(w, totalW), h)
            container.mover:SetAlpha(1)
            container:ClearAllPoints()
            container:SetPoint("CENTER", container.mover, "CENTER")
        end
    end

    for i = #self.activeDefensives + 1, #self.defensiveIcons do
        self.defensiveIcons[i]:Hide()
    end

    for i, spellID in ipairs(self.activeDefensives) do
        local f = self:GetDefensiveIcon(i)
        f:ClearAllPoints()
        f:Show()
        
        local x = 0
        if growth == "CENTER" then 
            x = -(totalW / 2) + (w / 2) + (i - 1) * (w + gap)
            f:SetPoint("CENTER", container, "CENTER", x, 0)
        elseif growth == "LEFT" then 
            x = -(i - 1) * (w + gap); f:SetPoint("RIGHT", container, "RIGHT", x, 0)
        elseif growth == "RIGHT" then 
            x = (i - 1) * (w + gap); f:SetPoint("LEFT", container, "LEFT", x, 0) 
        end

        f:SetSize(w, h)
        local effectiveID = GetEffectiveSpellID(spellID)
        local iconTexture = C_Spell and C_Spell.GetSpellTexture(effectiveID) or GetSpellTexture(effectiveID)
        f.Icon:SetTexture(iconTexture)
        self.ApplyTexCoord(f.Icon, w, h)
        
        self:ApplySwipeSettings(f)
    end
end

function mod:UpdateDefensiveCooldowns()
    if not E.db.WishFlex.cdManager.Defensives.enable then return end
    for i, spellID in ipairs(self.activeDefensives) do
        local f = self.defensiveIcons[i]
        if f and f:IsShown() and not f.wasSetFromAura then
            local effectiveID = GetEffectiveSpellID(spellID)

            local CCD = C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(effectiveID)
            local SCD = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(effectiveID)

            if f.Cooldown.timer then
                f.Cooldown.timer.start = nil
                f.Cooldown.timer.duration = nil
            end

            if CCD and f.Cooldown.SetCooldownFromDurationObject then
                f.Cooldown:SetCooldownFromDurationObject(CCD)
            elseif SCD and f.Cooldown.SetCooldownFromDurationObject then
                f.Cooldown:SetCooldownFromDurationObject(SCD)
            else
                f.Cooldown:Clear()
            end
        end
    end
end


-- =======================================================
-- 【增强版配置生成：全面接管各分类冷却与层数分离设置】
-- =======================================================
local function GetEssentialGroup(dbKey, tabName, order)
    return {
        order = order, type = "group", name = tabName,
        get = function(i) return E.db.WishFlex.cdManager[dbKey][i[#i]] end,
        set = function(i, v) E.db.WishFlex.cdManager[dbKey][i[#i]] = v; mod:ScheduleLayout() end,
        args = {
            layoutStatus = { 
                order = 1, type = "group", name = "第一行", guiInline = true, args = { 
                    enableCustomLayout = { order = 1, type = "toggle", name = "启用双行" }, 
                    injectActionTimer = { 
                        order = 1.5, type = "toggle", name = "合并饰品药水", 
                        desc = "开启后，[饰品/药水/种族技能]等模块的图标将无缝注入并合并到重要技能的第二行末尾，跟随第二行一起排版和管理样式。",
                        get = function() return E.db.WishFlex.cdManager.Essential.injectActionTimer end,
                        set = function(_, v)
                            E.db.WishFlex.cdManager.Essential.injectActionTimer = v
                            mod:ScheduleLayout()
                            local AT = WUI:GetModule('ActionTimer', true)
                            if AT and not v then AT:UpdateLayout() end
                        end
                    },
                    maxPerRow = { order = 2, type = "range", name = "最大数", min = 1, max = 20, step = 1 }, 
                    iconGap = { order = 3, type = "range", name = "间距", min = 0, max = 20, step = 1 } 
                } 
            },
            row1Size = { order = 2, type = "group", name = "第一行尺寸", guiInline = true, args = { row1Width = { order=1, type="range", name="宽度", min=10, max=100, step=1 }, row1Height = { order=2, type="range", name="高度", min=10, max=100, step=1 } } },
            row1CdText = { order = 3, type = "group", name = "第一行 冷却倒计时", guiInline = true, args = { row1CdFontSize = {order=1,type="range",name="大小",min=8,max=40,step=1}, row1CdFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Essential.row1CdFontColor; return t and t.r or 1, t and t.g or 0.82, t and t.b or 0 end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Essential.row1CdFontColor={r=r,g=g,b=b} end}, row1CdXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, row1CdYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            row1StackText = { order = 4, type = "group", name = "第一行 层数文本", guiInline = true, args = { row1StackFontSize = {order=1,type="range",name="大小",min=8,max=40,step=1}, row1StackFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Essential.row1StackFontColor; return t and t.r or 1, t and t.g or 1, t and t.b or 1 end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Essential.row1StackFontColor={r=r,g=g,b=b} end}, row1StackXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, row1StackYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            row2Size = { order = 5, type = "group", name = "第二行尺寸", guiInline = true, args = { row2Width = { order=1, type="range", name="宽度", min=10, max=100, step=1 }, row2Height = { order=2, type="range", name="高度", min=10, max=100, step=1 }, row2IconGap = { order=3, type="range", name="间距", min=0, max=20, step = 1 } } },
            row2CdText = { order = 6, type = "group", name = "第二行 冷却倒计时", guiInline = true, args = { row2CdFontSize = {order=1,type="range",name="大小",min=8,max=40,step=1}, row2CdFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Essential.row2CdFontColor; return t and t.r or 1, t and t.g or 0.82, t and t.b or 0 end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Essential.row2CdFontColor={r=r,g=g,b=b} end}, row2CdXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, row2CdYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            row2StackText = { order = 7, type = "group", name = "第二行 层数文本", guiInline = true, args = { row2StackFontSize = {order=1,type="range",name="大小",min=8,max=40,step=1}, row2StackFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Essential.row2StackFontColor; return t and t.r or 1, t and t.g or 1, t and t.b or 1 end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Essential.row2StackFontColor={r=r,g=g,b=b} end}, row2StackXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, row2StackYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            glowGrp1 = { order = 8, type = "group", name = "高亮图标", guiInline = true, args = { glowEnable = { order = 1, type = "toggle", name = "像素发光" }, glowColor = { order = 2, type = "color", name = "线条颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.cdManager.Essential.glowColor or {r=1,g=0.8,b=0,a=1} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.cdManager.Essential.glowColor = {r=r,g=g,b=b,a=a}; end }, glowLines = { order = 3, type = "range", name = "线条数", min = 1, max = 20, step = 1 }, glowFreq = { order = 4, type = "range", name = "速度", min = 0.05, max = 2, step = 0.05 }, glowThick = { order = 5, type = "range", name = "线条粗细", min = 1, max = 10, step = 1 } } }
        }
    }
end

local function GetCDSubGroup(dbKey, tabName, order, isVertical)
    local growthValues = isVertical and { ["UP"] = "向上", ["DOWN"] = "向下" } or { ["LEFT"] = "向左", ["CENTER"] = "居中", ["RIGHT"] = "向右" }
    return {
        order = order, type = "group", name = tabName, 
        get = function(i) return E.db.WishFlex.cdManager[dbKey][i[#i]] end,
        set = function(i, v) E.db.WishFlex.cdManager[dbKey][i[#i]] = v; mod:ScheduleLayout() end,
        args = {
            layout = { order = 1, type = "group", name = "排版", guiInline = true, args = { growth = { order = 1, type = "select", name = "增长方向", values = growthValues }, iconGap = { order = 2, type = "range", name = "间距", min = 0, max = 20, step = 1 } } },
            sizeSet = { order = 2, type = "group", name = "图标宽高", guiInline = true, args = { width = {order=1,type="range",name="宽度",min=10,max=400,step=1}, height = {order=2,type="range",name="高度",min=10,max=100,step=1} } },
            cdText = { order = 3, type = "group", name = "冷却倒计时", guiInline = true, args = { cdFontSize = {order=1,type="range",name="大小",min=8,max=40,step=1}, cdFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager[dbKey].cdFontColor; return t and t.r or 1, t and t.g or 0.82, t and t.b or 0 end, set=function(_,r,g,b) E.db.WishFlex.cdManager[dbKey].cdFontColor={r=r,g=g,b=b} end}, cdXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, cdYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            stackText = { order = 4, type = "group", name = "层数文本", guiInline = true, args = { stackFontSize = {order=1,type="range",name="大小",min=8,max=40,step=1}, stackFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager[dbKey].stackFontColor; return t and t.r or 1, t and t.g or 1, t and t.b or 1 end, set=function(_,r,g,b) E.db.WishFlex.cdManager[dbKey].stackFontColor={r=r,g=g,b=b} end}, stackXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, stackYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
        }
    }
end

local function GetDefensiveGroup(dbKey, tabName, order)
    return {
        order = order, type = "group", name = tabName, 
        get = function(i) return E.db.WishFlex.cdManager[dbKey][i[#i]] end,
        set = function(i, v) E.db.WishFlex.cdManager[dbKey][i[#i]] = v; mod:UpdateKnownDefensives(); mod:ScheduleLayout() end,
        args = {
            enable = { order = 1, type = "toggle", name = "启用防守条", width = "normal" },
            attachToPlayer = { 
                order = 1.1, type = "toggle", name = "智能吸附玩家头像", 
                desc = "开启后，防守条将自动固定在 ElvUI 玩家头像框体右上角（上间距1像素）。并且强制图标从右向左生长以保证完美对齐。",
                get = function() return E.db.WishFlex.cdManager.Defensives.attachToPlayer end, 
                set = function(_, v) E.db.WishFlex.cdManager.Defensives.attachToPlayer = v; mod:LayoutDefensives() end 
            },
            customSpells = { 
                order = 1.2, type = "input", name = "添加自定义技能ID", 
                desc = "输入想要强行监控的技能ID，如果有多个请用英文逗号隔开，例如：12345, 67890", 
                width = "full", 
                get = function() return E.db.WishFlex.cdManager.Defensives.customSpells end, 
                set = function(_, v) E.db.WishFlex.cdManager.Defensives.customSpells = v; mod:UpdateKnownDefensives() end 
            },
            layout = { order = 2, type = "group", name = "排版", guiInline = true, args = { 
                growth = { order = 1, type = "select", name = "增长方向", disabled = function() return E.db.WishFlex.cdManager.Defensives.attachToPlayer end, values = { ["LEFT"] = "向左", ["CENTER"] = "居中", ["RIGHT"] = "向右" } }, 
                iconGap = { order = 2, type = "range", name = "间距", min = 0, max = 20, step = 1 } 
            } },
            sizeSet = { order = 3, type = "group", name = "图标宽高", guiInline = true, args = { width = {order=1,type="range",name="宽度",min=10,max=400,step=1}, height = {order=2,type="range",name="高度",min=10,max=100,step=1} } },
            buffText = { order = 4, type = "group", name = "BUFF持续时间文本", guiInline = true, args = { buffFontSize = {order=1,type="range",name="大小",min=8,max=40,step=1}, buffFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Defensives.buffFontColor; return t.r,t.g,t.b end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Defensives.buffFontColor={r=r,g=g,b=b} end}, buffXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, buffYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            cdText = { order = 5, type = "group", name = "冷却倒计时", guiInline = true, args = { cdFontSize = {order=1,type="range",name="大小",min=8,max=40,step=1}, cdFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Defensives.cdFontColor; return t.r,t.g,t.b end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Defensives.cdFontColor={r=r,g=g,b=b} end}, cdXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, cdYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            stackText = { order = 6, type = "group", name = "层数文本", guiInline = true, args = { stackFontSize = {order=1,type="range",name="大小",min=8,max=40,step=1}, stackFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Defensives.stackFontColor; return t.r,t.g,t.b end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Defensives.stackFontColor={r=r,g=g,b=b} end}, stackXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, stackYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            glow1 = { order = 7, type = "group", name = "BUFF激活走马灯", guiInline = true, args = { glowEnable = { order = 1, type = "toggle", name = "启用" }, glowColor = { order = 2, type = "color", name = "颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.cdManager[dbKey].glowColor or {r=0,g=1,b=0.5,a=1} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.cdManager[dbKey].glowColor = {r=r,g=g,b=b,a=a}; end }, glowLines = { order = 3, type = "range", name = "线条", min = 1, max = 20, step = 1 }, glowFreq = { order = 4, type = "range", name = "速度", min = 0.05, max = 2, step = 0.05 }, glowThick = { order = 5, type = "range", name = "线条粗细", min = 1, max = 10, step = 1 } } },
            textSet = { order = 8, type = "group", name = "褪色设置", guiInline = true, args = { desaturate = { order = 1, type = "toggle", name = "冷却中变灰", desc = "技能进入冷却时图标会安全失去色彩" } } },
        }
    }
end

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.cdmanager = { order = 20, type = "group", name = "|cff00e5cc冷却管理器|r", childGroups = "tab", args = {} }
    local args = WUI.OptionsArgs.cdmanager.args
    
    args.base = { 
        order = 1, type = "group", name = "全局与外观", 
        args = { 
            enable = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.modules.cooldownCustom end, set = function(_, v) E.db.WishFlex.modules.cooldownCustom = v; E:StaticPopup_Show("CONFIG_RL") end }, 
            countFont = { order = 2, type = "select", dialogControl = 'LSM30_Font', name = "全局字体", values = LSM:HashTable("font"), get = function() return E.db.WishFlex.cdManager.countFont end, set = function(_, v) E.db.WishFlex.cdManager.countFont = v; mod:ScheduleLayout(); mod:LayoutDefensives() end }, 
            countFontOutline = { order = 3, type = "select", name = "字体描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" }, get = function() return E.db.WishFlex.cdManager.countFontOutline end, set = function(_, v) E.db.WishFlex.cdManager.countFontOutline = v; mod:ScheduleLayout(); mod:LayoutDefensives() end }, 
            swipeColor = { order = 5, type = "color", name = "全局冷却遮罩颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.cdManager.swipeColor or {r=0,g=0,b=0,a=0.8} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.cdManager.swipeColor = {r=r,g=g,b=b,a=a}; mod:ScheduleLayout(); mod:LayoutDefensives() end },
            activeAuraColor = { order = 6, type = "color", name = "BUFF激活遮罩颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.cdManager.activeAuraColor or {r=1,g=0.95,b=0.57,a=0.69} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.cdManager.activeAuraColor = {r=r,g=g,b=b,a=a}; mod:ScheduleLayout(); mod:LayoutDefensives() end },
            reverseSwipe = { order = 7, type = "toggle", name = "反向遮罩(亮变黑)", get = function() return E.db.WishFlex.cdManager.reverseSwipe end, set = function(_, v) E.db.WishFlex.cdManager.reverseSwipe = v; mod:ScheduleLayout(); mod:LayoutDefensives() end }
        } 
    }
    args.essential = GetEssentialGroup("Essential", "重要技能", 2)
    args.defensives = GetDefensiveGroup("Defensives", "防御技能(独立)", 3)
    args.utility = GetCDSubGroup("Utility", "效能技能", 4, false)
    args.bufficon = GetCDSubGroup("BuffIcon", "增益图标", 5, false) 
    args.buffbar = GetCDSubGroup("BuffBar", "增益条", 6, true) 
end

-- =======================================================
-- 【最强护盾：文字独立渲染与防 ElvUI 毒刺劫持核心】
-- 支持所有组件层数/CD 分离配置与动态 X/Y 轴绝对居中锁定
-- =======================================================
function mod:ApplyText(frame, category, rowIndex)
    local db = E.db.WishFlex.cdManager
    local cfg = db[category]
    if not cfg then return end

    local fontPath = LSM:Fetch('font', db.countFont or "Expressway")
    local outline = db.countFontOutline or "OUTLINE"

    -- 读取拆分后的层数与冷却配置
    local cdSize, cdColor, cdX, cdY
    local stackSize, stackColor, stackX, stackY

    if category == "Essential" then
        if rowIndex == 2 then 
            cdSize = cfg.row2CdFontSize or 18; cdColor = cfg.row2CdFontColor or {r=1, g=0.82, b=0}; cdX = cfg.row2CdXOffset or 0; cdY = cfg.row2CdYOffset or 0
            stackSize = cfg.row2StackFontSize or 14; stackColor = cfg.row2StackFontColor or {r=1, g=1, b=1}; stackX = cfg.row2StackXOffset or 12; stackY = cfg.row2StackYOffset or -12
        else 
            cdSize = cfg.row1CdFontSize or 18; cdColor = cfg.row1CdFontColor or {r=1, g=0.82, b=0}; cdX = cfg.row1CdXOffset or 0; cdY = cfg.row1CdYOffset or 0
            stackSize = cfg.row1StackFontSize or 14; stackColor = cfg.row1StackFontColor or {r=1, g=1, b=1}; stackX = cfg.row1StackXOffset or 12; stackY = cfg.row1StackYOffset or -12
        end
    else
        cdSize = cfg.cdFontSize or 18; cdColor = cfg.cdFontColor or {r=1, g=0.82, b=0}; cdX = cfg.cdXOffset or 0; cdY = cfg.cdYOffset or 0
        stackSize = cfg.stackFontSize or 14; stackColor = cfg.stackFontColor or {r=1, g=1, b=1}; stackX = cfg.stackXOffset or 12; stackY = cfg.stackYOffset or -12
    end

    local stackText = (frame.Applications and frame.Applications.Applications) or (frame.ChargeCount and frame.ChargeCount.Current) or (not frame.isHijackedByEssential and frame.Count)

    local function FormatText(t, isStack)
        if not t or type(t) ~= "table" or not t.SetFont then return end
        
        local size = isStack and stackSize or cdSize
        local color = isStack and stackColor or cdColor
        local ox = isStack and stackX or cdX
        local oy = isStack and stackY or cdY
        
        local anchor = "CENTER"
        local parent = frame.Icon or frame

        -- 1. 字体刷新
        if t:GetFont() ~= fontPath or t._lastSize ~= size or t._lastOutline ~= outline then 
            t:FontTemplate(fontPath, size, outline) 
            t._lastSize = size
            t._lastOutline = outline
        end
        
        -- 2. 初始颜色与坐标
        t._isWishStyling = true
        t:SetTextColor(color.r, color.g, color.b)
        t:ClearAllPoints()
        t:SetPoint(anchor, parent, anchor, ox, oy)
        t:SetDrawLayer("OVERLAY", 7)
        t._isWishStyling = false

        -- 3. 动态上下文拦截死锁保护
        if not t._wishStyleHooked then
            t._wishStyleHooked = true
            
            hooksecurefunc(t, "SetPoint", function(self)
                if self._isWishStyling then return end
                self._isWishStyling = true
                self:ClearAllPoints()
                self:SetPoint(self._wishAnchor, self._wishParent, self._wishAnchor, self._wishX, self._wishY)
                self._isWishStyling = false
            end)

            hooksecurefunc(t, "SetTextColor", function(self)
                if self._isWishStyling then return end
                self._isWishStyling = true
                self:SetTextColor(self._wishColor.r, self._wishColor.g, self._wishColor.b)
                self._isWishStyling = false
            end)
        end
        
        -- 更新挂载的上下文动态变量
        t._wishAnchor = anchor
        t._wishParent = parent
        t._wishX = ox
        t._wishY = oy
        t._wishColor = color
    end

    -- 强制劫持原生CD计时器文本
    if frame.Cooldown then
        if frame.Cooldown.timer and frame.Cooldown.timer.text then FormatText(frame.Cooldown.timer.text, false) end
        if frame.Cooldown.SetCountdownFont then
            local fontObjName = "WishFlex_CDFont_" .. category .. (rowIndex or "1")
            local fontObj = _G[fontObjName] or CreateFont(fontObjName)
            fontObj:SetFont(fontPath, cdSize, outline)
            frame.Cooldown:SetCountdownFont(fontObjName)
        end
        if frame.Cooldown.GetCountdownFontString then
            local fs = frame.Cooldown:GetCountdownFontString()
            if fs then FormatText(fs, false) end
        end
        for _, region in pairs({frame.Cooldown:GetRegions()}) do
            if region and region.IsObjectType and region:IsObjectType("FontString") then
                FormatText(region, false)
            end
        end
    end

    if frame.text and frame.text ~= stackText then FormatText(frame.text, false) end
    if frame.value and frame.value ~= stackText then FormatText(frame.value, false) end
    
    FormatText(stackText, true)
end

local function WeldToMover(frame)
    if frame and frame.mover then
        if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", frame.mover, "CENTER")
    end
end

local function ForceBuffsLayout()
    local db = E.db.WishFlex.cdManager
    local function LayoutBuffs(viewerName, key, isVertical)
        local container = _G[viewerName]
        if not container or not container:IsShown() then return end
        
        WeldToMover(container)
        
        local icons = {}
        if container.itemFramePool then
            for f in container.itemFramePool:EnumerateActive() do
                if f:IsShown() and f:GetWidth() > 10 then 
                    table.insert(icons, f); 
                    SuppressDebuffBorder(f);
                    mod:ApplyText(f, key)
                    mod:ApplySwipeSettings(f)
                end
            end
        end
        if #icons == 0 then return end
        table.sort(icons, function(a, b) return (a:GetLeft() or 0) < (b:GetLeft() or 0) end)
        
        local cfg = db[key]
        local w, h = cfg.width or 45, cfg.height or 45
        local gap = cfg.iconGap or 2
        local growth = cfg.growth or (isVertical and "DOWN" or "CENTER")
        
        if isVertical then
            local totalHeight = (#icons * h) + math.max(0, (#icons - 1) * gap)
            container:SetSize(w, math.max(h, totalHeight))
            if container.mover then container.mover:SetSize(w, math.max(h, totalHeight)) end
            
            for i, f in ipairs(icons) do
                f:ClearAllPoints()
                local y = 0
                if growth == "DOWN" then 
                    y = -((i - 1) * (h + gap))
                    f:SetPoint("TOP", container, "TOP", 0, y)
                elseif growth == "UP" then 
                    y = (i - 1) * (h + gap)
                    f:SetPoint("BOTTOM", container, "BOTTOM", 0, y)
                else
                    y = -((i - 1) * (h + gap))
                    f:SetPoint("TOP", container, "TOP", 0, y)
                end
                
                f:SetSize(w, h)
                if f.Icon then
                    local iconObj = f.Icon.Icon or f.Icon
                    if not f.Bar then f.Icon:SetSize(w, h); mod.ApplyTexCoord(iconObj, w, h)
                    else 
                        f.Icon:SetSize(h, h); f.Bar:SetSize(w - h - 2, h)
                        f.Bar:ClearAllPoints(); f.Bar:SetPoint("LEFT", f.Icon, "RIGHT", 2, 0)
                        if iconObj then mod.ApplyTexCoord(iconObj, h, h) end 
                    end
                end
            end
        else
            local totalWidth = (#icons * w) + math.max(0, (#icons - 1) * gap)
            container:SetSize(math.max(w, totalWidth), h)
            if container.mover then container.mover:SetSize(math.max(w, totalWidth), h) end
            
            for i, f in ipairs(icons) do
                f:ClearAllPoints()
                local x = 0
                if growth == "CENTER" then 
                    x = -(totalWidth / 2) + (w / 2) + (i - 1) * (w + gap)
                    f:SetPoint("CENTER", container, "CENTER", x, 0)
                elseif growth == "LEFT" then 
                    x = -(i - 1) * (w + gap); f:SetPoint("RIGHT", container, "RIGHT", x, 0)
                elseif growth == "RIGHT" then 
                    x = (i - 1) * (w + gap); f:SetPoint("LEFT", container, "LEFT", x, 0) 
                end
                
                f:SetSize(w, h)
                if f.Icon then
                    local iconObj = f.Icon.Icon or f.Icon
                    if not f.Bar then f.Icon:SetSize(w, h); mod.ApplyTexCoord(iconObj, w, h)
                    else 
                        f.Icon:SetSize(h, h); f.Bar:SetSize(w - h - 2, h)
                        f.Bar:ClearAllPoints(); f.Bar:SetPoint("LEFT", f.Icon, "RIGHT", 2, 0)
                        if iconObj then mod.ApplyTexCoord(iconObj, h, h) end 
                    end
                end
            end
        end
    end
    LayoutBuffs("BuffIconCooldownViewer", "BuffIcon", false)
    LayoutBuffs("BuffBarCooldownViewer", "BuffBar", true)
end

local isUpdatingLayout = false
function mod:UpdateAllLayouts()
    if isUpdatingLayout then return end
    isUpdatingLayout = true

    local db = E.db.WishFlex.cdManager
    mod.activeTrackedFrames = {}

    local uViewer = _G.UtilityCooldownViewer
    if uViewer and uViewer.itemFramePool then
        WeldToMover(uViewer)
        
        local cfg = db.Utility
        local frames = {}
        for f in uViewer.itemFramePool:EnumerateActive() do if f:IsShown() then table.insert(frames, f) end end
        table.sort(frames, function(a, b) return (a.layoutIndex or 999) < (b.layoutIndex or 999) end)
        
        local w, h = cfg.width or 45, cfg.height or 30
        local gap = cfg.iconGap or 2
        local growth = cfg.growth or "CENTER"
        
        local totalW = (#frames * w) + math.max(0, (#frames - 1) * gap)
        uViewer:SetSize(math.max(w, totalW), h)
        if uViewer.mover then uViewer.mover:SetSize(math.max(w, totalW), h) end

        for i, f in ipairs(frames) do
            f:ClearAllPoints()
            local x = 0
            if growth == "CENTER" then 
                x = -(totalW / 2) + (w / 2) + (i - 1) * (w + gap)
                f:SetPoint("CENTER", uViewer, "CENTER", x, 0)
            elseif growth == "LEFT" then 
                x = -(i - 1) * (w + gap); f:SetPoint("RIGHT", uViewer, "RIGHT", x, 0)
            elseif growth == "RIGHT" then 
                x = (i - 1) * (w + gap); f:SetPoint("LEFT", uViewer, "LEFT", x, 0) 
            end

            f:SetSize(w, h)
            if f.Icon then local iconObj = f.Icon.Icon or f.Icon; f.Icon:SetSize(w, h); mod.ApplyTexCoord(iconObj, w, h) end
            
            SuppressDebuffBorder(f)
            mod:ApplyText(f, "Utility")
            mod:ApplySwipeSettings(f)
            table.insert(mod.activeTrackedFrames, f)
        end
    end

    local eViewer = _G.EssentialCooldownViewer
    if eViewer and eViewer.itemFramePool then
        WeldToMover(eViewer)
        
        local frames = {}
        for f in eViewer.itemFramePool:EnumerateActive() do if f:IsShown() then table.insert(frames, f) end end
        table.sort(frames, function(a, b) return (a.layoutIndex or 999) < (b.layoutIndex or 999) end)

        local cfgE = db.Essential
        if cfgE.enableCustomLayout then
            local r1, r2 = {}, {}
            for i, f in ipairs(frames) do 
                f:ClearAllPoints()
                if i <= cfgE.maxPerRow then table.insert(r1, f) else table.insert(r2, f) end 
            end

            -- ========================================================
            -- 【精髓注入】将饰品/药水模块 (ActionTimer) 无缝合并到第二行
            -- ========================================================
            local AT = WUI:GetModule('ActionTimer', true)
            if cfgE.injectActionTimer and AT and AT.Frames and AT.trackedItems then
                local activeAT = {}
                for uniqueKey, data in pairs(AT.trackedItems) do
                    if AT.Frames[uniqueKey] and AT.Frames[uniqueKey]:IsShown() then 
                        table.insert(activeAT, AT.Frames[uniqueKey]) 
                    end
                end
                table.sort(activeAT, function(a, b) return a.data.id < b.data.id end)
                for _, f in ipairs(activeAT) do
                    f.isHijackedByEssential = true
                    table.insert(r2, f)
                end
                
                if not AT._essentialInjectHooked then
                    AT._essentialInjectHooked = true
                    hooksecurefunc(AT, "UpdateLayout", function()
                        if E.db.WishFlex.cdManager.Essential.injectActionTimer then
                            mod:ScheduleLayout()
                        end
                    end)
                end
            else
                if AT and AT.Frames then
                    for _, f in pairs(AT.Frames) do f.isHijackedByEssential = false end
                end
            end
            -- ========================================================

            local w1, h1, gap = cfgE.row1Width, cfgE.row1Height, cfgE.iconGap
            local totalW1 = (#r1 * w1) + math.max(0, (#r1 - 1) * gap)
            eViewer:SetSize(math.max(w1, totalW1), h1)
            if eViewer.mover then eViewer.mover:SetSize(math.max(w1, totalW1), h1) end
            
            for i, f in ipairs(r1) do
                local startX1 = -(totalW1 / 2) + (w1 / 2)
                f:SetPoint("CENTER", eViewer, "CENTER", startX1 + (i - 1) * (w1 + gap), 0)
                f:SetSize(w1, h1)
                local iconTex = f.Icon and (f.Icon.Icon or f.Icon)
                if iconTex then mod.ApplyTexCoord(iconTex, w1, h1) end
                
                SuppressDebuffBorder(f)
                mod:ApplyText(f, "Essential", 1)
                mod:ApplySwipeSettings(f)
                table.insert(mod.activeTrackedFrames, f)
            end

            if not _G.WishFlex_CooldownRow2_Anchor then _G.WishFlex_CooldownRow2_Anchor = CreateFrame("Frame", "WishFlex_CooldownRow2_Anchor", E.UIParent) end
            WeldToMover(_G.WishFlex_CooldownRow2_Anchor)
            
            local w2, h2 = cfgE.row2Width, cfgE.row2Height
            local gap2 = cfgE.row2IconGap or 2
            local totalW2 = (#r2 * w2) + math.max(0, (#r2 - 1) * gap2)
            
            _G.WishFlex_CooldownRow2_Anchor:SetSize(math.max(w2, totalW2), h2)
            if _G.WishFlex_CooldownRow2_Anchor.mover then _G.WishFlex_CooldownRow2_Anchor.mover:SetSize(math.max(w2, totalW2), h2) end
            
            for i, f in ipairs(r2) do
                local startX2 = -(totalW2 / 2) + (w2 / 2)
                f:ClearAllPoints()
                f:SetPoint("CENTER", _G.WishFlex_CooldownRow2_Anchor, "CENTER", startX2 + (i - 1) * (w2 + gap2), 0)
                f:SetSize(w2, h2)
                local iconTex = f.Icon and (f.Icon.Icon or f.Icon)
                if iconTex then mod.ApplyTexCoord(iconTex, w2, h2) end
                
                if f.isHijackedByEssential then
                    local cdSize = cfgE.row2CdFontSize or 18
                    local cdColor = cfgE.row2CdFontColor or {r=1, g=0.82, b=0}
                    local cdX = cfgE.row2CdXOffset or 0
                    local cdY = cfgE.row2CdYOffset or 0
                    
                    local fontPath = LSM:Fetch('font', db.countFont or "Expressway")
                    local outline = db.countFontOutline or "OUTLINE"

                    local function FormatHijackCDText(t)
                        if not t or type(t) ~= "table" or not t.SetFont then return end
                        if t:GetFont() ~= fontPath or t._lastSize ~= cdSize or t._lastOutline ~= outline then
                            t:FontTemplate(fontPath, cdSize, outline)
                            t._lastSize = cdSize; t._lastOutline = outline
                        end
                        t._isHijackStyling = true
                        t:ClearAllPoints()
                        t:SetPoint("CENTER", f, "CENTER", cdX, cdY)
                        t:SetTextColor(cdColor.r, cdColor.g, cdColor.b)
                        t._isHijackStyling = false
                        
                        if not t._hijackHooked then
                            t._hijackHooked = true
                            hooksecurefunc(t, "SetPoint", function(self)
                                if self._isHijackStyling then return end
                                if not (self._hijackParent and self._hijackParent.isHijackedByEssential) then return end
                                self._isHijackStyling = true
                                self:ClearAllPoints()
                                self:SetPoint("CENTER", self._hijackParent, "CENTER", self._hijackX, self._hijackY)
                                self._isHijackStyling = false
                            end)
                            hooksecurefunc(t, "SetTextColor", function(self)
                                if self._isHijackStyling then return end
                                if not (self._hijackParent and self._hijackParent.isHijackedByEssential) then return end
                                self._isHijackStyling = true
                                self:SetTextColor(self._hijackColor.r, self._hijackColor.g, self._hijackColor.b)
                                self._isHijackStyling = false
                            end)
                        end
                        t._hijackParent = f
                        t._hijackX = cdX
                        t._hijackY = cdY
                        t._hijackColor = cdColor
                    end

                    if f.Cooldown then
                        if f.Cooldown.timer and f.Cooldown.timer.text then FormatHijackCDText(f.Cooldown.timer.text) end
                        if f.Cooldown.SetCountdownFont then
                            local fontObjName = "WishFlex_HijackCDFont_" .. i
                            local fontObj = _G[fontObjName] or CreateFont(fontObjName)
                            fontObj:SetFont(fontPath, cdSize, outline)
                            f.Cooldown:SetCountdownFont(fontObjName)
                        end
                        if f.Cooldown.GetCountdownFontString then
                            local fs = f.Cooldown:GetCountdownFontString()
                            if fs then FormatHijackCDText(fs) end
                        end
                        for _, region in pairs({f.Cooldown:GetRegions()}) do
                            if region and region.IsObjectType and region:IsObjectType("FontString") then
                                FormatHijackCDText(region)
                            end
                        end
                    end
                    
                    if f.Count then
                        if f.Count:GetFont() ~= fontPath or f.Count._lastSize ~= cdSize or f.Count._lastOutline ~= outline then
                            f.Count:FontTemplate(fontPath, cdSize, outline)
                            f.Count._lastSize = cdSize; f.Count._lastOutline = outline
                        end
                        f.Count._isHijackStyling = true
                        f.Count:ClearAllPoints()
                        f.Count:SetPoint("CENTER", f, "CENTER", cdX, cdY)
                        f.Count._isHijackStyling = false
                        
                        if not f.Count._hijackHooked then
                            f.Count._hijackHooked = true
                            hooksecurefunc(f.Count, "SetPoint", function(self)
                                if self._isHijackStyling then return end
                                if not (self._hijackParent and self._hijackParent.isHijackedByEssential) then return end
                                self._isHijackStyling = true
                                self:ClearAllPoints()
                                self:SetPoint("CENTER", self._hijackParent, "CENTER", self._hijackX, self._hijackY)
                                self._isHijackStyling = false
                            end)
                        end
                        f.Count._hijackParent = f
                        f.Count._hijackX = cdX
                        f.Count._hijackY = cdY
                    end
                    
                    mod:ApplySwipeSettings(f)
                else
                    SuppressDebuffBorder(f)
                    mod:ApplyText(f, "Essential", 2)
                    mod:ApplySwipeSettings(f)
                    table.insert(mod.activeTrackedFrames, f)
                end
            end
        end
    end

    isUpdatingLayout = false
end

function mod:ScheduleLayout()
    if self.layoutTimer then return end
    self.layoutTimer = E:Delay(0.05, function()
        self.layoutTimer = nil
        self:UpdateAllLayouts()
    end)
end

local function SafeMover(frame, moverName, title, defaultPoint)
    if not frame then return end
    if not frame:GetNumPoints() or frame:GetNumPoints() == 0 then frame:SetPoint(unpack(defaultPoint)) end
    if not frame.mover then E:CreateMover(frame, moverName, title, nil, nil, nil, "ALL,WishFlex") end
end

function mod:Initialize()
    InjectOptions(); if not E.db.WishFlex.modules.cooldownCustom then return end
    
    self:CacheAllSpells()
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CacheAllSpells")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "CacheAllSpells")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "CacheAllSpells")
    
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "UpdateKnownDefensives")
    self:RegisterEvent("SPELLS_CHANGED", "UpdateKnownDefensives")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "UpdateDefensiveCooldowns")
    self:RegisterEvent("SPELL_UPDATE_CHARGES", "UpdateDefensiveCooldowns")

    local defViewer = CreateFrame("Frame", "WishFlex_DefensiveViewer", E.UIParent)
    defViewer:SetSize(45, 45)
    SafeMover(defViewer, "WishFlexDefensiveMover", "WishFlex: 防御技能", {"CENTER", E.UIParent, "CENTER", 0, -150})
    self:UpdateKnownDefensives()

    if not _G.WishFlex_CooldownRow2_Anchor then _G.WishFlex_CooldownRow2_Anchor = CreateFrame("Frame", "WishFlex_CooldownRow2_Anchor", E.UIParent) end
    SafeMover(_G.UtilityCooldownViewer, "WishFlexUtilityMover", "WishFlex: 效能技能", {"CENTER", E.UIParent, "CENTER", 0, -100})
    SafeMover(_G.EssentialCooldownViewer, "WishFlexEssentialMover", "WishFlex: 重要技能(第一行)", {"CENTER", E.UIParent, "CENTER", 0, 50})
    SafeMover(_G.WishFlex_CooldownRow2_Anchor, "WishFlexEssentialRow2Mover", "WishFlex: 重要技能(第二行)", {"CENTER", E.UIParent, "CENTER", 0, -50})
    SafeMover(_G.BuffIconCooldownViewer, "WishFlexBuffIconMover", "WishFlex: 增益图标", {"CENTER", E.UIParent, "CENTER", 0, 150})
    SafeMover(_G.BuffBarCooldownViewer, "WishFlexBuffBarMover", "WishFlex: 增益条", {"CENTER", E.UIParent, "CENTER", 0, 100})

    local isHookingGlow = false
    if LCG then
        hooksecurefunc(LCG, "PixelGlow_Start", function(frame, color, lines, frequency, length, thickness, xOffset, yOffset, drawLayer, key)
            if isHookingGlow then return end; if not frame then return end; if key == "WishEssentialGlow" or key == "DefensiveGlow" then return end
            local cat = GetKeyFromFrame(frame)
            if cat == "Essential" then
                isHookingGlow = true; LCG.PixelGlow_Stop(frame, key); isHookingGlow = false
                local cfg = E.db.WishFlex.cdManager.Essential
                if cfg and cfg.glowEnable then
                    if not frame._wishEssentialGlow then
                        local c = cfg.glowColor
                        local gr, gg, gb, ga = 1, 0.8, 0, 1
                        if c then gr, gg, gb, ga = c.r, c.g, c.b, c.a end
                        LCG.PixelGlow_Start(frame, {gr, gg, gb, ga}, cfg.glowLines or 8, cfg.glowFreq or 0.25, cfg.glowLength or 10, cfg.glowThick or 2, xOffset, yOffset, drawLayer, "WishEssentialGlow")
                        frame._wishEssentialGlow = true
                    end
                end
            end
        end)
        hooksecurefunc(LCG, "PixelGlow_Stop", function(frame, key)
            if isHookingGlow then return end
            if key ~= "WishEssentialGlow" and frame and frame._wishEssentialGlow then
                local cat = GetKeyFromFrame(frame)
                if cat == "Essential" then
                    isHookingGlow = true; LCG.PixelGlow_Stop(frame, "WishEssentialGlow"); frame._wishEssentialGlow = false; isHookingGlow = false
                end
            end
        end)
    end

    local viewers = {"EssentialCooldownViewer", "UtilityCooldownViewer"}
    for _, name in ipairs(viewers) do
        local v = _G[name]
        if v then
            if type(v.Layout) == "function" then hooksecurefunc(v, "Layout", function() mod:UpdateAllLayouts() end) end
            if type(v.UpdateLayout) == "function" then hooksecurefunc(v, "UpdateLayout", function() mod:UpdateAllLayouts() end) end
            v:HookScript("OnShow", function() mod:UpdateAllLayouts() end)
            if v.itemFramePool and type(v.itemFramePool.Acquire) == "function" then
                hooksecurefunc(v.itemFramePool, "Acquire", function() mod:UpdateAllLayouts() end)
            end
        end
    end

    C_Timer.NewTicker(0.05, function() ForceBuffsLayout() end)

    local tickerFrame = CreateFrame("Frame")
    local tickElapsed = 0
    tickerFrame:SetScript("OnUpdate", function(_, delta)
        tickElapsed = tickElapsed + delta
        local interval = InCombatLockdown() and 0.1 or 0.5
        if tickElapsed >= interval then
            tickElapsed = 0
            
            local db = E.db.WishFlex.cdManager
            local t = GetTime()
            local fPath = LSM:Fetch('font', db.countFont or "Expressway")
            local outline = db.countFontOutline or "OUTLINE"

            for _, frame in ipairs(mod.activeTrackedFrames or {}) do
                local cat = GetKeyFromFrame(frame)
                if cat then
                    local rIdx = (frame.layoutIndex and frame.layoutIndex > (db.Essential.maxPerRow or 7)) and 2 or 1
                    mod:ApplyText(frame, cat, rIdx)
                end
            end
            
            if mod.activeDefensives and mod.defensiveIcons then
                local defDB = db.Defensives
                
                for i, spellID in ipairs(mod.activeDefensives) do
                    local f = mod.defensiveIcons[i]
                    if f and f:IsShown() then
                        local effectiveID = GetEffectiveSpellID(spellID)
                        local isBuffing = false
                        local buffTimeLeft = 0

                        local activeData = mod.activeBuffs[effectiveID] or mod.activeBuffs[spellID]
                        if activeData and activeData.endTime > t then
                            local elapsed = activeData.duration - (activeData.endTime - t)
                            if elapsed > 1.5 and not CheckAuraValid(effectiveID, false) and not CheckAuraValid(spellID, false) then
                                activeData.endTime = 0
                            else
                                isBuffing = true
                                buffTimeLeft = activeData.endTime - t
                            end
                        end

                        if isBuffing then
                            f.Icon:SetDesaturation(0)
                            f.Icon:SetVertexColor(1, 1, 1)
                            
                            f.Count:ClearAllPoints()
                            f.Count:SetPoint("CENTER", f.Icon, "CENTER", defDB.buffXOffset or 0, defDB.buffYOffset or 0)
                            f.Count:SetText(FormatTime(buffTimeLeft))
                            local bc = defDB.buffFontColor or {r=0, g=1, b=0}
                            f.Count:SetTextColor(bc.r, bc.g, bc.b)
                            f.Count:FontTemplate(fPath, defDB.buffFontSize or 18, outline)
                            
                            f.Cooldown.noCooldownCount = true
                            if f.Cooldown.timer and f.Cooldown.timer.text then f.Cooldown.timer.text:SetAlpha(0) end
                            f.Cooldown:SetHideCountdownNumbers(true)

                            if not f.wasSetFromAura or f.lastBuffEndTime ~= activeData.endTime then
                                f.wasSetFromAura = true
                                f.lastBuffEndTime = activeData.endTime
                                f.Cooldown:SetCooldown(activeData.endTime - activeData.duration, activeData.duration)
                            end

                            if defDB.glowEnable and not f.isGlowActive and LCG then
                                local gc = defDB.glowColor or {r=0, g=1, b=0.5, a=1}
                                LCG.PixelGlow_Start(f, {gc.r, gc.g, gc.b, gc.a}, defDB.glowLines or 8, defDB.glowFreq or 0.25, 10, defDB.glowThick or 2, 0, 0, false, "DefensiveGlow")
                                f.isGlowActive = true
                            end
                        else
                            if f.isGlowActive and LCG then
                                LCG.PixelGlow_Stop(f, "DefensiveGlow")
                                f.isGlowActive = false
                            end
                            
                            f.Cooldown.noCooldownCount = nil
                            f.Cooldown:SetHideCountdownNumbers(false)
                            
                            local defCDFontSize = defDB.cdFontSize or 18
                            local defCDX = defDB.cdXOffset or 0
                            local defCDY = defDB.cdYOffset or 0
                            local defCDColor = defDB.cdFontColor or {r=1, g=0.82, b=0}

                            local function ApplyDefensiveCDText(t)
                                if not t or not t.SetAlpha then return end
                                t:SetAlpha(1)
                                
                                if t:GetFont() ~= fPath or t._lastSize ~= defCDFontSize then
                                    t:FontTemplate(fPath, defCDFontSize, outline)
                                    t._lastSize = defCDFontSize
                                end
                                
                                t._isDefStyling = true
                                t:ClearAllPoints()
                                t:SetPoint("CENTER", f.Icon, "CENTER", defCDX, defCDY)
                                t:SetTextColor(defCDColor.r, defCDColor.g, defCDColor.b)
                                t._isDefStyling = false
                                
                                if not t._defStyleHooked then
                                    t._defStyleHooked = true
                                    hooksecurefunc(t, "SetPoint", function(self)
                                        if self._isDefStyling then return end
                                        self._isDefStyling = true
                                        self:ClearAllPoints()
                                        self:SetPoint("CENTER", self._defIcon, "CENTER", self._defX, self._defY)
                                        self._isDefStyling = false
                                    end)
                                    hooksecurefunc(t, "SetTextColor", function(self)
                                        if self._isDefStyling then return end
                                        self._isDefStyling = true
                                        self:SetTextColor(self._defColor.r, self._defColor.g, self._defColor.b)
                                        self._isDefStyling = false
                                    end)
                                end
                                
                                t._defIcon = f.Icon
                                t._defX = defCDX
                                t._defY = defCDY
                                t._defColor = defCDColor
                            end

                            if f.Cooldown.timer and f.Cooldown.timer.text then ApplyDefensiveCDText(f.Cooldown.timer.text) end
                            if f.Cooldown.GetCountdownFontString then
                                local fs = f.Cooldown:GetCountdownFontString()
                                if fs then ApplyDefensiveCDText(fs) end
                            end
                            for _, region in pairs({f.Cooldown:GetRegions()}) do
                                if region and region.IsObjectType and region:IsObjectType("FontString") then
                                    ApplyDefensiveCDText(region)
                                end
                            end
                            if f.Cooldown.SetCountdownFont then
                                local fontObjName = "WishFlex_DefensiveCDFont"
                                local fontObj = _G[fontObjName] or CreateFont(fontObjName)
                                fontObj:SetFont(fPath, defCDFontSize, outline)
                                f.Cooldown:SetCountdownFont(fontObjName)
                            end

                            local sc = defDB.stackFontColor or {r=1, g=1, b=1}
                            f.Count:SetTextColor(sc.r, sc.g, sc.b)
                            f.Count:ClearAllPoints()
                            f.Count:SetPoint("CENTER", f.Icon, "CENTER", defDB.stackXOffset or 12, defDB.stackYOffset or -12)
                            f.Count:FontTemplate(fPath, defDB.stackFontSize or 14, outline)
                            
                            local maxC = mod.spellMaxChargesCache[effectiveID] or 0
                            if maxC > 1 then
                                local cInfo = C_Spell and C_Spell.GetSpellCharges(effectiveID)
                                if cInfo then
                                    f.Count:SetText(cInfo.currentCharges)
                                else
                                    f.Count:SetText("")
                                end
                            else
                                f.Count:SetText("")
                            end

                            if f.wasSetFromAura then
                                f.wasSetFromAura = false

                                local CCD = C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(effectiveID)
                                local SCD = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(effectiveID)

                                if f.Cooldown.timer then
                                    f.Cooldown.timer.start = nil
                                    f.Cooldown.timer.duration = nil
                                    f.Cooldown.timer:Show()
                                end

                                if CCD and f.Cooldown.SetCooldownFromDurationObject then
                                    f.Cooldown:SetCooldownFromDurationObject(CCD)
                                elseif SCD and f.Cooldown.SetCooldownFromDurationObject then
                                    f.Cooldown:SetCooldownFromDurationObject(SCD)
                                else
                                    f.Cooldown:Clear()
                                end
                            end

                            local cInfo = C_Spell.GetSpellCooldown(effectiveID)
                            local sDur = cInfo and cInfo.duration or 0
                            local currSCD = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(effectiveID)
                            
                           if defDB.desaturate and currSCD and DesaturationCurve and currSCD.EvaluateRemainingDuration then
                                pcall(function()
                                    local desat = currSCD:EvaluateRemainingDuration(DesaturationCurve, 0) or 0
                                    f.Icon:SetDesaturation(desat)
                                    if desat > 0 then f.Icon:SetVertexColor(0.5, 0.5, 0.5) else f.Icon:SetVertexColor(1, 1, 1) end
                                end)
                            else
                                f.Icon:SetDesaturation(0)
                                f.Icon:SetVertexColor(1, 1, 1)
                            end
                        end
                    end
                end
            end
            
        end
    end)
    
    E:Delay(1, function() mod:UpdateAllLayouts(); mod:LayoutDefensives() end)
    E:Delay(3, function() mod:LayoutDefensives() end)
end