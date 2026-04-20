local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}

local CDMod = {}
WF.CooldownCustomAPI = CDMod 

CDMod.hiddenCDs = {}
CDMod.hiddenBuffs = {}
CDMod.Movers = {} 
local BaseSpellCache = {}

local DEFAULT_SWIPE_COLOR = {r = 0, g = 0, b = 0, a = 0.5}
local DEFAULT_ACTIVE_AURA_COLOR = {r = 0, g = 0, b = 0, a = 0.5}
local DEFAULT_CD_COLOR = {r = 1, g = 1, b = 1}
local DEFAULT_STACK_COLOR = {r = 1, g = 1, b = 1}

local DefaultConfig = {
    enable = true, countFont = "Expressway", countFontOutline = "OUTLINE", countFontColor = DEFAULT_STACK_COLOR,
    swipeColor = DEFAULT_SWIPE_COLOR, activeAuraColor = DEFAULT_ACTIVE_AURA_COLOR, reverseSwipe = true,
    Essential = { width = 48, height = 40, iconGap = 1, cdFontSize = 16, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0, maxPerRow = 999 },
    Utility = { snapToEssential = true, width = 40, height = 35, iconGap = 1, cdFontSize = 16, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0, maxPerRow = 999 },
    Defensive = { attachToPlayer = true, width = 35, height = 28, iconGap = 1, cdFontSize = 14, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "TOP", stackXOffset = 0, stackYOffset = 7, maxPerRow = 999 },
    ExtraMonitor = { attachToPlayer = true, snapToEssential = false, width = 30, height = 25, iconGap = 1, cdFontSize = 14, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOM", stackXOffset = 0, stackYOffset = -6, maxPerRow = 999 },
    BuffBar = { showIcon = true, iconPosition = "LEFT", width = 150, height = 24, barHeight = 24, barTexture = "Blizzard", barPosition = "CENTER", iconGap = 1, growth = "DOWN", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "LEFT", stackXOffset = 5, stackYOffset = 0 },
    BuffIcon = { snapToResource = false, snapToEssential = false, width = 40, height = 35, iconGap = 1, growth = "CENTER_HORIZONTAL", cdFontSize = 14, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "TOP", stackXOffset = 0, stackYOffset = 7, maxPerRow = 999 },
    ItemBuff = { snapToBuffIcon = true, attachToPlayer = false, width = 40, height = 30, iconGap = 1, cdFontSize = 14, cdFontColor = {r=0, g=1, b=0, a=1}, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0, maxPerRow = 999 }
}

local function MigrateOldSettings(db)
    if not db or not db.Essential then return end
    if db.Essential.row1Width then
        db.Essential.width = db.Essential.row1Width; db.Essential.height = db.Essential.row1Height
        db.Essential.cdFontSize = db.Essential.row1CdFontSize; db.Essential.cdFontColor = db.Essential.row1CdFontColor
        db.Essential.cdPosition = db.Essential.row1CdPosition; db.Essential.cdXOffset = db.Essential.row1CdXOffset; db.Essential.cdYOffset = db.Essential.row1CdYOffset
        db.Essential.stackFontSize = db.Essential.row1StackFontSize; db.Essential.stackFontColor = db.Essential.row1StackFontColor
        db.Essential.stackPosition = db.Essential.row1StackPosition; db.Essential.stackXOffset = db.Essential.row1StackXOffset; db.Essential.stackYOffset = db.Essential.row1StackYOffset
        local keysToRemove = {"row1Width", "row1Height", "row1CdFontSize", "row1CdFontColor", "row1CdPosition", "row1CdXOffset", "row1CdYOffset", "row1StackFontSize", "row1StackFontColor", "row1StackPosition", "row1StackXOffset", "row1StackYOffset", "row2Width", "row2Height", "row2CdFontSize", "row2CdFontColor", "row2CdPosition", "row2CdXOffset", "row2CdYOffset", "row2StackFontSize", "row2StackFontColor", "row2StackPosition", "row2StackXOffset", "row2StackYOffset", "rowYGap", "row2IconGap", "enableCustomLayout", "attachToPlayer", "attachX", "attachY", "offsetX", "offsetY"}
        for _, k in ipairs(keysToRemove) do db.Essential[k] = nil end
    end
    if db.Utility then db.Utility.attachToPlayer = nil; db.Utility.attachX = nil; db.Utility.attachY = nil; db.Utility.offsetX = nil; db.Utility.offsetY = nil; if db.Utility.snapToEssential == nil then db.Utility.snapToEssential = true end end
    if db.Defensive then
        if db.Defensive.attachX then db.Defensive.offsetX = db.Defensive.attachX; db.Defensive.attachX = nil end
        if db.Defensive.attachY then db.Defensive.offsetY = db.Defensive.attachY; db.Defensive.attachY = nil end
        db.Defensive.offsetX = nil; db.Defensive.offsetY = nil
    end
    if db.BuffIcon then 
        db.BuffIcon.offsetX = nil; 
        db.BuffIcon.offsetY = nil 
        db.BuffIcon.snapToResource = false 
    end
    if db.BuffBar then db.BuffBar.offsetX = nil; db.BuffBar.offsetY = nil end
    if db.ItemBuff and db.ItemBuff.snapToBuffIcon == nil then db.ItemBuff.snapToBuffIcon = true end
end

-- 【核心修复】：废除物理像素转化，回归纯净逻辑像素！
function CDMod.GetOnePixelSize()
    return 1
end

function CDMod.PixelSnap(value)
    if not value then return 0 end
    return value -- 取消浮点数吸附，彻底消灭GPU由于亚像素产生的取整撕裂
end

function CDMod:GetCurrentSpecID()
    local specIdx = GetSpecialization(); if not specIdx then return 0 end
    return GetSpecializationInfo(specIdx) or 0
end

function CDMod:SyncSpecGroups()
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
    local db = WF.db.cooldownCustom; if not db then return end
    if not db.SpecStorage then db.SpecStorage = {} end
    local specID = self:GetCurrentSpecID()
    if not db.SpecStorage[specID] then
        db.SpecStorage[specID] = { CustomRows = {}, CustomBuffRows = {} }
        if not db._migratedGroups then
            if db.CustomRows then for _, v in ipairs(db.CustomRows) do table.insert(db.SpecStorage[specID].CustomRows, v) end end
            if db.CustomBuffRows then for _, v in ipairs(db.CustomBuffRows) do table.insert(db.SpecStorage[specID].CustomBuffRows, v) end end
            db._migratedGroups = true
        end
    end
    db.CustomRows = db.SpecStorage[specID].CustomRows
    db.CustomBuffRows = db.SpecStorage[specID].CustomBuffRows
end

local function WeldToMover(frame, anchorFrame) 
    if frame and anchorFrame then 
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", anchorFrame, "CENTER")
    end 
end

local function EnsureMoverExists(r, isBuff, isDefensive)
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
    local anchorName = isDefensive and "WishFlex_Anchor_Defensive" or "WishFlex_Anchor_"..r
    local frame = _G[anchorName]
    if not frame then frame = CreateFrame("Frame", anchorName, UIParent); frame:SetSize(45, 45) end
    
    local moverName = anchorName .. "Mover"
    local mover = _G[moverName]
    if not mover then
        local title = isDefensive and "冷却：防御技能" or ((isBuff and "增益：" or "冷却：") .. r)
        if r == "ExtraMonitor" then title = "冷却：额外监控" end
        if r == "ItemBuff" then title = "物品/药水持续时间" end
        local point = isDefensive and {"TOP", UIParent, "CENTER", 0, -180} or {"CENTER", UIParent, "CENTER", 0, 0}
        
        mover = CreateFrame("Button", moverName, UIParent, "BackdropTemplate")
        mover:SetFrameStrata("HIGH"); mover:SetFrameLevel(100); mover:SetSize(45, 45); mover.isWishFlexMover = true
        
        if WF.db.movers and WF.db.movers[moverName] then 
            local p = WF.db.movers[moverName]; mover:SetPoint(p.point, UIParent, p.relativePoint, p.xOfs, p.yOfs) 
        else mover:SetPoint(unpack(point)) end
        
        mover:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
        mover:SetBackdropColor(0, 0.5, 1, 0.4)
        mover:SetBackdropBorderColor(0, 0.5, 1, 0.6)
        
        local label = mover:CreateFontString(nil, "OVERLAY")
        label:SetPoint("BOTTOM", mover, "TOP", 0, 4)
        label:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        label:SetTextColor(1, 1, 1, 1)
        
        local labelText = title
        if isDefensive or r == "ExtraMonitor" or r == "ItemBuff" then
            labelText = title .. "\n|cffaaaaaa(右键开关吸附)|r"
        end
        label:SetText(labelText)
        mover.label = label
        
        mover:EnableMouse(true); mover:SetMovable(true); mover:RegisterForDrag("LeftButton")
        mover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        mover:SetScript("OnDragStart", function(self)
            if EditModeManagerFrame and type(EditModeManagerFrame.ClearSelectedSystem) == "function" then pcall(function() EditModeManagerFrame:ClearSelectedSystem() end) end
            WF:SelectMover(self, false); self:StartMoving() 
        end)
        
        mover:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if not WF.db.movers then WF.db.movers = {} end
            
            local cx, cy = self:GetCenter()
            local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
            if cx and cy and pw and ph then
                local saveKey = self:GetName()
                if not WF.db.movers[saveKey] then WF.db.movers[saveKey] = {} end
                local m = WF.db.movers[saveKey]
                m.point = "CENTER"
                m.relativePoint = "CENTER"
                m.xOfs = cx - pw/2
                m.yOfs = cy - ph/2
            end
            
            if isDefensive and WF.db.cooldownCustom and WF.db.cooldownCustom.Defensive then WF.db.cooldownCustom.Defensive.attachToPlayer = false end
            if r == "ExtraMonitor" and WF.db.cooldownCustom and WF.db.cooldownCustom.ExtraMonitor then WF.db.cooldownCustom.ExtraMonitor.attachToPlayer = false end
            if r == "ItemBuff" and WF.db.cooldownCustom and WF.db.cooldownCustom.ItemBuff then WF.db.cooldownCustom.ItemBuff.snapToBuffIcon = false end
            
            CDMod:MarkLayoutDirty(true) 
        end)
        
        mover:Hide()
        mover:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                if EditModeManagerFrame and type(EditModeManagerFrame.ClearSelectedSystem) == "function" then pcall(function() EditModeManagerFrame:ClearSelectedSystem() end) end
                WF:SelectMover(self, false)
            elseif button == "RightButton" then
                if isDefensive and WF.db.cooldownCustom and WF.db.cooldownCustom.Defensive then
                    WF.db.cooldownCustom.Defensive.attachToPlayer = not WF.db.cooldownCustom.Defensive.attachToPlayer
                    CDMod:MarkLayoutDirty(true)
                elseif r == "ExtraMonitor" and WF.db.cooldownCustom and WF.db.cooldownCustom.ExtraMonitor then
                    WF.db.cooldownCustom.ExtraMonitor.attachToPlayer = not WF.db.cooldownCustom.ExtraMonitor.attachToPlayer
                    CDMod:MarkLayoutDirty(true)
                elseif r == "ItemBuff" and WF.db.cooldownCustom and WF.db.cooldownCustom.ItemBuff then
                    WF.db.cooldownCustom.ItemBuff.snapToBuffIcon = not WF.db.cooldownCustom.ItemBuff.snapToBuffIcon
                    CDMod:MarkLayoutDirty(true)
                end
            end
        end)
        table.insert(CDMod.Movers, mover)
    end
