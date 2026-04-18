local AddonName, ns = ...
local WF = ns.WF
local LSM = LibStub("LibSharedMedia-3.0", true)

WF.BarEngine = {}
local FramePool = {}
local ActiveKeys = {}

local DEFAULT_BG_COLOR = {r=0, g=0, b=0, a=0.5}
local DEFAULT_BAR_COLOR = {r=0, g=0.8, b=1, a=1}

-- 【极限优化】：提取所有高频调用的安全执行函数为静态指针，彻底消除 pcall 匿名闭包的内存碎片
local function SafeIsSecretValue(val) return type(val) == "number" and type(issecretvalue) == "function" and issecretvalue(val) end
local function SafeSetCooldownObj(cd, obj) cd:SetCooldownFromDurationObject(obj) end
local function SafeClearTimer(bar) bar:ClearTimerDuration() end
local function SafeSetTimer(bar, obj, dir) bar:SetTimerDuration(obj, 0, dir) end
local function SafeSetToTarget(bar) bar:SetToTargetValue() end
local function SafeSetText(fontStr, txt) fontStr:SetText(txt) end
local function SafeSetMinMax(bar, min, max) bar:SetMinMaxValues(min, max) end

local function GetOnePixelSize()
    local screenHeight = select(2, GetPhysicalScreenSize())
    if not screenHeight or screenHeight == 0 then return 1 end
    local uiScale = UIParent:GetEffectiveScale()
    if not uiScale or uiScale == 0 then return 1 end
    return 768.0 / screenHeight / uiScale
end

local function AddBoxBorder(target)
    local border = CreateFrame("Frame", nil, target)
    border:SetAllPoints(); border:SetFrameLevel(target:GetFrameLevel() + 5)
    
    local function DrawLine(p1, p2, x, y, w, h)
        local m = GetOnePixelSize()
        local t = border:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(0, 0, 0, 1)
        t:SetPoint(p1, border, p1, x, y)
        t:SetPoint(p2, border, p2, x, y)
        if w then t:SetWidth(m) end
        if h then t:SetHeight(m) end
    end
    
    DrawLine("TOPLEFT", "TOPRIGHT", 0, 0, nil, 1)
    DrawLine("BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, nil, 1)
    DrawLine("TOPLEFT", "BOTTOMLEFT", 0, 0, 1, nil)
    DrawLine("TOPRIGHT", "BOTTOMRIGHT", 0, 0, 1, nil)
    return border
end

local function GetSafeJustify(anchorStr)
    if type(anchorStr) ~= "string" then return "CENTER" end
    if string.match(anchorStr, "LEFT") then return "LEFT" elseif string.match(anchorStr, "RIGHT") then return "RIGHT" else return "CENTER" end
end

local function ApplyTextAnchor(fontString, anchorPos, parent, xOff, yOff, defaultPos)
    if not fontString then return end
    fontString:ClearAllPoints()
    local justify = GetSafeJustify(anchorPos or defaultPos)
    local x = tonumber(xOff) or (justify == "LEFT" and 4 or (justify == "RIGHT" and -4 or 0))
    local y = tonumber(yOff) or 0
    fontString:SetPoint(justify, parent, justify, x, y)
    fontString:SetJustifyH(justify)
end

function WF.BarEngine:PrepareRender()
    wipe(ActiveKeys)
end

function WF.BarEngine:AcquireFrame(key)
    if not key then key = "Default" end
    ActiveKeys[key] = true
    
    if not FramePool[key] then
        local f = CreateFrame("Frame", "WF_EngineBar_" .. key, UIParent)
        f.ignoreBackdrop = true; if f.SetBackdrop then f:SetBackdrop(nil) end
        
        f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -1); f.bg:SetAllPoints()
        
        f.iconFrame = CreateFrame("Frame", nil, f); f.iconFrame:SetFrameLevel(f:GetFrameLevel() + 1)
        f.iconFrame.ignoreBackdrop = true; if f.iconFrame.SetBackdrop then f.iconFrame:SetBackdrop(nil) end
        
        f.icon = f.iconFrame:CreateTexture(nil, "ARTWORK"); f.icon:SetAllPoints(); f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        
        f.chargeBar = CreateFrame("StatusBar", nil, f); f.chargeBar:SetFrameLevel(f:GetFrameLevel() + 1); f.chargeBar:SetAllPoints()
        f.chargeBar.ignoreBackdrop = true; if f.chargeBar.SetBackdrop then f.chargeBar:SetBackdrop(nil) end
        
        f.refreshCharge = CreateFrame("StatusBar", nil, f); f.refreshCharge:SetFrameLevel(f:GetFrameLevel() + 1)
        f.refreshCharge.ignoreBackdrop = true; if f.refreshCharge.SetBackdrop then f.refreshCharge:SetBackdrop(nil) end
        
        f.iconBorder = AddBoxBorder(f.iconFrame); f.sbBorder = AddBoxBorder(f)
        
        f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.cd.ignoreBackdrop = true; if f.cd.SetBackdrop then f.cd:SetBackdrop(nil) end
        f.cd:SetDrawSwipe(false); f.cd:SetDrawEdge(false); f.cd:SetDrawBling(false)
        
        pcall(f.cd.SetSwipeColor, f.cd, 0, 0, 0, 0)
        if not f.cd._WFHooked then
            hooksecurefunc(f.cd, "SetDrawSwipe", function(self, draw) 
                if draw and not self._isMutingSwipe then 
                    self._isMutingSwipe = true; self:SetDrawSwipe(false); self._isMutingSwipe = false 
                end 
            end)
            f.cd._WFHooked = true
        end
        
        f.cd.noCooldownOverride = true; f.cd.noOCC = true; f.cd.skipElvUICooldown = true; f.cd.noCooldownCount = false
        f.cd:SetHideCountdownNumbers(false); f.cd:SetFrameLevel(f:GetFrameLevel() + 20)
        
        local textFrame = CreateFrame("Frame", nil, f)
        textFrame:SetAllPoints(); textFrame:SetFrameLevel(f:GetFrameLevel() + 50)
        f.stackText = textFrame:CreateFontString(nil, "OVERLAY", nil, 7)
        
        for _, region in pairs({f.cd:GetRegions()}) do 
            if region:IsObjectType("FontString") then 
                f.timerText = region
                f.timerText:SetDrawLayer("OVERLAY", 7)
                break 
            end 
        end
        FramePool[key] = f
    end
    
    FramePool[key]:Show()
    return FramePool[key]
