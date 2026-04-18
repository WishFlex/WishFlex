local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}
local CR = WF.ClassResourceAPI
if not CR then return end

local LSM = LibStub("LibSharedMedia-3.0", true)
local math_floor, math_max, math_abs = math.floor, math.max, math.abs
local string_format = string.format
local GetTime, tonumber, tostring, type = GetTime, tonumber, tostring, type

local DEF_TEXT_COLOR = {r=1, g=1, b=1}
local DEF_DIVIDER_COLOR = {r=1, g=1, b=1, a=1}

local function ApplyTextureGradient(bar, matchedColor, orientation)
    if not bar then return end
    local tex = bar:GetStatusBarTexture()
    if not tex then return end
    
    tex:SetHorizTile(false)
    tex:SetVertTile(false)
    
    local orient = orientation or "HORIZONTAL"

    if matchedColor and matchedColor.isGradient then
        local sC = matchedColor.startC or {r=1,g=1,b=1,a=1}
        local eC = matchedColor.endC or {r=1,g=1,b=1,a=1}
        if CreateColor then
            tex:SetGradient(orient, CreateColor(sC.r, sC.g, sC.b, sC.a or 1), CreateColor(eC.r, eC.g, eC.b, eC.a or 1))
        else
            tex:SetGradient(orient, sC.r, sC.g, sC.b, sC.a or 1, eC.r, eC.g, eC.b, eC.a or 1)
        end
    else
        local r, g, b, a = bar:GetStatusBarColor()
        if not r then r, g, b, a = 1, 1, 1, 1 end 
        if CreateColor then
            tex:SetGradient(orient, CreateColor(r, g, b, a), CreateColor(r, g, b, a))
        else
            tex:SetGradient(orient, r, g, b, a, r, g, b, a)
        end
    end
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
        local fgTex = bar.statusBar:GetStatusBarTexture()
        fgTex:SetTexture(texPath)
        fgTex:SetHorizTile(false)
        fgTex:SetVertTile(false)
        if fgTex.SetSnapToPixelGrid then
            pcall(function()
                fgTex:SetSnapToPixelGrid(false)
                fgTex:SetTexelSnappingBias(0)
            end)
        end
    end
    
    if bar.statusBar.bg then
        local bgTexPath = LSM:Fetch("statusbar", finalBgTexture) or "Interface\\TargetingFrame\\UI-StatusBar"
        bar.statusBar.bg:SetTexture(bgTexPath)
        bar.statusBar.bg:SetVertexColor(bgc.r or 0, bgc.g or 0, bgc.b or 0, bgc.a or 0.5)
    end

    if bar.bdFrame and barCfg.borderEnable ~= nil then
        local bdSize = tonumber(barCfg.borderSize) or 1
        local m = CR.GetOnePixelSize() * bdSize
        local bc = barCfg.borderColor or {r=0, g=0, b=0, a=1}
        
        if barCfg.borderEnable then
            bar.bdFrame.top:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
            bar.bdFrame.bottom:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
            bar.bdFrame.left:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
            bar.bdFrame.right:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
            bar.bdFrame.top:SetHeight(m); bar.bdFrame.bottom:SetHeight(m)
            bar.bdFrame.left:SetWidth(m); bar.bdFrame.right:SetWidth(m)
            bar.bdFrame:Show()
        else
            bar.bdFrame:Hide()
        end
    end
end

