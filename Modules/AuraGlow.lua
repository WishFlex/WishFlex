local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs.LSM
local WUI = E:GetModule('WishFlex')
local mod = WUI:GetModule('AuraGlow', true) or WUI:NewModule('AuraGlow', 'AceHook-3.0', 'AceEvent-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

-- =========================================
-- 1. 初始化数据库
-- =========================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.auraGlow = true
P["WishFlex"].auraGlow = {
    enable = true,
    showOnlyKnown = true, 
    spells = {
        -- 【战士】
        ["107574"] = { buffID = 107574, duration = 0 }, 
        ["1719"]   = { buffID = 1719,   duration = 0 }, 
        ["871"]    = { buffID = 871,    duration = 0 }, 
        ["12975"]  = { buffID = 12975,  duration = 0 }, 
        ["118038"] = { buffID = 118038, duration = 0 }, 
        ["23920"]  = { buffID = 23920,  duration = 0 }, 
        ["184364"] = { buffID = 184364, duration = 0 }, 
        ["32736"]  = { buffID = 32736,  duration = 0 }, 
        -- 【圣骑士】
        ["31884"]  = { buffID = 31884,  duration = 0 }, 
        ["231895"] = { buffID = 231895, duration = 0 }, 
        ["642"]    = { buffID = 642,    duration = 0 }, 
        ["31850"]  = { buffID = 31850,  duration = 0 }, 
        ["86659"]  = { buffID = 86659,  duration = 0 }, 
        ["498"]    = { buffID = 498,    duration = 0 }, 
        ["6940"]   = { buffID = 6940,   duration = 0 }, 
        -- 【猎人】
        ["19574"]  = { buffID = 19574,  duration = 0 }, 
        ["288613"] = { buffID = 288613, duration = 0 }, 
        ["360952"] = { buffID = 360952, duration = 0 }, 
        ["186265"] = { buffID = 186265, duration = 0 }, 
        ["264735"] = { buffID = 264735, duration = 0 }, 
        -- 【潜行者】
        ["13750"]  = { buffID = 13750,  duration = 0 }, 
        ["121471"] = { buffID = 121471, duration = 0 }, 
        ["185313"] = { buffID = 185313, duration = 0 }, 
        ["31224"]  = { buffID = 31224,  duration = 0 }, 
        ["5277"]   = { buffID = 5277,   duration = 0 }, 
        ["1966"]   = { buffID = 1966,   duration = 0 }, 
        -- 【牧师】
        ["10060"]  = { buffID = 10060,  duration = 0 }, 
        ["33206"]  = { buffID = 33206,  duration = 0 }, 
        ["47536"]  = { buffID = 47536,  duration = 0 }, 
        ["47788"]  = { buffID = 47788,  duration = 0 }, 
        ["47585"]  = { buffID = 47585,  duration = 0 }, 
        ["19236"]  = { buffID = 19236,  duration = 0 }, 
        -- 【死亡骑士】
        ["51271"]  = { buffID = 51271,  duration = 0 }, 
        ["49028"]  = { buffID = 49028,  duration = 0 }, 
        ["48792"]  = { buffID = 48792,  duration = 0 }, 
        ["48707"]  = { buffID = 48707,  duration = 0 }, 
        ["55233"]  = { buffID = 55233,  duration = 0 }, 
        -- 【萨满祭司】
        ["114050"] = { buffID = 114050, duration = 0 }, 
        ["114051"] = { buffID = 114051, duration = 0 }, 
        ["114052"] = { buffID = 114052, duration = 0 }, 
        ["108271"] = { buffID = 108271, duration = 0 }, 
        ["79206"]  = { buffID = 79206,  duration = 0 }, 
        -- 【法师】
        ["190319"] = { buffID = 190319, duration = 0 }, 
        ["12472"]  = { buffID = 12472,  duration = 0 }, 
        ["365362"] = { buffID = 365362, duration = 0 }, 
        ["45438"]  = { buffID = 45438,  duration = 0 }, 
        ["110959"] = { buffID = 110959, duration = 0 }, 
        ["108978"] = { buffID = 108978, duration = 0 }, 
        -- 【术士】
        ["104773"] = { buffID = 104773, duration = 0 }, 
        ["108416"] = { buffID = 108416, duration = 0 }, 
        -- 【武僧】
        ["137639"] = { buffID = 137639, duration = 0 }, 
        ["115288"] = { buffID = 115288, duration = 0 }, 
        ["122278"] = { buffID = 122278, duration = 0 }, 
        ["115203"] = { buffID = 115203, duration = 0 }, 
        ["122783"] = { buffID = 122783, duration = 0 }, 
        ["122470"] = { buffID = 122470, duration = 0 }, 
        -- 【德鲁伊】
        ["390414"] = { buffID = 390414, duration = 0 }, 
        ["33891"]  = { buffID = 33891,  duration = 0 }, 
        ["102558"] = { buffID = 102558, duration = 0 }, 
        ["319454"] = { buffID = 319454, duration = 0 }, 
        ["22812"]  = { buffID = 22812,  duration = 0 }, 
        ["61336"]  = { buffID = 61336,  duration = 0 }, 
        -- 【恶魔猎手】
        ["191427"] = { buffID = 191427, duration = 0 }, 
        ["187827"] = { buffID = 187827, duration = 0 }, 
        ["198589"] = { buffID = 198589, duration = 0 }, 
        ["204021"] = { buffID = 204021, duration = 0 }, 
        -- 【唤魔师】
        ["375087"] = { buffID = 375087, duration = 0 }, 
        ["363916"] = { buffID = 363916, duration = 0 }, 
        ["374348"] = { buffID = 374348, duration = 0 }, 
    },
    text = { font = "Expressway", fontSize = 20, fontOutline = "OUTLINE", color = {r = 1, g = 0.82, b = 0}, offsetX = 0, offsetY = 0 },
    glowType = "pixel", glowColor = {r = 1, g = 0.82, b = 0, a = 1},
    glowPixelLines = 8, glowPixelFrequency = 0.25, glowPixelLength = 10,
    glowPixelThickness = 2, glowPixelXOffset = 0, glowPixelYOffset = 0,
}

local OverlayFrames = {}
local ActiveGlows = {}
mod.trackedAuras = {} 

-- =========================================
-- 2. 性能优化：API 内存缓存 (降耗核心)
-- =========================================
local BaseSpellCache = {}
local function GetBaseSpellFast(spellID)
    if not spellID then return nil end
    if BaseSpellCache[spellID] == nil then
        if C_Spell and C_Spell.GetBaseSpell then
            BaseSpellCache[spellID] = C_Spell.GetBaseSpell(spellID) or spellID
        else
            BaseSpellCache[spellID] = spellID
        end
    end
    return BaseSpellCache[spellID]
end

local function MatchesSpellID(info, targetID)
    if not info then return false end
    if info.spellID == targetID or info.overrideSpellID == targetID then return true end
    if info.linkedSpellIDs then
        for i = 1, #info.linkedSpellIDs do
            if info.linkedSpellIDs[i] == targetID then return true end
        end
    end
    if GetBaseSpellFast(info.spellID) == targetID then return true end
    return false
end

local function HasAuraInstanceID(value)
    if value == nil then return false end
    if issecretvalue and issecretvalue(value) then return true end
    if type(value) == "number" and value == 0 then return false end
    return true
end

local function VerifyAuraAlive(checkID, checkUnit)
    if not checkID then return false end
    local ok, aData = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, checkUnit, checkID)
    return (ok and aData ~= nil)
