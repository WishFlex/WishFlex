local AddonName, ns = ...
local WF = _G.WishFlex
local L = WF.L
local CR = WF.ClassResourceAPI
if not CR then return end

local LSM = LibStub("LibSharedMedia-3.0", true)
local math_floor, math_abs, math_max, math_min = math.floor, math.abs, math.max, math.min
local tostring, type = tostring, type
local UnitPowerType, UnitClass, GetSpecializationInfo = UnitPowerType, UnitClass, GetSpecializationInfo
local _, playerClass = UnitClass("player")
local ClassColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass] or {r=1, g=1, b=1}
local C_R, C_G, C_B = ClassColor.r, ClassColor.g, ClassColor.b

CR.Sandbox = CR.Sandbox or { popupMode = nil, popupTarget = nil, previewGap = 1 }

WF.UI:RegisterMenu({ id = "ClassResource", parent = "Combat", name = L["Class Resource"] or "职业资源与监控", key = "classResource_Global", order = 25 })

if WF.UI and WF.UI.MainFrame and not WF.UI.MainFrame._cr_onhide_hooked then
    WF.UI.MainFrame:HookScript("OnHide", function()
        if CR.ClearMonitors then CR:ClearMonitors() end
        if WF.WishMonitorAPI and type(WF.WishMonitorAPI.stateCache) == "table" then wipe(WF.WishMonitorAPI.stateCache) end
        if CR.RenderMonitors then pcall(function() CR:RenderMonitors({}, WF.db.wishMonitor or {}) end) end
        if WF.WishMonitorAPI and WF.WishMonitorAPI.TriggerUpdate then C_Timer.After(0.1, function() WF.WishMonitorAPI:TriggerUpdate() end) end
    end)
    WF.UI.MainFrame._cr_onhide_hooked = true
end

local function GetOnePixelSize()
    local screenHeight = select(2, GetPhysicalScreenSize()); if not screenHeight or screenHeight == 0 then return 1 end
    local uiScale = UIParent:GetEffectiveScale(); if not uiScale or uiScale == 0 then return 1 end
    return 768.0 / screenHeight / uiScale
end

local function PixelSnap(value)
    if not value then return 0 end
    local onePixel = GetOnePixelSize(); if onePixel == 0 then return value end
    return math_floor(value / onePixel + 0.5) * onePixel
end

local function GetSafeJustify(anchorStr)
    if type(anchorStr) ~= "string" then return "CENTER" end
    if string.match(anchorStr, "LEFT") then return "LEFT" elseif string.match(anchorStr, "RIGHT") then return "RIGHT" else return "CENTER" end
end

local function GetSandboxCDWidth()
    local dbCR = CR.GetDB(); if not dbCR.alignWithCD then return nil end
    if _G.EssentialCooldownViewer then local viewerW = _G.EssentialCooldownViewer:GetWidth(); if viewerW and viewerW > 10 then local calc = viewerW + (tonumber(dbCR.widthOffset) or 0); dbCR.lastKnownCDWidth = calc; return calc end end
    local cdDB = WF.db.cooldownCustom and WF.db.cooldownCustom.Essential; if not cdDB then return nil end
    local w = tonumber(cdDB.width) or 45; local gap = tonumber(cdDB.iconGap) or 2; local maxRow = tonumber(cdDB.maxPerRow) or 7; local actualCount = 0
    if WF.CooldownCustomAPI and WF.CooldownCustomAPI.Sandbox and WF.CooldownCustomAPI.Sandbox.RenderedLists then local list = WF.CooldownCustomAPI.Sandbox.RenderedLists["Essential"]; if list then actualCount = #list end else if _G.EssentialCooldownViewer and _G.EssentialCooldownViewer.itemFramePool then for f in _G.EssentialCooldownViewer.itemFramePool:EnumerateActive() do if f:IsShown() and not f._wishFlexHidden then actualCount = actualCount + 1 end end end end
    if actualCount > 0 then local renderCount = math_min(actualCount, maxRow); local calcW = (renderCount * w) + ((renderCount - 1) * gap) + (tonumber(dbCR.widthOffset) or 0); dbCR.lastKnownCDWidth = calcW; return calcW
    else return dbCR.lastKnownCDWidth or ((maxRow * w) + ((maxRow - 1) * gap) + (tonumber(dbCR.widthOffset) or 0)) end
end

local function SetupTextHitButton(btn, fontString, barKey)
    local hitBtn = fontString._hitBtn
    if not hitBtn then
        hitBtn = CreateFrame("Button", nil, fontString:GetParent(), "BackdropTemplate"); hitBtn:SetFrameLevel(fontString:GetParent():GetFrameLevel() + 5); fontString:SetDrawLayer("OVERLAY", 7) 
        hitBtn:SetBackdrop({ bgFile = nil, edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); hitBtn:SetBackdropBorderColor(1, 0.8, 0, 0.2)
        hitBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.3, 0.8, 1, 1); GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("|cff00ff00[" .. (L["Left Click"] or "左键") .. "]|r " .. (L["Edit text layout"] or "编辑该文本专属排版"), 1, 1, 1); GameTooltip:Show() end)
        hitBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(1, 0.8, 0, 0.2); GameTooltip:Hide() end)
        hitBtn:SetScript("OnClick", function(self)
            if string.sub(self.barKey, 1, 3) == "WM_" then
                CR.Sandbox.popupMode = "EDIT_MONITOR_TEXT"; CR.Sandbox.editMonitorID = string.sub(self.barKey, 4)
                local wmDB = WF.db.wishMonitor; CR.Sandbox.editMonitorCat = (wmDB.skills and wmDB.skills[CR.Sandbox.editMonitorID]) and "skill" or "buff"; WF.UI:RefreshCurrentPanel()
            else
                CR.Sandbox.popupMode = "TEXT"; CR.Sandbox.popupTarget = self.barKey; if WF.UI.GroupState then WF.UI.GroupState["sb_txt_"..self.barKey] = true end; WF.UI:RefreshCurrentPanel()
            end
        end)
        fontString._hitBtn = hitBtn
    end
    hitBtn.barKey = barKey; hitBtn:ClearAllPoints(); hitBtn:SetPoint("TOPLEFT", fontString, "TOPLEFT", -4, 2); hitBtn:SetPoint("BOTTOMRIGHT", fontString, "BOTTOMRIGHT", 4, -2)
    if fontString:GetStringWidth() < 10 then hitBtn:SetSize(40, 20); hitBtn:SetPoint("CENTER", fontString, "CENTER") end; hitBtn:Show()
