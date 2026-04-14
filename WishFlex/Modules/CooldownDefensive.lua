local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF

-- 【防御组】预设技能 ID 库
-- 只要在这里配置了的 ID，无论暴雪默认把它放哪，都会被自动强制抓取进“防御组”。
-- 你也可以随时在沙盒里手动拖拽覆盖这个规则。
WF.DefensiveSpells = {
    -- ================= WARRIOR (战士) =================
    [23920]  = true,  -- 法术反射 (Spell Reflection)
    [97462]  = true,  -- 集结呐喊 (Rallying Cry)
    [118038] = true,  -- 剑在人在 (Die by the Sword)
    [184364] = true,  -- 狂怒回复 (Enraged Regeneration)
    [871]    = true,  -- 盾墙 (Shield Wall)

    -- ================= PALADIN (圣骑士) =================
    [642]    = true,  -- 圣盾术 (Divine Shield)
    [498]    = true,  -- 圣佑术 (Divine Protection)
    [31850]  = true,  -- 春哥/炽热防御者 (Ardent Defender)
    [86659]  = true,  -- 远古列王守卫 (Guardian of Ancient Kings)
    [1044]   = true,  -- 自由祝福 (Blessing of Freedom) - 保留原设
    [1022]   = true,  -- 保护祝福 (Blessing of Protection) - 保留原设

    -- ================= HUNTER (猎人) =================
    [109304] = true,  -- 意气风发 (Exhilaration)
    [186265] = true,  -- 灵龟守护 (Aspect of the Turtle)
    [264735] = true,  -- 优胜劣汰 (Survival of the Fittest)

    -- ================= ROGUE (潜行者) =================
    [1966]   = true,  -- 佯攻 (Feint)
    [5277]   = true,  -- 闪避 (Evasion)
    [31224]  = true,  -- 暗影斗篷 (Cloak of Shadows)
    [185311] = true,  -- 猩红之瓶 (Crimson Vial)

    -- ================= PRIEST (牧师) =================
    [586]    = true,  -- 渐隐术 (Fade)
    [19236]  = true,  -- 绝望祷言 (Desperate Prayer)
    [47585]  = true,  -- 消散 (Dispersion)
    [33206]  = true,  -- 痛苦压制 (Pain Suppression) - 保留原设

    -- ================= DEATH KNIGHT (死亡骑士) =================
    [48707]  = true,  -- 反魔法护罩 (Anti-Magic Shell)
    [48792]  = true,  -- 冰封之韧 (Icebound Fortitude)
    [49039]  = true,  -- 巫妖之躯 (Lichborne)
    [51052]  = true,  -- 反魔法领域 (Anti-Magic Zone)
    [55233]  = true,  -- 吸血鬼之血 (Vampiric Blood)

    -- ================= SHAMAN (萨满祭司) =================
    [108271] = true,  -- 星界转移 (Astral Shift)

    -- ================= MAGE (法师) =================
    [45438]  = true,  -- 寒冰屏障/冰箱 (Ice Block)
    [414658]  = true,  -- 寒冰屏障/冰箱 (Ice Block)
    [342245] = true,  -- 操控时间 (Alter Time)
    [235450] = true,  -- 棱光护体 (Prismatic Barrier)
    [235313] = true,  -- 烈焰护体 (Blazing Barrier)
    [11426]  = true,  -- 寒冰护体 (Ice Barrier)

    -- ================= WARLOCK (术士) =================
    [104773] = true,  -- 不灭决心 (Unending Resolve)
    [108416] = true,  -- 黑暗契约 (Dark Pact)

    -- ================= MONK (武僧) =================
    [115203] = true,  -- 壮胆酒 (Fortifying Brew)
    [116849] = true,  -- 作茧缚命 (Life Cocoon) - 保留原设
    [122783] = true,  -- 散魔功 (Diffuse Magic) - 保留原设
    [122278] = true,  -- 躯不坏 (Dampen Harm) - 保留原设

    -- ================= DRUID (德鲁伊) =================
    [22812]  = true,  -- 树皮术 (Barkskin)
    [61336]  = true,  -- 生存本能 (Survival Instincts)
    [102342] = true,  -- 铁木树皮 (Ironbark)

    -- ================= DEMON HUNTER (恶魔猎手) =================
    [196718] = true,  -- 幻影打击/黑暗 (Darkness)
    [198589] = true,  -- 疾影 (Blur)
    [204021] = true,  -- 烈火烙印 (Fiery Brand)

    -- ================= EVOKER (唤魔者) =================
    [363916] = true,  -- 黑曜鳞结 (Obsidian Scales)
    [374348] = true,  -- 新生光焰 (Renewing Blaze) - 保留原设


}