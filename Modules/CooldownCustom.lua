local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')
local LSM = E.Libs.LSM
local WUI = E:GetModule('WishFlex')
local mod = WUI:NewModule('CooldownCustom', 'AceHook-3.0', 'AceEvent-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

local DEFAULT_SWIPE_COLOR = {r = 0, g = 0, b = 0, a = 0.8}
local DEFAULT_ACTIVE_AURA_COLOR = {r = 1, g = 0.95, b = 0.57, a = 0.69}
local DEFAULT_CD_COLOR = {r = 1, g = 0.82, b = 0}
local DEFAULT_STACK_COLOR = {r = 1, g = 1, b = 1}

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.cooldownCustom = true
P["WishFlex"].cdManager = {
    swipeColor = DEFAULT_SWIPE_COLOR, activeAuraColor = DEFAULT_ACTIVE_AURA_COLOR, reverseSwipe = true,
    Utility = { width = 45, height = 30, iconGap = 2, growth = "CENTER", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackXOffset = 12, stackYOffset = -12 },
    BuffBar = { width = 120, height = 30, iconGap = 2, growth = "DOWN", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackXOffset = 12, stackYOffset = -12 },
    BuffIcon = { width = 45, height = 45, iconGap = 2, growth = "CENTER", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackXOffset = 12, stackYOffset = -12 }, 
    Essential = { enableCustomLayout = true, injectActionTimer = false, maxPerRow = 7, iconGap = 2, glowEnable = true, glowColor = {r = 1, g = 1, b = 1, a = 1}, glowLines = 8, glowFreq = 0.25, glowLength = 10, glowThick = 2,
        row1Width = 45, row1Height = 45, row1CdFontSize = 18, row1CdFontColor = DEFAULT_CD_COLOR, row1CdXOffset = 0, row1CdYOffset = 0, row1StackFontSize = 14, row1StackFontColor = DEFAULT_STACK_COLOR, row1StackXOffset = 12, row1StackYOffset = -12, 
        row2Width = 40, row2Height = 40, row2IconGap = 2, row2CdFontSize = 18, row2CdFontColor = DEFAULT_CD_COLOR, row2CdXOffset = 0, row2CdYOffset = 0, row2StackFontSize = 14, row2StackFontColor = DEFAULT_STACK_COLOR, row2StackXOffset = 12, row2StackYOffset = -12 },
    countFont = "Expressway", countFontOutline = "OUTLINE", countFontColor = DEFAULT_STACK_COLOR,
}

local function GetKeyFromFrame(frame)
    local parent = frame:GetParent()
    while parent do
        local name = parent:GetName() or ""
        if name:find("UtilityCooldownViewer") then return "Utility" end
        if name:find("BuffBarCooldownViewer") then return "BuffBar" end
        if name:find("BuffIconCooldownViewer") then return "BuffIcon" end
        if name:find("EssentialCooldownViewer") then return "Essential" end
        parent = parent:GetParent()
    end
    return nil
end

function mod.ApplyTexCoord(texture, width, height)
    if not texture or not texture.SetTexCoord then return end
    local ratio = width / height
    local offset = 0.08
    local left, right, top, bottom = offset, 1-offset, offset, 1-offset
    if ratio > 1 then
        local vH = (1 - 2*offset) / ratio; top, bottom = 0.5 - (vH/2), 0.5 + (vH/2)
    elseif ratio < 1 then
        local vW = (1 - 2*offset) * ratio; left, right = 0.5 - (vW/2), 0.5 + (vW/2)
    end
    texture:SetTexCoord(left, right, top, bottom)
end

local HookedFrames = {}
local function SuppressDebuffBorder(f)
    if not f or HookedFrames[f] then return end
    HookedFrames[f] = true
    local borders = { f.DebuffBorder, f.Border, f.IconBorder, f.IconOverlay, f.overlay, f.ExpireBorder, f.Icon and f.Icon.Border, f.Icon and f.Icon.IconBorder, f.Icon and f.Icon.DebuffBorder }
    for i = 1, #borders do
        local border = borders[i]
        if border then
            border:Hide(); border:SetAlpha(0)
            if type(border.Show) == "function" then hooksecurefunc(border, "Show", function(self) self:Hide(); self:SetAlpha(0) end) end
            if type(border.UpdateFromAuraData) == "function" then hooksecurefunc(border, "UpdateFromAuraData", function(self) self:Hide(); self:SetAlpha(0) end) end
        end
    end
    if f.PandemicIcon then f.PandemicIcon:SetAlpha(0); f.PandemicIcon:Hide() end
    if type(f.ShowPandemicStateFrame) == "function" then hooksecurefunc(f, "ShowPandemicStateFrame", function(self) if self.PandemicIcon then self.PandemicIcon:Hide(); self.PandemicIcon:SetAlpha(0) end end) end
    if f.CooldownFlash then
        f.CooldownFlash:SetAlpha(0); f.CooldownFlash:Hide()
        if type(f.CooldownFlash.Show) == "function" then hooksecurefunc(f.CooldownFlash, "Show", function(self) self:Hide(); self:SetAlpha(0); if self.FlashAnim then self.FlashAnim:Stop() end end) end
        if f.CooldownFlash.FlashAnim and type(f.CooldownFlash.FlashAnim.Play) == "function" then hooksecurefunc(f.CooldownFlash.FlashAnim, "Play", function(self) self:Stop(); f.CooldownFlash:Hide() end) end
    end
    if f.SpellActivationAlert then
        f.SpellActivationAlert:SetAlpha(0); f.SpellActivationAlert:Hide()
        if type(f.SpellActivationAlert.Show) == "function" then hooksecurefunc(f.SpellActivationAlert, "Show", function(self) self:Hide(); self:SetAlpha(0) end) end
    end
    local bg = f.backdrop or f
    if bg and type(bg.SetBackdropBorderColor) == "function" then
        hooksecurefunc(bg, "SetBackdropBorderColor", function(self, r, g, b, a)
            if self.isHookingColor then return end
            local dr, dg, db = 0, 0, 0
            if E.media and E.media.bordercolor then dr, dg, db = unpack(E.media.bordercolor) end
            if math.abs((r or 0) - dr) > 0.01 or math.abs((g or 0) - dg) > 0.01 or math.abs((b or 0) - db) > 0.01 then
                self.isHookingColor = true; self:SetBackdropBorderColor(dr, dg, db, a or 1); self.isHookingColor = false
            end
        end)
        local dr, dg, db = 0, 0, 0
        if E.media and E.media.bordercolor then dr, dg, db = unpack(E.media.bordercolor) end
        bg.isHookingColor = true; bg:SetBackdropBorderColor(dr, dg, db, 1); bg.isHookingColor = false
    end
end

local function WeldToMover(frame)
    if frame and frame.mover then
        if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end
        frame:ClearAllPoints(); frame:SetPoint("CENTER", frame.mover, "CENTER")
    end
end

local function SafeMover(frame, moverName, title, defaultPoint)
    if not frame then return end
    if not frame:GetNumPoints() or frame:GetNumPoints() == 0 then frame:SetPoint(unpack(defaultPoint)) end
    if not frame.mover then E:CreateMover(frame, moverName, title, nil, nil, nil, "ALL,WishFlex") end
end

local function GetEssentialGroup(dbKey, tabName, order)
    return {
        order = order, type = "group", name = tabName,
        get = function(i) return E.db.WishFlex.cdManager[dbKey][i[#i]] end,
        set = function(i, v) E.db.WishFlex.cdManager[dbKey][i[#i]] = v; mod:TriggerLayout() end,
        args = {
            layoutStatus = { order = 1, type = "group", name = "第一行", guiInline = true, args = { enableCustomLayout = { order = 1, type = "toggle", name = "启用双行" }, injectActionTimer = { order = 1.5, type = "toggle", name = "合并饰品药水", get = function() return E.db.WishFlex.cdManager.Essential.injectActionTimer end, set = function(_, v) E.db.WishFlex.cdManager.Essential.injectActionTimer = v; mod:TriggerLayout(); local AT = WUI:GetModule('ActionTimer', true); if AT and not v then AT:UpdateLayout() end end }, maxPerRow = { order = 2, type = "range", name = "最大数", min = 1, max = 20, step = 1 }, iconGap = { order = 3, type = "range", name = "间距", min = 0, max = 20, step = 1 } } },
            row1Size = { order = 2, type = "group", name = "第一行尺寸", guiInline = true, args = { row1Width = { order=1, type="range", name="宽度", min=10, max=100, step=1 }, row1Height = { order=2, type="range", name="高度", min=10, max=100, step=1 } } },
            row1CdText = { order = 3, type = "group", name = "第一行 冷却倒计时", guiInline = true, args = { row1CdFontSize = {order=1,type="range",name="大小",min=4,max=40,step=1}, row1CdFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Essential.row1CdFontColor; return t and t.r or 1, t and t.g or 0.82, t and t.b or 0 end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Essential.row1CdFontColor={r=r,g=g,b=b} end}, row1CdXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, row1CdYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            row1StackText = { order = 4, type = "group", name = "第一行 层数文本", guiInline = true, args = { row1StackFontSize = {order=1,type="range",name="大小",min=4,max=40,step=1}, row1StackFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Essential.row1StackFontColor; return t and t.r or 1, t and t.g or 1, t and t.b or 1 end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Essential.row1StackFontColor={r=r,g=g,b=b} end}, row1StackXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, row1StackYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            row2Size = { order = 5, type = "group", name = "第二行尺寸", guiInline = true, args = { row2Width = { order=1, type="range", name="宽度", min=10, max=100, step=1 }, row2Height = { order=2, type="range", name="高度", min=10, max=100, step=1 }, row2IconGap = { order=3, type="range", name="间距", min=0, max=20, step = 1 } } },
            row2CdText = { order = 6, type = "group", name = "第二行 冷却倒计时", guiInline = true, args = { row2CdFontSize = {order=1,type="range",name="大小",min=4,max=40,step=1}, row2CdFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Essential.row2CdFontColor; return t and t.r or 1, t and t.g or 0.82, t and t.b or 0 end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Essential.row2CdFontColor={r=r,g=g,b=b} end}, row2CdXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, row2CdYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            row2StackText = { order = 7, type = "group", name = "第二行 层数文本", guiInline = true, args = { row2StackFontSize = {order=1,type="range",name="大小",min=4,max=40,step=1}, row2StackFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager.Essential.row2StackFontColor; return t and t.r or 1, t and t.g or 1, t and t.b or 1 end, set=function(_,r,g,b) E.db.WishFlex.cdManager.Essential.row2StackFontColor={r=r,g=g,b=b} end}, row2StackXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, row2StackYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            glowGrp1 = { order = 8, type = "group", name = "高亮图标", guiInline = true, args = { glowEnable = { order = 1, type = "toggle", name = "像素发光" }, glowColor = { order = 2, type = "color", name = "线条颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.cdManager.Essential.glowColor or {r=1,g=1,b=1,a=1} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.cdManager.Essential.glowColor = {r=r,g=g,b=b,a=a}; mod:TriggerLayout() end }, glowLines = { order = 3, type = "range", name = "线条数", min = 1, max = 20, step = 1 }, glowFreq = { order = 4, type = "range", name = "速度", min = 0.05, max = 2, step = 0.05 }, glowThick = { order = 5, type = "range", name = "线条粗细", min = 1, max = 10, step = 1 } } }
        }
    }
end

local function GetCDSubGroup(dbKey, tabName, order, isVertical)
    local growthValues = isVertical and { ["UP"] = "向上", ["DOWN"] = "向下" } or { ["LEFT"] = "向左", ["CENTER"] = "居中", ["RIGHT"] = "向右" }
    return {
        order = order, type = "group", name = tabName, 
        get = function(i) return E.db.WishFlex.cdManager[dbKey][i[#i]] end,
        set = function(i, v) E.db.WishFlex.cdManager[dbKey][i[#i]] = v; mod:TriggerLayout() end,
        args = {
            layout = { order = 1, type = "group", name = "排版", guiInline = true, args = { growth = { order = 1, type = "select", name = "增长方向", values = growthValues }, iconGap = { order = 2, type = "range", name = "间距", min = 0, max = 20, step = 1 } } },
            sizeSet = { order = 2, type = "group", name = "图标宽高", guiInline = true, args = { width = {order=1,type="range",name="宽度",min=10,max=400,step=1}, height = {order=2,type="range",name="高度",min=10,max=100,step=1} } },
            cdText = { order = 3, type = "group", name = "冷却倒计时", guiInline = true, args = { cdFontSize = {order=1,type="range",name="大小",min=4,max=40,step=1}, cdFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager[dbKey].cdFontColor; return t and t.r or 1, t and t.g or 0.82, t and t.b or 0 end, set=function(_,r,g,b) E.db.WishFlex.cdManager[dbKey].cdFontColor={r=r,g=g,b=b} end}, cdXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, cdYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            stackText = { order = 4, type = "group", name = "层数文本", guiInline = true, args = { stackFontSize = {order=1,type="range",name="大小",min=4,max=40,step=1}, stackFontColor = {order=2,type="color",name="颜色",get=function() local t=E.db.WishFlex.cdManager[dbKey].stackFontColor; return t and t.r or 1, t and t.g or 1, t and t.b or 1 end, set=function(_,r,g,b) E.db.WishFlex.cdManager[dbKey].stackFontColor={r=r,g=g,b=b} end}, stackXOffset = {order=3,type="range",name="X偏移",min=-50,max=50,step=1}, stackYOffset = {order=4,type="range",name="Y偏移",min=-50,max=50,step=1} } },
        }
    }
end

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.cdmanager = { order = 20, type = "group", name = "|cff00e5cc冷却管理器|r", childGroups = "tab", args = {} }
    local args = WUI.OptionsArgs.cdmanager.args
    
    args.base = { 
        order = 1, type = "group", name = "全局与外观", 
        args = { 
            enable = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.modules.cooldownCustom end, set = function(_, v) E.db.WishFlex.modules.cooldownCustom = v; E:StaticPopup_Show("CONFIG_RL") end }, 
            countFont = { order = 2, type = "select", dialogControl = 'LSM30_Font', name = "全局字体", values = LSM:HashTable("font"), get = function() return E.db.WishFlex.cdManager.countFont end, set = function(_, v) E.db.WishFlex.cdManager.countFont = v; mod:TriggerLayout() end }, 
            countFontOutline = { order = 3, type = "select", name = "字体描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" }, get = function() return E.db.WishFlex.cdManager.countFontOutline end, set = function(_, v) E.db.WishFlex.cdManager.countFontOutline = v; mod:TriggerLayout() end }, 
            swipeColor = { order = 5, type = "color", name = "全局冷却遮罩颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.cdManager.swipeColor or DEFAULT_SWIPE_COLOR return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.cdManager.swipeColor = {r=r,g=g,b=b,a=a}; mod:TriggerLayout() end },
            activeAuraColor = { order = 6, type = "color", name = "BUFF激活遮罩颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.cdManager.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.cdManager.activeAuraColor = {r=r,g=g,b=b,a=a}; mod:TriggerLayout() end },
            reverseSwipe = { order = 7, type = "toggle", name = "反向遮罩(亮变黑)", get = function() return E.db.WishFlex.cdManager.reverseSwipe end, set = function(_, v) E.db.WishFlex.cdManager.reverseSwipe = v; mod:TriggerLayout() end }
        } 
    }
    args.essential = GetEssentialGroup("Essential", "重要技能", 2)
    args.utility = GetCDSubGroup("Utility", "效能技能", 4, false)
    args.bufficon = GetCDSubGroup("BuffIcon", "增益图标", 5, false) 
    args.buffbar = GetCDSubGroup("BuffBar", "增益条", 6, true) 
end

local function SortByLeft(a, b) return (a:GetLeft() or 0) < (b:GetLeft() or 0) end
local function SortByLayoutIndex(a, b) return (a.layoutIndex or 999) < (b.layoutIndex or 999) end
local function SortByATDataId(a, b) return a.data.id < b.data.id end

local function StaticUpdateSwipeColor(self)
    local b = self:GetParent()
    local cddb = E.db.WishFlex.cdManager
    if b and b.wasSetFromAura then
        local ac = cddb.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR
        self:SetSwipeColor(ac.r, ac.g, ac.b, ac.a)
    else
        local sc = cddb.swipeColor or DEFAULT_SWIPE_COLOR
        self:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
    end
end

local function HookedSetPoint(self)
    if self._isWishStyling then return end
    self._isWishStyling = true
    self:ClearAllPoints()
    self:SetPoint(self._wishAnchor, self._wishParent, self._wishAnchor, self._wishX, self._wishY)
    self._isWishStyling = false
end

local function HookedSetTextColor(self)
    if self._isWishStyling then return end
    self._isWishStyling = true
    self:SetTextColor(self._wishColor.r, self._wishColor.g, self._wishColor.b)
    self._isWishStyling = false
end

local function HookedSetFont(self)
    if self._isWishStyling then return end
    self._isWishStyling = true
    if self.FontTemplate then self:FontTemplate(self._wishFontPath, self._wishSize, self._wishOutline) else self:SetFont(self._wishFontPath, self._wishSize, self._wishOutline) end
    self._isWishStyling = false
end

local function HijackSetPoint(self)
    if self._isHijackStyling then return end
    if not (self._hijackParent and self._hijackParent.isHijackedByEssential) then return end
    self._isHijackStyling = true
    self:ClearAllPoints()
    self:SetPoint("CENTER", self._hijackParent, "CENTER", self._hijackX, self._hijackY)
    self._isHijackStyling = false
end

local function HijackSetTextColor(self)
    if self._isHijackStyling then return end
    if not (self._hijackParent and self._hijackParent.isHijackedByEssential) then return end
    self._isHijackStyling = true
    self:SetTextColor(self._hijackColor.r, self._hijackColor.g, self._hijackColor.b)
    self._isHijackStyling = false
end

local function HijackSetFont(self)
    if self._isHijackStyling then return end
    if not (self._hijackParent and self._hijackParent.isHijackedByEssential) then return end
    self._isHijackStyling = true
    if self.FontTemplate then self:FontTemplate(self._hijackFontPath, self._hijackSize, self._hijackOutline) else self:SetFont(self._hijackFontPath, self._hijackSize, self._hijackOutline) end
    self._isHijackStyling = false
end

function mod:ApplySwipeSettings(frame)
    if not frame or not frame.Cooldown then return end
    local db = E.db.WishFlex.cdManager
    local rev = db.reverseSwipe
    if rev == nil then rev = true end
    frame.Cooldown:SetReverse(rev)

    if not frame.Cooldown._wishSwipeHooked then
        hooksecurefunc(frame.Cooldown, "SetCooldown", StaticUpdateSwipeColor)
        if frame.Cooldown.SetCooldownFromDurationObject then hooksecurefunc(frame.Cooldown, "SetCooldownFromDurationObject", StaticUpdateSwipeColor) end
        frame.Cooldown._wishSwipeHooked = true
    end

    if frame.wasSetFromAura then
        local ac = db.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR
        frame.Cooldown:SetSwipeColor(ac.r, ac.g, ac.b, ac.a)
    else
        local sc = db.swipeColor or DEFAULT_SWIPE_COLOR
        frame.Cooldown:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
    end
end

local function FormatText(t, isStack, cdSize, cdColor, cdX, cdY, stackSize, stackColor, stackX, stackY, fontPath, outline, frame)
    if not t or type(t) ~= "table" or not t.SetFont then return end
    local size = isStack and stackSize or cdSize
    local color = isStack and stackColor or cdColor
    local ox = isStack and stackX or cdX
    local oy = isStack and stackY or cdY
    
    t._wishFontPath, t._wishSize, t._wishOutline, t._wishAnchor, t._wishParent, t._wishX, t._wishY, t._wishColor = fontPath, size, outline, "CENTER", frame.Icon or frame, ox, oy, color
    t._isWishStyling = true
    if t.FontTemplate then t:FontTemplate(fontPath, size, outline) else t:SetFont(fontPath, size, outline) end
    t:SetTextColor(color.r, color.g, color.b); t:ClearAllPoints(); t:SetPoint("CENTER", frame.Icon or frame, "CENTER", ox, oy); t:SetDrawLayer("OVERLAY", 7)
    t._isWishStyling = false
    
    if not t._wishStyleHooked then
        t._wishStyleHooked = true
        hooksecurefunc(t, "SetPoint", HookedSetPoint)
        hooksecurefunc(t, "SetTextColor", HookedSetTextColor)
        hooksecurefunc(t, "SetFont", HookedSetFont)
    end
end

function mod:ApplyText(frame, category, rowIndex)
    local db = E.db.WishFlex.cdManager
    local cfg = db[category]
    if not cfg then return end
    local fontPath = LSM:Fetch('font', db.countFont or "Expressway")
    local outline = db.countFontOutline or "OUTLINE"
    local cdSize, cdColor, cdX, cdY, stackSize, stackColor, stackX, stackY

    if category == "Essential" then
        if rowIndex == 2 then 
            cdSize, cdColor, cdX, cdY = cfg.row2CdFontSize, cfg.row2CdFontColor, cfg.row2CdXOffset, cfg.row2CdYOffset
            stackSize, stackColor, stackX, stackY = cfg.row2StackFontSize, cfg.row2StackFontColor, cfg.row2StackXOffset, cfg.row2StackYOffset
        else 
            cdSize, cdColor, cdX, cdY = cfg.row1CdFontSize, cfg.row1CdFontColor, cfg.row1CdXOffset, cfg.row1CdYOffset
            stackSize, stackColor, stackX, stackY = cfg.row1StackFontSize, cfg.row1StackFontColor, cfg.row1StackXOffset, cfg.row1StackYOffset
        end
    else
        cdSize, cdColor, cdX, cdY = cfg.cdFontSize, cfg.cdFontColor, cfg.cdXOffset, cfg.cdYOffset
        stackSize, stackColor, stackX, stackY = cfg.stackFontSize, cfg.stackFontColor, cfg.stackXOffset, cfg.stackYOffset
    end

    local stackText = (frame.Applications and frame.Applications.Applications) or (frame.ChargeCount and frame.ChargeCount.Current) or (not frame.isHijackedByEssential and frame.Count)
    if frame.Cooldown then
        if frame.Cooldown.timer and frame.Cooldown.timer.text then FormatText(frame.Cooldown.timer.text, false, cdSize, cdColor, cdX, cdY, stackSize, stackColor, stackX, stackY, fontPath, outline, frame) end
        
        for k = 1, select("#", frame.Cooldown:GetRegions()) do 
            local region = select(k, frame.Cooldown:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("FontString") then 
                FormatText(region, false, cdSize, cdColor, cdX, cdY, stackSize, stackColor, stackX, stackY, fontPath, outline, frame) 
            end 
        end
    end
    FormatText(stackText, true, cdSize, cdColor, cdX, cdY, stackSize, stackColor, stackX, stackY, fontPath, outline, frame)
end

local cachedIcons = {}
local cachedFrames = {}
local cachedR1 = {}
local cachedR2 = {}
local cachedActiveAT = {}

local function DoLayoutBuffs(viewerName, key, isVertical)
    local db = E.db.WishFlex.cdManager
    local container = _G[viewerName]
    if not container or not container:IsShown() then return end
    
    WeldToMover(container)
    table.wipe(cachedIcons)
    local count = 0
    
    if container.itemFramePool then 
        for f in container.itemFramePool:EnumerateActive() do 
            if f:IsShown() and f:GetWidth() > 10 then 
                count = count + 1
                cachedIcons[count] = f
                SuppressDebuffBorder(f); mod:ApplyText(f, key); mod:ApplySwipeSettings(f)
            end 
        end 
    end 
    if count == 0 then return end
    table.sort(cachedIcons, SortByLeft)
    
    local cfg = db[key]; local w, h, gap, growth = cfg.width or 45, cfg.height or 45, cfg.iconGap or 2, cfg.growth or (isVertical and "DOWN" or "CENTER")
    local totalW = (count * w) + math.max(0, (count - 1) * gap)
    local totalH = (count * h) + math.max(0, (count - 1) * gap)
    
    container:SetSize(isVertical and w or totalW, isVertical and totalH or h)
    if container.mover then container.mover:SetSize(container:GetSize()) end
    
    for i = 1, count do
        local f = cachedIcons[i]
        f:ClearAllPoints()
        
        if isVertical then 
            local y = -(totalH / 2) + (h / 2) + (i - 1) * (h + gap)
            if growth == "UP" then f:SetPoint("CENTER", container, "CENTER", 0, y) 
            elseif growth == "DOWN" then f:SetPoint("CENTER", container, "CENTER", 0, -y) 
            else f:SetPoint("CENTER", container, "CENTER", 0, -y) end
        else 
            local x = -(totalW / 2) + (w / 2) + (i - 1) * (w + gap)
            if growth == "LEFT" then f:SetPoint("CENTER", container, "CENTER", -x, 0) 
            elseif growth == "RIGHT" then f:SetPoint("CENTER", container, "CENTER", x, 0) 
            else f:SetPoint("CENTER", container, "CENTER", x, 0) end 
        end
        
        f:SetSize(w, h)
        if f.Icon then
            local iconObj = f.Icon.Icon or f.Icon
            if not f.Bar then 
                f.Icon:SetSize(w, h); mod.ApplyTexCoord(iconObj, w, h)
            else 
                f.Icon:SetSize(h, h); f.Bar:SetSize(w - h - gap, h)
                f.Bar:ClearAllPoints(); f.Bar:SetPoint("LEFT", f.Icon, "RIGHT", gap, 0)
                if iconObj then mod.ApplyTexCoord(iconObj, h, h) end 
            end
        end
    end
end

function mod:ForceBuffsLayout()
    DoLayoutBuffs("BuffIconCooldownViewer", "BuffIcon", false)
    DoLayoutBuffs("BuffBarCooldownViewer", "BuffBar", true)
end

function mod:UpdateAllLayouts()
    local db = E.db.WishFlex.cdManager
    local function LayoutViewer(viewer, cfg, cat)
        if not viewer or not viewer.itemFramePool then return end
        WeldToMover(viewer)
        
        table.wipe(cachedFrames)
        local count = 0
        for f in viewer.itemFramePool:EnumerateActive() do 
            if f:IsShown() then 
                count = count + 1
                cachedFrames[count] = f 
                SuppressDebuffBorder(f); self:ApplyText(f, cat); self:ApplySwipeSettings(f)
            end 
        end
        if count == 0 then return end
        
        table.sort(cachedFrames, SortByLayoutIndex)
        local w, h, gap, growth = cfg.width or 45, cfg.height or 30, cfg.iconGap or 2, cfg.growth or "CENTER"
        local totalW = (count * w) + math.max(0, (count - 1) * gap)
        viewer:SetSize(math.max(w, totalW), h); if viewer.mover then viewer.mover:SetSize(math.max(w, totalW), h) end
        
        for i = 1, count do
            local f = cachedFrames[i]
            f:ClearAllPoints(); 
            local x = -(totalW / 2) + (w / 2) + (i - 1) * (w + gap)
            if growth == "CENTER" then f:SetPoint("CENTER", viewer, "CENTER", x, 0)
            elseif growth == "LEFT" then f:SetPoint("CENTER", viewer, "CENTER", -x, 0)
            elseif growth == "RIGHT" then f:SetPoint("CENTER", viewer, "CENTER", x, 0) end
            
            f:SetSize(w, h); if f.Icon then mod.ApplyTexCoord(f.Icon.Icon or f.Icon, w, h) end
        end
    end
    LayoutViewer(_G.UtilityCooldownViewer, db.Utility, "Utility")

    local eViewer = _G.EssentialCooldownViewer
    if eViewer and eViewer.itemFramePool then
        WeldToMover(eViewer)
        table.wipe(cachedFrames)
        local count = 0
        for f in eViewer.itemFramePool:EnumerateActive() do 
            if f:IsShown() then count = count + 1; cachedFrames[count] = f end 
        end
        
        if count > 0 then
            table.sort(cachedFrames, SortByLayoutIndex)
            local cfgE = db.Essential
            if cfgE.enableCustomLayout then
                table.wipe(cachedR1); table.wipe(cachedR2)
                local r1c, r2c = 0, 0
                for i = 1, count do 
                    local f = cachedFrames[i]
                    if i <= cfgE.maxPerRow then r1c = r1c + 1; cachedR1[r1c] = f else r2c = r2c + 1; cachedR2[r2c] = f end 
                end
                
                local AT = WUI:GetModule('ActionTimer', true)
                if cfgE.injectActionTimer and AT and AT.Frames and AT.trackedItems then
                    table.wipe(cachedActiveAT)
                    local atc = 0
                    for uniqueKey, data in pairs(AT.trackedItems) do if AT.Frames[uniqueKey] and AT.Frames[uniqueKey]:IsShown() then atc = atc + 1; cachedActiveAT[atc] = AT.Frames[uniqueKey] end end
                    
                    table.sort(cachedActiveAT, SortByATDataId)
                    for i = 1, atc do local f = cachedActiveAT[i]; f.isHijackedByEssential = true; r2c = r2c + 1; cachedR2[r2c] = f end
                    if not AT._essentialInjectHooked then AT._essentialInjectHooked = true; hooksecurefunc(AT, "UpdateLayout", function() if E.db.WishFlex.cdManager.Essential.injectActionTimer then mod:TriggerLayout() end end) end
                else if AT and AT.Frames then for _, f in pairs(AT.Frames) do f.isHijackedByEssential = false end end end

                local w1, h1, gap = cfgE.row1Width, cfgE.row1Height, cfgE.iconGap
                local totalW1 = (r1c * w1) + math.max(0, (r1c - 1) * gap)
                eViewer:SetSize(math.max(w1, totalW1), h1); if eViewer.mover then eViewer.mover:SetSize(math.max(w1, totalW1), h1) end
                
                for i = 1, r1c do
                    local f = cachedR1[i]
                    local x = -(totalW1 / 2) + (w1 / 2) + (i - 1) * (w1 + gap)
                    f:ClearAllPoints(); f:SetPoint("CENTER", eViewer, "CENTER", x, 0)
                    f:SetSize(w1, h1)
                    local iconTex = f.Icon and (f.Icon.Icon or f.Icon); if iconTex then mod.ApplyTexCoord(iconTex, w1, h1) end
                    
                    SuppressDebuffBorder(f); self:ApplyText(f, "Essential", 1); self:ApplySwipeSettings(f)
                end

                if not _G.WishFlex_CooldownRow2_Anchor then _G.WishFlex_CooldownRow2_Anchor = CreateFrame("Frame", "WishFlex_CooldownRow2_Anchor", E.UIParent) end
                WeldToMover(_G.WishFlex_CooldownRow2_Anchor)
                local w2, h2, gap2 = cfgE.row2Width, cfgE.row2Height, cfgE.row2IconGap or 2
                local totalW2 = (r2c * w2) + math.max(0, (r2c - 1) * gap2)
                _G.WishFlex_CooldownRow2_Anchor:SetSize(math.max(w2, totalW2), h2); if _G.WishFlex_CooldownRow2_Anchor.mover then _G.WishFlex_CooldownRow2_Anchor.mover:SetSize(math.max(w2, totalW2), h2) end
                
                for i = 1, r2c do
                    local f = cachedR2[i]
                    f:ClearAllPoints()
                    local x = -(totalW2 / 2) + (w2 / 2) + (i - 1) * (w2 + gap2)
                    f:SetPoint("CENTER", _G.WishFlex_CooldownRow2_Anchor, "CENTER", x, 0)
                    f:SetSize(w2, h2)
                    local iconTex = f.Icon and (f.Icon.Icon or f.Icon); if iconTex then mod.ApplyTexCoord(iconTex, w2, h2) end
                    
                    if f.isHijackedByEssential then
                        local cdSize, cdColor, cdX, cdY = cfgE.row2CdFontSize or 18, cfgE.row2CdFontColor or DEFAULT_CD_COLOR, cfgE.row2CdXOffset or 0, cfgE.row2CdYOffset or 0
                        local fontPath = LSM:Fetch('font', db.countFont or "Expressway"); local outline = db.countFontOutline or "OUTLINE"

                        local function FormatHijackCDText(t)
                            if not t or type(t) ~= "table" or not t.SetFont then return end
                            t._hijackFontPath, t._hijackSize, t._hijackOutline, t._hijackParent, t._hijackX, t._hijackY, t._hijackColor = fontPath, cdSize, outline, f, cdX, cdY, cdColor
                            t._isHijackStyling = true
                            if t.FontTemplate then t:FontTemplate(fontPath, cdSize, outline) else t:SetFont(fontPath, cdSize, outline) end
                            t:ClearAllPoints(); t:SetPoint("CENTER", f, "CENTER", cdX, cdY); t:SetTextColor(cdColor.r, cdColor.g, cdColor.b)
                            t._isHijackStyling = false
                            if not t._hijackHooked then
                                t._hijackHooked = true
                                hooksecurefunc(t, "SetPoint", HijackSetPoint)
                                hooksecurefunc(t, "SetTextColor", HijackSetTextColor)
                                hooksecurefunc(t, "SetFont", HijackSetFont)
                            end
                        end

                        if f.Cooldown then
                            if f.Cooldown.timer and f.Cooldown.timer.text then FormatHijackCDText(f.Cooldown.timer.text) end
                            for k = 1, select("#", f.Cooldown:GetRegions()) do 
                                local region = select(k, f.Cooldown:GetRegions())
                                if region and region.IsObjectType and region:IsObjectType("FontString") then FormatHijackCDText(region) end 
                            end
                        end
                        
                        if f.Count then
                            f.Count._hijackFontPath, f.Count._hijackSize, f.Count._hijackOutline, f.Count._hijackParent, f.Count._hijackX, f.Count._hijackY = fontPath, cdSize, outline, f, cdX, cdY
                            f.Count._isHijackStyling = true
                            if f.Count.FontTemplate then f.Count:FontTemplate(fontPath, cdSize, outline) else f.Count:SetFont(fontPath, cdSize, outline) end
                            f.Count:ClearAllPoints(); f.Count:SetPoint("CENTER", f, "CENTER", cdX, cdY)
                            f.Count._isHijackStyling = false
                            if not f.Count._hijackHooked then
                                f.Count._hijackHooked = true
                                hooksecurefunc(f.Count, "SetPoint", HijackSetPoint)
                                hooksecurefunc(f.Count, "SetFont", HijackSetFont)
                            end
                        end
                        self:ApplySwipeSettings(f)
                    else
                        SuppressDebuffBorder(f); self:ApplyText(f, "Essential", 2); self:ApplySwipeSettings(f)
                    end
                end
            end
        end
    end
end

local isLayingOut = false
function mod:TriggerLayout()
    if isLayingOut then return end
    isLayingOut = true
    self:UpdateAllLayouts()
    self:ForceBuffsLayout()
    isLayingOut = false
end

function mod:Initialize()
    InjectOptions(); if not E.db.WishFlex.modules.cooldownCustom then return end
    
    if not _G.WishFlex_CooldownRow2_Anchor then _G.WishFlex_CooldownRow2_Anchor = CreateFrame("Frame", "WishFlex_CooldownRow2_Anchor", E.UIParent) end
    SafeMover(_G.UtilityCooldownViewer, "WishFlexUtilityMover", "WishFlex: 效能技能", {"CENTER", E.UIParent, "CENTER", 0, -100})
    SafeMover(_G.EssentialCooldownViewer, "WishFlexEssentialMover", "WishFlex: 重要技能(第一行)", {"CENTER", E.UIParent, "CENTER", 0, 50})
    SafeMover(_G.WishFlex_CooldownRow2_Anchor, "WishFlexEssentialRow2Mover", "WishFlex: 重要技能(第二行)", {"CENTER", E.UIParent, "CENTER", 0, -50})
    SafeMover(_G.BuffIconCooldownViewer, "WishFlexBuffIconMover", "WishFlex: 增益图标", {"CENTER", E.UIParent, "CENTER", 0, 150})
    SafeMover(_G.BuffBarCooldownViewer, "WishFlexBuffBarMover", "WishFlex: 增益条", {"CENTER", E.UIParent, "CENTER", 0, 100})

    local isHookingGlow = false
    if LCG then
        hooksecurefunc(LCG, "PixelGlow_Start", function(frame, color, lines, frequency, length, thickness, xOffset, yOffset, drawLayer, key)
            if isHookingGlow or not frame or key == "WishEssentialGlow" then return end
            if GetKeyFromFrame(frame) == "Essential" then
                isHookingGlow = true; LCG.PixelGlow_Stop(frame, key); isHookingGlow = false
                local cfg = E.db.WishFlex.cdManager.Essential
                if cfg and cfg.glowEnable then
                    local c = cfg.glowColor or {r=1, g=1, b=1, a=1}
                    LCG.PixelGlow_Start(frame, {c.r, c.g, c.b, c.a}, cfg.glowLines or 8, cfg.glowFreq or 0.25, cfg.glowLength or 10, cfg.glowThick or 2, xOffset, yOffset, drawLayer, "WishEssentialGlow")
                end
            end
        end)
        hooksecurefunc(LCG, "PixelGlow_Stop", function(frame, key)
            if isHookingGlow or key == "WishEssentialGlow" or not frame then return end
            if GetKeyFromFrame(frame) == "Essential" then
                isHookingGlow = true; LCG.PixelGlow_Stop(frame, "WishEssentialGlow"); isHookingGlow = false
            end
        end)
    end

    local function EventTrigger() mod:TriggerLayout() end

    local viewers = {"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer"}
    for _, name in ipairs(viewers) do
        local v = _G[name]
        if v then
            if v.Layout then hooksecurefunc(v, "Layout", EventTrigger) end
            if v.UpdateLayout then hooksecurefunc(v, "UpdateLayout", EventTrigger) end
            if v.itemFramePool and type(v.itemFramePool.Acquire) == "function" then 
                hooksecurefunc(v.itemFramePool, "Acquire", EventTrigger) 
            end
        end
    end

    -- =========================================================================
    -- 【核心优化引擎】：同帧瞬发防抖拦截 (Same-Frame Debounce)
    -- =========================================================================
    -- 原理：脱战时不占用任何 CPU，但一旦玩家 Buff 变动，在同一渲染帧内立刻接管。
    -- 无论一瞬间触发多少次 UNIT_AURA，依靠帧锁保证只运算1次，根除 FPS 掉帧。
    local frameLimitPending = false
    local frameLimiter = CreateFrame("Frame")
    frameLimiter:SetScript("OnUpdate", function()
        frameLimitPending = false 
    end)

    function mod:UNIT_AURA(event, unit)
        if unit == "player" then
            if not frameLimitPending then
                frameLimitPending = true
                mod:TriggerLayout() -- 同帧立即强杀暴雪的默认排版，彻底消灭视觉延迟
            end
        end
    end
    self:RegisterEvent("UNIT_AURA")
    -- =========================================================================

    -- 战斗状态智能管理：进战开启狂暴兜底镇压（处理饰品CD等无光环更新的组件），脱战 0 占用休眠
    function mod:PLAYER_REGEN_DISABLED()
        if self.combatLayoutTicker then self.combatLayoutTicker:Cancel() end
        self.combatLayoutTicker = C_Timer.NewTicker(0.05, function() mod:TriggerLayout() end)
    end

    function mod:PLAYER_REGEN_ENABLED()
        if self.combatLayoutTicker then
            self.combatLayoutTicker:Cancel()
            self.combatLayoutTicker = nil
        end
        mod:TriggerLayout()
    end

    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    if InCombatLockdown() then self:PLAYER_REGEN_DISABLED() end

    self:TriggerLayout()
end