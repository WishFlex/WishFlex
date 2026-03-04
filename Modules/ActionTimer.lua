local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs.LSM
local WUI = E:GetModule('WishFlex')
local AT = WUI:NewModule('ActionTimer', 'AceHook-3.0', 'AceEvent-3.0', 'AceTimer-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

local CustomPotions = {
    [211880] = true, [212265] = true, [212263] = true, [212264] = true, [211878] = true,
}

local RacialSpells = {
    59752, 20594, 58984, 20589, 28880, 68992, 255647, 265221, 265036, 287712, 312215,
    20572, 7744, 20549, 26297, 25046, 28730, 50613, 69041, 260364, 255654, 274738, 292463, 312411,
    107079, 368970, 357210
}
local RacialSpellsMap = {}
for _, id in ipairs(RacialSpells) do RacialSpellsMap[id] = true end

AT.Frames = {}
AT.trackedItems = {}
AT.buffDurationCache = {}
AT.itemSpellMap = {}
AT.isPreviewing = false

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.actionTimer = true
P["WishFlex"].actionTimer = {
    monitorTrinket13 = false, monitorTrinket14 = false,
    width = 45, height = 45, iconGap = 5, growth = "RIGHT",
    countFont = "Expressway", countFontSize = 16, countFontOutline = "OUTLINE",
    countXOffset = 0, countYOffset = 0,
    cdFontColor = { r = 1, g = 1, b = 1 }, buffFontColor = { r = 0, g = 1, b = 0 },
    glowColor = { r = 0, g = 1, b = 0.5, a = 1 }, glowLines = 8, glowFreq = 0.25, glowLength = 10, glowThick = 2
}

V["WishFlex"] = V["WishFlex"] or {}
V["WishFlex"].actionTimer = V["WishFlex"].actionTimer or { list = {} }

function AT.ApplyTexCoord(texture, width, height)
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

local function GetNativeCooldown(data)
    local start, duration = 0, 0
    if data.type == "item" then
        if C_Container and C_Container.GetItemCooldown then start, duration = C_Container.GetItemCooldown(data.id)
        elseif GetItemCooldown then start, duration = GetItemCooldown(data.id) end
    else
        if C_Spell and C_Spell.GetSpellCooldown then
            local info = C_Spell.GetSpellCooldown(data.id)
            if info then start, duration = info.startTime, info.duration end
        elseif GetSpellCooldown then start, duration = GetSpellCooldown(data.id) end
    end
    return start, duration
end

local function IsZero(val) return val == 0 end
local function IsLessOrEq(val, limit) return val <= limit end
local function IsEqual(a, b) return a == b end

local function SafeIsOnCD(start, duration)
    if start == nil or duration == nil then return false end
    local okStart, isStartZero = pcall(IsZero, start)
    if okStart and isStartZero then return false end
    local okDur, isGCD = pcall(IsLessOrEq, duration, 1.5)
    if okDur and isGCD then return false end
    return true
end

local ScannerTooltip = CreateFrame("GameTooltip", "WishFlex_ActionScanner", UIParent, "GameTooltipTemplate")
function AT:CacheDurations()
    if InCombatLockdown() then return end
    wipe(self.buffDurationCache); wipe(self.itemSpellMap)
    local patterns = { "持续%s*(%d+)%s*秒", "lasts%s*(%d+)%s*sec", "(%d+)%s*秒", "(%d+)%s*sec" }
    for uniqueKey, data in pairs(self.trackedItems) do
        if data.manualBuff and data.manualBuff > 0 then
            self.buffDurationCache[data.id] = data.manualBuff
            if data.type == "item" then
                local _, sID = C_Item.GetItemSpell(data.id); if sID then self.itemSpellMap[sID] = data.id end
            end
        else
            ScannerTooltip:SetOwner(UIParent, "ANCHOR_NONE"); ScannerTooltip:ClearLines()
            local ok
            if data.type == "item" then 
                local _, sID = C_Item.GetItemSpell(data.id); if sID then self.itemSpellMap[sID] = data.id end
                ok = pcall(function() ScannerTooltip:SetItemByID(data.id) end)
            else ok = pcall(function() ScannerTooltip:SetSpellByID(data.id) end) end
            
            if ok then
                for i = 1, 10 do
                    local line = _G["WishFlex_ActionScannerTextLeft" .. i]
                    local okText, text = pcall(function() return line and line:GetText() end)
                    if okText and text and type(text) == "string" and not issecretvalue(text) then
                        for _, p in ipairs(patterns) do
                            local val = text:match(p)
                            if val then self.buffDurationCache[data.id] = tonumber(val); break end
                        end
                    end
                    if self.buffDurationCache[data.id] then break end
                end
            end
        end
    end
end

local function IsActiveTrinket(itemID)
    if not itemID then return false end
    local _, spellID = C_Item.GetItemSpell(itemID)
    return spellID ~= nil
end

function AT:UpdateTrackedItems()
    wipe(self.trackedItems)
    if E.db.WishFlex.actionTimer.monitorTrinket13 then
        local trinket1 = GetInventoryItemID("player", 13)
        if IsActiveTrinket(trinket1) then self.trackedItems["item_"..trinket1] = { id = trinket1, type = "item", manualBuff = 0 } end
    end
    if E.db.WishFlex.actionTimer.monitorTrinket14 then
        local trinket2 = GetInventoryItemID("player", 14)
        if IsActiveTrinket(trinket2) then self.trackedItems["item_"..trinket2] = { id = trinket2, type = "item", manualBuff = 0 } end
    end
    for potID in pairs(CustomPotions) do 
        if C_Item.GetItemCount(potID) > 0 then self.trackedItems["item_"..potID] = { id = potID, type = "item", manualBuff = 0 } end 
    end
    for spellID in pairs(RacialSpellsMap) do
        if IsPlayerSpell(spellID) then self.trackedItems["spell_"..spellID] = { id = spellID, type = "spell", manualBuff = 0 } end
    end
    for id, info in pairs(E.private.WishFlex.actionTimer.list) do
        if type(info) == "table" and info.type then self.trackedItems[info.type.."_"..id] = { id = id, type = info.type, manualBuff = info.manualBuff or 0 } end
    end
    self:CacheDurations(); self:BuildFrames(); self:UpdateLayout()
end

function AT:UpdateList()
    if not WUI.OptionsArgs.actionTimer then return end
    local args = WUI.OptionsArgs.actionTimer.args.list.args; wipe(args)
    local idx = 1
    for id, info in pairs(E.private.WishFlex.actionTimer.list) do
        if type(info) == "table" and info.type then
            local spellInfo = (info.type == "spell") and type(id) == "number" and C_Spell.GetSpellInfo(id) or nil
            local name = (info.type == "item" and C_Item.GetItemInfo(id)) or (spellInfo and spellInfo.name) or tostring(id)
            local icon = (info.type == "item" and C_Item.GetItemIconByID(id)) or (spellInfo and spellInfo.iconID) or 136243
            args[tostring(id)] = {
                order = idx, type = "execute", name = name, image = icon, imageCoords = E.TexCoords,
                func = function() E.private.WishFlex.actionTimer.list[id] = nil; AT:UpdateTrackedItems(); AT:UpdateList() end
            }
            idx = idx + 1
        end
    end
end

function AT:BuildFrames()
    local anchor = _G["WishFlex_ActionTimer_Anchor"]
    if not anchor then return end
    for _, f in pairs(self.Frames) do f:Hide() end
    for uniqueKey, data in pairs(self.trackedItems) do
        if not self.Frames[uniqueKey] then
            local f = CreateFrame("Frame", "WishFlex_ActionTimerFrame_"..uniqueKey, anchor)
            f:CreateBackdrop("Transparent") 
            f.Icon = f:CreateTexture(nil, "BACKGROUND"); f.Icon:SetInside(f.backdrop)
            f.Cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
            f.Cooldown:SetInside(f.backdrop); f.Cooldown:SetHideCountdownNumbers(false); f.Cooldown:SetDrawEdge(false)
            E:RegisterCooldown(f.Cooldown)
            f.TextFrame = CreateFrame("Frame", nil, f); f.TextFrame:SetAllPoints(f); f.TextFrame:SetFrameLevel(f.Cooldown:GetFrameLevel() + 10)
            f.Count = f.TextFrame:CreateFontString(nil, "OVERLAY")
            f.data = data; f.buffEndTime = 0; f.buffDuration = 0; f.isGlowActive = false; f.onCD = false
            self.Frames[uniqueKey] = f
        end
        local f = self.Frames[uniqueKey]
        if data.type == "item" then f.Icon:SetTexture(C_Item.GetItemIconByID(data.id) or 136243)
        else local sInfo = C_Spell.GetSpellInfo(data.id); f.Icon:SetTexture(sInfo and sInfo.iconID or 136243) end
        f:Show()
    end
end

function AT:UpdateLayout()
    local cfg = E.db.WishFlex.actionTimer
    local anchor = _G["WishFlex_ActionTimer_Anchor"]
    if not anchor or not cfg then return end
    local w, h, gap, growth = cfg.width or 45, cfg.height or 45, cfg.iconGap or 5, cfg.growth or "RIGHT"
    
    local activeFrames = {}
    for uniqueKey, f in pairs(self.Frames) do if self.trackedItems[uniqueKey] then table.insert(activeFrames, f) end end
    table.sort(activeFrames, function(a, b) return a.data.id < b.data.id end)
    
    anchor:SetSize(w, h)
    if anchor.mover then anchor.mover:SetSize(w, h) end

    for i, f in ipairs(activeFrames) do
        f:ClearAllPoints()
        local x = 0
        if growth == "CENTER" then
            local totalW = (#activeFrames * w) + math.max(0, (#activeFrames - 1) * gap)
            x = -(totalW / 2) + (w / 2) + (i - 1) * (w + gap)
            f:SetPoint("CENTER", anchor, "CENTER", x, 0)
        elseif growth == "LEFT" then 
            x = -(i - 1) * (w + gap); f:SetPoint("CENTER", anchor, "CENTER", x, 0)
        elseif growth == "RIGHT" then 
            x = (i - 1) * (w + gap); f:SetPoint("CENTER", anchor, "CENTER", x, 0) 
        end
        
        f:SetSize(w, h); AT.ApplyTexCoord(f.Icon, w, h)
        local fontPath = LSM:Fetch('font', cfg.countFont or "Expressway")
        f.Count:FontTemplate(fontPath, cfg.countFontSize or 16, cfg.countFontOutline or "OUTLINE")
        f.Count:ClearAllPoints(); f.Count:SetPoint("CENTER", f, "CENTER", cfg.countXOffset or 0, cfg.countYOffset or 0)
        local cdText = f.Cooldown and f.Cooldown.timer and f.Cooldown.timer.text
        if cdText and type(cdText) == "table" and cdText.SetFont then
            cdText:FontTemplate(fontPath, cfg.countFontSize or 16, cfg.countFontOutline or "OUTLINE")
            local cdC = cfg.cdFontColor
            if cdC then cdText:SetTextColor(cdC.r, cdC.g, cdC.b) else cdText:SetTextColor(1, 1, 1) end
            cdText:ClearAllPoints(); cdText:SetPoint("CENTER", f, "CENTER", cfg.countXOffset or 0, cfg.countYOffset or 0)
        end
    end
end

function AT:UpdateConfig()
    self:UpdateLayout()
    local anchor = _G["WishFlex_ActionTimer_Anchor"]
    if anchor then
        self.isPreviewing = true
        E:UIFrameFadeIn(anchor, 0.2, anchor:GetAlpha(), 1)
        for _, f in pairs(self.Frames) do 
            if f:IsShown() then 
                E:UIFrameFadeIn(f, 0.2, f:GetAlpha(), 1) 
                f.Count:SetText("59")
                local bc = E.db.WishFlex.actionTimer.buffFontColor
                if bc then f.Count:SetTextColor(bc.r, bc.g, bc.b) else f.Count:SetTextColor(0, 1, 0) end
                f.Icon:SetDesaturated(false)
                f.Icon:SetVertexColor(1, 1, 1)
            end 
        end
        if self.previewTimer then self:CancelTimer(self.previewTimer) end
        self.previewTimer = self:ScheduleTimer(function()
            self.isPreviewing = false
            local SH = WUI:GetModule('SmartHide', true)
            if SH and type(SH.UpdateVisibility) == "function" then SH:UpdateVisibility() end
        end, 4)
    end
end

function AT:UNIT_SPELLCAST_SUCCEEDED(_, unit, _, spellID)
    if unit ~= "player" then return end
    local itemID = self.itemSpellMap[spellID]
    for uniqueKey, data in pairs(self.trackedItems) do
        if (data.type == "item" and data.id == itemID) or (data.type == "spell" and data.id == spellID) then
            local duration = self.buffDurationCache[data.id] or 15 
            if duration > 0 then 
                self.Frames[uniqueKey].buffEndTime = GetTime() + duration 
                self.Frames[uniqueKey].buffDuration = duration
            end
        end
    end
end

local function CheckAuraValid(id, isItem)
    local sName, sID = nil, id
    if isItem then
        local _, spID = C_Item.GetItemSpell(id)
        if spID then sID = spID; local sInfo = C_Spell.GetSpellInfo(sID); if sInfo then sName = sInfo.name end end
    else
        local sInfo = C_Spell.GetSpellInfo(id); if sInfo then sName = sInfo.name end
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

local function FormatTime(time)
    if time >= 60 then return string.format("%dm", math.floor(time / 60))
    elseif time > 5 then return tostring(math.ceil(time)) else return string.format("%.1f", time) end
end

function AT:Heartbeat()
    local t = GetTime(); local cfg = E.db.WishFlex.actionTimer
    local bc = cfg.buffFontColor
    local gc = cfg.glowColor

    for uniqueKey, data in pairs(self.trackedItems) do
        local f = self.Frames[uniqueKey]
        if f and f:IsShown() then
            local start, duration = GetNativeCooldown(data)
            local isCD = SafeIsOnCD(start, duration)
            local isRacial = (data.type == "spell" and RacialSpellsMap[data.id])
            
            local buffTimeLeft = 0
            if f.buffEndTime and f.buffEndTime > t then
                local elapsed = f.buffDuration - (f.buffEndTime - t)
                if elapsed > 1.5 and not CheckAuraValid(data.id, data.type == "item") then
                    f.buffEndTime = 0 
                else
                    buffTimeLeft = f.buffEndTime - t
                end
            end
            
            if buffTimeLeft > 0 then
                if f.onCD then f.Cooldown:Hide(); f.onCD = false end
                f.Icon:SetDesaturated(false); f.Icon:SetVertexColor(1, 1, 1)
                f.Count:SetText(FormatTime(buffTimeLeft))
                
                if bc then f.Count:SetTextColor(bc.r, bc.g, bc.b) else f.Count:SetTextColor(0, 1, 0) end
                
                if not f.isGlowActive and LCG then
                    local gr = gc and gc.r or 0
                    local gg = gc and gc.g or 1
                    local gb = gc and gc.b or 0.5
                    local ga = gc and gc.a or 1
                    LCG.PixelGlow_Start(f, {gr, gg, gb, ga}, cfg.glowLines or 8, cfg.glowFreq or 0.25, cfg.glowLength or 10, cfg.glowThick or 2, 0, 0, false, "ActionTimerGlow")
                    f.isGlowActive = true
                end
            elseif isCD then
                if not f.onCD then f.Cooldown:Show(); f.Cooldown:SetCooldown(start, duration); f.onCD = true end
                if not isRacial then f.Icon:SetDesaturated(true); f.Icon:SetVertexColor(0.6, 0.6, 0.6)
                else f.Icon:SetDesaturated(false); f.Icon:SetVertexColor(1, 1, 1) end
                
                f.Count:SetText("") 
                if f.isGlowActive and LCG then LCG.PixelGlow_Stop(f, "ActionTimerGlow"); f.isGlowActive = false end
            else
                if f.onCD then f.Cooldown:Clear(); f.Cooldown:Hide(); f.onCD = false end
                f.Icon:SetDesaturated(false); f.Icon:SetVertexColor(1, 1, 1); f.Count:SetText("")
                if f.isGlowActive and LCG then LCG.PixelGlow_Stop(f, "ActionTimerGlow"); f.isGlowActive = false end
            end
        end
    end
end

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.actionTimer = {
        order = 21, type = "group", name = "|cff00e5cc饰品药水|r", childGroups = "tab",
        args = {
            base = {
                order = 1, type = "group", name = "排版",
                get = function(i) return E.db.WishFlex.actionTimer[i[#i]] end,
                set = function(i, v) E.db.WishFlex.actionTimer[i[#i]] = v; AT:UpdateConfig() end,
                args = {
                    enable = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.modules.actionTimer end, set = function(_, v) E.db.WishFlex.modules.actionTimer = v; E:StaticPopup_Show("CONFIG_RL") end }, 
                    growth = { order = 2, type = "select", name = "增长方向", values = { ["LEFT"] = "向左", ["CENTER"] = "居中", ["RIGHT"] = "向右" } },
                    iconGap = { order = 3, type = "range", name = "间距", min = 0, max = 20, step = 1 },
                    width = { order = 4, type = "range", name = "宽度", min = 10, max = 100, step = 1 },
                    height = { order = 5, type = "range", name = "高度", min = 10, max = 100, step = 1 },
                    monitorTrinket13 = { order = 8, type = "toggle", name = "饰品 1", get = function() return E.db.WishFlex.actionTimer.monitorTrinket13 end, set = function(_, v) E.db.WishFlex.actionTimer.monitorTrinket13 = v; AT:UpdateTrackedItems(); AT:UpdateConfig() end },
                    monitorTrinket14 = { order = 9, type = "toggle", name = "饰品 2", get = function() return E.db.WishFlex.actionTimer.monitorTrinket14 end, set = function(_, v) E.db.WishFlex.actionTimer.monitorTrinket14 = v; AT:UpdateTrackedItems(); AT:UpdateConfig() end },
                }
            },
            text = {
                order = 2, type = "group", name = "文本与颜色", guiInline = true,
                get = function(i) return E.db.WishFlex.actionTimer[i[#i]] end,
                set = function(i, v) E.db.WishFlex.actionTimer[i[#i]] = v; AT:UpdateConfig() end,
                args = {
                    countFont = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "全局字体", values = LSM:HashTable("font") }, 
                    countFontOutline = { order = 2, type = "select", name = "字体描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } }, 
                    countFontSize = {order=3,type="range",name="文本大小",min=8,max=40,step=1}, 
                    countXOffset = {order=4,type="range",name="时间文本 X 偏移",min=-50,max=50,step=1}, 
                    countYOffset = {order=5,type="range",name="时间文本 Y 偏移",min=-50,max=50,step=1},
                    cdFontColor = { order=6, type="color", name="冷却时间颜色", get = function() local t = E.db.WishFlex.actionTimer.cdFontColor or {r=1,g=1,b=1} return t.r, t.g, t.b end, set = function(_, r, g, b) E.db.WishFlex.actionTimer.cdFontColor = {r=r,g=g,b=b}; AT:UpdateConfig() end }, 
                    buffFontColor = { order=7, type="color", name="高亮颜色", get = function() local t = E.db.WishFlex.actionTimer.buffFontColor or {r=0,g=1,b=0} return t.r, t.g, t.b end, set = function(_, r, g, b) E.db.WishFlex.actionTimer.buffFontColor = {r=r,g=g,b=b}; AT:UpdateConfig() end }, 
                }
            },
            glow = {
                order = 3, type = "group", name = "图标高亮",
                get = function(i) return E.db.WishFlex.actionTimer[i[#i]] end,
                set = function(i, v) E.db.WishFlex.actionTimer[i[#i]] = v; AT:UpdateConfig() end,
                args = {
                    glowColor = { order = 1, type = "color", name = "线条颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.actionTimer.glowColor or {r=0,g=1,b=0.5,a=1} return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.actionTimer.glowColor = {r=r,g=g,b=b,a=a}; end }, 
                    glowLines = { order = 2, type = "range", name = "线条数量", min = 1, max = 20, step = 1 },
                    glowFreq = { order = 3, type = "range", name = "滚动速度", min = 0.05, max = 2, step = 0.05 },
                    glowLength = { order = 4, type = "range", name = "线条长度", min = 1, max = 20, step = 1 },
                    glowThick = { order = 5, type = "range", name = "线条粗细", min = 1, max = 10, step = 1 },
                }
            },
            add = {
                order = 4, type = "group", name = "添加额外监控",
                args = {
                    inputID = { order = 1, type = "input", name = "输入ID", set = function(_, v) AT.tempID = tonumber(v) end, get = function() return tostring(AT.tempID or "") end },
                    inputType = { order = 2, type = "select", name = "类型", values = { ["item"] = "物品", ["spell"] = "法术" }, set = function(_, v) AT.tempType = v end, get = function() return AT.tempType or "item" end },
                    inputBuff = { order = 3, type = "range", name = "手动Buff时长(秒)", desc = "设为0则自动扫描工具提示", min = 0, max = 60, step = 1, set = function(_, v) AT.tempBuff = v end, get = function() return AT.tempBuff or 0 end },
                    executeAdd = { order = 4, type = "execute", name = "确认添加", func = function() 
                        if AT.tempID then 
                            local tType = AT.tempType or "item"
                            E.private.WishFlex.actionTimer.list[AT.tempID] = { type = tType, manualBuff = AT.tempBuff or 0 } 
                            AT.tempID = nil; AT.tempBuff = 0
                            AT:UpdateTrackedItems(); AT:UpdateList(); AT:UpdateConfig()
                        end 
                    end },
                }
            },
            list = { order = 5, type = "group", name = "监控列表 (点击移除)", args = {} }
        }
    }
end

hooksecurefunc(WUI, "Initialize", function() if not AT.Initialized then AT:Initialize() end end)

function AT:Initialize()
    if self.Initialized then return end
    self.Initialized = true
    InjectOptions(); if not E.db.WishFlex.modules.actionTimer then return end
    
    local anchor = CreateFrame("Frame", "WishFlex_ActionTimer_Anchor", E.UIParent)
    anchor:SetSize(40, 40); anchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, -200)
    E:CreateMover(anchor, "WishFlexActionTimerMover", "WishFlex: 动作计时(饰品药水)", nil, nil, nil, "ALL,WishFlex")
    
    self:UpdateTrackedItems()
    self:UpdateList()
    
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "UpdateTrackedItems")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "UpdateTrackedItems")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateTrackedItems")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    
    local tickerFrame = CreateFrame("Frame")
    local tickElapsed = 0
    tickerFrame:SetScript("OnUpdate", function(_, delta)
        tickElapsed = tickElapsed + delta
        local interval = InCombatLockdown() and 0.1 or 0.5
        if AT.isPreviewing then interval = 0.1 end
        if tickElapsed >= interval then
            tickElapsed = 0
            if not AT.isPreviewing then AT:Heartbeat() end
        end
    end)
end