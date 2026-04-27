local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}

local ExtraMonitor = CreateFrame("Frame", "WishFlex_ExtraMonitor", UIParent)
ExtraMonitor:Hide() 
WF.ExtraMonitorAPI = ExtraMonitor

local defaults = {
    enable = true,
    attachToPlayer = true, 
    iconWidth = 30,
    iconHeight = 25,
    iconGap = 1,
    maxPerRow = 6,
    autoTrinkets = true,
    autoRacial = true,
    zeroCountBehavior = "hide",
    stackPosition = "BOTTOM",
    stackXOffset = 0,
    stackYOffset = -6,
    cdPosition = "CENTER",
    cdXOffset = 0,
    cdYOffset = 0,
    customItems = {
        [5512] = true,     
        [241308] = true,   
        [241304] = true,   
                [241294] = true,   -- 吞噬之梦药水 (填任意一个星级的基础ID即可)
        [241288] = true,   -- 鲁莽药水
    },
    customSpells = {},
    customOrder = {},
}

local MANUAL_ITEM_ALTERNATE_EXCEPTION_GROUPS = {
    { 5512, 224464 }, 
}

local function GetResolvedItemID(configItemID)
    if not configItemID or configItemID <= 0 then return configItemID end
    if GetItemCount(configItemID) > 0 or IsEquippedItem(configItemID) then return configItemID end

    for _, group in ipairs(MANUAL_ITEM_ALTERNATE_EXCEPTION_GROUPS) do
        local inGroup = false
        for _, id in ipairs(group) do if id == configItemID then inGroup = true; break end end
        if inGroup then
            for _, id in ipairs(group) do if id ~= configItemID and (GetItemCount(id) > 0 or IsEquippedItem(id)) then return id end end
        end
    end

    local _, refSpell = C_Item.GetItemSpell(configItemID)
    if refSpell and refSpell > 0 then
        for _, delta in ipairs({ 1, -1 }) do
            local oid = configItemID + delta
            if oid > 0 and GetItemCount(oid) > 0 then
                local _, sp = C_Item.GetItemSpell(oid)
                if sp == refSpell then return oid end
            end
        end
    end
    return configItemID
end

local function ParseDuration(text)
    if not text then return nil end
    if type(issecretvalue) == "function" and issecretvalue(text) then return nil end
    
    local t = tostring(text)
    
    local dur = t:match("持续(%d+)秒") or t:match("持续 (%d+) 秒") or t:match("持续%s*(%d+)%s*秒")
    if dur then return tonumber(dur) end

    dur = t:match("持续(%d+)sec") or t:match("持续 (%d+) sec") or t:match("for%s*(%d+)%s*sec") or t:match("for%s*(%d+)%s*second")
    if dur then return tonumber(dur) end

    dur = t:match("(%d+)秒") or t:match("(%d+) 秒") or t:match("(%d+) sec")
    if dur then
        local num = tonumber(dur)
        if num and num >= 5 and num <= 60 then return num end
    end
    return nil
end

local scanTooltip
local function GetItemDuration(itemID, spellID, tType)
    if spellID then
        local desc = nil
        pcall(function() if C_Spell and C_Spell.GetSpellDescription then desc = C_Spell.GetSpellDescription(spellID) end end)
        if desc and desc ~= "" then
            local dur = ParseDuration(desc)
            if dur then return dur end
        end
        if C_TooltipInfo and C_TooltipInfo.GetSpellByID then
            local tInfo = C_TooltipInfo.GetSpellByID(spellID)
            if tInfo and tInfo.lines then
                for _, line in ipairs(tInfo.lines) do
                    if line.leftText then
                        local dur = ParseDuration(line.leftText)
                        if dur then return dur end
                    end
                end
            end
        end
    end

    if tType == "item" and itemID then
        if not scanTooltip then
            scanTooltip = CreateFrame("GameTooltip", "WF_ItemBuffScanTooltip", UIParent, "GameTooltipTemplate")
            scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        end
        scanTooltip:ClearLines()
        scanTooltip:SetItemByID(itemID)
        for i = 1, scanTooltip:NumLines() do
            local line = _G["WF_ItemBuffScanTooltipTextLeft" .. i]
            if line then
                local text = line:GetText()
                if text and text ~= "" then
                    local dur = ParseDuration(text)
                    if dur then return dur end
                end
            end
        end
    end
    return nil
end

local function SafeGetBuffDuration(data)
    if data.buffDuration then return data.buffDuration end
    local tID = data.type == "item" and data.id or nil
    local sID = data.useSpellID or (data.type == "spell" and data.id or nil)
    local dur = GetItemDuration(tID, sID, data.type)
    if dur then
        data.buffDuration = dur
        return dur
    end
    return nil
