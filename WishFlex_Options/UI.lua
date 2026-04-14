local math_min, math_max, math_pi, math_floor, math_abs = math.min, math.max, math.pi, math.floor, math.abs
local string_lower, string_find, string_gsub, string_format = string.lower, string.find, string.gsub, string.format
local table_insert, table_sort = table.insert, table.sort
local pairs, ipairs, type, tostring = pairs, ipairs, type, tostring

local WF = _G.WishFlex
local L = WF.L 

WF.UI.CurrentNodeKey = WF.UI.CurrentNodeKey or "WF_HOME"

local function Lerp(a, b, t) return a + (b - a) * t end
local AnimFrame = CreateFrame("Frame")
local activeAnims = {}
AnimFrame:SetScript("OnUpdate", function(_, elapsed)
    for frame, anims in pairs(activeAnims) do
        for key, data in pairs(anims) do
            data.timer = data.timer + elapsed
            local progress = math_min(1, data.timer / data.duration)
            local ease = 1 - (1 - progress) * (1 - progress)
            data.updateFunc(ease)
            if progress >= 1 then
                if data.onComplete then data.onComplete() end
                anims[key] = nil
            end
        end
        if next(anims) == nil then activeAnims[frame] = nil end
    end
end)

StaticPopupDialogs["WISHFLEX_RELOAD_UI"] = {
    text = L["One or more settings require a UI reload to take effect."] or "部分设置/配置切换需要重载界面(RL)才能生效。",
    button1 = ACCEPT or "接受", button2 = CANCEL or "取消",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function WF.UI:Animate(frame, key, duration, updateFunc, onComplete)
    if not activeAnims[frame] then activeAnims[frame] = {} end
    activeAnims[frame][key] = { timer = 0, duration = duration, updateFunc = updateFunc, onComplete = onComplete }
end
function WF.UI:ShowReloadPopup() StaticPopup_Show("WISHFLEX_RELOAD_UI") end

function WF.UI:UpdateTargetWidth(reqWidth, animated)
    if not WF.MainFrame then return end
    self.CurrentReqWidth = reqWidth or 800 
    local sidebarW = WF.MainFrame.Sidebar.isExpanded and 200 or 40
    local targetW = math_max(900, self.CurrentReqWidth + sidebarW + 70)
    if animated then
        local startW = WF.MainFrame:GetWidth()
        WF.UI:Animate(WF.MainFrame, "WindowResize", 0.3, function(ease) WF.MainFrame:SetWidth(Lerp(startW, targetW, ease)) end)
    else WF.MainFrame:SetWidth(targetW) end
end

function WF.UI:RefreshCurrentPanel()
    if WF.ScrollChild and self.CurrentNodeKey then
        for k in pairs(self.WidgetCounts) do self.WidgetCounts[k] = 0 end
        for _, pool in pairs(self.WidgetPools) do for _, widget in ipairs(pool) do widget:Hide(); widget:ClearAllPoints() end end
        for i = 1, WF.ScrollChild:GetNumChildren() do local child = select(i, WF.ScrollChild:GetChildren()); if type(child) == "table" and child.Hide then child:Hide() end end
        for i = 1, WF.ScrollChild:GetNumRegions() do local region = select(i, WF.ScrollChild:GetRegions()); if type(region) == "table" and region.Hide then region:Hide() end end
        
        if self.Panels[self.CurrentNodeKey] then
            local stableLogicalWidth = 800 
            local y, reqWidth = self.Panels[self.CurrentNodeKey](WF.ScrollChild, stableLogicalWidth / 2.2)
            WF.ScrollChild:SetHeight(math_abs(y) + 50)
            self:UpdateTargetWidth(reqWidth or 800, false)
        end
    end
end

local FRAME_WIDTH, FRAME_HEIGHT, TITLE_HEIGHT, SIDEBAR_WIDTH_COLLAPSED, SIDEBAR_WIDTH_EXPANDED = 900, 650, 35, 40, 200
local ICON_ARROW = "Interface\\AddOns\\WishFlex\\Media\\Icons\\menu.tga"
local ICON_CLOSE = "Interface\\AddOns\\WishFlex\\Media\\Icons\\off.tga"
local ICON_GEAR = "Interface\\AddOns\\WishFlex\\Media\\Icons\\sett.tga"

local LSM = LibStub("LibSharedMedia-3.0", true)
local FontOptions, StatusBarOptions = {}, {}
if LSM then
    for name, _ in pairs(LSM:HashTable("font")) do table_insert(FontOptions, {text = name, value = name}) end
    for name, _ in pairs(LSM:HashTable("statusbar")) do table_insert(StatusBarOptions, {text = name, value = name}) end
    table_sort(FontOptions, function(a, b) return a.text < b.text end)
    table_sort(StatusBarOptions, function(a, b) return a.text < b.text end)
end
WF.UI.FontOptions = #FontOptions > 0 and FontOptions or { {text = "Expressway", value = "Expressway"} }
WF.UI.StatusBarOptions = #StatusBarOptions > 0 and StatusBarOptions or { {text = "Blizzard", value = "Interface\\TargetingFrame\\UI-StatusBar"} }

local AnchorOptions = {
    { text = L["TOPLEFT"] or "左上", value = "TOPLEFT" }, { text = L["TOP"] or "上方", value = "TOP" }, { text = L["TOPRIGHT"] or "右上", value = "TOPRIGHT" },
    { text = L["LEFT"] or "左侧", value = "LEFT" }, { text = L["CENTER"] or "居中", value = "CENTER" }, { text = L["RIGHT"] or "右侧", value = "RIGHT" },
    { text = L["BOTTOMLEFT"] or "左下", value = "BOTTOMLEFT" }, { text = L["BOTTOM"] or "下方", value = "BOTTOM" }, { text = L["BOTTOMRIGHT"] or "右下", value = "BOTTOMRIGHT" },
}
WF.UI.AnchorOptions = AnchorOptions

local _, playerClass = UnitClass("player")
local ClassColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass] or {r=1, g=1, b=1}
local CR, CG, CB = ClassColor.r, ClassColor.g, ClassColor.b

local function ApplyFlatSkin(frame, r, g, b, a, br, bg, bb, ba)
    if not frame:GetWidth() or frame:GetWidth() == 0 then frame:SetSize(10, 10) end
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropColor(r or 0.1, g or 0.1, b or 0.1, a or 0.95); frame:SetBackdropBorderColor(br or 0, bg or 0, bb or 0, ba or 1)
end

local function CreateUIFont(parent, size, justify, isBold)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(isBold and "Fonts\\ARKai_T.ttf" or STANDARD_TEXT_FONT, size or 13, "OUTLINE"); text:SetJustifyH(justify or "LEFT")
    return text
end

local function ShowTooltipTemp(owner, text, r, g, b)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT"); GameTooltip:ClearLines(); GameTooltip:AddLine(text, r or 1, g or 1, b or 1); GameTooltip:Show()
    C_Timer.After(2, function() if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end end)
end

WF.UI.Factory = {}
WF.UI.Factory.ApplyFlatSkin = ApplyFlatSkin
local Factory = WF.UI.Factory

-- =====================================
-- [新增] 斜纹背景材质引擎
-- =====================================
local STRIPE_TEX = [[Interface\AddOns\WishFlex\Media\Textures\stripes.blp]]

local function ApplyStripe(frame, alpha, blend)
    if not frame or frame.wfStripe then return end
    
    local stripe = frame:CreateTexture(nil, "BORDER", nil, 1)
    stripe:SetAllPoints(frame)
    stripe:SetTexture(STRIPE_TEX, "REPEAT", "REPEAT")
    stripe:SetHorizTile(true); stripe:SetVertTile(true)
    stripe:SetAlpha(alpha or 0.8)
    stripe:SetBlendMode(blend or "ADD") 
    stripe:SetVertexColor(1, 1, 1, 1)
    stripe:SetTexCoord(0, 6, 0, 6) 
    
    frame.wfStripe = stripe
end
Factory.ApplyStripe = ApplyStripe
-- =====================================

local ROW_HEIGHT = 28
local CONTROL_WIDTH_RATIO = 0.55

function Factory:CreateScrollArea(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10); scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    local scrollChild = CreateFrame("Frame")
    scrollFrame:SetScript("OnSizeChanged", function(self, width, height) if self:GetScrollChild() then self:GetScrollChild():SetWidth(width) end end)
    scrollChild:SetSize(scrollFrame:GetWidth() or 800, 1); scrollFrame:SetScrollChild(scrollChild)
    return scrollFrame, scrollChild
end

function Factory:CreateFlatButton(parent, textStr, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(120, 26); ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1)
    local text = CreateUIFont(btn, 13, "CENTER"); text:SetPoint("CENTER"); text:SetText(textStr); text:SetTextColor(0.8, 0.8, 0.8)
    btn:SetScript("OnMouseDown", function() text:SetPoint("CENTER", 1, -1) end); btn:SetScript("OnMouseUp", function() text:SetPoint("CENTER", 0, 0) end)
    btn:SetScript("OnEnter", function() ApplyFlatSkin(btn, 0.2, 0.2, 0.2, 1, 0, 0, 0, 1); text:SetTextColor(1, 1, 1) end); btn:SetScript("OnLeave", function() ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1); text:SetTextColor(0.8, 0.8, 0.8) end)
    btn:SetScript("OnClick", function() if onClick then onClick() end end)
    return btn
