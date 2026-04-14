local AddonName, ns = ...

-- ==========================================
-- [1. 创建核心框架对象]
-- ==========================================
local WF = CreateFrame("Frame", "WishFlexCore")
_G.WishFlex = WF
ns.WF = WF 

WF.Title = "|cff00ffccWishFlex|r"
WF.ModulesRegistry = {}
ns.L = ns.L or {}
WF.L = ns.L 

-- ==========================================
-- [性能基石]
-- ==========================================
local tablePool = {}
function WF:AcquireTable()
    local t = next(tablePool)
    if t then tablePool[t] = nil; return t end
    return {}
end
function WF:ReleaseTable(t)
    if type(t) ~= "table" then return end
    wipe(t); tablePool[t] = true 
end

WF.EventDispatcher = CreateFrame("Frame")
WF.EventCallbacks = {}
WF.EventDispatcher:SetScript("OnEvent", function(_, event, ...)
    if WF.EventCallbacks[event] then
        for i = 1, #WF.EventCallbacks[event] do
            xpcall(WF.EventCallbacks[event][i], geterrorhandler(), event, ...)
        end
    end
end)
function WF:RegisterEvent(event, callback)
    if type(callback) ~= "function" then return end
    if not self.EventCallbacks[event] then
        self.EventCallbacks[event] = {}
        if not string.match(event, "^WF_") then
            pcall(function() self.EventDispatcher:RegisterEvent(event) end)
        end
    end
    table.insert(self.EventCallbacks[event], callback)
end

function WF:CreateFadeAnim(frame, duration, startAlpha, endAlpha)
    if not frame.wfFadeGroup then
        frame.wfFadeGroup = frame:CreateAnimationGroup()
        local alpha = frame.wfFadeGroup:CreateAnimation("Alpha")
        alpha:SetSmoothing("IN_OUT")
        frame.wfFadeGroup.alpha = alpha
    end
    frame.wfFadeGroup.alpha:SetDuration(duration)
    frame.wfFadeGroup.alpha:SetFromAlpha(startAlpha)
    frame.wfFadeGroup.alpha:SetToAlpha(endAlpha)
    return frame.wfFadeGroup
end

WF.UI = {
    Menus = {}, Panels = {},
    WidgetPools = { toggle = {}, slider = {}, color = {}, dropdown = {}, header = {}, container = {}, input = {} },
    WidgetCounts = { toggle = 0, slider = 0, color = 0, dropdown = 0, header = 0, container = 0, input = 0 }
}
function WF.UI:RegisterMenu(menuData) table.insert(self.Menus, menuData) end
function WF.UI:RegisterPanel(key, renderFunc) self.Panels[key] = renderFunc end

function WF:RegisterModule(key, name, initFunc)
    self.ModulesRegistry[key] = { name = name, Init = initFunc }
end

-- ==========================================
-- [ 核心编辑模式与微调面板引擎 ]
-- ==========================================
WF.Movers = {}
WF.SelectedMover = nil
WF.EditModeControlPanel = nil
WF.BackgroundCatcher = nil
WF._hasCustomEditModeChanges = false

local function EnsureBackgroundCatcher()
    if WF.BackgroundCatcher then return end
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("HIGH")
    catcher:SetFrameLevel(1) 
    catcher:EnableMouse(true)
    catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    catcher:SetScript("OnClick", function()
        if WF.MoversUnlocked and WF.SelectedMover then
            WF:SelectMover(nil)
        end
    end)
    catcher:Hide()
    WF.BackgroundCatcher = catcher
end

local function CreateFlatInput(parent, w, h)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(w, h)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    box:SetBackdropColor(0.15, 0.15, 0.15, 1)
    box:SetBackdropBorderColor(0, 0, 0, 1)
    box:SetTextInsets(2, 2, 0, 0)
    box:SetJustifyH("CENTER")
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