end

local EMPTY_TABLE = {}
local DEFAULT_STACK_COLOR = {r=1, g=1, b=1, a=1}
local DEFAULT_CD_COLOR = {r=1, g=1, b=1, a=1}

local function IsSpellAvailable(spellID)
    if not spellID then return false end
    local isKnown = false
    pcall(function()
        if IsPlayerSpell and IsPlayerSpell(spellID) then isKnown = true end
        if not isKnown and IsSpellKnown and IsSpellKnown(spellID) then isKnown = true end
        if not isKnown and C_Spell and C_Spell.IsSpellUsable then
            local isUsable, noMana = C_Spell.IsSpellUsable(spellID)
            if isUsable or noMana then isKnown = true end
        end
        if not isKnown and IsSpellKnownOrOverridesKnown then isKnown = IsSpellKnownOrOverridesKnown(spellID) end
    end)
    return isKnown
end

local function IsItemAvailable(itemID)
    if not itemID then return false end
    local isKnown = false
    pcall(function()
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
        if C_Item and C_Item.DoesItemExistByID and C_Item.DoesItemExistByID(itemID) then
            if IsEquippedItem(itemID) then isKnown = true end
            if not isKnown and GetItemCount(itemID) > 0 then isKnown = true end
        end
    end)
    return isKnown
end

local function GetDB()
    if not WF.db.extraMonitor then WF.db.extraMonitor = {} end
    for k, v in pairs(defaults) do
        if WF.db.extraMonitor[k] == nil then
            if type(v) == "table" then
                WF.db.extraMonitor[k] = {}
                for subK, subV in pairs(v) do WF.db.extraMonitor[k][subK] = subV end
            else WF.db.extraMonitor[k] = v end
        end
    end
    if WF.db.extraMonitor.iconSize then
        WF.db.extraMonitor.iconWidth = WF.db.extraMonitor.iconSize
        WF.db.extraMonitor.iconHeight = WF.db.extraMonitor.iconSize
        WF.db.extraMonitor.iconSize = nil
    end
    return WF.db.extraMonitor
end
ExtraMonitor.GetDB = GetDB

local function ApplyTexCoord(texture, w, h)
    if not texture or not w or not h or h == 0 then return end
    local ratio = w / h
    if ratio == 1 then texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif ratio > 1 then local offset = (1 - (h/w)) / 2 * 0.84; texture:SetTexCoord(0.08, 0.92, 0.08 + offset, 0.92 - offset)
    else local offset = (1 - (w/h)) / 2 * 0.84; texture:SetTexCoord(0.08 + offset, 0.92 - offset, 0.08, 0.92) end
end

ExtraMonitor.ActiveTrackers = {}
local FramePool = {}
ExtraMonitor.FramePool = FramePool 
ExtraMonitor.ItemBuffPool = {}