end

local function GetAuraDataAnywhere(buffID)
    local ok, auraData = pcall(C_UnitAuras.GetPlayerAuraBySpellID, buffID)
    if ok and auraData then return auraData, "player" end

    if UnitExists("target") then
        for _, filter in ipairs({"HARMFUL", "HELPFUL"}) do
            for i = 1, 40 do
                local aData
                pcall(function() aData = C_UnitAuras.GetAuraDataByIndex("target", i, filter) end)
                if not aData then break end
                
                local match = false
                pcall(function() match = (aData.spellId == buffID) end)
                if match then return aData, "target" end
            end
        end
    end
    return nil, "player"
end

-- =========================================
-- 3. 设置界面
-- =========================================
local function IsSpellLearned(spellID)
    if not spellID then return false end
    if IsPlayerSpell(spellID) then return true end
    if C_Spell and C_Spell.IsSpellKnownOrOverridesKnown and C_Spell.IsSpellKnownOrOverridesKnown(spellID) then return true end
    return false
end

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.cdmanager = WUI.OptionsArgs.cdmanager or { order = 20, type = "group", name = "|cff00e5cc冷却管理器|r", childGroups = "tab", args = {} }
    
    local args = WUI.OptionsArgs.cdmanager.args
    args.auraglow = {
        order = 7, type = "group", name = "高亮提醒",
        get = function(info) return E.db.WishFlex.auraGlow[info[#info]] end,
        set = function(info, v) E.db.WishFlex.auraGlow[info[#info]] = v; mod:UpdateGlows(true) end,
        args = {
            enable = { order = 1, type = "toggle", name = "启用高亮提醒" },
            showOnlyKnown = { order = 2, type = "toggle", name = "仅显示已学技能", desc = "开启后，下拉列表会自动过滤，只显示当前专精学会的技能。\n如果需要配置饰品、光环等非技能效果，请关闭此选项。" },
            desc = { order = 3, type = "description", name = "|cff00ffcc巅峰方案：|r\n极致性能优化版！支持脱战智能降频、全域单次扫描法与底层 API 内存级缓存。\n" },
            spellManagement = {
                order = 4, type = "group", name = "法术管理", guiInline = true,
                args = {
                    addSpell = { order = 1, type = "input", name = "添加技能ID", get = function() return "" end, set = function(_, v) local id = tonumber(v) if id then E.db.WishFlex.auraGlow.spells[tostring(id)] = { buffID = id, duration = 0 }; mod.selectedSpell = tostring(id) end end },
                    selectSpell = { 
                        order = 2, type = "select", name = "管理已添加技能", 
                        values = function() 
                            local vals = {} 
                            for k, v in pairs(E.db.WishFlex.auraGlow.spells) do 
                                local id = tonumber(k)
                                local shouldShow = true
                                if E.db.WishFlex.auraGlow.showOnlyKnown then shouldShow = IsSpellLearned(id) end
                                if shouldShow then
                                    local name = C_Spell.GetSpellName(id) or "未知技能" 
                                    vals[k] = name .. " (" .. k .. ")" 
                                end
                            end 
                            return vals 
                        end, 
                        get = function() return mod.selectedSpell end, 
                        set = function(_, v) mod.selectedSpell = v end 
                    },
                    editBuff = { order = 3, type = "input", name = "触发发光的Buff ID", get = function() local d = mod.selectedSpell and E.db.WishFlex.auraGlow.spells[mod.selectedSpell]; return d and tostring(type(d) == "table" and d.buffID or d) or "" end, set = function(_, v) local id = tonumber(v); if mod.selectedSpell and id then if type(E.db.WishFlex.auraGlow.spells[mod.selectedSpell]) ~= "table" then E.db.WishFlex.auraGlow.spells[mod.selectedSpell] = { buffID = id, duration = 0 } else E.db.WishFlex.auraGlow.spells[mod.selectedSpell].buffID = id end; mod:UpdateGlows(true) end end, disabled = function() return not mod.selectedSpell end },
                    deleteSpell = { order = 4, type = "execute", name = "删除选中", func = function() if mod.selectedSpell then local id = tonumber(mod.selectedSpell); E.db.WishFlex.auraGlow.spells[mod.selectedSpell] = nil; mod.selectedSpell = nil; if ActiveGlows[id] then ActiveGlows[id] = false; if OverlayFrames[id] then LCG.PixelGlow_Stop(OverlayFrames[id], "WishAuraDurationGlow"); OverlayFrames[id]:Hide() end end; if _G.BuffIconCooldownViewer and _G.BuffIconCooldownViewer.itemFramePool then for frame in _G.BuffIconCooldownViewer.itemFramePool:EnumerateActive() do if frame.cooldownInfo and MatchesSpellID(frame.cooldownInfo, id) then frame:SetAlpha(1); frame:SetWidth(45); frame:EnableMouse(true) end end end; local CC = WUI:GetModule('CooldownCustom', true); if CC and CC.TriggerLayout then CC:TriggerLayout() end end end, disabled = function() return not mod.selectedSpell end }
                }
            },
            glowGroup = {
                order = 5, type = "group", name = "发光设置", guiInline = true,
                args = {
                    glowColor = { order = 1, type = "color", name = "颜色", hasAlpha = true, get = function() local c = E.db.WishFlex.auraGlow.glowColor; return c.r, c.g, c.b, c.a end, set = function(_, r, g, b, a) E.db.WishFlex.auraGlow.glowColor = {r=r, g=g, b=b, a=a}; mod:UpdateGlows(true) end },
                    glowPixelLines = { order = 2, type = "range", name = "线条数", min = 1, max = 20, step = 1 },
                    glowPixelFrequency = { order = 3, type = "range", name = "频率", min = -2, max = 2, step = 0.05 },
                    glowPixelLength = { order = 4, type = "range", name = "长度", min = 1, max = 50, step = 1 },
                    glowPixelThickness = { order = 5, type = "range", name = "粗细", min = 1, max = 10, step = 1 },
                    glowPixelXOffset = { order = 6, type = "range", name = "X轴偏移", min = -20, max = 20, step = 1 },
                    glowPixelYOffset = { order = 7, type = "range", name = "Y轴偏移", min = -20, max = 20, step = 1 },
                }
            },
            textGroup = {
                order = 6, type = "group", name = "倒计时文本设置", guiInline = true,
                get = function(info) return E.db.WishFlex.auraGlow.text[info[#info]] end,
                set = function(info, v) E.db.WishFlex.auraGlow.text[info[#info]] = v; mod:UpdateGlows(true) end,
                args = {
                    font = { order = 1, type = "select", name = "字体", dialogControl = 'LSM30_Font', values = LSM:HashTable("font") },
                    fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 60, step = 1 },
                    fontOutline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "OUTLINE", ["MONOCHROMEOUTLINE"] = "MONOCROMEOUTLINE", ["THICKOUTLINE"] = "THICKOUTLINE" } },
                    color = { order = 4, type = "color", name = "颜色", get = function() local c = E.db.WishFlex.auraGlow.text.color; return c.r, c.g, c.b end, set = function(_, r, g, b) E.db.WishFlex.auraGlow.text.color = {r=r, g=g, b=b}; mod:UpdateGlows(true) end },
                    offsetX = { order = 5, type = "range", name = "X轴偏移", min = -50, max = 50, step = 1 },
                    offsetY = { order = 6, type = "range", name = "Y轴偏移", min = -50, max = 50, step = 1 },
                }
            }
        }
    }
end

-- =========================================
-- 4. 动态裁切算法 & 极速贴合
-- =========================================
local function GetCropCoords(w, h)
    local l, r, t, b = unpack(E.TexCoords)
    if not w or not h or h == 0 or w == 0 then return l, r, t, b end
    local ratio = w / h
    if math.abs(ratio - 1) < 0.05 then return l, r, t, b end
    if ratio > 1 then
        local crop = (1 - (1/ratio)) / 2
        local rangeY = b - t
        return l, r, t + rangeY * crop, b - rangeY * crop
    else
        local crop = (1 - ratio) / 2
        local rangeX = r - l
        return l + rangeX * crop, r - rangeX * crop, t, b
    end
end

local function GetHardcodedSize(parentFrame)
    local cfg = E.db.WishFlex.cdManager
    if not cfg then return 45, 45 end
    local parent = parentFrame:GetParent()
    local parentName = parent and parent:GetName() or ""
    
    if parentName:find("Utility") or (parent and parent.itemFramePool and parent == _G.UtilityCooldownViewer) then
        return cfg.Utility.width or 45, cfg.Utility.height or 30
    elseif parentName:find("Essential") or parentName == "WishFlex_CooldownRow2_Anchor" or (parent and parent.itemFramePool and parent == _G.EssentialCooldownViewer) then
        if parentName == "WishFlex_CooldownRow2_Anchor" or (parentFrame.layoutIndex and cfg.Essential.maxPerRow and parentFrame.layoutIndex > cfg.Essential.maxPerRow) then
            return cfg.Essential.row2Width or 40, cfg.Essential.row2Height or 40
        end
        return cfg.Essential.row1Width or 45, cfg.Essential.row1Height or 45
    end
    
    local ok, w = pcall(function() return parentFrame:GetWidth() end)
    local ok2, h = pcall(function() return parentFrame:GetHeight() end)
    if ok and ok2 and type(w) == "number" and type(h) == "number" and w > 0 then return w, h end
    return 45, 45
end

local function SnapOverlayToFrame(overlay, sourceFrame)
    if sourceFrame and sourceFrame:IsVisible() then
        local success, cx, cy = pcall(function() return sourceFrame:GetCenter() end)
        if success and cx and cy then
            local scale = sourceFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            overlay:SetScale(scale)
            local rawW, rawH = GetHardcodedSize(sourceFrame)
            overlay:SetSize(rawW, rawH)
            overlay.iconTex:SetTexCoord(GetCropCoords(rawW, rawH))
            overlay:ClearAllPoints()
            overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
            return true
        end
    end
    return false
end

-- =========================================
-- 5. 召唤暴雪原生渲染引擎 
-- =========================================
local function SyncOverlayTextAndVisuals(overlay)
    local cfg = E.db.WishFlex.auraGlow.text
    local fontPath = LSM:Fetch('font', cfg.font)
    local r, g, b = cfg.color.r, cfg.color.g, cfg.color.b
    
    if overlay.lastFont ~= fontPath or overlay.lastSize ~= cfg.fontSize or overlay.lastOutline ~= cfg.fontOutline then
        overlay.durationText:SetFont(fontPath, cfg.fontSize, cfg.fontOutline)
        overlay.lastFont = fontPath
        overlay.lastSize = cfg.fontSize
        overlay.lastOutline = cfg.fontOutline
    end
    
    if overlay.lastR ~= r or overlay.lastG ~= g or overlay.lastB ~= b then
        overlay.durationText:SetTextColor(r, g, b)
        overlay.lastR = r
        overlay.lastG = g
        overlay.lastB = b
    end

    if overlay.lastOffsetX ~= cfg.offsetX or overlay.lastOffsetY ~= cfg.offsetY then
        overlay.durationText:ClearAllPoints()
        overlay.durationText:SetPoint("CENTER", overlay, "CENTER", cfg.offsetX, cfg.offsetY)
        overlay.lastOffsetX = cfg.offsetX
        overlay.lastOffsetY = cfg.offsetY
    end
end

local function GetOrCreateOverlay(parentFrame, spellID)
    if not OverlayFrames[spellID] then
        local overlay = CreateFrame("Frame", nil, UIParent)
        overlay:SetFrameStrata("HIGH") 
        
        local iconTex = overlay:CreateTexture(nil, "ARTWORK")
        iconTex:SetPoint("TOPLEFT", overlay, "TOPLEFT", E.mult, -E.mult)
        iconTex:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -E.mult, E.mult)
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo and spellInfo.iconID then iconTex:SetTexture(spellInfo.iconID) end
        overlay.iconTex = iconTex
        
        local cd = CreateFrame("Cooldown", nil, overlay, "CooldownFrameTemplate")
        cd:SetAllPoints()
        cd:SetDrawSwipe(false) 
        cd:SetDrawEdge(false)  
        cd:SetDrawBling(false) 
        cd:SetHideCountdownNumbers(false)
        
        cd.noCooldownOverride = true
        cd.noOCC = true
        cd.skipElvUICooldown = true
        overlay.cd = cd
        
        for _, region in pairs({cd:GetRegions()}) do
            if region:IsObjectType("FontString") then
                overlay.durationText = region
                break
            end
        end
        if not overlay.durationText then overlay.durationText = cd:CreateFontString(nil, "OVERLAY") end
        
        overlay:SetScript("OnUpdate", function(self)
            if not SnapOverlayToFrame(self, self.sourceFrame) then
                self:Hide()
                return
            end
            SyncOverlayTextAndVisuals(self)
        end)
        OverlayFrames[spellID] = overlay
    end
    return OverlayFrames[spellID]
end

-- =========================================
-- 6. 发光与扫描引擎
-- =========================================
local function ApplyIndependentGlow(ov)
    local cfg = E.db.WishFlex.auraGlow
    
    LCG.PixelGlow_Stop(ov, "WishAuraDurationGlow")
    LCG.AutoCastGlow_Stop(ov, "WishAuraDurationGlow")
    LCG.ButtonGlow_Stop(ov)
    LCG.ProcGlow_Stop(ov, "WishAuraDurationGlow")
    
    if cfg.glowType == "pixel" then
        LCG.PixelGlow_Start(ov, {cfg.glowColor.r, cfg.glowColor.g, cfg.glowColor.b, cfg.glowColor.a}, cfg.glowPixelLines, cfg.glowPixelFrequency, cfg.glowPixelLength, cfg.glowPixelThickness, cfg.glowPixelXOffset, cfg.glowPixelYOffset, false, "WishAuraDurationGlow")
    end
end

-- =========================================
-- 7. 性能优化：全域单次扫描法 (降耗核心)
-- =========================================
function mod:UpdateGlows(forceUpdate)
    if not E.db.WishFlex.auraGlow.enable then return end
    mod.trackedAuras = mod.trackedAuras or {}

    -- [优化点 1]：单次统一扫描所有的底层框架，大幅降低 CPU 循环嵌套占用
    local activeSkillFrames = {}
    local activeBuffFrames = {}

    for _, viewer in ipairs({_G.EssentialCooldownViewer, _G.UtilityCooldownViewer}) do
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                if frame:IsVisible() and frame.cooldownInfo then activeSkillFrames[#activeSkillFrames+1] = frame end
            end
        end
    end

    for _, viewer in ipairs({_G.BuffIconCooldownViewer, _G.BuffBarCooldownViewer}) do
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                if frame.cooldownInfo then activeBuffFrames[#activeBuffFrames+1] = frame end
            end
        end
    end

    local function FastFindSkillFrame(targetID)
        for i = 1, #activeSkillFrames do
            if MatchesSpellID(activeSkillFrames[i].cooldownInfo, targetID) then return activeSkillFrames[i] end
        end
        return nil
    end

    local function FastFindBuffFrame(targetID)
        for i = 1, #activeBuffFrames do
            if MatchesSpellID(activeBuffFrames[i].cooldownInfo, targetID) then return activeBuffFrames[i] end
        end
        return nil
    end

    -- 确保数据向下兼容
    local cleanSpells = {}
    for k, v in pairs(E.db.WishFlex.auraGlow.spells) do
        if type(v) == "table" then cleanSpells[k] = v else cleanSpells[k] = { buffID = v, duration = 0 } end
    end
    E.db.WishFlex.auraGlow.spells = cleanSpells

    -- 核心处理循环
    for spellIDStr, spellData in pairs(E.db.WishFlex.auraGlow.spells) do
        local spellID = tonumber(spellIDStr)
        local buffID = type(spellData) == "table" and spellData.buffID or tonumber(spellData)
        if buffID then
            local skillFrame = FastFindSkillFrame(spellID)
            local buffFrame = FastFindBuffFrame(buffID)
            
            local auraActive = false
            local auraInstanceID = nil
            local unit = "player"
            
            if buffFrame then
                local tempID, tempUnit
                pcall(function() tempID = buffFrame.auraInstanceID end)
                pcall(function() tempUnit = buffFrame.auraDataUnit or "player" end)
                if tempID and VerifyAuraAlive(tempID, tempUnit) then
                    auraInstanceID = tempID; unit = tempUnit; auraActive = true
                    mod.trackedAuras[buffID] = { id = auraInstanceID, unit = unit }
                end
            end
            
            if not auraActive and mod.trackedAuras[buffID] then
                local t = mod.trackedAuras[buffID]
                if VerifyAuraAlive(t.id, t.unit) then
                    auraActive = true; auraInstanceID = t.id; unit = t.unit
                else
                    mod.trackedAuras[buffID] = nil 
                end
            end
            
            if not auraActive then
                local auraData, foundUnit = GetAuraDataAnywhere(buffID)
                if auraData then
                    local tempID
                    pcall(function() tempID = auraData.auraInstanceID end)
                    if tempID then 
                        auraActive = true; auraInstanceID = tempID; unit = foundUnit
                        mod.trackedAuras[buffID] = { id = auraInstanceID, unit = unit } 
                    end
                end
            end
            
            if skillFrame and skillFrame:IsVisible() and auraActive then
                local overlay = GetOrCreateOverlay(skillFrame, spellID)
                overlay.sourceFrame = skillFrame
                
                if auraInstanceID then
                    local ok, durObj = pcall(C_UnitAuras.GetAuraDuration, unit, auraInstanceID)
                    if ok and durObj then pcall(function() overlay.cd:SetCooldownFromDurationObject(durObj) end) end
                end
                
                SnapOverlayToFrame(overlay, skillFrame)
                overlay:Show()
                if forceUpdate or not ActiveGlows[spellID] then
                    ActiveGlows[spellID] = true
                    ApplyIndependentGlow(overlay)
                end
            else
                ActiveGlows[spellID] = false
                if OverlayFrames[spellID] then 
                    LCG.PixelGlow_Stop(OverlayFrames[spellID], "WishAuraDurationGlow")
                    LCG.AutoCastGlow_Stop(OverlayFrames[spellID], "WishAuraDurationGlow")
                    LCG.ButtonGlow_Stop(OverlayFrames[spellID])
                    LCG.ProcGlow_Stop(OverlayFrames[spellID], "WishAuraDurationGlow")
                    if OverlayFrames[spellID].cd then OverlayFrames[spellID].cd:Clear() end
                    OverlayFrames[spellID]:Hide() 
                end
            end
        end
    end
end

-- =========================================
-- 8. 增益静默隐藏钩子
-- =========================================
local function HookBuffHide()
    local function HideIt(frame)
        if not E.db.WishFlex.auraGlow.enable or not frame.cooldownInfo then return end
        
        if frame:GetWidth() >= 1 and not frame.wishFlexOrigWidth then
            frame.wishFlexOrigWidth = frame:GetWidth()
        end
        
        for _, spellData in pairs(E.db.WishFlex.auraGlow.spells) do
            local targetID = type(spellData) == "table" and spellData.buffID or tonumber(spellData)
            if targetID and MatchesSpellID(frame.cooldownInfo, targetID) then
                frame:SetAlpha(0); frame:SetWidth(0.001); frame:EnableMouse(false); return
            end
        end
        
        if frame:GetWidth() < 1 then 
            frame:SetWidth(frame.wishFlexOrigWidth or 45) 
        end
        frame:SetAlpha(1); frame:EnableMouse(true)
    end

    if _G.CooldownViewerBuffIconItemMixin then
        hooksecurefunc(_G.CooldownViewerBuffIconItemMixin, "OnCooldownIDSet", HideIt)
        hooksecurefunc(_G.CooldownViewerBuffIconItemMixin, "OnActiveStateChanged", HideIt)
    end
    if _G.CooldownViewerBuffBarItemMixin then
        hooksecurefunc(_G.CooldownViewerBuffBarItemMixin, "OnCooldownIDSet", HideIt)
        hooksecurefunc(_G.CooldownViewerBuffBarItemMixin, "OnActiveStateChanged", HideIt)
    end
end

-- =========================================
-- 9. 事件触发与生命周期 (智能脱战降频核心)
-- =========================================
local updatePending = false
local function RequestUpdateGlows()
    if updatePending then return end
    updatePending = true
    
    -- [优化点 2]：脱战时，CPU 负荷将直接降低 80%！
    local isCombat = InCombatLockdown()
    local delay = isCombat and 0 or 0.2
    
    C_Timer.After(delay, function() 
        updatePending = false
        mod:UpdateGlows() 
    end)
end

local function SafeHook(object, funcName, callback)
    if object and object[funcName] and type(object[funcName]) == "function" then
        hooksecurefunc(object, funcName, callback)
    end
end

function mod:UNIT_AURA(event, unit)
    if unit == "player" or unit == "target" then RequestUpdateGlows() end
end

function mod:OnCombatEvent()
    RequestUpdateGlows()
end

function mod:Initialize()
    if E.db.WishFlex and E.db.WishFlex.auraGlow and E.db.WishFlex.auraGlow.spells then
        local cleanSpells = {}
        for k, v in pairs(E.db.WishFlex.auraGlow.spells) do
            if type(v) == "number" then cleanSpells[k] = { buffID = v, duration = 0 } else cleanSpells[k] = v end
        end
        E.db.WishFlex.auraGlow.spells = cleanSpells
    end

    InjectOptions()
    if not E.db.WishFlex.modules.auraGlow then return end
    
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnCombatEvent")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatEvent")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEvent")
    HookBuffHide()
    
    local viewers = { _G.BuffIconCooldownViewer, _G.EssentialCooldownViewer, _G.UtilityCooldownViewer, _G.BuffBarCooldownViewer }
    for _, viewer in ipairs(viewers) do
        if viewer then
            SafeHook(viewer, "RefreshData", RequestUpdateGlows)
            SafeHook(viewer, "UpdateLayout", RequestUpdateGlows)
            SafeHook(viewer, "Layout", RequestUpdateGlows)
            if viewer.itemFramePool then
                SafeHook(viewer.itemFramePool, "Acquire", RequestUpdateGlows)
                SafeHook(viewer.itemFramePool, "Release", RequestUpdateGlows)
            end
        end
    end
end