local function ControlPanelOnUpdate(self)
    local s = WF.SelectedMover
    if not s then return end
    
    local cx, cy = s:GetCenter()
    if not cx or not cy then return end
    
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    local nx = math.floor(cx - pw/2 + 0.5)
    local ny = math.floor(cy - ph/2 + 0.5)
    
    if not self.xInput:HasFocus() and tostring(nx) ~= self.xInput:GetText() then
        self.xInput:SetText(tostring(nx))
    end
    if not self.yInput:HasFocus() and tostring(ny) ~= self.yInput:GetText() then
        self.yInput:SetText(tostring(ny))
    end
    
    self:ClearAllPoints()
    self:SetPoint("BOTTOM", s, "TOP", 0, 30)
end

local function CreateEditModePanel()
    if WF.EditModeControlPanel then return end
    local panel = CreateFrame("Frame", "WF_EditModeControlPanel", UIParent, "BackdropTemplate")
    panel:SetSize(160, 140)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(9999)
    panel:EnableMouse(true)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    panel:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
    panel:SetBackdropBorderColor(0, 0, 0, 1)
    panel:Hide()
    
    panel:SetScript("OnUpdate", ControlPanelOnUpdate)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOP", 0, -8)
    panel.title:SetTextColor(0, 0.8, 1)

    panel.xLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.xLabel:SetText("X:")
    panel.xLabel:SetPoint("TOPLEFT", 15, -35)

    panel.xInput = CreateFlatInput(panel, 45, 20)
    panel.xInput:SetPoint("LEFT", panel.xLabel, "RIGHT", 4, 0)

    panel.yLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.yLabel:SetText("Y:")
    panel.yLabel:SetPoint("LEFT", panel.xInput, "RIGHT", 12, 0)

    panel.yInput = CreateFlatInput(panel, 45, 20)
    panel.yInput:SetPoint("LEFT", panel.yLabel, "RIGHT", 4, 0)

    local function OnCoordEntered(self)
        local val = tonumber(self:GetText())
        if not val or not WF.SelectedMover then return end
        self:ClearFocus()
        local x = tonumber(panel.xInput:GetText()) or 0
        local y = tonumber(panel.yInput:GetText()) or 0
        WF:UpdateMoverPos(WF.SelectedMover, x, y)
    end
    panel.xInput:SetScript("OnEnterPressed", OnCoordEntered)
    panel.yInput:SetScript("OnEnterPressed", OnCoordEntered)

    local snapToggle = CreateFrame("Button", nil, panel, "BackdropTemplate")
    snapToggle:SetSize(16, 16)
    snapToggle:SetPoint("TOPLEFT", 15, -62)
    snapToggle:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    snapToggle:SetBackdropColor(0.1, 0.1, 0.1, 1)
    snapToggle:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    local snapIcon = snapToggle:CreateTexture(nil, "OVERLAY")
    snapIcon:SetAllPoints()
    snapIcon:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    snapIcon:Hide()
    snapToggle.icon = snapIcon
    
    local snapText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    snapText:SetPoint("LEFT", snapToggle, "RIGHT", 6, 0)
    
    panel.snapToggle = snapToggle
    panel.snapText = snapText
    
    snapToggle:SetScript("OnClick", function(self)
        local mover = WF.SelectedMover
        if not mover then return end
        local db = WF.db and WF.db.cooldownCustom
        
        local isChecked = not self.icon:IsShown()
        if isChecked then self.icon:Show() else self.icon:Hide() end
        
        if mover == _G.UtilityCooldownViewer and db then
            db.Utility.snapToEssential = isChecked
        elseif mover == _G.BuffIconCooldownViewer and db then
            db.BuffIcon.snapToEssential = isChecked
        elseif mover:GetName() == "WishFlex_Anchor_DefensiveMover" and db then
            db.Defensive.attachToPlayer = isChecked
        elseif mover:GetName() == "WishFlex_ExtraMonitorMover" then
            local emDB = WF.db and WF.db.extraMonitor
            if emDB then emDB.attachToPlayer = isChecked end
            if WF.ExtraMonitorAPI and WF.ExtraMonitorAPI.UpdatePosition then WF.ExtraMonitorAPI:UpdatePosition() end
        end
        
        if WF.TriggerCooldownLayout then WF.TriggerCooldownLayout() end
        if WF.UI and WF.UI.RefreshCurrentPanel then pcall(function() WF.UI:RefreshCurrentPanel() end) end
    end)

    local function CreateNudgeBtn(point, relFrame, relPoint, x, y, dx, dy, rot)
        local btn = CreateFrame("Button", nil, panel, "BackdropTemplate")
        btn:SetSize(24, 24)
        btn:SetPoint(point, relFrame, relPoint, x, y)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
        btn:SetBackdropBorderColor(0, 0, 0, 1)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("CENTER")
        tex:SetSize(14, 14)
        tex:SetTexture("Interface\\AddOns\\WishFlex\\Media\\Icons\\down.tga")
        tex:SetRotation(rot)
        tex:SetVertexColor(0.8, 0.8, 0.8)

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.4, 0.4, 0.4, 1)
            tex:SetVertexColor(0, 0.8, 1) 
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.2, 1)
            tex:SetVertexColor(0.8, 0.8, 0.8)
        end)

        btn:SetScript("OnClick", function()
            if WF.SelectedMover then
                local cx, cy = WF.SelectedMover:GetCenter()
                if cx and cy then
                    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
                    local currentX = math.floor(cx - pw/2 + 0.5)
                    local currentY = math.floor(cy - ph/2 + 0.5)
                    WF:UpdateMoverPos(WF.SelectedMover, currentX + dx, currentY + dy)
                end
            end
        end)
        return btn
    end

    panel.btnUp = CreateNudgeBtn("BOTTOM", panel, "BOTTOM", 0, 38, 0, 1, math.pi)
    panel.btnDown = CreateNudgeBtn("BOTTOM", panel, "BOTTOM", 0, 10, 0, -1, 0)
    panel.btnLeft = CreateNudgeBtn("RIGHT", panel.btnDown, "LEFT", -4, 0, -1, 0, -math.pi/2)
    panel.btnRight = CreateNudgeBtn("LEFT", panel.btnDown, "RIGHT", 4, 0, 1, 0, math.pi/2)

    WF.EditModeControlPanel = panel
