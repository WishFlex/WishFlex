local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs.LSM
local WUI = E:GetModule('WishFlex')
local DEF = WUI:NewModule('DefensiveCooldowns', 'AceHook-3.0', 'AceEvent-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

local DEFAULT_BUFF_COLOR = {r = 0, g = 1, b = 0}
local DEFAULT_CD_COLOR = {r = 1, g = 0.82, b = 0}
local DEFAULT_STACK_COLOR = {r = 1, g = 1, b = 1}
local DEFAULT_GLOW_COLOR = {r = 0, g = 1, b = 0.5, a = 1}

-- =======================================================
-- 【本地内部数据库】: 你可以随意修改以下的 dur(持续), cd(冷却), charges(层数)
-- =======================================================
local SpellDB = {
    WARRIOR = { [118038]={dur=8,cd=180,charges=1}, [97462]={dur=10,cd=180,charges=1}, [184364]={dur=8,cd=120,charges=1}, [871]={dur=8,cd=240,charges=1}, [12975]={dur=15,cd=180,charges=1}, [23920]={dur=5,cd=25,charges=1}, [386029]={dur=2,cd=12,charges=1} },
    PALADIN = { [642]={dur=8,cd=300,charges=1}, [498]={dur=8,cd=60,charges=1}, [31850]={dur=10,cd=120,charges=1}, [86659]={dur=8,cd=300,charges=1}, [184662]={dur=15,cd=120,charges=1}, [205191]={dur=10,cd=60,charges=1} },
    HUNTER = { [186265]={dur=8,cd=180,charges=1}, [109304]={dur=10,cd=120,charges=1}, [264735]={dur=6,cd=180,charges=1}, [281195]={dur=10,cd=120,charges=1} },
    ROGUE = { [5277]={dur=10,cd=120,charges=1}, [31224]={dur=5,cd=120,charges=1}, [1966]={dur=10,cd=15,charges=1}, [199754]={dur=10,cd=120,charges=1} },
    PRIEST = { [19236]={dur=8,cd=90,charges=1}, [33206]={dur=8,cd=180,charges=1}, [47536]={dur=10,cd=90,charges=1}, [47588]={dur=10,cd=120,charges=1}, [64843]={dur=8,cd=180,charges=1}, [65081]={dur=4,cd=120,charges=1} },
    DEATHKNIGHT = { [48707]={dur=5,cd=60,charges=1}, [48792]={dur=8,cd=180,charges=1}, [49039]={dur=10,cd=120,charges=1}, [55233]={dur=10,cd=90,charges=1}, [48743]={dur=10,cd=120,charges=1} },
    SHAMAN = { [108271]={dur=12,cd=90,charges=1}, [210643]={dur=60,cd=180,charges=1}, [114052]={dur=15,cd=180,charges=1} },
    MAGE = { [45438]={dur=10,cd=240,charges=1}, [110909]={dur=10,cd=20,charges=3}, [198065]={dur=15,cd=60,charges=1}, [235313]={dur=10,cd=60,charges=1}, [342245]={dur=10,cd=60,charges=1}, [414658]={dur=12,cd=120,charges=1} },
    WARLOCK = { [104773]={dur=8,cd=180,charges=1}, [108416]={dur=8,cd=60,charges=1}, [389831]={dur=10,cd=12,charges=1} },
    MONK = { [115203]={dur=15,cd=180,charges=1}, [122278]={dur=10,cd=120,charges=1}, [122470]={dur=10,cd=90,charges=1}, [115176]={dur=6,cd=300,charges=1}, [115310]={dur=10,cd=180,charges=1}, [322507]={dur=10,cd=45,charges=1} },
    DRUID = { [22812]={dur=12,cd=60,charges=1}, [61336]={dur=6,cd=180,charges=2}, [102342]={dur=12,cd=90,charges=1}, [108238]={dur=10,cd=36,charges=2} },
    DEMONHUNTER = { [196718]={dur=8,cd=180,charges=1}, [198589]={dur=10,cd=60,charges=1}, [204021]={dur=8,cd=60,charges=1} },
    EVOKER = { [363916]={dur=12,cd=90,charges=2}, [374348]={dur=8,cd=60,charges=1}, [374227]={dur=5,cd=120,charges=1}, [357170]={dur=8,cd=60,charges=1} },
}

DEF.activeDefensives = {}
DEF.defensiveIcons = {}
-- 核心本地追踪表：彻底摒弃游戏API
DEF.tracker = {}

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.defensiveCDs = true
P["WishFlex"].defensives = {
    enable = true, attachToPlayer = true, customSpells = "",
    width = 45, height = 45, iconGap = 2, growth = "LEFT", desaturate = true,
    countFont = "Expressway", countFontOutline = "OUTLINE",
    buffFontSize = 18, buffFontColor = DEFAULT_BUFF_COLOR, buffXOffset = 0, buffYOffset = 0,
    cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdXOffset = 0, cdYOffset = 0,
    stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackXOffset = 12, stackYOffset = -12,
    glowEnable = true, glowColor = DEFAULT_GLOW_COLOR, glowLines = 8, glowFreq = 0.25, glowThick = 2 
}

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.defensives = {
        order = 22, type = "group", name = "|cff00e5cc独立防御技能|r", childGroups = "tab",
        get = function(i) return E.db.WishFlex.defensives[i[#i]] end,
        set = function(i, v) E.db.WishFlex.defensives[i[#i]] = v; DEF:UpdateLayout() end,
        args = {
            general = {
                order = 1, type = "group", name = "基础与排版", guiInline = true,
                args = {
                    enable = { order = 1, type = "toggle", name = "启用模块", get = function() return E.db.WishFlex.modules.defensiveCDs end, set = function(_, v) E.db.WishFlex.modules.defensiveCDs = v; E:StaticPopup_Show("CONFIG_RL") end },
                    attachToPlayer = { order = 2, type = "toggle", name = "吸附至玩家头像框" },
                    customSpells = { order = 3, type = "input", name = "自定义技能ID (逗号分隔)", width = "full", set = function(_, v) E.db.WishFlex.defensives.customSpells = v; DEF:UpdateKnownDefensives() end },
                    growth = { order = 4, type = "select", name = "增长方向", disabled = function() return E.db.WishFlex.defensives.attachToPlayer end, values = { ["LEFT"] = "向左", ["CENTER"] = "居中", ["RIGHT"] = "向右" } },
                    iconGap = { order = 5, type = "range", name = "间距", min = 0, max = 20, step = 1 },
                    width = { order = 6, type = "range", name = "图标宽度", min = 10, max = 100, step = 1 },
                    height = { order = 7, type = "range", name = "图标高度", min = 10, max = 100, step = 1 },
                    desaturate = { order = 8, type = "toggle", name = "冷却中变灰" },
                }
            },
            font = {
                order = 2, type = "group", name = "字体设置", guiInline = true,
                args = {
                    countFont = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "全局字体", values = LSM:HashTable("font") },
                    countFontOutline = { order = 2, type = "select", name = "字体描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                    buffFontSize = {order=3,type="range",name="持续时间大小",min=4,max=40,step=1}, 
                    buffFontColor = {order=4,type="color",name="持续时间颜色",get=function() local t=E.db.WishFlex.defensives.buffFontColor or DEFAULT_BUFF_COLOR return t.r,t.g,t.b end, set=function(_,r,g,b) E.db.WishFlex.defensives.buffFontColor={r=r,g=g,b=b} end}, 
                    buffXOffset = {order=5,type="range",name="持续时间X偏移",min=-50,max=50,step=1}, 
                    buffYOffset = {order=6,type="range",name="持续时间Y偏移",min=-50,max=50,step=1},
                    
                    cdFontSize = {order=7,type="range",name="冷却时间大小",min=4,max=40,step=1}, 
                    cdFontColor = {order=8,type="color",name="冷却时间颜色",get=function() local t=E.db.WishFlex.defensives.cdFontColor or DEFAULT_CD_COLOR return t.r,t.g,t.b end, set=function(_,r,g,b) E.db.WishFlex.defensives.cdFontColor={r=r,g=g,b=b} end}, 
                    cdXOffset = {order=9,type="range",name="冷却时间X偏移",min=-50,max=50,step=1}, 
                    cdYOffset = {order=10,type="range",name="冷却时间Y偏移",min=-50,max=50,step=1},
                    
                    stackFontSize = {order=11,type="range",name="层数大小",min=4,max=40,step=1}, 
                    stackFontColor = {order=12,type="color",name="层数颜色",get=function() local t=E.db.WishFlex.defensives.stackFontColor or DEFAULT_STACK_COLOR return t.r,t.g,t.b end, set=function(_,r,g,b) E.db.WishFlex.defensives.stackFontColor={r=r,g=g,b=b} end}, 
                    stackXOffset = {order=13,type="range",name="层数X偏移",min=-50,max=50,step=1}, 
                    stackYOffset = {order=14,type="range",name="层数Y偏移",min=-50,max=50,step=1},
                }
            },
            glow = {
                order = 3, type = "group", name = "高亮效果", guiInline = true,
                args = {
                    glowEnable = { order = 1, type = "toggle", name = "启用像素发光" },
                    glowColor = { order = 2, type = "color", name = "线条颜色", hasAlpha = true, get = function() local t = E.db.WishFlex.defensives.glowColor or DEFAULT_GLOW_COLOR return t.r, t.g, t.b, t.a end, set = function(_, r, g, b, a) E.db.WishFlex.defensives.glowColor = {r=r,g=g,b=b,a=a}; end },
                    glowLines = { order = 3, type = "range", name = "线条数量", min = 1, max = 20, step = 1 },
                    glowFreq = { order = 4, type = "range", name = "动画速度", min = 0.05, max = 2, step = 0.05 },
                    glowThick = { order = 5, type = "range", name = "线条粗细", min = 1, max = 10, step = 1 },
                }
            }
        }
    }
end

local function ApplyTexCoord(texture, width, height)
    if not texture or not texture.SetTexCoord then return end
    local ratio = width / height
    local offset = 0.08
    local left, right, top, bottom = offset, 1-offset, offset, 1-offset
    if ratio > 1 then local vH = (1 - 2*offset) / ratio; top, bottom = 0.5 - (vH/2), 0.5 + (vH/2)
    elseif ratio < 1 then local vW = (1 - 2*offset) * ratio; left, right = 0.5 - (vW/2), 0.5 + (vW/2) end
    texture:SetTexCoord(left, right, top, bottom)
end

function DEF:GetIconFrame(index)
    if not self.defensiveIcons[index] then
        local f = CreateFrame("Frame", "WishFlex_DefensiveIcon"..index, _G.WishFlex_DefensiveViewer)
        f:SetTemplate("Transparent")
        f.Icon = f:CreateTexture(nil, "ARTWORK"); f.Icon:SetInside()
        f.Cooldown = CreateFrame("Cooldown", "$parentCooldown", f, "CooldownFrameTemplate")
        f.Cooldown:SetInside(); f.Cooldown:SetDrawEdge(false); f.Cooldown:SetHideCountdownNumbers(true) 
        
        f.OverlayFrame = CreateFrame("Frame", nil, f)
        f.OverlayFrame:SetAllPoints(); f.OverlayFrame:SetFrameLevel(f.Cooldown:GetFrameLevel() + 5)
        
        local db = E.db.WishFlex.defensives
        local fPath = LSM:Fetch('font', db.countFont or "Expressway")
        local outline = db.countFontOutline or "OUTLINE"

        f.BuffText = f.OverlayFrame:CreateFontString(nil, "OVERLAY")
        f.BuffText:SetFont(fPath, db.buffFontSize or 18, outline)
        
        f.CDText = f.OverlayFrame:CreateFontString(nil, "OVERLAY")
        f.CDText:SetFont(fPath, db.cdFontSize or 18, outline)
        
        f.StackText = f.OverlayFrame:CreateFontString(nil, "OVERLAY")
        f.StackText:SetFont(fPath, db.stackFontSize or 14, outline)
        
        self.defensiveIcons[index] = f
    end
    return self.defensiveIcons[index]
end

function DEF:UpdateKnownDefensives()
    if InCombatLockdown() then return end
    table.wipe(self.activeDefensives)
    local _, pClass = UnitClass("player")
    local db = SpellDB[pClass] or {}
    local seen = {}

    local function AddSpellToTracker(spellID, dur, cd, charges)
        if not seen[spellID] then
            table.insert(self.activeDefensives, spellID)
            seen[spellID] = true
            if not self.tracker[spellID] then
                self.tracker[spellID] = {
                    info = {dur = dur, cd = cd, charges = charges},
                    buffEndTime = 0, cdEndTime = 0, nextChargeTime = 0,
                    currentCharges = charges
                }
            end
        end
    end

    for spellID, data in pairs(db) do
        if IsPlayerSpell(spellID) then AddSpellToTracker(spellID, data.dur, data.cd, data.charges) end
    end

    local customStr = E.db.WishFlex.defensives.customSpells or ""
    for idStr in string.gmatch(customStr, "[%d]+") do
        local spellID = tonumber(idStr)
        if spellID then
            local data = db[spellID] or {dur=10, cd=60, charges=1}
            AddSpellToTracker(spellID, data.dur, data.cd, data.charges)
        end
    end

    self:UpdateLayout()
end

function DEF:UpdateLayout()
    local db = E.db.WishFlex.defensives
    local container = _G.WishFlex_DefensiveViewer
    if not db.enable or #self.activeDefensives == 0 then if container then container:Hide() end; return end
    
    container:Show()
    local w, h, gap, growth = db.width, db.height, db.iconGap, db.growth
    if db.attachToPlayer then growth = "LEFT" end
    
    local totalW = (#self.activeDefensives * w) + math.max(0, (#self.activeDefensives - 1) * gap)
    container:SetSize(math.max(w, totalW), h)

    if db.attachToPlayer and _G.ElvUF_Player then
        container:ClearAllPoints(); container:SetPoint("BOTTOMRIGHT", _G.ElvUF_Player, "TOPRIGHT", 0, 1)
        if container.mover then container.mover:SetAlpha(0) end 
    else
        if container.mover then 
            container.mover:SetSize(math.max(w, totalW), h); container.mover:SetAlpha(1)
            container:ClearAllPoints(); container:SetPoint("CENTER", container.mover, "CENTER")
        end
    end

    for i = #self.activeDefensives + 1, #self.defensiveIcons do self.defensiveIcons[i]:Hide() end
    for i, spellID in ipairs(self.activeDefensives) do
        local f = self:GetIconFrame(i)
        f:ClearAllPoints(); f:Show()
        local x = 0
        if growth == "CENTER" then x = -(totalW / 2) + (w / 2) + (i - 1) * (w + gap); f:SetPoint("CENTER", container, "CENTER", x, 0)
        elseif growth == "LEFT" then x = -(i - 1) * (w + gap); f:SetPoint("RIGHT", container, "RIGHT", x, 0)
        elseif growth == "RIGHT" then x = (i - 1) * (w + gap); f:SetPoint("LEFT", container, "LEFT", x, 0) end

        f:SetSize(w, h)
        local effectiveID = (C_Spell and C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(spellID)) or spellID
        local iconTex = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(effectiveID)) or GetSpellTexture(effectiveID) or 136243
        f.Icon:SetTexture(iconTex); ApplyTexCoord(f.Icon, w, h)
        f.Cooldown:SetReverse(true); f.Cooldown:SetSwipeColor(0, 0, 0, 0.8)
    end
end

-- =======================================================
-- 【本地引擎】：彻底拒绝访问游戏API层数和冷却时长！
-- =======================================================
function DEF:UNIT_SPELLCAST_SUCCEEDED(_, unit, _, spellID)
    if unit ~= "player" then return end
    local effID = (C_Spell and C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(spellID)) or spellID

    for _, trackID in ipairs(self.activeDefensives) do 
        local tID = (C_Spell and C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(trackID)) or trackID
        if tID == effID or trackID == spellID then
            local tData = self.tracker[trackID]
            if tData then
                local now = GetTime()
                tData.buffEndTime = now + tData.info.dur
                
                if tData.info.charges > 1 then
                    if tData.currentCharges > 0 then
                        tData.currentCharges = tData.currentCharges - 1
                        if tData.currentCharges == tData.info.charges - 1 then
                            tData.nextChargeTime = now + tData.info.cd
                        end
                    end
                else
                    tData.cdEndTime = now + tData.info.cd
                end
            end
            break
        end 
    end
end

function DEF:Heartbeat()
    local db = E.db.WishFlex.defensives
    if not db.enable then return end
    local now = GetTime()
    local fPath = LSM:Fetch('font', db.countFont or "Expressway")
    local outline = db.countFontOutline or "OUTLINE"

    for i, spellID in ipairs(self.activeDefensives) do
        local f = self.defensiveIcons[i]
        local tData = self.tracker[spellID]

        if f and f:IsShown() and tData then
            local info = tData.info

            -- 内部引擎充能恢复机制
            if info.charges > 1 then
                if tData.currentCharges < info.charges and now >= tData.nextChargeTime then
                    tData.currentCharges = tData.currentCharges + 1
                    if tData.currentCharges < info.charges then
                        tData.nextChargeTime = tData.nextChargeTime + info.cd
                    else
                        tData.nextChargeTime = 0
                    end
                end
            end

            local isBuffing = tData.buffEndTime > now
            local isOnCD = false
            local cdStart, cdDur = 0, info.cd
            local remain = 0

            if info.charges > 1 then
                if tData.currentCharges == 0 then
                    isOnCD = true
                    remain = tData.nextChargeTime - now
                    cdStart = tData.nextChargeTime - info.cd
                end
            else
                if tData.cdEndTime > now then
                    isOnCD = true
                    remain = tData.cdEndTime - now
                    cdStart = tData.cdEndTime - info.cd
                end
            end
            
            -- UI 渲染
            if isBuffing then
                f.Icon:SetDesaturated(false); f.Icon:SetVertexColor(1, 1, 1)
                f.CDText:SetText(""); f.Cooldown:Hide()
                
                local bfc = db.buffFontColor or DEFAULT_BUFF_COLOR
                f.BuffText:FontTemplate(fPath, db.buffFontSize, outline)
                f.BuffText:SetTextColor(bfc.r, bfc.g, bfc.b)
                f.BuffText:ClearAllPoints(); f.BuffText:SetPoint("CENTER", f.Icon, "CENTER", db.buffXOffset, db.buffYOffset)
                f.BuffText:SetFormattedText("%.1f", tData.buffEndTime - now)
                
                if db.glowEnable and not f.isGlowActive and LCG then 
                    local gc = db.glowColor or DEFAULT_GLOW_COLOR
                    LCG.PixelGlow_Start(f, {gc.r, gc.g, gc.b, gc.a}, db.glowLines, db.glowFreq, 10, db.glowThick, 0, 0, false, "DefensiveGlow")
                    f.isGlowActive = true 
                end
            elseif isOnCD then
                if f.isGlowActive and LCG then LCG.PixelGlow_Stop(f, "DefensiveGlow"); f.isGlowActive = false end
                f.BuffText:SetText("")
                if db.desaturate then f.Icon:SetDesaturated(true); f.Icon:SetVertexColor(0.5, 0.5, 0.5) else f.Icon:SetDesaturated(false); f.Icon:SetVertexColor(1, 1, 1) end
                
                -- 使用原生的视觉转条（纯视觉扫过，不会抛错）
                if f._lastCDStart ~= cdStart or f._lastCDDur ~= cdDur then 
                    f.Cooldown:Show(); f.Cooldown:SetCooldown(cdStart, cdDur); f._lastCDStart = cdStart; f._lastCDDur = cdDur 
                end
                
                local cfc = db.cdFontColor or DEFAULT_CD_COLOR
                f.CDText:FontTemplate(fPath, db.cdFontSize, outline)
                f.CDText:SetTextColor(cfc.r, cfc.g, cfc.b)
                f.CDText:ClearAllPoints(); f.CDText:SetPoint("CENTER", f.Icon, "CENTER", db.cdXOffset, db.cdYOffset)
                f.CDText:SetFormattedText("%.0f", remain)
            else
                if f.isGlowActive and LCG then LCG.PixelGlow_Stop(f, "DefensiveGlow"); f.isGlowActive = false end
                f.BuffText:SetText(""); f.CDText:SetText(""); f.Cooldown:Hide(); f.Icon:SetDesaturated(false); f.Icon:SetVertexColor(1, 1, 1)
                f._lastCDStart = 0; f._lastCDDur = 0
            end

            -- 层数渲染
            if info.charges > 1 then
                local sfc = db.stackFontColor or DEFAULT_STACK_COLOR
                f.StackText:FontTemplate(fPath, db.stackFontSize, outline)
                f.StackText:SetTextColor(sfc.r, sfc.g, sfc.b)
                f.StackText:ClearAllPoints(); f.StackText:SetPoint("CENTER", f.Icon, "CENTER", db.stackXOffset, db.stackYOffset)
                f.StackText:SetText((tData.currentCharges > 0) and tostring(tData.currentCharges) or "")
            else 
                f.StackText:SetText("") 
            end
        end
    end
end

function DEF:Initialize()
    if not E.db.WishFlex.modules.defensiveCDs then return end
    local container = CreateFrame("Frame", "WishFlex_DefensiveViewer", E.UIParent)
    container:SetSize(45, 45); container:SetPoint("CENTER", E.UIParent, "CENTER", 0, -150)
    E:CreateMover(container, "WishFlexDefensiveMover", "WishFlex: 独立防御技能", nil, nil, nil, "ALL,WishFlex")
    self:UpdateKnownDefensives(); self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED"); self:RegisterEvent("PLAYER_TALENT_UPDATE", "UpdateKnownDefensives"); self:RegisterEvent("SPELLS_CHANGED", "UpdateKnownDefensives")
    local ticker = 0; container:SetScript("OnUpdate", function(_, elapsed) ticker = ticker + elapsed; local interval = InCombatLockdown() and 0.1 or 0.5; if ticker >= interval then ticker = 0; DEF:Heartbeat() end end)
end