local AddonName, ns = ...
local WF = ns.WF
local LSM = LibStub("LibSharedMedia-3.0", true)

WF.BarEngine = {}
local FramePool = {}
local ActiveKeys = {}

local DEFAULT_BG_COLOR = {r=0, g=0, b=0, a=0.5}
local DEFAULT_BAR_COLOR = {r=0, g=0.8, b=1, a=1}

-- 【修复 BUG：获取真实的屏幕物理像素，防止缩放抗锯齿把边框“吞掉”】
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
        local m = GetOnePixelSize() -- 使用精准的物理 1 像素
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
        
        pcall(function() f.cd:SetSwipeColor(0, 0, 0, 0) end)
        if not f.cd._WFHooked then
            hooksecurefunc(f.cd, "SetDrawSwipe", function(self, draw) 
                if draw and not self._isMutingSwipe then 
                    self._isMutingSwipe = true; self:SetDrawSwipe(false); self._isMutingSwipe = false 
                end 
            end)
            f.cd._WFHooked = true
        end
        
        f.cd.noCooldownOverride = true; f.cd.noOCC = true; f.cd.skipElvUICooldown = true
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
    for k, f in pairs(FramePool) do if not ActiveKeys[k] then f:Hide(); pcall(function() f.cd:Clear() end) end end
end

function WF.BarEngine:ReleaseAll()
    for _, f in pairs(FramePool) do f:Hide(); pcall(function() f.cd:Clear() end) end
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

    f.stackText:SetFont(fontPath, fSize + 2, "OUTLINE"); f.stackText:SetTextColor(1, 1, 1, 1)

    if f.timerText then
        if f.timerText.FontTemplate then f.timerText:FontTemplate(fontPath, fSize, "OUTLINE") else f.timerText:SetFont(fontPath, fSize, "OUTLINE") end
        f.timerText:SetTextColor(1, 1, 1, 1)
    end
    if visualConfig.iconID then f.icon:SetTexture(visualConfig.iconID) end

    if visualConfig.textEnable == false then
        f.stackText:SetText("")
        f.stackText:SetAlpha(0)
        f.stackText:Hide()
    end

    if visualConfig.useStatusBar then
        f.iconFrame:Hide(); f.cd:SetDrawSwipe(false); f.cd:Show()
        f.bg:Show(); f.sbBorder:Show()
        if visualConfig.textEnable ~= false then ApplyTextAnchor(f.stackText, visualConfig.textAnchor, f, visualConfig.xOffset, visualConfig.yOffset, "LEFT") end
        if not visualConfig.dynamicTimer and f.timerText then ApplyTextAnchor(f.timerText, visualConfig.timerAnchor, f, visualConfig.timerXOffset, visualConfig.timerYOffset, "RIGHT") end
    else
        f.iconFrame:Hide(); f.bg:Hide(); f.sbBorder:Hide(); f.chargeBar:Hide(); f.refreshCharge:Hide()
        f.cd:SetDrawSwipe(false); f.cd:SetDrawEdge(false); f.cd:SetDrawBling(false); f.cd:Show()
        if visualConfig.textEnable ~= false then ApplyTextAnchor(f.stackText, visualConfig.textAnchor, f, visualConfig.xOffset, visualConfig.yOffset, "CENTER") end
        if f.timerText then ApplyTextAnchor(f.timerText, visualConfig.timerAnchor, f, visualConfig.timerXOffset, visualConfig.timerYOffset, "CENTER") end
    end
end