end

function WF:UpdateMoverPos(mover, baseCenterX, baseCenterY)
    local x = math.floor(baseCenterX + 0.5)
    local y = math.floor(baseCenterY + 0.5)

    mover:ClearAllPoints()
    mover:SetPoint("CENTER", UIParent, "CENTER", x, y)

    local db = WF.db and WF.db.cooldownCustom
    local emDB = WF.db and WF.db.extraMonitor
    local snapBroke = false
    
    if mover == _G.UtilityCooldownViewer and db and db.Utility and db.Utility.snapToEssential then
        db.Utility.snapToEssential = false; snapBroke = true
    elseif mover == _G.BuffIconCooldownViewer and db and db.BuffIcon and db.BuffIcon.snapToEssential then
        db.BuffIcon.snapToEssential = false; snapBroke = true
    elseif mover:GetName() == "WishFlex_Anchor_DefensiveMover" and db and db.Defensive and db.Defensive.attachToPlayer then
        db.Defensive.attachToPlayer = false; snapBroke = true
    elseif mover:GetName() == "WishFlex_ExtraMonitorMover" and emDB and emDB.attachToPlayer then
        emDB.attachToPlayer = false; snapBroke = true
    end
    
    if snapBroke then
        if WF.EditModeControlPanel and WF.EditModeControlPanel:IsShown() and WF.SelectedMover == mover then
            WF.EditModeControlPanel.snapToggle.icon:Hide()
        end
        if WF.UI and WF.UI.RefreshCurrentPanel then pcall(function() WF.UI:RefreshCurrentPanel() end) end
    end

    if not mover.isNativeEditMode then
        if not WF.db.movers then WF.db.movers = {} end
        WF.db.movers[mover:GetName()] = { point="CENTER", relativePoint="CENTER", xOfs=x, yOfs=y }

        if mover.targetFrame then
            mover.targetFrame:ClearAllPoints()
            mover.targetFrame:SetPoint("CENTER", mover, "CENTER", 0, 0)
        end
    end

    if WF.TriggerCooldownLayout then WF.TriggerCooldownLayout() end
    if WF.WishMonitorAPI and WF.WishMonitorAPI.TriggerUpdate then WF.WishMonitorAPI:TriggerUpdate() end

    C_Timer.After(0.05, function()
        if not mover.isNativeEditMode and mover.targetFrame and WF.MoversUnlocked then
            local isAnchoredToMover = false
            if mover.targetFrame.GetNumPoints then
                for i = 1, mover.targetFrame:GetNumPoints() do
                    local _, relativeTo = mover.targetFrame:GetPoint(i)
                    if relativeTo == mover then isAnchoredToMover = true; break end
                end
            end
            if not isAnchoredToMover then
                mover:ClearAllPoints()
                mover:SetPoint("CENTER", mover.targetFrame, "CENTER", 0, 0)
            end
        end
    end)