local function FindCDText(f, ...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region.IsObjectType and region:IsObjectType("FontString") and region ~= f.count and region ~= f.dummyText then 
            return region
        end
    end
    return nil
end

local function UpdateItemBuffFontAndSettings(f)
    local cdDB = WF.db and WF.db.cooldownCustom or EMPTY_TABLE
    local tCatCfg = cdDB.ItemBuff or {}
    
    local cdSize = tonumber(tCatCfg.cdFontSize) or 18
    local outline = cdDB.countFontOutline or "OUTLINE"
    local fontPath = STANDARD_TEXT_FONT
    if LibStub then
        local LSM = LibStub("LibSharedMedia-3.0", true)
        if LSM and cdDB.countFont then fontPath = LSM:Fetch('font', cdDB.countFont) or STANDARD_TEXT_FONT end
    end
    
    local cdColor = tCatCfg.cdFontColor or {r=0, g=1, b=0, a=1}

    local cdText = f.cdTextObj
    if not cdText then
        if f.cd and f.cd.GetCountdownFontString then cdText = f.cd:GetCountdownFontString() end
        if not cdText and f.cd then cdText = FindCDText(f, f.cd:GetRegions()) end
        if cdText then f.cdTextObj = cdText end
    end
    
    if cdText then
        pcall(cdText.SetFont, cdText, fontPath, cdSize, outline)
        cdText:SetTextColor(cdColor.r, cdColor.g, cdColor.b, cdColor.a or 1)
    end
end

function ExtraMonitor:ShowItemBuff(data)
    local id = data.id
    local buffDur = SafeGetBuffDuration(data)
    if not buffDur then return end

    local f = ExtraMonitor.ItemBuffPool[id]
    if not f then
        f = CreateFrame("Button", "WF_ItemBuffIcon_"..id, UIParent, "BackdropTemplate")
        f:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
        f:SetBackdropBorderColor(0, 0, 0, 1)
        
        f.icon = f:CreateTexture(nil, "BACKGROUND")
        f.icon:SetAllPoints()
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.cd:SetAllPoints()
        f.cd:SetDrawEdge(false)
        f.cd:SetReverse(true)
        f.cd:SetHideCountdownNumbers(false)
        
        f.isExtraMonitor = true 
        f.id = id
        f:Hide()
        ExtraMonitor.ItemBuffPool[id] = f
    end
    
    local tex = (data.type == "item") and C_Item.GetItemIconByID(data.id) or C_Spell.GetSpellTexture(data.id)
    if tex then f.icon:SetTexture(tex) end
    
    UpdateItemBuffFontAndSettings(f)
    if ActionButton_ShowOverlayGlow then ActionButton_ShowOverlayGlow(f) end
    
    pcall(f.cd.SetCooldown, f.cd, GetTime(), buffDur)
    
    f.isBuffActive = true
    f:Show()
    
    if WF.CooldownCustomAPI then WF.CooldownCustomAPI:MarkLayoutDirty(true) end
    
    if id == "dummy_test" then
        if f.timer then f.timer:Cancel() end
        return
    end

    if f.timer then f.timer:Cancel() end
    f.timer = C_Timer.NewTimer(buffDur, function()
        f.isBuffActive = false
        f:Hide()
        if ActionButton_HideOverlayGlow then ActionButton_HideOverlayGlow(f) end
        if WF.CooldownCustomAPI then WF.CooldownCustomAPI:MarkLayoutDirty(true) end
    end)
end

function ExtraMonitor:GetTrackedItemsForSandbox()
    local parentEnabled = WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable ~= false
    if not parentEnabled or (WF.db and WF.db.extraMonitor and WF.db.extraMonitor.enable == false) then return {} end

    local db = self.GetDB(); local trackers = {}; local order = db.customOrder or EMPTY_TABLE
    local function AddEM(tStr, id, isRac, isTrin, en)
        local idStr = tostring(id)
        local nameStr = (tStr == "item") and (C_Item.GetItemNameByID(id) or "Item:"..id) or ((C_Spell.GetSpellInfo(id) and C_Spell.GetSpellInfo(id).name) or "Spell:"..id)
        local iconTex = (tStr == "item") and C_Item.GetItemIconByID(id) or C_Spell.GetSpellTexture(id)
        local dbKey = tStr .. "_" .. idStr
        table.insert(trackers, { idStr = idStr, dbKey = dbKey, name = nameStr, icon = iconTex, defaultIdx = order[dbKey] or 999, type = tStr, isRacial = isRac, isTrinket = isTrin, enabled = en })
    end
    
    local racials = ns.RACE_RACIALS or EMPTY_TABLE
    local _, race = UnitRace("player")
    local seenRacialNames = {} 
    if race and racials[race] then 
        for _, spellID in ipairs(racials[race]) do 
            if IsSpellAvailable(spellID) then 
                local sInfo = C_Spell.GetSpellInfo(spellID)
                local sName = sInfo and sInfo.name or tostring(spellID)
                if not seenRacialNames[sName] then
                    seenRacialNames[sName] = true
                    AddEM("spell", spellID, true, false, db.autoRacial) 
                end
            end 
        end 
    end
    
    for slot = 13, 14 do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then local _, useSpellID = C_Item.GetItemSpell(itemID); if useSpellID and useSpellID > 0 then AddEM("item", itemID, false, true, db.autoTrinkets) end end
    end
    
    if db.customSpells then for id, en in pairs(db.customSpells) do if IsSpellAvailable(id) then AddEM("spell", id, false, false, en) end end end
    if db.customItems then for id, en in pairs(db.customItems) do AddEM("item", id, false, false, en) end end
    return trackers
end

function ExtraMonitor:ScanTracked()
    wipe(self.ActiveTrackers)
    local parentEnabled = WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable ~= false
    if not parentEnabled or (WF.db and WF.db.extraMonitor and WF.db.extraMonitor.enable == false) then return end

    local db = GetDB()
    if not db.enable then return end

    local seenSpells = {}
    local seenItems = {}
    local seenRacialNames = {} 

    local racials = ns.RACE_RACIALS or EMPTY_TABLE
    if db.autoRacial then
        local _, race = UnitRace("player")
        if race and racials[race] then 
            for _, spellID in ipairs(racials[race]) do 
                if IsSpellAvailable(spellID) and not seenSpells[spellID] then 
                    local sInfo = C_Spell.GetSpellInfo(spellID)
                    local sName = sInfo and sInfo.name or tostring(spellID)
                    if not seenRacialNames[sName] then
                        seenRacialNames[sName] = true
                        seenSpells[spellID] = true
                        local buffDur = GetItemDuration(nil, spellID, "spell")
                        table.insert(self.ActiveTrackers, { type = "spell", id = spellID, isRacial = true, useSpellID = spellID, buffDuration = buffDur }) 
                    end
                end 
            end 
        end
    end
    
    if db.customSpells then 
        for spellID, enabled in pairs(db.customSpells) do 
            if enabled and IsSpellAvailable(spellID) and not seenSpells[spellID] then 
                seenSpells[spellID] = true
                local buffDur = GetItemDuration(nil, spellID, "spell")
                table.insert(self.ActiveTrackers, { type = "spell", id = spellID, useSpellID = spellID, buffDuration = buffDur }) 
            end 
        end 
    end
    
    if db.autoTrinkets then
        for slot = 13, 14 do
            local itemID = GetInventoryItemID("player", slot)
            if itemID then 
                local _, useSpellID = C_Item.GetItemSpell(itemID)
                if useSpellID and useSpellID > 0 and not seenItems[itemID] then 
                    seenItems[itemID] = true
                    local buffDur = GetItemDuration(itemID, useSpellID, "item")
                    table.insert(self.ActiveTrackers, { type = "item", id = itemID, slot = slot, isTrinket = true, useSpellID = useSpellID, buffDuration = buffDur }) 
                end 
            end
        end
    end
    
    if db.customItems then 
        for configItemID, enabled in pairs(db.customItems) do 
            if enabled then 
                local actualID = GetResolvedItemID(configItemID)
                local isAvail = IsItemAvailable(actualID)
                if not isAvail and (configItemID == 5512 or configItemID == 224464) then 
                    local _, class = UnitClass("player")
                    if class == "WARLOCK" then isAvail = true end 
                end
                if isAvail and not seenItems[actualID] then 
                    seenItems[actualID] = true
                    local _, useSpellID = C_Item.GetItemSpell(actualID)
                    local buffDur = GetItemDuration(actualID, useSpellID, "item")
                    table.insert(self.ActiveTrackers, { type = "item", id = actualID, configID = configItemID, useSpellID = useSpellID, buffDuration = buffDur }) 
                end 
            end 
        end 
    end

    table.sort(self.ActiveTrackers, function(a, b)
        local order = db.customOrder or EMPTY_TABLE
        local baseIdA = a.configID or a.id; local baseIdB = b.configID or b.id
        local idA = a.type .. "_" .. baseIdA; local idB = b.type .. "_" .. baseIdB
        local valA = order[idA] or 999; local valB = order[idB] or 999
        if valA == valB then return idA < idB end
        return valA < valB
    end)
end

local function AcquireIconFrame(dbKey)
    if not FramePool[dbKey] then
        local fName = "WF_ExtraMonitor_Icon_" .. string.gsub(dbKey, "[^%w]", "_")
        local f = CreateFrame("Button", fName, ExtraMonitor, "BackdropTemplate")
        f:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
        f:SetBackdropBorderColor(0, 0, 0, 1)
        f.icon = f:CreateTexture(nil, "BACKGROUND"); f.icon:SetAllPoints()
        f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.cd:SetAllPoints(); f.cd:SetDrawEdge(false); 
        f.cd:SetHideCountdownNumbers(false) 
        f.textFrame = CreateFrame("Frame", nil, f); f.textFrame:SetAllPoints(); f.textFrame:SetFrameLevel(f.cd:GetFrameLevel() + 5)
        f.count = f.textFrame:CreateFontString(nil, "OVERLAY")
        f.dummyText = f.textFrame:CreateFontString(nil, "OVERLAY")
        f.dummyText:SetShadowColor(0,0,0,1); f.dummyText:SetShadowOffset(1, -1)
        f.dummyText:Hide()
        f.mask = f.textFrame:CreateTexture(nil, "BACKGROUND")
        f.mask:SetAllPoints()
        f.mask:SetColorTexture(0, 0.5, 1, 0.3)
        f.mask:Hide()
        f.isExtraMonitor = true
        f.cdActive = false
        FramePool[dbKey] = f
    end
    return FramePool[dbKey]
end

function ExtraMonitor:UpdateDisplay()
    local db = GetDB(); local dbO = (WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides) or EMPTY_TABLE
    
    local parentEnabled = WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable ~= false
    if not db.enable or not parentEnabled then 
        self:Hide()
        for _, f in pairs(FramePool) do f:Hide(); f.cdActive = false; if f.cd then pcall(f.cd.Clear, f.cd) end end
        return 
    end
    
    self:Show()

    local w = tonumber(db.iconWidth) or 36; local h = tonumber(db.iconHeight) or 36

    local isConfigOpen = false
    if WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown() and WF.UI.CurrentNodeKey == "cooldownCustom_Global" then isConfigOpen = true end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then isConfigOpen = true end

    for _, f in pairs(FramePool) do f._emActiveThisFrame = false end

    if isConfigOpen then
        if not ExtraMonitor.ItemBuffPool["dummy_test"] then
            local df = CreateFrame("Button", "WF_ItemBuffIcon_dummy_test", UIParent, "BackdropTemplate")
            df:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
            df:SetBackdropBorderColor(0, 0, 0, 1)
            df.icon = df:CreateTexture(nil, "BACKGROUND")
            df.icon:SetAllPoints()
            df.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            df.cd = CreateFrame("Cooldown", nil, df, "CooldownFrameTemplate")
            df.cd:SetAllPoints()
            df.cd:SetDrawEdge(false)
            df.cd:SetReverse(true)
            df.cd:SetHideCountdownNumbers(false)
            df.isExtraMonitor = true 
            df.id = "dummy_test"
            df.icon:SetTexture(134400)
            df.isBuffActive = true
            ExtraMonitor.ItemBuffPool["dummy_test"] = df
            ExtraMonitor:ShowItemBuff({id = "dummy_test", type = "spell", buffDuration = 15})
        else
            local f = ExtraMonitor.ItemBuffPool["dummy_test"]
            f.isBuffActive = true
            f:Show()
            UpdateItemBuffFontAndSettings(f)
            if WF.CooldownCustomAPI then WF.CooldownCustomAPI:MarkLayoutDirty(false) end
        end
    else
        if ExtraMonitor.ItemBuffPool["dummy_test"] then
            ExtraMonitor.ItemBuffPool["dummy_test"].isBuffActive = false
            ExtraMonitor.ItemBuffPool["dummy_test"]:Hide()
        end
    end

    local function updateTextSafely(fontStr, text)
        if fontStr._lastText ~= text then
            fontStr:SetText(text)
            fontStr._lastText = text
        end
    end

    for i, data in ipairs(self.ActiveTrackers) do
        local configID = data.configID or data.id
        local dbKey = data.type .. "_" .. tostring(configID)
        local f = AcquireIconFrame(dbKey)
        f._emActiveThisFrame = true; f.spellID = data.id; f.dbKey = dbKey
        
        local oCat = dbO[f.dbKey] and dbO[f.dbKey].category or (dbO[tostring(configID)] and dbO[tostring(configID)].category)
        local isCrossGrouped = (oCat == "Essential" or oCat == "Utility" or oCat == "Defensive" or oCat == "BuffIcon" or oCat == "BuffBar" or (oCat and string.sub(oCat, 1, 9) == "CustomRow") or (oCat and string.sub(oCat, 1, 13) == "CustomBuffRow"))

        if isCrossGrouped then
            f.isCrossGrouped = true; f.category = oCat
            f.sortIndex = dbO[f.dbKey] and dbO[f.dbKey].sortIndex or (dbO[tostring(configID)] and dbO[tostring(configID)].sortIndex) or 999
        else 
            f.isCrossGrouped = false; f.category = "ExtraMonitor" 
        end
        
        local count, st, dur = 0, 0, 0; local chargeInfo = nil; local durObj = nil; local isOnGCD = false; local spellCdActive = false
        
        if data.type == "item" then
            if data.isTrinket then count = 1 else count = GetItemCount(data.id, false, true) or 0 end
            if C_Container and C_Container.GetItemCooldown then st, dur = C_Container.GetItemCooldown(data.id) elseif GetItemCooldown then st, dur = GetItemCooldown(data.id) end
            local newTex = C_Item.GetItemIconByID(data.id)
            if f._lastIconTex ~= newTex then f.icon:SetTexture(newTex); f._lastIconTex = newTex end
        elseif data.type == "spell" then
            if C_Spell and C_Spell.GetSpellCharges then 
                local ok, res = pcall(C_Spell.GetSpellCharges, data.id)
                if ok then chargeInfo = res end
            end
            count = chargeInfo and chargeInfo.currentCharges or 1
            
            if C_Spell and C_Spell.GetSpellCooldown then
                local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, data.id)
                if ok and cdInfo then 
                    st, dur = cdInfo.startTime, cdInfo.duration
                    isOnGCD = (cdInfo.isOnGCD == true)
                    if cdInfo.isActive ~= nil then spellCdActive = (cdInfo.isActive == true) else spellCdActive = true end 
                end
            end
            if not isOnGCD and C_Spell and C_Spell.GetSpellCooldownDuration then 
                local ok, res = pcall(C_Spell.GetSpellCooldownDuration, data.id)
                if ok then durObj = res end
            end
            local newTex = C_Spell.GetSpellTexture(data.id)
            if f._lastIconTex ~= newTex then f.icon:SetTexture(newTex); f._lastIconTex = newTex end
        end

        local tCat = f.isCrossGrouped and f.category or "ExtraMonitor"
        local cdDB = WF.db.cooldownCustom or EMPTY_TABLE
        local tCatCfg = cdDB[tCat] or db
        
        local realW = f.isCrossGrouped and (tonumber(tCatCfg.width) or 45) or w
        local realH = f.isCrossGrouped and (tonumber(tCatCfg.height) or 45) or h
        
        if not parentEnabled then
            if f._lastWForTex ~= realW or f._lastHForTex ~= realH then
                ApplyTexCoord(f.icon, realW, realH)
                f._lastWForTex = realW; f._lastHForTex = realH
            end
        end
        
        local stackPos = tCatCfg.stackPosition or db.stackPosition or "BOTTOMRIGHT"; local stackX = tonumber(tCatCfg.stackXOffset or db.stackXOffset) or 0; local stackY = tonumber(tCatCfg.stackYOffset or db.stackYOffset) or 0; local stackSize = tonumber(tCatCfg.stackFontSize or db.stackFontSize) or 14; local stackColor = tCatCfg.stackFontColor or db.stackFontColor or DEFAULT_STACK_COLOR
        local cdPos = tCatCfg.cdPosition or db.cdPosition or "CENTER"; local cdX = tonumber(tCatCfg.cdXOffset or db.cdXOffset) or 0; local cdY = tonumber(tCatCfg.cdYOffset or db.cdYOffset) or 0; local cdSize = tonumber(tCatCfg.cdFontSize or db.cdFontSize) or 18; local cdColor = tCatCfg.cdFontColor or db.cdFontColor or DEFAULT_CD_COLOR
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        local fontPath = (LSM and cdDB.countFont and LSM:Fetch('font', cdDB.countFont)) or STANDARD_TEXT_FONT; local outline = cdDB.countFontOutline or "OUTLINE"

        if f.count._lastFont ~= fontPath or f.count._lastSize ~= stackSize or f.count._lastOutline ~= outline then
            pcall(f.count.SetFont, f.count, fontPath, stackSize, outline)
            f.count._lastFont = fontPath; f.count._lastSize = stackSize; f.count._lastOutline = outline
        end
        if f.count._lastColorR ~= stackColor.r or f.count._lastColorG ~= stackColor.g or f.count._lastColorB ~= stackColor.b or f.count._lastColorA ~= stackColor.a then
            f.count:SetTextColor(stackColor.r, stackColor.g, stackColor.b, stackColor.a or 1)
            f.count._lastColorR = stackColor.r; f.count._lastColorG = stackColor.g; f.count._lastColorB = stackColor.b; f.count._lastColorA = stackColor.a
        end
        if stackX == 0 and stackY == 0 and stackPos == "BOTTOMRIGHT" then stackX = -2; stackY = 2 end
        if f.count._lastPos ~= stackPos or f.count._lastX ~= stackX or f.count._lastY ~= stackY then
            f.count:ClearAllPoints()
            f.count:SetPoint(stackPos, f.textFrame, stackPos, stackX, stackY)
            f.count._lastPos = stackPos; f.count._lastX = stackX; f.count._lastY = stackY
        end

        if f.dummyText._lastFont ~= fontPath or f.dummyText._lastSize ~= cdSize or f.dummyText._lastOutline ~= outline then
            pcall(f.dummyText.SetFont, f.dummyText, fontPath, cdSize, outline)
            f.dummyText._lastFont = fontPath; f.dummyText._lastSize = cdSize; f.dummyText._lastOutline = outline
        end
        if f.dummyText._lastColorR ~= cdColor.r or f.dummyText._lastColorG ~= cdColor.g or f.dummyText._lastColorB ~= cdColor.b or f.dummyText._lastColorA ~= cdColor.a then
            f.dummyText:SetTextColor(cdColor.r, cdColor.g, cdColor.b, cdColor.a or 1)
            f.dummyText._lastColorR = cdColor.r; f.dummyText._lastColorG = cdColor.g; f.dummyText._lastColorB = cdColor.b; f.dummyText._lastColorA = cdColor.a
        end
        if f.dummyText._lastPos ~= cdPos or f.dummyText._lastX ~= cdX or f.dummyText._lastY ~= cdY then
            f.dummyText:ClearAllPoints()
            f.dummyText:SetPoint(cdPos, f.textFrame, cdPos, cdX, cdY)
            f.dummyText._lastPos = cdPos; f.dummyText._lastX = cdX; f.dummyText._lastY = cdY
        end

        local cdText = f.cdTextObj
        if not cdText then
            if f.cd.GetCountdownFontString then cdText = f.cd:GetCountdownFontString() end
            if not cdText then cdText = FindCDText(f, f.cd:GetRegions()) end
            if cdText then f.cdTextObj = cdText end
        end

        if cdText then 
            if cdText._lastFont ~= fontPath or cdText._lastSize ~= cdSize or cdText._lastOutline ~= outline then
                pcall(cdText.SetFont, cdText, fontPath, cdSize, outline)
                cdText._lastFont = fontPath; cdText._lastSize = cdSize; cdText._lastOutline = outline
            end
            if cdText._lastColorR ~= cdColor.r or cdText._lastColorG ~= cdColor.g or cdText._lastColorB ~= cdColor.b or cdText._lastColorA ~= cdColor.a then
                cdText:SetTextColor(cdColor.r, cdColor.g, cdColor.b, cdColor.a or 1)
                cdText._lastColorR = cdColor.r; cdText._lastColorG = cdColor.g; cdText._lastColorB = cdColor.b; cdText._lastColorA = cdColor.a
            end
            if cdText._lastPos ~= cdPos or cdText._lastX ~= cdX or cdText._lastY ~= cdY then
                cdText:ClearAllPoints()
                cdText:SetPoint(cdPos, f.cd, cdPos, cdX, cdY) 
                cdText._lastPos = cdPos; cdText._lastX = cdX; cdText._lastY = cdY
            end
        end

        local shouldShow = false
        
        if isConfigOpen and not f.isCrossGrouped then
            shouldShow = true
            updateTextSafely(f.count, data.type == "item" and "5" or "")
            updateTextSafely(f.dummyText, data.type == "spell" and "12" or "")
            if not f.dummyText:IsShown() then f.dummyText:Show() end
            if f.cdActive then f.cd:Clear(); f.cdActive = false; f._lastSt = nil; f._lastDurObj = nil end
            
            if f._lastDesat ~= false then f.icon:SetDesaturated(false); f.icon:SetVertexColor(1, 1, 1); f._lastDesat = false end
            if not f.mask:IsShown() then f.mask:Show() end
        else
            if f.dummyText:IsShown() then f.dummyText:Hide() end
            if count > 0 or data.type == "spell" then
                shouldShow = true
                if count > 1 then updateTextSafely(f.count, tostring(count)) else updateTextSafely(f.count, "") end
                
                -- 【修复2】：精确判断真实剩余冷却时间，杜绝魔兽世界历史CD接口导致的假褪色
                local isFaded = false 
                if data.type == "spell" then
                    if not isOnGCD and durObj and spellCdActive then
                        local remain = (durObj.startTime or 0) + (durObj.duration or 0) - GetTime()
                        if remain > 0 then
                            if not f._lastDurObj or f._lastDurObj.startTime ~= durObj.startTime or f._lastDurObj.duration ~= durObj.duration then
                                pcall(f.cd.SetCooldownFromDurationObject, f.cd, durObj)
                                f._lastDurObj = { startTime = durObj.startTime, duration = durObj.duration }
                                f._lastSt = nil
                            end
                            f.cdActive = true
                            isFaded = true
                        else
                            if f.cdActive then f.cd:Clear(); f.cdActive = false; f._lastDurObj = nil; f._lastSt = nil end
                            isFaded = false
                        end
                    else 
                        if f.cdActive then f.cd:Clear(); f.cdActive = false; f._lastDurObj = nil; f._lastSt = nil end 
                        isFaded = false
                    end
                    if chargeInfo and chargeInfo.maxCharges and chargeInfo.maxCharges > 1 then 
                        isFaded = (chargeInfo.currentCharges == 0) 
                    end
                else
                    local validItemCD = false
                    if type(dur) == "number" and dur > 1.5 then 
                        if st and (st + dur) > GetTime() then
                            validItemCD = true 
                        end
                    elseif type(issecretvalue) == "function" and issecretvalue(dur) then 
                        validItemCD = true 
                    end
                    
                    if validItemCD then
                        if f._lastSt ~= st or f._lastDur ~= dur then
                            pcall(f.cd.SetCooldown, f.cd, st, dur)
                            f._lastSt = st
                            f._lastDur = dur
                            f._lastDurObj = nil
                        end
                        f.cdActive = true; isFaded = true 
                    else 
                        if f.cdActive then f.cd:Clear(); f.cdActive = false; f._lastSt = nil; f._lastDurObj = nil end; isFaded = false 
                    end
                end

                if isFaded then 
                    if f._lastDesat ~= true then f.icon:SetDesaturated(true); f.icon:SetVertexColor(0.5, 0.5, 0.5); f._lastDesat = true end
                    if f.mask:IsShown() then f.mask:Hide() end
                else 
                    if f._lastDesat ~= false then f.icon:SetDesaturated(false); f.icon:SetVertexColor(1, 1, 1); f._lastDesat = false end
                    if f.mask:IsShown() then f.mask:Hide() end
                end
            else
                if db.zeroCountBehavior == "gray" then 
                    shouldShow = true
                    if f._lastDesat ~= true then f.icon:SetDesaturated(true); f.icon:SetVertexColor(0.5, 0.5, 0.5); f._lastDesat = true end
                    if f.mask:IsShown() then f.mask:Hide() end
                    updateTextSafely(f.count, "0")
                    if f.cdActive then f.cd:Clear(); f.cdActive = false; f._lastSt = nil; f._lastDurObj = nil end
                else 
                    shouldShow = false 
                end
            end
        end

        if shouldShow then
            if not f:IsShown() then f:Show() end
        else
            if f:IsShown() then f:Hide() end
        end
    end

    for _, f in pairs(FramePool) do if not f._emActiveThisFrame and f:IsShown() then f:Hide() end end
