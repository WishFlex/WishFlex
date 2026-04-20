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

local spellToKeyCache = nil
local itemToKeyCache = nil

local kbEventFrame = CreateFrame("Frame")
kbEventFrame:RegisterEvent("UPDATE_BINDINGS")
kbEventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
kbEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
kbEventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
kbEventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
kbEventFrame:SetScript("OnEvent", function()
    spellToKeyCache = nil
    itemToKeyCache = nil
end)

local function FormatKeyForDisplay(key)
    if not key or key == "" then return "" end
    local bindingText = GetBindingText and GetBindingText(key, "KEY_", true)
    local displayKey = (bindingText and bindingText ~= "") and bindingText or key
    if displayKey:find("|", 1, true) then return displayKey end

    local upperKey = key:upper()
    upperKey = upperKey:gsub("PADLTRIGGER", "LT"):gsub("PADRTRIGGER", "RT")
    upperKey = upperKey:gsub("PADLSHOULDER", "LB"):gsub("PADRSHOULDER", "RB")
    upperKey = upperKey:gsub("PADLSTICK", "LS"):gsub("PADRSTICK", "RS")
    upperKey = upperKey:gsub("PADDPADUP", "D↑"):gsub("PADDPADDOWN", "D↓")
    upperKey = upperKey:gsub("PADDPADLEFT", "D←"):gsub("PADDPADRIGHT", "D→")
    upperKey = upperKey:gsub("^PAD", "")
    upperKey = upperKey:gsub("SHIFT%-", "S"):gsub("META%-", "M"):gsub("CTRL%-", "C")
    upperKey = upperKey:gsub("ALT%-", "A"):gsub("STRG%-", "ST"):gsub("CONTROL%-", "C")
    upperKey = upperKey:gsub("MOUSE%s?WHEEL%s?UP", "MU"):gsub("MOUSE%s?WHEEL%s?DOWN", "MD")
    upperKey = upperKey:gsub("MIDDLE%s?MOUSE", "M3"):gsub("MOUSE%s?BUTTON%s?", "M"):gsub("BUTTON", "M")
    upperKey = upperKey:gsub("NUMPAD%s?PLUS", "N+"):gsub("NUMPAD%s?MINUS", "N-")
    upperKey = upperKey:gsub("NUMPAD%s?MULTIPLY", "N*"):gsub("NUMPAD%s?DIVIDE", "N/")
    upperKey = upperKey:gsub("NUMPAD%s?DECIMAL", "N."):gsub("NUMPAD%s?ENTER", "NEnt")
    upperKey = upperKey:gsub("NUMPAD%s?", "N"):gsub("NUM%s?", "N"):gsub("NPAD%s?", "N")
    upperKey = upperKey:gsub("PAGE%s?UP", "PU"):gsub("PAGE%s?DOWN", "PD")
    upperKey = upperKey:gsub("INSERT", "Ins"):gsub("DELETE", "Del")
    upperKey = upperKey:gsub("SPACEBAR", "Spc"):gsub("ENTER", "Ent")
    upperKey = upperKey:gsub("ESCAPE", "Esc"):gsub("TAB", "Tab")
    upperKey = upperKey:gsub("CAPSLOCK", "Caps"):gsub("CAPS%s?LOCK", "Caps")
    upperKey = upperKey:gsub("HOME", "Hom"):gsub("END", "End")
    return upperKey
end