end

function WF.BarEngine:CleanupUnused()
    for k, f in pairs(FramePool) do if not ActiveKeys[k] then f:Hide(); pcall(f.cd.Clear, f.cd) end end
end

function WF.BarEngine:ReleaseAll()
    for _, f in pairs(FramePool) do f:Hide(); pcall(f.cd.Clear, f.cd) end
    wipe(ActiveKeys)
end

function WF.BarEngine:ApplyStyle(f, visualConfig)
    local texPath = LSM:Fetch("statusbar", visualConfig.texture or "Wish2") or "Interface\\Buttons\\WHITE8x8"
    local bgTexPath = LSM:Fetch("statusbar", visualConfig.bgTexture or "Wish2") or "Interface\\Buttons\\WHITE8x8"
    local fontPath = LSM:Fetch("font", visualConfig.font or "Expressway") or STANDARD_TEXT_FONT
    local fSize = tonumber(visualConfig.fontSize) or 12

    f.bg:SetTexture(bgTexPath)
    
    local bgC = visualConfig.bgColor or DEFAULT_BG_COLOR
    f.bg:SetVertexColor(tonumber(bgC.r) or 0, tonumber(bgC.g) or 0, tonumber(bgC.b) or 0, tonumber(bgC.a) or 0.5)
    
    local c = visualConfig.color or DEFAULT_BAR_COLOR
    local reverse = visualConfig.reverseFill and true or false
    
    f.chargeBar:SetReverseFill(reverse); f.refreshCharge:SetReverseFill(reverse)
    f.chargeBar:SetStatusBarTexture(texPath)
    
    local fgAlpha = tonumber(c.a) or 1
    f.chargeBar:SetStatusBarColor(tonumber(c.r) or 1, tonumber(c.g) or 1, tonumber(c.b) or 1, fgAlpha)
    
    f.refreshCharge:SetStatusBarTexture(texPath)
    f.refreshCharge:SetStatusBarColor(tonumber(c.r) or 1, tonumber(c.g) or 1, tonumber(c.b) or 1, fgAlpha * 0.8)

    local tC = visualConfig.textColor or visualConfig.color or {r=1, g=1, b=1, a=1}
    f.stackText:SetFont(fontPath, fSize + 2, "OUTLINE")
    f.stackText:SetTextColor(tonumber(tC.r) or 1, tonumber(tC.g) or 1, tonumber(tC.b) or 1, tonumber(tC.a) or 1)

    if f.timerText then
        if f.timerText.FontTemplate then f.timerText:FontTemplate(fontPath, fSize, "OUTLINE") else f.timerText:SetFont(fontPath, fSize, "OUTLINE") end
        f.timerText:SetTextColor(tonumber(tC.r) or 1, tonumber(tC.g) or 1, tonumber(tC.b) or 1, tonumber(tC.a) or 1)
    end
    if visualConfig.iconID then f.icon:SetTexture(visualConfig.iconID) end

    local isTextMode = (visualConfig.displayMode == "text")
    local showStack = (visualConfig.textEnable ~= false)
    local showTimer = (visualConfig.timerEnable ~= false)

    if isTextMode then showStack = false end

    if not showStack then
        f.stackText:SetText("")
        f.stackText:SetAlpha(0)
        f.stackText:Hide()
    else
        f.stackText:SetAlpha(1)
    end

    if f.timerText then f.timerText:SetAlpha(showTimer and 1 or 0) end
    f.cd:SetHideCountdownNumbers(not showTimer)
    f.cd.noCooldownCount = false

    if visualConfig.useStatusBar then
        f.iconFrame:Hide(); f.cd:SetDrawSwipe(false); f.cd:Show()
        
        if isTextMode then
            f.bg:Hide()
            if f.sbBorder then f.sbBorder:Hide() end
            f.chargeBar:SetAlpha(0)
            f.refreshCharge:SetAlpha(0)
        else
            f.bg:Show()
            if f.sbBorder then f.sbBorder:Show() end
            f.chargeBar:SetAlpha(1)
            f.refreshCharge:SetAlpha(1)
        end

        if showStack then ApplyTextAnchor(f.stackText, visualConfig.textAnchor, f, visualConfig.xOffset, visualConfig.yOffset, "LEFT") end
        if not visualConfig.dynamicTimer and f.timerText and showTimer then ApplyTextAnchor(f.timerText, visualConfig.timerAnchor, f, visualConfig.timerXOffset, visualConfig.timerYOffset, "RIGHT") end
    else
        f.iconFrame:Hide(); f.bg:Hide(); f.sbBorder:Hide(); f.chargeBar:Hide(); f.refreshCharge:Hide()
        f.cd:SetDrawSwipe(false); f.cd:SetDrawEdge(false); f.cd:SetDrawBling(false); f.cd:Show()
        if showStack then ApplyTextAnchor(f.stackText, visualConfig.textAnchor, f, visualConfig.xOffset, visualConfig.yOffset, "CENTER") end
        if f.timerText and showTimer then ApplyTextAnchor(f.timerText, visualConfig.timerAnchor, f, visualConfig.timerXOffset, visualConfig.timerYOffset, "CENTER") end
    end