end

function Factory:CreateInput(parent, x, y, width, titleText, db, key, callback)
    WF.UI.WidgetCounts.input = WF.UI.WidgetCounts.input + 1
    local c = WF.UI.WidgetPools.input[WF.UI.WidgetCounts.input]
    if not c then
        c = CreateFrame("Button", nil, UIParent)
        c.title = CreateUIFont(c, 13, "LEFT"); c.title:SetPoint("LEFT", 5, 0)
        
        c.boxBg = CreateFrame("Frame", nil, c, "BackdropTemplate"); ApplyFlatSkin(c.boxBg, 0.05, 0.05, 0.05, 1, 0.3, 0.3, 0.3, 0.6)
        c.box = CreateFrame("EditBox", nil, c.boxBg); c.box:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); c.box:SetPoint("TOPLEFT", 5, 0); c.box:SetPoint("BOTTOMRIGHT", -5, 0); c.box:SetAutoFocus(false)
        c.box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end); c.box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        
        c:SetScript("OnMouseDown", function() c.box:SetFocus() end)
        c:SetScript("OnEnter", function() ApplyFlatSkin(c.boxBg, 0.1, 0.1, 0.1, 1, CR, CG, CB, 0.8); c.title:SetTextColor(1, 1, 1); ApplyFlatSkin(c, 1, 1, 1, 0.05, 0,0,0,0) end)
        c:SetScript("OnLeave", function() ApplyFlatSkin(c.boxBg, 0.05, 0.05, 0.05, 1, 0.3, 0.3, 0.3, 0.6); c.title:SetTextColor(0.7, 0.7, 0.7); ApplyFlatSkin(c, 0, 0, 0, 0, 0,0,0,0) end)
        WF.UI.WidgetPools.input[WF.UI.WidgetCounts.input] = c
    end
    c:SetParent(parent); c:SetSize(width, ROW_HEIGHT); c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y)
    
    local ctrlWidth = width * CONTROL_WIDTH_RATIO
    c.boxBg:SetSize(ctrlWidth, 22); c.boxBg:ClearAllPoints(); c.boxBg:SetPoint("RIGHT", -5, 0)
    
    c.box:SetScript("OnTextChanged", nil)
    c.title:SetText(titleText); c.title:SetTextColor(0.7, 0.7, 0.7); c.box:SetText(db[key] or "")
    
    c.box:SetScript("OnTextChanged", function(self, userInput) 
        if not userInput then return end; db[key] = self:GetText(); if callback then callback(self:GetText()) end 
    end)
    
    c:Show(); return c, y - ROW_HEIGHT
end

function Factory:CreateToggle(parent, x, y, width, titleText, db, key, callback)
    WF.UI.WidgetCounts.toggle = WF.UI.WidgetCounts.toggle + 1
    local c = WF.UI.WidgetPools.toggle[WF.UI.WidgetCounts.toggle]
    if not c then
        c = CreateFrame("Button", nil, UIParent)
        c.text = CreateUIFont(c, 13, "LEFT"); c.text:SetPoint("LEFT", 5, 0)
        
        c.track = CreateFrame("Frame", nil, c, "BackdropTemplate"); c.track:SetSize(36, 16); c.track:SetPoint("RIGHT", -5, 0)
        ApplyFlatSkin(c.track, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1)
        c.thumb = CreateFrame("Frame", nil, c.track, "BackdropTemplate"); c.thumb:SetSize(12, 12); ApplyFlatSkin(c.thumb, 0.6, 0.6, 0.6, 1, 0, 0, 0, 0)
        
        c.UpdateState = function(animated, isOn)
            local targetX = isOn and 22 or 2; local targetR, targetG, targetB = 0.15, 0.15, 0.15
            if isOn then targetR, targetG, targetB = CR, CG, CB end
            if animated then
                local startR, startG, startB = c.track:GetBackdropColor(); local startX = select(4, c.thumb:GetPoint()) or 2
                WF.UI:Animate(c, "toggle", 0.2, function(ease)
                    c.thumb:ClearAllPoints(); c.thumb:SetPoint("LEFT", c.track, "LEFT", Lerp(startX, targetX, ease), 0)
                    c.track:SetBackdropColor(Lerp(startR, targetR, ease), Lerp(startG, targetG, ease), Lerp(startB, targetB, ease), 1)
                    local tc = Lerp(0.6, 1, ease); c.thumb:SetBackdropColor(tc, tc, tc, 1)
                end)
            else
                c.thumb:ClearAllPoints(); c.thumb:SetPoint("LEFT", c.track, "LEFT", targetX, 0); c.track:SetBackdropColor(targetR, targetG, targetB, 1)
                local tc = isOn and 1 or 0.6; c.thumb:SetBackdropColor(tc, tc, tc, 1)
            end
        end
        c:SetScript("OnEnter", function() c.text:SetTextColor(1, 1, 1); ApplyFlatSkin(c, 1, 1, 1, 0.05, 0,0,0,0) end)
        c:SetScript("OnLeave", function() c.text:SetTextColor(0.9, 0.9, 0.9); ApplyFlatSkin(c, 0, 0, 0, 0, 0,0,0,0) end)
        WF.UI.WidgetPools.toggle[WF.UI.WidgetCounts.toggle] = c
    end
    c:SetParent(parent); c:SetSize(width, ROW_HEIGHT); c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y)
    c.text:SetText(titleText); c.text:SetTextColor(0.9, 0.9, 0.9)
    c:SetScript("OnClick", function() local isOn = not db[key]; db[key] = isOn; c.UpdateState(true, isOn); if callback then callback(isOn) end end)
    c.UpdateState(false, db[key]); c:Show()
    return c, y - ROW_HEIGHT
end

function Factory:CreateSlider(parent, x, y, width, titleText, minVal, maxVal, step, db, key, callback)
    WF.UI.WidgetCounts.slider = WF.UI.WidgetCounts.slider + 1
    local c = WF.UI.WidgetPools.slider[WF.UI.WidgetCounts.slider]
    if not c then
        c = CreateFrame("Frame", nil, UIParent)
        c.title = CreateUIFont(c, 13, "LEFT"); c.title:SetPoint("LEFT", 5, 0)
        
        c.slider = CreateFrame("Slider", nil, c); c.slider:SetOrientation("HORIZONTAL"); c.slider:SetObeyStepOnDrag(true)
        c.slider:EnableMouse(true) 
        
        c.trackBg = CreateFrame("Frame", nil, c.slider, "BackdropTemplate")
        c.trackBg:SetPoint("LEFT"); c.trackBg:SetPoint("RIGHT")
        c.trackBg:SetHeight(5)
        c.trackBg:SetFrameLevel(c.slider:GetFrameLevel() - 1)
        ApplyFlatSkin(c.trackBg, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)
        
        c.thumb = c.slider:CreateTexture(nil, "ARTWORK")
        c.thumb:SetColorTexture(CR, CG, CB, 1)
        c.thumb:SetSize(8, 14) 
        c.slider:SetThumbTexture(c.thumb)
        
        c.slider:EnableMouseWheel(true)
        c.slider:SetScript("OnMouseWheel", function(self, delta)
            if self.isSystemUpdating then return end
            local current = self:GetValue()
            local minV, maxV = self:GetMinMaxValues()
            local s = c.stepValue or 1
            if (maxV - minV) > 100 then s = s * 5 end 
            local target = current + (delta * s)
            if target < minV then target = minV end
            if target > maxV then target = maxV end
            self:SetValue(target)
        end)
        
        c.valBg = CreateFrame("Frame", nil, c, "BackdropTemplate")
        ApplyFlatSkin(c.valBg, 0.05, 0.05, 0.05, 0.6, 0.4, 0.4, 0.4, 0.5)
        
        c.valInput = CreateFrame("EditBox", nil, c.valBg)
        c.valInput:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        c.valInput:SetJustifyH("RIGHT")
        c.valInput:SetTextColor(CR, CG, CB)
        c.valInput:SetAutoFocus(false)
        c.valInput:SetPoint("TOPLEFT", 2, 0)
        c.valInput:SetPoint("BOTTOMRIGHT", -2, 0)
        
        c.valInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        c.valInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        
        c.valBg:SetScript("OnMouseDown", function() c.valInput:SetFocus() end)
        c.valInput:SetScript("OnEditFocusGained", function(self) ApplyFlatSkin(c.valBg, 0.1, 0.1, 0.1, 1, CR, CG, CB, 1) end)
        
        c:SetScript("OnEnter", function() c.title:SetTextColor(1, 1, 1); ApplyFlatSkin(c, 1, 1, 1, 0.05, 0,0,0,0) end)
        c:SetScript("OnLeave", function() c.title:SetTextColor(0.7, 0.7, 0.7); ApplyFlatSkin(c, 0, 0, 0, 0, 0,0,0,0) end)
        WF.UI.WidgetPools.slider[WF.UI.WidgetCounts.slider] = c
    end
    c:SetParent(parent); c:SetSize(width, ROW_HEIGHT); c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y)
    
    local ctrlWidth = width * CONTROL_WIDTH_RATIO
    c.valBg:SetSize(40, 20); c.valBg:ClearAllPoints(); c.valBg:SetPoint("RIGHT", -5, 0)
    c.slider:SetSize(ctrlWidth - 55, 24); c.slider:ClearAllPoints(); c.slider:SetPoint("RIGHT", c.valBg, "LEFT", -10, 0)
    
    c.slider:SetScript("OnValueChanged", nil)
    c.valInput:SetScript("OnEditFocusLost", nil)
    
    c.slider.isSystemUpdating = true
    c.slider:SetMinMaxValues(minVal, maxVal)
    c.slider:SetValueStep(step or 1)
    c.stepValue = step or 1 
    
    local targetVal = tonumber(db[key]) or minVal
    if targetVal < minVal then targetVal = minVal end
    if targetVal > maxVal then targetVal = maxVal end
    c.slider:SetValue(targetVal)
    
    c.title:SetText(titleText); c.title:SetTextColor(0.7, 0.7, 0.7)
    c.valInput:SetText(string_format("%.2f", targetVal):gsub("%.00", ""))
    ApplyFlatSkin(c.valBg, 0.05, 0.05, 0.05, 0.6, 0.4, 0.4, 0.4, 0.5)
    
    local function UpdateValue(newVal, fromInput)
        if c.slider.isSystemUpdating then return end
        if db[key] == newVal then return end
        db[key] = newVal
        local fStr = string_format("%.2f", newVal):gsub("%.00", "")
        if not fromInput then c.valInput:SetText(fStr) end
        if fromInput then
            c.slider.isSystemUpdating = true
            c.slider:SetValue(newVal)
            c.slider.isSystemUpdating = false
        end
        if callback then callback(newVal) end
    end

    c.slider:SetScript("OnValueChanged", function(self, value) UpdateValue(value, false) end)
    
    c.valInput:SetScript("OnEditFocusLost", function(self)
        ApplyFlatSkin(c.valBg, 0.05, 0.05, 0.05, 0.6, 0.4, 0.4, 0.4, 0.5)
        local txt = self:GetText()
        local num = tonumber(txt)
        if num then
            if num < minVal then num = minVal end
            if num > maxVal then num = maxVal end
            if step and step > 0 then num = minVal + math_floor((num - minVal) / step + 0.5) * step end
            self:SetText(string_format("%.2f", num):gsub("%.00", ""))
            UpdateValue(num, true)
        else self:SetText(string_format("%.2f", tonumber(db[key]) or minVal):gsub("%.00", "")) end
    end)
    
    c.slider.isSystemUpdating = false
    c:Show(); return c, y - ROW_HEIGHT
