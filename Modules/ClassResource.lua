local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WF = E:GetModule('WishFlex')
local CR = WF:NewModule('ClassResource', 'AceEvent-3.0')
local LSM = E.Libs.LSM
local playerClass = select(2, UnitClass("player"))
local hasHealerSpec = (playerClass == "PALADIN" or playerClass == "PRIEST" or playerClass == "SHAMAN" or playerClass == "MONK" or playerClass == "DRUID" or playerClass == "EVOKER")

local defaults = {
    enable = true, alignWithCD = false, widthOffset = 2, width = 250, yOffset = 4, texture = "WishFlex-g1", specConfigs = {},
    power = { enable = true, height = 14, textFormat = "BOTH", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1} },
    -- 针对主资源条引入职业独立的颜色表，杜绝切职业颜色覆盖的问题
    class = { enable = true, height = 12, textFormat = "ABSOLUTE", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, useCustomColor = false, customColor = {r=1, g=0.96, b=0.41}, useCustomColors = {}, customColors = {} },
    tertiary = { enable = true, height = 10, textFormat = "ABSOLUTE", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, useCustomColor = false, customColor = {r=0.4, g=0.8, b=1} },
    mana = { enable = true, height = 10, textFormat = "PERCENT", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, barXOffset = 0, barYOffset = 0 },
}

local DEFAULT_COLOR = {r=1, g=1, b=1}
local POWER_COLORS = { [0]={r=0,g=0.5,b=1}, [1]={r=1,g=0,b=0}, [2]={r=1,g=0.5,b=0.25}, [3]={r=1,g=1,b=0}, [4]={r=1,g=0.96,b=0.41}, [5]={r=0.8,g=0.1,b=0.2}, [7]={r=0.5,g=0.32,b=0.55}, [8]={r=0.3,g=0.52,b=0.9}, [9]={r=0.95,g=0.9,b=0.6}, [11]={r=0,g=0.5,b=1}, [12]={r=0.71,g=1,b=0.92}, [13]={r=0.4,g=0,b=0.8}, [16]={r=0.1,g=0.1,b=0.98}, [17]={r=0.79,g=0.26,b=0.99}, [18]={r=1,g=0.61,b=0}, [19]={r=0.4,g=0.8,b=1} }
local TERTIARY_COLORS = { shaman_apps={r=0,g=0.5,b=1}, hunter_apps={r=0.6,g=0.8,b=0.2}, warrior_apps={r=0.8,g=0.1,b=0.1}, stagger_green={r=0,g=1,b=0.5}, stagger_yellow={r=1,g=1,b=0}, stagger_red={r=1,g=0,b=0}, evoker_dur={r=0.8,g=0.6,b=0.1}, dh_vengeance={r=0.6,g=0.2,b=0.8}, mage_icicles={r=0.4,g=0.8,b=1}, mage_charges={r=1,g=0.5,b=0} }

local function DeepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            DeepMerge(target[k], v)
        else
            if target[k] == nil then target[k] = v end
        end
    end
end

local dbInitialized = false
local function GetDB()
    if not E.db.WishFlex then E.db.WishFlex = {} end
    if type(E.db.WishFlex.classResource) ~= "table" then E.db.WishFlex.classResource = {} end
    if not dbInitialized then
        DeepMerge(E.db.WishFlex.classResource, defaults)
        dbInitialized = true
    end
    return E.db.WishFlex.classResource
end

local function GetCurrentContextID()
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        if formID == 1 then return 1001 elseif formID == 5 then return 1002 elseif formID == 31 then return 1003 elseif formID == 3 or formID == 4 or formID == 27 then return 1004 else return 1000 end
    else
        local specIndex = GetSpecialization()
        return specIndex and GetSpecializationInfo(specIndex) or 0
    end
end

local function GetCurrentSpecConfig(ctxId)
    local db = GetDB()
    ctxId = ctxId or GetCurrentContextID()
    if not db.specConfigs then db.specConfigs = {} end
    if type(db.specConfigs[ctxId]) ~= "table" then db.specConfigs[ctxId] = {} end
    local cfg = db.specConfigs[ctxId]
    if cfg.showPower == nil then cfg.showPower = true end
    if cfg.showClass == nil then cfg.showClass = true end
    if cfg.showTertiary == nil then cfg.showTertiary = true end
    if cfg.showMana == nil then cfg.showMana = false end
    if cfg.textPower == nil then cfg.textPower = true end
    if cfg.textClass == nil then cfg.textClass = true end
    if cfg.textTertiary == nil then cfg.textTertiary = true end
    if cfg.textMana == nil then cfg.textMana = true end
    return cfg
end

local function GetSafeColor(cfg, defColor, isClassBar)
    if cfg then
        if isClassBar then
            if type(cfg.useCustomColors) == "table" and cfg.useCustomColors[playerClass] then
                local cc = type(cfg.customColors) == "table" and cfg.customColors[playerClass]
                if cc and type(cc.r) == "number" then return cc end
            end
        elseif cfg.useCustomColor and type(cfg.customColor) == "table" and type(cfg.customColor.r) == "number" then
            return cfg.customColor
        end
    end
    if type(defColor) == "table" and type(defColor.r) == "number" then return defColor end
    return DEFAULT_COLOR