end

local function LockFramePosition(f, viewer, x, y)
    f._wf_targetP = "BOTTOMLEFT"
    f._wf_targetRef = viewer
    f._wf_targetRP = "BOTTOMLEFT"
    f._wf_targetX = x
    f._wf_targetY = y
    
    if not f._wf_posHooked then
        f._wf_posHooked = true
        hooksecurefunc(f, "SetPoint", function(self)
            if self._wf_isApplyingPos then return end
            self._wf_isApplyingPos = true
            self:ClearAllPoints()
            self:SetPoint(self._wf_targetP, self._wf_targetRef, self._wf_targetRP, self._wf_targetX, self._wf_targetY)
            self._wf_isApplyingPos = false
        end)
    end
    
    f._wf_isApplyingPos = true
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", viewer, "BOTTOMLEFT", x, y)
    f._wf_isApplyingPos = false
end

local function EnforceWishFlexSize(f, w, h)
    if not f then return end
    f._wf_targetW = w; f._wf_targetH = h
    
    local function SmartCrop(icon, tw, th)
        if not icon then return end
        tw = tw or 1; th = th or 1; if tw == 0 then tw = 1 end; if th == 0 then th = 1 end
        local zoom = 0.08
        if math.abs(tw - th) < 0.1 then 
            icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
            return 
        end
        local ratio = tw / th
        if ratio > 1 then 
            local crop = (1 - (1 / ratio)) / 2
            local actualCrop = zoom + crop * (1 - 2*zoom)
            icon:SetTexCoord(zoom, 1 - zoom, actualCrop, 1 - actualCrop)
        else 
            local crop = (1 - ratio) / 2
            local actualCrop = zoom + crop * (1 - 2*zoom)
            icon:SetTexCoord(actualCrop, 1 - actualCrop, zoom, 1 - zoom) 
        end
    end

    if not f._wf_sizeHooked then
        f._wf_sizeHooked = true
        hooksecurefunc(f, "SetSize", function(self, nw, nh)
            if self._wf_isApplyingSize then return end
            if math.abs((nw or 0) - self._wf_targetW) > 0.1 or math.abs((nh or 0) - self._wf_targetH) > 0.1 then
                self._wf_isApplyingSize = true; self:SetSize(self._wf_targetW, self._wf_targetH); self._wf_isApplyingSize = false
                if self.isExtraMonitor and self.icon then 
                    self.icon:SetAllPoints(self)
                    SmartCrop(self.icon, self._wf_targetW, self._wf_targetH)
                end
            end
        end)
        hooksecurefunc(f, "SetWidth", function(self, nw)
            if self._wf_isApplyingSize then return end
            if math.abs((nw or 0) - self._wf_targetW) > 0.1 then
                self._wf_isApplyingSize = true; self:SetWidth(self._wf_targetW); self._wf_isApplyingSize = false
            end
        end)
        hooksecurefunc(f, "SetHeight", function(self, nh)
            if self._wf_isApplyingSize then return end
            if math.abs((nh or 0) - self._wf_targetH) > 0.1 then
                self._wf_isApplyingSize = true; self:SetHeight(self._wf_targetH); self._wf_isApplyingSize = false
            end
        end)
        hooksecurefunc(f, "SetScale", function(self, scale)
            if self._wf_isApplyingScale then return end
            if math.abs((scale or 1) - 1) > 0.01 then
                self._wf_isApplyingScale = true; self:SetScale(1); self._wf_isApplyingScale = false
            end
        end)
    end
    
    f._wf_isApplyingSize = true; f:SetSize(w, h); f._wf_isApplyingSize = false
    f._wf_isApplyingScale = true; f:SetScale(1); f._wf_isApplyingScale = false
    
    if f.isExtraMonitor and f.icon then
        f.icon:ClearAllPoints()
        f.icon:SetAllPoints(f)
        SmartCrop(f.icon, w, h)
    end
end