end

function Factory:CreateColorPicker(parent, x, y, width, titleText, db, key, callback)
    WF.UI.WidgetCounts.color = WF.UI.WidgetCounts.color + 1
    local c = WF.UI.WidgetPools.color[WF.UI.WidgetCounts.color]
    if not c then
        c = CreateFrame("Button", nil, UIParent)
        c.text = CreateUIFont(c, 13, "LEFT"); c.text:SetPoint("LEFT", 5, 0)
        
        c.swatch = CreateFrame("Button", nil, c, "BackdropTemplate"); c.swatch:SetSize(16, 16); c.swatch:SetPoint("RIGHT", -25, 0)
        ApplyFlatSkin(c.swatch, 0, 0, 0, 1, 0, 0, 0, 1)
        c.tex = c.swatch:CreateTexture(nil, "ARTWORK"); c.tex:SetPoint("TOPLEFT", 1, -1); c.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        
        c.classBtn = CreateFrame("Button", nil, c, "BackdropTemplate"); c.classBtn:SetSize(12, 12); c.classBtn:SetPoint("LEFT", c.swatch, "RIGHT", 6, 0)
        ApplyFlatSkin(c.classBtn, CR, CG, CB, 1, 0, 0, 0, 1)
        c.classBtn:SetScript("OnEnter", function() c.classBtn:SetBackdropBorderColor(1, 1, 1, 1); ShowTooltipTemp(c.classBtn, L["Apply Class Color"] or "一键应用职业色", CR, CG, CB) end)
        c.classBtn:SetScript("OnLeave", function() c.classBtn:SetBackdropBorderColor(0, 0, 0, 1); GameTooltip:Hide() end)
        
        c:SetScript("OnEnter", function() c.text:SetTextColor(1, 1, 1); ApplyFlatSkin(c, 1, 1, 1, 0.05, 0,0,0,0) end)
        c:SetScript("OnLeave", function() c.text:SetTextColor(0.9, 0.9, 0.9); ApplyFlatSkin(c, 0, 0, 0, 0, 0,0,0,0) end)
        WF.UI.WidgetPools.color[WF.UI.WidgetCounts.color] = c
    end
    c:SetParent(parent); c:SetSize(width, ROW_HEIGHT); c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y)
    c.text:SetText(titleText); c.text:SetTextColor(0.9, 0.9, 0.9)
    
    local function UpdateColor() 
        local col = db[key]
        if type(col) ~= "table" or type(col.r) ~= "number" then 
            col = {r=1, g=1, b=1, a=1} 
        end
        c.tex:SetColorTexture(col.r, col.g, col.b, col.a or 1) 
    end
    UpdateColor()
    
    c.classBtn:SetScript("OnClick", function() db[key] = {r = CR, g = CG, b = CB, a = 1}; UpdateColor(); if callback then callback() end end)
    
    local function OpenPicker()
        local col = db[key]
        if type(col) ~= "table" or type(col.r) ~= "number" then 
            col = {r=1, g=1, b=1, a=1} 
        end
        local function OnColorSet() local r, g, b = ColorPickerFrame:GetColorRGB(); local a = 1; if ColorPickerFrame.GetColorAlpha then a = ColorPickerFrame:GetColorAlpha() elseif OpacitySliderFrame then a = OpacitySliderFrame:GetValue() end; db[key] = {r=r, g=g, b=b, a=a}; UpdateColor(); if callback then callback() end end
        local function OnColorCancel(prev) db[key] = {r=prev.r, g=prev.g, b=prev.b, a=prev.opacity}; UpdateColor(); if callback then callback() end end
        if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow({ r=col.r, g=col.g, b=col.b, opacity=col.a or 1, hasOpacity=true, swatchFunc=OnColorSet, opacityFunc=OnColorSet, cancelFunc=OnColorCancel }) else ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = OnColorSet, OnColorSet, OnColorCancel; ColorPickerFrame:SetColorRGB(col.r, col.g, col.b); ColorPickerFrame.hasOpacity = true; ColorPickerFrame.opacity = col.a or 1; ColorPickerFrame:Show() end
    end
    c.swatch:SetScript("OnClick", OpenPicker)
    c:SetScript("OnClick", OpenPicker)
    
    c:Show(); return c, y - ROW_HEIGHT
end

