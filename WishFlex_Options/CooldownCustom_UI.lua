local AddonName, ns = ...
local WF = _G.WishFlex
local L = WF.L
local CDMod = WF.CooldownCustomAPI
local EM = WF.ExtraMonitorAPI
if not CDMod then return end

local LSM = LibStub("LibSharedMedia-3.0", true)
local LCG = LibStub("LibCustomGlow-1.0", true)

local function PixelSnap(value)
    if not value then return 0 end
    local screenHeight = select(2, GetPhysicalScreenSize()); if not screenHeight or screenHeight == 0 then return value end
    local uiScale = UIParent:GetEffectiveScale(); if not uiScale or uiScale == 0 then return value end
    local onePixel = 768.0 / screenHeight / uiScale
    return math.floor(value / onePixel + 0.5) * onePixel
end

CDMod.Sandbox = CDMod.Sandbox or {
    popupMode = nil, popupTarget = nil, 
    scannedEssential = {}, scannedUtility = {}, scannedDefensive = {}, scannedBuffIcon = {}, scannedBuffBar = {}, scannedExtraMonitor = {}, scannedItemBuff = {},
    RenderedLists = {}, QuickAddSelection = {} 
}

local function IsCombatCD(cat) return (cat == "Essential" or cat == "Utility" or cat == "Defensive" or cat == "ExtraMonitor" or (cat and string.sub(cat, 1, 9) == "CustomRow")) end
local function IsBuffCat(cat) return (cat == "BuffIcon" or cat == "BuffBar" or cat == "ItemBuff" or (cat and string.sub(cat, 1, 13) == "CustomBuffRow")) end

local function ForceLearnCheck(spellID) 
    local known = false
    if not spellID then return false end
    pcall(function() 
        if C_Spell and C_Spell.IsSpellLearned then known = C_Spell.IsSpellLearned(spellID) end
        if not known and IsPlayerSpell then known = IsPlayerSpell(spellID) end
        if not known and IsSpellKnown then known = IsSpellKnown(spellID) end
        if not known and IsSpellKnownOrOverridesKnown then known = IsSpellKnownOrOverridesKnown(spellID) end
    end)
    return known 
end

local function ApplySmartTexCoord(texture, w, h)
    if not texture then return end
    w = w or 1; h = h or 1; if w == 0 then w = 1 end; if h == 0 then h = 1 end
    local zoom = 0.1; if w == h then texture:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom); return end
    local ratio = w / h
    if ratio > 1 then local crop = (1 - (1 / ratio)) / 2; local actualCrop = zoom + crop * (1 - 2*zoom); texture:SetTexCoord(zoom, 1 - zoom, actualCrop, 1 - actualCrop)
    else local crop = (1 - ratio) / 2; local actualCrop = zoom + crop * (1 - 2*zoom); texture:SetTexCoord(actualCrop, 1 - actualCrop, zoom, 1 - zoom) end
end

local function ScanForSandbox()
    wipe(CDMod.Sandbox.scannedEssential); wipe(CDMod.Sandbox.scannedUtility); wipe(CDMod.Sandbox.scannedDefensive); wipe(CDMod.Sandbox.scannedBuffIcon); wipe(CDMod.Sandbox.scannedBuffBar); wipe(CDMod.Sandbox.scannedExtraMonitor); wipe(CDMod.Sandbox.scannedItemBuff)
    if WF.db.cooldownCustom and WF.db.cooldownCustom.CustomRows then for _, r in ipairs(WF.db.cooldownCustom.CustomRows) do if not CDMod.Sandbox["scanned"..r] then CDMod.Sandbox["scanned"..r] = {} end; wipe(CDMod.Sandbox["scanned"..r]) end end
    if WF.db.cooldownCustom and WF.db.cooldownCustom.CustomBuffRows then for _, r in ipairs(WF.db.cooldownCustom.CustomBuffRows) do if not CDMod.Sandbox["scanned"..r] then CDMod.Sandbox["scanned"..r] = {} end; wipe(CDMod.Sandbox["scanned"..r]) end end

    local dbO = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides or {}; local seen = {}

    if EM and EM.GetTrackedItemsForSandbox then
        for _, item in ipairs(EM:GetTrackedItemsForSandbox()) do
            local isValid = true
            if item then
                if item.type == "spell" then isValid = ForceLearnCheck(tonumber(item.idStr)) else isValid = true end
            end
            
            if isValid then
                local oCat = nil
                if dbO[item.dbKey] and dbO[item.dbKey].category then oCat = dbO[item.dbKey].category
                elseif dbO[item.idStr] and dbO[item.idStr].category then oCat = dbO[item.idStr].category end
                
                local tCat = "ExtraMonitor"
                if oCat and (IsCombatCD(oCat) or oCat == "ExtraMonitor") then tCat = oCat end
                
                local sItem = { idStr = item.idStr, dbKey = item.dbKey, name = item.name, icon = item.icon, defaultIdx = item.defaultIdx, isEM = true, emData = item }
                
                if CDMod.Sandbox["scanned"..tCat] then
                    if not seen[item.dbKey] then
                        seen[item.dbKey] = true; seen["CD_" .. item.idStr] = true; seen["BUFF_" .. item.idStr] = true; seen[item.idStr] = true
                        table.insert(CDMod.Sandbox["scanned"..tCat], sItem)
                    end
                end
            end
        end
    end

    local function ProcessItem(spellID, defCat, defaultIndex, isAura, rawInfo)
        if not spellID then return end
        if type(issecretvalue) == "function" and issecretvalue(spellID) then return end
        
        local sidStr = tostring(spellID); local domain = isAura and "BUFF" or "CD"; local dbKey = domain .. "_" .. sidStr
        local tCat = defCat; local defSpells = WF.DefensiveSpells or ns.DefensiveSpells
        
        if seen[dbKey] then return end; seen[dbKey] = true

        if dbO[dbKey] and dbO[dbKey].category then 
            local oCat = dbO[dbKey].category; 
            if oCat == "Essential" or oCat == "Utility" or oCat == "Defensive" or oCat == "BuffIcon" or oCat == "BuffBar" or oCat == "ExtraMonitor" or CDMod.Sandbox["scanned"..oCat] then tCat = oCat end
        elseif dbO[sidStr] and dbO[sidStr].category then 
            local oCat = dbO[sidStr].category; 
            local oDomain = (oCat == "BuffIcon" or oCat == "BuffBar" or string.sub(oCat, 1, 13) == "CustomBuffRow") and "BUFF" or "CD"; 
            if oDomain == domain and (oCat == "Essential" or oCat == "Utility" or oCat == "Defensive" or oCat == "BuffIcon" or oCat == "BuffBar" or oCat == "ExtraMonitor" or CDMod.Sandbox["scanned"..oCat]) then tCat = oCat end
        else 
            if domain == "CD" and defSpells and (defSpells[spellID] or defSpells[sidStr] or defSpells[tonumber(spellID)] or (rawInfo and rawInfo.spellID and (defSpells[rawInfo.spellID] or defSpells[tostring(rawInfo.spellID)]))) then tCat = "Defensive" end 
        end

        local sInfo = nil; pcall(function() sInfo = C_Spell.GetSpellInfo(spellID) end)
        if sInfo and sInfo.name then 
            local item = { idStr = sidStr, dbKey = dbKey, name = sInfo.name, icon = sInfo.iconID, defaultIdx = defaultIndex or 999, linkedIDs = rawInfo and rawInfo.linkedSpellIDs }
            if CDMod.Sandbox["scanned"..tCat] then table.insert(CDMod.Sandbox["scanned"..tCat], item) end
        end
    end

    local ScanCacheFrames = {}
    local function DoActiveScan(viewerName, defCat, isAura, fallbackType)
        local viewer = _G[viewerName]; if not viewer then return end
        
        local function TryProcess(cdID, layoutIndex)
            if not cdID then return end
            local info = nil; pcall(function() info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID) end)
            if info then 
                local mainID = (info.linkedSpellIDs and info.linkedSpellIDs[1]) or info.overrideSpellID or info.spellID
                if mainID and type(mainID) == "number" and not (issecretvalue and issecretvalue(mainID)) and mainID > 0 then
                    ProcessItem(mainID, defCat, layoutIndex, isAura, info)
                end
            end 
        end

        wipe(ScanCacheFrames)
        if viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do table.insert(ScanCacheFrames, frame) end
        else
            for _, child in ipairs({ viewer:GetChildren() }) do table.insert(ScanCacheFrames, child) end
        end
        for _, frame in ipairs(ScanCacheFrames) do
            local cdID = frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID)
            TryProcess(cdID, frame.layoutIndex or 999)
        end
    end

    DoActiveScan("EssentialCooldownViewer", "Essential", false, 0)
    DoActiveScan("UtilityCooldownViewer", "Utility", false, 1)
    DoActiveScan("BuffIconCooldownViewer", "BuffIcon", true, 2)
    DoActiveScan("BuffBarCooldownViewer", "BuffBar", true, 3)