local BURST_THROTTLE = 0.033; local WATCHDOG_THROTTLE = 0.25; local BURST_TICKS = 5; local IDLE_DISABLE_SEC = 2.0
local layoutEngine = CreateFrame("Frame"); local engineEnabled = false; local layoutDirty = true
local burstTicksRemaining = 0; local lastActivityTime = 0; local nextUpdateTime = 0; local lastLayoutHash = 0

function CDMod:MarkLayoutDirty(force)
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
    if force then CDMod._forceLayout = true end
    layoutDirty = true; burstTicksRemaining = BURST_THROTTLE; lastActivityTime = GetTime(); nextUpdateTime = 0
    if not engineEnabled then layoutEngine:SetScript("OnUpdate", self.OnUpdateEngine); engineEnabled = true end
end
WF.TriggerCooldownLayout = function() CDMod:MarkLayoutDirty(true) end

local hashViewersList = {}
local function GetLayoutStateHash()
    local hash = 0
    wipe(hashViewersList)
    hashViewersList[1] = _G.UtilityCooldownViewer
    hashViewersList[2] = _G.EssentialCooldownViewer
    hashViewersList[3] = _G.BuffIconCooldownViewer
    hashViewersList[4] = _G.BuffBarCooldownViewer
    hashViewersList[5] = _G.WishFlex_ExtraMonitorCooldownViewer
    hashViewersList[6] = _G.WishFlex_ItemBuffCooldownViewer 
    
    local vCount = 6
    if WF.db.cooldownCustom then
        if WF.db.cooldownCustom.CustomRows then 
            for _, r in ipairs(WF.db.cooldownCustom.CustomRows) do 
                local cv = _G["WishFlex_CooldownViewer_"..r]
                if cv then vCount = vCount + 1; hashViewersList[vCount] = cv end 
            end 
        end
        if WF.db.cooldownCustom.CustomBuffRows then 
            for _, r in ipairs(WF.db.cooldownCustom.CustomBuffRows) do 
                local cv = _G["WishFlex_CooldownViewer_"..r]
                if cv then vCount = vCount + 1; hashViewersList[vCount] = cv end 
            end 
        end
    end
    
    for i = 1, vCount do 
        local viewer = hashViewersList[i]
        if viewer and viewer.itemFramePool then 
            local c = 0
            for f in viewer.itemFramePool:EnumerateActive() do 
                if f:IsShown() then 
                    local info = f.cooldownInfo or (f.GetCooldownInfo and f:GetCooldownInfo())
                    local sid = info and (info.overrideSpellID or info.spellID)
                    local sidNum = tonumber(sid) or 0
                    
                    if sidNum > 0 then
                        local idx = tonumber(f.layoutIndex) or 0
                        local hidden = f._wishFlexHidden and 1 or 0
                        hash = (hash * 31 + sidNum) % 2147483647; hash = (hash * 17 + idx) % 2147483647; hash = hash + hidden; c = c + 1 
                    end
                end 
            end
            hash = (hash * 13 + c) % 2147483647
        end 
    end

    if WF.ExtraMonitorAPI then
        local c = 0
        if WF.ExtraMonitorAPI.FramePool then
            for _, f in pairs(WF.ExtraMonitorAPI.FramePool) do
                if f:IsShown() and f.isExtraMonitor then
                    local sid = tonumber(f.id) or 0
                    local idx = tonumber(f.sortIndex) or 0
                    local hidden = f._wishFlexHidden and 1 or 0
                    hash = (hash * 31 + sid) % 2147483647; hash = (hash * 17 + idx) % 2147483647; hash = hash + hidden; c = c + 1 
                end
            end
        end
        if WF.ExtraMonitorAPI.ItemBuffPool then
            for _, f in pairs(WF.ExtraMonitorAPI.ItemBuffPool) do
                if f.isBuffActive then
                    local sid = tonumber(f.id) or 999999
                    hash = (hash * 31 + sid) % 2147483647; c = c + 1 
                end
            end
        end
        hash = (hash * 13 + c) % 2147483647
    end

    return hash
end

function CDMod.OnUpdateEngine()
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then 
        layoutEngine:SetScript("OnUpdate", nil); engineEnabled = false; return 
    end 
    local now = GetTime(); local throttle = (layoutDirty or burstTicksRemaining > 0) and BURST_THROTTLE or WATCHDOG_THROTTLE
    if now < nextUpdateTime then return end; nextUpdateTime = now + throttle
    if layoutDirty or burstTicksRemaining > 0 then
        CDMod:BuildHiddenCache(); local currentHash = GetLayoutStateHash()
        
        if currentHash ~= lastLayoutHash or CDMod._forceLayout then 
            lastLayoutHash = currentHash; CDMod:UpdateAllLayouts(); CDMod:ForceBuffsLayout(); CDMod._forceLayout = false
        end
        
        if burstTicksRemaining > 0 then burstTicksRemaining = burstTicksRemaining - 1 elseif (now - lastActivityTime) >= IDLE_DISABLE_SEC then layoutEngine:SetScript("OnUpdate", nil); engineEnabled = false end
        layoutDirty = false; lastActivityTime = now
    end
end

local function IsSafeValue(val) return val ~= nil and (type(issecretvalue) ~= "function" or not issecretvalue(val)) end

function CDMod.GetBaseSpellFast(spellID) 
    if not IsSafeValue(spellID) then return nil end
    if BaseSpellCache[spellID] == nil then 
        local base = spellID
        local success, res = pcall(function() return C_Spell and C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(spellID) end)
        if success and res then base = res end
        
        if base == spellID then
            local sInfo = nil
            pcall(function() sInfo = C_Spell.GetSpellInfo(spellID) end)
            if not sInfo or not sInfo.name then return base end
        end
        
        BaseSpellCache[spellID] = base 
    end
    return BaseSpellCache[spellID] 
end

function CDMod.ResolveActualSpellID(info, isAura)
    if not info then return nil end; if type(info) ~= "table" then return tonumber(info) end
    if isAura and info.linkedSpellIDs and info.linkedSpellIDs[1] then return info.linkedSpellIDs[1] end
    return info.overrideSpellID or info.spellID
end

function CDMod.GetOverrideData(info, dbO, isAura, keyName)
    if not dbO or not next(dbO) or type(info) ~= "table" then return nil end
    local prefix = isAura and "BUFF_" or "CD_"
    
    local function CheckID(checkID)
        if not checkID then return nil end
        local k1 = prefix .. tostring(checkID)
        local k2 = tostring(checkID)
        if dbO[k1] and dbO[k1][keyName] ~= nil then return dbO[k1][keyName] end
        if dbO[k2] and dbO[k2][keyName] ~= nil then return dbO[k2][keyName] end
        return nil
    end
    
    local sid = CDMod.ResolveActualSpellID(info, isAura)
    local res = CheckID(sid)
    if res ~= nil then return res end
    
    res = CheckID(info.overrideSpellID)
    if res ~= nil then return res end
    
    res = CheckID(info.spellID)
    if res ~= nil then return res end
    
    if info.linkedSpellIDs then
        for _, lid in ipairs(info.linkedSpellIDs) do
            res = CheckID(lid)
            if res ~= nil then return res end
        end
    end
    
    local baseID = CDMod.GetBaseSpellFast(sid)
    res = CheckID(baseID)
    if res ~= nil then return res end
    
    return nil
end