function Factory:CreateDropdown(parent, x, y, width, titleText, db, key, options, callback)
    WF.UI.WidgetCounts.dropdown = WF.UI.WidgetCounts.dropdown + 1
    local c = WF.UI.WidgetPools.dropdown[WF.UI.WidgetCounts.dropdown]
    if not c then
        c = CreateFrame("Button", nil, UIParent)
        c.title = CreateUIFont(c, 13, "LEFT"); c.title:SetPoint("LEFT", 5, 0)
        
        c.box = CreateFrame("Frame", nil, c, "BackdropTemplate"); ApplyFlatSkin(c.box, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)
        c.valText = CreateUIFont(c.box, 12, "CENTER"); c.valText:SetPoint("CENTER", 0, 0); c.valText:SetTextColor(CR, CG, CB)
        
        c.menu = CreateFrame("Frame", nil, c.box, "BackdropTemplate"); c.menu:SetPoint("TOPLEFT", c.box, "BOTTOMLEFT", 0, -2); ApplyFlatSkin(c.menu, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); c.menu:SetFrameStrata("TOOLTIP"); c.menu:Hide()
        c.scrollFrame = CreateFrame("ScrollFrame", nil, c.menu); c.scrollChild = CreateFrame("Frame"); c.scrollFrame:SetScrollChild(c.scrollChild)
        c.items = {}
        
        c:SetScript("OnEnter", function() c.title:SetTextColor(1, 1, 1); ApplyFlatSkin(c.box, 0.1, 0.1, 0.1, 1, 0, 0, 0, 1); ApplyFlatSkin(c, 1, 1, 1, 0.05, 0,0,0,0) end)
        c:SetScript("OnLeave", function() c.title:SetTextColor(0.7, 0.7, 0.7); ApplyFlatSkin(c.box, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); ApplyFlatSkin(c, 0, 0, 0, 0, 0,0,0,0) end)
        c:SetScript("OnClick", function() if c.menu:IsShown() then c.menu:Hide() else c.menu:Show() end end)
        WF.UI.WidgetPools.dropdown[WF.UI.WidgetCounts.dropdown] = c
    end
    c:SetParent(parent); c:SetSize(width, ROW_HEIGHT); c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y)
    c.title:SetText(titleText); c.title:SetTextColor(0.7, 0.7, 0.7)
    
    local ctrlWidth = width * CONTROL_WIDTH_RATIO
    c.box:SetSize(ctrlWidth, 22); c.box:ClearAllPoints(); c.box:SetPoint("RIGHT", -5, 0)
    
    local function GetOptText(val) for _, v in ipairs(options) do if v.value == val then return v.text end end return tostring(val) end
    c.valText:SetText(GetOptText(db[key]))
    
    local showScroll = #options > 8
    c.menu:SetSize(ctrlWidth, (showScroll and 8 or #options) * 22 + 4); c.scrollFrame:SetPoint("TOPLEFT", 4, -2); c.scrollFrame:SetPoint("BOTTOMRIGHT", showScroll and -26 or -4, 2)
    if showScroll and not c.scrollFrame.ScrollBar then c.scrollFrame.ScrollBar = CreateFrame("EventFrame", nil, c.scrollFrame, "MinimalScrollBar"); c.scrollFrame.ScrollBar:SetPoint("TOPLEFT", c.scrollFrame, "TOPRIGHT", 6, 0); c.scrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", c.scrollFrame, "BOTTOMRIGHT", 6, 0); ScrollUtil.InitScrollFrameWithScrollBar(c.scrollFrame, c.scrollFrame.ScrollBar) end
    if c.scrollFrame.ScrollBar then if showScroll then c.scrollFrame.ScrollBar:Show() else c.scrollFrame.ScrollBar:Hide() end end

    c.scrollChild:SetSize(ctrlWidth - (showScroll and 30 or 10), #options * 22)
    for i, item in ipairs(c.items) do item:Hide() end

    for i, opt in ipairs(options) do
        local item = c.items[i]
        if not item then
            item = CreateFrame("Button", nil, c.scrollChild)
            item.itxt = CreateUIFont(item, 12, "LEFT"); item.itxt:SetPoint("LEFT", 10, 0)
            item:SetScript("OnEnter", function() ApplyFlatSkin(item, 0.15, 0.15, 0.15, 1, 0,0,0,0) end); item:SetScript("OnLeave", function() ApplyFlatSkin(item, 0, 0, 0, 0, 0,0,0,0) end)
            
            -- [新增] 右侧删除按钮
            item.delBtn = CreateFrame("Button", nil, item)
            item.delBtn:SetSize(16, 16)
            item.delBtn:SetPoint("RIGHT", -5, 0)
            item.delBtn.text = CreateUIFont(item.delBtn, 12, "CENTER")
            item.delBtn.text:SetPoint("CENTER")
            item.delBtn.text:SetText("X")
            item.delBtn.text:SetTextColor(0.8, 0.2, 0.2)
            item.delBtn:SetScript("OnEnter", function() item.delBtn.text:SetTextColor(1, 0.2, 0.2) end)
            item.delBtn:SetScript("OnLeave", function() item.delBtn.text:SetTextColor(0.8, 0.2, 0.2) end)
            
            c.items[i] = item
        end
        item:SetSize(ctrlWidth - (showScroll and 30 or 10), 22); item:ClearAllPoints(); item:SetPoint("TOPLEFT", 0, -(i-1)*22); item.itxt:SetText(opt.text)
        item:SetScript("OnClick", function() db[key] = opt.value; c.valText:SetText(opt.text); c.menu:Hide(); if callback then callback(opt.value) end end)
        
        -- [新增] 动态显示与绑定删除逻辑
        if opt.onDelete then
            item.delBtn:Show()
            item.delBtn:SetScript("OnClick", function(self)
                opt.onDelete(opt.value)
                c.menu:Hide()
            end)
        else
            item.delBtn:Hide()
        end
        
        item:Show()
    end
    c:Show(); return c, y - ROW_HEIGHT
end

function Factory:CreateGroupHeader(parent, x, y, width, titleText, isExpanded, onClick)
    WF.UI.WidgetCounts.header = WF.UI.WidgetCounts.header + 1
    local btn = WF.UI.WidgetPools.header[WF.UI.WidgetCounts.header]
    if not btn then
        btn = CreateFrame("Button", nil, UIParent, "BackdropTemplate"); ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0.8, 0, 0, 0, 0)
        
        -- ++新加入的斜纹调用++
        Factory.ApplyStripe(btn, 0.4, "ADD")
        
        btn.accent = btn:CreateTexture(nil, "OVERLAY"); btn.accent:SetPoint("TOPLEFT"); btn.accent:SetPoint("BOTTOMLEFT"); btn.accent:SetWidth(2)
        btn.text = CreateUIFont(btn, 13, "LEFT"); btn.icon = btn:CreateTexture(nil, "OVERLAY"); btn.icon:SetSize(14, 14); btn.icon:SetTexture(ICON_ARROW)
        btn:SetScript("OnMouseDown", function() btn.text:SetPoint("LEFT", 16, -1); btn.icon:SetPoint("RIGHT", -7, -1) end); btn:SetScript("OnMouseUp", function() btn.text:SetPoint("LEFT", 15, 0); btn.icon:SetPoint("RIGHT", -8, 0) end)
        WF.UI.WidgetPools.header[WF.UI.WidgetCounts.header] = btn
    end
    btn:SetParent(parent); btn:SetSize(width, 26); btn:ClearAllPoints(); btn:SetPoint("TOPLEFT", x, y)
    btn.text:SetPoint("LEFT", 15, 0); btn.text:SetText(titleText); btn.icon:SetPoint("RIGHT", -8, 0)
    btn.accent:SetColorTexture(isExpanded and CR or 0.25, isExpanded and CG or 0.25, isExpanded and CB or 0.25, 1)
    btn.text:SetTextColor(isExpanded and 1 or 0.7, isExpanded and 1 or 0.7, isExpanded and 1 or 0.7)
    btn.icon:SetRotation(isExpanded and -math_pi/2 or 0); btn.icon:SetVertexColor(isExpanded and CR or 0.5, isExpanded and CG or 0.5, isExpanded and CB or 0.5, 1)
    btn:SetScript("OnEnter", function() ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 0); btn.accent:SetColorTexture(CR, CG, CB, 1); btn.icon:SetVertexColor(CR, CG, CB, 1); btn.text:SetTextColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function() ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0.8, 0, 0, 0, 0); btn.accent:SetColorTexture(isExpanded and CR or 0.25, isExpanded and CG or 0.25, isExpanded and CB or 0.25, 1); btn.icon:SetVertexColor(isExpanded and CR or 0.5, isExpanded and CG or 0.5, isExpanded and CB or 0.5, 1); btn.text:SetTextColor(isExpanded and 1 or 0.7, isExpanded and 1 or 0.7, isExpanded and 1 or 0.7) end)
    btn:SetScript("OnClick", function() if onClick then onClick() end end); btn:Show()
    return btn, y - 30
end

WF.UI.GroupState = WF.UI.GroupState or {}
local GroupState = WF.UI.GroupState

function WF.UI:RenderOptionsGroup(parent, startX, startY, colWidth, options, onChange, level)
    local y = startY; level = level or 0; local indent = level * 12; local cx = startX + indent; local itemWidth = colWidth - indent
    for _, opt in ipairs(options) do
        if opt.type == "group" then
            local gKey = opt.key or opt.text or tostring(opt)
            if GroupState[gKey] == nil then GroupState[gKey] = (opt.expanded ~= false) end
            local isExpanded = GroupState[gKey]
            local btn; btn, y = Factory:CreateGroupHeader(parent, cx, y, itemWidth, opt.text, isExpanded, function() GroupState[gKey] = not GroupState[gKey]; WF.UI:RefreshCurrentPanel(); if type(onChange) == "function" then onChange("UI_REFRESH") end end)
            if isExpanded and opt.childs then y = self:RenderOptionsGroup(parent, cx, y - 4, itemWidth, opt.childs, onChange, level + 1); y = y - 6 end
        elseif opt.type == "toggle" then _, y = Factory:CreateToggle(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, function(val) if opt.callback then opt.callback(val) end; if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange(val) end end end)
        elseif opt.type == "slider" then _, y = Factory:CreateSlider(parent, cx + 8, y, itemWidth, opt.text, opt.min, opt.max, opt.step, opt.db, opt.key, function(val) if opt.callback then opt.callback(val) end; if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange(val) end end end)
        elseif opt.type == "color" then _, y = Factory:CreateColorPicker(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, function() if opt.callback then opt.callback() end; if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange() end end end)
        elseif opt.type == "dropdown" then _, y = Factory:CreateDropdown(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, opt.options, function(val) if opt.callback then opt.callback(val) end; if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange(val) end end end)
        elseif opt.type == "input" then _, y = Factory:CreateInput(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, function(val) if opt.callback then opt.callback(val) end; if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange(val) end end end)
        elseif opt.type == "button" then
            WF.UI.WidgetCounts.button = (WF.UI.WidgetCounts.button or 0) + 1
            if not WF.UI.WidgetPools.button then WF.UI.WidgetPools.button = {} end
            local c = WF.UI.WidgetPools.button[WF.UI.WidgetCounts.button]
            if not c then
                c = Factory:CreateFlatButton(parent, "")
                for i=1, c:GetNumRegions() do
                    local reg = select(i, c:GetRegions())
                    if reg:IsObjectType("FontString") then c.textObj = reg; break end
                end
                WF.UI.WidgetPools.button[WF.UI.WidgetCounts.button] = c
            end
            c:SetParent(parent); c:SetSize(itemWidth, ROW_HEIGHT - 4); c:ClearAllPoints(); c:SetPoint("TOPLEFT", cx + 8, y)
            c.textObj:SetText(opt.text)
            
            c:SetScript("OnEnter", function() Factory.ApplyFlatSkin(c, 0.6, 0.2, 0.2, 1, 0, 0, 0, 1); c.textObj:SetTextColor(1, 1, 1) end)
            c:SetScript("OnLeave", function() Factory.ApplyFlatSkin(c, 0.4, 0.1, 0.1, 1, 0, 0, 0, 1); c.textObj:SetTextColor(0.9, 0.9, 0.9) end)
            Factory.ApplyFlatSkin(c, 0.4, 0.1, 0.1, 1, 0, 0, 0, 1)
            c.textObj:SetTextColor(0.9, 0.9, 0.9)
            
            c:SetScript("OnClick", function() if opt.callback then opt.callback() end end)
            c:Show(); y = y - ROW_HEIGHT
        end
    end
    return y
