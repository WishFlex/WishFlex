local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs.LSM
local WUI = E:GetModule('WishFlex')
local mod = WUI:NewModule('WishTargetAlert', 'AceEvent-3.0')

-- ==========================================
-- 1. 默认设置与数据库补全
-- ==========================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.targetAlert = true

local function GetDB()
    if not E.private.WishFlex then E.private.WishFlex = {} end
    if type(E.private.WishFlex.targetAlert) ~= "table" then E.private.WishFlex.targetAlert = {} end
    local db = E.private.WishFlex.targetAlert
    local defaults = {
        enable = false, sizeW = 60, sizeH = 60,
        font = "Expressway", fontSize = 24, fontOutline = "OUTLINE",
        fontColor = { r = 1, g = 1, b = 1 }, offsetX = 0, offsetY = 0,
        useGlow = true, glowColor = { r = 1, g = 0, b = 0, a = 1 },
        glowLines = 8, glowFreq = 0.25, glowThick = 2,
        growDirection = "CENTER", iconGap = 4, 
    }
    
    -- 清理废弃的音效相关旧数据
    db.sound = nil
    db.customSound = nil
    
    for k, v in pairs(defaults) do if db[k] == nil then db[k] = v end end
    return db
end

-- ==========================================
-- 2. 视觉防变形裁切
-- ==========================================
local function ApplyTexCoord(texture, width, height)
    if not texture then return end
    local ratio = width / height
    local offset = 0.08
    local left, right, top, bottom = offset, 1-offset, offset, 1-offset
    if ratio > 1 then local vH = (1 - 2*offset) / ratio; top, bottom = 0.5 - (vH/2), 0.5 + (vH/2)
    elseif ratio < 1 then local vW = (1 - 2*offset) * ratio; left, right = 0.5 - (vW/2), 0.5 + (vW/2) end
    texture:SetTexCoord(left, right, top, bottom)
end