end

local function GetSafeJustify(anchorStr)
    if type(anchorStr) ~= "string" then return "CENTER" end
    if string.match(anchorStr, "LEFT") then return "LEFT" elseif string.match(anchorStr, "RIGHT") then return "RIGHT" else return "CENTER" end
end

local function DrawSandboxToUI(forcedWidth)
    local db = WF.db.cooldownCustom; local scrollChild = WF.UI.MainScrollChild
    if not scrollChild or not scrollChild.SandboxIconsPool then return 0, 0 end
    local previewBox = scrollChild.CD_Sandbox_Box; local canvas = scrollChild.CD_Sandbox_Canvas
    if not canvas or not previewBox then return 0, 0 end

    for _, btn in ipairs(scrollChild.SandboxIconsPool) do btn:Hide(); btn:ClearAllPoints(); btn:SetParent(canvas) end
    if not scrollChild.CD_Sandbox_DropIndicator then
        local ind = CreateFrame("Frame", nil, canvas, "BackdropTemplate"); ind:SetSize(4, 45); local tex = ind:CreateTexture(nil, "OVERLAY"); tex:SetAllPoints(); tex:SetColorTexture(0, 1, 0, 1); ind.tex = tex; ind:Hide(); scrollChild.CD_Sandbox_DropIndicator = ind
    else scrollChild.CD_Sandbox_DropIndicator:SetParent(canvas) end
    
    local poolIdx = 1; local maxDisplayW = (forcedWidth or 850) - 30
    local function GetSortedList(source, catName)
        local sorted = {}; for _, v in ipairs(source) do table.insert(sorted, v) end
        table.sort(sorted, function(a, b) 
            local idxA = db.spellOverrides and (db.spellOverrides[a.dbKey] or db.spellOverrides[a.idStr]) and ((db.spellOverrides[a.dbKey] and db.spellOverrides[a.dbKey].sortIndex) or (db.spellOverrides[a.idStr] and db.spellOverrides[a.idStr].sortIndex))
            local idxB = db.spellOverrides and (db.spellOverrides[b.dbKey] or db.spellOverrides[b.idStr]) and ((db.spellOverrides[b.dbKey] and db.spellOverrides[b.dbKey].sortIndex) or (db.spellOverrides[b.idStr] and db.spellOverrides[b.idStr].sortIndex))
            local vA = idxA or a.defaultIdx or 999
            local vB = idxB or b.defaultIdx or 999
            if vA == vB then return tostring(a.idStr) < tostring(b.idStr) end
            return vA < vB
        end)
        return sorted
    end
    
    local eList = GetSortedList(CDMod.Sandbox.scannedEssential, "Essential"); local uList = GetSortedList(CDMod.Sandbox.scannedUtility, "Utility"); local dList = GetSortedList(CDMod.Sandbox.scannedDefensive, "Defensive"); local biList = GetSortedList(CDMod.Sandbox.scannedBuffIcon, "BuffIcon"); local bbList = GetSortedList(CDMod.Sandbox.scannedBuffBar, "BuffBar"); local emList = GetSortedList(CDMod.Sandbox.scannedExtraMonitor, "ExtraMonitor")
    
    local ibList = GetSortedList(CDMod.Sandbox.scannedItemBuff or {}, "ItemBuff")
    if #ibList == 0 then
        table.insert(ibList, { idStr = "dummy_ib", dbKey = "dummy_ib", name = L["Trinket/Potion Buff"] or "饰品/药水增益 (预览)", icon = 134400, defaultIdx = 1, isDummy = true })
    end
    
    CDMod.Sandbox.RenderedLists = { Essential = eList, Utility = uList, Defensive = dList, BuffIcon = biList, BuffBar = bbList, ExtraMonitor = emList, ItemBuff = ibList }

    local function SetupTextHitButton(btn, fontString, textType, rowID, catName)
        local hitBtn = fontString._hitBtn
        if not hitBtn then
            hitBtn = CreateFrame("Button", nil, btn, "BackdropTemplate"); hitBtn:SetFrameLevel(btn:GetFrameLevel() + 10); hitBtn.textObj = fontString
            hitBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); hitBtn:SetBackdropColor(0,0,0,0); hitBtn:SetBackdropBorderColor(0.3,0.8,1,0.5) 
            hitBtn:SetScript("OnClick", function(self) CDMod.Sandbox.popupMode = "TEXT"; CDMod.Sandbox.popupTarget = { row = rowID, type = textType, cat = catName }; WF.UI:RefreshCurrentPanel() end)
            fontString._hitBtn = hitBtn
        end
        hitBtn:ClearAllPoints(); if fontString:GetStringWidth() < 10 then hitBtn:SetSize(16, 16); hitBtn:SetPoint("CENTER", fontString, "CENTER") else hitBtn:SetPoint("TOPLEFT", fontString, "TOPLEFT", -2, 2); hitBtn:SetPoint("BOTTOMRIGHT", fontString, "BOTTOMRIGHT", 2, -2) end; hitBtn:Show()
    end

    local function RenderGroup(list, catCfg, catName, rowID, startY)
        catCfg = catCfg or {}; local w = PixelSnap(catCfg.width or 45); local h = PixelSnap(catCfg.height or 45); local gap = PixelSnap(catCfg.iconGap or 2)
        local isVertical = (catName == "BuffBar") or (catCfg.growth == "DOWN") or (catCfg.growth == "UP"); local barH = PixelSnap(catCfg.barHeight or h); local itemH = math.max(h, barH); local count = #list
        local contentW = (count == 0) and w or (isVertical and w or (count * w + (count - 1) * gap)); local contentH = (count == 0) and itemH or (isVertical and (count * itemH + (count - 1) * gap) or itemH)
        local bgPadding = 2; local needsScroll = not isVertical and (contentW > maxDisplayW)
        local bgW = isVertical and (w + bgPadding*2) or (needsScroll and (maxDisplayW + bgPadding*2) or (contentW + bgPadding*2))
        local bgH = isVertical and (contentH + bgPadding*2) or (itemH + bgPadding*2 + (needsScroll and 18 or 0))
        local verticalOverflow = 40 

        if not canvas.groupBgs then canvas.groupBgs = {} end
        local bg = canvas.groupBgs[rowID]
        if not bg then 
            bg = CreateFrame("Button", nil, canvas, "BackdropTemplate"); WF.UI.Factory.ApplyFlatSkin(bg, 0.1, 0.1, 0.1, 0.3, 0.2, 0.2, 0.2, 0.6); canvas.groupBgs[rowID] = bg 
            bg:SetScript("OnClick", function() CDMod.Sandbox.popupMode = "ROW"; CDMod.Sandbox.popupTarget = rowID; WF.UI:RefreshCurrentPanel() end)
            bg.clip = CreateFrame("Frame", nil, bg); bg.clip:SetClipsChildren(true); bg.container = CreateFrame("Frame", nil, bg.clip)
            bg.slider = CreateFrame("Slider", nil, bg); bg.slider:SetOrientation("HORIZONTAL"); bg.slider:SetObeyStepOnDrag(true)
            local thumb = bg.slider:CreateTexture(nil, "ARTWORK"); thumb:SetColorTexture(1, 0.82, 0, 1); thumb:SetSize(20, 10); bg.slider:SetThumbTexture(thumb)
            bg.slider:SetScript("OnValueChanged", function(self, val) bg.container:ClearAllPoints(); if isVertical then bg.container:SetPoint("TOPLEFT", bg.clip, "TOPLEFT", 0, -verticalOverflow) else bg.container:SetPoint("TOPLEFT", bg.clip, "TOPLEFT", -val, -verticalOverflow) end end)
        end
        bg.catName = catName; bg.rowID = rowID
        local hasTitle = (catName == "ExtraMonitor") or (catName == "ItemBuff") or (string.sub(catName, 1, 9) == "CustomRow") or (string.sub(catName, 1, 13) == "CustomBuffRow")
        local titleSpace = hasTitle and 15 or 0
        bg:ClearAllPoints(); bg:SetSize(bgW, bgH); bg:SetPoint("TOP", canvas, "TOP", 0, startY - titleSpace); bg:Show()
        
        bg.clip:SetClipsChildren(needsScroll); bg.clip:ClearAllPoints(); bg.container:SetSize(contentW, contentH); bg.container:ClearAllPoints()
        if not isVertical then
            bg.clip:SetPoint("TOPLEFT", bg, "TOPLEFT", bgPadding, -bgPadding + verticalOverflow); bg.clip:SetSize(needsScroll and maxDisplayW or contentW, itemH + bgPadding*2 + verticalOverflow*2)
            if needsScroll then bg.slider:Show(); bg.slider:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", bgPadding, bgPadding); bg.slider:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -bgPadding, bgPadding); bg.slider:SetHeight(12); bg.slider:SetMinMaxValues(0, contentW - maxDisplayW); local currVal = math.min(bg.slider:GetValue(), contentW - maxDisplayW); bg.slider:SetValue(currVal); bg.container:SetPoint("TOPLEFT", bg.clip, "TOPLEFT", -currVal, -verticalOverflow) else bg.slider:Hide(); bg.slider:SetValue(0); bg.container:SetPoint("TOPLEFT", bg.clip, "TOPLEFT", 0, -verticalOverflow) end
        else
            bg.clip:SetPoint("TOPLEFT", bg, "TOPLEFT", bgPadding, -bgPadding + verticalOverflow); bg.clip:SetSize(w, contentH + bgPadding*2 + verticalOverflow*2); bg.slider:Hide(); bg.slider:SetValue(0); bg.container:SetPoint("TOPLEFT", bg.clip, "TOPLEFT", 0, -verticalOverflow)
        end
        
        if not bg.titleStr then bg.titleStr = bg:CreateFontString(nil, "OVERLAY"); bg.titleStr:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE"); bg.titleStr:SetPoint("BOTTOMLEFT", bg, "TOPLEFT", 2, 4); bg.titleStr:SetTextColor(0.5, 0.8, 1) end
        if catName == "ExtraMonitor" then bg.titleStr:SetText(L["Extra Monitor"] or "额外监控组"); bg.titleStr:Show() 
        elseif catName == "ItemBuff" then bg.titleStr:SetText(L["Item/Potion Buff"] or "物品/药水持续时间"); bg.titleStr:Show()
        elseif string.sub(catName, 1, 13) == "CustomBuffRow" then bg.titleStr:SetText((L["Custom Buff Group "] or "自定义增益组 ") .. catName); bg.titleStr:Show() 
        elseif string.sub(catName, 1, 9) == "CustomRow" then bg.titleStr:SetText((L["Custom Skill Group "] or "自定义技能组 ") .. catName); bg.titleStr:Show() 
        else bg.titleStr:Hide() end
        if count == 0 then if not bg.emptyTxt then bg.emptyTxt = bg:CreateFontString(nil, "OVERLAY"); bg.emptyTxt:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); bg.emptyTxt:SetPoint("CENTER"); bg.emptyTxt:SetTextColor(0.5, 0.5, 0.5) end; bg.emptyTxt:SetText(L["Click to setup or drag icon here (Empty)"] or "点击设置或拖入图标 (空)"); bg.emptyTxt:Show(); return bgH + titleSpace else if bg.emptyTxt then bg.emptyTxt:Hide() end end
        
        local middleIdx = math.max(1, math.floor((count + 1) / 2))

        for i = 1, count do
            local item = list[i]; local btn = scrollChild.SandboxIconsPool[poolIdx]
            
            if not btn then 
                btn = CreateFrame("Button", nil, canvas)
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                
                btn.texBg = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
                btn.texBg:SetColorTexture(0, 0, 0, 1)
                btn.tex = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
                btn.texBg:SetPoint("TOPLEFT", btn.tex, "TOPLEFT", -1, 1)
                btn.texBg:SetPoint("BOTTOMRIGHT", btn.tex, "BOTTOMRIGHT", 1, -1)
                
                btn.barBg = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
                btn.barBg:SetColorTexture(0, 0, 0, 1)
                btn.barTex = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
                btn.barBg:SetPoint("TOPLEFT", btn.barTex, "TOPLEFT", -1, 1)
                btn.barBg:SetPoint("BOTTOMRIGHT", btn.barTex, "BOTTOMRIGHT", 1, -1)

                btn.mask = btn:CreateTexture(nil, "OVERLAY")
                btn.mask:SetAllPoints(btn.tex)
                btn.mask:SetColorTexture(0, 0, 0, 0.7)
                
                btn.maskIcon = btn:CreateTexture(nil, "OVERLAY")
                btn.maskIcon:SetSize(16, 16)
                btn.maskIcon:SetPoint("CENTER", btn.tex, "CENTER")
                btn.maskIcon:SetTexture("Interface\\AddOns\\WishFlex\\Media\\Icons\\off.tga")
                btn.maskIcon:SetVertexColor(1, 0, 0, 0.8)
                
                btn.qualityIcon = btn:CreateTexture(nil, "OVERLAY", nil, 7)
                btn.qualityIcon:SetSize(16, 16)
                btn.qualityIcon:SetPoint("TOPLEFT", btn.tex, "TOPLEFT", -2, 2)
                btn.qualityIcon:Hide()

                scrollChild.SandboxIconsPool[poolIdx] = btn 
            end
            
            btn:SetParent(bg.container)
            btn.spellID = item.idStr; btn.dbKey = item.dbKey; btn.defaultIdx = item.defaultIdx; btn.catName = catName; btn.rowID = rowID; btn.origCatName = item.origCatName; btn.linkedIDs = item.linkedIDs; btn.isEM = item.isEM; btn.emData = item.emData
            
            if item.isEM and item.emData and item.emData.type == "item" then
                local qID = item.emData.actualID or tonumber(item.idStr) or 0
                local quality = nil
                if C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo then quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(qID) end
                if not quality and C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo then quality = C_TradeSkillUI.GetItemCraftedQualityByItemInfo(qID) end
                if quality then btn.qualityIcon:SetAtlas("Professions-Icon-Quality-Tier" .. quality); btn.qualityIcon:Show() else btn.qualityIcon:Hide() end
            else btn.qualityIcon:Hide() end

            btn:SetScale(1)
            btn:SetSize(w, itemH)
            btn:ClearAllPoints()
            if isVertical then btn:SetPoint("TOP", bg.container, "TOP", 0, (catCfg.growth == "UP") and -(contentH - itemH - (i - 1) * (itemH + gap)) or -(i - 1) * (itemH + gap)) 
            else btn:SetPoint("LEFT", bg.container, "LEFT", (i - 1) * (w + gap), 0) end
            
            btn.tex:SetVertexColor(1, 1, 1, 1); btn.tex:SetTexture(item.icon)
            
            if LCG then
                if not btn.glowAnchor then btn.glowAnchor = CreateFrame("Frame", nil, btn) end
                btn.glowAnchor:ClearAllPoints(); btn.glowAnchor:SetAllPoints(btn.tex); btn.glowAnchor:SetFrameLevel(btn:GetFrameLevel() + 2)
                LCG.PixelGlow_Stop(btn.glowAnchor); LCG.AutoCastGlow_Stop(btn.glowAnchor); LCG.ButtonGlow_Stop(btn.glowAnchor); LCG.ProcGlow_Stop(btn.glowAnchor)
            end

            if catName == "BuffBar" then 
                btn.texBg:Show(); btn.barBg:Show(); btn.barTex:Show()
                local iconPos = catCfg.iconPosition or "LEFT"; local barPos = catCfg.barPosition or "CENTER"; local showIcon = (catCfg.showIcon ~= false)
                local texPath = (LSM and catCfg.barTexture) and LSM:Fetch("statusbar", catCfg.barTexture) or "Interface\\TargetingFrame\\UI-StatusBar"; local barC = catCfg.barColor or {r=0, g=0.8, b=1, a=1}
                btn.barTex:SetTexture(texPath); btn.barTex:SetVertexColor(barC.r, barC.g, barC.b, barC.a or 1)

                if showIcon then 
                    btn.tex:Show(); btn.texBg:Show(); btn.tex:SetScale(1); btn.tex:SetSize(h, h)
                    local actualBarW = math.max(1, w - h - gap); btn.barTex:SetSize(actualBarW, barH) 
                    local iconY, barY
                    if barPos == "TOP" then iconY = itemH - h; barY = itemH - barH elseif barPos == "BOTTOM" then iconY = 0; barY = 0 else iconY = PixelSnap((itemH - h) / 2); barY = PixelSnap((itemH - barH) / 2) end
                    btn.tex:ClearAllPoints(); btn.barTex:ClearAllPoints()
                    if iconPos == "LEFT" then btn.tex:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, iconY); btn.barTex:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", h + gap, barY) 
                    else btn.barTex:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, barY); btn.tex:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", actualBarW + gap, iconY) end
                    ApplySmartTexCoord(btn.tex, h, h)
                else 
                    btn.tex:Hide(); btn.texBg:Hide(); btn.barTex:SetSize(w, barH)
                    local barY; if barPos == "TOP" then barY = itemH - barH elseif barPos == "BOTTOM" then barY = 0 else barY = PixelSnap((itemH - barH) / 2) end
                    btn.barTex:ClearAllPoints(); btn.barTex:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, barY)
                end 
            else 
                btn.tex:Show(); btn.texBg:Show(); btn.barTex:Hide(); btn.barBg:Hide(); btn.tex:SetScale(1); btn.tex:SetSize(w, h); btn.tex:ClearAllPoints(); btn.tex:SetPoint("CENTER", btn, "CENTER", 0, 0); ApplySmartTexCoord(btn.tex, w, h)
            end
            
            local isBlacklisted = db.blacklist and (db.blacklist[item.dbKey] or db.blacklist[item.idStr])
            if isBlacklisted then
                if btn.tex.SetDesaturation then btn.tex:SetDesaturation(1) else btn.tex:SetDesaturated(true) end
                btn.tex:SetVertexColor(0.4, 0.4, 0.4); btn.texBg:SetColorTexture(0.5, 0, 0, 1)
                if catName == "BuffBar" then btn.barTex:SetVertexColor(0.4, 0.4, 0.4, 1) end
                btn.mask:Show(); btn.maskIcon:Show()
            else
                if btn.tex.SetDesaturation then btn.tex:SetDesaturation(0) else btn.tex:SetDesaturated(false) end
                btn.tex:SetVertexColor(1, 1, 1); btn.texBg:SetColorTexture(0, 0, 0, 1)
                if catName == "BuffBar" then local barC = catCfg.barColor or {r=0, g=0.8, b=1, a=1}; btn.barTex:SetVertexColor(barC.r, barC.g, barC.b, barC.a or 1) end
                btn.mask:Hide(); btn.maskIcon:Hide()
            end

            btn:SetScript("OnEnter", function(self)
                self.texBg:SetColorTexture(1, 0.8, 0, 1)
                self.barBg:SetColorTexture(1, 0.8, 0, 1)
                if self.isDragging then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(item.name, 1, 1, 1)
                if db.blacklist and (db.blacklist[item.dbKey] or db.blacklist[item.idStr]) then GameTooltip:AddLine("|cffaaaaaa" .. (L["(Hidden in UI)"] or "(已在界面中隐藏)") .. "|r", 1, 1, 1) end
                GameTooltip:Show()
            end)
            
            btn:SetScript("OnLeave", function(self)
                local r, g, b = 0, 0, 0
                if db.blacklist and (db.blacklist[item.dbKey] or db.blacklist[item.idStr]) then r = 0.5 end
                self.texBg:SetColorTexture(r, g, b, 1); self.barBg:SetColorTexture(0, 0, 0, 1); GameTooltip:Hide()
            end)

            btn:SetScript("OnClick", function(self, button) 
                if self.isDragging then return end
                if self.catName == "ItemBuff" and button == "RightButton" then return end 
                if button == "RightButton" then 
                    if CDMod.Menu and CDMod.Menu.ShowRightClickMenu then
                        CDMod.Menu:ShowRightClickMenu(self, item.idStr, item.name, catName, item.emData, function() 
                            ScanForSandbox(); DrawSandboxToUI(); WF.UI:RefreshCurrentPanel()
                        end)
                    end
                else 
                    CDMod.Sandbox.popupMode = "ROW"; CDMod.Sandbox.popupTarget = self.rowID; WF.UI:RefreshCurrentPanel()
                end
            end)
            
            btn:RegisterForDrag("LeftButton")
            btn:SetScript("OnDragStart", function(self) 
                if self.catName == "ItemBuff" then return end
                self.isDragging = true; self.origFrameLevel = self:GetFrameLevel() or 1; self:SetFrameLevel(math.min(65535, self.origFrameLevel + 50)); local cx, cy = GetCursorPosition(); local uiScale = self:GetEffectiveScale(); self.cursorStartX = cx / uiScale; self.cursorStartY = cy / uiScale; local p, rt, rp, x, y = self:GetPoint(); self.origP, self.origRT, self.origRP = p, rt, rp; self.startX, self.startY = x, y
                local isCombatOrEMS = IsCombatCD(self.catName) or self.catName == "ExtraMonitor"
                self:SetScript("OnUpdate", function(s) 
                    local ncx, ncy = GetCursorPosition(); ncx, ncy = ncx / uiScale, ncy / uiScale; s:ClearAllPoints(); s:SetPoint(s.origP, s.origRT, s.origRP, s.startX + (ncx - s.cursorStartX), s.startY + (ncy - s.cursorStartY)); local ind = scrollChild.CD_Sandbox_DropIndicator; local scx, scy = s:GetCenter(); if not scx or not scy then return end
                    local targetBg = nil
                    for _, cBg in pairs(canvas.groupBgs) do 
                        if cBg:IsShown() and cBg.catName ~= "CustomEffects" and cBg.catName ~= "ItemBuff" then 
                            local isCombatOrEMBg = IsCombatCD(cBg.catName) or cBg.catName == "ExtraMonitor"
                            if (isCombatOrEMS and isCombatOrEMBg) or (IsBuffCat(s.catName) and IsBuffCat(cBg.catName)) then 
                                local cl, cb, cw, ch = cBg:GetRect(); if cl and cb and scx >= cl - 10 and scx <= cl + cw + 10 and scy >= cb - 10 and scy <= cb + ch + 10 then targetBg = cBg; break end 
                            end 
                        end 
                    end
                    local minDist = 9999; local closestBtn = nil
                    for j = 1, #scrollChild.SandboxIconsPool do 
                        local other = scrollChild.SandboxIconsPool[j]; 
                        if other:IsShown() and other ~= s and other.catName ~= "CustomEffects" and other.catName ~= "ItemBuff" then 
                            local isCombatOrEMOther = IsCombatCD(other.catName) or other.catName == "ExtraMonitor"
                            if (isCombatOrEMS and isCombatOrEMOther) or (IsBuffCat(s.catName) and IsBuffCat(other.catName)) then 
                                if not (targetBg and other.catName ~= targetBg.catName) then 
                                    local ox, oy = other:GetCenter(); if ox and oy then local dist = math.sqrt((scx - ox)^2 + (scy - oy)^2); if dist < minDist then minDist = dist; closestBtn = other end end 
                                end 
                            end 
                        end 
                    end
                    if closestBtn and minDist < 45 then 
                        local ox, oy = closestBtn:GetCenter(); s.dropTarget = closestBtn; s.dropMode = "btn"; 
                        local isVerticalTarget = (closestBtn.catName == "BuffBar" or (db[closestBtn.catName] and (db[closestBtn.catName].growth == "DOWN" or db[closestBtn.catName].growth == "UP")))
                        if isVerticalTarget then s.dropModeDir = (scy > oy) and ((db[closestBtn.catName].growth == "UP") and "after" or "before") or ((db[closestBtn.catName].growth == "UP") and "before" or "after") else s.dropModeDir = (scx < ox) and "before" or "after" end; 
                        ind:ClearAllPoints(); ind:SetParent(closestBtn:GetParent()); ind:SetFrameLevel(math.min(65535, closestBtn:GetFrameLevel() + 5)); ind.tex:SetColorTexture(0, 1, 0, 1); 
                        if isVerticalTarget then ind:SetSize(closestBtn:GetWidth() + 10, 4); if scy > oy then ind:SetPoint("BOTTOM", closestBtn, "TOP", 0, 2) else ind:SetPoint("TOP", closestBtn, "BOTTOM", 0, -2) end else ind:SetSize(4, closestBtn:GetHeight() + 10); if s.dropModeDir == "before" then ind:SetPoint("RIGHT", closestBtn, "LEFT", -2, 0) else ind:SetPoint("LEFT", closestBtn, "RIGHT", 2, 0) end end; 
                        ind:Show() 
                    elseif targetBg then s.dropTarget = targetBg; s.dropMode = "bg"; ind:ClearAllPoints(); ind:SetParent(targetBg.clip); ind:SetFrameLevel(math.min(65535, targetBg.clip:GetFrameLevel() + 2)); ind:SetAllPoints(targetBg.clip); ind.tex:SetColorTexture(0, 1, 0, 0.2); ind:Show() 
                    else ind:Hide(); s.dropTarget = nil end
                end)
            end)
            btn:SetScript("OnDragStop", function(self) 
                self.isDragging = false; self:SetScript("OnUpdate", nil); self:SetFrameLevel(math.max(1, math.min(65535, self.origFrameLevel or 1))); if scrollChild.CD_Sandbox_DropIndicator then scrollChild.CD_Sandbox_DropIndicator:Hide() end
                if self.dropTarget then
                    local srcCat = self.catName; local tgtCat = self.dropTarget.catName; local srcList = CDMod.Sandbox.RenderedLists[srcCat]; local tgtList = CDMod.Sandbox.RenderedLists[tgtCat]
                    if srcList and tgtList then 
                        local myIdx; for idx, v in ipairs(srcList) do if v.dbKey == self.dbKey then myIdx = idx; break end end
                        if myIdx then 
                            local myItem = table.remove(srcList, myIdx); 
                            if self.dropMode == "bg" then table.insert(tgtList, #tgtList + 1, myItem) else local targetIdx = 0; for idx, v in ipairs(tgtList) do if v.dbKey == self.dropTarget.dbKey then targetIdx = idx; break end end; if self.dropModeDir == "after" then table.insert(tgtList, targetIdx + 1, myItem) else table.insert(tgtList, targetIdx > 0 and targetIdx or 1, myItem) end end
                            
                            local dbO = db.spellOverrides; if not dbO then dbO = {}; db.spellOverrides = dbO end; 
                            local function SyncSave(vData, key, val) 
                                local idStr = tostring(vData.idStr)
                                if vData.dbKey then 
                                    if not dbO[vData.dbKey] then dbO[vData.dbKey] = {} end
                                    dbO[vData.dbKey][key] = val 
                                else
                                    if not dbO[idStr] then dbO[idStr] = {} end
                                    dbO[idStr][key] = val
                                end
                                
                                if vData.linkedIDs then 
                                    for j = 1, #vData.linkedIDs do 
                                        local lid = tostring(vData.linkedIDs[j])
                                        local prefix = vData.dbKey and string.match(vData.dbKey, "^([A-Za-z]+)_")
                                        if prefix then
                                            local lidKey = prefix .. "_" .. lid; if not dbO[lidKey] then dbO[lidKey] = {} end; dbO[lidKey][key] = val
                                        else
                                            if not dbO[lid] then dbO[lid] = {} end; dbO[lid][key] = val 
                                        end
                                    end 
                                end 
                            end
                            
                            if srcCat ~= tgtCat then SyncSave(myItem, "category", tgtCat) end
                            for idx, v in ipairs(tgtList) do SyncSave(v, "sortIndex", idx) end
                            if srcCat ~= tgtCat then for idx, v in ipairs(srcList) do SyncSave(v, "sortIndex", idx) end end 
                            
                            if db.blacklist then
                                db.blacklist[myItem.dbKey] = nil
                                db.blacklist[myItem.idStr] = nil
                                db.blacklist[tostring(myItem.idStr)] = nil
                            end
                        end
                    end
                end
                
                self:ClearAllPoints()
                if CDMod.InvalidateHiddenCache then CDMod:InvalidateHiddenCache() end
                if CDMod.MarkLayoutDirty then CDMod:MarkLayoutDirty(true) end

                ScanForSandbox()
                if WF.UI.MainScrollChild and WF.UI.MainScrollChild.CD_Sandbox_Canvas then 
                    DrawSandboxToUI(maxDisplayW + 30) 
                else 
                    if WF.UI.RefreshCurrentPanel then WF.UI:RefreshCurrentPanel() end 
                end
            end)
            
            if i == middleIdx then 
                if not btn.mockCd then btn.mockCd = btn:CreateFontString(nil, "OVERLAY", nil, 7); btn.mockStack = btn:CreateFontString(nil, "OVERLAY", nil, 7) end
                local fontPath = (LSM and LSM:Fetch('font', db.countFont)) or STANDARD_TEXT_FONT
                
                btn.mockCd:SetFont(fontPath, catCfg.cdFontSize or 18, "OUTLINE")
                
                -- 【核心修复】：应用用户设置的颜色，如果没有配置则给一个默认值
                local cdC = catCfg.cdFontColor or {r=1, g=0.82, b=0, a=1}; 
                if catName == "ItemBuff" then 
                    cdC = catCfg.cdFontColor or {r=0, g=1, b=0, a=1} -- 如果用户没选过，默认给绿色
                end 
                btn.mockCd:SetTextColor(cdC.r, cdC.g, cdC.b, cdC.a or 1); btn.mockCd:ClearAllPoints()
                
                local textRefCD = btn; local textRefStack = btn
                if catName == "BuffBar" then if catCfg.showIcon ~= false then textRefCD = btn.barTex; textRefStack = btn.tex else textRefCD = btn.barTex; textRefStack = btn.barTex end else textRefCD = btn.tex; textRefStack = btn.tex end
                local cdPos = catCfg.cdPosition or "CENTER"
                btn.mockCd:SetPoint(cdPos, textRefCD, cdPos, catCfg.cdXOffset or 0, catCfg.cdYOffset or 0); btn.mockCd:SetJustifyH(GetSafeJustify(cdPos)); btn.mockCd:SetText("12")
                
                btn.mockStack:SetFont(fontPath, catCfg.stackFontSize or 14, "OUTLINE")
                local stC = catCfg.stackFontColor or {r=1, g=1, b=1, a=1}; btn.mockStack:SetTextColor(stC.r, stC.g, stC.b, stC.a or 1); btn.mockStack:ClearAllPoints()
                local stPos = catCfg.stackPosition or "BOTTOMRIGHT"
                btn.mockStack:SetPoint(stPos, textRefStack, stPos, catCfg.stackXOffset or 0, catCfg.stackYOffset or 0); btn.mockStack:SetJustifyH(GetSafeJustify(stPos)); btn.mockStack:SetText("3")
                
                SetupTextHitButton(btn, btn.mockCd, "CD", btn.rowID, btn.catName); SetupTextHitButton(btn, btn.mockStack, "STACK", btn.rowID, btn.catName)
                btn.mockCd:Show(); btn.mockStack:Show(); btn.mockCd._hitBtn:Show(); btn.mockStack._hitBtn:Show()
            else 
                if btn.mockCd then btn.mockCd:Hide(); btn.mockStack:Hide(); btn.mockCd._hitBtn:Hide(); btn.mockStack._hitBtn:Hide() end 
            end
            btn:Show(); poolIdx = poolIdx + 1
        end
        return bgH + titleSpace
    end

    local currentY = -15
    if db.CustomBuffRows then for _, r in ipairs(db.CustomBuffRows) do local cList = GetSortedList(CDMod.Sandbox["scanned"..r] or {}, r); CDMod.Sandbox.RenderedLists[r] = cList; currentY = currentY - RenderGroup(cList, db[r] or {}, r, r, currentY) - 12 end end
    if #bbList > 0 then currentY = currentY - RenderGroup(bbList, db.BuffBar or {}, "BuffBar", "BuffBar", currentY) - 12 end
    currentY = currentY - RenderGroup(biList, db.BuffIcon or {}, "BuffIcon", "BuffIcon", currentY) - 12
    currentY = currentY - RenderGroup(ibList, db.ItemBuff or {}, "ItemBuff", "ItemBuff", currentY) - 12 
    
    currentY = currentY - RenderGroup(eList, db.Essential or {}, "Essential", "Essential", currentY) - 12
    currentY = currentY - RenderGroup(uList, db.Utility or {}, "Utility", "Utility", currentY) - 12
    currentY = currentY - RenderGroup(dList, db.Defensive or {}, "Defensive", "Defensive", currentY) - 12
    if db.CustomRows then for _, r in ipairs(db.CustomRows) do local cList = GetSortedList(CDMod.Sandbox["scanned"..r] or {}, r); CDMod.Sandbox.RenderedLists[r] = cList; currentY = currentY - RenderGroup(cList, db[r] or {}, r, r, currentY) - 12 end end
    
    local cH_em = RenderGroup(emList, db.ExtraMonitor or {}, "ExtraMonitor", "ExtraMonitor", currentY)
    currentY = currentY - cH_em - 12

    local btnAddRow = scrollChild.CD_Sandbox_BtnAddRow
    if not btnAddRow then
        btnAddRow = WF.UI.Factory:CreateFlatButton(scrollChild, L["Add Custom Skill Group"] or "新增自定义技能组", function()
            if not db.CustomRows then db.CustomRows = {} end
            local newId = "CustomRow_" .. math.floor(GetTime() * 1000) .. math.random(10, 99)
            table.insert(db.CustomRows, newId)
            db[newId] = { width = 40, height = 40, iconGap = 1, cdFontSize = 18, cdFontColor = {r=1,g=0.82,b=0}, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = {r=1,g=1,b=1}, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 }
            CDMod:MarkLayoutDirty(true); WF.UI:RefreshCurrentPanel() 
        end)
        scrollChild.CD_Sandbox_BtnAddRow = btnAddRow
    end
    btnAddRow:ClearAllPoints(); btnAddRow:SetParent(canvas); btnAddRow:SetPoint("TOP", canvas, "TOP", -110, currentY - 5); btnAddRow:SetWidth(180); btnAddRow:Show()

    local btnAddBuffRow = scrollChild.CD_Sandbox_BtnAddBuffRow
    if not btnAddBuffRow then
        btnAddBuffRow = WF.UI.Factory:CreateFlatButton(scrollChild, L["Add Custom Buff Group"] or "新增自定义增益组", function()
            if not db.CustomBuffRows then db.CustomBuffRows = {} end
            local newId = "CustomBuffRow_" .. math.floor(GetTime() * 1000) .. math.random(10, 99)
            table.insert(db.CustomBuffRows, newId)
            db[newId] = { width = 40, height = 40, iconGap = 1, growth = "CENTER_HORIZONTAL", cdFontSize = 18, cdFontColor = {r=1,g=0.82,b=0}, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = {r=1,g=1,b=1}, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 }
            CDMod:MarkLayoutDirty(true); WF.UI:RefreshCurrentPanel() 
        end)
        scrollChild.CD_Sandbox_BtnAddBuffRow = btnAddBuffRow
    end
    btnAddBuffRow:ClearAllPoints(); btnAddBuffRow:SetParent(canvas); btnAddBuffRow:SetPoint("TOP", canvas, "TOP", 110, currentY - 5); btnAddBuffRow:SetWidth(180); btnAddBuffRow:Show()
    
    currentY = currentY - 45

    canvas:SetScale(1); canvas:ClearAllPoints(); canvas:SetPoint("TOP", previewBox, "TOP", 0, 0)
    return math.abs(currentY)
end

if not WF.UI.MenuRegistered_CDCustom then
    WF.UI:RegisterMenu({ id = "Combat", name = L["Combat"] or "战斗组件", type = "root", icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\zd", order = 10 })
    WF.UI:RegisterMenu({ id = "CDManager", parent = "Combat", name = L["Cooldown Manager"] or "冷却排版管理", key = "cooldownCustom_Global", order = 20 })
    WF.UI.MenuRegistered_CDCustom = true
end

local function HandleCDChange(val) 
    if CDMod.InvalidateHiddenCache then CDMod:InvalidateHiddenCache() end
    if WF.TriggerCooldownLayout then WF.TriggerCooldownLayout() end
    
    if type(val) == "string" and val == "UI_REFRESH" then WF.UI:RefreshCurrentPanel() 
    else if WF.UI.MainScrollChild and WF.UI.MainScrollChild.CD_Sandbox_Canvas then DrawSandboxToUI(850) end end
end

local origRefresh = WF.UI.RefreshCurrentPanel
WF.UI.RefreshCurrentPanel = function(self)
    if WF.UI.SandboxMenu then WF.UI.SandboxMenu:Hide() end
    if self.CurrentNodeKey ~= "cooldownCustom_Global" and WF.UI.CDPopup then WF.UI.CDPopup:Hide() end
    origRefresh(self)
end

WF.UI:RegisterPanel("cooldownCustom_Global", function(scrollChild, ColW)
    local db = WF.db.cooldownCustom or {}; if not db.Essential then db.Essential = {} end; if not db.Utility then db.Utility = {} end; if not db.Defensive then db.Defensive = {} end; if not db.BuffIcon then db.BuffIcon = {} end; if not db.BuffBar then db.BuffBar = {} end
    if not db.ExtraMonitor then db.ExtraMonitor = {} end; if not db.ItemBuff then db.ItemBuff = {} end
    
    WF.UI.MainScrollChild = scrollChild; local targetWidth = 900; local ColW = targetWidth - 40; local currentY = -10 

    local isEnabled = WF.db.cooldownCustom.enable ~= false

    local btnToggle = scrollChild.CD_BtnToggleEnable
    if not btnToggle then
        btnToggle = WF.UI.Factory:CreateFlatButton(scrollChild, "", nil)
        scrollChild.CD_BtnToggleEnable = btnToggle
    end
    btnToggle:SetScript("OnClick", function()
        local newState = not (WF.db.cooldownCustom.enable ~= false)
        WF.db.cooldownCustom.enable = newState
        if not WF.db.extraMonitor then WF.db.extraMonitor = {} end
        WF.db.extraMonitor.enable = newState 
        WF.UI:ShowReloadPopup()
        WF.UI:RefreshCurrentPanel()
    end)
    local toggleText = isEnabled and (L["Disable CD & EM"] or "|cffff5555关闭冷却管理器|r") or (L["Enable CD & EM"] or "|cff55ff55启用冷却管理器|r")
    for i=1, btnToggle:GetNumRegions() do local reg = select(i, btnToggle:GetRegions()); if reg:IsObjectType("FontString") then reg:SetText(toggleText); break end end

    local btnGlobal = scrollChild.CD_BtnGlobal
    if not btnGlobal then
        btnGlobal = WF.UI.Factory:CreateFlatButton(scrollChild, L["Global Layout & Settings"] or "全局排版设置", nil)
        scrollChild.CD_BtnGlobal = btnGlobal
    end
    btnGlobal:SetScript("OnClick", function() CDMod.Sandbox.popupMode = "GLOBAL"; WF.UI:RefreshCurrentPanel() end)
    
    local btnScan = scrollChild.CD_ScanBtn
    if not btnScan then
        btnScan = WF.UI.Factory:CreateFlatButton(scrollChild, L["Refresh Sandbox / Fetch Data"] or "刷新沙盒/抓取当前数据", nil)
        scrollChild.CD_ScanBtn = btnScan
    end
    btnScan:SetScript("OnClick", function() ScanForSandbox(); WF.UI:RefreshCurrentPanel() end)

    local btnHelp = scrollChild.CD_BtnHelp
    if not btnHelp then
        btnHelp = WF.UI.Factory:CreateFlatButton(scrollChild, L["Operation Guide"] or "操作指南", nil)
        scrollChild.CD_BtnHelp = btnHelp
    end
    btnHelp:SetScript("OnEnter", function(self) 
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); 
        GameTooltip:SetText(L["Sandbox Operation Guide"] or "【沙盒操作指南】", 1, 0.82, 0); 
        GameTooltip:AddLine("|cff00ff00[" .. (L["Left Click"] or "左键") .. "]|r " .. (L["Click group background or icon to setup layout"] or "点击组背景或图标：设置该组排版"), 1, 1, 1); 
        GameTooltip:AddLine("|cff00ff00[" .. (L["Left Click"] or "左键") .. "]|r " .. (L["Click number text to adjust font and offset"] or "点击数字文本：调整字体与偏移"), 1, 1, 1); 
        GameTooltip:AddLine("|cffffaa00[" .. (L["Right Click"] or "右键") .. "]|r " .. (L["Click icon to open toggle and style menu"] or "点击图标：呼出开关与样式菜单"), 1, 1, 1); 
        GameTooltip:AddLine("|cff00ccff[" .. (L["Drag"] or "拖拽") .. "]|r " .. (L["Hold left click to reorder icons within same group type"] or "左键按住图标：同类组间自由排列"), 1, 1, 1); 
        GameTooltip:Show() 
    end); btnHelp:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btnToggle:SetParent(scrollChild); btnToggle:ClearAllPoints(); btnToggle:SetPoint("TOPLEFT", 15, currentY); btnToggle:SetWidth(160); btnToggle:Show()

    if not isEnabled then
        if scrollChild.CD_Sandbox_Box then scrollChild.CD_Sandbox_Box:Hide() end
        btnGlobal:Hide(); btnScan:Hide(); btnHelp:Hide()
        
        local dMsg = scrollChild.CD_DisabledMsg
        if not dMsg then dMsg = scrollChild:CreateFontString(nil, "OVERLAY"); dMsg:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE"); dMsg:SetTextColor(0.6, 0.6, 0.6); dMsg:SetJustifyH("LEFT"); scrollChild.CD_DisabledMsg = dMsg end
        dMsg:SetPoint("TOPLEFT", btnToggle, "BOTTOMLEFT", 0, -50)
        dMsg:SetText(L["CD System Disabled Msg"] or "冷却管理器已关闭 \n\n- 系统底层挂载已完全熔断断流。\n- 内存占用与渲染循环已清空释放。\n- 排版沙盒与多余设置项已隐藏。\n\n如需使用，请点击上方【启用】按钮并重载界面。")
        dMsg:Show()
        return -(math.abs(currentY) + 200), targetWidth
    end

    if scrollChild.CD_DisabledMsg then scrollChild.CD_DisabledMsg:Hide() end

    btnGlobal:SetParent(scrollChild); btnGlobal:ClearAllPoints(); btnGlobal:SetPoint("LEFT", btnToggle, "RIGHT", 10, 0); btnGlobal:Show()
    btnScan:SetParent(scrollChild); btnScan:ClearAllPoints(); btnScan:SetPoint("LEFT", btnGlobal, "RIGHT", 10, 0); btnScan:SetWidth(200); btnScan:Show()
    btnHelp:SetParent(scrollChild); btnHelp:ClearAllPoints(); btnHelp:SetPoint("LEFT", btnScan, "RIGHT", 10, 0); btnHelp:SetWidth(120); btnHelp:Show()

    currentY = currentY - 35
    local previewBox = scrollChild.CD_Sandbox_Box or CreateFrame("Frame", nil, scrollChild, "BackdropTemplate"); previewBox:SetPoint("TOPLEFT", 15, currentY); WF.UI.Factory.ApplyFlatSkin(previewBox, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); previewBox:Show(); scrollChild.CD_Sandbox_Box = previewBox
    local bgClick = scrollChild.CD_Sandbox_BgClick or CreateFrame("Button", nil, previewBox); scrollChild.CD_Sandbox_BgClick = bgClick; bgClick:SetAllPoints(); bgClick:SetFrameLevel(previewBox:GetFrameLevel()); bgClick:SetScript("OnClick", function() if CDMod.Sandbox.popupMode then CDMod.Sandbox.popupMode = nil; WF.UI:RefreshCurrentPanel() end end)
    local canvas = scrollChild.CD_Sandbox_Canvas or CreateFrame("Frame", nil, previewBox); canvas:SetPoint("TOP", previewBox, "TOP", 0, 0); scrollChild.CD_Sandbox_Canvas = canvas
    if not scrollChild.SandboxIconsPool then scrollChild.SandboxIconsPool = {} end
    
    ScanForSandbox(); local sandboxH = DrawSandboxToUI(ColW) or 350
    local previewHeight = math.max(350, sandboxH + 30)
    previewBox:SetSize(ColW, previewHeight); canvas:SetSize(ColW, previewHeight)
    currentY = currentY - previewHeight - 15

    if CDMod.Sandbox.popupMode and CDMod.Menu and CDMod.Menu.GetPopup then
        local popup = CDMod.Menu:GetPopup()
        CDMod.Menu:RenderPopupContent(popup, CDMod.Sandbox.popupMode, CDMod.Sandbox.popupTarget, db, HandleCDChange, function()
            ScanForSandbox(); DrawSandboxToUI(ColW); WF.UI:RefreshCurrentPanel()
        end)
    else
        if WF.UI.CDPopup then WF.UI.CDPopup:Hide() end
    end

    return -(math.abs(currentY)), targetWidth
end)