end

function WF.UI:GetTextOptions(dbRef, prefix, titleStr, groupKey)
    local childs = {
        { type = "slider", key = prefix.."FontSize", db = dbRef, min = 8, max = 64, step = 1, text = L["Font Size"] or "字体大小" },
        { type = "dropdown", key = prefix.."Position", db = dbRef, text = L["Anchor"] or "锚点位置", options = AnchorOptions },
        { type = "color", key = prefix.."FontColor", db = dbRef, text = L["Color"] or "文本颜色" },
        { type = "slider", key = prefix.."XOffset", db = dbRef, min = -50, max = 50, step = 1, text = L["X Offset"] or "X 偏移微调" },
        { type = "slider", key = prefix.."YOffset", db = dbRef, min = -50, max = 50, step = 1, text = L["Y Offset"] or "Y 偏移微调" }
    }
    return { type = "group", key = groupKey, text = titleStr, childs = childs }
end

local menuExpanded = {}
local function BuildMenuTree()
    local tree, map = {}, {}
    for _, item in ipairs(WF.UI.Menus) do item.childs = {}; map[item.id] = item end
    for _, item in ipairs(WF.UI.Menus) do if item.parent and map[item.parent] then table_insert(map[item.parent].childs, item) else table_insert(tree, item) end end
    local function sortTree(node) table_sort(node, function(a, b) return (a.order or 99) < (b.order or 99) end); for _, child in ipairs(node) do sortTree(child.childs) end end
    sortTree(tree)
    local flat = {}; local function flatten(node, lvl) for _, item in ipairs(node) do item.level = lvl; table_insert(flat, item); flatten(item.childs, lvl + 1) end end
    flatten(tree, 0); return flat
end

local function RenderTreeMenu()
    local sidebar = WF.MainFrame.Sidebar; local isExpanded = sidebar.isExpanded
    if not sidebar.buttons then sidebar.buttons = {} end
    for _, b in ipairs(sidebar.buttons) do b:Hide() end
    local yOffset = -50
    local activeIndicator = sidebar.activeIndicator
    if not activeIndicator then activeIndicator = sidebar:CreateTexture(nil, "OVERLAY"); activeIndicator:SetWidth(3); activeIndicator:SetColorTexture(CR, CG, CB, 1); sidebar.activeIndicator = activeIndicator end

    local currentMenu = BuildMenuTree(); local btnIndex = 1

    local function AddBtn(item)
        local btn = sidebar.buttons[btnIndex]
        if not btn then
            btn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
            local hoverGlow = btn:CreateTexture(nil, "BACKGROUND"); hoverGlow:SetAllPoints(); hoverGlow:SetColorTexture(CR, CG, CB, 0); btn.hoverGlow = hoverGlow
            local tIcon = btn:CreateTexture(nil, "OVERLAY"); tIcon:SetSize(18, 18); tIcon:SetPoint("LEFT", 10, 0); btn.tIcon = tIcon
            local icon = btn:CreateTexture(nil, "OVERLAY"); icon:SetSize(14, 14); btn.arrowIcon = icon
            local text = CreateUIFont(btn, 13, "LEFT"); btn.text = text
            sidebar.buttons[btnIndex] = btn
        end
        btnIndex = btnIndex + 1

        btn:SetHeight(28); btn:SetPoint("LEFT", 0, 0); btn:SetPoint("RIGHT", 0, 0); btn:SetPoint("TOP", 0, yOffset)
        ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0, 0,0,0,0)
        local xIndent = (item.level * 18)
        
        if item.icon then btn.tIcon:SetTexture(item.icon); btn.tIcon:SetVertexColor(0.6, 0.6, 0.6, 1); if item.type == "root" and item.id == "HOME" then btn.tIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9) else btn.tIcon:SetTexCoord(0, 1, 0, 1) end; btn.tIcon:Show() else btn.tIcon:Hide() end
        if item.type == "root" or item.type == "group" then if not item.icon then btn.arrowIcon:SetPoint("LEFT", xIndent + 10, 0); btn.arrowIcon:SetTexture(ICON_ARROW); btn.arrowIcon._wf_rot = menuExpanded[item.id] and -math_pi/2 or 0; btn.arrowIcon:SetRotation(btn.arrowIcon._wf_rot); btn.arrowIcon:SetVertexColor(CR, CG, CB, 1); btn.arrowIcon:Show() else btn.arrowIcon:Hide() end else btn.arrowIcon:Hide() end
        btn.text:SetPoint("LEFT", xIndent + 35, 0); btn.text:SetText(item.name)
        if item.type == "root" then btn.text:SetTextColor(CR, CG, CB) else btn.text:SetTextColor(0.6, 0.6, 0.6) end
        if not isExpanded then btn.text:Hide() else btn.text:Show() end

        btn:SetScript("OnMouseDown", function() if item.icon then btn.tIcon:SetPoint("LEFT", 11, -1) end; if btn.arrowIcon:IsShown() then btn.arrowIcon:SetPoint("LEFT", xIndent + 11, -1) end; btn.text:SetPoint("LEFT", xIndent + 36, -1) end)
        btn:SetScript("OnMouseUp", function() if item.icon then btn.tIcon:SetPoint("LEFT", 10, 0) end; if btn.arrowIcon:IsShown() then btn.arrowIcon:SetPoint("LEFT", xIndent + 10, 0) end; btn.text:SetPoint("LEFT", xIndent + 35, 0) end)
        
        btn:SetScript("OnClick", function()
            if item.type == "root" or item.type == "group" then menuExpanded[item.id] = not menuExpanded[item.id] end
            
            if not sidebar.isExpanded then 
                sidebar.isExpanded = true
                sidebar:SetWidth(SIDEBAR_WIDTH_EXPANDED)
                if sidebar.mIcon then 
                    local startRad = sidebar.mIcon._wf_rot or 0
                    WF.UI:Animate(sidebar.mIcon, "rotation", 0.2, function(ease) 
                        local currentRad = Lerp(startRad, -math_pi/2, ease)
                        sidebar.mIcon:SetRotation(currentRad)
                        sidebar.mIcon._wf_rot = currentRad 
                    end) 
                end 
                WF.UI:UpdateTargetWidth(WF.UI.CurrentReqWidth or 800, true)
            end
            
            if item.key then
                for _, b in ipairs(sidebar.buttons) do 
                    if b.tIcon then b.tIcon:SetVertexColor(0.6, 0.6, 0.6, 1) end
                    if b.text and b.itemType ~= "root" then b.text:SetTextColor(0.6, 0.6, 0.6) end 
                end
                btn.text:SetTextColor(1, 1, 1)
                if btn.tIcon then btn.tIcon:SetVertexColor(CR, CG, CB, 1) end
                activeIndicator:ClearAllPoints()
                activeIndicator:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
                activeIndicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
                activeIndicator:Show()
                WF.UI.CurrentNodeKey = item.key
                WF.UI:RefreshCurrentPanel()
                WF.MainFrame.TitleBar.titleText:SetText("|cffffffffW|cff00ffccF|r // "..item.name)
            end
            RenderTreeMenu()
        end)
        
        btn:SetScript("OnEnter", function() if not sidebar.isExpanded then ShowTooltipTemp(btn, item.name, CR, CG, CB) end; WF.UI:Animate(btn, "hover", 0.15, function(ease) btn.hoverGlow:SetColorTexture(CR, CG, CB, Lerp(0, 0.15, ease)) end) end)
        btn:SetScript("OnLeave", function() if not sidebar.isExpanded and GameTooltip:IsOwned(btn) then GameTooltip:Hide() end; WF.UI:Animate(btn, "hover", 0.15, function(ease) btn.hoverGlow:SetColorTexture(CR, CG, CB, Lerp(0.15, 0, ease)) end) end)
        btn.itemType = item.type; btn:Show(); yOffset = yOffset - 30
    end

    for _, item in ipairs(currentMenu) do
        if item.type == "root" then AddBtn(item) elseif isExpanded and item.parent and menuExpanded[item.parent] then
            local pNode = nil; for _, n in ipairs(currentMenu) do if n.id == item.parent then pNode = n; break end end
            if pNode and (pNode.type == "root" or (pNode.parent and menuExpanded[pNode.parent])) then AddBtn(item) end
        end
    end
end