function CDMod.ApplySpellOverrides(frame)
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end
    if not frame then return end
    local info = frame.cooldownInfo or (frame.GetCooldownInfo and frame:GetCooldownInfo())
    if not info and frame.isExtraMonitor then info = {spellID = frame.dbKey or frame.spellID or frame.id} end
    local isAura = frame.wishFlexCategory and (frame.wishFlexCategory == "BuffIcon" or frame.wishFlexCategory == "BuffBar" or string.sub(frame.wishFlexCategory, 1, 13) == "CustomBuffRow")
    
    local dbO = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides
    local customIcon = CDMod.GetOverrideData(info, dbO, isAura, "customIcon")
    
    local iconObj = frame.Icon and (frame.Icon.Icon or frame.Icon)
    if customIcon and customIcon ~= "" and iconObj and iconObj.SetTexture then 
        iconObj:SetTexture(tonumber(customIcon) or customIcon) 
    end
end

CDMod.hiddenCacheBuilt = false
function CDMod:InvalidateHiddenCache() self.hiddenCacheBuilt = false end

function CDMod:BuildHiddenCache()
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
    if self.hiddenCacheBuilt then return end
    self.hiddenCacheBuilt = true
    
    wipe(self.hiddenCDs); wipe(self.hiddenBuffs)

    if WF.db and WF.db.wishMonitor then
        if WF.db.wishMonitor.skills then
            for idStr, cfg in pairs(WF.db.wishMonitor.skills) do
                if cfg.enable and cfg.hideOriginal then
                    local idNum = tonumber(idStr) or tonumber(string.match(tostring(idStr), "^(%d+)"))
                    if idNum then self.hiddenCDs[idNum] = true end
                end
            end
        end
        if WF.db.wishMonitor.buffs then
            for idStr, cfg in pairs(WF.db.wishMonitor.buffs) do
                if cfg.enable and cfg.hideOriginal then
                    local idNum = tonumber(idStr) or tonumber(string.match(tostring(idStr), "^(%d+)"))
                    if idNum then self.hiddenBuffs[idNum] = true end
                end
            end
        end
    end

    if WF.db and WF.db.auraGlow and WF.db.auraGlow.spells then
        for idStr, cfg in pairs(WF.db.auraGlow.spells) do
            if cfg.hideOriginal then
                local bID = tonumber(cfg.buffID) or tonumber(string.match(tostring(idStr), "^(%d+)"))
                if bID then self.hiddenBuffs[bID] = true end
            end
        end
    end

    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.blacklist then 
        for key, isHidden in pairs(WF.db.cooldownCustom.blacklist) do 
            if isHidden then 
                if type(key) == "string" and string.match(key, "^CD_") then
                    local idNum = tonumber(string.sub(key, 4))
                    if idNum then self.hiddenCDs[idNum] = true end
                elseif type(key) == "string" and string.match(key, "^BUFF_") then
                    local idNum = tonumber(string.sub(key, 6))
                    if idNum then self.hiddenBuffs[idNum] = true end
                else
                    local idNum = tonumber(key) or tonumber(string.match(tostring(key), "^(%d+)"))
                    if idNum then self.hiddenCDs[idNum] = true; self.hiddenBuffs[idNum] = true end
                end
            end 
        end 
    end

    if WF.ExtraMonitorAPI and WF.db.extraMonitor and WF.db.extraMonitor.enable and WF.db.extraMonitor.autoRacial then
        if WF.ExtraMonitorAPI.ActiveTrackers then
            local dbO = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides or {}
            for _, data in ipairs(WF.ExtraMonitorAPI.ActiveTrackers) do
                if data.type == "spell" and data.isRacial and data.id then
                    local info = {spellID = data.id}
                    local hasCustomOverride = CDMod.GetOverrideData(info, dbO, false, "category")
                    if not hasCustomOverride then self.hiddenCDs[data.id] = true end
                end
            end
        end
    end
end

function CDMod.ShouldHideCD(info)
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return false end
    local dbO = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides
    
    if CDMod.GetOverrideData(info, dbO, false, "hide") then return true end

    local sid = CDMod.ResolveActualSpellID(info, false); 
    if not sid and info and info.isExtraMonitor then sid = info.id end
    if not sid then return false end

    if CDMod.hiddenCDs[sid] then return true end
    local baseID = CDMod.GetBaseSpellFast(sid); if baseID and CDMod.hiddenCDs[baseID] then return true end 
    return false
end

function CDMod.ShouldHideBuff(info)
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return false end
    local dbO = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides
    
    if CDMod.GetOverrideData(info, dbO, true, "hide") then return true end

    local sid = CDMod.ResolveActualSpellID(info, true); if not sid then return false end
    if CDMod.hiddenBuffs[sid] then return true end
    local baseID = CDMod.GetBaseSpellFast(sid); if baseID and CDMod.hiddenBuffs[baseID] then return true end 
    return false
end

function CDMod.PhysicalHideFrame(frame) 
    if not frame then return end
    frame:SetAlpha(0)
    if frame.Icon and frame.Icon.SetAlpha then frame.Icon:SetAlpha(0) end
    frame:EnableMouse(false)

    if frame._wf_posHooked then
        frame._wf_targetP = "CENTER"
        frame._wf_targetRef = UIParent
        frame._wf_targetRP = "CENTER"
        frame._wf_targetX = -5000
        frame._wf_targetY = 0
        frame._wf_isApplyingPos = true
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", -5000, 0)
        frame._wf_isApplyingPos = false
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", -5000, 0)
    end
    
    frame._wishFlexHidden = true 
end

local globalGlowHooked = false
local function HideNativeGlow(frame) if not frame then return end; local alert = frame.SpellActivationAlert; if alert then alert:SetAlpha(0); alert:Hide() end end

local function SetupGlobalGlowHooks()
    if globalGlowHooked then return end
    local alertManager = _G.ActionButtonSpellAlertManager; if not alertManager then return end
    hooksecurefunc(alertManager, "ShowAlert", function(_, frame) 
        if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
        if frame and frame.cooldownInfo then HideNativeGlow(frame); if WF.GlowAPI then WF.GlowAPI:Show(frame) end end 
    end)
    hooksecurefunc(alertManager, "HideAlert", function(_, frame) 
        if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
        if frame and frame.cooldownInfo then HideNativeGlow(frame); if WF.GlowAPI then WF.GlowAPI:Hide(frame) end end 
    end)
    globalGlowHooked = true
end

function CDMod.SetupFrameGlow(frame)
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
    if not frame then return end; HideNativeGlow(frame)
    if frame.SpellActivationAlert and frame.SpellActivationAlert:IsShown() then HideNativeGlow(frame); if WF.GlowAPI then WF.GlowAPI:Show(frame) end end
end

local function GetSortVal(f)
    local info = f.cooldownInfo or (f.GetCooldownInfo and f:GetCooldownInfo())
    if not info and f.isExtraMonitor then info = {spellID = f.dbKey or f.spellID or f.id} end
    local isAura = f.wishFlexCategory and (f.wishFlexCategory == "BuffIcon" or f.wishFlexCategory == "BuffBar" or string.sub(f.wishFlexCategory, 1, 13) == "CustomBuffRow")
    
    local dbO = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides
    local sortOverride = CDMod.GetOverrideData(info, dbO, isAura, "sortIndex")
    if sortOverride then return sortOverride end
    
    return f.layoutIndex or f.sortIndex or 999
end

local function SortByLayoutIndex(a, b) 
    local vA = GetSortVal(a)
    local vB = GetSortVal(b)
    if vA == vB then
        local idA = a.isExtraMonitor and (a.spellID or a.id) or (a.cooldownInfo and (a.cooldownInfo.overrideSpellID or a.cooldownInfo.spellID)) or 0
        local idB = b.isExtraMonitor and (b.spellID or b.id) or (b.cooldownInfo and (b.cooldownInfo.overrideSpellID or b.cooldownInfo.spellID)) or 0
        local numA, numB = tonumber(idA) or 0, tonumber(idB) or 0
        if numA == numB then return tostring(idA) < tostring(idB) end
        return numA < numB
    end
    return vA < vB 
end