end

local origRefresh = WF.UI.RefreshCurrentPanel
WF.UI.RefreshCurrentPanel = function(self) if self.CurrentNodeKey ~= "classResource_Global" and WF.UI.CRPopup then WF.UI.CRPopup:Hide() end; origRefresh(self) end

WF.UI:RegisterPanel("classResource_Global", function(scrollChild, ColW)
    local db = CR.GetDB()
    if not db._spacingForced1 then db.alignYOffset = 1; db.spacing = 1; for _, specCfg in pairs(db.specConfigs or {}) do if type(specCfg) == "table" then specCfg.yOffset = 1 end end; db._spacingForced1 = true end
    local tempDB = { spec = CR.selectedSpecForConfig or CR.GetCurrentContextID() }; local specCfg = CR.GetCurrentSpecConfig(tempDB.spec); local wmDB = WF.db.wishMonitor or {}

    local seenInSortLocal = {}; local cleanedSortOrder = {}
    for _, k in ipairs(db.sortOrder) do
        if k == "mana" and not CR.hasHealerSpec then
        elseif k == "WM_48518" then
        elseif string.sub(k, 1, 3) == "WM_" then
            local spellID = string.sub(k, 4)
            if (wmDB.skills and wmDB.skills[spellID]) or (wmDB.buffs and wmDB.buffs[spellID]) then if not seenInSortLocal[k] then table.insert(cleanedSortOrder, k); seenInSortLocal[k] = true end end
        else 
            if not seenInSortLocal[k] then table.insert(cleanedSortOrder, k); seenInSortLocal[k] = true end 
        end
    end
    for spellID, _ in pairs(wmDB.skills or {}) do local k = "WM_"..spellID; if k ~= "WM_48518" and not seenInSortLocal[k] then table.insert(cleanedSortOrder, 1, k); seenInSortLocal[k] = true end end
    for spellID, _ in pairs(wmDB.buffs or {}) do local k = "WM_"..spellID; if k ~= "WM_48518" and not seenInSortLocal[k] then table.insert(cleanedSortOrder, 1, k); seenInSortLocal[k] = true end end
    
    db.sortOrder = cleanedSortOrder

    local targetWidth = 1000; local ColW = targetWidth - 40; local currentY = -10
    local function SafeLayoutChange() CR:UpdateLayout(); if WF.WishMonitorAPI and WF.WishMonitorAPI.TriggerUpdate then WF.WishMonitorAPI:TriggerUpdate() end end
    local function HandleCRChange(val) SafeLayoutChange(); if type(val) == "string" then WF.UI:RefreshCurrentPanel() else if CR.Sandbox.RenderPreview then CR.Sandbox.RenderPreview() end end end

    local isEnabled = db.enable ~= false

    local btnToggle = scrollChild.CR_BtnToggleEnable
    if not btnToggle then
        btnToggle = WF.UI.Factory:CreateFlatButton(scrollChild, "", nil)
        scrollChild.CR_BtnToggleEnable = btnToggle
    end
    btnToggle:SetScript("OnClick", function()
        local newState = not (db.enable ~= false)
        db.enable = newState
        if not WF.db.wishMonitor then WF.db.wishMonitor = {} end
        WF.db.wishMonitor.enable = newState
        WF.UI:ShowReloadPopup()
        WF.UI:RefreshCurrentPanel()
    end)
    local toggleText = isEnabled and (L["Disable CR & Monitor"] or "|cffff5555关闭资源条|r") or (L["Enable CR & Monitor"] or "|cff55ff55启用资源条|r")
    for i=1, btnToggle:GetNumRegions() do local reg = select(i, btnToggle:GetRegions()); if reg:IsObjectType("FontString") then reg:SetText(toggleText); break end end

    local btnGlobal = scrollChild.CR_BtnGlobal
    if not btnGlobal then
        btnGlobal = WF.UI.Factory:CreateFlatButton(scrollChild, L["Global Layout & Settings"] or "全局排版设置", nil)
        scrollChild.CR_BtnGlobal = btnGlobal
    end
    btnGlobal:SetScript("OnClick", function() CR.Sandbox.popupMode = "GLOBAL"; WF.UI:RefreshCurrentPanel() end)
    
    local btnScan = scrollChild.CR_ScanBtn
    if not btnScan then
        btnScan = WF.UI.Factory:CreateFlatButton(scrollChild, L["Refresh Sandbox / Fetch Data"] or "刷新沙盒/抓取当前数据", nil)
        scrollChild.CR_ScanBtn = btnScan
    end
    btnScan:SetScript("OnClick", function() WF.UI:RefreshCurrentPanel() end)

    local btnHelp = scrollChild.CR_BtnHelp
    if not btnHelp then
        btnHelp = WF.UI.Factory:CreateFlatButton(scrollChild, L["Operation Guide"] or "操作指南", nil)
        scrollChild.CR_BtnHelp = btnHelp
    end
    btnHelp:SetScript("OnEnter", function(self) 
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); 
        GameTooltip:SetText(L["Sandbox Operation Guide"] or "【沙盒操作指南】", 1, 0.82, 0); GameTooltip:AddLine(" "); 
        GameTooltip:AddLine("|cff00ff00[" .. (L["Left Click"] or "左键") .. "]|r " .. (L["Click bar or placeholder to setup size"] or "点击条本身/占位框：设置外观尺寸"), 1, 1, 1); 
        GameTooltip:AddLine("|cff00ff00[" .. (L["Left Click"] or "左键") .. "]|r " .. (L["Click text to setup text layout"] or "点击对应文本：设置文本排版"), 1, 1, 1); 
        GameTooltip:AddLine("|cff00ccff[" .. (L["Drag"] or "拖拽排版") .. "]|r " .. (L["Hold bar to reorder"] or "按住条拖动：插队到任意顺序"), 1, 1, 1); 
        GameTooltip:AddLine("|cffffaa00[" .. (L["Right Click"] or "右键") .. "]|r " .. (L["Click bar or placeholder to open quick toggle menu"] or "点击条本身/占位框：呼出快捷开关与删除"), 1, 1, 1); 
        GameTooltip:Show() 
    end); btnHelp:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btnToggle:SetParent(scrollChild); btnToggle:ClearAllPoints(); btnToggle:SetPoint("TOPLEFT", 15, currentY); btnToggle:SetWidth(150); btnToggle:Show()

    if not isEnabled then
        if scrollChild.CR_Sandbox_Box then scrollChild.CR_Sandbox_Box:Hide() end
        btnGlobal:Hide(); btnScan:Hide(); btnHelp:Hide()
        
        local dMsg = scrollChild.CR_DisabledMsg
        if not dMsg then
            dMsg = scrollChild:CreateFontString(nil, "OVERLAY")
            dMsg:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
            dMsg:SetTextColor(0.6, 0.6, 0.6)
            dMsg:SetJustifyH("LEFT")
            scrollChild.CR_DisabledMsg = dMsg
        end
        dMsg:SetPoint("TOPLEFT", btnToggle, "BOTTOMLEFT", 0, -50)
        dMsg:SetText(L["CR System Disabled Msg"] or "资源条已关闭 \n\n- 系统底层渲染计算已完全拦截。\n- 全部框体与材质已经从内存中清空隐藏。\n- 排版沙盒面板已隐藏消失。\n\n如需使用，请点击上方【启用】按钮并重载界面。")
        dMsg:Show()
        
        return -(math.abs(currentY) + 200), targetWidth
    end

    if scrollChild.CR_DisabledMsg then scrollChild.CR_DisabledMsg:Hide() end

    btnGlobal:SetParent(scrollChild); btnGlobal:ClearAllPoints(); btnGlobal:SetPoint("LEFT", btnToggle, "RIGHT", 10, 0); btnGlobal:Show()
    btnScan:SetParent(scrollChild); btnScan:ClearAllPoints(); btnScan:SetPoint("LEFT", btnGlobal, "RIGHT", 10, 0); btnScan:SetWidth(200); btnScan:Show()
    btnHelp:SetParent(scrollChild); btnHelp:ClearAllPoints(); btnHelp:SetPoint("LEFT", btnScan, "RIGHT", 10, 0); btnHelp:SetWidth(120); btnHelp:Show()

    currentY = currentY - 35

    local previewBox = scrollChild.CR_Sandbox_Box or CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    previewBox:SetPoint("TOPLEFT", 15, currentY); WF.UI.Factory.ApplyFlatSkin(previewBox, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); previewBox:Show(); scrollChild.CR_Sandbox_Box = previewBox

    local bgClick = scrollChild.CR_Sandbox_BgClick or CreateFrame("Button", nil, previewBox)
    bgClick:SetAllPoints(); bgClick:SetFrameLevel(previewBox:GetFrameLevel()); bgClick:SetScript("OnClick", function() if CR.Sandbox.popupMode then CR.Sandbox.popupMode = nil; if WF.UI.CRPopup then WF.UI.CRPopup:Hide() end; WF.UI:RefreshCurrentPanel() end end); scrollChild.CR_Sandbox_BgClick = bgClick

    local canvas = scrollChild.CR_Sandbox_Canvas or CreateFrame("Frame", nil, previewBox)
    canvas:SetPoint("TOP", previewBox, "TOP", 0, 0); scrollChild.CR_Sandbox_Canvas = canvas
    
    local btnAddMonitor = scrollChild.CR_Sandbox_AddMonitorBtn or WF.UI.Factory:CreateFlatButton(previewBox, L["Add Custom Monitor"] or "新增监控", function()
        if WF.WishMonitorAPI and WF.WishMonitorAPI.ScanViewers then WF.WishMonitorAPI:ScanViewers(true) end; CR.Sandbox.popupMode = "ADD_MONITOR"; CR.Sandbox.newMonitorState = { cat = "buff", type = "time", spell = nil, displayMode = "bar" }; WF.UI:RefreshCurrentPanel()
    end)
    scrollChild.CR_Sandbox_AddMonitorBtn = btnAddMonitor; btnAddMonitor:SetParent(previewBox); btnAddMonitor:ClearAllPoints(); btnAddMonitor:SetPoint("BOTTOMRIGHT", previewBox, "BOTTOMRIGHT", -25, 10); btnAddMonitor:SetSize(100, 26); btnAddMonitor:SetFrameLevel(previewBox:GetFrameLevel() + 20); btnAddMonitor:Show()

    local sliderGap = scrollChild.CR_Sandbox_GapSlider
    if not sliderGap then
        sliderGap = CreateFrame("Slider", "WishFlex_CR_SandboxGapSlider_V2", previewBox); sliderGap:SetOrientation("VERTICAL"); sliderGap:SetMinMaxValues(0, 50); sliderGap:SetValueStep(1); sliderGap:SetObeyStepOnDrag(true)
        local bg = CreateFrame("Frame", nil, sliderGap, "BackdropTemplate"); bg:SetPoint("TOP", sliderGap, "TOP", 0, -5); bg:SetPoint("BOTTOM", sliderGap, "BOTTOM", 0, 5); bg:SetWidth(4); bg:SetFrameLevel(sliderGap:GetFrameLevel() - 1); WF.UI.Factory.ApplyFlatSkin(bg, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)
        local thumb = sliderGap:CreateTexture(nil, "ARTWORK"); thumb:SetColorTexture(C_R, C_G, C_B, 1); thumb:SetSize(16, 8); sliderGap:SetThumbTexture(thumb)
        local text = sliderGap:CreateFontString(nil, "OVERLAY"); text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); text:SetPoint("BOTTOM", sliderGap, "TOP", 0, 2); text:SetText(L["Sandbox"] or "沙盒"); text:SetTextColor(1, 0.82, 0)
        local valText = sliderGap:CreateFontString(nil, "OVERLAY"); valText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE"); valText:SetPoint("TOP", sliderGap, "BOTTOM", 0, -2); valText:SetTextColor(1, 1, 1); sliderGap.valText = valText
        sliderGap:SetScript("OnValueChanged", function(self, value) local val = math.floor(value + 0.5); self.valText:SetText(val); if CR.Sandbox.previewGap ~= val then CR.Sandbox.previewGap = val; if CR.Sandbox.RenderPreview then CR.Sandbox.RenderPreview() end end end)
        scrollChild.CR_Sandbox_GapSlider = sliderGap
    end
    sliderGap:SetParent(previewBox); sliderGap:ClearAllPoints(); sliderGap:SetPoint("TOPRIGHT", previewBox, "TOPRIGHT", -15, -40); sliderGap:SetPoint("BOTTOMRIGHT", previewBox, "BOTTOMRIGHT", -15, 60); sliderGap:Show(); sliderGap:SetFrameLevel(previewBox:GetFrameLevel() + 20); sliderGap:SetValue(CR.Sandbox.previewGap or 1); if sliderGap.valText then sliderGap.valText:SetText(CR.Sandbox.previewGap or 1) end
    
    if not scrollChild.CR_DropIndicator then local ind = CreateFrame("Frame", nil, canvas, "BackdropTemplate"); ind:SetSize(ColW - 60, 4); local tex = ind:CreateTexture(nil, "OVERLAY"); tex:SetAllPoints(); tex:SetColorTexture(0, 1, 0, 1); ind.tex = tex; ind:Hide(); scrollChild.CR_DropIndicator = ind else scrollChild.CR_DropIndicator:SetParent(canvas); scrollChild.CR_DropIndicator:SetSize(ColW - 60, 4) end

    local pool = scrollChild.CR_Sandbox_Pool or {}; scrollChild.CR_Sandbox_Pool = pool
    for _, v in ipairs(pool) do v:Hide() end

    local function RenderSandbox()
        local cy = -25; local gapY = CR.Sandbox.previewGap or 1; local PADDING = 15 
        local dynamicCDW = GetSandboxCDWidth(); local baseBarWidth = (db.alignWithCD and dynamicCDW) and dynamicCDW or (tonumber(specCfg.width) or 250)

        for i, key in ipairs(db.sortOrder) do
            local isCurrentSpec = true; local cfgObj = nil
            if string.sub(key, 1, 3) == "WM_" then local spellID = string.sub(key, 4); cfgObj = (wmDB.skills and wmDB.skills[spellID]) or (wmDB.buffs and wmDB.buffs[spellID]); if cfgObj and cfgObj.specID and cfgObj.specID ~= 0 and cfgObj.specID ~= tempDB.spec then isCurrentSpec = false end end

            local btn = pool[i]
            if not btn then
                btn = CreateFrame("Button", nil, canvas, "BackdropTemplate"); btn.borderTex = btn:CreateTexture(nil, "BACKGROUND"); btn.borderTex:SetAllPoints(); btn.borderTex:SetColorTexture(0, 0, 0, 0) 
                local m = 0; local sb = CreateFrame("StatusBar", nil, btn); sb:SetPoint("TOPLEFT", btn, "TOPLEFT", m, -m); sb:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -m, m); btn.sb = sb
                local bg = sb:CreateTexture(nil, "BACKGROUND", nil, -1); bg:SetAllPoints(); btn.sbBg = bg
                btn.textFrame = CreateFrame("Frame", nil, btn); btn.textFrame:SetAllPoints(btn); btn.textFrame:SetFrameLevel(sb:GetFrameLevel() + 10)
                btn.text = btn.textFrame:CreateFontString(nil, "OVERLAY"); btn:RegisterForClicks("LeftButtonUp", "RightButtonUp"); btn:RegisterForDrag("LeftButton"); pool[i] = btn
            end
            
            if not isCurrentSpec then btn:Hide() else
                btn.key = key; local isTextMode = (cfgObj and cfgObj.displayMode == "text"); btn.isTextMode = isTextMode
                btn:SetScript("OnClick", function(self, button) if self.isDragging then return end; if button == "RightButton" then if CR.Menu and CR.Menu.ShowRightClickMenu then CR.Menu:ShowRightClickMenu(self, self.key, self.text:GetText() or self.key, HandleCRChange) end else if WF.UI.CR_SandboxMenu then WF.UI.CR_SandboxMenu:Hide() end; if string.sub(self.key, 1, 3) == "WM_" then CR.Sandbox.popupMode = "EDIT_MONITOR_BAR"; CR.Sandbox.editMonitorID = string.sub(self.key, 4); CR.Sandbox.editMonitorCat = (wmDB.skills and wmDB.skills[CR.Sandbox.editMonitorID]) and "skill" or "buff"; WF.UI:RefreshCurrentPanel() else CR.Sandbox.popupMode = "ROW"; CR.Sandbox.popupTarget = self.key; WF.UI:RefreshCurrentPanel() end end end)
                btn:SetScript("OnEnter", function(self) if not self.isDragging and CR.Sandbox.popupTarget ~= self.key and not self.isTextMode then self.borderTex:SetColorTexture(1, 1, 1, 0.15) end end)
                btn:SetScript("OnLeave", function(self) if not self.isDragging and CR.Sandbox.popupTarget ~= self.key and not self.isTextMode then self.borderTex:SetColorTexture(0, 0, 0, 0) end end)
                btn:SetScript("OnDragStart", function(self)
                    self.isDragging = true; local currentLevel = self:GetFrameLevel() or 1; self.origFrameLevel = currentLevel; self:SetFrameLevel(math_min(65535, currentLevel + 50))
                    local cx, mcy = GetCursorPosition(); local uiScale = self:GetEffectiveScale(); self.cursorStartX = cx / uiScale; self.cursorStartY = mcy / uiScale
                    local p, rt, rp, x, y = self:GetPoint(); self.origP, self.origRT, self.origRP = p, rt, rp; self.startX, self.startY = x, y
                    local isInd = false; local dragCfg = nil
                    if self.key == "power" then dragCfg = specCfg.power; isInd = dragCfg.independent elseif self.key == "class" then dragCfg = specCfg.class; isInd = dragCfg.independent elseif self.key == "mana" then dragCfg = specCfg.mana; isInd = dragCfg.independent elseif self.key == "vigor" then dragCfg = db.vigor; isInd = dragCfg.independent elseif self.key == "whirling" then dragCfg = db.whirling; isInd = dragCfg.independent elseif string.sub(self.key, 1, 3) == "WM_" then dragCfg = (wmDB.skills and wmDB.skills[string.sub(self.key, 4)]) or (wmDB.buffs and wmDB.buffs[string.sub(self.key, 4)]); if dragCfg then isInd = dragCfg.independent end end
                    if isInd and dragCfg then self.isFreeDrag = true; self:SetScript("OnUpdate", function(s) local ncx, ncy = GetCursorPosition(); ncx = ncx / uiScale; ncy = ncy / uiScale; s:ClearAllPoints(); s:SetPoint(s.origP, s.origRT, s.origRP, s.startX + (ncx - s.cursorStartX), s.startY + (ncy - s.cursorStartY)) end) else
                        self.isFreeDrag = false; self:SetScript("OnUpdate", function(s)
                            local _, ncy = GetCursorPosition(); ncy = ncy / uiScale; s:ClearAllPoints(); s:SetPoint(s.origP, s.origRT, s.origRP, s.startX, s.startY + (ncy - s.cursorStartY))
                            local ind = scrollChild.CR_DropIndicator; local scy = select(2, s:GetCenter()); if not scy then return end
                            local closestBtn = nil; local minDist = 9999
                            for j = 1, #pool do local other = pool[j]; if other:IsShown() and other ~= s and not other.isFreeDrag then local oy = select(2, other:GetCenter()); if oy then local dist = math_abs(scy - oy); if dist < minDist then minDist = dist; closestBtn = other end end end end
                            if closestBtn and minDist < 40 then s.dropTarget = closestBtn; local oy = select(2, closestBtn:GetCenter()); s.dropModeDir = (scy > oy) and "before" or "after"; ind:ClearAllPoints(); ind:SetParent(closestBtn:GetParent()); ind:SetFrameLevel(math_min(65535, closestBtn:GetFrameLevel() + 5)); ind:SetSize(baseBarWidth, 4); if s.dropModeDir == "before" then ind:SetPoint("BOTTOM", closestBtn, "TOP", 0, 1) else ind:SetPoint("TOP", closestBtn, "BOTTOM", 0, -1) end; ind:Show() else ind:Hide(); s.dropTarget = nil end
                        end)
                    end
                end)
                btn:SetScript("OnDragStop", function(self)
                    self.isDragging = false; self:SetScript("OnUpdate", nil); self:SetFrameLevel(math_max(1, math_min(65535, self.origFrameLevel or 1))); if scrollChild.CR_DropIndicator then scrollChild.CR_DropIndicator:Hide() end
                    if self.isFreeDrag then
                        local cx, mcy = GetCursorPosition(); local uiScale = self:GetEffectiveScale(); local dragCfg = nil
                        if self.key == "power" then dragCfg = specCfg.power elseif self.key == "class" then dragCfg = specCfg.class elseif self.key == "mana" then dragCfg = specCfg.mana elseif self.key == "vigor" then dragCfg = db.vigor elseif self.key == "whirling" then dragCfg = db.whirling elseif string.sub(self.key, 1, 3) == "WM_" then dragCfg = (wmDB.skills and wmDB.skills[string.sub(self.key, 4)]) or (wmDB.buffs and wmDB.buffs[string.sub(self.key, 4)]) end
                        if dragCfg then dragCfg.barXOffset = (tonumber(dragCfg.barXOffset) or 0) + math_floor(((cx / uiScale) - self.cursorStartX) + 0.5); dragCfg.barYOffset = (tonumber(dragCfg.barYOffset) or 0) + math_floor(((mcy / uiScale) - self.cursorStartY) + 0.5) end
                    else
                        if self.dropTarget then local myIdx, targetIdx; for idx, v in ipairs(db.sortOrder) do if v == self.key then myIdx = idx end; if v == self.dropTarget.key then targetIdx = idx end end; if myIdx and targetIdx then local myItem = table.remove(db.sortOrder, myIdx); targetIdx = 0; for idx, v in ipairs(db.sortOrder) do if v == self.dropTarget.key then targetIdx = idx break end end; if self.dropModeDir == "after" then table.insert(db.sortOrder, targetIdx + 1, myItem) else table.insert(db.sortOrder, targetIdx > 0 and targetIdx or 1, myItem) end end end
                    end
                    self:ClearAllPoints(); WF.UI:RefreshCurrentPanel(); CR:UpdateLayout()
                end)
                
                btn:SetParent(canvas); local isInd = false; local h = 10; local c = {r=1,g=1,b=1}; local name = ""; local isEnabled = true; local isMonitor = string.sub(key, 1, 3) == "WM_"
                
                if key == "power" then h = tonumber(specCfg.power.height) or 10; c = CR.GetSafeColor(specCfg.power, CR.GetPowerColor(UnitPowerType("player")), false); name = L["Power Bar"] or "能量条"; isEnabled = specCfg.showPower; isInd = specCfg.power.independent; cfgObj = specCfg.power
                elseif key == "class" then h = tonumber(specCfg.class.height) or 10; local _,_,dc = CR.GetClassResourceData(); c = CR.GetSafeColor(specCfg.class, dc, true); name = L["Class Resource Bar"] or "主资源条"; isEnabled = specCfg.showClass; isInd = specCfg.class.independent; cfgObj = specCfg.class
                elseif key == "mana" then h = tonumber(specCfg.mana.height) or 10; c = CR.GetSafeColor(specCfg.mana, CR.POWER_COLORS[0], false); name = L["Extra Mana Bar"] or "额外法力条"; isEnabled = specCfg.showMana; isInd = specCfg.mana.independent; cfgObj = specCfg.mana 
                elseif key == "vigor" then h = tonumber(db.vigor.height) or 10; c = CR.GetSafeColor(db.vigor, {r=0.2,g=0.7,b=1}, false); name = L["Vigor Bar"] or "驭空术资源条"; isEnabled = db.showVigor; isInd = db.vigor.independent; cfgObj = db.vigor 
                elseif key == "whirling" then h = tonumber(db.whirling.height) or 4; c = CR.GetSafeColor(db.whirling, {r=1,g=0.8,b=0}, false); name = L["Whirling Surge Bar"] or "回旋冲刺条"; isEnabled = db.showWhirling; isInd = db.whirling.independent; cfgObj = db.whirling 
                elseif isMonitor then
                    local spellID = string.sub(key, 4)
                    if not cfgObj then isEnabled = false; name = L["Deleted Monitor"] or "已删除监控"; c = {r=0.2,g=0.2,b=0.2}; h=10 else
                        isEnabled = cfgObj.enable; isInd = cfgObj.independent; h = tonumber(cfgObj.height) or 10; c = type(cfgObj.color) == "table" and cfgObj.color or {r=0,g=0.8,b=1}
                        if spellID == "48517" then name = L["[Monitor] Eclipse (Unified Style & Slot)"] or "[监控] 日月蚀 (统一样式与槽位)" else local sInfo = C_Spell.GetSpellInfo(tonumber(spellID)); name = (L["[Monitor] "] or "[监控] ") .. (sInfo and sInfo.name or spellID) end
                    end
                end

                if isInd then name = name .. " (" .. (L["Independent Layout"] or "独立排版") .. ")" end

                btn:SetSize(baseBarWidth, h); local texName = (cfgObj and cfgObj.useCustomTexture and cfgObj.texture and cfgObj.texture ~= "") and cfgObj.texture or db.texture
                btn.sb:SetStatusBarTexture(LSM:Fetch("statusbar", texName) or "Interface\\TargetingFrame\\UI-StatusBar"); local bgTexName = (cfgObj and cfgObj.useCustomBgTexture and cfgObj.bgTexture and cfgObj.bgTexture ~= "") and cfgObj.bgTexture or db.texture; btn.sbBg:SetTexture(LSM:Fetch("statusbar", bgTexName) or "Interface\\TargetingFrame\\UI-StatusBar")
                local globalBg = wmDB.globalBgColor or wmDB.bgColor or db.globalBgColor or {r=0,g=0,b=0,a=0.5}; local bgC = (cfgObj and cfgObj.useCustomBgColor and cfgObj.bgColor) or globalBg
                
                if isTextMode then btn.sb:Hide(); btn.sbBg:Hide(); btn.borderTex:Hide(); btn:SetBackdrop(nil) else
                    btn.sb:Show(); btn.sbBg:Show(); btn.borderTex:Show(); if CR.Sandbox.popupTarget == key then btn.borderTex:SetColorTexture(1, 0.8, 0, 0.4) else btn.borderTex:SetColorTexture(0, 0, 0, 0) end
                    btn.sb:SetStatusBarColor(c.r, c.g, c.b, 0.9); btn.sbBg:SetVertexColor(bgC.r or 0, bgC.g or 0, bgC.b or 0, bgC.a or 1); btn:SetBackdrop(nil)
                    if not isEnabled then btn.sb:SetStatusBarColor(0.2, 0.2, 0.2, 0.8); name = name .. " |cffff0000(" .. (L["Disabled"] or "禁用") .. ")|r" end
                end

                btn.sb:SetMinMaxValues(0, 3); btn.sb:SetValue(2); btn:ClearAllPoints()
                if isInd then local xOff = tonumber(cfgObj.barXOffset) or 0; local yOff = tonumber(cfgObj.barYOffset) or 0; local clampX = math_max(-(ColW / 2 - 20), math_min((ColW / 2 - 20), xOff)); local clampY = math_max(-150, math_min(150, yOff)); btn:SetPoint("CENTER", previewBox, "CENTER", clampX, clampY)
                else btn:SetPoint("TOP", canvas, "TOP", 0, cy); cy = cy - h - gapY - PADDING end

                if not btn.mockMain then btn.mockMain = btn.textFrame:CreateFontString(nil, "OVERLAY") end; if not btn.mockTimer then btn.mockTimer = btn.textFrame:CreateFontString(nil, "OVERLAY") end

                if key == "WM_48517" then
                    if not btn.mockLunarBar then btn.mockLunarBar = CreateFrame("StatusBar", nil, btn); btn.mockLunarBar:SetStatusBarTexture(LSM:Fetch("statusbar", texName) or "Interface\\TargetingFrame\\UI-StatusBar"); btn.mockLunarBar:SetStatusBarColor(0.4, 0.7, 1, 0.9); btn.mockLunarBar:SetMinMaxValues(0, 3); btn.mockLunarBar:SetValue(2) end
                    local divW = GetOnePixelSize(); local halfW = PixelSnap((baseBarWidth / 2) - (divW / 2)); btn.sb:ClearAllPoints(); btn.sb:SetPoint("RIGHT", btn, "CENTER", -(divW/2), 0); btn.sb:SetSize(halfW, h); btn.mockLunarBar:ClearAllPoints(); btn.mockLunarBar:SetPoint("LEFT", btn, "CENTER", (divW/2), 0); btn.mockLunarBar:SetSize(halfW, h); btn.mockLunarBar:Show()
                    if isTextMode then btn.mockLunarBar:Hide() else btn.mockLunarBar:Show() end; if not btn.mockEclipseDivider then btn.mockEclipseDivider = btn.textFrame:CreateTexture(nil, "OVERLAY", nil, 7); btn.mockEclipseDivider:SetColorTexture(0, 0, 0, 1) end
                    btn.mockEclipseDivider:SetWidth(divW); btn.mockEclipseDivider:ClearAllPoints(); btn.mockEclipseDivider:SetPoint("CENTER", btn, "CENTER"); btn.mockEclipseDivider:SetPoint("TOP", btn, "TOP"); btn.mockEclipseDivider:SetPoint("BOTTOM", btn, "BOTTOM"); if isTextMode then btn.mockEclipseDivider:Hide() else btn.mockEclipseDivider:Show() end
                else btn.sb:ClearAllPoints(); btn.sb:SetAllPoints(btn); if btn.mockLunarBar then btn.mockLunarBar:Hide() end; if btn.mockEclipseDivider then btn.mockEclipseDivider:Hide() end end

                local numMax = 1
                if isMonitor then local spellID = string.sub(key, 4); if cfgObj and cfgObj.trackType == "charge" then local chInfo = C_Spell.GetSpellCharges(tonumber(spellID)); if chInfo and chInfo.maxCharges then numMax = chInfo.maxCharges end elseif cfgObj and cfgObj.mode == "stack" then numMax = tonumber(cfgObj.maxStacks) or 5 end
                else if key == "power" then numMax = 1 elseif key == "class" then local _, maxP = CR.GetClassResourceData(); if maxP and maxP > 0 then numMax = maxP end elseif key == "vigor" then numMax = 6 end end

                if not btn.dividers then btn.dividers = {} end
                if not isTextMode and numMax > 1 then
                    local exactSeg = baseBarWidth / numMax; if key == "WM_48517" then exactSeg = (baseBarWidth / 2) / numMax end; local pixelSize = GetOnePixelSize()
                    for divIdx = 1, numMax - 1 do
                        if not btn.dividers[divIdx] then btn.dividers[divIdx] = btn.sb:CreateTexture(nil, "OVERLAY", nil, 7); btn.dividers[divIdx]:SetColorTexture(0, 0, 0, 1) end
                        btn.dividers[divIdx]:SetWidth(pixelSize); local offset = PixelSnap(exactSeg * divIdx); btn.dividers[divIdx]:ClearAllPoints(); btn.dividers[divIdx]:SetPoint("TOPLEFT", btn.sb, "TOPLEFT", offset, 0); btn.dividers[divIdx]:SetPoint("BOTTOMLEFT", btn.sb, "BOTTOMLEFT", offset, 0); btn.dividers[divIdx]:Show()
                    end
                    for divIdx = numMax, #btn.dividers do if btn.dividers[divIdx] then btn.dividers[divIdx]:Hide() end end
                else for divIdx = 1, #btn.dividers do btn.dividers[divIdx]:Hide() end end
                
                if isEnabled and cfgObj and key == "power" and cfgObj.thresholdLines then
                    if not btn.thresholdLines then btn.thresholdLines = {} end; local activeLines = 0
                    for lineIdx = 1, 5 do
                        local tLineCfg = cfgObj.thresholdLines[lineIdx]
                        if type(tLineCfg) == "table" and tLineCfg.enable and (tonumber(tLineCfg.value) or 0) > 0 then
                            activeLines = activeLines + 1; local tLine = btn.thresholdLines[activeLines]
                            if not tLine then tLine = btn.sb:CreateTexture(nil, "OVERLAY", nil, 7); btn.thresholdLines[activeLines] = tLine end
                            local lineVal = tonumber(tLineCfg.value) or 0; local realMax = UnitPowerMax("player", UnitPowerType("player"))
                            if not realMax or realMax <= 0 then realMax = 100 end; local pct = lineVal / realMax; if pct > 1 then pct = 1 end
                            local posX = pct * baseBarWidth; local tColor = type(tLineCfg.color) == "table" and tLineCfg.color or {r=1,g=1,b=1,a=1}; local tThick = tonumber(tLineCfg.thickness) or 2
                            tLine:SetColorTexture(tColor.r or 1, tColor.g or 1, tColor.b or 1, tColor.a or 1); tLine:SetWidth(tThick); tLine:ClearAllPoints(); tLine:SetPoint("TOPLEFT", btn.sb, "TOPLEFT", posX - (tThick/2), 0); tLine:SetPoint("BOTTOMLEFT", btn.sb, "BOTTOMLEFT", posX - (tThick/2), 0); tLine:Show()
                        end
                    end
                    for idx = activeLines + 1, #(btn.thresholdLines or {}) do if btn.thresholdLines[idx] then btn.thresholdLines[idx]:Hide() end end
                else if btn.thresholdLines then for _, tl in ipairs(btn.thresholdLines) do tl:Hide() end end end
                
                if isEnabled and cfgObj then
                    local gFontPath = db.font or "Expressway"; local font = LSM:Fetch("font", gFontPath) or STANDARD_TEXT_FONT
                    local fSize = tonumber(cfgObj.fontSize) or 12; if fSize < 1 then fSize = 1 end
                    local fColor