end

function WF:SelectMover(mover, isNative)
    WF.SelectedMover = mover
    CreateEditModePanel()
    EnsureBackgroundCatcher()
    
    if mover then
        mover.isNativeEditMode = isNative
        WF.BackgroundCatcher:Show()
        WF.EditModeControlPanel.title:SetText(isNative and (mover.systemName or "原生排版组") or (mover.titleText or "排版控制"))
        
        local cx, cy = mover:GetCenter()
        local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
        local realX = cx and (cx - pw/2) or 0
        local realY = cy and (cy - ph/2) or 0
        
        WF.EditModeControlPanel.xInput:SetText(tostring(math.floor(realX + 0.5)))
        WF.EditModeControlPanel.yInput:SetText(tostring(math.floor(realY + 0.5)))
        
        local db = WF.db and WF.db.cooldownCustom
        local showSnap = false
        
        if mover == _G.UtilityCooldownViewer then
            showSnap = true
            WF.EditModeControlPanel.snapText:SetText("吸附第一行")
            if db and db.Utility and db.Utility.snapToEssential then WF.EditModeControlPanel.snapToggle.icon:Show() else WF.EditModeControlPanel.snapToggle.icon:Hide() end
        elseif mover == _G.BuffIconCooldownViewer then
            showSnap = true
            WF.EditModeControlPanel.snapText:SetText("吸附正上方")
            if db and db.BuffIcon and db.BuffIcon.snapToEssential then WF.EditModeControlPanel.snapToggle.icon:Show() else WF.EditModeControlPanel.snapToggle.icon:Hide() end
        elseif mover:GetName() == "WishFlex_Anchor_DefensiveMover" then
            showSnap = true
            WF.EditModeControlPanel.snapText:SetText("自动吸附头像")
            if db and db.Defensive and db.Defensive.attachToPlayer then WF.EditModeControlPanel.snapToggle.icon:Show() else WF.EditModeControlPanel.snapToggle.icon:Hide() end
        elseif mover:GetName() == "WishFlex_ExtraMonitorMover" then
            showSnap = true
            WF.EditModeControlPanel.snapText:SetText("自动吸附头像")
            local emDB = WF.db and WF.db.extraMonitor
            if emDB and emDB.attachToPlayer then WF.EditModeControlPanel.snapToggle.icon:Show() else WF.EditModeControlPanel.snapToggle.icon:Hide() end
        end
        
        if showSnap then
            WF.EditModeControlPanel.snapToggle:Show()
            WF.EditModeControlPanel.snapText:Show()
            WF.EditModeControlPanel:SetHeight(145)
            WF.EditModeControlPanel.btnUp:SetPoint("BOTTOM", WF.EditModeControlPanel, "BOTTOM", 0, 38)
        else
            WF.EditModeControlPanel.snapToggle:Hide()
            WF.EditModeControlPanel.snapText:Hide()
            WF.EditModeControlPanel:SetHeight(115)
            WF.EditModeControlPanel.btnUp:SetPoint("BOTTOM", WF.EditModeControlPanel, "BOTTOM", 0, 38)
        end
        
        WF.EditModeControlPanel:ClearAllPoints()
        WF.EditModeControlPanel:SetPoint("BOTTOM", mover, "TOP", 0, 30)
        WF.EditModeControlPanel:Show()
    else
        WF.BackgroundCatcher:Hide()
        if WF.EditModeControlPanel then WF.EditModeControlPanel:Hide() end
    end

    for _, m in ipairs(WF.Movers) do
        if m == mover then
            m:SetBackdropColor(0, 0.5, 1, 0.6)
            m:SetBackdropBorderColor(0, 0.8, 1, 1)
            m:SetFrameLevel(100)
            if m.text then m.text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE"); m.text:SetTextColor(1, 1, 1, 1) end
        else
            m:SetBackdropColor(0, 0.5, 1, 0.4)
            m:SetBackdropBorderColor(0, 0.5, 1, 0.6)
            m:SetFrameLevel(90)
            if m.text then m.text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE"); m.text:SetTextColor(1, 1, 1, 1) end
        end
    end