end

local updatePending = false
function ExtraMonitor:TriggerUpdate()
    if not updatePending then
        updatePending = true
        C_Timer.After(0.05, function()
            updatePending = false
            if ExtraMonitor:IsShown() or (WF.db and WF.db.extraMonitor and WF.db.extraMonitor.enable) then
                ExtraMonitor:UpdateDisplay()
            end
        end)
    end
end
WF.ExtraMonitorAPI.TriggerUpdate = ExtraMonitor.TriggerUpdate

local function InitExtraMonitor()
    local parentEnabled = WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable ~= false
    if (WF.db and WF.db.extraMonitor and WF.db.extraMonitor.enable == false) or not parentEnabled then 
        ExtraMonitor:Hide()
        return 
    end

    local db = GetDB()
    ExtraMonitor:SetFrameStrata("MEDIUM")
    ExtraMonitor:ScanTracked()
    ExtraMonitor:UpdateDisplay()
    
    if WF.RegisterEvent then
        WF:RegisterEvent("PLAYER_ENTERING_WORLD", function() ExtraMonitor:ScanTracked(); ExtraMonitor:TriggerUpdate() end)
        WF:RegisterEvent("BAG_UPDATE_DELAYED", function() ExtraMonitor:ScanTracked(); ExtraMonitor:TriggerUpdate() end)
        WF:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() ExtraMonitor:ScanTracked(); ExtraMonitor:TriggerUpdate() end)
        WF:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() ExtraMonitor:ScanTracked(); ExtraMonitor:TriggerUpdate() end)
        
        WF:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(event, unit, castGUID, spellID)
            if unit ~= "player" and unit ~= "pet" then return end
            if type(spellID) ~= "number" then return end
            
            for _, data in ipairs(ExtraMonitor.ActiveTrackers) do
                if (data.useSpellID == spellID) or (data.id == spellID) then
                    local bDur = SafeGetBuffDuration(data)
                    if bDur then 
                        ExtraMonitor:ShowItemBuff(data) 
                    end
                end
            end
        end)
        
        WF:RegisterEvent("SPELL_UPDATE_COOLDOWN", function() ExtraMonitor:TriggerUpdate() end)
        WF:RegisterEvent("SPELL_UPDATE_CHARGES", function() ExtraMonitor:TriggerUpdate() end)
        WF:RegisterEvent("BAG_UPDATE_COOLDOWN", function() ExtraMonitor:TriggerUpdate() end)
        WF:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", function() ExtraMonitor:TriggerUpdate() end)
        
        WF:RegisterEvent("ADDON_LOADED", function(_, addon)
            if addon == "WishFlex_Options" then
                C_Timer.After(0.5, function()
                    if WF.UI and WF.UI.MainFrame then
                        WF.UI.MainFrame:HookScript("OnShow", function() ExtraMonitor:TriggerUpdate() end)
                        WF.UI.MainFrame:HookScript("OnHide", function() ExtraMonitor:TriggerUpdate() end)
                    end
                end)
            end
        end)
    end

    C_Timer.After(1, function()
        if EditModeManagerFrame then
            EditModeManagerFrame:HookScript("OnShow", function() ExtraMonitor:TriggerUpdate() end)
            EditModeManagerFrame:HookScript("OnHide", function() ExtraMonitor:TriggerUpdate() end)
        end
    end)
end

WF:RegisterModule("extraMonitor", L["Extra CD Monitor"] or "额外监控", InitExtraMonitor)