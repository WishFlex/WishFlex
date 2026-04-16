local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local CDMod = WF.CooldownCustomAPI
local LSM = LibStub("LibSharedMedia-3.0", true)

local DEFAULT_SWIPE_COLOR = {r = 0, g = 0, b = 0, a = 0.5}
local DEFAULT_ACTIVE_AURA_COLOR = {r = 0, g = 0, b = 0, a = 0.5}

local SafeHide = function(self) if self:IsShown() then self:Hide() end; if self:GetAlpha() > 0 then self:SetAlpha(0) end end
local SafeEquals = function(v, expected) 
    local ok, res = pcall(function() return v == expected end)
    return ok and res 
end

function CDMod.ApplyElvUISkin(targetObj, parentFrame)
    if not targetObj then return nil end
    if not targetObj.wishBd then
        local bd = CreateFrame("Frame", nil, parentFrame)
        local parentLvl = (parentFrame and parentFrame.GetFrameLevel and parentFrame:GetFrameLevel()) or 1
        if targetObj.GetFrameLevel then bd:SetFrameLevel(math.max(0, targetObj:GetFrameLevel() - 1)) else bd:SetFrameLevel(math.max(0, parentLvl)) end
        
        bd.ignoreBackdrop = true
        if bd.SetBackdrop then pcall(function() bd:SetBackdrop(nil) end) end
        bd.CreateBackdrop = function() end; bd.SetTemplate = function() end
        
        local m = CDMod.GetOnePixelSize()
        local function DrawEdge(p1, p2, x, y, w, h)
            local t = bd:CreateTexture(nil, "BORDER", nil, 1); t:SetColorTexture(0, 0, 0, 1)
            t:SetPoint(p1, bd, p1, x, y); t:SetPoint(p2, bd, p2, x, y)
            if w then t:SetWidth(m) end; if h then t:SetHeight(m) end
            if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
            if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
            return t
        end
        bd.top = DrawEdge("TOPLEFT", "TOPRIGHT", 0, 0, nil, 1); bd.bottom = DrawEdge("BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, nil, 1)
        bd.left = DrawEdge("TOPLEFT", "BOTTOMLEFT", 0, 0, 1, nil); bd.right = DrawEdge("TOPRIGHT", "BOTTOMRIGHT", 0, 0, 1, nil)
        if targetObj.IsObjectType and targetObj:IsObjectType("Texture") then targetObj:SetDrawLayer("ARTWORK", 1) end
        targetObj.wishBd = bd
    end
    local m = CDMod.GetOnePixelSize()
    targetObj:ClearAllPoints()
    targetObj:SetPoint("TOPLEFT", targetObj.wishBd, "TOPLEFT", m, -m)
    targetObj:SetPoint("BOTTOMRIGHT", targetObj.wishBd, "BOTTOMRIGHT", -m, m)
    return targetObj.wishBd
end

function CDMod.RemoveBarIconMask(parentFrame, iconTex)
    if not parentFrame or type(parentFrame.GetRegions) ~= "function" then return end
    if not iconTex or type(iconTex.RemoveMaskTexture) ~= "function" then return end
    if parentFrame._wfMaskRemoved then return end
    local regions = { parentFrame:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region and region.IsObjectType and region:IsObjectType("MaskTexture") then
            if region:GetAtlas() == "UI-HUD-CoolDownManager-Mask" then pcall(function() iconTex:RemoveMaskTexture(region) end); parentFrame._wfMaskRemoved = true; break end
        end
    end
end

function CDMod.ApplyTexCoord(texture, w, h) 
    if not texture or not w or not h or h == 0 then return end
    local ratio = w / h
    if ratio == 1 then texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif ratio > 1 then local offset = (1 - (h/w)) / 2 * 0.84; texture:SetTexCoord(0.08, 0.92, 0.08 + offset, 0.92 - offset)
    else local offset = (1 - (w/h)) / 2 * 0.84; texture:SetTexCoord(0.08 + offset, 0.92 - offset, 0.08, 0.92) end
end

function CDMod.SuppressDebuffBorder(f)
    if not f or f._wishBorderSuppressed then return end; f._wishBorderSuppressed = true
    
    local borders = { 
        f.Background, f.bg, f.PandemicIcon, f.DebuffBorder, f.Border, f.IconBorder, f.IconOverlay, f.overlay, f.ExpireBorder, 
        f.Icon and f.Icon.Border, f.Icon and f.Icon.IconBorder, f.Icon and f.Icon.DebuffBorder, f.Icon and f.Icon.bg, f.Icon and f.Icon.Background,
        f.Bar and f.Bar.Border, f.Bar and f.Bar.BarBG, f.Bar and f.Bar.Pip, f.Bar and f.Bar.bg, f.Bar and f.Bar.Background 
    }
    for i = 1, #borders do 
        local border = borders[i]
        if border then 
            border:Hide(); border:SetAlpha(0); hooksecurefunc(border, "Show", SafeHide) 
            if border.SetAlpha then hooksecurefunc(border, "SetAlpha", function(s, a) if a > 0 and not s._wishAlphaLock then s._wishAlphaLock = true; s:SetAlpha(0); s._wishAlphaLock = false end end) end
        end 
    end
    if f.DebuffBorder and f.DebuffBorder.UpdateFromAuraData then hooksecurefunc(f.DebuffBorder, "UpdateFromAuraData", SafeHide) end
    if f.ShowPandemicStateFrame then hooksecurefunc(f, "ShowPandemicStateFrame", function(self) if self.PandemicIcon then if self.PandemicIcon:IsShown() then self.PandemicIcon:Hide() end; self.PandemicIcon:SetAlpha(0) end end) end
    
    for i = 1, select("#", f:GetRegions()) do 
        local region = select(i, f:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("Texture") then 
            local isOverlay = false
            pcall(function() isOverlay = (region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" or region:GetTexture() == 6707800) end)
            if isOverlay then 
                region:SetAlpha(0); region:Hide(); hooksecurefunc(region, "Show", SafeHide) 
            end 
        end 
    end
end

local function ForceSwipeColor(self, r, g, b, a)
    local b_parent = self:GetParent()
    local cddb = WF.db.cooldownCustom
    local sc = (b_parent and b_parent.wasSetFromAura) and (cddb.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR) or (cddb.swipeColor or DEFAULT_SWIPE_COLOR)
    if r == sc.r and g == sc.g and b == sc.b and a == sc.a then return end
    self:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
end

function CDMod:ApplySwipeSettings(frame) 
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end
    if not frame or not frame.Cooldown then return end
    if frame.CooldownFlash and not frame._wishFlashHooked then
        hooksecurefunc(frame.CooldownFlash, "Show", function(self) self:Hide(); if self.FlashAnim then self.FlashAnim:Stop() end end)
        if frame.CooldownFlash.FlashAnim and frame.CooldownFlash.FlashAnim.Play then hooksecurefunc(frame.CooldownFlash.FlashAnim, "Play", function(self) self:Stop(); frame.CooldownFlash:Hide() end) end
        frame._wishFlashHooked = true
    end

    local function ApplyToCooldown(cd, isMain)
        local db = WF.db.cooldownCustom; local rev = db.reverseSwipe; if rev == nil then rev = true end
        cd:SetReverse(rev); cd:SetUseCircularEdge(false)
        
        local iconTex = frame.Icon and (frame.Icon.Icon or frame.Icon) or frame
        local realAnchor = iconTex.wishBd or iconTex
        cd:ClearAllPoints(); cd:SetAllPoints(realAnchor); cd:SetFrameLevel(frame:GetFrameLevel() + (isMain and 2 or 1))

        if not cd._wishCDHooked then
            cd._isMutingTex = true; cd:SetSwipeTexture("Interface\\Buttons\\WHITE8x8"); cd._isMutingTex = false
            hooksecurefunc(cd, "SetSwipeTexture", function(self, tex) if tex ~= "Interface\\Buttons\\WHITE8x8" and not self._isMutingTex then self._isMutingTex = true; self:SetSwipeTexture("Interface\\Buttons\\WHITE8x8"); self._isMutingTex = false end end)
            cd._isMutingSwipe = true; cd:SetDrawSwipe(true); cd._isMutingSwipe = false
            hooksecurefunc(cd, "SetDrawSwipe", function(self, draw) if not draw and not self._isMutingSwipe then self._isMutingSwipe = true; self:SetDrawSwipe(true); self._isMutingSwipe = false end end)
            cd._isMutingEdge = true; cd:SetDrawEdge(false); cd._isMutingEdge = false
            hooksecurefunc(cd, "SetDrawEdge", function(self, draw) if draw and not self._isMutingEdge then self._isMutingEdge = true; self:SetDrawEdge(false); self._isMutingEdge = false end end)
            cd._isMutingBling = true; cd:SetDrawBling(false); cd._isMutingBling = false
            hooksecurefunc(cd, "SetDrawBling", function(self, draw) if draw and not self._isMutingBling then self._isMutingBling = true; self:SetDrawBling(false); self._isMutingBling = false end end)
            
            hooksecurefunc(cd, "SetSwipeColor", function(self, ... ) if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end; ForceSwipeColor(self, ...) end)
            local function RefreshCDState(self)
                if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end
                if not self._isMutingTex then self._isMutingTex=true; self:SetSwipeTexture("Interface\\Buttons\\WHITE8x8"); self._isMutingTex=false end
                if not self._isMutingSwipe then self._isMutingSwipe=true; self:SetDrawSwipe(true); self._isMutingSwipe=false end
                if not self._isMutingEdge then self._isMutingEdge=true; self:SetDrawEdge(false); self._isMutingEdge=false end
                if not self._isMutingBling then self._isMutingBling=true; self:SetDrawBling(false); self._isMutingBling=false end
                ForceSwipeColor(self)
            end
            hooksecurefunc(cd, "SetCooldown", RefreshCDState)
            if cd.SetCooldownFromDurationObject then hooksecurefunc(cd, "SetCooldownFromDurationObject", RefreshCDState) end
            cd._wishCDHooked = true
        end
        ForceSwipeColor(cd)
    end
    if frame.Cooldown then ApplyToCooldown(frame.Cooldown, true) end
    for _, child in pairs({frame:GetChildren()}) do if child:IsObjectType("Cooldown") and child ~= frame.Cooldown then ApplyToCooldown(child, false) end end
end

local function FormatText(t, isStack, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, targetRefStack, targetRefCD) 
    if not t or type(t) ~= "table" or not t.SetFont then return end
    local size = isStack and stackSize or cdSize; local color = isStack and stackColor or cdColor; local pos = isStack and stackPos or cdPos or "CENTER"; local ox = isStack and stackX or cdX or 0; local oy = isStack and stackY or cdY or 0
    local ref = isStack and targetRefStack or targetRefCD
    t:SetFont(fontPath, size, outline); t:SetTextColor(color.r, color.g, color.b); t:ClearAllPoints(); t:SetPoint(pos, ref, pos, ox, oy); t:SetDrawLayer("OVERLAY", 7) 
end

function CDMod:ApplyText(frame, category)
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
    local db = WF.db.cooldownCustom; local cfg = db[category]; if not cfg then return end
    local fontPath = (LSM and LSM:Fetch('font', db.countFont)) or STANDARD_TEXT_FONT; local outline = db.countFontOutline or "OUTLINE"
    local cdSize, cdColor, cdPos, cdX, cdY = cfg.cdFontSize, cfg.cdFontColor, cfg.cdPosition or "CENTER", cfg.cdXOffset or 0, cfg.cdYOffset or 0
    local stackSize, stackColor, stackPos, stackX, stackY = cfg.stackFontSize, cfg.stackFontColor, cfg.stackPosition or "BOTTOMRIGHT", cfg.stackXOffset or 0, cfg.stackYOffset or 0
    
    if not frame.wishTextContainer then 
        frame.wishTextContainer = CreateFrame("Frame", nil, frame)
        frame.wishTextContainer.ignoreBackdrop = true
        if frame.wishTextContainer.SetBackdrop then pcall(function() frame.wishTextContainer:SetBackdrop(nil) end) end
        frame.wishTextContainer.CreateBackdrop = function() end; frame.wishTextContainer.SetTemplate = function() end
        frame.wishTextContainer:SetAllPoints() 
    end
    frame.wishTextContainer:SetFrameLevel(frame:GetFrameLevel() + 10)

    local targetRefStack = frame; local targetRefCD = frame
    if category == "BuffBar" then
        if cfg.showIcon ~= false then
            local iconObj = type(frame.Icon) == "table" and (frame.Icon.IsObjectType and frame.Icon:IsObjectType("Texture") and frame.Icon or frame.Icon.Icon) or frame.Icon
            targetRefStack = iconObj and iconObj.wishBd or iconObj or frame; targetRefCD = frame.Bar and frame.Bar.wishBd or frame.Bar or frame
        else 
            targetRefStack = frame.Bar and frame.Bar.wishBd or frame.Bar or frame; targetRefCD = targetRefStack 
        end
    else
        local iconObj = type(frame.Icon) == "table" and (frame.Icon.IsObjectType and frame.Icon:IsObjectType("Texture") and frame.Icon or frame.Icon.Icon) or frame.Icon
        targetRefStack = iconObj and iconObj.wishBd or iconObj or frame; targetRefCD = targetRefStack
    end
    
    local stackFS
    if frame.Applications and frame.Applications.Applications then stackFS = frame.Applications.Applications
    elseif frame.ChargeCount and frame.ChargeCount.Current then stackFS = frame.ChargeCount.Current
    elseif frame.Count and type(frame.Count) == "table" and frame.Count.IsObjectType and frame.Count:IsObjectType("FontString") then stackFS = frame.Count end

    if stackFS then
        local parent = stackFS:GetParent()
        if parent and type(parent.SetFrameLevel) == "function" then
            local targetLevel = frame:GetFrameLevel() + 7
            if parent:GetFrameLevel() ~= targetLevel then parent:SetFrameLevel(targetLevel) end
        end
        FormatText(stackFS, true, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, targetRefStack, targetRefCD)
    end

    if frame.Cooldown then 
        if frame.Cooldown.timer and frame.Cooldown.timer.text then FormatText(frame.Cooldown.timer.text, false, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, targetRefStack, targetRefCD) end
        for k = 1, select("#", frame.Cooldown:GetRegions()) do 
            local region = select(k, frame.Cooldown:GetRegions()); 
            if region and region.IsObjectType and region:IsObjectType("FontString") and region ~= stackFS then FormatText(region, false, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, targetRefStack, targetRefCD) end 
        end 
    end
end

local function ApplyIconAlignment(f, w, h)
    local isTex = type(f.Icon) == "table" and f.Icon.IsObjectType and f.Icon:IsObjectType("Texture")
    local iconTex = isTex and f.Icon or (f.Icon and f.Icon.Icon) or f.Icon
    local iconFrame = isTex and f or f.Icon

    if iconTex then
        local iconBd = CDMod.ApplyElvUISkin(iconTex, iconFrame)
        iconBd:SetSize(w, h); iconBd:Show()

        -- 【VFLOW 级架构】：整体移动并缩放原生 f.Icon 框架
        if not isTex and f.Icon then
            f.Icon:SetSize(w, h)
            f.Icon:ClearAllPoints()
            f.Icon:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
            
            iconBd:ClearAllPoints()
            iconBd:SetAllPoints(f.Icon)
        else
            iconBd:ClearAllPoints()
            iconBd:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        end

        if iconTex.Show then iconTex:Show() end
        CDMod.ApplyTexCoord(iconTex, w, h)
    end
end

local function ApplyBarAlignment(f, cfg, w, h, barH, gap)
    local iconPos = cfg.iconPosition or "LEFT"; local barPos = cfg.barPosition or "CENTER"; local showIcon = (cfg.showIcon ~= false) 
    f._wf_showIcon = showIcon 
    
    local isTex = type(f.Icon) == "table" and f.Icon.IsObjectType and f.Icon:IsObjectType("Texture")
    local iconTex = isTex and f.Icon or (f.Icon and f.Icon.Icon) or f.Icon
    local iconFrame = isTex and f or f.Icon
    local barObj = f.Bar or f.StatusBar

    -- AYIJE 防御：封印进度条自带底色和材质
    if barObj then
        if barObj.BarBG then
            barObj.BarBG:Hide(); barObj.BarBG:SetAlpha(0)
            if not barObj._wf_bgHooked then
                hooksecurefunc(barObj.BarBG, "Show", SafeHide)
                if barObj.BarBG.SetAlpha then hooksecurefunc(barObj.BarBG, "SetAlpha", function(s, a) if a > 0 and not s._wishAlphaLock then s._wishAlphaLock = true; s:SetAlpha(0); s._wishAlphaLock = false end end) end
                barObj._wf_bgHooked = true
            end
        end
        if barObj.Pip then
            barObj.Pip:Hide(); barObj.Pip:SetAlpha(0)
            if not barObj._wf_pipHooked then
                hooksecurefunc(barObj.Pip, "Show", SafeHide)
                if barObj.Pip.SetAlpha then hooksecurefunc(barObj.Pip, "SetAlpha", function(s, a) if a > 0 and not s._wishAlphaLock then s._wishAlphaLock = true; s:SetAlpha(0); s._wishAlphaLock = false end end) end
                barObj._wf_pipHooked = true
            end
        end
    end
    
    local iconBd = CDMod.ApplyElvUISkin(iconTex, iconFrame)
    local barBd = CDMod.ApplyElvUISkin(barObj, f)
    
    iconBd:ClearAllPoints(); barBd:ClearAllPoints()
    
    local itemH = math.max(h, barH)
    local actualBarW = w
    
    if showIcon then
        if f.Cooldown then f.Cooldown:SetAlpha(1) end
        iconBd:SetSize(h, h); iconBd:Show()
        
        if not isTex and f.Icon and f.Icon.Show then f.Icon:Show() end
        if iconTex and iconTex.Show then iconTex:Show() end
        if iconTex and iconTex.SetTexCoord then CDMod.ApplyTexCoord(iconTex, h, h) end 
        
        actualBarW = math.max(1, w - h - gap); barBd:SetSize(actualBarW, barH); barBd:Show()
        
        local iconY, barY
        if barPos == "TOP" then 
            iconY = itemH - h; barY = itemH - barH 
        elseif barPos == "BOTTOM" then 
            iconY = 0; barY = 0 
        else 
            iconY = CDMod.PixelSnap((itemH - h) / 2); barY = CDMod.PixelSnap((itemH - barH) / 2) 
        end
        
        local iconX, barX = 0, 0
        if iconPos == "LEFT" then 
            iconX = 0; barX = h + gap
        else 
            barX = 0; iconX = actualBarW + gap
        end

        -- 【VFLOW 级核心架构修复】：带着所有暴雪原生底图，整体移动原生 f.Icon 框架！
        if not isTex and f.Icon then
            f.Icon:SetSize(h, h)
            f.Icon:ClearAllPoints()
            f.Icon:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", iconX, iconY)
            
            iconBd:ClearAllPoints()
            iconBd:SetAllPoints(f.Icon)
        else
            iconBd:ClearAllPoints()
            iconBd:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", iconX, iconY)
        end
        
        barBd:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", barX, barY)
    else
        if f.Cooldown then 
            f.Cooldown:SetAlpha(0)
            f.Cooldown:SetDrawSwipe(false)
            f.Cooldown:SetDrawEdge(false)
            f.Cooldown:SetDrawBling(false)
        end
        iconBd:Hide(); if iconTex and iconTex.Hide then iconTex:Hide() end
        
        -- 当隐藏图标时，将整个 f.Icon 框架放逐到屏幕外，彻底杜绝任何幽灵黑框泄露
        if not isTex and f.Icon then 
            if f.Icon.Hide then pcall(function() f.Icon:Hide() end) end 
            f.Icon:ClearAllPoints()
            f.Icon:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -9999, -9999)
        end
        
        barBd:SetSize(w, barH); barBd:Show()
        
        local barY
        if barPos == "TOP" then 
            barY = itemH - barH 
        elseif barPos == "BOTTOM" then 
            barY = 0 
        else 
            barY = CDMod.PixelSnap((itemH - barH) / 2) 
        end
        barBd:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, barY)
    end
    
    local texPath = (LSM and LSM:Fetch("statusbar", cfg.barTexture)) or "Interface\\TargetingFrame\\UI-StatusBar"
    local barColor = cfg.barColor or {r=0, g=0.8, b=1, a=1}
    
    if barObj then
        local isPreview = (not f.cooldownInfo) or 
                          (EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()) or 
                          (WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown())

        if type(barObj.SetStatusBarTexture) == "function" then
            barObj:SetStatusBarTexture(texPath)
        elseif type(barObj.SetTexture) == "function" then
            barObj:SetTexture(texPath)
        end

        if not barObj.wfVirtualFill then
            barObj.wfVirtualFill = barObj:CreateTexture(nil, "OVERLAY")
            barObj.wfVirtualFill:SetPoint("TOPLEFT")
            barObj.wfVirtualFill:SetPoint("BOTTOMLEFT")
        end
        
        if isPreview then
            barObj.wfVirtualFill:SetTexture(texPath)
            barObj.wfVirtualFill:SetVertexColor(barColor.r, barColor.g, barColor.b, barColor.a or 1)
            barObj.wfVirtualFill:SetWidth(math.max(1, actualBarW * 0.8))
            barObj.wfVirtualFill:Show()
            if barObj.GetStatusBarTexture and barObj:GetStatusBarTexture() then barObj:GetStatusBarTexture():SetAlpha(0) end
        else
            barObj.wfVirtualFill:Hide()
            if barObj.GetStatusBarTexture and barObj:GetStatusBarTexture() then barObj:GetStatusBarTexture():SetAlpha(1) end
        end
    end
end

local function StyleFrameCommon(f, cfg, w, h, catName)
    local isBar = (catName == "BuffBar"); local barH = CDMod.PixelSnap(cfg.barHeight or h); local gap = CDMod.PixelSnap(cfg.iconGap or 2)
    f:SetSize(w, math.max(h, barH))
    if isBar then ApplyBarAlignment(f, cfg, w, h, barH, gap) else ApplyIconAlignment(f, w, h) end
end

function CDMod:ImmediateStyleFrame(frame, category)
    if WF.db and WF.db.cooldownCustom and WF.db.cooldownCustom.enable == false then return end 
    if not frame then return end
    
    frame.ignoreBackdrop = true
    if frame.SetBackdrop then pcall(function() frame:SetBackdrop(nil) end) end
    frame.CreateBackdrop = function() end; frame.SetTemplate = function() end

    local isBuffGroup = (category == "BuffIcon" or category == "BuffBar")
    local db = WF.db.cooldownCustom
    if db and db.CustomBuffRows then for _, r in ipairs(db.CustomBuffRows) do if category == r then isBuffGroup = true; break end end end

    local info = frame.cooldownInfo or (frame.GetCooldownInfo and frame:GetCooldownInfo())
    if isBuffGroup then if CDMod.ShouldHideBuff(info) then CDMod.PhysicalHideFrame(frame); return end 
    else if CDMod.ShouldHideCD(info) then CDMod.PhysicalHideFrame(frame); return end end

    local targetAlpha = 1
    local sid = CDMod.ResolveActualSpellID(info, isBuffGroup)
    local dbO_match = (db and db.spellOverrides and sid) and db.spellOverrides[tostring(sid)] or nil

    if dbO_match and dbO_match.idleAlphaEnable then
        local isActive = true
        if type(frame.IsActive) == "function" then isActive = frame:IsActive() elseif frame.active ~= nil then isActive = frame.active elseif frame.Cooldown and type(frame.Cooldown.GetCooldownDuration) == "function" then isActive = (frame.Cooldown:GetCooldownDuration() > 0) end
        if not isActive then targetAlpha = (dbO_match.idleAlpha or 50) / 100.0 end
    end

    if frame._wishFlexHidden then frame._wishFlexHidden = false; frame:EnableMouse(true) end
    frame:SetAlpha(targetAlpha); if frame.Icon then frame.Icon:SetAlpha(targetAlpha) end

    CDMod.SuppressDebuffBorder(frame)
    local cfg = db and db[category]
    if cfg then 
        local w = CDMod.PixelSnap(cfg.width or 45); local h = CDMod.PixelSnap(cfg.height or 45)
        
        local maskTargetFrame = frame.Icon or frame
        local maskTargetTex = type(frame.Icon) == "table" and (frame.Icon.Icon or frame.Icon) or frame.Icon
        CDMod.RemoveBarIconMask(maskTargetFrame, maskTargetTex)
        
        StyleFrameCommon(frame, cfg, w, h, category)
        
        if category == "BuffBar" and cfg.barColor and frame.Bar then
            local bc = cfg.barColor
            if not frame.Bar._wfColorHooked then
                hooksecurefunc(frame.Bar, "SetStatusBarColor", function(self, r, g, b, a)
                    if self._isWFSettingColor then return end
                    local currentCfg = WF.db.cooldownCustom and WF.db.cooldownCustom.BuffBar
                    local override = currentCfg and currentCfg.barColor
                    if override then
                        self._isWFSettingColor = true
                        self:SetStatusBarColor(override.r, override.g, override.b, override.a or 1)
                        self._isWFSettingColor = false
                    end
                end)
                frame.Bar._wfColorHooked = true
            end
            frame.Bar._isWFSettingColor = true
            frame.Bar:SetStatusBarColor(bc.r, bc.g, bc.b, bc.a or 1)
            frame.Bar._isWFSettingColor = false
        end
    end
    frame.wishFlexCategory = category
    self:ApplyText(frame, category); self:ApplySwipeSettings(frame); CDMod.SetupFrameGlow(frame); CDMod.ApplySpellOverrides(frame)
end