local function BuildKeyMap()
    spellToKeyCache = {}
    itemToKeyCache = {}

    local function AddAlias(spellID, itemID, keyBind)
        if not keyBind or keyBind == "" or keyBind == "●" or keyBind == RANGE_INDICATOR then return end
        local formatted = FormatKeyForDisplay(keyBind)
        if spellID and spellID > 0 then
            if not spellToKeyCache[spellID] then spellToKeyCache[spellID] = formatted end
            if C_Spell and C_Spell.GetOverrideSpell then
                local ov = C_Spell.GetOverrideSpell(spellID)
                if ov and ov > 0 and not spellToKeyCache[ov] then spellToKeyCache[ov] = formatted end
            end
            if C_Spell and C_Spell.GetBaseSpell then
                local base = C_Spell.GetBaseSpell(spellID)
                if base and base > 0 and not spellToKeyCache[base] then spellToKeyCache[base] = formatted end
            end
        end
        if itemID and itemID > 0 then
            if not itemToKeyCache[itemID] then itemToKeyCache[itemID] = formatted end
        end
    end

    local function CheckSlot(slot, keyBind)
        if not slot or not keyBind then return end
        local actionType, id, subType = GetActionInfo(slot)
        if not id then return end
        if actionType == "spell" or (actionType == "macro" and subType == "spell") then
            AddAlias(id, nil, keyBind)
        elseif actionType == "macro" then
            local mSpellID = GetMacroSpell and GetMacroSpell(id)
            if not mSpellID and GetActionText then
                local mName = GetActionText(slot)
                if mName then mSpellID = GetMacroSpell(mName) end
            end
            AddAlias(mSpellID, nil, keyBind)
        elseif actionType == "item" then
            AddAlias(nil, id, keyBind)
            if C_Item and C_Item.GetItemSpell then
                local _, iSpellID = C_Item.GetItemSpell(id)
                if iSpellID then AddAlias(iSpellID, nil, keyBind) end
            end
        end
    end

    local function ScanButton(btn, bindCmd)
        if not btn or not btn.action then return end
        local kb = nil
        if bindCmd then kb = GetBindingKey(bindCmd) end
        if not kb and btn.config and btn.config.keyBoundTarget then kb = GetBindingKey(btn.config.keyBoundTarget) end
        if not kb and btn.HotKey and btn.HotKey.GetText then
            local text = btn.HotKey:GetText()
            if text and text ~= "" and text ~= "●" and text ~= RANGE_INDICATOR then kb = text end
        end
        if kb then CheckSlot(btn.action, kb) end
    end

    local blizzBars = {
        {"ActionButton", "ACTIONBUTTON"},
        {"MultiBarBottomLeftButton", "MULTIACTIONBAR1BUTTON"},
        {"MultiBarBottomRightButton", "MULTIACTIONBAR2BUTTON"},
        {"MultiBarRightButton", "MULTIACTIONBAR3BUTTON"},
        {"MultiBarLeftButton", "MULTIACTIONBAR4BUTTON"},
        {"MultiBar5Button", "MULTIACTIONBAR5BUTTON"},
        {"MultiBar6Button", "MULTIACTIONBAR6BUTTON"},
        {"MultiBar7Button", "MULTIACTIONBAR7BUTTON"},
        {"ExtraActionButton", "EXTRAACTIONBUTTON"}
    }
    for _, info in ipairs(blizzBars) do
        for i=1, 12 do ScanButton(_G[info[1]..i], info[2]..i) end
    end

    if _G.ElvUI_Bar1Button1 then
        for i=1, 15 do for j=1, 12 do ScanButton(_G["ElvUI_Bar"..i.."Button"..j]) end end
    end
    if _G.DominosActionButton1 then
        for i=1, 120 do ScanButton(_G["DominosActionButton"..i]) end
    end
    if _G.BT4Button1 then
        for i=1, 120 do ScanButton(_G["BT4Button"..i]) end
    end
end
local function GetHotkey(spellID, itemID)
    if not spellToKeyCache or not itemToKeyCache then BuildKeyMap() end
    
    itemID = tonumber(itemID)
    if itemID and itemID > 0 and itemToKeyCache[itemID] then return itemToKeyCache[itemID] end
    
    spellID = tonumber(spellID)
    if spellID and spellID > 0 then
        if spellToKeyCache[spellID] then return spellToKeyCache[spellID] end
        if CDMod.GetBaseSpellFast then
            local baseFast = CDMod.GetBaseSpellFast(spellID)
            if baseFast and spellToKeyCache[baseFast] then return spellToKeyCache[baseFast] end
        end
        if C_Spell and C_Spell.GetBaseSpell then
            local base = C_Spell.GetBaseSpell(spellID)
            if base and spellToKeyCache[base] then return spellToKeyCache[base] end
        end
        
        local sInfo = C_Spell.GetSpellInfo(spellID)
        local sName = sInfo and sInfo.name
        if sName and sName ~= "" then
            local lowerName = string.lower(sName)
            for cachedID, key in pairs(spellToKeyCache) do
                local cInfo = C_Spell.GetSpellInfo(cachedID)
                if cInfo and cInfo.name and string.lower(cInfo.name) == lowerName then
                    spellToKeyCache[spellID] = key 
                    return key
                end
            end
        end
    end
    return ""