local function LayoutGenericGroup(viewer, framesList, catName, isBuffGroup)
    if not viewer then return end
    local db = WF.db.cooldownCustom; local cfg = db[catName]; local count = #framesList
    local isNativeViewer = (viewer == _G.EssentialCooldownViewer or viewer == _G.UtilityCooldownViewer or viewer == _G.BuffIconCooldownViewer or viewer == _G.BuffBarCooldownViewer)
    local targetAnchor = _G["WishFlex_Anchor_"..catName]
    
    if not viewer._wf_scaleHooked then
        viewer._wf_scaleHooked = true
        hooksecurefunc(viewer, "SetScale", function(self, scale)
            if self._wf_isApplyingScale then return end
            if math.abs((scale or 1) - 1) > 0.01 then
                self._wf_isApplyingScale = true; self:SetScale(1); self._wf_isApplyingScale = false
            end
        end)
    end
    viewer._wf_isApplyingScale = true; viewer:SetScale(1); viewer._wf_isApplyingScale = false

    if targetAnchor and not isNativeViewer then WeldToMover(viewer, targetAnchor) end
    
    if count > 0 then
        table.sort(framesList, SortByLayoutIndex)
        for i = 1, count do 
            local f = framesList[i]
            if not f.isExtraMonitor and CDMod.ImmediateStyleFrame then 
                CDMod:ImmediateStyleFrame(f, catName) 
            elseif f.isExtraMonitor then
                if f.Count and cfg.stackPosition then
                    f.Count:ClearAllPoints()
                    f.Count:SetPoint(cfg.stackPosition, f, cfg.stackPosition, cfg.stackXOffset or 0, cfg.stackYOffset or 0)
                end
            end
            
            f._wf_isApplyingPos = true
            if f:GetParent() ~= viewer then f:SetParent(viewer) end 
            f._wf_isApplyingPos = false
        end
        
        local maxPerRow = tonumber(cfg.maxPerRow) or 999; if maxPerRow <= 0 then maxPerRow = 999 end
        local cols = math.min(count, maxPerRow); local rows = math.ceil(count / maxPerRow)
        
        local w = CDMod.PixelSnap(cfg.width or 45); local h = CDMod.PixelSnap(cfg.height or 45); local gap = CDMod.PixelSnap(cfg.iconGap or 2)
        local barH = CDMod.PixelSnap(cfg.barHeight or h); local itemH = math.max(h, barH)
        local isVertical = (catName == "BuffBar") or (cfg.growth == "UP") or (cfg.growth == "DOWN")
        
        local totalW, totalH
        if isVertical then totalW = (rows * w) + math.max(0, (rows - 1) * gap); totalH = (cols * itemH) + math.max(0, (cols - 1) * gap)
        else totalW = (cols * w) + math.max(0, (cols - 1) * gap); totalH = (rows * itemH) + math.max(0, (rows - 1) * gap) end
        
        viewer:SetSize(math.max(1, totalW), math.max(1, totalH))
        
        if targetAnchor and not isNativeViewer then 
            targetAnchor:SetSize(viewer:GetSize())
            local mover = _G[targetAnchor:GetName().."Mover"]; 
            if mover then mover:SetSize(viewer:GetWidth(), viewer:GetHeight()) end 
        end
        
        local growth = cfg.growth or (isVertical and "DOWN" or "CENTER_HORIZONTAL")

        for i = 1, count do
            local f = framesList[i];
            local idx = i - 1; local col = idx % maxPerRow; local row = math.floor(idx / maxPerRow)
            local xPos, yPos = 0, 0
            if isVertical then
                if growth == "UP" then xPos = row * (w + gap); yPos = col * (itemH + gap)
                else xPos = row * (w + gap); yPos = totalH - itemH - (col * (itemH + gap)) end
            else
                if growth == "LEFT" then xPos = totalW - w - (col * (w + gap)); yPos = totalH - itemH - (row * (itemH + gap))
                else xPos = col * (w + gap); yPos = totalH - itemH - (row * (itemH + gap)) end
            end
            
            LockFramePosition(f, viewer, xPos, yPos)
            EnforceWishFlexSize(f, w, math.max(h, barH))
            
            if f._wishFlexHidden then
                f:SetAlpha(1); if f.Icon and f.Icon.SetAlpha then f.Icon:SetAlpha(1) end
                f:EnableMouse(true); f._wishFlexHidden = false
            end
        end
        viewer:Show(); viewer:SetAlpha(1)
    else 
        viewer:SetSize(1, 1); viewer:Show(); viewer:SetAlpha(1)
        if targetAnchor and not isNativeViewer then 
            targetAnchor:SetSize(1, 1); local mover = _G[targetAnchor:GetName().."Mover"]; if mover then mover:SetSize(45, 45) end
        end
    end
end

function CDMod:BroadcastWidth()
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
    local w = 250; local viewerType = "Essential"; local activeViewer = _G.EssentialCooldownViewer
    if not (activeViewer and activeViewer:IsShown() and (activeViewer:GetWidth() or 0) > 5) then activeViewer = _G.UtilityCooldownViewer; viewerType = "Utility" end
    
    if activeViewer and activeViewer.itemFramePool then
        local actualCount = 0
        if WF.CooldownCustomAPI and WF.CooldownCustomAPI.Sandbox and WF.CooldownCustomAPI.Sandbox.RenderedLists then local list = WF.CooldownCustomAPI.Sandbox.RenderedLists[viewerType]; if list then actualCount = #list end end
        if actualCount == 0 then
            for f in activeViewer.itemFramePool:EnumerateActive() do
                if f:IsShown() and not f._wishFlexHidden then 
                    local info = f.cooldownInfo or (f.GetCooldownInfo and f:GetCooldownInfo())
                    local sid = info and (info.overrideSpellID or info.spellID)
                    if sid then actualCount = actualCount + 1 end
                end
            end
            if WF.ExtraMonitorAPI and WF.ExtraMonitorAPI.FramePool then
                for _, f in pairs(WF.ExtraMonitorAPI.FramePool) do
                    if f:IsShown() and f.isExtraMonitor then
                        if not f._emTempInfo then f._emTempInfo = { isExtraMonitor = true } end
                        f._emTempInfo.spellID = f.dbKey or f.spellID or f.id
                        local info = f._emTempInfo
                        
                        local dbO = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides
                        local oCat = CDMod.GetOverrideData(info, dbO, false, "category")
                        local tCat = oCat or "ExtraMonitor"
                        if tCat == viewerType then actualCount = actualCount + 1 end
                    end
                end
            end
        end
        
        if actualCount > 0 then
            local cdDB = WF.db.cooldownCustom and WF.db.cooldownCustom[viewerType]
            local itemW = 45; local gap = 2
            if cdDB then itemW = tonumber(cdDB.width) or 45; gap = tonumber(cdDB.iconGap) or 2; local maxPerRow = tonumber(cdDB.maxPerRow) or 999; if actualCount > maxPerRow then actualCount = maxPerRow end end
            local snapW = CDMod.PixelSnap(itemW); local snapGap = CDMod.PixelSnap(gap)
            local calcW = (actualCount * snapW) + math.max(0, (actualCount - 1) * snapGap); w = CDMod.PixelSnap(calcW)
        end
    end
    if WF.ClassResourceAPI and type(WF.ClassResourceAPI.SetTargetWidth) == "function" then WF.ClassResourceAPI:SetTargetWidth(w) end
end