function CR:UpdateDividers(bar, maxVal)
    bar.dividers = bar.dividers or {}
    local numMax = (CR.IsSecret(maxVal) and 1) or (tonumber(maxVal) or 1)
    if numMax <= 0 then numMax = 1 end; if numMax > 20 then numMax = 20 end 
    
    local targetFrame = bar.gridFrame
    local width = targetFrame:GetWidth() or 250
    local height = targetFrame:GetHeight() or 10
    
    -- 动态判断主资源条是否也是垂直模式
    local isVert = (bar.statusBar and bar.statusBar:GetOrientation() == "VERTICAL")
    
    local stateHash = numMax .. "_" .. width .. "_" .. height .. "_" .. tostring(isVert)
    if bar._lastDividerState == stateHash then return end
    bar._lastDividerState = stateHash

    local numDividers = numMax > 1 and (numMax - 1) or 0
    local segWidth = isVert and (height / numMax) or (width / numMax)
    
    local pSize = CR.GetOnePixelSize()
    for i = 1, numDividers do
        if not bar.dividers[i] then 
            local tex = targetFrame:CreateTexture(nil, "OVERLAY", nil, 7); tex:SetColorTexture(0, 0, 0, 1); bar.dividers[i] = tex 
        end
        
        -- 精确浮点定位，消除反向填充缝隙
        local offset = segWidth * i
        bar.dividers[i]:ClearAllPoints()
        
        if isVert then
            bar.dividers[i]:SetHeight(pSize)
            bar.dividers[i]:SetPoint("BOTTOMLEFT", targetFrame, "BOTTOMLEFT", 0, offset)
            bar.dividers[i]:SetPoint("BOTTOMRIGHT", targetFrame, "BOTTOMRIGHT", 0, offset)
        else
            bar.dividers[i]:SetWidth(pSize)
            bar.dividers[i]:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", offset, 0)
            bar.dividers[i]:SetPoint("BOTTOMLEFT", targetFrame, "BOTTOMLEFT", offset, 0)
        end
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

function CR:UpdateMonitorDividers(f, numMax, widthOrHeight)
    local parentFrame = f.chargeBar or f
    
    if not f.dividerFrame then
        f.dividerFrame = CreateFrame("Frame", nil, parentFrame)
        f.dividerFrame:SetFrameLevel(parentFrame:GetFrameLevel() + 15)
        
        f.dividerFrame:SetScript("OnSizeChanged", function(self, newWidth, newHeight)
            if not self.numMax or self.numMax <= 1 then return end
            if not newWidth or newWidth <= 0 then return end
            if not newHeight or newHeight <= 0 then return end
            
            local isVert = self.isVertical
            local exactSeg = isVert and (newHeight / self.numMax) or (newWidth / self.numMax)
            local pSize = CR.GetOnePixelSize()
            
            for i = 1, self.numMax - 1 do
                if self.divs and self.divs[i] then
                    local offset = exactSeg * i
                    -- 核心修复：绝对禁止使用SetWidth(0)，使用纯点锚定逻辑覆盖
                    self.divs[i]:ClearAllPoints()
                    
                    if isVert then
                        self.divs[i]:SetHeight(pSize)
                        self.divs[i]:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, offset)
                        self.divs[i]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, offset)
                    else
                        self.divs[i]:SetWidth(pSize)
                        self.divs[i]:SetPoint("TOPLEFT", self, "TOPLEFT", offset, 0)
                        self.divs[i]:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", offset, 0)
                    end
                end
            end
        end)
    end
    
    f.dividerFrame:SetParent(parentFrame)
    f.dividerFrame:ClearAllPoints()
    f.dividerFrame:SetAllPoints(parentFrame)
    
    f.dividers = f.dividers or {}
    f.dividerFrame.divs = f.dividers
    
    if f.cfg and f.cfg.displayMode == "text" then numMax = 1 end
    numMax = tonumber(numMax) or 1
    f.dividerFrame.numMax = numMax

    local isIndependent = (f.cfg and f.cfg.independent)
    f.dividerFrame.isVertical = (isIndependent and f.cfg.orientation == "VERTICAL")

    if numMax <= 1 then 
        for _, d in ipairs(f.dividers) do d:Hide() end
        return 
    end 
    
    for i = 1, numMax - 1 do
        if not f.dividers[i] then 
            local tex = f.dividerFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetColorTexture(0, 0, 0, 1)
            f.dividers[i] = tex 
        end
        f.dividers[i]:Show()
    end
    
    for i = numMax, #f.dividers do 
        if f.dividers[i] then f.dividers[i]:Hide() end 
    end
    
    local currentWidth = parentFrame:GetWidth() or f.calcWidth
    local currentHeight = parentFrame:GetHeight() or f.calcHeight
    if currentWidth and currentWidth > 0 and currentHeight and currentHeight > 0 then
        f.dividerFrame:GetScript("OnSizeChanged")(f.dividerFrame, currentWidth, currentHeight)
    end
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
    if bar._lastColorR ~= c.r or bar._lastColorG ~= c.g or bar._lastColorB ~= c.b then 
        bar.text:SetTextColor(c.r, c.g, c.b); bar.timerText:SetTextColor(c.r, c.g, c.b)
        bar._lastColorR = c.r; bar._lastColorG = c.g; bar._lastColorB = c.b 
    end
    
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
            elseif CR.IsSecret and CR.IsSecret(current) or (CR.IsSecret and CR.IsSecret(maxVal)) then newMainText = current
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
        if CR.IsSecret and CR.IsSecret(newMainText) then pcall(bar.text.SetText, bar.text, newMainText); bar._lastMainString = nil
        else if type(bar._lastMainString) ~= "string" or bar._lastMainString ~= newMainText then bar.text:SetText(newMainText); bar._lastMainString = newMainText end end
        if not bar._isMainShown then bar.text:Show(); bar._isMainShown = true end
    end

    if textCfg.timerEnable ~= false then
        if CR.IsSecret and CR.IsSecret(newTimerText) then pcall(bar.timerText.SetText, bar.timerText, newTimerText); bar._lastTimerString = nil
        else if type(bar._lastTimerString) ~= "string" or bar._lastTimerString ~= newTimerText then bar.timerText:SetText(newTimerText); bar._lastTimerString = newTimerText end end
        if not bar._isTimerShown then bar.timerText:Show(); bar._isTimerShown = true end
    else if bar._isTimerShown then bar.timerText:Hide(); bar._isTimerShown = false end end
