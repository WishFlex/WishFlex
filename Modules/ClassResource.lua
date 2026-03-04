local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WF = E:GetModule('WishFlex')
local CR = WF:NewModule('ClassResource', 'AceEvent-3.0')
local LSM = E.Libs.LSM
local playerClass = select(2, UnitClass("player"))
local hasHealerSpec = (playerClass == "PALADIN" or playerClass == "PRIEST" or playerClass == "SHAMAN" or playerClass == "MONK" or playerClass == "DRUID" or playerClass == "EVOKER")

local defaults = {
    enable = true, 
    alignWithCD = false, 
    widthOffset = 2,     
    width = 250,              
    yOffset = 4,              
    texture = "WishFlex-g1", 
    specConfigs = {},

    power = { enable = true, height = 14, textFormat = "BOTH", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1} },
    class = { enable = true, height = 12, textFormat = "ABSOLUTE", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, useCustomColor = false, customColor = {r=1, g=0.96, b=0.41} },
    tertiary = { enable = true, height = 10, textFormat = "ABSOLUTE", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, useCustomColor = false, customColor = {r=0.4, g=0.8, b=1} },
    mana = { enable = true, height = 10, textFormat = "PERCENT", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, barXOffset = 0, barYOffset = 0 },
}

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

local function GetDB()
    if not E.db.WishFlex then E.db.WishFlex = {} end
    if type(E.db.WishFlex.classResource) ~= "table" then E.db.WishFlex.classResource = {} end
    local db = E.db.WishFlex.classResource
    DeepMerge(db, defaults)
    return db
end

local function GetCurrentContextID()
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        if formID == 1 then return 1001
        elseif formID == 5 then return 1002
        elseif formID == 31 then return 1003
        elseif formID == 3 or formID == 4 or formID == 27 then return 1004
        else return 1000 end
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

local function GetSafeColor(cfg, defColor)
    if cfg and cfg.useCustomColor and type(cfg.customColor) == "table" and type(cfg.customColor.r) == "number" then
        return cfg.customColor
    end
    if type(defColor) == "table" and type(defColor.r) == "number" then return defColor end
    return {r=1, g=1, b=1}
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
                            useCustomColor = { order = 3, type = "toggle", name = "自定义颜色" },
                            customColor = { order = 4, type = "color", name = "颜色", disabled = function() return not GetDB().class.useCustomColor end, get = function() local t = GetDB().class.customColor return t.r, t.g, t.b end, set = function(_, r, g, b) GetDB().class.customColor = {r=r,g=g,b=b}; CR:UpdateLayout() end },
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

-- ==========================================
-- 4. 颜色与宽度解析
-- ==========================================
local function GetPowerColor(pType)
    local colors = {
        [0] = {0, 0.5, 1},       -- Mana
        [1] = {1, 0, 0},         -- Rage
        [2] = {1, 0.5, 0.25},    -- Focus
        [3] = {1, 1, 0},         -- Energy
        [4] = {1, 0.96, 0.41},   -- Combo Points
        [5] = {0.8, 0.1, 0.2},   -- Runes
        [7] = {0.5, 0.32, 0.55}, -- Soul Shards
        [8] = {0.3, 0.52, 0.9},  -- Lunar Power
        [9] = {0.95, 0.9, 0.6},  -- Holy Power
        [11]= {0, 0.5, 1},       -- Maelstrom
        [12]= {0.71, 1, 0.92},   -- Chi
        [13]= {0.4, 0, 0.8},     -- Insanity
        [16]= {0.1, 0.1, 0.98},  -- Arcane Charges
        [17]= {0.79, 0.26, 0.99},-- Fury
        [18]= {1, 0.61, 0},      -- Pain
        [19]= {0.4, 0.8, 1},     -- Essence
    }
    local c = colors[pType] or {1, 1, 1}
    return {r = c[1], g = c[2], b = c[3]}
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