end

local function GetTargetWidth()
    local db = GetDB()
    if db.alignWithCD and E.db.WishFlex.cdManager and E.db.WishFlex.cdManager.Essential then
        local cdDB = E.db.WishFlex.cdManager.Essential
        local maxPerRow = tonumber(cdDB.maxPerRow) or 7
        local w = tonumber(cdDB.row1Width) or tonumber(cdDB.width) or 45
        local gap = tonumber(cdDB.iconGap) or 2
        return (maxPerRow * w) + ((maxPerRow - 1) * gap) + (tonumber(db.widthOffset) or 2)
    end
    return tonumber(db.width) or 250
end

local function GetPowerColor(pType) return POWER_COLORS[pType] or DEFAULT_COLOR end

local function GetClassResourceData()
    local spec = GetSpecializationInfo(GetSpecialization() or 1)
    local pType = UnitPowerType("player")
    local cc = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass]
    local classColor = cc and {r=cc.r, g=cc.g, b=cc.b} or DEFAULT_COLOR
    
    if playerClass == "ROGUE" then return UnitPower("player", 4), UnitPowerMax("player", 4), classColor, true
    elseif playerClass == "PALADIN" then return UnitPower("player", 9), 5, classColor, true
    elseif playerClass == "WARLOCK" then return UnitPower("player", 7), 5, classColor, true
    elseif playerClass == "MAGE" and spec == 62 then return UnitPower("player", 16), 4, classColor, true
    elseif playerClass == "MONK" and spec == 269 then return UnitPower("player", 12), UnitPowerMax("player", 12), classColor, true
    elseif playerClass == "EVOKER" then return UnitPower("player", 19), 6, classColor, true
    elseif playerClass == "DEATHKNIGHT" then return UnitPower("player", 5), 6, classColor, true
    elseif playerClass == "DRUID" and pType == 3 then return UnitPower("player", 4), 5, classColor, true
    elseif playerClass == "SHAMAN" and spec == 263 then
        local apps = 0
        if C_UnitAuras.GetPlayerAuraBySpellID then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(344179)
            if aura then apps = aura.applications or 1 end
        end
        return apps, 10, classColor, true
    elseif playerClass == "HUNTER" and spec == 255 then
        local apps = 0
        if C_UnitAuras.GetPlayerAuraBySpellID then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(260286)
            if aura then apps = aura.applications or 1 end
        end
        return apps, 3, classColor, true
    elseif playerClass == "WARRIOR" and spec == 72 then
        local apps = 0
        if C_UnitAuras.GetPlayerAuraBySpellID then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(85739) or C_UnitAuras.GetPlayerAuraBySpellID(322166)
            if aura then apps = aura.applications or 1 end
        end
        return apps, 4, classColor, true
    end
    return 0, 0, DEFAULT_COLOR, false
end

local function GetTertiaryResourceData()
    local spec = GetSpecializationInfo(GetSpecialization() or 1)
    
    if playerClass == "MONK" and spec == 268 then
        local stagger = UnitStagger("player") or 0
        local maxHealth = UnitHealthMax("player") or 1
        if maxHealth <= 0 then maxHealth = 1 end
        
        local show = false
        local color = TERTIARY_COLORS.stagger_green
        if stagger > 0 then
            show = true
            local p = stagger / maxHealth
            if p > 0.6 then color = TERTIARY_COLORS.stagger_red
            elseif p > 0.3 then color = TERTIARY_COLORS.stagger_yellow end
        end
        return stagger, maxHealth, color, false, 1, show
        
    elseif playerClass == "EVOKER" and spec == 1473 then
        local remain, dur, show = 0, 10, false
        if C_UnitAuras.GetPlayerAuraBySpellID then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(395296)
            if aura and aura.expirationTime then
                remain = aura.expirationTime - GetTime()
                if remain > 0 then
                    show = true
                    dur = aura.duration > 0 and aura.duration or 10
                else remain = 0 end
            end
        end
        return remain, dur, TERTIARY_COLORS.evoker_dur, true, 1, show
        
    elseif playerClass == "SHAMAN" and spec == 262 then
        local mana = UnitPower("player", 0)
        local maxMana = UnitPowerMax("player", 0)
        return mana, maxMana, GetPowerColor(0), false, 1, (maxMana > 0)
        
    elseif playerClass == "DEMONHUNTER" then
        if spec == 581 then 
            local count = C_Spell.GetSpellCastCount(228477) or 0
            return count, 6, TERTIARY_COLORS.dh_vengeance, false, 6, true
        end
        
    elseif playerClass == "MAGE" then
        if spec == 64 then 
            local icicles = 0
            if C_UnitAuras.GetPlayerAuraBySpellID then
                local aura = C_UnitAuras.GetPlayerAuraBySpellID(205473) or C_UnitAuras.GetPlayerAuraBySpellID(112214)
                if aura then icicles = aura.applications or 1 end
            end
            return icicles, 5, TERTIARY_COLORS.mage_icicles, false, 5, true
        elseif spec == 63 then
            local chargeInfo = C_Spell.GetSpellCharges(108853)
            local cur = chargeInfo and chargeInfo.currentCharges or 0
            return cur, 3, TERTIARY_COLORS.mage_charges, false, 3, true
        end
    end
    return 0, 0, DEFAULT_COLOR, false, 1, false