end

function WF:CreateMover(frame, moverName, defaultPoint, width, height, titleText)
    if not frame then return end
    local mover = _G[moverName]
    if not mover then
        mover = CreateFrame("Button", moverName, UIParent, "BackdropTemplate")
        mover:SetSize(width or 100, height or 40)
        mover:SetPoint(unpack(defaultPoint))
        mover:SetFrameStrata("HIGH")
        mover:SetMovable(true); mover:EnableMouse(true)
        mover:RegisterForDrag("LeftButton")
        mover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        mover.isWishFlexMover = true
        
        mover:SetScript("OnDragStart", function(self)
            WF:SelectMover(self, false)
            self:StartMoving()
        end)
        
        mover:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local cx, cy = self:GetCenter()
            local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
            WF:UpdateMoverPos(self, cx - pw/2, cy - ph/2)
        end)
        
        mover:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                WF:SelectMover(self, false)
            end
        end)
        
        mover:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
        mover:SetBackdropColor(0, 0.5, 1, 0.4)
        mover:SetBackdropBorderColor(0, 0.5, 1, 0.6)
        
        mover.text = mover:CreateFontString(nil, "OVERLAY")
        mover.text:SetPoint("BOTTOM", mover, "TOP", 0, 4)
        mover.text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        mover.text:SetTextColor(1, 1, 1, 1)
        mover.text:SetText(titleText or moverName)
        
        mover.titleText = titleText or moverName
        mover:Hide()
        table.insert(WF.Movers, mover)
    end
    
    mover.targetFrame = frame
    frame.mover = mover
    
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", mover, "CENTER")
    
    return mover
end

local function GetTrueBounds(f)
    local fName = f.GetName and f:GetName() or ""
    if fName == "WishFlex_ExtraMonitor" or fName == "WishFlex_DefensiveCooldownViewer" then
        local w, h = f:GetSize()
        if w and h and w > 2 and h > 2 then return w, h end
    end

    local minX, maxX, minY, maxY
    local function checkRect(frame)
        if not frame or not frame:IsShown() or frame:GetAlpha() == 0 then return end
        local l, b, w, h = frame:GetRect()
        if l and b and w and h then
            if not minX or l < minX then minX = l end
            if not maxX or l + w > maxX then maxX = l + w end
            if not minY or b < minY then minY = b end
            if not maxY or b + h > maxY then maxY = b + h end
        end
    end
    
    if f.activeBars then
        for _, bar in pairs(f.activeBars) do checkRect(bar) end
    elseif f.itemFramePool and type(f.itemFramePool.EnumerateActive) == "function" then
        for bar in f.itemFramePool:EnumerateActive() do checkRect(bar) end
    else
        for _, kid in ipairs({f:GetChildren()}) do
            if kid:GetName() ~= "WF_EditModeControlPanel" and not kid.isWishFlexMover then
                checkRect(kid)
            end
        end
    end
    
    if minX and maxX and minY and maxY then
        local uiScale = UIParent:GetEffectiveScale()
        return (maxX - minX) / uiScale, (maxY - minY) / uiScale
    end
    return f:GetSize()
