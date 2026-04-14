local AddonName, ns = ...

-- 暴露给整个插件命名空间，供任何模块调用
ns.RACE_RACIALS = {
    Scourge            = { 7744 }, 
    Tauren             = { 20549 }, 
    Orc                = { 20572, 33697, 33702 },
    BloodElf           = { 202719, 50613, 25046, 69179, 80483, 155145, 129597, 232633, 28730 },
    Dwarf              = { 20594 }, 
    Troll              = { 26297 }, 
    Draenei            = { 28880 },
    NightElf           = { 58984 }, 
    Human              = { 59752 }, 
    DarkIronDwarf      = { 265221 },
    Gnome              = { 20589 }, 
    HighmountainTauren = { 69041 }, 
    Worgen             = { 68992 },
    Goblin             = { 69070 }, 
    Pandaren           = { 107079 }, 
    MagharOrc          = { 274738 },
    LightforgedDraenei = { 255647 }, 
    VoidElf            = { 256948 }, 
    KulTiran           = { 287712 },
    ZandalariTroll     = { 291944 }, 
    Vulpera            = { 312411 }, 
    Mechagnome         = { 312924 },
    Dracthyr           = { 357214, 368970 }, 
    EarthenDwarf       = { 436344 }, 
    Haranir            = { 1287685 },
}

-- 提供一个全局公用的法术可用性检测函数
function ns.IsSpellAvailable(spellID)
    if not spellID then return false end
    local isKnown = false
    pcall(function()
        if IsPlayerSpell and IsPlayerSpell(spellID) then isKnown = true end
        if not isKnown and IsSpellKnown and IsSpellKnown(spellID) then isKnown = true end
        if not isKnown and C_Spell and C_Spell.IsSpellUsable then
            local isUsable, noMana = C_Spell.IsSpellUsable(spellID)
            if isUsable or noMana then isKnown = true end
        end
    end)
    return isKnown
end