end

local function GetSelectedSpec()
    return CR.selectedSpecForConfig or GetCurrentContextID()
end

local function InjectOptions()
    local function GetOptionsList()
        local opts = {}
        if playerClass == "DRUID" then
            opts[1000] = "人形态 / 无形态"
            opts[1001] = "猎豹形态"
            opts[1002] = "熊形态"
            opts[1003] = "枭兽形态"
            opts[1004] = "旅行形态"
        else
            local classID = select(3, UnitClass("player"))
            for i = 1, GetNumSpecializationsForClassID(classID) do
                local id, name = GetSpecializationInfoForClassID(classID, i)
                if id and name then opts[id] = name end
            end
            opts[0] = "无专精 / 通用"
        end
        return opts
    end

    if not CR.selectedSpecForConfig then CR.selectedSpecForConfig = GetCurrentContextID() end

    WF.OptionsArgs = WF.OptionsArgs or {}
    WF.OptionsArgs.classResource = {
        order = 15, type = "group", name = "|cff00ffcc职业资源条|r", childGroups = "tab",
        get = function(i) return GetDB()[i[#i]] end,
        set = function(i, v) GetDB()[i[#i]] = v; CR:UpdateLayout() end,
        args = {
            general = {
                order = 1, type = "group", name = "全局排版",
                args = {
                    desc = { order = 1, type = "description", name = "全自动识别当前专精与形态，自动切换法力、连击点、符文、火冲、冰刺等！\n" },
                    enable = { order = 2, type = "toggle", name = "启用模块", get = function() return E.db.WishFlex.modules.classResource end, set = function(_, v) E.db.WishFlex.modules.classResource = v; E:StaticPopup_Show("CONFIG_RL") end },
                    spacer = { order = 3, type = "description", name = " " },
                    alignWithCD = { order = 4, type = "toggle", name = "对齐冷却管理器" },
                    widthOffset = { order = 5, type = "range", name = "边框补偿", min = -10, max = 10, step = 1, disabled = function() return not GetDB().alignWithCD end },
                    width = { order = 6, type = "range", name = "自定义宽度", min = 50, max = 600, step = 1, disabled = function() return GetDB().alignWithCD end },
                    yOffset = { order = 7, type = "range", name = "间距", min = 0, max = 50, step = 1 },
                    texture = { order = 8, type = "select", dialogControl = 'LSM30_Statusbar', name = "全局材质", values = LSM:HashTable("statusbar") },
                }
            },
            specVisibilityTab = {
                order = 2, type = "group", name = "|cff00ff00" .. (playerClass == "DRUID" and "各形态显隐" or "各专精显隐") .. "|r",
                args = {
                    selectSpec = {
                        order = 2, type = "select", name = "当前配置环境",
                        values = GetOptionsList,
                        get = function() return CR.selectedSpecForConfig end,
                        set = function(_, val) CR.selectedSpecForConfig = val; CR:UpdateLayout() end,
                    },
                    spacer = { order = 3, type = "description", name = " \n" },
                    
                    powerHeader = { order = 4, type = "header", name = "能量条 [法力/怒气/能量]" },
                    showPower = { order = 5, type = "toggle", name = "显示进度条", get = function() return GetCurrentSpecConfig(GetSelectedSpec()).showPower end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).showPower = val; CR:UpdateLayout() end },
                    textPower = { order = 6, type = "toggle", name = "显示条内文本", get = function() return GetCurrentSpecConfig(GetSelectedSpec()).textPower end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).textPower = val; CR:UpdateLayout() end },
                    
                    classHeader = { order = 7, type = "header", name = "主资源条 [连击点/圣能/符文]" },
                    showClass = { order = 8, type = "toggle", name = "显示进度条", get = function() return GetCurrentSpecConfig(GetSelectedSpec()).showClass end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).showClass = val; CR:UpdateLayout() end },
                    textClass = { order = 9, type = "toggle", name = "显示条内文本", get = function() return GetCurrentSpecConfig(GetSelectedSpec()).textClass end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).textClass = val; CR:UpdateLayout() end },
                    
                    tertiaryHeader = { order = 10, type = "header", name = "副资源条 [火冲/冰刺/酒池]" },
                    showTertiary = { order = 11, type = "toggle", name = "显示进度条", get = function() return GetCurrentSpecConfig(GetSelectedSpec()).showTertiary end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).showTertiary = val; CR:UpdateLayout() end },
                    textTertiary = { order = 12, type = "toggle", name = "显示条内文本", get = function() return GetCurrentSpecConfig(GetSelectedSpec()).textTertiary end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).textTertiary = val; CR:UpdateLayout() end },
                    
                    manaHeader = { order = 13, type = "header", name = "混合职业专属：额外法力值条", hidden = function() return not hasHealerSpec end },
                    showMana = { order = 14, type = "toggle", name = "显示额外法力条", hidden = function() return not hasHealerSpec end, get = function() return GetCurrentSpecConfig(GetSelectedSpec()).showMana end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).showMana = val; CR:UpdateLayout() end },
                    textMana = { order = 15, type = "toggle", name = "显示条内文本", hidden = function() return not hasHealerSpec end, get = function() return GetCurrentSpecConfig(GetSelectedSpec()).textMana end, set = function(_, val) GetCurrentSpecConfig(GetSelectedSpec()).textMana = val; CR:UpdateLayout() end },
                }
            },
            powerTab = {
                order = 3, type = "group", 
                name = function() return GetCurrentSpecConfig(GetSelectedSpec()).showPower and "能量条" or "|cff888888能量条(已停用)|r" end,
                disabled = function() return not GetCurrentSpecConfig(GetSelectedSpec()).showPower end,
                get = function(i) return GetDB().power[i[#i]] end,
                set = function(i, v) GetDB().power[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    barGroup = {
                        order = 1, type = "group", name = "能量条", guiInline = true,
                        args = {
                            enable = { order = 1, type = "toggle", name = "启用" },
                            height = { order = 2, type = "range", name = "高度", min = 2, max = 50, step = 1 },
                            useCustomColor = { order = 3, type = "toggle", name = "自定义颜色" },
                            customColor = { order = 4, type = "color", name = "颜色", disabled = function() return not GetDB().power.useCustomColor end, get = function() local t = GetDB().power.customColor return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().power.customColor = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                        }
                    },
                    fontGroup = {
                        order = 2, type = "group", name = "文本样式", guiInline = true,
                        args = {
                            font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") },
                            fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 },
                            outline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                            color = { order = 4, type = "color", name = "颜色", get = function() local t = GetDB().power.color return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().power.color = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                        }
                    },
                    layoutGroup = {
                        order = 3, type = "group", name = "文本排版", guiInline = true,
                        args = {
                            textFormat = { order = 1, type = "select", name = "文本格式", values = { ["PERCENT"] = "百分比", ["ABSOLUTE"] = "具体数值", ["BOTH"] = "数值 / 最大值", ["NONE"] = "隐藏" } },
                            xOffset = { order = 2, type = "range", name = "X 偏移", min = -200, max = 200, step = 1 },
                            yOffset = { order = 3, type = "range", name = "Y 偏移", min = -100, max = 100, step = 1 },
                        }
                    }
                }
            },
            classTab = {
                order = 4, type = "group", 
                name = function() return GetCurrentSpecConfig(GetSelectedSpec()).showClass and "主资源条" or "|cff888888主资源条(已停用)|r" end,
                disabled = function() return not GetCurrentSpecConfig(GetSelectedSpec()).showClass end,
                get = function(i) return GetDB().class[i[#i]] end,
                set = function(i, v) GetDB().class[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    barGroup = {
                        order = 1, type = "group", name = "设置", guiInline = true,
                        args = {
                            enable = { order = 1, type = "toggle", name = "启用" },
                            height = { order = 2, type = "range", name = "高度", min = 2, max = 50, step = 1 },
                            useCustomColor = { 
                                order = 3, type = "toggle", name = "独立自定义颜色", 
                                desc = "开启后，主资源条的自定义颜色将仅对【当前登录的职业】生效，切换其他职业时互不干扰。",
                                get = function() 
                                    local db = GetDB().class
                                    if type(db.useCustomColors) ~= "table" then db.useCustomColors = {} end
                                    return db.useCustomColors[playerClass] or false 
                                end, 
                                set = function(_, v) 
                                    local db = GetDB().class
                                    if type(db.useCustomColors) ~= "table" then db.useCustomColors = {} end
                                    db.useCustomColors[playerClass] = v
                                    CR:UpdateLayout() 
                                end 
                            },
                            customColor = { 
                                order = 4, type = "color", name = "颜色", 
                                disabled = function() 
                                    local db = GetDB().class
                                    return not (type(db.useCustomColors) == "table" and db.useCustomColors[playerClass]) 
                                end, 
                                get = function() 
                                    local db = GetDB().class
                                    if type(db.customColors) ~= "table" then db.customColors = {} end
                                    local t = db.customColors[playerClass]
                                    if not t then 
                                        local cc = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass]
                                        t = cc and {r=cc.r, g=cc.g, b=cc.b} or {r=1, g=1, b=1}
                                    end
                                    return t.r, t.g, t.b 
                                end, 
                                set = function(_, r, g, b) 
                                    local db = GetDB().class
                                    if type(db.customColors) ~= "table" then db.customColors = {} end
                                    db.customColors[playerClass] = {r=r,g=g,b=b}
                                    CR:UpdateLayout() 
                                end 
                            },
                        }
                    },
                    fontGroup = {
                        order = 2, type = "group", name = "文本样式", guiInline = true,
                        args = {
                            font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") },
                            fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 },
                            outline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                            color = { order = 4, type = "color", name = "颜色", get = function() local t = GetDB().class.color return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().class.color = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                        }
                    },
                    layoutGroup = {
                        order = 3, type = "group", name = "文本排版", guiInline = true,
                        args = {
                            textFormat = { order = 1, type = "select", name = "文本格式", values = { ["PERCENT"] = "百分比", ["ABSOLUTE"] = "具体数值", ["BOTH"] = "数值 / 最大值", ["NONE"] = "隐藏" } },
                            xOffset = { order = 2, type = "range", name = "X 偏移", min = -200, max = 200, step = 1 },
                            yOffset = { order = 3, type = "range", name = "Y 偏移", min = -100, max = 100, step = 1 },
                        }
                    }
                }
            },
            tertiaryTab = {
                order = 5, type = "group", 
                name = function() return GetCurrentSpecConfig(GetSelectedSpec()).showTertiary and "副资源条" or "|cff888888副资源条(已停用)|r" end,
                disabled = function() return not GetCurrentSpecConfig(GetSelectedSpec()).showTertiary end,
                get = function(i) return GetDB().tertiary[i[#i]] end,
                set = function(i, v) GetDB().tertiary[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    barGroup = {
                        order = 1, type = "group", name = "设置", guiInline = true,
                        args = {
                            enable = { order = 1, type = "toggle", name = "启用" },
                            height = { order = 2, type = "range", name = "高度", min = 2, max = 50, step = 1 },
                            useCustomColor = { order = 3, type = "toggle", name = "自定义颜色" },
                            customColor = { order = 4, type = "color", name = "颜色", disabled = function() return not GetDB().tertiary.useCustomColor end, get = function() local t = GetDB().tertiary.customColor return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().tertiary.customColor = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                        }
                    },
                    fontGroup = {
                        order = 2, type = "group", name = "文本样式", guiInline = true,
                        args = {
                            font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") },
                            fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 },
                            outline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                            color = { order = 4, type = "color", name = "颜色", get = function() local t = GetDB().tertiary.color return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().tertiary.color = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                        }
                    },
                    layoutGroup = {
                        order = 3, type = "group", name = "文本排版", guiInline = true,
                        args = {
                            textFormat = { order = 1, type = "select", name = "文本格式", values = { ["PERCENT"] = "百分比", ["ABSOLUTE"] = "具体数值", ["BOTH"] = "数值 / 最大值", ["NONE"] = "隐藏" } },
                            xOffset = { order = 2, type = "range", name = "X 偏移", min = -200, max = 200, step = 1 },
                            yOffset = { order = 3, type = "range", name = "Y 偏移", min = -100, max = 100, step = 1 },
                        }
                    }
                }
            },
            manaTab = {
                order = 6, type = "group", 
                name = function() return GetCurrentSpecConfig(GetSelectedSpec()).showMana and "专属法力条" or "|cff888888专属法力条(已停用)|r" end,
                hidden = function() return not hasHealerSpec end,
                disabled = function() return not GetCurrentSpecConfig(GetSelectedSpec()).showMana end,
                get = function(i) return GetDB().mana[i[#i]] end,
                set = function(i, v) GetDB().mana[i[#i]] = v; CR:UpdateLayout() end,
                args = {
                    barGroup = {
                        order = 1, type = "group", name = "设置", guiInline = true,
                        args = {
                            desc = { order = 1, type = "description", name = "注意：法力值将强制使用百分比显示。\n|cff00ff00此条拥有独立的锚点，可单独解锁移动！|r\n" },
                            enable = { order = 2, type = "toggle", name = "全局启用开关" },
                            height = { order = 3, type = "range", name = "高度", min = 2, max = 50, step = 1 },
                            barXOffset = { order = 4, type = "range", name = "X 偏移", min = -500, max = 500, step = 1 },
                            barYOffset = { order = 5, type = "range", name = "Y 偏移", min = -500, max = 500, step = 1 },
                            useCustomColor = { order = 6, type = "toggle", name = "自定义颜色" },
                            customColor = { order = 7, type = "color", name = "颜色", disabled = function() return not GetDB().mana.useCustomColor end, get = function() local t = GetDB().mana.customColor return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().mana.customColor = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                        }
                    },
                    fontGroup = {
                        order = 2, type = "group", name = "文本样式", guiInline = true,
                        args = {
                            font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") },
                            fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 40, step = 1 },
                            outline = { order = 3, type = "select", name = "描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
                            color = { order = 4, type = "color", name = "颜色", get = function() local t = GetDB().mana.color return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().mana.color = {r=r,g=g,b=b}; CR:UpdateLayout() end },
                        }
                    },
                    layoutGroup = {
                        order = 3, type = "group", name = "文本排版", guiInline = true,
                        args = {
                            textFormat = { order = 1, type = "select", name = "文本格式", values = { ["PERCENT"] = "百分比", ["ABSOLUTE"] = "具体数值", ["BOTH"] = "数值 / 最大值", ["NONE"] = "隐藏" } },
                            xOffset = { order = 2, type = "range", name = "X 偏移", min = -200, max = 200, step = 1 },
                            yOffset = { order = 3, type = "range", name = "Y 偏移", min = -100, max = 100, step = 1 },
                        }
                    }
                }
            }
        }
    }
end

function CR:UpdateDividers(bar, maxVal)
    bar.dividers = bar.dividers or {}
    local numMax = tonumber(maxVal) or 1
    if numMax <= 0 then numMax = 1 end
    if numMax > 20 then numMax = 20 end 

    local width = bar:GetWidth() or 250
    if bar._lastDividerMax == numMax and bar._lastDividerWidth == width then return end
    bar._lastDividerMax = numMax
    bar._lastDividerWidth = width

    local numDividers = numMax > 1 and (numMax - 1) or 0
    local segWidth = width / numMax

    for i = 1, numDividers do
        if not bar.dividers[i] then
            local tex = bar.textFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetColorTexture(0, 0, 0, 1) 
            tex:SetWidth(1)                 
            bar.dividers[i] = tex
        end
        bar.dividers[i]:ClearAllPoints()
        bar.dividers[i]:SetPoint("TOPLEFT", bar.textFrame, "TOPLEFT", segWidth * i, 0)
        bar.dividers[i]:SetPoint("BOTTOMLEFT", bar.textFrame, "BOTTOMLEFT", segWidth * i, 0)
        bar.dividers[i]:Show()
    end
    for i = numDividers + 1, #bar.dividers do if bar.dividers[i] then bar.dividers[i]:Hide() end end
end

-- 彻底移除了 pcall 的内联安全格式化，杜绝了每秒几十次的闭包创建
local function FormatSafeText(bar, textCfg, current, maxVal, isTime, pType, showText)
    if not bar.text or textCfg.textFormat == "NONE" or not showText then 
        if bar.text and bar.text:IsShown() then bar.text:Hide() end
        return 
    end
    if not bar.text:IsShown() then bar.text:Show() end

    local fontPath = LSM:Fetch("font", textCfg.font) or E.media.normFont
    local fontSize = tonumber(textCfg.fontSize) or 12
    local fontOutline = textCfg.outline or "OUTLINE"
    if bar._lastFont ~= fontPath or bar._lastSize ~= fontSize or bar._lastOutline ~= fontOutline then
        bar.text:FontTemplate(fontPath, fontSize, fontOutline)
        bar._lastFont = fontPath; bar._lastSize = fontSize; bar._lastOutline = fontOutline
    end
    
    local c = textCfg.color or DEFAULT_COLOR
    if bar._lastColorR ~= c.r or bar._lastColorG ~= c.g or bar._lastColorB ~= c.b then
        bar.text:SetTextColor(c.r, c.g, c.b)
        bar._lastColorR = c.r; bar._lastColorG = c.g; bar._lastColorB = c.b
    end

    local ox = tonumber(textCfg.xOffset) or 0
    local oy = tonumber(textCfg.yOffset) or 0
    if bar._lastOffsetX ~= ox or bar._lastOffsetY ~= oy then
        bar.text:ClearAllPoints()
        bar.text:SetPoint("CENTER", bar.textFrame, "CENTER", ox, oy)
        bar._lastOffsetX = ox; bar._lastOffsetY = oy
    end
    
    local newText = ""
    local cVal = current or 0
    local mVal = maxVal or 1

    if isTime then
        newText = string.format("%.1f", cVal)
    elseif pType == 0 then
        local scale = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or 100
        local perc = UnitPowerPercent("player", pType, true, scale) or 0
        newText = string.format("%.0f", perc)
    elseif textCfg.textFormat == "PERCENT" then
        if pType then
            local scale = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or 100
            local perc = UnitPowerPercent("player", pType, true, scale) or 0
            newText = string.format("%.0f", perc)
        else
            local p = 0
            if mVal > 0 then p = (cVal / mVal) * 100 end
            newText = string.format("%.0f", p)
        end
    elseif textCfg.textFormat == "ABSOLUTE" then
        newText = (type(AbbreviateNumbers) == "function") and AbbreviateNumbers(cVal) or tostring(cVal)
    else
        local curStr = (type(AbbreviateNumbers) == "function") and AbbreviateNumbers(cVal) or tostring(cVal)
        local maxStr = (type(AbbreviateNumbers) == "function") and AbbreviateNumbers(mVal) or tostring(mVal)
        newText = curStr .. " / " .. maxStr
    end

    if bar._lastText ~= newText then
        bar._lastText = newText
        bar.text:SetText(newText)
    end
end

function CR:UpdateLayout()
    self:WakeUp() -- 任何布局变动直接唤醒渲染循环
    if not self.anchor then return end
    local db = GetDB()
    local currentContextID = GetCurrentContextID()
    local specCfg = GetCurrentSpecConfig(currentContextID)
    self.cachedSpecCfg = specCfg -- 全局缓存配置项

    local tex = LSM:Fetch("statusbar", db.texture) or E.media.normTex or [[Interface\TargetingFrame\UI-StatusBar]]
    local targetWidth = GetTargetWidth()
    local totalHeight = 0
    local lastBar = nil
    
    local function AnchorBar(bar, height, isShown)
        bar:ClearAllPoints()
        if isShown then
            bar.isForceHidden = false 
            bar:SetSize(targetWidth, tonumber(height) or 14)
            if not lastBar then bar:SetPoint("BOTTOM", self.anchor, "BOTTOM", 0, 0)
            else bar:SetPoint("BOTTOM", lastBar, "TOP", 0, tonumber(db.yOffset) or 4); totalHeight = totalHeight + (tonumber(db.yOffset) or 4) end
            
            bar.statusBar:SetStatusBarTexture(tex)
            bar:Show()
            totalHeight = totalHeight + (tonumber(height) or 14)
            lastBar = bar
        else
            bar.isForceHidden = true 
            bar:Hide()
        end
    end

    local pType = UnitPowerType("player")
    local pMax = UnitPowerMax("player", pType)
    self.showPower = db.power.enable and pMax > 0 and specCfg.showPower
    local _, _, _, hasClassDef = GetClassResourceData()
    self.showClass = db.class.enable and hasClassDef and specCfg.showClass
    local _, _, _, _, _, tShouldShow = GetTertiaryResourceData()
    self.showTertiary = db.tertiary.enable and tShouldShow and specCfg.showTertiary
    local manaMax = UnitPowerMax("player", 0)
    self.showMana = hasHealerSpec and db.mana.enable and manaMax > 0 and specCfg.showMana

    AnchorBar(self.powerBar, db.power.height, self.showPower)
    AnchorBar(self.classBar, db.class.height, self.showClass)
    AnchorBar(self.tertiaryBar, db.tertiary.height, self.showTertiary)
    self.anchor:SetSize(targetWidth, math.max(10, totalHeight))

    if self.showMana and self.manaAnchor then
        self.manaBar.isForceHidden = false
        self.manaBar:SetSize(targetWidth, tonumber(db.mana.height) or 10)
        self.manaBar:ClearAllPoints()
        local bx, by = tonumber(db.mana.barXOffset) or 0, tonumber(db.mana.barYOffset) or 0
        self.manaBar:SetPoint("CENTER", self.manaAnchor, "CENTER", bx, by)
        self.manaBar.statusBar:SetStatusBarTexture(tex)
        self.manaBar:Show()
        self.manaAnchor:SetSize(targetWidth, tonumber(db.mana.height) or 10)
    elseif self.manaBar then
        self.manaBar.isForceHidden = true
        self.manaBar:Hide()
    end
    
    self:DynamicTick()
end

function CR:DynamicTick()
    if not self.anchor then return end
    local db = GetDB()
    local specCfg = self.cachedSpecCfg or GetCurrentSpecConfig(GetCurrentContextID())
    self.hasActiveTimer = false

    if self.showPower then
        local pType = UnitPowerType("player")
        local pMax = UnitPowerMax("player", pType)
        if pMax <= 0 then pMax = 1 end
        local pCurr = UnitPower("player", pType)
        local pColor = GetSafeColor(db.power, GetPowerColor(pType), false)
        self.powerBar.statusBar:SetMinMaxValues(0, pMax)
        self.powerBar.statusBar:SetValue(pCurr)
        self.powerBar.statusBar:SetStatusBarColor(pColor.r, pColor.g, pColor.b)
        self:UpdateDividers(self.powerBar, 1)
        FormatSafeText(self.powerBar, db.power, pCurr, pMax, false, pType, specCfg.textPower)
    end

    if self.showClass then
        local cCurr, cMax, cDefColor = GetClassResourceData()
        if cMax <= 0 then cMax = 1 end
        local cColor = GetSafeColor(db.class, cDefColor, true)
        self.classBar.statusBar:SetMinMaxValues(0, cMax)
        self.classBar.statusBar:SetValue(cCurr)
        self.classBar.statusBar:SetStatusBarColor(cColor.r, cColor.g, cColor.b)
        self:UpdateDividers(self.classBar, cMax)
        FormatSafeText(self.classBar, db.class, cCurr, cMax, false, nil, specCfg.textClass)
    end
    
    local tCurr, tMax, tDefColor, tIsTime, tSegments, tShouldShow = GetTertiaryResourceData()
    local newShowTertiary = db.tertiary.enable and tShouldShow and specCfg.showTertiary
    if self.showTertiary ~= newShowTertiary then 
        self.showTertiary = newShowTertiary
        self:UpdateLayout() 
        return
    end
    
    if self.showTertiary then
        if tIsTime and tShouldShow then self.hasActiveTimer = true end
        if tMax <= 0 then tMax = 1 end
        local tColor = GetSafeColor(db.tertiary, tDefColor, false)
        self.tertiaryBar.statusBar:SetMinMaxValues(0, tMax)
        self.tertiaryBar.statusBar:SetValue(tCurr)
        self.tertiaryBar.statusBar:SetStatusBarColor(tColor.r, tColor.g, tColor.b)
        self:UpdateDividers(self.tertiaryBar, tSegments)
        local isEleMana = (playerClass == "SHAMAN" and GetSpecializationInfo(GetSpecialization() or 1) == 262)
        FormatSafeText(self.tertiaryBar, db.tertiary, tCurr, tMax, tIsTime, isEleMana and 0 or nil, specCfg.textTertiary)
    end
    
    if self.showMana then
        local mMax = UnitPowerMax("player", 0)
        if mMax <= 0 then mMax = 1 end
        local mCurr = UnitPower("player", 0)
        local mColor = GetSafeColor(db.mana, POWER_COLORS[0], false)
        self.manaBar.statusBar:SetMinMaxValues(0, mMax)
        self.manaBar.statusBar:SetValue(mCurr)
        self.manaBar.statusBar:SetStatusBarColor(mColor.r, mColor.g, mColor.b)
        self:UpdateDividers(self.manaBar, 1)
        FormatSafeText(self.manaBar, db.mana, mCurr, mMax, false, 0, specCfg.textMana)
    end
end

function CR:CreateBarContainer(name, parent)
    local bar = CreateFrame("Frame", name, parent, "BackdropTemplate")
    bar:SetTemplate("Transparent")
    local sb = CreateFrame("StatusBar", nil, bar)
    sb:SetInside(bar)
    bar.statusBar = sb
    local textFrame = CreateFrame("Frame", nil, bar)
    textFrame:SetAllPoints(bar)
    textFrame:SetFrameLevel(bar:GetFrameLevel() + 10)
    bar.textFrame = textFrame
    bar.text = textFrame:CreateFontString(nil, "OVERLAY") 
    return bar
end

-- 唤醒引擎：响应所有的战斗和资源变化事件
function CR:WakeUp(event, unit)
    if (event == "UNIT_AURA" or event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT") and unit ~= "player" then return end
    self.idleTimer = 0
    self.sleepMode = false
end

function CR:OnContextChanged()
    self.selectedSpecForConfig = GetCurrentContextID()
    self.cachedSpecCfg = GetCurrentSpecConfig(self.selectedSpecForConfig)
    self:UpdateLayout()
end

function CR:Initialize()
    GetDB() 
    InjectOptions()
    
    if not E.db.WishFlex.modules.classResource then return end
    
    self.anchor = CreateFrame("Frame", "WishFlex_ClassResourceAnchor", E.UIParent)
    self.anchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, -180)
    E:CreateMover(self.anchor, "WishFlexClassResourceMover", "WishFlex: 职业资源条", nil, nil, nil, "ALL,WISHFLEX")

    self.manaAnchor = CreateFrame("Frame", "WishFlex_ManaBarAnchor", E.UIParent)
    self.manaAnchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, -220)
    E:CreateMover(self.manaAnchor, "WishFlexManaBarMover", "WishFlex: 专属法力条", nil, nil, nil, "ALL,WISHFLEX")

    self.powerBar = self:CreateBarContainer("WishFlex_PowerBar", self.anchor)
    self.classBar = self:CreateBarContainer("WishFlex_ClassBar", self.anchor)
    self.tertiaryBar = self:CreateBarContainer("WishFlex_TertiaryBar", self.anchor)
    self.manaBar = self:CreateBarContainer("WishFlex_ManaBar", self.manaAnchor)
    
    self.showPower, self.showClass, self.showTertiary, self.showMana = false, false, false, false
    
    -- 睡眠引擎状态控制
    self.idleTimer = 0
    self.sleepMode = false
    self.hasActiveTimer = false
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateLayout")
    self:RegisterEvent("UNIT_DISPLAYPOWER", "UpdateLayout")
    self:RegisterEvent("UNIT_MAXPOWER", "UpdateLayout")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnContextChanged")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "OnContextChanged")
    
    -- 高优打断睡眠事件
    self:RegisterEvent("UNIT_POWER_UPDATE", "WakeUp")
    self:RegisterEvent("UNIT_POWER_FREQUENT", "WakeUp")
    self:RegisterEvent("UNIT_AURA", "WakeUp")
    self:RegisterEvent("SPELL_UPDATE_CHARGES", "WakeUp")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "WakeUp")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "WakeUp")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "WakeUp")
    
    CR:OnContextChanged()
    
    local ticker = 0
    self.anchor:SetScript("OnUpdate", function(_, elapsed)
        if CR.sleepMode then return end
        
        ticker = ticker + elapsed
        local interval = InCombatLockdown() and 0.05 or 0.2
        if ticker >= interval then
            ticker = 0
            CR:DynamicTick()
            
            -- 脱战且发呆两秒后（并且当前没有运行中的倒计时），进入 0CPU 深度休眠
            if not InCombatLockdown() then
                CR.idleTimer = (CR.idleTimer or 0) + interval
                if CR.idleTimer >= 2 and not CR.hasActiveTimer then
                    CR.sleepMode = true
                end
            else
                CR.idleTimer = 0
            end
        end
    end)
end