end

function CR:CreateBarContainer(name, parent)
    local bar = _G[name] or CreateFrame("Frame", name, parent)
    if not bar.statusBar then
        local sb = CreateFrame("StatusBar", nil, bar)
        sb:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
        sb:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
        bar.statusBar = sb
        
        local sbBg = sb:CreateTexture(nil, "BACKGROUND", nil, -1)
        sbBg:SetAllPoints(sb)
        sb.bg = sbBg
        
        local bd = CreateFrame("Frame", nil, bar)
        bd:SetAllPoints(bar)
        bd:SetFrameLevel(sb:GetFrameLevel() + 2)
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
        local gridFrame = CreateFrame("Frame", nil, bar)
        gridFrame:SetAllPoints(bar.statusBar)
        gridFrame:SetFrameLevel(bar.statusBar:GetFrameLevel() + 5)
        bar.gridFrame = gridFrame
    end
    if not bar.textFrame then
        local textFrame = CreateFrame("Frame", nil, bar)
        textFrame:SetAllPoints(bar)
        textFrame:SetFrameLevel(bar.statusBar:GetFrameLevel() + 10)
        bar.textFrame = textFrame
        bar.text = textFrame:CreateFontString(nil, "OVERLAY"); bar.timerText = textFrame:CreateFontString(nil, "OVERLAY") 
    end
    return bar
end

function CR:ClearMonitors()
    if WF.db and WF.db.classResource and WF.db.classResource.enable == false then return end

    if WF.BarEngine then WF.BarEngine:ReleaseAll() end
    wipe(self.ActiveMonitorFrames or {})
end