local function GetClassResourceData()
    local spec = GetSpecializationInfo(GetSpecialization() or 1)
    local pType = UnitPowerType("player")
    
    if playerClass == "ROGUE" then return UnitPower("player", 4), UnitPowerMax("player", 4), GetPowerColor(4), true
    elseif playerClass == "PALADIN" then return UnitPower("player", 9), 5, GetPowerColor(9), true
    elseif playerClass == "WARLOCK" then return UnitPower("player", 7), 5, GetPowerColor(7), true
    elseif playerClass == "MAGE" and spec == 62 then return UnitPower("player", 16), 4, GetPowerColor(16), true
    elseif playerClass == "MONK" and spec == 269 then return UnitPower("player", 12), UnitPowerMax("player", 12), GetPowerColor(12), true
    elseif playerClass == "EVOKER" then return UnitPower("player", 19), 6, GetPowerColor(19), true
    elseif playerClass == "DEATHKNIGHT" then return UnitPower("player", 5), 6, GetPowerColor(5), true
    elseif playerClass == "DRUID" and pType == 3 then return UnitPower("player", 4), 5, GetPowerColor(4), true
    elseif playerClass == "SHAMAN" and spec == 263 then
        local apps = 0
        if C_UnitAuras.GetPlayerAuraBySpellID then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(344179)
            if aura then apps = aura.applications or 1 end
        end
        return apps, 10, {r=0, g=0.5, b=1}, true
    elseif playerClass == "HUNTER" and spec == 255 then
        local apps = 0
        if C_UnitAuras.GetPlayerAuraBySpellID then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(260286)
            if aura then apps = aura.applications or 1 end
        end
        return apps, 3, {r=0.6, g=0.8, b=0.2}, true
    elseif playerClass == "WARRIOR" and spec == 72 then
        local apps = 0
        if C_UnitAuras.GetPlayerAuraBySpellID then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(85739) or C_UnitAuras.GetPlayerAuraBySpellID(322166)
            if aura then apps = aura.applications or 1 end
        end
        return apps, 4, {r=0.8, g=0.1, b=0.1}, true
    end
    
    return 0, 0, {r=1,g=1,b=1}, false
end

local function GetTertiaryResourceData()
    local spec = GetSpecializationInfo(GetSpecialization() or 1)
    
    if playerClass == "MONK" and spec == 268 then
        local stagger, maxHealth = 0, 1
        pcall(function() stagger = UnitStagger("player") or 0; maxHealth = UnitHealthMax("player") or 1 end)
        if maxHealth <= 0 then maxHealth = 1 end
        
        local show = false
        local color = {r=0, g=1, b=0.5}
        if stagger > 0 then
            show = true
            local p = stagger / maxHealth
            if p > 0.6 then color = {r=1, g=0, b=0}
            elseif p > 0.3 then color = {r=1, g=1, b=0} end
        end
        return stagger, maxHealth, color, false, 1, show
        
    elseif playerClass == "EVOKER" and spec == 1473 then
        local remain, dur = 0, 10
        local show = false
        if C_UnitAuras.GetPlayerAuraBySpellID then
            pcall(function()
                local aura = C_UnitAuras.GetPlayerAuraBySpellID(395296)
                if aura and aura.expirationTime then
                    remain = aura.expirationTime - GetTime()
                    if remain > 0 then
                        show = true
                        dur = aura.duration > 0 and aura.duration or 10
                    else remain = 0 end
                end
            end)
        end
        return remain, dur, {r=0.8, g=0.6, b=0.1}, true, 1, show
        
    elseif playerClass == "SHAMAN" and spec == 262 then
        local mana = UnitPower("player", 0)
        local maxMana = UnitPowerMax("player", 0)
        return mana, maxMana, GetPowerColor(0), false, 1, (maxMana > 0)
        
    elseif playerClass == "DEMONHUNTER" then
        if spec == 581 then 
            local count = 0
            pcall(function() count = C_Spell.GetSpellCastCount(228477); if not count then count = 0 end end)
            return count, 6, {r=0.6, g=0.2, b=0.8}, false, 6, true
        else 
            local apps = 0
            local show = false
            local maxStacks = 50 
            pcall(function()
                local aura = nil
                if C_UnitAuras.GetPlayerAuraBySpellID then
                    aura = C_UnitAuras.GetPlayerAuraBySpellID(1225789) or C_UnitAuras.GetPlayerAuraBySpellID(1227702)
                end
                if not aura and AuraUtil and AuraUtil.FindAuraByName then
                    aura = AuraUtil.FindAuraByName("虚空变形", "player", "HELPFUL")
                end
                if aura then 
                    apps = (aura.applications and aura.applications > 0) and aura.applications or 1
                    show = true
                end
                if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(1247534) then
                    maxStacks = 35
                end
            end)
            return apps, maxStacks, {r=0.5, g=0.1, b=0.8}, false, 1, show
        end
        
    elseif playerClass == "MAGE" then
        if spec == 64 then 
            local icicles = 0
            if C_UnitAuras.GetPlayerAuraBySpellID then
                pcall(function()
                    local aura = C_UnitAuras.GetPlayerAuraBySpellID(205473) or C_UnitAuras.GetPlayerAuraBySpellID(112214)
                    if aura then icicles = aura.applications or 1 end
                end)
            end
            return icicles, 5, {r=0.4, g=0.8, b=1}, false, 5, true
            
        elseif spec == 63 then
            local cur, maxVal = 0, 3
            pcall(function()
                local chargeInfo = C_Spell.GetSpellCharges(108853)
                if chargeInfo then cur = chargeInfo.currentCharges end
            end)
            return cur, maxVal, {r=1, g=0.5, b=0}, false, maxVal, true
        end
    end
    
    return 0, 0, {r=1,g=1,b=1}, false, 1, false
