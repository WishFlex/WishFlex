local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')
local LSM = E.Libs.LSM
local WUI = E:GetModule('WishFlex')
local mod = WUI:NewModule('CooldownCustom', 'AceHook-3.0', 'AceEvent-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

mod.itemSpellMap = {} 
mod.buffDurationCache = {} 
mod.activeBuffs = {} 

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.cooldownCustom = true
P["WishFlex"].cdManager = {
    Utility = { 
        width = 45, height = 30, iconGap = 2, growth = "CENTER", 
        countFontSize = 14, countXOffset = 0, countYOffset = 0,
        glowEnable = true, glowColor = {r = 1, g = 0.8, b = 0, a = 1}, glowLines = 8, glowFreq = 0.25, glowLength = 10, glowThick = 2
    },
    BuffBar = { width = 120, height = 30, countFontSize = 14, countXOffset = 0, countYOffset = 0, iconGap = 2, growth = "DOWN", glowEnable = false, glowColor = {r = 1, g = 0.8, b = 0, a = 1}, glowLines = 8, glowFreq = 0.25, glowThick = 2 },
    BuffIcon = { width = 45, height = 45, countFontSize = 14, countXOffset = 0, countYOffset = 0, iconGap = 2, growth = "CENTER", glowEnable = false, glowColor = {r = 1, g = 0.8, b = 0, a = 1}, glowLines = 8, glowFreq = 0.25, glowThick = 2 }, 
    Essential = { 
        enableCustomLayout = true, maxPerRow = 7, iconGap = 2,
        row1Width = 45, row1Height = 45, row1CountFontSize = 14, row1CountXOffset = 0, row1CountYOffset = 0,
        row2Width = 40, row2Height = 40, row2IconGap = 2, row2CountFontSize = 14, row2CountXOffset = 0, row2CountYOffset = 0,
        glowEnable = true, glowColor = {r = 1, g = 0.8, b = 0, a = 1}, glowLines = 8, glowFreq = 0.25, glowLength = 10, glowThick = 2
    },
    countFont = "Expressway", countFontOutline = "OUTLINE", countFontColor = { r = 1, g = 1, b = 1 },
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

local function HideDebuffBorder(icon)
    if icon.DebuffBorder then icon.DebuffBorder:SetAlpha(0); icon.DebuffBorder:Hide() end
    if icon.Border then icon.Border:SetAlpha(0); icon.Border:Hide() end
    if icon.IconBorder then icon.IconBorder:SetAlpha(0); icon.IconBorder:Hide() end
end

local ScannerTooltip = CreateFrame("GameTooltip", "WishFlex_BuffScanner", UIParent, "GameTooltipTemplate")
function mod:CacheAllSpells()
    if InCombatLockdown() then return end
    wipe(self.buffDurationCache)
    wipe(self.itemSpellMap)
    local patterns = { "持续%s*(%d+)%s*秒", "lasts%s*(%d+)%s*sec", "(%d+)%s*秒", "(%d+)%s*sec" }
    
    local function ScanTooltip(id, isItem)
        if self.buffDurationCache[id] then return end
        if isItem then
            local _, sID = C_Item.GetItemSpell(id)
            if sID then self.itemSpellMap[sID] = id end
        end
        ScannerTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        ScannerTooltip:ClearLines()
        local ok
        if isItem then ok = pcall(function() ScannerTooltip:SetItemByID(id) end)
        else ok = pcall(function() ScannerTooltip:SetSpellByID(id) end) end
        
        if ok then
            for i = 1, 10 do
                local line = _G["WishFlex_BuffScannerTextLeft" .. i]
                local okText, text = pcall(function() return line and line:GetText() end)
                if okText and text and type(text) == "string" and not issecretvalue(text) then
                    for _, p in ipairs(patterns) do
                        local val = text:match(p)
                        if val then self.buffDurationCache[id] = tonumber(val); return end
                    end
                end
            end
        end
    end

    for i = 1, 19 do
        local itemID = GetInventoryItemID("player", i)
        if itemID then ScanTooltip(itemID, true) end
    end
    for i = 1, 120 do
        local actionType, id = GetActionInfo(i)
        if actionType == "spell" and id then ScanTooltip(id, false)
        elseif actionType == "item" and id then ScanTooltip(id, true) end
    end
end

local function GetEssentialGroup(dbKey, tabName, order)
    return {
        order = order, type = "group", name = tabName,
        get = function(i) return E.db.WishFlex.cdManager[dbKey][i[#i]] end,
        set = function(i, v) E.db.WishFlex.cdManager[dbKey][i[#i]] = v; mod:ScheduleLayout() end,
        args = {
            layoutStatus = { order = 1, type = "group", name = "第一行", guiInline = true, args = { enableCustomLayout = { order = 1, type = "toggle", name = "启用双行" }, maxPerRow = { order = 2, type = "range", name = "最大数", min = 1, max = 20, step = 1 }, iconGap = { order = 3, type = "range", name = "间距", min = 0, max = 20, step = 1 } } },
            row1Size = { order = 2, type = "group", name = "第一行设置", guiInline = true, args = { row1Width = { order=1, type="range", name="宽度", min=10, max=100, step=1 }, row1Height = { order=2, type="range", name="高度", min=10, max=100, step=1 }, row1CountFontSize = { order=3, type="range", name="文本大小", min=8, max=40, step=1 }, row1CountXOffset = { order=4, type="range", name="文本X偏移", min=-50, max=50, step=1 }, row1CountYOffset = { order=5, type="range", name="文本Y偏移", min=-50, max=50, step=1 } } },
            row2Size = { order = 3, type = "group", name = "第二行设置", guiInline = true, args = { row2Width = { order=1, type="range", name="宽度", min=10, max=100, step=1 }, row2Height = { order=2, type="range", name="高度", min=10, max=100, step=1 }, row2IconGap = { order=3, type="range", name="间距", min=0, max=20, step=1 }, row2CountFontSize = { order=4, type="range", name="文本大小", min=8, max=40, step=1 }, row2CountXOffset = { order=5, type="range", name="文本X偏移", min=-50, max=50, step=1 }, row2CountYOffset = { order=6, type="range", name="文本Y偏移", min=-50, max=50, step=1 } } },
            glowGrp1 = { order = 4, type = "group", name = "高亮图标", guiInline = true, args = { 
                glowEnable = { order = 1, type = "toggle", name = "像素发光" }, 
                glowColor = { order = 2, type = "color", name = "线条颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.cdManager.Essential.glowColor or {r=1,g=0.8,b=0,a=1} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.cdManager.Essential.glowColor = {r=r,g=g,b=b,a=a}; end }, 
                glowLines = { order = 3, type = "range", name = "线条数", min = 1, max = 20, step = 1 }, 
                glowFreq = { order = 4, type = "range", name = "速度", min = 0.05, max = 2, step = 0.05 },
                glowThick = { order = 5, type = "range", name = "线条粗细", min = 1, max = 10, step = 1 } 
            } }
        }
    }
end

local function GetUtilityGroup(dbKey, tabName, order)
    return {
        order = order, type = "group", name = tabName, 
        get = function(i) return E.db.WishFlex.cdManager[dbKey][i[#i]] end,
        set = function(i, v) E.db.WishFlex.cdManager[dbKey][i[#i]] = v; mod:ScheduleLayout() end,
        args = {
            layout = { order = 1, type = "group", name = "排版", guiInline = true, args = { growth = { order = 1, type = "select", name = "增长方向", values = { ["LEFT"] = "向左", ["CENTER"] = "居中", ["RIGHT"] = "向右" } }, iconGap = { order = 2, type = "range", name = "间距", min = 0, max = 20, step = 1 } } },
            size = { order = 2, type = "group", name = "图标大小", guiInline = true, args = { width = {order=1,type="range",name="宽度",min=10,max=400,step=1}, height = {order=2,type="range",name="高度",min=10,max=100,step=1} } },
            text = { order = 3, type = "group", name = "文本设置", guiInline = true, args = { countFontSize = {order=1,type="range",name="文本大小",min=8,max=40,step=1}, countXOffset = {order=2,type="range",name="X偏移",min=-50,max=50,step=1}, countYOffset = {order=3,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            glow1 = { order = 4, type = "group", name = "触发特效", guiInline = true, args = { 
                glowEnable = { order = 1, type = "toggle", name = "启用" }, 
                glowColor = { order = 2, type = "color", name = "颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.cdManager[dbKey].glowColor or {r=1,g=0.8,b=0,a=1} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.cdManager[dbKey].glowColor = {r=r,g=g,b=b,a=a}; end }, 
                glowLines = { order = 3, type = "range", name = "线条", min = 1, max = 20, step = 1 }, 
                glowFreq = { order = 4, type = "range", name = "速度", min = 0.05, max = 2, step = 0.05 },
                glowThick = { order = 5, type = "range", name = "线条粗细", min = 1, max = 10, step = 1 } 
            } }
        }
    }
end

local function GetCDSubGroup(dbKey, tabName, order, isVertical)
    local growthValues = isVertical and { ["UP"] = "向上", ["DOWN"] = "向下" } or { ["LEFT"] = "向左", ["CENTER"] = "居中", ["RIGHT"] = "向右" }
    return {
        order = order, type = "group", name = tabName, 
        get = function(i) return E.db.WishFlex.cdManager[dbKey][i[#i]] end,
        set = function(i, v) E.db.WishFlex.cdManager[dbKey][i[#i]] = v; mod:ScheduleLayout() end,
        args = {
            layout = { order = 1, type = "group", name = "排版", guiInline = true, args = { growth = { order = 1, type = "select", name = "增长方向", values = growthValues }, iconGap = { order = 2, type = "range", name = "间距", min = 0, max = 20, step = 1 } } },
            sizeSet = { order = 2, type = "group", name = "图标宽高", guiInline = true, args = { width = {order=1,type="range",name="宽度",min=10,max=400,step=1}, height = {order=2,type="range",name="高度",min=10,max=100,step=1} } },
            countSet = { order = 3, type = "group", name = "文本设置", guiInline = true, args = { countFontSize = {order=1,type="range",name="文本大小",min=8,max=40,step=1}, countXOffset = {order=2,type="range",name="X偏移",min=-50,max=50,step=1}, countYOffset = {order=3,type="range",name="Y偏移",min=-50,max=50,step=1} } },
            glowSet = { order = 4, type = "group", name = "发光设置", guiInline = true, args = {
                glowEnable = { order = 1, type = "toggle", name = "启用" }, 
                glowColor = { order = 2, type = "color", name = "颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.cdManager[dbKey].glowColor or {r=1,g=0.8,b=0,a=1} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.cdManager[dbKey].glowColor = {r=r,g=g,b=b,a=a}; end }, 
                glowLines = { order = 3, type = "range", name = "线条", min = 1, max = 20, step = 1 }, 
                glowFreq = { order = 4, type = "range", name = "速度", min = 0.05, max = 2, step = 0.05 },
                glowThick = { order = 5, type = "range", name = "线条粗细", min = 1, max = 10, step = 1 } 
            } }
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
            countFont = { order = 2, type = "select", dialogControl = 'LSM30_Font', name = "全局字体", values = LSM:HashTable("font"), get = function() return E.db.WishFlex.cdManager.countFont end, set = function(_, v) E.db.WishFlex.cdManager.countFont = v; mod:ScheduleLayout() end }, 
            countFontOutline = { order = 3, type = "select", name = "字体描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" }, get = function() return E.db.WishFlex.cdManager.countFontOutline end, set = function(_, v) E.db.WishFlex.cdManager.countFontOutline = v; mod:ScheduleLayout() end }, 
            countFontColor = { order = 4, type = "color", name = "文本颜色", get = function() local t = E.db.WishFlex.cdManager.countFontColor or {r=1,g=1,b=1} return t.r, t.g, t.b end, set = function(_, r, g, b) E.db.WishFlex.cdManager.countFontColor = {r=r,g=g,b=b}; mod:ScheduleLayout() end },
        } 
    }
    args.essential = GetEssentialGroup("Essential", "重要技能", 2)
    args.utility = GetUtilityGroup("Utility", "效能技能", 4)
    args.bufficon = GetCDSubGroup("BuffIcon", "增益图标", 5, false) 
    args.buffbar = GetCDSubGroup("BuffBar", "增益条", 6, true) 
end

function mod:ApplyText(frame, category, rowIndex)
    local db = E.db.WishFlex.cdManager
    local cfg = db[category]
    if not cfg then return end

    local fontSize, xOff, yOff
    if category == "Essential" then
        if rowIndex == 2 then fontSize = cfg.row2CountFontSize or 14; xOff = cfg.row2CountXOffset or 0; yOff = cfg.row2CountYOffset or 0
        else fontSize = cfg.row1CountFontSize or 14; xOff = cfg.row1CountXOffset or 0; yOff = cfg.row1CountYOffset or 0 end
    else
        fontSize = cfg.countFontSize or 14; xOff = cfg.countXOffset or 0; yOff = cfg.countYOffset or 0
    end
    
    local fontColor = db.countFontColor
    local fontPath = LSM:Fetch('font', db.countFont or "Expressway")
    local outline = db.countFontOutline or "OUTLINE"

    local durationText = frame.Cooldown and frame.Cooldown.timer and frame.Cooldown.timer.text
    local stackText = (frame.Applications and frame.Applications.Applications) or (frame.ChargeCount and frame.ChargeCount.Current) or frame.Count

    local function FormatText(t, isStack)
        if not t or type(t) ~= "table" or not t.SetFont then return end
        local cFont, cSize, cOut = t:GetFont()
        if cFont ~= fontPath or cSize ~= fontSize or cOut ~= outline then t:FontTemplate(fontPath, fontSize, outline) end
        if fontColor then t:SetTextColor(fontColor.r, fontColor.g, fontColor.b) else t:SetTextColor(1, 1, 1) end
        t:ClearAllPoints()
        if isStack and durationText then t:SetPoint("BOTTOMRIGHT", frame.Icon or frame, "BOTTOMRIGHT", xOff, yOff)
        else t:SetPoint("CENTER", frame.Icon or frame, "CENTER", xOff, yOff) end
        t:SetDrawLayer("OVERLAY", 7)
    end

    if category ~= "BuffIcon" and category ~= "BuffBar" then
        FormatText(durationText, false)
        if frame.text and frame.text ~= durationText and frame.text ~= stackText then FormatText(frame.text, false) end
        if frame.value and frame.value ~= durationText and frame.value ~= stackText then FormatText(frame.value, false) end
    end
    FormatText(stackText, true)
end

local function WeldToMover(frame)
    if frame and frame.mover then
        if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", frame.mover, "CENTER")
    end
end

local function ForceBuffsLayout()
    local db = E.db.WishFlex.cdManager
    local function LayoutBuffs(viewerName, key, isVertical)
        local container = _G[viewerName]
        if not container or not container:IsShown() then return end
        
        WeldToMover(container)
        
        local icons = {}
        if container.itemFramePool then
            for f in container.itemFramePool:EnumerateActive() do
                if f:IsShown() and f:GetWidth() > 10 then table.insert(icons, f); HideDebuffBorder(f); mod:ApplyText(f, key) end
            end
        end
        if #icons == 0 then return end
        table.sort(icons, function(a, b) return (a:GetLeft() or 0) < (b:GetLeft() or 0) end)
        
        local cfg = db[key]
        local w, h = cfg.width or 45, cfg.height or 45
        local gap = cfg.iconGap or 2
        local growth = cfg.growth or (isVertical and "DOWN" or "CENTER")
        
        if isVertical then
            local totalHeight = (#icons * h) + math.max(0, (#icons - 1) * gap)
            container:SetSize(w, math.max(h, totalHeight))
            if container.mover then container.mover:SetSize(w, math.max(h, totalHeight)) end
            
            for i, f in ipairs(icons) do
                f:ClearAllPoints()
                local y = 0
                if growth == "DOWN" then 
                    y = -((i - 1) * (h + gap))
                    f:SetPoint("TOP", container, "TOP", 0, y)
                elseif growth == "UP" then 
                    y = (i - 1) * (h + gap)
                    f:SetPoint("BOTTOM", container, "BOTTOM", 0, y)
                else
                    y = -((i - 1) * (h + gap))
                    f:SetPoint("TOP", container, "TOP", 0, y)
                end
                
                f:SetSize(w, h)
                if f.Icon then
                    local iconObj = f.Icon.Icon or f.Icon
                    if not f.Bar then f.Icon:SetSize(w, h); mod.ApplyTexCoord(iconObj, w, h)
                    else 
                        f.Icon:SetSize(h, h); f.Bar:SetSize(w - h - 2, h)
                        f.Bar:ClearAllPoints(); f.Bar:SetPoint("LEFT", f.Icon, "RIGHT", 2, 0)
                        if iconObj then mod.ApplyTexCoord(iconObj, h, h) end 
                    end
                end
            end
        else
            local totalWidth = (#icons * w) + math.max(0, (#icons - 1) * gap)
            container:SetSize(math.max(w, totalWidth), h)
            if container.mover then container.mover:SetSize(math.max(w, totalWidth), h) end
            
            for i, f in ipairs(icons) do
                f:ClearAllPoints()
                local x = 0
                if growth == "CENTER" then 
                    x = -(totalWidth / 2) + (w / 2) + (i - 1) * (w + gap)
                    f:SetPoint("CENTER", container, "CENTER", x, 0)
                elseif growth == "LEFT" then 
                    x = -(i - 1) * (w + gap); f:SetPoint("RIGHT", container, "RIGHT", x, 0)
                elseif growth == "RIGHT" then 
                    x = (i - 1) * (w + gap); f:SetPoint("LEFT", container, "LEFT", x, 0) 
                end
                
                f:SetSize(w, h)
                if f.Icon then
                    local iconObj = f.Icon.Icon or f.Icon
                    if not f.Bar then f.Icon:SetSize(w, h); mod.ApplyTexCoord(iconObj, w, h)
                    else 
                        f.Icon:SetSize(h, h); f.Bar:SetSize(w - h - 2, h)
                        f.Bar:ClearAllPoints(); f.Bar:SetPoint("LEFT", f.Icon, "RIGHT", 2, 0)
                        if iconObj then mod.ApplyTexCoord(iconObj, h, h) end 
                    end
                end
            end
        end
    end
    LayoutBuffs("BuffIconCooldownViewer", "BuffIcon", false)
    LayoutBuffs("BuffBarCooldownViewer", "BuffBar", true)
end

local isUpdatingLayout = false
function mod:UpdateAllLayouts()
    if isUpdatingLayout then return end
    isUpdatingLayout = true

    local db = E.db.WishFlex.cdManager
    mod.activeTrackedFrames = {}

    local uViewer = _G.UtilityCooldownViewer
    if uViewer and uViewer.itemFramePool then
        WeldToMover(uViewer)
        
        local cfg = db.Utility
        local frames = {}
        for f in uViewer.itemFramePool:EnumerateActive() do if f:IsShown() then table.insert(frames, f) end end
        table.sort(frames, function(a, b) return (a.layoutIndex or 999) < (b.layoutIndex or 999) end)
        
        local w, h = cfg.width or 45, cfg.height or 30
        local gap = cfg.iconGap or 2
        local growth = cfg.growth or "CENTER"
        
        local totalW = (#frames * w) + math.max(0, (#frames - 1) * gap)
        uViewer:SetSize(math.max(w, totalW), h)
        if uViewer.mover then uViewer.mover:SetSize(math.max(w, totalW), h) end

        for i, f in ipairs(frames) do
            f:ClearAllPoints()
            local x = 0
            if growth == "CENTER" then 
                x = -(totalW / 2) + (w / 2) + (i - 1) * (w + gap)
                f:SetPoint("CENTER", uViewer, "CENTER", x, 0)
            elseif growth == "LEFT" then 
                x = -(i - 1) * (w + gap); f:SetPoint("RIGHT", uViewer, "RIGHT", x, 0)
            elseif growth == "RIGHT" then 
                x = (i - 1) * (w + gap); f:SetPoint("LEFT", uViewer, "LEFT", x, 0) 
            end

            f:SetSize(w, h)
            if f.Icon then local iconObj = f.Icon.Icon or f.Icon; f.Icon:SetSize(w, h); mod.ApplyTexCoord(iconObj, w, h) end
            
            mod:ApplyText(f, "Utility")
            table.insert(mod.activeTrackedFrames, f)
        end
    end

    local eViewer = _G.EssentialCooldownViewer
    if eViewer and eViewer.itemFramePool then
        WeldToMover(eViewer)
        
        local frames = {}
        for f in eViewer.itemFramePool:EnumerateActive() do if f:IsShown() then table.insert(frames, f) end end
        table.sort(frames, function(a, b) return (a.layoutIndex or 999) < (b.layoutIndex or 999) end)

        local cfgE = db.Essential
        if cfgE.enableCustomLayout then
            local r1, r2 = {}, {}
            for i, f in ipairs(frames) do f:ClearAllPoints(); if i <= cfgE.maxPerRow then table.insert(r1, f) else table.insert(r2, f) end end

            local w1, h1, gap = cfgE.row1Width, cfgE.row1Height, cfgE.iconGap
            local totalW1 = (#r1 * w1) + math.max(0, (#r1 - 1) * gap)
            eViewer:SetSize(math.max(w1, totalW1), h1)
            if eViewer.mover then eViewer.mover:SetSize(math.max(w1, totalW1), h1) end
            
            for i, f in ipairs(r1) do
                local startX1 = -(totalW1 / 2) + (w1 / 2)
                f:SetPoint("CENTER", eViewer, "CENTER", startX1 + (i - 1) * (w1 + gap), 0)
                f:SetSize(w1, h1)
                local iconTex = f.Icon and (f.Icon.Icon or f.Icon)
                if iconTex then mod.ApplyTexCoord(iconTex, w1, h1) end
                mod:ApplyText(f, "Essential", 1)
                table.insert(mod.activeTrackedFrames, f)
            end

            if not _G.WishFlex_CooldownRow2_Anchor then _G.WishFlex_CooldownRow2_Anchor = CreateFrame("Frame", "WishFlex_CooldownRow2_Anchor", E.UIParent) end
            WeldToMover(_G.WishFlex_CooldownRow2_Anchor)
            
            local w2, h2 = cfgE.row2Width, cfgE.row2Height
            local gap2 = cfgE.row2IconGap or 2
            local totalW2 = (#r2 * w2) + math.max(0, (#r2 - 1) * gap2)
            
            _G.WishFlex_CooldownRow2_Anchor:SetSize(math.max(w2, totalW2), h2)
            if _G.WishFlex_CooldownRow2_Anchor.mover then _G.WishFlex_CooldownRow2_Anchor.mover:SetSize(math.max(w2, totalW2), h2) end
            
            for i, f in ipairs(r2) do
                local startX2 = -(totalW2 / 2) + (w2 / 2)
                f:SetPoint("CENTER", _G.WishFlex_CooldownRow2_Anchor, "CENTER", startX2 + (i - 1) * (w2 + gap2), 0)
                f:SetSize(w2, h2)
                local iconTex = f.Icon and (f.Icon.Icon or f.Icon)
                if iconTex then mod.ApplyTexCoord(iconTex, w2, h2) end
                mod:ApplyText(f, "Essential", 2)
                table.insert(mod.activeTrackedFrames, f)
            end
        end
    end

    isUpdatingLayout = false
end

function mod:ScheduleLayout()
    if self.layoutTimer then return end
    self.layoutTimer = E:Delay(0.05, function()
        self.layoutTimer = nil
        self:UpdateAllLayouts()
    end)
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, unit, _, spellID)
    if unit ~= "player" then return end
    local itemID = self.itemSpellMap[spellID]
    local id = itemID or spellID
    local duration = self.buffDurationCache[id]
    if duration and duration > 0 then 
        self.activeBuffs[id] = { endTime = GetTime() + duration, duration = duration }
    end
end

local function IsEqual(a, b) return a == b end

local function CheckAuraValid(id, isItem)
    local sName, sID = nil, id
    if isItem then
        local _, spID = C_Item.GetItemSpell(id)
        if spID then 
            sID = spID
            local sInfo = C_Spell.GetSpellInfo(sID)
            if sInfo then sName = sInfo.name end
        end
    else
        local sInfo = C_Spell.GetSpellInfo(id)
        if sInfo then sName = sInfo.name end
    end
    
    if not sName and not sID then return true end 
    
    local hasSecret = false
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        
        if sName and aura.name then
            local ok, match = pcall(IsEqual, aura.name, sName)
            if ok and match then return true end
            if not ok then hasSecret = true end
        end
        
        if sID and aura.spellId then
            local ok, match = pcall(IsEqual, aura.spellId, sID)
            if ok and match then return true end
            if not ok then hasSecret = true end
        end
    end
    return hasSecret
end

local function SafeMover(frame, moverName, title, defaultPoint)
    if not frame then return end
    if not frame:GetNumPoints() or frame:GetNumPoints() == 0 then frame:SetPoint(unpack(defaultPoint)) end
    if not frame.mover then E:CreateMover(frame, moverName, title, nil, nil, nil, "ALL,WishFlex") end
end

function mod:Initialize()
    InjectOptions(); if not E.db.WishFlex.modules.cooldownCustom then return end
    
    self:CacheAllSpells()
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CacheAllSpells")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "CacheAllSpells")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "CacheAllSpells")

    if not _G.WishFlex_CooldownRow2_Anchor then _G.WishFlex_CooldownRow2_Anchor = CreateFrame("Frame", "WishFlex_CooldownRow2_Anchor", E.UIParent) end
    SafeMover(_G.UtilityCooldownViewer, "WishFlexUtilityMover", "WishFlex: 效能技能", {"CENTER", E.UIParent, "CENTER", 0, -100})
    SafeMover(_G.EssentialCooldownViewer, "WishFlexEssentialMover", "WishFlex: 重要技能(第一行)", {"CENTER", E.UIParent, "CENTER", 0, 50})
    SafeMover(_G.WishFlex_CooldownRow2_Anchor, "WishFlexEssentialRow2Mover", "WishFlex: 重要技能(第二行)", {"CENTER", E.UIParent, "CENTER", 0, -50})
    SafeMover(_G.BuffIconCooldownViewer, "WishFlexBuffIconMover", "WishFlex: 增益图标", {"CENTER", E.UIParent, "CENTER", 0, 150})
    SafeMover(_G.BuffBarCooldownViewer, "WishFlexBuffBarMover", "WishFlex: 增益条", {"CENTER", E.UIParent, "CENTER", 0, 100})

    local isHookingGlow = false
    if LCG then
        hooksecurefunc(LCG, "PixelGlow_Start", function(frame, color, lines, frequency, length, thickness, xOffset, yOffset, drawLayer, key)
            if isHookingGlow then return end; if not frame then return end; if key == "WishEssentialGlow" or key == "WishUtilGlow" then return end
            local cat = GetKeyFromFrame(frame)
            if cat == "Essential" or cat == "Utility" then
                isHookingGlow = true; LCG.PixelGlow_Stop(frame, key); isHookingGlow = false
                
                if cat == "Essential" then
                    local cfg = E.db.WishFlex.cdManager.Essential
                    if cfg and cfg.glowEnable then
                        if not frame._wishEssentialGlow then
                            local c = cfg.glowColor
                            local gr, gg, gb, ga = 1, 0.8, 0, 1
                            if c then gr, gg, gb, ga = c.r, c.g, c.b, c.a end
                            LCG.PixelGlow_Start(frame, {gr, gg, gb, ga}, cfg.glowLines or 8, cfg.glowFreq or 0.25, cfg.glowLength or 10, cfg.glowThick or 2, xOffset, yOffset, drawLayer, "WishEssentialGlow")
                            frame._wishEssentialGlow = true
                        end
                    end
                end
            end
        end)
        hooksecurefunc(LCG, "PixelGlow_Stop", function(frame, key)
            if isHookingGlow then return end
            if key ~= "WishEssentialGlow" and frame and frame._wishEssentialGlow then
                local cat = GetKeyFromFrame(frame)
                if cat == "Essential" then
                    isHookingGlow = true; LCG.PixelGlow_Stop(frame, "WishEssentialGlow"); frame._wishEssentialGlow = false; isHookingGlow = false
                end
            end
        end)
    end

    local viewers = {"EssentialCooldownViewer", "UtilityCooldownViewer"}
    for _, name in ipairs(viewers) do
        local v = _G[name]
        if v then
            if type(v.Layout) == "function" then hooksecurefunc(v, "Layout", function() mod:UpdateAllLayouts() end) end
            if type(v.UpdateLayout) == "function" then hooksecurefunc(v, "UpdateLayout", function() mod:UpdateAllLayouts() end) end
            v:HookScript("OnShow", function() mod:UpdateAllLayouts() end)
            if v.itemFramePool and type(v.itemFramePool.Acquire) == "function" then
                hooksecurefunc(v.itemFramePool, "Acquire", function() mod:UpdateAllLayouts() end)
            end
        end
    end

    C_Timer.NewTicker(0.05, function() ForceBuffsLayout() end)

    local tickerFrame = CreateFrame("Frame")
    local tickElapsed = 0
    tickerFrame:SetScript("OnUpdate", function(_, delta)
        tickElapsed = tickElapsed + delta
        local interval = InCombatLockdown() and 0.1 or 0.5
        if tickElapsed >= interval then
            tickElapsed = 0
            
            local db = E.db.WishFlex.cdManager
            local t = GetTime()

            for _, frame in ipairs(mod.activeTrackedFrames or {}) do
                local cat = GetKeyFromFrame(frame)
                if cat then
                    local rIdx = (frame.layoutIndex and frame.layoutIndex > (db.Essential.maxPerRow or 7)) and 2 or 1
                    mod:ApplyText(frame, cat, rIdx)
                    local cfg = db[cat]
                    
                    if cat == "Utility" and cfg and cfg.glowEnable then
                        local info = frame.cooldownInfo or (frame.GetCooldownInfo and frame:GetCooldownInfo())
                        local id = info and (info.overrideSpellID or info.spellID)
                        if not id and info and info.itemID then id = info.itemID end
                        if info and info.spellID and mod.itemSpellMap[info.spellID] then id = mod.itemSpellMap[info.spellID] end
                        
                        local isBuffing = false
                        if id and mod.activeBuffs[id] and (mod.activeBuffs[id].endTime > t) then
                            local elapsed = mod.activeBuffs[id].duration - (mod.activeBuffs[id].endTime - t)
                            if elapsed > 1.5 and not CheckAuraValid(id, info.itemID ~= nil) then
                                mod.activeBuffs[id].endTime = 0
                            else
                                isBuffing = true
                            end
                        end
                        
                        if isBuffing then
                            if not frame._wishUtilGlow then
                                local gc = cfg.glowColor
                                local gr, gg, gb, ga = 1, 0.8, 0, 1
                                if gc then gr, gg, gb, ga = gc.r, gc.g, gc.b, gc.a end
                                if LCG then LCG.PixelGlow_Start(frame, {gr, gg, gb, ga}, cfg.glowLines or 8, cfg.glowFreq or 0.25, cfg.glowLength or 10, cfg.glowThick or 2, 0, 0, false, "WishUtilGlow") end
                                frame._wishUtilGlow = true
                            end
                        else
                            if frame._wishUtilGlow then
                                if LCG then LCG.PixelGlow_Stop(frame, "WishUtilGlow") end
                                frame._wishUtilGlow = false
                            end
                        end
                    end
                end
            end
        end
    end)
    
    E:Delay(1, function() mod:UpdateAllLayouts() end)
end