-- ==========================================
-- 3. 设置菜单注入
-- ==========================================
function mod:InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.targetAlert = {
        order = 35, type = "group", name = "|cff00c0cc点名提醒|r",
        get = function(info) return GetDB()[info[#info]] end,
        set = function(info, v) GetDB()[info[#info]] = v; if mod.anchor then mod:UpdateLayout() end end,
        args = {
            enable = { order = 1, type = "toggle", name = "|cff00ff00当前角色启用|r", set = function(_, v) GetDB().enable = v; E:StaticPopup_Show("CONFIG_RL") end },
            sizeGroup = { order = 5, type = "group", name = "图标规格", guiInline = true, args = { sizeW = { order = 1, type = "range", name = "宽度", min = 20, max = 300, step = 1 }, sizeH = { order = 2, type = "range", name = "高度", min = 20, max = 300, step = 1 } } },
            
            growGroup = { order = 6, type = "group", name = "图标排列展开 (多目标同时施法时)", guiInline = true, args = { 
                growDirection = { order = 1, type = "select", name = "展开方向", values = { ["LEFT"] = "向左排列", ["CENTER"] = "居中横向", ["RIGHT"] = "向右排列", ["UP"] = "向上堆叠", ["DOWN"] = "向下堆叠" } },
                iconGap = { order = 2, type = "range", name = "图标间距", min = 0, max = 50, step = 1 }
            } },
            
            glowGroup = { order = 8, type = "group", name = "走马灯特效", guiInline = true, args = { 
                useGlow = { order = 1, type = "toggle", name = "启用" }, 
                glowColor = { order = 2, type = "color", hasAlpha = true, name = "边框颜色", get = function() local t = GetDB().glowColor return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) GetDB().glowColor = {r=r,g=g,b=b,a=a}; mod:UpdateLayout() end }, 
                glowLines = { order = 3, type = "range", name = "线条数", min = 1, max = 20, step = 1 }, 
                glowFreq = { order = 4, type = "range", name = "速度", min = 0.05, max = 2, step = 0.05 } 
            } },
            
            fontGroup = { order = 10, type = "group", name = "文字排版", guiInline = true, args = { font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") }, fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 120, step = 1 }, fontOutline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } }, fontColor = { order = 4, type = "color", name = "颜色", get = function() local t = GetDB().fontColor return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().fontColor = {r=r,g=g,b=b}; mod:UpdateLayout() end }, offsetX = { order = 5, type = "range", name = "X偏移", min = -150, max = 150, step = 1 }, offsetY = { order = 6, type = "range", name = "Y偏移", min = -150, max = 150, step = 1 } } },
            preview = { order = 20, type = "execute", name = "测试多目标动画", func = function() if WishFlex_TargetAlertEngine then WishFlex_TargetAlertEngine:Preview() end end }
        }
    }
end

-- ==========================================
-- 4. 锚点与池化框架管理
-- ==========================================
WishFlex_TargetAlertEngine = CreateFrame("Frame")
local Engine = WishFlex_TargetAlertEngine
Engine.pool = {}
Engine.Pending = {}

function mod:UpdateLayout()
    if not self.anchor then return end
    local db = GetDB()
    self.anchor:SetSize(db.sizeW, db.sizeH)
    
    for unit, f in pairs(Engine.pool) do
        f:SetSize(db.sizeW, db.sizeH)
        ApplyTexCoord(f.Icon, db.sizeW, db.sizeH)
        
        local fontPath = LSM:Fetch("font", db.font)
        f.Time:SetFont(fontPath, db.fontSize, db.fontOutline)
        f.Time:SetTextColor(db.fontColor.r, db.fontColor.g, db.fontColor.b)
        f.Time:ClearAllPoints()
        f.Time:SetPoint("CENTER", f, "CENTER", db.offsetX, db.offsetY)
        
        local LCG = E.Libs.CustomGlow
        if LCG then
            LCG.PixelGlow_Stop(f)
            if db.useGlow then 
                local c = db.glowColor
                LCG.PixelGlow_Start(f, {c.r, c.g, c.b, c.a}, db.glowLines, db.glowFreq, 8, db.glowThick, 0, 0, false, "WishTargetAlertGlow_"..unit)
            end
        end
    end
    Engine:UpdatePositions()
end

function mod:CreateAlertAnchor()
    if self.anchor then return end
    self.anchor = CreateFrame("Frame", "WishTargetAlertAnchor", E.UIParent)
    self.anchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, 250)
    self.anchor:SetSize(GetDB().sizeW, GetDB().sizeH)
    E:CreateMover(self.anchor, "WishTargetAlertMover", "WishFlex: 点名提醒阵列", nil, nil, nil, "ALL,WishFlex", nil, "WishFlex,targetalert")
end

local function GetAlertFrame(unit)
    if not mod.anchor then mod:CreateAlertAnchor() end
    if not Engine.pool[unit] then
        local f = CreateFrame("Frame", "WishTargetAlert_"..unit, mod.anchor)
        f:SetFrameStrata("HIGH")
        
        f.Icon = f:CreateTexture(nil, "ARTWORK")
        f.Icon:SetAllPoints()
        f.Time = f:CreateFontString(nil, "OVERLAY", nil, 7)
        
        f.CD = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.CD:SetAllPoints(); f.CD:SetReverse(true); f.CD.skipSkin = true; f.CD:SetHideCountdownNumbers(true)
        
        Engine.pool[unit] = f
        mod:UpdateLayout()
    end
    return Engine.pool[unit]
end

function mod:Initialize()
    if self.Initialized then return end
    self.Initialized = true; self:InjectOptions()
    if GetDB().enable then mod:CreateAlertAnchor() end
end

-- ==========================================
-- 5. 【纯净视觉引擎】全维度展开与防弹机制
-- ==========================================
function Engine:UpdatePositions()
    local active = {}
    for unit, f in pairs(self.pool) do
        if f:IsShown() then table.insert(active, f) end
    end
    if #active == 0 then return end

    table.sort(active, function(a, b) return (a.creationTime or 0) < (b.creationTime or 0) end)

    local db = GetDB()
    local w, h = db.sizeW or 60, db.sizeH or 60
    local gap = db.iconGap or 4
    local dir = db.growDirection or "CENTER"
    local totalW = (#active * w) + (#active - 1) * gap
    
    for i, f in ipairs(active) do
        f:ClearAllPoints()
        local xOffset, yOffset = 0, 0
        if dir == "CENTER" then
            xOffset = -totalW / 2 + w / 2 + (i - 1) * (w + gap)
        elseif dir == "RIGHT" then
            xOffset = (i - 1) * (w + gap)
        elseif dir == "LEFT" then
            xOffset = -(i - 1) * (w + gap)
        elseif dir == "UP" then
            yOffset = (i - 1) * (h + gap)
        elseif dir == "DOWN" then
            yOffset = -(i - 1) * (h + gap)
        end
        f:SetPoint("CENTER", mod.anchor, "CENTER", xOffset, yOffset)
    end
end

local function TriggerUI(unit, icon, durationObj)
    local f = GetAlertFrame(unit)
    f.durationObj = durationObj
    
    if not f:IsShown() then f.creationTime = GetTime() end

    pcall(function()
        if type(durationObj) ~= "number" and f.CD.SetCooldownFromDurationObject then
            f.CD:SetCooldownFromDurationObject(durationObj)
        end
    end)

    f.Icon:SetTexture(icon)
    f:Show()
    
    -- 阵营筛选全权交由C++，不碰判定
    pcall(function()
        if f.SetAlphaFromBoolean then
            if PlayerIsSpellTarget then
                f:SetAlphaFromBoolean(PlayerIsSpellTarget(unit, "player"))
            else
                f:SetAlphaFromBoolean(UnitIsUnit(unit.."target", "player"))
            end
        end
    end)
    
    Engine:UpdatePositions()
end

local function StopUI(unit)
    if unit == "ALL" then
        for u, f in pairs(Engine.pool) do f.durationObj = nil; f:Hide() end
    elseif Engine.pool[unit] then
        Engine.pool[unit].durationObj = nil
        Engine.pool[unit]:Hide()
    end
    Engine:UpdatePositions()
end

local function DoCheck(unit)
    if not GetDB().enable then return end
    
    local isEnemy = true
    pcall(function() if UnitExists(unit) and not UnitCanAttack("player", unit) then isEnemy = false end end)
    if not isEnemy then return end

    local name, _, icon = UnitCastingInfo(unit)
    local isChannel = false
    if not name then name, _, icon = UnitChannelInfo(unit); isChannel = true end
    
    if name then
        local durationObj = isChannel and UnitChannelDuration(unit) or UnitCastingDuration(unit)
        if durationObj then TriggerUI(unit, icon, durationObj) end
    end
end

function Engine:Preview()
    local t = GetTime()
    for i = 1, 3 do
        local unit = "TEST"..i
        local f = GetAlertFrame(unit)
        f.durationObj = nil
        f.previewEndTime = t + 3 + i
        f.creationTime = t + i
        f.CD:SetCooldown(t, 3 + i)
        f.Icon:SetTexture(136012)
        f:SetAlpha(1)
        f:Show()
    end
    Engine:UpdatePositions()
end

-- ==========================================
-- 6. 事件核心
-- ==========================================
Engine:SetScript("OnEvent", function(self, event, unit)
    if not unit or unit == "player" then return end
    
    -- 【终极去重白名单】：无视 target/focus/mouseover。只允许 nameplate 和 boss 通过
    if not (string.find(unit, "^nameplate") or string.find(unit, "^boss")) then return end

    if event:find("_STOP") or event:find("_INTERRUPTED") or event:find("_FAILED") or event:find("_SUCCEEDED") or event == "NAME_PLATE_UNIT_REMOVED" then
        self.Pending[unit] = nil
        StopUI(unit)
    elseif event == "UNIT_TARGET" or event == "NAME_PLATE_UNIT_ADDED" then
        DoCheck(unit)
    else
        self.Pending[unit] = 0.2
    end
end)

Engine:RegisterEvent("UNIT_SPELLCAST_START")
Engine:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
Engine:RegisterEvent("UNIT_TARGET")
Engine:RegisterEvent("NAME_PLATE_UNIT_ADDED") 
Engine:RegisterEvent("NAME_PLATE_UNIT_REMOVED") 
Engine:RegisterEvent("UNIT_SPELLCAST_STOP")
Engine:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
Engine:RegisterEvent("UNIT_SPELLCAST_FAILED")
Engine:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
Engine:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
Engine:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

Engine:SetScript("OnUpdate", function(self, elapsed)
    self.checkTimer = (self.checkTimer or 0) + elapsed

    for u, d in pairs(self.Pending) do
        if d > 0 then self.Pending[u] = d - elapsed
        else self.Pending[u] = nil; DoCheck(u) end
    end

    -- 绝对盲写，直接向屏幕推倒计时
    for unit, f in pairs(Engine.pool) do
        if f:IsShown() then
            if string.find(unit, "TEST") and f.previewEndTime then
                local remain = f.previewEndTime - GetTime()
                if remain > 0 then f.Time:SetFormattedText("%.1f", remain) else StopUI(unit) end
            elseif f.durationObj then
                pcall(function() f.Time:SetFormattedText("%.1f", f.durationObj:GetRemainingDuration()) end)
            end
        end
    end

    if self.checkTimer > 0.1 then
        self.checkTimer = 0
        for unit, f in pairs(Engine.pool) do
            if f:IsShown() and not string.find(unit, "TEST") then
                local name = UnitCastingInfo(unit)
                if not name then name = UnitChannelInfo(unit) end
                if not name then StopUI(unit) end
            end
        end
    end
end)