function CR:PrepareMonitorStyle(f, wmDB, cfg, spellID)
    local crDB = CR.GetDB()
    local visualConfig = f.visualConfig or {}
    f.visualConfig = visualConfig
    
    visualConfig.texture = (cfg.useCustomTexture == true and cfg.texture) and cfg.texture or wmDB.texture or crDB.texture or "Wish2"
    visualConfig.bgTexture = (cfg.useCustomBgTexture == true and cfg.bgTexture) and cfg.bgTexture or wmDB.texture or crDB.texture or "Wish2"
    
    local fWidth = (cfg.width and tonumber(cfg.width) > 0) and tonumber(cfg.width) or self:GetActiveWidth()
    local fHeight = (cfg.height and tonumber(cfg.height) > 0) and tonumber(cfg.height) or 10
    
    visualConfig.font = crDB.font or "Expressway"
    visualConfig.fontSize = (cfg.fontSize and tonumber(cfg.fontSize) > 0) and tonumber(cfg.fontSize) or (tonumber(wmDB.fontSize) or crDB.fontSize or 12)
    
    local globalBg = wmDB.globalBgColor or wmDB.bgColor or crDB.globalBgColor or {r=0, g=0, b=0, a=0.5}
    
    if not visualConfig.bgColor then visualConfig.bgColor = {} end
    if cfg.useCustomBgColor and type(cfg.bgColor) == "table" then
        visualConfig.bgColor.r = tonumber(cfg.bgColor.r) or tonumber(globalBg.r) or 0
        visualConfig.bgColor.g = tonumber(cfg.bgColor.g) or tonumber(globalBg.g) or 0
        visualConfig.bgColor.b = tonumber(cfg.bgColor.b) or tonumber(globalBg.b) or 0
        visualConfig.bgColor.a = tonumber(cfg.bgColor.a) or tonumber(globalBg.a) or 0.5
    else
        visualConfig.bgColor.r = tonumber(globalBg.r) or 0
        visualConfig.bgColor.g = tonumber(globalBg.g) or 0
        visualConfig.bgColor.b = tonumber(globalBg.b) or 0
        visualConfig.bgColor.a = tonumber(globalBg.a) or 0.5
    end
    
    if not visualConfig.color then visualConfig.color = {} end
    if type(cfg.color) == "table" then
        visualConfig.color.r = tonumber(cfg.color.r) or 1
        visualConfig.color.g = tonumber(cfg.color.g) or 1
        visualConfig.color.b = tonumber(cfg.color.b) or 1
        visualConfig.color.a = tonumber(cfg.color.a) or 1
    else
        visualConfig.color.r = 0; visualConfig.color.g = 0.8; visualConfig.color.b = 1; visualConfig.color.a = 1
    end

    visualConfig.reverseFill = cfg.reverseFill
    visualConfig.alwaysShow = cfg.alwaysShow
    
    local isTextMode = (cfg.displayMode == "text")
    visualConfig.useStatusBar = (not isTextMode)
    
    visualConfig.height = fHeight
    
    visualConfig.textEnable = false
    visualConfig.textAnchor = "CENTER"
    visualConfig.xOffset = 0
    visualConfig.yOffset = 0
    
    if cfg.timerEnable ~= nil then visualConfig.timerEnable = cfg.timerEnable else visualConfig.timerEnable = cfg.showTimerText end
    visualConfig.timerAnchor = cfg.timerAnchor
    visualConfig.timerXOffset = cfg.timerXOffset
    visualConfig.timerYOffset = cfg.timerYOffset

    visualConfig.dynamicTimer = cfg.dynamicTimer; visualConfig.iconID = nil

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if spellInfo then visualConfig.iconID = spellInfo.iconID end
    
    if WF.BarEngine then WF.BarEngine:ApplyStyle(f, visualConfig) end
    if f.chargeBar then
        local fgTex = f.chargeBar:GetStatusBarTexture()
        if fgTex and fgTex.SetSnapToPixelGrid then
            pcall(function()
                fgTex:SetSnapToPixelGrid(false)
                fgTex:SetTexelSnappingBias(0)
            end)
        end
    end
    
    f.calcWidth = CR.PixelSnap(fWidth); f.calcHeight = CR.PixelSnap(fHeight)
    return visualConfig
end