end

function CDMod.ApplyElvUISkin(targetObj, parentFrame, bdSize, bdColor)
    if not targetObj then return nil end
    local m = CDMod.GetOnePixelSize() * (bdSize or 1)
    local bc = bdColor or {r=0, g=0, b=0, a=1}

    if not targetObj.wishBd then
        local bd = CreateFrame("Frame", nil, parentFrame)
        local parentLvl = (parentFrame and parentFrame.GetFrameLevel and parentFrame:GetFrameLevel()) or 1
        if targetObj.GetFrameLevel then bd:SetFrameLevel(math.max(0, targetObj:GetFrameLevel() + 5)) else bd:SetFrameLevel(math.max(0, parentLvl + 5)) end
        
        bd.ignoreBackdrop = true
        if bd.SetBackdrop then pcall(function() bd:SetBackdrop(nil) end) end
        bd.CreateBackdrop = function() end; bd.SetTemplate = function() end
        
        local defaultM = CDMod.GetOnePixelSize()
        local function DrawEdge(p1, p2, x, y, w, h)
            local t = bd:CreateTexture(nil, "BORDER", nil, 1); t:SetColorTexture(0, 0, 0, 1)
            t:SetPoint(p1, bd, p1, x, y); t:SetPoint(p2, bd, p2, x, y)
            if w then t:SetWidth(defaultM) end; if h then t:SetHeight(defaultM) end
            -- 【修复】：删除这两行强制破坏抗锯齿的底层接管，让引擎自然平滑吸附
            return t
        end
        bd.top = DrawEdge("TOPLEFT", "TOPRIGHT", 0, 0, nil, 1); bd.bottom = DrawEdge("BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, nil, 1)
        bd.left = DrawEdge("TOPLEFT", "BOTTOMLEFT", 0, 0, 1, nil); bd.right = DrawEdge("TOPRIGHT", "BOTTOMRIGHT", 0, 0, 1, nil)
        if targetObj.IsObjectType and targetObj:IsObjectType("Texture") then targetObj:SetDrawLayer("ARTWORK", 1) end
        targetObj.wishBd = bd
    end

    if bdSize == 0 then
        targetObj.wishBd.top:Hide(); targetObj.wishBd.bottom:Hide(); targetObj.wishBd.left:Hide(); targetObj.wishBd.right:Hide(); m = 0
    else
        targetObj.wishBd.top:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
        targetObj.wishBd.bottom:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
        targetObj.wishBd.left:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
        targetObj.wishBd.right:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
        targetObj.wishBd.top:SetHeight(m); targetObj.wishBd.bottom:SetHeight(m)
        targetObj.wishBd.left:SetWidth(m); targetObj.wishBd.right:SetWidth(m)
        targetObj.wishBd.top:Show(); targetObj.wishBd.bottom:Show(); targetObj.wishBd.left:Show(); targetObj.wishBd.right:Show()
    end

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
            if isOverlay then region:SetAlpha(0); region:Hide(); hooksecurefunc(region, "Show", SafeHide) end 
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
    
    if frame.CooldownFlash and not frame._wishFlashHooked then
        hooksecurefunc(frame.CooldownFlash, "Show", function(self) self:Hide(); if self.FlashAnim then self.FlashAnim:Stop() end end)
        if frame.CooldownFlash.FlashAnim and frame.CooldownFlash.FlashAnim.Play then hooksecurefunc(frame.CooldownFlash.FlashAnim, "Play", function(self) self:Stop(); frame.CooldownFlash:Hide() end) end
        frame._wishFlashHooked = true
    end

    local function ApplyToCooldown(cd, isMain)
        local db = WF.db.cooldownCustom; local rev = db.reverseSwipe; if rev == nil then rev = true end
        cd:SetReverse(rev); cd:SetUseCircularEdge(false)
        
        local iconTex = nil
        if type(frame.Icon) == "table" then
            iconTex = frame.Icon.Icon or frame.Icon
        elseif type(frame.icon) == "table" then
            iconTex = frame.icon
        end
        if not iconTex then iconTex = frame end

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
    if frame.cd then ApplyToCooldown(frame.cd, true) end 

    for _, child in pairs({frame:GetChildren()}) do if child:IsObjectType("Cooldown") and child ~= frame.Cooldown and child ~= frame.cd then ApplyToCooldown(child, false) end end
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
        else targetRefStack = frame.Bar and frame.Bar.wishBd or frame.Bar or frame; targetRefCD = targetRefStack end
    else
        local iconObj = type(frame.Icon) == "table" and (frame.Icon.IsObjectType and frame.Icon:IsObjectType("Texture") and frame.Icon or frame.Icon.Icon) or frame.Icon
        if not iconObj and type(frame.icon) == "table" and frame.icon.IsObjectType and frame.icon:IsObjectType("Texture") then iconObj = frame.icon end
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
    elseif frame.cd then
        if frame.cd.timer and frame.cd.timer.text then FormatText(frame.cd.timer.text, false, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, targetRefStack, targetRefCD) end
        for k = 1, select("#", frame.cd:GetRegions()) do 
            local region = select(k, frame.cd:GetRegions()); 
            if region and region.IsObjectType and region:IsObjectType("FontString") and region ~= stackFS then FormatText(region, false, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, targetRefStack, targetRefCD) end 
        end 
    end

    local isSkillGroup = (category == "Essential" or category == "Utility" or category == "Defensive" or category == "ExtraMonitor" or (category and string.match(category, "^CustomRow")))
    
    if isSkillGroup and cfg.showHotkey then
        if not frame.wishHotkey then frame.wishHotkey = frame.wishTextContainer:CreateFontString(nil, "OVERLAY") end
        
        local info = frame.cooldownInfo or (frame.GetCooldownInfo and frame:GetCooldownInfo())
        local actualID = tonumber(CDMod.ResolveActualSpellID and CDMod.ResolveActualSpellID(info, false) or (info and info.spellID))
        local itemID = nil
        
        if frame.isExtraMonitor then
            if frame.dbKey and frame.dbKey:match("^item_") then 
                itemID = tonumber(frame.spellID or frame.id) 
                actualID = nil
            else
                actualID = tonumber(frame.spellID or frame.id)
            end
        end
        
        local hotkeyText = GetHotkey(actualID, itemID)
        
        local hkSize = cfg.hkFontSize or 12
        local hkColor = cfg.hkFontColor or {r=0.8, g=0.8, b=0.8, a=1}
        local hkPos = cfg.hkPosition or "TOPRIGHT"
        
        FormatText(frame.wishHotkey, false, hkSize, hkColor, hkPos, cfg.hkXOffset or 0, cfg.hkYOffset or 0, hkSize, hkColor, hkPos, cfg.hkXOffset or 0, cfg.hkYOffset or 0, fontPath, outline, targetRefStack, targetRefCD)
        frame.wishHotkey:SetText(hotkeyText)
        frame.wishHotkey:Show()
    else 
        if frame.wishHotkey then frame.wishHotkey:Hide() end 
    end
end

local function ApplyIconAlignment(f, cfg, w, h, overrideDB)
    local useOverrideBd = overrideDB and overrideDB.borderEnable ~= nil
    local bdEnable = useOverrideBd and overrideDB.borderEnable or (cfg.borderEnable ~= false)
    local bdSize = bdEnable and (useOverrideBd and (overrideDB.borderSize or 1) or (cfg.borderSize or 1)) or 0
    local bdColor = (useOverrideBd and overrideDB.borderColor) or cfg.borderColor

    local iconTex = nil; local iconFrame = f
    if type(f.Icon) == "table" then
        if f.Icon.IsObjectType and f.Icon:IsObjectType("Texture") then iconTex = f.Icon
        elseif f.Icon.Icon then iconTex = f.Icon.Icon; iconFrame = f.Icon
        else iconTex = f.Icon; iconFrame = f.Icon end
    elseif type(f.icon) == "table" and f.icon.IsObjectType and f.icon:IsObjectType("Texture") then iconTex = f.icon end
    if not iconTex and type(f.GetNormalTexture) == "function" then iconTex = f:GetNormalTexture() end

    if iconTex then
        local iconBd = CDMod.ApplyElvUISkin(iconTex, iconFrame, bdSize, bdColor)
        iconBd:SetSize(w, h); iconBd:Show()

        if iconFrame ~= f and type(iconFrame.SetSize) == "function" then
            iconFrame:SetSize(w, h); iconFrame:ClearAllPoints(); iconFrame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
            iconBd:ClearAllPoints(); iconBd:SetAllPoints(iconFrame)
        else
            iconBd:ClearAllPoints(); iconBd:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        end
        if iconTex.Show then iconTex:Show() end
        CDMod.ApplyTexCoord(iconTex, w, h)
    end
end

local function ApplyBarAlignment(f, cfg, w, h, barH, gap, overrideDB)
    local useOverrideBd = overrideDB and overrideDB.borderEnable ~= nil
    local bdEnable = useOverrideBd and overrideDB.borderEnable or (cfg.borderEnable ~= false)
    local bdSize = bdEnable and (useOverrideBd and (overrideDB.borderSize or 1) or (cfg.borderSize or 1)) or 0
    local bdColor = (useOverrideBd and overrideDB.borderColor) or cfg.borderColor

    local iconPos = cfg.iconPosition or "LEFT"; local barPos = cfg.barPosition or "CENTER"; local showIcon = (cfg.showIcon ~= false) 
    f._wf_showIcon = showIcon 
    
    local iconTex = nil; local iconFrame = f
    if type(f.Icon) == "table" then
        if f.Icon.IsObjectType and f.Icon:IsObjectType("Texture") then iconTex = f.Icon
        elseif f.Icon.Icon then iconTex = f.Icon.Icon; iconFrame = f.Icon
        else iconTex = f.Icon; iconFrame = f.Icon end
    elseif type(f.icon) == "table" and f.icon.IsObjectType and f.icon:IsObjectType("Texture") then iconTex = f.icon end
    if not iconTex and type(f.GetNormalTexture) == "function" then iconTex = f:GetNormalTexture() end

    local barObj = f.Bar or f.StatusBar

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
    
    local iconBd = CDMod.ApplyElvUISkin(iconTex, iconFrame, bdSize, bdColor)
    local barBd = CDMod.ApplyElvUISkin(barObj, f, bdSize, bdColor)
    
    if iconBd then iconBd:ClearAllPoints() end
    if barBd then barBd:ClearAllPoints() end
    
    local itemH = math.max(h, barH); local actualBarW = w
    
    if showIcon then
        if f.Cooldown then f.Cooldown:SetAlpha(1) end
        if iconBd then iconBd:SetSize(h, h); iconBd:Show() end
        if iconFrame ~= f and type(iconFrame.Show) == "function" then iconFrame:Show() end
        if iconTex and type(iconTex.Show) == "function" then iconTex:Show() end
        if iconTex and type(iconTex.SetTexCoord) == "function" then CDMod.ApplyTexCoord(iconTex, h, h) end 
        
        actualBarW = math.max(1, w - h - gap); if barBd then barBd:SetSize(actualBarW, barH); barBd:Show() end
        
        local iconY, barY
        if barPos == "TOP" then iconY = itemH - h; barY = itemH - barH 
        elseif barPos == "BOTTOM" then iconY = 0; barY = 0 
        else iconY = CDMod.PixelSnap((itemH - h) / 2); barY = CDMod.PixelSnap((itemH - barH) / 2) end
        
        local iconX, barX = 0, 0
        if iconPos == "LEFT" then iconX = 0; barX = h + gap else barX = 0; iconX = actualBarW + gap end

        if iconFrame ~= f and type(iconFrame.SetSize) == "function" then
            iconFrame:SetSize(h, h); iconFrame:ClearAllPoints(); iconFrame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", iconX, iconY)
            if iconBd then iconBd:ClearAllPoints(); iconBd:SetAllPoints(iconFrame) end
        else
            if iconBd then iconBd:ClearAllPoints(); iconBd:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", iconX, iconY) end
        end
        if barBd then barBd:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", barX, barY) end
    else
        if f.Cooldown then f.Cooldown:SetAlpha(0); f.Cooldown:SetDrawSwipe(false); f.Cooldown:SetDrawEdge(false); f.Cooldown:SetDrawBling(false) end
        if iconBd then iconBd:Hide() end; if iconTex and type(iconTex.Hide) == "function" then iconTex:Hide() end
        
        if iconFrame ~= f and type(iconFrame.ClearAllPoints) == "function" then 
            if type(iconFrame.Hide) == "function" then pcall(function() iconFrame:Hide() end) end 
            iconFrame:ClearAllPoints(); iconFrame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -9999, -9999)
        end
        
        if barBd then 
            barBd:SetSize(w, barH); barBd:Show()
            local barY = (barPos == "TOP") and (itemH - barH) or ((barPos == "BOTTOM") and 0 or CDMod.PixelSnap((itemH - barH) / 2))
            barBd:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, barY)
        end
    end
    
    local texPath = (LSM and LSM:Fetch("statusbar", cfg.barTexture)) or "Interface\\TargetingFrame\\UI-StatusBar"
    local barColor = cfg.barColor or {r=0, g=0.8, b=1, a=1}
    
    if barObj then
        local isPreview = (not f.cooldownInfo) or (EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()) or (WF.UI and WF.UI.MainFrame and WF.UI.MainFrame:IsShown())
        if type(barObj.SetStatusBarTexture) == "function" then barObj:SetStatusBarTexture(texPath) elseif type(barObj.SetTexture) == "function" then barObj:SetTexture(texPath) end
        if not barObj.wfVirtualFill then barObj.wfVirtualFill = barObj:CreateTexture(nil, "OVERLAY"); barObj.wfVirtualFill:SetPoint("TOPLEFT"); barObj.wfVirtualFill:SetPoint("BOTTOMLEFT") end
        
        if isPreview then
            barObj.wfVirtualFill:SetTexture(texPath); barObj.wfVirtualFill:SetVertexColor(barColor.r, barColor.g, barColor.b, barColor.a or 1); barObj.wfVirtualFill:SetWidth(math.max(1, actualBarW * 0.8)); barObj.wfVirtualFill:Show()
            if barObj.GetStatusBarTexture and barObj:GetStatusBarTexture() then barObj:GetStatusBarTexture():SetAlpha(0) end
        else
            barObj.wfVirtualFill:Hide()
            if barObj.GetStatusBarTexture and barObj:GetStatusBarTexture() then barObj:GetStatusBarTexture():SetAlpha(1) end
        end
    end