function CDMod:ApplySavedNativePositions()
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
    if not WF.db.movers then return end
    local db = WF.db.cooldownCustom or {}

    local function applyPos(vName)
        local viewer = _G[vName]
        if viewer and WF.db.movers[vName] then
            local p = WF.db.movers[vName]
            
            local _, relTo, _, cx, cy = viewer:GetPoint()
            cx = cx or 0
            cy = cy or 0
            if relTo ~= UIParent or math.abs(cx - p.xOfs) > 0.5 or math.abs(cy - p.yOfs) > 0.5 then
                viewer._isRestoring = true
                viewer:SetMovable(true)
                viewer:ClearAllPoints()
                viewer:SetPoint(p.point, UIParent, p.relativePoint, p.xOfs, p.yOfs)
                viewer._isRestoring = false
            end
        end
    end

    applyPos("EssentialCooldownViewer")

    if not (db.Utility and db.Utility.snapToEssential) then
        applyPos("UtilityCooldownViewer")
    end

    if not (db.BuffIcon and (db.BuffIcon.snapToEssential or db.BuffIcon.snapToResource)) then
        applyPos("BuffIconCooldownViewer")
    end

    applyPos("BuffBarCooldownViewer")
end

local function HandleAttachment(db, anchorFrameName, dbGroup, defaultY, anchorPointOffset)
    local dAnchor = _G[anchorFrameName]; local dMover = _G[anchorFrameName .. "Mover"]
    if dAnchor then
        dAnchor:ClearAllPoints()
        if dMover then dMover:ClearAllPoints() end
        
        if dbGroup == "ItemBuff" and db.ItemBuff and db.ItemBuff.snapToBuffIcon and _G.BuffIconCooldownViewer then
            dAnchor:SetPoint("BOTTOM", _G.BuffIconCooldownViewer, "TOP", 0, CDMod.PixelSnap(12))
            if dMover then 
                dMover:SetPoint("CENTER", dAnchor, "CENTER", 0, 0)
                if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then dMover:Show() else dMover:Hide() end
            end
            return 
        end
        
        if db[dbGroup] and db[dbGroup].attachToPlayer then
            local anchorFrame = nil
            if _G.ElvUF_Player then anchorFrame = _G.ElvUF_Player.backdrop or _G.ElvUF_Player 
            elseif _G.oUF_Player then anchorFrame = _G.oUF_Player 
            elseif _G.PlayerFrame then anchorFrame = _G.PlayerFrame end
            
            if anchorFrame then 
                if anchorPointOffset == "Defensive" then dAnchor:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, 1) 
                else dAnchor:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -1) end
            else dAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, defaultY) end
            
            if dMover then 
                dMover:SetPoint("CENTER", dAnchor, "CENTER", 0, 0)
                if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then dMover:Show() else dMover:Hide() end
            end
        else
            if dMover then
                if WF.db.movers and WF.db.movers[dMover:GetName()] then 
                    local p = WF.db.movers[dMover:GetName()]
                    dMover:SetPoint(p.point, UIParent, p.relativePoint, p.xOfs, p.yOfs) 
                else dMover:SetPoint("TOP", UIParent, "CENTER", 0, defaultY) end
                dAnchor:SetPoint("CENTER", dMover, "CENTER", 0, 0)
                if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then dMover:Show() else dMover:Hide() end
            else dAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, defaultY) end
        end
    end
end

local cacheCatFramesBuffs = { BuffIcon = {}, BuffBar = {}, ItemBuff = {} }
function CDMod:ForceBuffsLayout() 
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
    local db = WF.db.cooldownCustom
    wipe(cacheCatFramesBuffs.BuffIcon); wipe(cacheCatFramesBuffs.BuffBar); wipe(cacheCatFramesBuffs.ItemBuff)
    local catFrames = cacheCatFramesBuffs
    if db.CustomBuffRows then for _, r in ipairs(db.CustomBuffRows) do if not catFrames[r] then catFrames[r] = {} else wipe(catFrames[r]) end end end

    local function GatherBuffs(viewer, defCat)
        if not viewer or not viewer.itemFramePool then return end
        for f in viewer.itemFramePool:EnumerateActive() do
            if f:IsShown() then
                local info = f.cooldownInfo or (f.GetCooldownInfo and f:GetCooldownInfo())
                local sid = CDMod.ResolveActualSpellID(info, true)
                
                if not sid then CDMod.PhysicalHideFrame(f) else
                    local tCat = defCat; 
                    local dbO = db.spellOverrides; 
                    local oCat = CDMod.GetOverrideData(info, dbO, true, "category")
                    
                    if oCat then
                        local isCDCat = (oCat == "Essential" or oCat == "Utility" or oCat == "Defensive" or oCat == "ExtraMonitor" or oCat == "ItemBuff")
                        if db.CustomRows then for _, r in ipairs(db.CustomRows) do if oCat == r then isCDCat = true; break end end end
                        if not isCDCat then
                            if oCat == "BuffIcon" or oCat == "BuffBar" then tCat = oCat end
                            if db.CustomBuffRows then for _, r in ipairs(db.CustomBuffRows) do if oCat == r then tCat = oCat end end end
                        end
                    end
                    if CDMod.ShouldHideBuff(info) then CDMod.PhysicalHideFrame(f) else if not catFrames[tCat] then catFrames[tCat] = {} end; table.insert(catFrames[tCat], f) end
                end
            end
        end
    end
    
    GatherBuffs(_G.BuffIconCooldownViewer, "BuffIcon"); GatherBuffs(_G.BuffBarCooldownViewer, "BuffBar")
    if db.CustomBuffRows then for _, r in ipairs(db.CustomBuffRows) do local cv = _G["WishFlex_CooldownViewer_"..r]; if cv then GatherBuffs(cv, r) end end end

    if WF.ExtraMonitorAPI and WF.ExtraMonitorAPI.FramePool then
        for _, f in pairs(WF.ExtraMonitorAPI.FramePool) do
            if f:IsShown() and f.isExtraMonitor then
                if not f._emTempInfo then f._emTempInfo = { isExtraMonitor = true } end
                f._emTempInfo.spellID = f.dbKey or f.spellID or f.id
                local info = f._emTempInfo
                
                local dbO = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides
                local oCat = CDMod.GetOverrideData(info, dbO, false, "category")
                if oCat then
                    local isBuffCat = (oCat == "BuffIcon" or oCat == "BuffBar" or oCat == "ItemBuff")
                    if db.CustomBuffRows then for _, r in ipairs(db.CustomBuffRows) do if oCat == r then isBuffCat = true; break end end end
                    if isBuffCat and catFrames[oCat] then table.insert(catFrames[oCat], f) end
                end
            end
        end
    end

    if WF.ExtraMonitorAPI and WF.ExtraMonitorAPI.ItemBuffPool then
        for _, f in pairs(WF.ExtraMonitorAPI.ItemBuffPool) do
            if f.isBuffActive then
                table.insert(catFrames.ItemBuff, f)
            end
        end
    end

    LayoutGenericGroup(_G.BuffIconCooldownViewer, catFrames.BuffIcon, "BuffIcon", true)
    LayoutGenericGroup(_G.BuffBarCooldownViewer, catFrames.BuffBar, "BuffBar", true)
    
    EnsureMoverExists("ItemBuff", true, false)
    if not _G.WishFlex_ItemBuffCooldownViewer then 
        local cv = CreateFrame("Frame", "WishFlex_ItemBuffCooldownViewer", UIParent); 
        cv:SetFrameStrata("HIGH"); cv:SetFrameLevel(50); 
        _G.WishFlex_ItemBuffCooldownViewer = cv 
    end
    LayoutGenericGroup(_G.WishFlex_ItemBuffCooldownViewer, catFrames.ItemBuff, "ItemBuff", true)

    if db.CustomBuffRows then
        for _, r in ipairs(db.CustomBuffRows) do
            EnsureMoverExists(r, true, false)
            if not _G["WishFlex_CooldownViewer_"..r] then local cv = CreateFrame("Frame", "WishFlex_CooldownViewer_"..r, UIParent); cv:SetFrameStrata("HIGH"); cv:SetFrameLevel(50); _G["WishFlex_CooldownViewer_"..r] = cv end
            LayoutGenericGroup(_G["WishFlex_CooldownViewer_"..r], catFrames[r] or {}, r, true)
        end
    end

    if db.CustomRows then
        for _, r in ipairs(db.CustomRows) do
            if catFrames[r] and #catFrames[r] > 0 then
                EnsureMoverExists(r, false, false)
                if not _G["WishFlex_CooldownViewer_"..r] then local cv = CreateFrame("Frame", "WishFlex_CooldownViewer_"..r, UIParent); cv:SetFrameStrata("HIGH"); cv:SetFrameLevel(50); _G["WishFlex_CooldownViewer_"..r] = cv end
                LayoutGenericGroup(_G["WishFlex_CooldownViewer_"..r], catFrames[r], r, true)
            end
        end
    end

    local buffIconViewer = _G.BuffIconCooldownViewer
    if db.BuffIcon.snapToResource and buffIconViewer then
        local anchorTarget = _G.EssentialCooldownViewer
        local yOffset = 45
        if WF.ClassResourceAPI and WF.ClassResourceAPI.GetTopStackedFrame then
            local topCR = WF.ClassResourceAPI:GetTopStackedFrame()
            if topCR then anchorTarget = topCR; yOffset = 10 end
        end
        if anchorTarget then buffIconViewer:ClearAllPoints(); buffIconViewer:SetPoint("BOTTOM", anchorTarget, "TOP", 0, CDMod.PixelSnap(yOffset)) end
    elseif db.BuffIcon.snapToEssential and _G.EssentialCooldownViewer and buffIconViewer then
        buffIconViewer:ClearAllPoints(); buffIconViewer:SetPoint("BOTTOM", _G.EssentialCooldownViewer, "TOP", 0, CDMod.PixelSnap(45))
    end

    if db.CustomBuffRows then
        for _, r in ipairs(db.CustomBuffRows) do
            local cAnchor = _G["WishFlex_Anchor_"..r]; local cMover = _G["WishFlex_Anchor_"..r.."Mover"]
            if cAnchor then
                cAnchor:ClearAllPoints()
                if cMover then
                    cAnchor:SetPoint("CENTER", cMover, "CENTER", 0, 0)
                    if WF.db.movers and WF.db.movers[cMover:GetName()] then local p = WF.db.movers[cMover:GetName()]; cMover:ClearAllPoints(); cMover:SetPoint(p.point, UIParent, p.relativePoint, p.xOfs, p.yOfs) end
                else cAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
                if cMover then if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then cMover:Show() end end
            end
        end
    end
    
    CDMod:ApplySavedNativePositions()
