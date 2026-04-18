local AddonName, ns = ...
local WF = _G.WishFlex

WF.DefaultPresets = {
    ["WARRIOR"] = {
        [0] = { 
            { id = "23920", type = "buff", duration = 0, name = "法术反射" },
            { id = "97462", type = "buff", duration = 0, name = "集结呐喊" },
            { id = "118038", type = "buff", duration = 0, name = "剑在人在" },
            { id = "184364", type = "buff", duration = 0, name = "狂怒回复" },
            { id = "871", type = "buff", duration = 0, name = "盾墙" },
        },
        [71] = { 
            { id = "260708", type = "buff", duration = 0, name = "横扫攻击" },
            { id = "227847", type = "skill", duration = 12, name = "剑刃风暴" },
        },
        [72] = { 
            { id = "1719", type = "buff", duration = 0, name = "鲁莽" },
            { id = "12950", type = "monitor", mode = "stack", maxVal = 4, name = "冰刺", showStackText = false, hideOriginal = false },
        },
        [73] = {}
    },
    ["PALADIN"] = {
        [0] = { 
            { id = "642", type = "buff", duration = 0, name = "圣盾术" },
            { id = "498", type = "buff", duration = 0, name = "圣佑术" },
            { id = "31850", type = "buff", duration = 0, name = "炽热防御者" },
            { id = "86659", type = "buff", duration = 0, name = "远古列王守卫" },
            { id = "1044", type = "buff", duration = 0, name = "自由祝福" },
            { id = "1022", type = "buff", duration = 0, name = "保护祝福" },
        },
        [65] = { 
            { id = "31884", type = "buff", duration = 0, requireSpell = 31884 },
            { id = "1279187", type = "buff", duration = 0, buffID = 216331, requireSpell = 216331 },
            { id = "31821", type = "skill", duration = 8, name = "光环掌握" },
        },
        [66] = { 
            { id = "31884", type = "buff", duration = 0 },
            { id = "389539", type = "buff", duration = 0 },
            { id = "204018", type = "buff", duration = 0 },
        },
        [70] = { 
            { id = "31884", type = "buff", duration = 0 },
        }
    },
    ["HUNTER"] = {
        [0] = { 
            { id = "109304", type = "buff", duration = 0, name = "意气风发" },
            { id = "186265", type = "buff", duration = 0, name = "灵龟守护" },
            { id = "264735", type = "buff", duration = 0, name = "优胜劣汰" },
        },
        [253] = { 
            { id = "19574", type = "buff", duration = 0, name = "狂野怒火" },
        },
        [254] = { 
            { id = "288613", type = "buff", duration = 0, name = "百发百中" },
        },
        [255] = { 
           { id = "260285", type = "monitor", mode = "stack", maxVal = 3, color = {r=0.67, g=0.83, b=0.45}, name = "利刃", showStackText = false },
        }
    },
    ["ROGUE"] = {
        [0] = { 
            { id = "1966", type = "buff", duration = 0, name = "佯攻" },
            { id = "5277", type = "buff", duration = 0, name = "闪避" },
            { id = "31224", type = "buff", duration = 0, name = "暗影斗篷" },
            { id = "185311", type = "buff", duration = 0, name = "猩红之瓶" },
        },
        [259] = { 
            { id = "32645", type = "buff", duration = 0, name = "毒伤" },
            { id = "79140", type = "skill", duration = 20, name = "宿敌" },
        },
        [260] = { 
            { id = "315508", type = "monitor", mode = "time", maxVal = 30, color = {r=0.2, g=0.8, b=0.2}, name = "命运骨骰" },
            { id = "13750", type = "buff", duration = 0, name = "冲动" },
            { id = "13877", type = "skill", duration = 12, name = "剑刃乱舞" },
        },
        [261] = { 
            { id = "121471", type = "buff", duration = 0, name = "暗影之舞" },
            { id = "185313", type = "skill", duration = 8, name = "暗影之舞(层数)" },
        }
    },
    ["PRIEST"] = {
        [0] = { 
            { id = "586", type = "buff", duration = 0, name = "渐隐术" },
            { id = "19236", type = "buff", duration = 0, name = "绝望祷言" },
            { id = "47585", type = "buff", duration = 0, name = "消散" },
            { id = "33206", type = "buff", duration = 0, name = "痛苦压制" },
        },
        [256] = { 
            { id = "10060", type = "skill", duration = 20, name = "能量灌注" },
        },
        [257] = { 
            { id = "47788", type = "buff", duration = 0, name = "守护之魂" },
            { id = "64843", type = "skill", duration = 8, name = "神圣赞美诗" },
        },
        [258] = { 
            { id = "228260", type = "buff", duration = 0, name = "虚空爆发" },
            { id = "34433", type = "skill", duration = 15, name = "暗影魔" },
            { id = "34914", type = "skill", duration = 0, glowEnable = false, fadedEnable = true },
            { id = "589", type = "skill", duration = 0, glowEnable = false, fadedEnable = true },
        }
    },
    ["DEATHKNIGHT"] = {
        [0] = { 
            { id = "48707", type = "buff", duration = 0, name = "反魔法护罩" },
            { id = "48792", type = "buff", duration = 0, name = "冰封之韧" },
            { id = "49039", type = "buff", duration = 0, name = "巫妖之躯" },
            { id = "51052", type = "buff", duration = 0, name = "反魔法领域" },
            { id = "55233", type = "buff", duration = 0, name = "吸血鬼之血" },
        },
        [250] = { 
            { id = "49028", type = "skill", duration = 8, name = "符文刃舞" },
        },
        [251] = { 
            { id = "51271", type = "buff", duration = 0, name = "冰霜之柱" },
            { id = "152279", type = "skill", duration = 15, name = "冰霜巨龙之息" },
        },
        [252] = { 
            { id = "63560", type = "buff", duration = 0, name = "黑暗突变" },
            { id = "49206", type = "skill", duration = 30, name = "召唤石像鬼" },
        }
    },
    ["SHAMAN"] = {
        [0] = { 
            { id = "108271", type = "buff", duration = 0, name = "星界转移" },
        },
        [262] = { 
            { id = "114050", type = "buff", duration = 0, name = "升腾" },
            { id = "191634", type = "skill", duration = 15, name = "风暴守护者" },
        },
        [263] = { 
            { id = "114051", type = "buff", duration = 0, name = "升腾" },
            { id = "115356", type = "skill", duration = 10, name = "风暴打击" },
            { id = "187880", type = "monitor", mode = "stack", maxVal = 10, name = "漩涡武器", showStackText = false },
        },
        [264] = { 
            { id = "114052", type = "buff", duration = 0, name = "升腾" },
            { id = "108280", type = "skill", duration = 10, name = "治疗之潮图腾" },
        }
    },
    ["MAGE"] = {
        [0] = { 
            { id = "45438", type = "buff", duration = 0, name = "寒冰屏障" },
            { id = "414658", type = "buff", duration = 0, name = "寒冰屏障" },
            { id = "342245", type = "buff", duration = 0, name = "操控时间" },
            { id = "235450", type = "buff", duration = 0, name = "棱光护体" },
            { id = "235313", type = "buff", duration = 0, name = "烈焰护体" },
            { id = "11426", type = "buff", duration = 0, name = "寒冰护体" },
        },
        [62] = { 
            { id = "365350", type = "buff", duration = 0, name = "奥术涌动" },
        },
        [63] = { 
            { 
                id = "108853", type = "monitor", isSkill = true, trackType = "charge", maxVal = 3, 
                color = {r=1, g=0.4, b=0, a=1}, name = "火焰冲击", 
                showStackText = false, showTimerText = true, dynamicTimer = true
            },
            { id = "190319", type = "buff", duration = 0, name = "燃烧" },
        },
        [64] = { 
            { id = "205473", type = "monitor", mode = "stack", maxVal = 5, color = {r=0.2, g=0.8, b=1.0}, name = "冰刺", showStackText = false },
        }
    },
    ["WARLOCK"] = {
        [0] = { 
            { id = "104773", type = "buff", duration = 0, name = "不灭决心" },
            { id = "108416", type = "buff", duration = 0, name = "黑暗契约" },
        },
        [265] = { 
            { id = "205180", type = "skill", duration = 20, name = "召唤黑眼", useOverlay = true },
            { id = "980", type = "skill", duration = 0, name = "痛楚", glowEnable = false, fadedEnable = true },
            { id = "172", type = "skill", duration = 0, name = "腐蚀术", glowEnable = false, fadedEnable = true },
            { id = "1259790", type = "skill", duration = 0, name = "鬼影缠身", glowEnable = false, fadedEnable = true },
        },
        [266] = { 
            { id = "265187", type = "skill", duration = 20, name = "召唤恶魔暴君", useOverlay = true },
            { id = "1276672", type = "skill", duration = 12, name = "召唤末日守卫", useOverlay = true },
        },
        [267] = { 
            { id = "1122", type = "skill", duration = 30, name = "召唤地狱火", useOverlay = true },
            { id = "442726", type = "buff", duration = 0, name = "怨毒" },
            { id = "445468", type = "skill", duration = 0, name = "献祭", glowEnable = false, fadedEnable = true },
            { id = "348", type = "skill", duration = 0, name = "献祭", glowEnable = false, fadedEnable = true },
        }
    },
    ["MONK"] = {
        [0] = { 
            { id = "115203", type = "buff", duration = 0, name = "壮胆酒" },
            { id = "116849", type = "buff", duration = 0, name = "作茧缚命" },
            { id = "122783", type = "buff", duration = 0, name = "散魔功" },
            { id = "122278", type = "buff", duration = 0, name = "躯不坏" },
        },
        [268] = { 
            { id = "115176", type = "skill", duration = 8, name = "禅悟冥想" },
        },
        [269] = { 
            { id = "137639", type = "buff", duration = 0, name = "风火雷电" },
            { id = "115080", type = "skill", duration = 8, name = "轮回之触" },
        },
        [270] = { 
            { id = "322118", type = "skill", duration = 25, name = "召唤玉珑" },
        }
    },
    ["DRUID"] = {
        [0] = { 
            { id = "22812", type = "buff", duration = 0, name = "树皮术" },
            { id = "61336", type = "buff", duration = 0, name = "生存本能" },
            { id = "102342", type = "buff", duration = 0, name = "铁木树皮" },
        },
        [102] = { 
            { id = "102560", type = "buff", duration = 0, name = "超凡之盟" },
            { id = "8921", type = "skill", duration = 0, name = "月火术", glowEnable = false, fadedEnable = true },
            { id = "93402", type = "skill", duration = 0, name = "星火术", glowEnable = false, fadedEnable = true },
            { id = "48517", type = "monitor", mode = "time", name = "日蚀", color = {r=1, g=0.5, b=0, a=1}, alwaysShow = false, inFreeLayout = false, reverseFill = true, timerAnchor = "RIGHT", stackAnchor = "RIGHT", isDuration = true },
            { id = "48518", type = "monitor", mode = "time", name = "月蚀", color = {r=0.4, g=0.7, b=1, a=1}, alwaysShow = false, inFreeLayout = false, reverseFill = false, timerAnchor = "LEFT", stackAnchor = "LEFT", isDuration = true },
        },
        [103] = { 
            { id = "106951", type = "buff", duration = 0, name = "狂暴", requireSpell = 106951 },
            { id = "102543", type = "buff", duration = 0, name = "狂暴", requireSpell = 102543 },
            { id = "1822", type = "skill", duration = 0, name = "斜掠", glowEnable = false, fadedEnable = true },
            { id = "1079", type = "skill", duration = 0, name = "割裂", glowEnable = false, fadedEnable = true },
        },
        [104] = { 
            { id = "50334", type = "buff", duration = 0, name = "狂暴(熊)", requireSpell = 50334 },
        },
        [105] = { 
            { id = "33891", type = "buff", duration = 0, name = "化身：生命之树" },
        }
    },
    ["DEMONHUNTER"] = {
        [0] = { 
            { id = "196718", type = "buff", duration = 0, name = "黑暗" },
            { id = "198589", type = "buff", duration = 0, name = "疾影" },
            { id = "204021", type = "buff", duration = 0, name = "烈火烙印" },
        },
        [577] = { 
            { id = "162264", type = "buff", duration = 0, name = "恶魔变形" },
        },
        [581] = { 
            { id = "187827", type = "buff", duration = 0, name = "恶魔变形(复仇)" },
            { id = "203981", type = "monitor", mode = "stack", maxVal = 6, color = {r = 0.64, g = 0.19, b = 0.79}, name = "灵魂残片", showStackText = false },
        }
    },
    ["EVOKER"] = {
        [0] = { 
            { id = "363916", type = "buff", duration = 0, name = "黑曜鳞结" },
            { id = "374348", type = "buff", duration = 0, name = "新生光焰" },
        },
        [1467] = { 
            { id = "375087", type = "buff", duration = 0, name = "狂龙之怒" },
        },
        [1468] = { 
            { id = "355936", type = "skill", duration = 5, name = "梦境飞行" },
        },
        [1473] = { 
        }
    }
}

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
loader:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
    
    C_Timer.After(1.5, function()
        if not WF or not WF.db then return end
        
        if not WF.db.auraGlow then WF.db.auraGlow = {} end
        if not WF.db.auraGlow.disabledPresets then WF.db.auraGlow.disabledPresets = {} end
        if not WF.db.auraGlow.spells then WF.db.auraGlow.spells = {} end
        if not WF.db.cooldownTracker then WF.db.cooldownTracker = { desatSpells = {}, resourceSpells = {} } end

        local _, playerClass = UnitClass("player")

        local function InjectGroup(group, groupSpecID)
            if type(group) ~= "table" then return end
            groupSpecID = groupSpecID or 0
            local isAllSpecs = (groupSpecID == 0)
            
            for _, preset in ipairs(group) do
                local pid = tostring(preset.id)
                
                if not WF.db.auraGlow.disabledPresets[pid] then
                    if preset.type == "buff" or preset.type == "skill" then
                        
                        if not WF.db.auraGlow.spells[pid] then
                            WF.db.auraGlow.spells[pid] = {
                                enable = preset.glowEnable ~= false,
                                isSkill = (preset.type == "skill"),
                                buffID = tonumber(pid),
                                duration = preset.duration or 0,
                                targetAura = (preset.type == "skill"),
                                specID = groupSpecID,
                                allSpecs = isAllSpecs,
                                requireSpell = preset.requireSpell,
                                useOverlay = preset.useOverlay or false
                            }
                        else
                            if WF.db.auraGlow.spells[pid].specID == nil then
                                WF.db.auraGlow.spells[pid].specID = groupSpecID
                            end
                        end
                        
                        if preset.fadedEnable then
                            WF.db.cooldownTracker.desatSpells[pid] = true
                        end
                        
                    elseif preset.type == "monitor" then
                        if not WF.db.wishMonitor then WF.db.wishMonitor = { buffs = {}, skills = {}, sortOrder = {} } end
                        
                        local cMode = preset.mode or "time"
                        local isBuff = (preset.isSkill ~= true)
                        local targetDB = isBuff and WF.db.wishMonitor.buffs or WF.db.wishMonitor.skills
                        
                        local hasStacks = (cMode == "stack" or preset.trackType == "charge")
                        local defaultAlwaysShow = hasStacks
                        if preset.alwaysShow ~= nil then defaultAlwaysShow = preset.alwaysShow end

                        local defaultHide = false
                        if preset.hideOriginal ~= nil then defaultHide = preset.hideOriginal end

                        if not targetDB[pid] then
                            targetDB[pid] = {
                                enable = true,
                                specID = groupSpecID,     
                                allSpecs = isAllSpecs,    
                                useStatusBar = true,      
                                mode = cMode,             
                                trackType = preset.trackType or "cooldown", 
                                maxStacks = preset.maxVal or 5,
                                alwaysShow = defaultAlwaysShow,
                                inFreeLayout = preset.inFreeLayout or false,
                                reverseFill = preset.reverseFill or false,
                                bgColor = preset.bgColor or nil,
                                isDuration = (preset.isDuration == nil) and true or preset.isDuration,
                                alignWithResource = not preset.inFreeLayout,
                                color = preset.color or {r=0, g=0.8, b=1, a=1},
                                showStackText = (preset.showStackText ~= nil) and preset.showStackText or (cMode == "stack"),
                                showTimerText = (preset.showTimerText ~= nil) and preset.showTimerText or (cMode == "time"),
                                timerAnchor = preset.timerAnchor or "RIGHT",
                                stackAnchor = preset.stackAnchor or "LEFT",
                                hideOriginal = defaultHide,
                                dynamicTimer = preset.dynamicTimer
                            }
                        else
                            if targetDB[pid].specID == nil then targetDB[pid].specID = groupSpecID end
                        end
                        
                        -- 【拦截核心】：将 monitor 的褪色状态安全剥离
                        if targetDB[pid].hideOriginal then
                            if not WF.db.cooldownCustom then WF.db.cooldownCustom = {} end
                            if not WF.db.cooldownCustom.blacklist then WF.db.cooldownCustom.blacklist = {} end
                            WF.db.cooldownCustom.blacklist[pid] = true
                            WF.db.cooldownCustom.blacklist["BUFF_"..pid] = true
                            WF.db.cooldownCustom.blacklist["CD_"..pid] = true
                            
                            if not WF.db.auraGlow then WF.db.auraGlow = {} end
                            if not WF.db.auraGlow.blacklist then WF.db.auraGlow.blacklist = {} end
                            WF.db.auraGlow.blacklist[pid] = true
                            
                            -- 将它从褪色列表移除，防止被 CooldownTracker 误伤
                            WF.db.cooldownTracker.desatSpells[pid] = false
                        else
                            if WF.db.cooldownCustom and WF.db.cooldownCustom.blacklist then 
                                WF.db.cooldownCustom.blacklist[pid] = nil 
                                WF.db.cooldownCustom.blacklist["BUFF_"..pid] = nil
                                WF.db.cooldownCustom.blacklist["CD_"..pid] = nil
                            end
                            if WF.db.auraGlow and WF.db.auraGlow.blacklist then WF.db.auraGlow.blacklist[pid] = nil end
                        end
                    end
                end
            end
        end

        if WF.DefaultPresets["ALL"] then InjectGroup(WF.DefaultPresets["ALL"][0], 0) end
        if WF.DefaultPresets[playerClass] then
            for specID, group in pairs(WF.DefaultPresets[playerClass]) do
                InjectGroup(group, specID)
            end
        end
        
        if WF.CooldownTrackerAPI and WF.CooldownTrackerAPI.RefreshAll then WF.CooldownTrackerAPI:RefreshAll() end
        if WF.WishMonitorAPI and WF.WishMonitorAPI.TriggerUpdate then WF.WishMonitorAPI:TriggerUpdate() end
        if WF.UI and WF.UI.RefreshCurrentPanel then pcall(function() WF.UI:RefreshCurrentPanel() end) end
        if WF.TriggerCooldownLayout then WF.TriggerCooldownLayout() end
    end)
end)