end

local function IsFrameActuallyVisible(f, mover)
    if not f then return false end
    if not f:IsShown() or f:GetAlpha() == 0 then return false end
    if f.itemFramePool and type(f.itemFramePool.GetNumActive) == "function" then
        if f.itemFramePool:GetNumActive() > 0 then return true end
    end
    if f.activeBars then
        for _, bar in pairs(f.activeBars) do
            if type(bar) == "table" and bar.IsShown and bar:IsShown() then return true end
        end
    end
    for _, kid in ipairs({f:GetChildren()}) do
        if kid:IsShown() and kid ~= mover and kid:GetName() ~= "WF_EditModeControlPanel" then
            return true
        end
    end
    return false
end

function WF:SetEditMode(isActive)
    WF.MoversUnlocked = isActive
    
    if not isActive then WF:SelectMover(nil) end

    if WF.ClassResourceAPI and type(WF.ClassResourceAPI.RepositionMonitors) == "function" then
        pcall(function() WF.ClassResourceAPI:RepositionMonitors() end)
    end

    for _, mover in ipairs(WF.Movers) do
        local shouldShow = true
        local mName = mover:GetName()
        local f = mover.targetFrame
        
        if f then
            shouldShow = IsFrameActuallyVisible(f, mover)
        end

        if mName == "WishFlex_Anchor_EssentialMover" or 
           mName == "WishFlex_Anchor_UtilityMover" or 
           mName == "WishFlex_Anchor_BuffIconMover" or 
           mName == "WishFlex_Anchor_BuffBarMover" then
            shouldShow = false
        end

        if mName == "WishFlex_MonitorAnchorMover" or mName == "WishFlex_FreeMonitorAnchorMover" then
            if WF.db and WF.db.wishMonitor and WF.db.wishMonitor.enable == false then shouldShow = false end
        end

        if mName:match("^WishFlex_WM_Anchor_") then
            shouldShow = true
        end

        if WF.MoversUnlocked and shouldShow and f then
            mover:Show()
            
            if WF.SelectedMover ~= mover then
                mover:SetBackdropColor(0, 0.5, 1, 0.4)
                mover:SetBackdropBorderColor(0, 0.5, 1, 0.6)
                mover:SetFrameLevel(90)
                if mover.text then 
                    mover.text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
                    mover.text:SetTextColor(1, 1, 1, 1) 
                end
            end
            
            local isAnchoredToMover = false
            if f.GetNumPoints then
                for i = 1, f:GetNumPoints() do
                    local _, relativeTo = f:GetPoint(i)
                    if relativeTo == mover then isAnchoredToMover = true; break end
                end
            end
            
            if not isAnchoredToMover then
                mover:ClearAllPoints()
                mover:SetPoint("CENTER", f, "CENTER", 0, 0)
            end
            
            local fw, fh = GetTrueBounds(f)
            mover:SetSize(math.max(1, fw), math.max(1, fh))
        else
            mover:Hide()
        end
    end
end

function WF:ToggleMovers()
    WF:SetEditMode(not WF.MoversUnlocked)
end

SLASH_WISHFLEXMOVER1 = "/wfmove"
SlashCmdList["WISHFLEXMOVER"] = function() WF:ToggleMovers() end

function WF:OpenUI()
    if not C_AddOns.IsAddOnLoaded("WishFlex_Options") then
        local loaded, reason = C_AddOns.LoadAddOn("WishFlex_Options")
        if not loaded then print("|cffff0000[WishFlex]|r 无法加载设置模块: " .. tostring(reason)); return end
    end
    if WF.ToggleUI then WF:ToggleUI() end
end