end

local cacheCatFramesCD = { Essential = {}, Utility = {}, Defensive = {}, ExtraMonitor = {} }
function CDMod:UpdateAllLayouts()
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
    local db = WF.db.cooldownCustom
    wipe(cacheCatFramesCD.Essential); wipe(cacheCatFramesCD.Utility); wipe(cacheCatFramesCD.Defensive); wipe(cacheCatFramesCD.ExtraMonitor)
    local catFrames = cacheCatFramesCD
    if db.CustomRows then for _, r in ipairs(db.CustomRows) do if not catFrames[r] then catFrames[r] = {} else wipe(catFrames[r]) end end end
    
    local function GatherFrames(viewer, defCat)
        if not viewer or not viewer.itemFramePool then return end
        for f in viewer.itemFramePool:EnumerateActive() do 
            if f:IsShown() then 
                local info = f.cooldownInfo or (f.GetCooldownInfo and f:GetCooldownInfo())
                local sid = CDMod.ResolveActualSpellID(info, false)
                
                if not sid then CDMod.PhysicalHideFrame(f) else
                    local tCat = defCat; 
                    local dbO = db.spellOverrides; 
                    local oCat = CDMod.GetOverrideData(info, dbO, false, "category")

                    if oCat then
                        local isBuffCat = (oCat == "BuffIcon" or oCat == "BuffBar" or oCat == "ItemBuff")
                        if db.CustomBuffRows then for _, r in ipairs(db.CustomBuffRows) do if oCat == r then isBuffCat = true; break end end end
                        if not isBuffCat then
                            if oCat == "Essential" or oCat == "Utility" or oCat == "Defensive" or oCat == "ExtraMonitor" then tCat = oCat end
                            if db.CustomRows then for _, r in ipairs(db.CustomRows) do if oCat == r then tCat = oCat end end end
                        end
                    else
                        local baseID = CDMod.GetBaseSpellFast(sid)
                        local isDefensive = WF.DefensiveSpells and (WF.DefensiveSpells[sid] or (baseID and WF.DefensiveSpells[baseID]))
                        if (defCat == "Essential" or defCat == "Utility") and isDefensive then tCat = "Defensive" end
                    end
                    
                    if CDMod.ShouldHideCD(info) then CDMod.PhysicalHideFrame(f) else if not catFrames[tCat] then catFrames[tCat] = {} end; table.insert(catFrames[tCat], f) end
                end
            end 
        end
    end
    
    GatherFrames(_G.UtilityCooldownViewer, "Utility"); GatherFrames(_G.EssentialCooldownViewer, "Essential")
    if db.CustomRows then for _, r in ipairs(db.CustomRows) do local cv = _G["WishFlex_CooldownViewer_"..r]; if cv then GatherFrames(cv, r) end end end

    if WF.ExtraMonitorAPI and WF.ExtraMonitorAPI.FramePool then
        for _, f in pairs(WF.ExtraMonitorAPI.FramePool) do
            if f:IsShown() and f.isExtraMonitor then
                if not f._emTempInfo then f._emTempInfo = { isExtraMonitor = true } end
                f._emTempInfo.spellID = f.dbKey or f.spellID or f.id
                local info = f._emTempInfo
                
                local tCat = "ExtraMonitor" 
                local dbO = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides
                local oCat = CDMod.GetOverrideData(info, dbO, false, "category")
                
                if oCat then
                    local isBuffCat = (oCat == "BuffIcon" or oCat == "BuffBar" or oCat == "ItemBuff")
                    if db.CustomBuffRows then for _, r in ipairs(db.CustomBuffRows) do if oCat == r then isBuffCat = true; break end end end
                    if not isBuffCat then tCat = oCat end
                end
                if catFrames[tCat] then table.insert(catFrames[tCat], f) end
            end
        end
    end

    LayoutGenericGroup(_G.EssentialCooldownViewer, catFrames.Essential, "Essential", false)
    LayoutGenericGroup(_G.UtilityCooldownViewer, catFrames.Utility, "Utility", false)
    
    EnsureMoverExists("Defensive", false, true)
    if not WF.DefensiveCooldownViewer then WF.DefensiveCooldownViewer = CreateFrame("Frame", "WishFlex_DefensiveCooldownViewer", UIParent); WF.DefensiveCooldownViewer:SetFrameStrata("HIGH"); WF.DefensiveCooldownViewer:SetFrameLevel(50) end
    LayoutGenericGroup(WF.DefensiveCooldownViewer, catFrames.Defensive, "Defensive", false)

    EnsureMoverExists("ExtraMonitor", false, false)
    if not WF.ExtraMonitorCooldownViewer then WF.ExtraMonitorCooldownViewer = CreateFrame("Frame", "WishFlex_ExtraMonitorCooldownViewer", UIParent); WF.ExtraMonitorCooldownViewer:SetFrameStrata("HIGH"); WF.ExtraMonitorCooldownViewer:SetFrameLevel(50) end
    LayoutGenericGroup(WF.ExtraMonitorCooldownViewer, catFrames.ExtraMonitor, "ExtraMonitor", false)

    if db.CustomRows then
        for _, r in ipairs(db.CustomRows) do
            EnsureMoverExists(r, false, false)
            if not _G["WishFlex_CooldownViewer_"..r] then local cv = CreateFrame("Frame", "WishFlex_CooldownViewer_"..r, UIParent); cv:SetFrameStrata("HIGH"); cv:SetFrameLevel(50); _G["WishFlex_CooldownViewer_"..r] = cv end
            LayoutGenericGroup(_G["WishFlex_CooldownViewer_"..r], catFrames[r] or {}, r, false)
        end
    end

    if db.CustomBuffRows then
        for _, r in ipairs(db.CustomBuffRows) do
            if catFrames[r] and #catFrames[r] > 0 then
                EnsureMoverExists(r, true, false)
                if not _G["WishFlex_CooldownViewer_"..r] then local cv = CreateFrame("Frame", "WishFlex_CooldownViewer_"..r, UIParent); cv:SetFrameStrata("HIGH"); cv:SetFrameLevel(50); _G["WishFlex_CooldownViewer_"..r] = cv end
                LayoutGenericGroup(_G["WishFlex_CooldownViewer_"..r], catFrames[r], r, false)
            end
        end
    end

    local utilityViewer = _G.UtilityCooldownViewer
    if db.Utility.snapToEssential and _G.EssentialCooldownViewer and utilityViewer then utilityViewer:ClearAllPoints(); utilityViewer:SetPoint("TOP", _G.EssentialCooldownViewer, "BOTTOM", 0, -CDMod.PixelSnap(1)) end

    HandleAttachment(db, "WishFlex_Anchor_Defensive", "Defensive", -180, "Defensive")
    HandleAttachment(db, "WishFlex_Anchor_ExtraMonitor", "ExtraMonitor", -250, "ExtraMonitor")
    HandleAttachment(db, "WishFlex_Anchor_ItemBuff", "ItemBuff", -100, "ItemBuff")

    if db.CustomRows then
        for _, r in ipairs(db.CustomRows) do
            local cAnchor = _G["WishFlex_Anchor_"..r]; local cMover = _G["WishFlex_Anchor_"..r.."Mover"]
            if cAnchor then
                cAnchor:ClearAllPoints()
                if cMover then
                    cAnchor:SetPoint("CENTER", cMover, "CENTER", 0, 0)
                    if WF.db.movers and WF.db.movers[cMover:GetName()] then local p = WF.db.movers[cMover:GetName()]; cMover:ClearAllPoints(); cMover:SetPoint(p.point, UIParent, p.relativePoint, p.xOfs, p.yOfs) end
                    if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then cMover:Show() end
                else cAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
            end
        end
    end

    CDMod:ApplySavedNativePositions()
    self:BroadcastWidth()