function WF:ToggleUI()
    if not WF.MainFrame then
        local frame = CreateFrame("Frame", "WishFlexMainUI", UIParent, "BackdropTemplate")
        WF.MainFrame = frame; frame:Hide(); WF.db = WF.db or {}; local initialScale = WF.db.uiScale or 1
        frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT); frame:SetPoint("CENTER"); frame:SetMovable(true); frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton"); frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing); frame:SetFrameStrata("DIALOG")
        frame:SetResizable(true); frame:SetResizeBounds(700, 500, 1400, 1000)
        ApplyFlatSkin(frame, 0.08, 0.08, 0.08, 0.95, CR, CG, CB, 1); frame:SetScale(initialScale)
        
        -- ++新加入的斜纹调用：主界面背景++
        Factory.ApplyStripe(frame, 0.3, "ADD")

        local resizeGrip = CreateFrame("Button", nil, frame); resizeGrip:SetSize(16, 16); resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"); resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"); resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        resizeGrip:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end end); resizeGrip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

        local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate"); sidebar:SetPoint("TOPLEFT", 1, -1); sidebar:SetPoint("BOTTOMLEFT", 1, 1); ApplyFlatSkin(sidebar, 0.1, 0.1, 0.1, 1, 0, 0, 0, 1); frame.Sidebar = sidebar
        
        -- ++新加入的斜纹调用：侧边栏++
        Factory.ApplyStripe(sidebar, 0.5, "ADD")

        local menuBtn = CreateFrame("Button", nil, sidebar, "BackdropTemplate"); menuBtn:SetSize(40, 26); menuBtn:SetPoint("TOP", 0, -10)
        local mIcon = menuBtn:CreateTexture(nil, "ARTWORK"); mIcon:SetSize(16, 16); mIcon:SetPoint("CENTER"); mIcon:SetTexture(ICON_ARROW); mIcon:SetVertexColor(CR, CG, CB, 1); sidebar.mIcon = mIcon
        menuBtn:SetScript("OnEnter", function() if not sidebar.isExpanded then ShowTooltipTemp(menuBtn, L["MENU"] or "菜单", CR, CG, CB) end end); menuBtn:SetScript("OnLeave", function() if GameTooltip:IsOwned(menuBtn) then GameTooltip:Hide() end end)
        menuBtn:SetScript("OnMouseDown", function() mIcon:SetPoint("CENTER", 1, -1) end); menuBtn:SetScript("OnMouseUp", function() mIcon:SetPoint("CENTER", 0, 0) end)
        menuBtn:SetScript("OnClick", function() sidebar.isExpanded = not sidebar.isExpanded; sidebar:SetWidth(sidebar.isExpanded and SIDEBAR_WIDTH_EXPANDED or SIDEBAR_WIDTH_COLLAPSED); RenderTreeMenu(); local startRad = mIcon._wf_rot or 0; WF.UI:Animate(mIcon, "rotation", 0.2, function(ease) local currentRad = Lerp(startRad, sidebar.isExpanded and -math_pi/2 or 0, ease); mIcon:SetRotation(currentRad); mIcon._wf_rot = currentRad end); WF.UI:UpdateTargetWidth(WF.UI.CurrentReqWidth, true) end)

        local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate"); titleBar:SetHeight(TITLE_HEIGHT); titleBar:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, 0); titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1); ApplyFlatSkin(titleBar, 0.12, 0.12, 0.12, 1, 0, 0, 0, 1); frame.TitleBar = titleBar
        
        -- ++新加入的斜纹调用：顶部标题栏++
        Factory.ApplyStripe(titleBar, 0.6, "ADD")
        
        local titleText = CreateUIFont(titleBar, 14, "LEFT"); titleText:SetPoint("LEFT", 15, 0); titleText:SetText("|cffffffffW|cff00ffccF|r // "..(L["Home"] or "主页")); titleBar.titleText = titleText

        local closeBtn = CreateFrame("Button", nil, titleBar); closeBtn:SetSize(20, 20); closeBtn:SetPoint("RIGHT", -8, 0)
        local cIcon = closeBtn:CreateTexture(nil, "ARTWORK"); cIcon:SetPoint("CENTER"); cIcon:SetSize(14, 14); cIcon:SetTexture(ICON_CLOSE); cIcon:SetVertexColor(0.6, 0.6, 0.6, 1)
        closeBtn:SetScript("OnEnter", function() cIcon:SetVertexColor(CR, CG, CB, 1) end); closeBtn:SetScript("OnLeave", function() cIcon:SetVertexColor(0.6, 0.6, 0.6, 1) end); closeBtn:SetScript("OnMouseDown", function() cIcon:SetPoint("CENTER", 1, -1) end); closeBtn:SetScript("OnMouseUp", function() cIcon:SetPoint("CENTER", 0, 0) end); closeBtn:SetScript("OnClick", function() frame:Hide() end)

        local gearBtn = CreateFrame("Button", nil, titleBar); gearBtn:SetSize(20, 20); gearBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
        local gIcon = gearBtn:CreateTexture(nil, "ARTWORK"); gIcon:SetPoint("CENTER"); gIcon:SetSize(14, 14); gIcon:SetTexture(ICON_GEAR); gIcon:SetVertexColor(0.6, 0.6, 0.6, 1)
        gearBtn:SetScript("OnEnter", function() gIcon:SetVertexColor(CR, CG, CB, 1); ShowTooltipTemp(gearBtn, L["Enter Edit Mode"] or "进入编辑模式", CR, CG, CB) end); 
        gearBtn:SetScript("OnLeave", function() gIcon:SetVertexColor(0.6, 0.6, 0.6, 1); GameTooltip:Hide() end); 
        gearBtn:SetScript("OnMouseDown", function() gIcon:SetPoint("CENTER", 1, -1) end); 
        gearBtn:SetScript("OnMouseUp", function() gIcon:SetPoint("CENTER", 0, 0) end)
        gearBtn:SetScript("OnClick", function() 
            if EditModeManagerFrame then 
                ShowUIPanel(EditModeManagerFrame) 
            end 
            frame:Hide() 
        end)
        
        local scalePlusBtn = CreateFrame("Button", nil, titleBar); scalePlusBtn:SetSize(20, 20); scalePlusBtn:SetPoint("RIGHT", gearBtn, "LEFT", -15, 0)
        scalePlusBtn.text = CreateUIFont(scalePlusBtn, 16, "CENTER"); scalePlusBtn.text:SetPoint("CENTER"); scalePlusBtn.text:SetText("+"); scalePlusBtn.text:SetTextColor(0.6, 0.6, 0.6)
        scalePlusBtn:SetScript("OnEnter", function() scalePlusBtn.text:SetTextColor(CR, CG, CB) end); scalePlusBtn:SetScript("OnLeave", function() scalePlusBtn.text:SetTextColor(0.6, 0.6, 0.6) end); scalePlusBtn:SetScript("OnMouseDown", function() scalePlusBtn.text:SetPoint("CENTER", 1, -1) end); scalePlusBtn:SetScript("OnMouseUp", function() scalePlusBtn.text:SetPoint("CENTER", 0, 0) end)
        
        local scaleTxt = CreateUIFont(titleBar, 12, "CENTER"); scaleTxt:SetPoint("RIGHT", scalePlusBtn, "LEFT", -5, 0)
        
        local scaleMinusBtn = CreateFrame("Button", nil, titleBar); scaleMinusBtn:SetSize(20, 20); scaleMinusBtn:SetPoint("RIGHT", scaleTxt, "LEFT", -5, 0)
        scaleMinusBtn.text = CreateUIFont(scaleMinusBtn, 16, "CENTER"); scaleMinusBtn.text:SetPoint("CENTER"); scaleMinusBtn.text:SetText("-"); scaleMinusBtn.text:SetTextColor(0.6, 0.6, 0.6)
        scaleMinusBtn:SetScript("OnEnter", function() scaleMinusBtn.text:SetTextColor(CR, CG, CB) end); scaleMinusBtn:SetScript("OnLeave", function() scaleMinusBtn.text:SetTextColor(0.6, 0.6, 0.6) end); scaleMinusBtn:SetScript("OnMouseDown", function() scaleMinusBtn.text:SetPoint("CENTER", 1, -1) end); scaleMinusBtn:SetScript("OnMouseUp", function() scaleMinusBtn.text:SetPoint("CENTER", 0, 0) end)

        local function UpdateScaleDisplay() WF.db = WF.db or {}; local s = WF.db.uiScale or 1; scaleTxt:SetText(math_floor(s * 100) .. "%"); frame:SetScale(s) end
        scalePlusBtn:SetScript("OnClick", function() WF.db = WF.db or {}; WF.db.uiScale = math_min(2.0, (WF.db.uiScale or 1) + 0.05); UpdateScaleDisplay() end)
        scaleMinusBtn:SetScript("OnClick", function() WF.db = WF.db or {}; WF.db.uiScale = math_max(0.5, (WF.db.uiScale or 1) - 0.05); UpdateScaleDisplay() end); UpdateScaleDisplay()

        local content = CreateFrame("Frame", nil, frame, "BackdropTemplate"); content:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0); content:SetPoint("BOTTOMRIGHT", -1, 1); content:SetFrameLevel(frame:GetFrameLevel() + 1)
        local scrollFrame, scrollChild = Factory:CreateScrollArea(content)
        content.scrollFrame = scrollFrame; content.scrollChild = scrollChild; frame.Content = content; WF.ScrollChild = scrollChild
    end
    
    if not WF.MainFrame:IsShown() then
        local sidebar = WF.MainFrame.Sidebar; sidebar.isExpanded = false; sidebar:SetWidth(SIDEBAR_WIDTH_COLLAPSED)
        if sidebar.mIcon then sidebar.mIcon:SetRotation(0) end

        RenderTreeMenu()
        local firstBtn = sidebar.buttons[1]
        if firstBtn then
            for _, b in ipairs(sidebar.buttons) do if b.tIcon then b.tIcon:SetVertexColor(0.6, 0.6, 0.6, 1) end; if b.text and b.itemType ~= "root" then b.text:SetTextColor(0.6, 0.6, 0.6) end end
            firstBtn.text:SetTextColor(1, 1, 1); if firstBtn.tIcon then firstBtn.tIcon:SetVertexColor(CR, CG, CB, 1) end
            if sidebar.activeIndicator then sidebar.activeIndicator:ClearAllPoints(); sidebar.activeIndicator:SetPoint("TOPLEFT", firstBtn, "TOPLEFT", 0, 0); sidebar.activeIndicator:SetPoint("BOTTOMLEFT", firstBtn, "BOTTOMLEFT", 0, 0); sidebar.activeIndicator:Show() end
            WF.UI.CurrentNodeKey = "WF_HOME"; WF.UI:RefreshCurrentPanel(); WF.MainFrame.TitleBar.titleText:SetText("|cffffffffW|cff00ffccF|r // "..(L["Home"] or "主页"))
        end
        WF.MainFrame:Show()
    else WF.MainFrame:Hide() end