function CR:RenderMonitors(activeData, wmDB)
    if WF.db and WF.db.classResource and WF.db.classResource.enable == false then return end
    if self.WakeUp then 
        self:WakeUp() 
    end
    
    self.lastWmDB = wmDB
    if WF.BarEngine then WF.BarEngine:PrepareRender() end
    self.ActiveMonitorFrames = self.ActiveMonitorFrames or {}; wipe(self.ActiveMonitorFrames)
    local eclipseData = nil; local newActiveData = {}
    
    for _, data in ipairs(activeData) do
        if data.spellID == 48517 or data.spellID == 48518 then
            if not eclipseData then eclipseData = { isEclipse = true, spellIDStr = "48517", spellID = 48517 } end
            if data.spellID == 48517 then eclipseData.solar = data; eclipseData.cfg = data.cfg end
            if data.spellID == 48518 then eclipseData.lunar = data end
        else table.insert(newActiveData, data) end
    end
    if eclipseData then if not eclipseData.cfg and eclipseData.lunar then eclipseData.cfg = eclipseData.lunar.cfg end; table.insert(newActiveData, eclipseData) end

    for _, data in ipairs(newActiveData) do
        local f = WF.BarEngine:AcquireFrame("WM_" .. data.spellIDStr)
        f.cfg = data.cfg; f.spellID = data.spellID; f.spellIDStr = data.spellIDStr; f.isDualEclipse = false
        
        local visualConfig = self:PrepareMonitorStyle(f, wmDB, data.cfg, data.spellID)
        visualConfig.mode = data.cfg and data.cfg.mode or "time"
        local isTextMode = (data.cfg and data.cfg.displayMode == "text")
        local isIndependent = (data.cfg and data.cfg.independent)
        local orient = (isIndependent and data.cfg.orientation) or "HORIZONTAL"

        if data.isEclipse then
            local sData = data.solar; local lData = data.lunar; local isDual = (sData ~= nil and lData ~= nil)
            if isDual then
                f.isDualEclipse = true; visualConfig.reverseFill = true 
                if sData.isConfigPreview then sData.state.isActive = true; sData.state.count = 2; sData.state.durObjC = { startTime = GetTime(), duration = 5 } end
                
                local sMatchedColor = nil
                if CR.GetDynamicBarColor then
                    sMatchedColor = CR.GetDynamicBarColor(sData.state.count, sData.state.maxVal, sData.cfg, visualConfig.color)
                    if sMatchedColor then 
                        if sMatchedColor.isGradient then
                            visualConfig.color.r, visualConfig.color.g, visualConfig.color.b, visualConfig.color.a = 1,1,1,1
                        else
                            visualConfig.color.r = sMatchedColor.r or 1; visualConfig.color.g = sMatchedColor.g or 1; visualConfig.color.b = sMatchedColor.b or 1; visualConfig.color.a = sMatchedColor.a or 1 
                        end
                    end
                end

                f.state = sData.state
                if WF.BarEngine then WF.BarEngine:UpdateState(f, sData.state, visualConfig) end

                local divW = CR.GetOnePixelSize()
                if f.chargeBar then 
                    f.chargeBar:ClearAllPoints(); f.chargeBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1); f.chargeBar:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -(divW/2), 1); pcall(function() f.chargeBar:SetReverseFill(true) end); 
                    ApplyTextureGradient(f.chargeBar, sMatchedColor, orient)
                end
                if f.bg then f.bg:ClearAllPoints(); f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1); f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -(divW/2), 1); end
                if f.timerText then f.timerText:ClearAllPoints(); f.timerText:SetPoint("RIGHT", f, "CENTER", -8, 0); f.timerText:SetJustifyH("RIGHT") end
                
                local lf = WF.BarEngine:AcquireFrame("WM_48518_LUNAR_SUB"); local lVis = self:PrepareMonitorStyle(lf, wmDB, lData.cfg, lData.spellID)
                lf:SetParent(f); lf:ClearAllPoints(); lf:SetPoint("TOPLEFT", f, "TOP", (divW/2), 0); lf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0); lf:Show()
                
                lVis.mode = lData.cfg.mode or "time"; lVis.reverseFill = false; lVis.timerAnchor = "LEFT"; lVis.textAnchor = "LEFT"
                local lDefColor = lData.cfg.color or {r=0.4, g=0.7, b=1, a=1}
                lVis.color.r = lDefColor.r or 1; lVis.color.g = lDefColor.g or 1; lVis.color.b = lDefColor.b or 1; lVis.color.a = lDefColor.a or 1
                
                if lData.isConfigPreview then lData.state.isActive = true; lData.state.count = 2; lData.state.durObjC = { startTime = GetTime(), duration = 5 } end
                
                local lMatchedColor = nil
                if CR.GetDynamicBarColor then
                    lMatchedColor = CR.GetDynamicBarColor(lData.state.count, lData.state.maxVal, lData.cfg, lVis.color)
                    if lMatchedColor then 
                        if lMatchedColor.isGradient then
                            lVis.color.r, lVis.color.g, lVis.color.b, lVis.color.a = 1,1,1,1
                        else
                            lVis.color.r = lMatchedColor.r or 1; lVis.color.g = lMatchedColor.g or 1; lVis.color.b = lMatchedColor.b or 1; lVis.color.a = lMatchedColor.a or 1 
                        end
                    end
                end

                lf.state = lData.state
                if WF.BarEngine then WF.BarEngine:UpdateState(lf, lData.state, lVis) end

                if lf.chargeBar then 
                    lf.chargeBar:ClearAllPoints(); lf.chargeBar:SetPoint("TOPLEFT", lf, "TOPLEFT", 1, -1); lf.chargeBar:SetPoint("BOTTOMRIGHT", lf, "BOTTOMRIGHT", -1, 1); pcall(function() lf.chargeBar:SetReverseFill(false) end); 
                    ApplyTextureGradient(lf.chargeBar, lMatchedColor, orient)
                end
                if lf.bg then lf.bg:ClearAllPoints(); lf.bg:SetPoint("TOPLEFT", lf, "TOPLEFT", 1, -1); lf.bg:SetPoint("BOTTOMRIGHT", lf, "BOTTOMRIGHT", -1, 1); end
                if lf.sbBorder then lf.sbBorder:Hide() end
                if lf.timerText then lf.timerText:ClearAllPoints(); lf.timerText:SetPoint("LEFT", f, "CENTER", 8, 0); lf.timerText:SetJustifyH("LEFT") end
                f.lunarSubFrame = lf
                if not f.eclipseDivider then f.eclipseDivider = f:CreateTexture(nil, "OVERLAY", nil, 7); f.eclipseDivider:SetColorTexture(0, 0, 0, 1) end
                f.eclipseDivider:SetWidth(divW); f.eclipseDivider:ClearAllPoints(); f.eclipseDivider:SetPoint("CENTER", f, "CENTER"); f.eclipseDivider:SetPoint("TOP", f, "TOP"); f.eclipseDivider:SetPoint("BOTTOM", f, "BOTTOM"); if isTextMode then f.eclipseDivider:Hide() else f.eclipseDivider:Show() end
                
                self:UpdateMonitorDividers(f, 1, f.calcWidth)

            elseif sData then
                visualConfig.reverseFill = true 
                if sData.isConfigPreview then sData.state.isActive = true; sData.state.count = 2; sData.state.durObjC = { startTime = GetTime(), duration = 5 } end
                
                local matchedColor = nil
                if CR.GetDynamicBarColor then
                    matchedColor = CR.GetDynamicBarColor(sData.state.count, sData.state.maxVal, sData.cfg, visualConfig.color)
                    if matchedColor then 
                        if matchedColor.isGradient then
                            visualConfig.color.r, visualConfig.color.g, visualConfig.color.b, visualConfig.color.a = 1,1,1,1
                        else
                            visualConfig.color.r = matchedColor.r or 1; visualConfig.color.g = matchedColor.g or 1; visualConfig.color.b = matchedColor.b or 1; visualConfig.color.a = matchedColor.a or 1 
                        end
                    end
                end

                f.state = sData.state
                if WF.BarEngine then WF.BarEngine:UpdateState(f, sData.state, visualConfig) end
                
                if f.chargeBar then 
                    f.chargeBar:ClearAllPoints(); f.chargeBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1); f.chargeBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1); pcall(function() f.chargeBar:SetReverseFill(true) end); 
                    ApplyTextureGradient(f.chargeBar, matchedColor, orient)
                end
                if f.bg then f.bg:ClearAllPoints(); f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1); f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1); end
                if f.timerText then f.timerText:ClearAllPoints(); f.timerText:SetPoint("RIGHT", f, "RIGHT", -4, 0); f.timerText:SetJustifyH("RIGHT") end
                if f.sbBorder then if isTextMode then f.sbBorder:Hide() else f.sbBorder:Show() end end
                if f.lunarSubFrame then f.lunarSubFrame:Hide() end; if f.eclipseDivider then f.eclipseDivider:Hide() end
                
                self:UpdateMonitorDividers(f, 1, f.calcWidth)

            elseif lData then
                local lVis = self:PrepareMonitorStyle(f, wmDB, lData.cfg, lData.spellID); 
                lVis.reverseFill = false 
                
                local lDefColor = lData.cfg.color or {r=0.4, g=0.7, b=1, a=1}
                lVis.color.r = lDefColor.r or 1; lVis.color.g = lDefColor.g or 1; lVis.color.b = lDefColor.b or 1; lVis.color.a = lDefColor.a or 1
                
                if lData.isConfigPreview then lData.state.isActive = true; lData.state.count = 2; lData.state.durObjC = { startTime = GetTime(), duration = 5 } end
                
                local matchedColor = nil
                if CR.GetDynamicBarColor then
                    matchedColor = CR.GetDynamicBarColor(lData.state.count, lData.state.maxVal, lData.cfg, lVis.color)
                    if matchedColor then 
                        if matchedColor.isGradient then
                            lVis.color.r, lVis.color.g, lVis.color.b, lVis.color.a = 1,1,1,1
                        else
                            lVis.color.r = matchedColor.r or 1; lVis.color.g = matchedColor.g or 1; lVis.color.b = matchedColor.b or 1; visualConfig.color.a = matchedColor.a or 1 
                        end
                    end
                end

                f.state = lData.state
                if WF.BarEngine then WF.BarEngine:UpdateState(f, lData.state, lVis) end
                
                if f.chargeBar then 
                    f.chargeBar:ClearAllPoints(); f.chargeBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1); f.chargeBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1); pcall(function() f.chargeBar:SetReverseFill(false) end); 
                    ApplyTextureGradient(f.chargeBar, matchedColor, orient)
                end
                if f.bg then f.bg:ClearAllPoints(); f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1); f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1); end
                if f.timerText then f.timerText:ClearAllPoints(); f.timerText:SetPoint("LEFT", f, "LEFT", 4, 0); f.timerText:SetJustifyH("LEFT") end
                if f.sbBorder then if isTextMode then f.sbBorder:Hide() else f.sbBorder:Show() end end
                if f.lunarSubFrame then f.lunarSubFrame:Hide() end; if f.eclipseDivider then f.eclipseDivider:Hide() end
                
                self:UpdateMonitorDividers(f, 1, f.calcWidth)
            end
            table.insert(self.ActiveMonitorFrames, f)
        else
            local state = data.state
            if data.isConfigPreview then state.isActive = true; state.count = state.maxVal or 2; state.durObjC = { startTime = GetTime(), duration = 5 } end
            
            local matchedColor = nil
            if CR.GetDynamicBarColor then
                local numMax = state.maxVal or 1
                if visualConfig.mode == "stack" or data.cfg.trackType == "charge" then
                    numMax = tonumber(data.cfg.maxStacks) or numMax
                end
                
                local decodedCurr = CR.DecodeSecretValue(state.count, numMax)
                matchedColor = CR.GetDynamicBarColor(decodedCurr, numMax, data.cfg, visualConfig.color)
                
                if matchedColor then
                    if matchedColor.isGradient then
                        visualConfig.color.r, visualConfig.color.g, visualConfig.color.b, visualConfig.color.a = 1,1,1,1
                    else
                        visualConfig.color.r = matchedColor.r or 1; visualConfig.color.g = matchedColor.g or 1; visualConfig.color.b = matchedColor.b or 1; visualConfig.color.a = matchedColor.a or 1 
                    end
                end
            end

            f.state = state
            if WF.BarEngine then WF.BarEngine:UpdateState(f, state, visualConfig) end
            
            if f.chargeBar then 
                f.chargeBar:ClearAllPoints(); f.chargeBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1); f.chargeBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1); 
                ApplyTextureGradient(f.chargeBar, matchedColor, orient)
            end
            if f.bg then f.bg:ClearAllPoints(); f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1); f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1); end
            if f.sbBorder then if isTextMode then f.sbBorder:Hide() else f.sbBorder:Show() end end
            if f.lunarSubFrame then f.lunarSubFrame:Hide() end; if f.eclipseDivider then f.eclipseDivider:Hide() end
            
            local numMax = state.maxVal or 1
            if visualConfig.mode == "stack" or data.cfg.trackType == "charge" then
                numMax = tonumber(data.cfg.maxStacks) or numMax
            end
            self:UpdateMonitorDividers(f, numMax, f.calcWidth)

            table.insert(self.ActiveMonitorFrames, f)
        end
    end
    
    if WF.BarEngine then WF.BarEngine:CleanupUnused() end
    self:RepositionMonitors()
end


function CR:RepositionMonitors()
    if WF.db and WF.db.classResource and WF.db.classResource.enable == false then return end

    if not self.ActiveMonitorFrames then return end
    
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
                local spellInfo = nil; pcall(function() spellInfo = C_Spell.GetSpellInfo(tonumber(f.spellID)) end)
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
            if f.cfg.displayMode ~= "text" then f:SetSize(f.calcWidth, f.calcHeight) else f:SetSize(math_max(f.calcWidth or 80, 80), math_max(f.calcHeight or 40, 40)) end
        end
    end
    
    local wmDB = WF.db and WF.db.wishMonitor or {}
    local dbCR = CR.GetDB()
    
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