end

local function BreakSnapOnDrag(systemName, dbKey)
    local system = _G[systemName]; if not system then return end
    if system.HookScript then system:HookScript("OnDragStop", function() 
        local db = WF.db.cooldownCustom and WF.db.cooldownCustom[dbKey]; 
        if db and (db.snapToEssential or db.snapToResource or db.snapToBuffIcon) then 
            db.snapToEssential = false; db.snapToResource = false; db.snapToBuffIcon = false
            if WF.UI and WF.UI.RefreshCurrentPanel then pcall(function() WF.UI:RefreshCurrentPanel() end) end 
        end 
    end) end
end

local function InitCooldownCustom()
    if not WF.db.cooldownCustom then WF.db.cooldownCustom = {} end
    MigrateOldSettings(WF.db.cooldownCustom) 
    for k, v in pairs(DefaultConfig) do if WF.db.cooldownCustom[k] == nil then WF.db.cooldownCustom[k] = v end end
    for _, k in ipairs({"Essential", "Utility", "Defensive", "ExtraMonitor", "BuffBar", "BuffIcon", "ItemBuff"}) do for subK, subV in pairs(DefaultConfig[k]) do if WF.db.cooldownCustom[k][subK] == nil then WF.db.cooldownCustom[k][subK] = subV end end end
    
    if WF.db.cooldownCustom.enable == false then return end

    if not WF.db.movers then WF.db.movers = {} end
    
    if WF.ExtraMonitorAPI and WF.ExtraMonitorAPI.UpdateDisplay and not CDMod._emMasterHooked then
        CDMod._emMasterHooked = true
        local origUpdate = WF.ExtraMonitorAPI.UpdateDisplay
        WF.ExtraMonitorAPI.UpdateDisplay = function(self)
            origUpdate(self)
            CDMod:MarkLayoutDirty(false)
        end
    end

    CDMod.hiddenCacheBuilt = false
    CDMod:SyncSpecGroups()
    SetupGlobalGlowHooks()
    EnsureMoverExists("Defensive", false, true)
    EnsureMoverExists("ExtraMonitor", false, false)
    EnsureMoverExists("ItemBuff", true, false)

    if WF.db.cooldownCustom.CustomRows then for _, r in ipairs(WF.db.cooldownCustom.CustomRows) do EnsureMoverExists(r, false, false) end end
    if WF.db.cooldownCustom.CustomBuffRows then for _, r in ipairs(WF.db.cooldownCustom.CustomBuffRows) do EnsureMoverExists(r, true, false) end end
    
    BreakSnapOnDrag("UtilityCooldownViewer", "Utility"); BreakSnapOnDrag("BuffIconCooldownViewer", "BuffIcon")
    
    if EditModeManagerFrame and not CDMod._editModeHooked then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() for _, mover in ipairs(CDMod.Movers) do if mover.Show then mover:Show() end end end)
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            for _, mover in ipairs(CDMod.Movers) do if mover.Hide then mover:Hide() end end
            CDMod:UpdateAllLayouts(); CDMod:ForceBuffsLayout()
        end)
        CDMod._editModeHooked = true
    end

    local nativeSystems = {
        "EssentialCooldownViewer",
        "UtilityCooldownViewer",
        "BuffIconCooldownViewer",
        "BuffBarCooldownViewer"
    }
    for _, vName in ipairs(nativeSystems) do
        local viewer = _G[vName]
        if viewer then
            hooksecurefunc(viewer, "SetPoint", function(self)
                if not self._isRestoring and EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then
                    local cx, cy = self:GetCenter()
                    if cx and cy then
                        local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
                        if not WF.db.movers then WF.db.movers = {} end
                        local saveKey = self:GetName()
                        if not WF.db.movers[saveKey] then WF.db.movers[saveKey] = {} end
                        local m = WF.db.movers[saveKey]
                        m.point = "CENTER"
                        m.relativePoint = "CENTER"
                        m.xOfs = cx - pw/2
                        m.yOfs = cy - ph/2
                    end
                end
            end)
            
            if viewer.UpdateLayout then
                hooksecurefunc(viewer, "UpdateLayout", function()
                    CDMod:MarkLayoutDirty(false)
                end)
            end
        end
    end

    WF:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
        if WF.db.cooldownCustom.enable == false then return end 
        CDMod:SyncSpecGroups()
        CDMod:MarkLayoutDirty(true)
    end)
    
    WF:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if WF.db.cooldownCustom.enable == false then return end 
        C_Timer.After(1.0, function() CDMod:MarkLayoutDirty(true) end)
    end)

    WF:RegisterEvent("SPELLS_CHANGED", function()
        if WF.db.cooldownCustom.enable == false then return end 
        CDMod:MarkLayoutDirty(true)
    end)
    
    WF:RegisterEvent("UNIT_PET", function(unit)
        if unit == "player" and WF.db.cooldownCustom.enable ~= false then 
            C_Timer.After(0.5, function() CDMod:MarkLayoutDirty(true) end)
        end
    end)
    
    CDMod:MarkLayoutDirty(true)
end

WF:RegisterModule("cooldownCustom", L["Cooldown Custom"] or "冷却管理器", InitCooldownCustom)