end

function WF.BarEngine:UpdateState(f, state, visualConfig)
    if not f then return end
    f.maxVal = state.maxVal or 1
    f.state = state

    local c = visualConfig.color or DEFAULT_BAR_COLOR
    local r, g, b, a = tonumber(c.r) or 1, tonumber(c.g) or 1, tonumber(c.b) or 1, tonumber(c.a) or 1
    
    local isTextMode = (visualConfig.displayMode == "text")
    local showStack = (visualConfig.textEnable ~= false)
    local showTimer = (visualConfig.timerEnable ~= false)

    if isTextMode then showStack = false end

    if state.isActive then
        f:SetAlpha(1)
        
        if visualConfig.useStatusBar then
            f.chargeBar:SetStatusBarColor(r, g, b, a)
            f.refreshCharge:SetStatusBarColor(r, g, b, a * 0.8)
            
            if isTextMode then
                f.chargeBar:SetAlpha(0)
                f.refreshCharge:SetAlpha(0)
            else
                f.chargeBar:SetAlpha(1)
                f.refreshCharge:SetAlpha(1)
            end
        end

        if not showStack then
            f.stackText:SetText("")
            f.stackText:SetAlpha(0)
            f.stackText:Hide()
        else
            f.stackText:SetAlpha(1)
            local success, isSecret = pcall(SafeIsSecretValue, state.count)
            if success and isSecret then 
                pcall(SafeSetText, f.stackText, state.count)
                f.stackText:Show() 
            else
                local cnt = tonumber(state.count) or 0
                if cnt > 0 then f.stackText:SetText(cnt); f.stackText:Show() else f.stackText:Hide() end
            end
        end
        
        if f.timerText then f.timerText:SetAlpha(showTimer and 1 or 0) end
        f.cd:SetHideCountdownNumbers(not showTimer)
        f.cd.noCooldownCount = false

        if visualConfig.useStatusBar then
            if state.trackType == "buff" and visualConfig.mode == "stack" then
                f.chargeBar:Show(); f.refreshCharge:Hide()
                if f.chargeBar.ClearTimerDuration then pcall(SafeClearTimer, f.chargeBar) end
                f.chargeBar:SetMinMaxValues(0, state.maxVal); f.chargeBar:SetValue(state.count or 0)
                f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.chargeBar) 
                if f.timerText and showTimer then ApplyTextAnchor(f.timerText, visualConfig.timerAnchor, f, visualConfig.timerXOffset, visualConfig.timerYOffset, "RIGHT") end
            elseif state.trackType == "charge" then
                f.chargeBar:Show()
                if f.chargeBar.ClearTimerDuration then pcall(SafeClearTimer, f.chargeBar) end
                f.chargeBar:SetMinMaxValues(0, state.maxVal); f.chargeBar:SetValue(state.count or 0)

                local needsRecharge = false
                local sSuccess, isSecret = pcall(SafeIsSecretValue, state.count)
                if sSuccess and isSecret then needsRecharge = true else local cnt = tonumber(state.count) or 0; if cnt < state.maxVal then needsRecharge = true end end

                if needsRecharge and state.durObjC then
                    local totalW = f:GetWidth(); if not totalW or totalW < 5 then totalW = f.calcWidth or 100 end
                    local maxV = (state.maxVal and state.maxVal > 0) and state.maxVal or 1; local segW = totalW / maxV

                    f.refreshCharge:ClearAllPoints()
                    local tex = f.chargeBar:GetStatusBarTexture()
                    if tex then if visualConfig.reverseFill then f.refreshCharge:SetPoint("RIGHT", tex, "LEFT", 0, 0) else f.refreshCharge:SetPoint("LEFT", tex, "RIGHT", 0, 0) end
                        f.refreshCharge:SetPoint("TOP", f.chargeBar, "TOP", 0, 0); f.refreshCharge:SetPoint("BOTTOM", f.chargeBar, "BOTTOM", 0, 0); f.refreshCharge:SetWidth(segW)
                    end
                    pcall(SafeSetMinMax, f.refreshCharge, 0, 1)
                    local dir = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0
                    if f.refreshCharge.SetTimerDuration then pcall(SafeSetTimer, f.refreshCharge, state.durObjC, dir) end
                    f.refreshCharge:Show(); f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.refreshCharge)
                    if f.timerText and showTimer then ApplyTextAnchor(f.timerText, "CENTER", f.refreshCharge, visualConfig.timerXOffset, visualConfig.timerYOffset, "CENTER") end
                else
                    f.refreshCharge:Hide(); if f.refreshCharge.ClearTimerDuration then pcall(SafeClearTimer, f.refreshCharge) end
                    f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.chargeBar)
                    if f.timerText and showTimer then ApplyTextAnchor(f.timerText, visualConfig.timerAnchor, f, visualConfig.timerXOffset, visualConfig.timerYOffset, "RIGHT") end
                end
            else 
                f.chargeBar:Show(); f.refreshCharge:Hide(); if f.refreshCharge.ClearTimerDuration then pcall(SafeClearTimer, f.refreshCharge) end
                f.chargeBar:SetMinMaxValues(0, 1)
                if state.durObjC then 
                    local dir = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.TimeRemaining or 1
                    if f.chargeBar.SetTimerDuration then pcall(SafeSetTimer, f.chargeBar, state.durObjC, dir) end
                    if f.chargeBar.SetToTargetValue then pcall(SafeSetToTarget, f.chargeBar) end
                else 
                    if f.chargeBar.ClearTimerDuration then pcall(SafeClearTimer, f.chargeBar) end; f.chargeBar:SetValue(1)
                end 
                f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.chargeBar)
                if f.timerText and showTimer then ApplyTextAnchor(f.timerText, visualConfig.timerAnchor, f, visualConfig.timerXOffset, visualConfig.timerYOffset, "RIGHT") end
            end
        end
        if state.durObjC then 
            if f.cd.SetCooldownFromDurationObject and type(state.durObjC) == "userdata" then 
                pcall(SafeSetCooldownObj, f.cd, state.durObjC)
            else 
                local st, dur; if type(state.durObjC) == "userdata" and type(state.durObjC.GetCooldownStartTime) == "function" then st = state.durObjC:GetCooldownStartTime(); dur = state.durObjC:GetCooldownDuration() else st = state.durObjC.startTime; dur = state.durObjC.duration end
                if st and dur and (SafeIsSecretValue(dur) or (tonumber(dur) and tonumber(dur) > 0)) then f.cd:SetCooldown(st, dur) else f.cd:Clear() end 
            end 
        else f.cd:Clear() end
    else
        f.cd:Clear(); f.stackText:Hide(); if f.timerText then f.timerText:Hide() end
        
        local isConfigOpen = WF.MoversUnlocked or (WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown()) or (EditModeManagerFrame and EditModeManagerFrame:IsShown())
        
        if visualConfig.useStatusBar then
            f.chargeBar:Show(); f.refreshCharge:Hide()
            if f.chargeBar.ClearTimerDuration then pcall(SafeClearTimer, f.chargeBar) end
            if f.refreshCharge.ClearTimerDuration then pcall(SafeClearTimer, f.refreshCharge) end
            f.chargeBar:SetMinMaxValues(0, f.maxVal or 1)
            
            if isConfigOpen then
                f.chargeBar:SetValue((f.maxVal or 1) * 0.5)
                local fgAlpha = tonumber(c.a) or 1
                f.chargeBar:SetStatusBarColor(r, g, b, fgAlpha)
                f:SetAlpha(1)
                
                if isTextMode then
                    f.chargeBar:SetAlpha(0)
                    f.bg:Hide()
                    if f.sbBorder then f.sbBorder:Hide() end
                else
                    f.chargeBar:SetAlpha(1)
                    f.bg:Show()
                    if f.sbBorder then f.sbBorder:Show() end
                end
                
                if showTimer and f.timerText then 
                    f.timerText:SetText("5.0"); f.timerText:SetAlpha(1); f.timerText:Show() 
                end
                if showStack then
                    f.stackText:SetText(f.maxVal and f.maxVal > 1 and f.maxVal or "3"); f.stackText:SetAlpha(1); f.stackText:Show()
                end
            else
                f.chargeBar:SetValue(0)
                if visualConfig.alwaysShow then f:SetAlpha(1) else f:SetAlpha(0) end
            end
            f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.chargeBar)
        else
            if isConfigOpen then
                if showTimer and f.timerText then 
                    f.timerText:SetText("5.0"); f.timerText:SetAlpha(1); f.timerText:Show() 
                end
                if showStack then
                    f.stackText:SetText(f.maxVal and f.maxVal > 1 and f.maxVal or "3"); f.stackText:SetAlpha(1); f.stackText:Show()
                end
                f:SetAlpha(1)
            else f:SetAlpha(0) end
        end
    end
end