end

WF.UI:RegisterMenu({ id = "Profile", name = L["Profile Management"] or "配置与分享", type = "root", icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\set.tga", key = "Profile_Global", order = 90 })

WF.UI:RegisterPanel("Profile_Global", function(scrollChild)
    local totalWidth = WF.UI.CurrentReqWidth or 800
    local leftMargin = 15; local centerGap = 20
    local colW = (totalWidth - (leftMargin * 2) - centerGap) / 2
    local leftX = leftMargin; local rightX = leftX + colW + centerGap; local startY = -10

    local profHeader, currentY = WF.UI.Factory:CreateGroupHeader(scrollChild, leftX, startY, totalWidth - 30, L["Profile Management Title"] or "|cff00ffcc[0]|r 配置文件管理 (Profiles)", true)
    currentY = currentY - 5

    local profileOptions = {}
    if WF.globalDB and WF.globalDB.profiles then
        for pName, _ in pairs(WF.globalDB.profiles) do
            table_insert(profileOptions, { 
                text = pName, 
                value = pName,
                onDelete = function(val)
                    -- 保护机制：防止误删当前正在使用的配置
                    if WF.globalDB.currentProfile[WF.playerKey] == val then
                        print(L["Cannot delete active profile!"] or "|cffff0000[WishFlex]|r 无法删除当前正在使用的配置文件！请先切换至其他配置。")
                        return
                    end
                    
                    -- 从数据库中删除
                    WF.globalDB.profiles[val] = nil
                    
                    -- 同步清理自动加载（专精绑定）中与该配置相关的设置
                    if WF.globalDB.specProfiles then
                        for k, v in pairs(WF.globalDB.specProfiles) do
                            if v == val then WF.globalDB.specProfiles[k] = nil end
                        end
                    end
                    
                    print(string_format(L["Profile %s deleted."] or "|cff00ffcc[WishFlex]|r 配置文件 [%s] 已成功删除。", val))
                    WF.UI:RefreshCurrentPanel() -- 实时刷新界面，移除刚才删掉的选项
                end
            })
        end
    end

    local selectDropdown, selectY = WF.UI.Factory:CreateDropdown(scrollChild, leftX, currentY, colW, L["Select and Apply Profile:"] or "选择并应用配置:", WF, "activeProfile", profileOptions, function(val)
        if WF.globalDB then
            WF.globalDB.currentProfile[WF.playerKey] = val
            WF.UI:ShowReloadPopup() 
        end
    end)

    scrollChild.NewProfileName = scrollChild.NewProfileName or ""
    local newProfInput, _ = WF.UI.Factory:CreateInput(scrollChild, rightX, currentY, colW - 130, L["New/Copy Current Profile:"] or "新建/复制当前配置:", scrollChild, "NewProfileName")
    
    local createBtn = scrollChild.Prof_BtnCreate
    if not createBtn then
        createBtn = WF.UI.Factory:CreateFlatButton(scrollChild, L["Create"] or "创建", function()
            local name = scrollChild.NewProfileName
            if name and name ~= "" and WF.globalDB and not WF.globalDB.profiles[name] then
                local function DeepCopy(src) if type(src) ~= "table" then return src end; local tgt = {}; for k, v in pairs(src) do tgt[k] = DeepCopy(v) end; return tgt end
                WF.globalDB.profiles[name] = DeepCopy(WF.db)
                WF.globalDB.currentProfile[WF.playerKey] = name
                ReloadUI()
            else
                print(L["Profile name invalid or already exists!"] or "|cffff0000[WishFlex]|r 配置文件名称无效或已存在！")
            end
        end)
        scrollChild.Prof_BtnCreate = createBtn
    end
    createBtn:SetParent(scrollChild); createBtn:SetWidth(120); createBtn:ClearAllPoints(); createBtn:SetPoint("LEFT", newProfInput.boxBg, "RIGHT", 10, 0); createBtn:Show()
    currentY = selectY - 10

    local specGroupHeader, specY = WF.UI.Factory:CreateGroupHeader(scrollChild, leftX, currentY, totalWidth - 30, L["Spec Auto-Load Binding"] or "专精自动加载绑定", true)
    currentY = specY - 5

    local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
    local specOpts = { { text = L["None"] or "不绑定", value = "NONE" } }
    for _, opt in ipairs(profileOptions) do table_insert(specOpts, {text = opt.text, value = opt.value}) end

    for i = 1, numSpecs do
        local specID, specName = GetSpecializationInfo(i)
        if specID then
            WF.UI.SpecProxy = WF.UI.SpecProxy or {}
            WF.UI.SpecProxy[specID] = WF.globalDB.specProfiles[tostring(specID)] or "NONE"
            
            local _, nY = WF.UI.Factory:CreateDropdown(scrollChild, leftX + ((i-1)%2 == 0 and 0 or (colW + centerGap)), currentY, colW, specName .. (L[" Auto-Load:"] or " 自动加载:"), WF.UI.SpecProxy, specID, specOpts, function(val)
                if val == "NONE" then
                    WF.globalDB.specProfiles[tostring(specID)] = nil
                else
                    WF.globalDB.specProfiles[tostring(specID)] = val
                end
            end)
            if i % 2 == 0 or i == numSpecs then currentY = nY - 10 end
        end
    end
    
    startY = currentY - 20

    local LibSerialize = LibStub("LibSerialize", true)
    local LibDeflate = LibStub("LibDeflate", true)

    if not LibSerialize or not LibDeflate then
        local err = scrollChild:CreateFontString(nil, "OVERLAY")
        err:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE"); err:SetPoint("TOPLEFT", leftX, startY)
        err:SetText(L["Missing dependencies LibSerialize or LibDeflate."] or "|cffff0000[错误]|r 缺少依赖库 LibSerialize 或 LibDeflate，导入导出功能无法启用。")
        return -50, totalWidth
    end

    local GroupState = WF.UI.GroupState
    if GroupState["Prof_Exp_Grp"] == nil then GroupState["Prof_Exp_Grp"] = false end
    if GroupState["Prof_Imp_Grp"] == nil then GroupState["Prof_Imp_Grp"] = false end

    local expHeader, expY = WF.UI.Factory:CreateGroupHeader(scrollChild, leftX, startY, colW, L["Export Profile"] or "|cff00ffcc[1]|r 导出配置 (生成代码分享)", GroupState["Prof_Exp_Grp"], function() GroupState["Prof_Exp_Grp"] = not GroupState["Prof_Exp_Grp"]; WF.UI:RefreshCurrentPanel() end)
    local impHeader, impY = WF.UI.Factory:CreateGroupHeader(scrollChild, rightX, startY, colW, L["Import Profile"] or "|cffffaa00[2]|r 导入配置 (覆盖现有设置)", GroupState["Prof_Imp_Grp"], function() GroupState["Prof_Imp_Grp"] = not GroupState["Prof_Imp_Grp"]; WF.UI:RefreshCurrentPanel() end)
    expY = expY - 5; impY = impY - 5

    scrollChild.Prof_ExpMode = scrollChild.Prof_ExpMode or "GLOBAL"

    local expDropdown = scrollChild.Prof_ExpDropdown
    local expScroll = scrollChild.Prof_ExpScroll
    local expBox = scrollChild.Prof_ExpBox
    local expBtn1 = scrollChild.Prof_BtnExp
    local expBtn2 = scrollChild.Prof_BtnExpClear

    if GroupState["Prof_Exp_Grp"] then
        local opts = { 
            { text = L["Export All (Recommended)"] or "【全局】导出所有配置 (推荐)", value = "GLOBAL" }, 
            { text = L["Cooldown Manager (CD)"] or "冷却管理器套装 (CD)", value = "CD" }, 
            { text = L["Class Resource (CR)"] or "资源条排版套装 (CR)", value = "CR" } 
        }
        expDropdown, expY = WF.UI.Factory:CreateDropdown(scrollChild, leftX, expY, colW, "", scrollChild, "Prof_ExpMode", opts, function() WF.UI:RefreshCurrentPanel() end)
        scrollChild.Prof_ExpDropdown = expDropdown
        
        expDropdown.box:ClearAllPoints(); expDropdown.box:SetPoint("LEFT", expDropdown, "LEFT", 0, 0); expDropdown.box:SetPoint("RIGHT", expDropdown, "RIGHT", 0, 0)
        expDropdown.menu:SetWidth(colW)
        if expDropdown.scrollChild then expDropdown.scrollChild:SetWidth(colW - 20) end
        if expDropdown.items then for _, item in ipairs(expDropdown.items) do item:SetWidth(colW - 20) end end

        if not expScroll then
            local bg = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate"); WF.UI.Factory.ApplyFlatSkin(bg, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)
            expScroll = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
            expScroll:SetPoint("TOPLEFT", 5, -5); expScroll:SetPoint("BOTTOMRIGHT", -25, 5)
            expBox = CreateFrame("EditBox", nil, expScroll)
            expBox:SetMultiLine(true); expBox:SetAutoFocus(false); expBox:SetFontObject("ChatFontNormal")
            -- [修改] 解除限制，防止被截断
            expBox:SetMaxLetters(0)
            expBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            expScroll:SetScrollChild(expBox); expScroll.bg = bg; scrollChild.Prof_ExpScroll = expScroll; scrollChild.Prof_ExpBox = expBox
        end
        expScroll.bg:SetParent(scrollChild); expScroll.bg:SetSize(colW, 180); expScroll.bg:ClearAllPoints(); expScroll.bg:SetPoint("TOPLEFT", leftX, expY)
        expBox:SetWidth(colW - 30); expScroll.bg:Show(); expY = expY - 190

        local btnWidth = (colW - 10) / 2
        if not expBtn1 then
            expBtn1 = WF.UI.Factory:CreateFlatButton(scrollChild, L["Generate Export Code"] or "生成导出代码", function()
                local data = {}
                if scrollChild.Prof_ExpMode == "GLOBAL" then
                    local function DeepCopy(src) if type(src) ~= "table" then return src end; local tgt = {}; for k, v in pairs(src) do tgt[k] = DeepCopy(v) end; return tgt end
                    data = DeepCopy(WF.db); data.minimap = nil; data.movers = nil; data.uiScale = nil 
                elseif scrollChild.Prof_ExpMode == "CD" then data.cooldownCustom = WF.db.cooldownCustom; data.wishMonitor = WF.db.wishMonitor; data.glow = WF.db.glow; data.auraGlow = WF.db.auraGlow; data.cooldownTracker = WF.db.cooldownTracker
                elseif scrollChild.Prof_ExpMode == "CR" then data.classResource = WF.db.classResource end
                
                local serialized = LibSerialize:Serialize(data); local compressed = LibDeflate:CompressDeflate(serialized); local encoded = LibDeflate:EncodeForPrint(compressed)
                expBox:SetText("!WF!" .. scrollChild.Prof_ExpMode .. "!" .. encoded)
                -- [修改] 生成代码后强制使其获取焦点并且全选文本，引导玩家直接按下 Ctrl+C 复制
                expBox:SetFocus()
                expBox:HighlightText()
                print(L["Export string generated successfully."] or "|cff00ffcc[WishFlex]|r 导出字符串生成成功，请按 Ctrl+C 复制。")
            end)
            scrollChild.Prof_BtnExp = expBtn1
        end
        expBtn1:SetParent(scrollChild); expBtn1:SetWidth(btnWidth); expBtn1:ClearAllPoints(); expBtn1:SetPoint("TOPLEFT", leftX, expY); expBtn1:Show()

        if not expBtn2 then expBtn2 = WF.UI.Factory:CreateFlatButton(scrollChild, L["Clear Input"] or "清空输入框", function() expBox:SetText("") end); scrollChild.Prof_BtnExpClear = expBtn2 end
        expBtn2:SetParent(scrollChild); expBtn2:SetWidth(btnWidth); expBtn2:ClearAllPoints(); expBtn2:SetPoint("LEFT", expBtn1, "RIGHT", 10, 0); expBtn2:Show()
        
        expY = expY - 40
    else
        if expDropdown then expDropdown:Hide() end; if expScroll and expScroll.bg then expScroll.bg:Hide() end
        if expBtn1 then expBtn1:Hide() end; if expBtn2 then expBtn2:Hide() end
    end

    local impLabel = scrollChild.Prof_ImpLabel
    local impScroll = scrollChild.Prof_ImpScroll
    local impBox = scrollChild.Prof_ImpBox
    local impBtn1 = scrollChild.Prof_BtnImp
    local impBtn2 = scrollChild.Prof_BtnImpClear

    if GroupState["Prof_Imp_Grp"] then
        if not impLabel then impLabel = scrollChild:CreateFontString(nil, "OVERLAY"); impLabel:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); impLabel:SetTextColor(0.5, 0.5, 0.5); scrollChild.Prof_ImpLabel = impLabel end
        impLabel:SetSize(colW, 28); impLabel:SetJustifyH("CENTER"); impLabel:SetJustifyV("MIDDLE"); impLabel:SetPoint("TOPLEFT", rightX, impY); impLabel:SetText(L["Paste your WishFlex profile code below:"] or "请在下方输入框中粘贴您的 WishFlex 配置代码："); impLabel:Show()
        impY = impY - 28 

        if not impScroll then
            local bg = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate"); WF.UI.Factory.ApplyFlatSkin(bg, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)
            impScroll = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
            impScroll:SetPoint("TOPLEFT", 5, -5); impScroll:SetPoint("BOTTOMRIGHT", -25, 5)
            impBox = CreateFrame("EditBox", nil, impScroll)
            impBox:SetMultiLine(true); impBox:SetAutoFocus(false); impBox:SetFontObject("ChatFontNormal")
            -- [修改] 将 MaxLetters 设置为 0 彻底解除字符串粘贴长度限制
            impBox:SetMaxLetters(0)
            impBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            
            -- [修改] 优化交互，当玩家点击到黑色背景区域时，将焦点强制赋予输入框
            bg:SetScript("OnMouseDown", function() impBox:SetFocus() end)
            
            impScroll:SetScrollChild(impBox); impScroll.bg = bg; scrollChild.Prof_ImpScroll = impScroll; scrollChild.Prof_ImpBox = impBox
        end
        impScroll.bg:SetParent(scrollChild); impScroll.bg:SetSize(colW, 180); impScroll.bg:ClearAllPoints(); impScroll.bg:SetPoint("TOPLEFT", rightX, impY)
        impBox:SetWidth(colW - 30); impScroll.bg:Show(); impY = impY - 190

        local btnWidth = (colW - 10) / 2
if not impBtn1 then
            impBtn1 = WF.UI.Factory:CreateFlatButton(scrollChild, L["Parse and Import"] or "解析并导入代码", function()
                local input = impBox:GetText(); 
                local prefix, payload = input:match("^!WF!(%a+)!(.+)$")
                if not prefix or not payload then print(L["Import failed: Invalid format."] or "|cffff0000[WishFlex]|r 导入失败：字符串格式不正确。"); return end
                
                local decoded = LibDeflate:DecodeForPrint(payload)
                if not decoded then print(L["Import failed: Cannot decode."] or "|cffff0000[WishFlex]|r 导入失败：无法解码。"); return end
                
                local decompressed = LibDeflate:DecompressDeflate(decoded)
                if not decompressed then print(L["Import failed: Cannot decompress."] or "|cffff0000[WishFlex]|r 导入失败：无法解压。"); return end
                
                local success, data = LibSerialize:Deserialize(decompressed)
                if not success or type(data) ~= "table" then print(L["Import failed: Data corrupted."] or "|cffff0000[WishFlex]|r 导入失败：数据结构损坏。"); return end
                
                -- 将解析出的数据合并到当前配置中
                for k, v in pairs(data) do WF.db[k] = v end
                
                print((L["Successfully imported "] or "|cff00ff00[WishFlex]|r 成功导入了 [") .. prefix .. (L[" profile! Reloading..."] or "] 模块配置！正在重载界面..."))
                
                -- [关键修复] 直接在鼠标点击事件中同步执行重载，去除 C_Timer 延迟，确保 100% 触发
                ReloadUI()
                
            end)
            scrollChild.Prof_BtnImp = impBtn1
        end
        impBtn1:SetParent(scrollChild); impBtn1:SetWidth(btnWidth); impBtn1:ClearAllPoints(); impBtn1:SetPoint("TOPLEFT", rightX, impY); impBtn1:Show()

        if not impBtn2 then impBtn2 = WF.UI.Factory:CreateFlatButton(scrollChild, L["Clear Input"] or "清空输入框", function() impBox:SetText("") end); scrollChild.Prof_BtnImpClear = impBtn2 end
        impBtn2:SetParent(scrollChild); impBtn2:SetWidth(btnWidth); impBtn2:ClearAllPoints(); impBtn2:SetPoint("LEFT", impBtn1, "RIGHT", 10, 0); impBtn2:Show()
        
        impY = impY - 40
    else
        if impLabel then impLabel:Hide() end; if impScroll and impScroll.bg then impScroll.bg:Hide() end
        if impBtn1 then impBtn1:Hide() end; if impBtn2 then impBtn2:Hide() end
    end

    return -(math_max(math_abs(expY), math_abs(impY))), totalWidth
end)