end

function CR:UpdateDividers(bar, maxVal)
    bar.dividers = bar.dividers or {}
    local numMax = tonumber(maxVal) or 1
    if numMax <= 0 then numMax = 1 end
    if numMax > 20 then numMax = 20 end 

    local numDividers = numMax > 1 and (numMax - 1) or 0
    local width = bar:GetWidth() or 250
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

local function FormatSafeText(bar, textCfg, current, maxVal, isTime, pType, showText)
    if not bar.text or textCfg.textFormat == "NONE" or not showText then 
        if bar.text then bar.text:Hide() end
        return 
    end
    
    bar.text:Show()
    local fontPath = LSM:Fetch("font", textCfg.font) or E.media.normFont
    bar.text:FontTemplate(fontPath, tonumber(textCfg.fontSize) or 12, textCfg.outline or "OUTLINE")
    
    local c = textCfg.color or {r=1, g=1, b=1}
    bar.text:SetTextColor(c.r, c.g, c.b)
    bar.text:ClearAllPoints()
    bar.text:SetPoint("CENTER", bar.textFrame, "CENTER", tonumber(textCfg.xOffset) or 0, tonumber(textCfg.yOffset) or 0)
    
    pcall(function()
        if isTime then
            bar.text:SetFormattedText("%.1f", current)
            return
        end
        
        if pType == 0 then
            local scale = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or 100
            local perc = UnitPowerPercent("player", pType, true, scale)
            bar.text:SetFormattedText("%.0f", perc or 0)
            return
        end
        
        if textCfg.textFormat == "PERCENT" then
            if pType then
                local scale = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or 100
                local perc = UnitPowerPercent("player", pType, true, scale)
                bar.text:SetFormattedText("%.0f", perc or 0)
            else
                local p = 0
                if type(maxVal) == "number" and maxVal > 0 then p = (current / maxVal) * 100 end
                bar.text:SetFormattedText("%.0f", p)
            end
        elseif textCfg.textFormat == "ABSOLUTE" then
            if type(AbbreviateNumbers) == "function" then bar.text:SetFormattedText("%s", AbbreviateNumbers(current))
            else bar.text:SetFormattedText("%s", current) end
        else
            if type(AbbreviateNumbers) == "function" then bar.text:SetFormattedText("%s / %s", AbbreviateNumbers(current), AbbreviateNumbers(maxVal))
            else bar.text:SetFormattedText("%s / %s", current, maxVal) end
        end
    end)
end

function CR:UpdateLayout()
    if not self.anchor then return end
    local db = GetDB()
    local currentContextID = GetCurrentContextID()
    local specCfg = GetCurrentSpecConfig(currentContextID)

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
        
        local bx = tonumber(db.mana.barXOffset) or 0
        local by = tonumber(db.mana.barYOffset) or 0
        self.manaBar:SetPoint("CENTER", self.manaAnchor, "CENTER", bx, by)
        
        self.manaBar.statusBar:SetStatusBarTexture(tex)
        self.manaBar:Show()
        self.manaAnchor:SetSize(targetWidth, tonumber(db.mana.height) or 10)
    elseif self.manaBar then
        self.manaBar.isForceHidden = true
        self.manaBar:Hide()
    end