if isMonitor then
    fColor = type(cfgObj.textColor) == "table" and cfgObj.textColor or {r=1,g=1,b=1}
else
    fColor = type(cfgObj.color) == "table" and cfgObj.color or {r=1,g=1,b=1}
end
local fOut = cfgObj.outline or "OUTLINE"
                    
                    btn.mockMain:SetFont(font, fSize, fOut); btn.mockMain:SetTextColor(fColor.r or 1, fColor.g or 1, fColor.b or 1)
                    btn.mockTimer:SetFont(font, fSize, fOut); btn.mockTimer:SetTextColor(fColor.r or 1, fColor.g or 1, fColor.b or 1)

                    if isMonitor then
                        if key == "WM_48517" then
                            btn.mockMain:SetText(""); btn.mockMain:SetAlpha(0); btn.mockMain:Hide(); if btn.mockMain._hitBtn then btn.mockMain._hitBtn:Hide() end
                            btn.mockTimer:SetText("8.0"); btn.mockTimer:SetAlpha(1); btn.mockTimer:ClearAllPoints(); btn.mockTimer:SetPoint("LEFT", btn.textFrame, "CENTER", 8, 0); btn.mockTimer:SetJustifyH("LEFT"); btn.mockTimer:Show()
                            SetupTextHitButton(btn, btn.mockTimer, key)
                        else
                            btn.mockMain:SetText(""); btn.mockMain:SetAlpha(0); btn.mockMain:Hide()
                            if btn.mockMain._hitBtn then btn.mockMain._hitBtn:Hide() end
                            
                            local tAnchor = cfgObj.timerAnchor or "CENTER"; local tX = tonumber(cfgObj.timerXOffset) or 0; local tY = tonumber(cfgObj.timerYOffset) or 0
                            local validAnchor = {TOPLEFT=1, TOP=1, TOPRIGHT=1, LEFT=1, CENTER=1, RIGHT=1, BOTTOMLEFT=1, BOTTOM=1, BOTTOMRIGHT=1}
                            local safeAnchor = validAnchor[tAnchor] and tAnchor or "CENTER"
                            local justify = "CENTER"; if string.match(safeAnchor, "LEFT") then justify = "LEFT" elseif string.match(safeAnchor, "RIGHT") then justify = "RIGHT" end
                            
                            btn.mockTimer:ClearAllPoints(); btn.mockTimer:SetPoint(safeAnchor, btn.textFrame, safeAnchor, tX, tY); btn.mockTimer:SetJustifyH(justify)
                            
                            if cfgObj.timerEnable ~= false then
                                btn.mockTimer:SetText("12s"); btn.mockTimer:SetAlpha(1)
                            else
                                btn.mockTimer:SetText(L["[Text Disabled]"] or "[文本未启用]"); btn.mockTimer:SetAlpha(0.6)
                            end
                            btn.mockTimer:Show(); SetupTextHitButton(btn, btn.mockTimer, key)
                        end
                    else
                        local isBrewmaster = (playerClass == "MONK" and tempDB.spec == 268); local hasMainText = (key == "power" or key == "mana" or (key == "class" and isBrewmaster))
                        if hasMainText then
                            local mAnchor = cfgObj.textAnchor or "CENTER"; local mX = tonumber(cfgObj.xOffset) or (mAnchor=="LEFT" and 4 or (mAnchor=="RIGHT" and -4 or 0)); local mY = tonumber(cfgObj.yOffset) or 0
                            btn.mockMain:ClearAllPoints(); btn.mockMain:SetPoint(GetSafeJustify(mAnchor), btn.textFrame, GetSafeJustify(mAnchor), mX, mY); btn.mockMain:SetJustifyH(GetSafeJustify(mAnchor))
                            if cfgObj.textEnable ~= false then btn.mockMain:SetText("100"); btn.mockMain:SetAlpha(1) else btn.mockMain:SetText(L["[Text Disabled]"] or "[文本未启用]"); btn.mockMain:SetAlpha(0.6) end
                            btn.mockMain:Show(); SetupTextHitButton(btn, btn.mockMain, key)
                        else btn.mockMain:Hide(); if btn.mockMain._hitBtn then btn.mockMain._hitBtn:Hide() end end
                        btn.mockTimer:Hide(); if btn.mockTimer._hitBtn then btn.mockTimer._hitBtn:Hide() end
                    end
                    if btn.text then btn.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); btn.text:ClearAllPoints(); btn.text:SetPoint("BOTTOM", btn.textFrame, "TOP", 0, 4); btn.text:SetText(name); btn.text:Show() end
                else
                    btn.mockMain:Hide(); btn.mockTimer:Hide(); if btn.mockMain and btn.mockMain._hitBtn then btn.mockMain._hitBtn:Hide() end; if btn.mockTimer and btn.mockTimer._hitBtn then btn.mockTimer._hitBtn:Hide() end
                    if btn.text then btn.text:ClearAllPoints(); btn.text:SetPoint("CENTER", btn.textFrame, "CENTER", 0, 0); btn.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); btn.text:SetText(name); btn.text:Show() end
                end
                btn:Show()
            end
        end
        local previewHeight = math_max(500, math_abs(cy) + 30); previewBox:SetSize(ColW, previewHeight); canvas:SetSize(ColW, previewHeight)
        return previewHeight
    end

    CR.Sandbox.RenderPreview = RenderSandbox; local pHeight = RenderSandbox(); currentY = currentY - pHeight - 15
    if CR.Sandbox.popupMode and CR.Menu and CR.Menu.GetPopup then local popup = CR.Menu:GetPopup(); CR.Menu:RenderPopupContent(popup, CR.Sandbox.popupMode, CR.Sandbox.popupTarget, tempDB, specCfg, HandleCRChange) else if WF.UI.CRPopup then WF.UI.CRPopup:Hide() end end
    return -(math_abs(currentY)), targetWidth
end)