SLASH_WISHFLEX1 = "/wf"; SLASH_WISHFLEX2 = "/wishflex"
SlashCmdList["WISHFLEX"] = function() WF:OpenUI() end
function WF:InitMinimapIcon()
    local L = WF.L
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if LDB and LDBIcon then
        local minimapData = LDB:NewDataObject("WishFlex", {
            type = "launcher", text = "WishFlex",
            icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\Logo3.tga",
            OnClick = function(_, button)
                if button == "LeftButton" then 
                    WF:OpenUI()
                elseif button == "RightButton" then 
                    if EditModeManagerFrame then
                        ShowUIPanel(EditModeManagerFrame)
                        if WF.MainFrame and WF.MainFrame:IsShown() then WF.MainFrame:Hide() end
                        print("|cff00ffcc[WishFlex]|r " .. (L["Entering Edit Mode"] or "正在进入暴雪编辑模式..."))
                    else
                        print("|cffff0000[WishFlex]|r " .. (L["Edit Mode not available."] or "编辑模式不可用。"))
                    end
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("|cff00ffccWishFlex GeniSys|r")
                tooltip:AddLine(" ")
                tooltip:AddLine("|cff00ff00["..(L["Left Click"] or "左键").."]|r "..(L["Open Settings Panel"] or "打开设置控制台"), 1, 1, 1)
                tooltip:AddLine("|cffffaa00["..(L["Right Click"] or "右键").."]|r "..(L["Enter Edit Mode"] or "进入暴雪编辑模式"), 1, 1, 1)
            end,
        })
        if not WF.db.minimap then WF.db.minimap = { hide = false } end
        if not LDBIcon:IsRegistered("WishFlex") then
            LDBIcon:Register("WishFlex", minimapData, WF.db.minimap)
        end
    end
end

local ValidDBKeys = {
    minimap = true, uiScale = true, movers = true,
    cooldownCustom = true, cooldownTracker = true, glow = true, auraGlow = true, wishMonitor = true,
    classResource = true, macroUI = true,
    extraMonitor = true,
}
function WF:PruneDB()
    if not WF.db then return end
    for key in pairs(WF.db) do
        if not ValidDBKeys[key] then
            WF.db[key] = nil
            print("|cff00ffcc[WishFlex]|r 自动清理废弃配置项: " .. tostring(key))
        end
    end
end

local function CopyDefaults(src, target)
    if type(src) ~= "table" then return src end
    if type(target) ~= "table" then target = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            target[k] = CopyDefaults(v, target[k])
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end

local StandbyManager = CreateFrame("Frame")
StandbyManager:RegisterEvent("PLAYER_REGEN_ENABLED")
StandbyManager:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(5, function()
            if not InCombatLockdown() then
                collectgarbage("collect")
            end
        end)
    end
end)

WF:RegisterEvent("ADDON_LOADED", function(event, addon)
    if addon == "WishFlex" then
        if not WishFlexDB then WishFlexDB = {} end
        
        -- 初始化全局配置结构
        if not WishFlexDB.profiles then WishFlexDB.profiles = {} end
        if not WishFlexDB.currentProfile then WishFlexDB.currentProfile = {} end
        if not WishFlexDB.specProfiles then WishFlexDB.specProfiles = {} end

        local playerKey = UnitName("player") .. "-" .. GetRealmName()
        
        -- 当某个角色首次加载时，为其创建基于角色名的独立配置档
        if not WishFlexDB.currentProfile[playerKey] then
            if not WishFlexDB.profiles[playerKey] then
                WishFlexDB.profiles[playerKey] = {}
                if ns.DefaultConfig then
                    WishFlexDB.profiles[playerKey] = CopyDefaults(ns.DefaultConfig, WishFlexDB.profiles[playerKey])
                end
            end
            WishFlexDB.currentProfile[playerKey] = playerKey
        end

        local activeProfileName = WishFlexDB.currentProfile[playerKey]
        
        -- 容错：如果指向的配置文件被删除了，重新为当前角色生成
        if not WishFlexDB.profiles[activeProfileName] then 
            activeProfileName = playerKey
            WishFlexDB.profiles[activeProfileName] = {}
            if ns.DefaultConfig then
                WishFlexDB.profiles[activeProfileName] = CopyDefaults(ns.DefaultConfig, WishFlexDB.profiles[activeProfileName])
            end
        end

        WF.db = WishFlexDB.profiles[activeProfileName]
        WF.globalDB = WishFlexDB
        WF.activeProfile = activeProfileName
        WF.playerKey = playerKey

        WF:PruneDB() 
        WF:InitMinimapIcon()
    end
end)