end

local function StyleFrameCommon(f, cfg, w, h, catName, overrideDB)
    local isBar = (catName == "BuffBar"); local barH = CDMod.PixelSnap(cfg.barHeight or h); local gap = CDMod.PixelSnap(cfg.iconGap or 2)
    f:SetSize(w, math.max(h, barH))
    if isBar then ApplyBarAlignment(f, cfg, w, h, barH, gap, overrideDB) else ApplyIconAlignment(f, cfg, w, h, overrideDB) end
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
    if not info and frame.isExtraMonitor then
        local emType = frame.dbKey and frame.dbKey:match("^(%w+)_")
        info = { spellID = frame.spellID or frame.id, itemID = (emType == "item" and (frame.spellID or frame.id) or nil), isExtraMonitor = true } 
    elseif not info and category == "ItemBuff" then
        info = { spellID = frame.spellID or frame.id, itemID = frame.id }
    end

    if isBuffGroup then if CDMod.ShouldHideBuff(info) then CDMod.PhysicalHideFrame(frame); return end 
    else if CDMod.ShouldHideCD(info) then CDMod.PhysicalHideFrame(frame); return end end

    local targetAlpha = 1
    local sid = CDMod.ResolveActualSpellID and CDMod.ResolveActualSpellID(info, isBuffGroup) or (info and info.spellID)
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
        if not maskTargetTex and type(frame.icon) == "table" and frame.icon.IsObjectType and frame.icon:IsObjectType("Texture") then maskTargetTex = frame.icon end
        CDMod.RemoveBarIconMask(maskTargetFrame, maskTargetTex)
        
        StyleFrameCommon(frame, cfg, w, h, category, dbO_match)
        
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
    self:ApplyText(frame, category); self:ApplySwipeSettings(frame); if CDMod.SetupFrameGlow then CDMod.SetupFrameGlow(frame) end; if CDMod.ApplySpellOverrides then CDMod.ApplySpellOverrides(frame) end
end