end

function CR:DynamicTick()
    if not self.anchor then return end
    local db = GetDB()
    local specCfg = GetCurrentSpecConfig(GetCurrentContextID())

    pcall(function()
        if self.showPower then
            local pType = UnitPowerType("player")
            local pMax = UnitPowerMax("player", pType)
            if pMax <= 0 then pMax = 1 end
            local pCurr = UnitPower("player", pType)
            local pColor = GetSafeColor(db.power, GetPowerColor(pType))
            
            self.powerBar.statusBar:SetMinMaxValues(0, pMax)
            self.powerBar.statusBar:SetValue(pCurr)
            self.powerBar.statusBar:SetStatusBarColor(pColor.r, pColor.g, pColor.b)
            self:UpdateDividers(self.powerBar, 1)
            FormatSafeText(self.powerBar, db.power, pCurr, pMax, false, pType, specCfg.textPower)
        end
    end)

    pcall(function()
        if self.showClass then
            local cCurr, cMax, cDefColor = GetClassResourceData()
            if cMax <= 0 then cMax = 1 end
            local cColor = GetSafeColor(db.class, cDefColor)
            
            self.classBar.statusBar:SetMinMaxValues(0, cMax)
            self.classBar.statusBar:SetValue(cCurr)
            self.classBar.statusBar:SetStatusBarColor(cColor.r, cColor.g, cColor.b)
            self:UpdateDividers(self.classBar, cMax)
            FormatSafeText(self.classBar, db.class, cCurr, cMax, false, nil, specCfg.textClass)
        end
    end)
    
    pcall(function()
        local tCurr, tMax, tDefColor, tIsTime, tSegments, tShouldShow = GetTertiaryResourceData()
        local newShowTertiary = db.tertiary.enable and tShouldShow and specCfg.showTertiary
        if self.showTertiary ~= newShowTertiary then self:UpdateLayout() end
        
        if self.showTertiary then
            if tMax <= 0 then tMax = 1 end
            local tColor = GetSafeColor(db.tertiary, tDefColor)
            self.tertiaryBar.statusBar:SetMinMaxValues(0, tMax)
            self.tertiaryBar.statusBar:SetValue(tCurr)
            self.tertiaryBar.statusBar:SetStatusBarColor(tColor.r, tColor.g, tColor.b)
            self:UpdateDividers(self.tertiaryBar, tSegments)
            
            local isEleMana = (playerClass == "SHAMAN" and GetSpecializationInfo(GetSpecialization() or 1) == 262)
            FormatSafeText(self.tertiaryBar, db.tertiary, tCurr, tMax, tIsTime, isEleMana and 0 or nil, specCfg.textTertiary)
        end
    end)
    
    pcall(function()
        if self.showMana then
            local mMax = UnitPowerMax("player", 0)
            if mMax <= 0 then mMax = 1 end
            local mCurr = UnitPower("player", 0)
            local mColor = GetSafeColor(db.mana, {r=0, g=0.5, b=1})
            
            self.manaBar.statusBar:SetMinMaxValues(0, mMax)
            self.manaBar.statusBar:SetValue(mCurr)
            self.manaBar.statusBar:SetStatusBarColor(mColor.r, mColor.g, mColor.b)
            self:UpdateDividers(self.manaBar, 1)
            FormatSafeText(self.manaBar, db.mana, mCurr, mMax, false, 0, specCfg.textMana)
        end
    end)
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

function CR:OnContextChanged()
    self.selectedSpecForConfig = GetCurrentContextID()
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
    
    self.showPower = false
    self.showClass = false
    self.showTertiary = false
    self.showMana = false
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateLayout")
    self:RegisterEvent("UNIT_DISPLAYPOWER", "UpdateLayout")
    self:RegisterEvent("UNIT_MAXPOWER", "UpdateLayout")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnContextChanged")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "OnContextChanged")
    
    CR:UpdateLayout()
    
    local ticker = 0
    self.anchor:SetScript("OnUpdate", function(_, elapsed)
        ticker = ticker + elapsed
        if ticker >= 0.05 then
            ticker = 0
            CR:DynamicTick()
        end
    end)
end