function WF.BarEngine:UpdateState(f, state, visualConfig)
    if not f then return end
    f.maxVal = state.maxVal or 1
    f.state = state

    local c = visualConfig.color or DEFAULT_BAR_COLOR
    local r, g, b, a = tonumber(c.r) or 1, tonumber(c.g) or 1, tonumber(c.b) or 1, tonumber(c.a) or 1
    
    local currentCount = tonumber(state.count) or 0
    if tostring(state.spellID) == "187880" and currentCount >= 5 then
        r, g, b = 1, 0.5, 0  
    end

    if state.isActive then
        f:SetAlpha(1)
        
        if visualConfig.useStatusBar then
            f.chargeBar:SetStatusBarColor(r, g, b, a)
            f.refreshCharge:SetStatusBarColor(r, g, b, a * 0.8)
        end

        if visualConfig.textEnable == false then
            f.stackText:SetText("")
            f.stackText:SetAlpha(0)
            f.stackText:Hide()
        else
            local success, isSecret = pcall(function() return type(state.count) == "number" and type(issecretvalue) == "function" and issecretvalue(state.count) end)
            if success and isSecret then pcall(function() f.stackText:SetText(state.count) end); f.stackText:Show() else
                local cnt = tonumber(state.count) or 0; if cnt > 0 then f.stackText:SetText(cnt); f.stackText:Show() else f.stackText:Hide() end
            end
        end
        
        if f.timerText then
            if visualConfig.timerEnable == false then f.timerText:SetAlpha(0) else f.timerText:SetAlpha(1) end
        end

        if visualConfig.useStatusBar then
            if state.trackType == "buff" and visualConfig.mode == "stack" then
                f.chargeBar:Show(); f.refreshCharge:Hide()
                if f.chargeBar.ClearTimerDuration then pcall(function() f.chargeBar:ClearTimerDuration() end) end
                f.chargeBar:SetMinMaxValues(0, state.maxVal); f.chargeBar:SetValue(state.count or 0)
                f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.chargeBar) 
                if f.timerText then ApplyTextAnchor(f.timerText, visualConfig.timerAnchor, f, visualConfig.timerXOffset, visualConfig.timerYOffset, "RIGHT") end
            elseif state.trackType == "charge" then
                f.chargeBar:Show()
                if f.chargeBar.ClearTimerDuration then pcall(function() f.chargeBar:ClearTimerDuration() end) end
                f.chargeBar:SetMinMaxValues(0, state.maxVal); f.chargeBar:SetValue(state.count or 0)

                local needsRecharge = false
                local sSuccess, isSecret = pcall(function() return type(state.count) == "number" and issecretvalue(state.count) end)
                if sSuccess and isSecret then needsRecharge = true else local cnt = tonumber(state.count) or 0; if cnt < state.maxVal then needsRecharge = true end end

                if needsRecharge and state.durObjC then
                    local totalW = f:GetWidth(); if not totalW or totalW < 5 then totalW = f.calcWidth or 100 end
                    local maxV = (state.maxVal and state.maxVal > 0) and state.maxVal or 1; local segW = totalW / maxV

                    f.refreshCharge:ClearAllPoints()
                    local tex = f.chargeBar:GetStatusBarTexture()
                    if tex then if visualConfig.reverseFill then f.refreshCharge:SetPoint("RIGHT", tex, "LEFT", 0, 0) else f.refreshCharge:SetPoint("LEFT", tex, "RIGHT", 0, 0) end
                        f.refreshCharge:SetPoint("TOP", f.chargeBar, "TOP", 0, 0); f.refreshCharge:SetPoint("BOTTOM", f.chargeBar, "BOTTOM", 0, 0); f.refreshCharge:SetWidth(segW)
                    end
                    pcall(function() f.refreshCharge:SetMinMaxValues(0, 1) end)
                    local dir = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0
                    if f.refreshCharge.SetTimerDuration then pcall(function() f.refreshCharge:SetTimerDuration(state.durObjC, 0, dir) end) end
                    f.refreshCharge:Show(); f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.refreshCharge)
                    if f.timerText then ApplyTextAnchor(f.timerText, "CENTER", f.refreshCharge, visualConfig.timerXOffset, visualConfig.timerYOffset, "CENTER") end
                else
                    f.refreshCharge:Hide(); if f.refreshCharge.ClearTimerDuration then pcall(function() f.refreshCharge:ClearTimerDuration() end) end
                    f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.chargeBar)
                    if f.timerText then ApplyTextAnchor(f.timerText, visualConfig.timerAnchor, f, visualConfig.timerXOffset, visualConfig.timerYOffset, "RIGHT") end
                end
            else 
                f.chargeBar:Show(); f.refreshCharge:Hide(); if f.refreshCharge.ClearTimerDuration then pcall(function() f.refreshCharge:ClearTimerDuration() end) end
                f.chargeBar:SetMinMaxValues(0, 1)
                if state.durObjC then 
                    local dir = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.TimeRemaining or 1
                    if f.chargeBar.SetTimerDuration then pcall(function() f.chargeBar:SetTimerDuration(state.durObjC, 0, dir) end) end
                    if f.chargeBar.SetToTargetValue then pcall(function() f.chargeBar:SetToTargetValue() end) end
                else 
                    if f.chargeBar.ClearTimerDuration then pcall(function() f.chargeBar:ClearTimerDuration() end) end; f.chargeBar:SetValue(1)
                end 
                f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.chargeBar)
                if f.timerText then ApplyTextAnchor(f.timerText, visualConfig.timerAnchor, f, visualConfig.timerXOffset, visualConfig.timerYOffset, "RIGHT") end
            end
        end
        if state.durObjC then 
            if f.cd.SetCooldownFromDurationObject and type(state.durObjC) == "userdata" then pcall(function() f.cd:SetCooldownFromDurationObject(state.durObjC) end) else 
                local st, dur; if type(state.durObjC) == "userdata" and type(state.durObjC.GetCooldownStartTime) == "function" then st = state.durObjC:GetCooldownStartTime(); dur = state.durObjC:GetCooldownDuration() else st = state.durObjC.startTime; dur = state.durObjC.duration end
                if st and dur and (IsSecret(dur) or (tonumber(dur) and tonumber(dur) > 0)) then f.cd:SetCooldown(st, dur) else f.cd:Clear() end 
            end 
        else f.cd:Clear() end
    else
        f.cd:Clear(); f.stackText:Hide(); if f.timerText then f.timerText:Hide() end
        if visualConfig.useStatusBar then
            f.chargeBar:Show(); f.refreshCharge:Hide()
            if f.chargeBar.ClearTimerDuration then pcall(function() f.chargeBar:ClearTimerDuration() end) end
            if f.refreshCharge.ClearTimerDuration then pcall(function() f.refreshCharge:ClearTimerDuration() end) end
            f.chargeBar:SetMinMaxValues(0, f.maxVal or 1)
            
            local isConfigOpen = WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown()
            if isConfigOpen then
                f.chargeBar:SetValue((f.maxVal or 1) * 0.5)
                local fgAlpha = tonumber(c.a) or 1
                f.chargeBar:SetStatusBarColor(r, g, b, fgAlpha)
                f:SetAlpha(1)
            else
                f.chargeBar:SetValue(0)
                if visualConfig.alwaysShow then f:SetAlpha(1) else f:SetAlpha(0) end
            end
            f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.chargeBar)
        else
            local isConfigOpen = WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown()
            if isConfigOpen then
                if visualConfig.timerEnable ~= false and f.timerText then f.timerText:SetText("5.0"); f.timerText:SetAlpha(1); f.timerText:Show() end
                f:SetAlpha(1)
            else f:SetAlpha(0) end
        end
    end
end