local function InitializeAddon()
    for key, data in pairs(WF.ModulesRegistry) do
        if WF.db[key] == nil then WF.db[key] = { enable = false } end
        if WF.db[key].enable then
            if type(data.Init) == "function" then
                data.Init()
                -- [修改] 移除了原有的单个模块加载 print 提示，避免刷屏
            end
        end
    end
    
    -- [修改] 将原来的核心引擎长提示，替换为你要的极简提示
    print("|cff00ffcc[WishFlex]|r 已加载模块: 输入 /wf 打开设置，/wfmove 解锁锚点")

    if EditModeManagerFrame then
        if type(EditModeManagerFrame.EnterEditMode) == "function" then
            hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() WF:SetEditMode(true) end)
        end
        if type(EditModeManagerFrame.ExitEditMode) == "function" then
            hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() WF:SetEditMode(false) end)
        end
        if type(EditModeManagerFrame.IsEditModeActive) == "function" and EditModeManagerFrame:IsEditModeActive() then 
            WF:SetEditMode(true) 
        end
        
        if type(EditModeManagerFrame.SelectSystem) == "function" then
            hooksecurefunc(EditModeManagerFrame, "SelectSystem", function(self, system)
                if system == _G.EssentialCooldownViewer or 
                   system == _G.UtilityCooldownViewer or 
                   system == _G.BuffIconCooldownViewer or 
                   system == _G.BuffBarCooldownViewer then
                    
                    if system == _G.EssentialCooldownViewer then system.systemName = "核心技能 (第一行)"
                    elseif system == _G.UtilityCooldownViewer then system.systemName = "效能技能 (第二行)"
                    elseif system == _G.BuffIconCooldownViewer then system.systemName = "增益图标组"
                    elseif system == _G.BuffBarCooldownViewer then system.systemName = "增益条组"
                    end
                    
                    WF:SelectMover(system, true)
                elseif system and system.isWishFlexMover then
                else
                    WF:SelectMover(nil)
                end
            end)
        end
        
        if type(EditModeManagerFrame.ClearSelectedSystem) == "function" then
            hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function()
                if WF.SelectedMover and WF.SelectedMover.isNativeEditMode then
                    WF:SelectMover(nil)
                end
            end)
        end

        if type(EditModeManagerFrame.UpdateSystemPositions) == "function" then
            hooksecurefunc(EditModeManagerFrame, "UpdateSystemPositions", function()
                if not WF.db or not WF.db.movers then return end
                for _, mover in ipairs(WF.Movers) do
                    local saveKey = mover:GetName()
                    local pos = WF.db.movers[saveKey]
                    if pos and mover.targetFrame then
                        if not mover.isNativeEditMode then
                            mover.targetFrame:ClearAllPoints()
                            mover.targetFrame:SetPoint("CENTER", UIParent, "CENTER", pos.xOfs, pos.yOfs)
                        end
                    end
                end
            end)
        end
    end
end

WF:RegisterEvent("PLAYER_LOGIN", InitializeAddon)

WF:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(event, unit)
    if unit and unit ~= "player" then return end
    if not WF.globalDB or not WF.globalDB.specProfiles then return end
    
    local specIndex = GetSpecialization()
    if specIndex then
        local specID = GetSpecializationInfo(specIndex)
        local targetProfile = WF.globalDB.specProfiles[tostring(specID)]
        
        if targetProfile and targetProfile ~= WF.activeProfile and WF.globalDB.profiles[targetProfile] then
            WF.globalDB.currentProfile[WF.playerKey] = targetProfile
            print("|cff00ffcc[WishFlex]|r 检测到专精切换，正在自动加载配置: [" .. targetProfile .. "]")
            C_Timer.After(1.5, ReloadUI) 
        end
    end
end)