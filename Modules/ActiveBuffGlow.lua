local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local mod = WUI:NewModule('ActiveBuffGlow', 'AceEvent-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

-- ==========================================
-- ⚙️ 核心配置区
-- ==========================================
local GlowSpells = {
    [107574] = true, -- 天神下凡
    [31884]  = true, -- 复仇之怒 (翅膀)
    [196718] = true, -- 幻影打击 (DH)
    [51271]  = true, -- 冰霜之柱 (DK)
    [1719]   = true, -- 鲁莽 (狂暴战)
    [10060]  = true, -- 能量灌注 (牧师)
}

local SpellTextureMap = {}
local SpellNameMap = {}
local glowProxyFrames = {}
local SpellFrameCache = {} -- 🧠 静态记忆缓存
local activeBuffs = {}

local function BuildMaps()
    for spellID in pairs(GlowSpells) do
        local tex = C_Spell and C_Spell.GetSpellTexture(spellID) or GetSpellTexture(spellID)
        if tex then SpellTextureMap[spellID] = tex end
        
        local name = C_Spell and C_Spell.GetSpellName(spellID) or GetSpellInfo(spellID)
        if name then SpellNameMap[spellID] = name end
    end
end

-- 🛡️ 光环状态检测
local function GetAuraStatus(spellID)
    local sName = SpellNameMap[spellID]
    if not sName then return false end
    
    for i = 1, 255 do
        local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not aura then break end 
        
        if type(aura.name) == "string" and not issecretvalue(aura.name) and aura.name == sName then
            return true
        end
    end
    return false
end

-- 👁️ 寻找目标框体
local function FindFrameForSpell(eViewer, targetSpellID)
    local targetTexture = SpellTextureMap[targetSpellID]

    for f in eViewer.itemFramePool:EnumerateActive() do
        if f:IsVisible() then
            -- 数据验证
            local ids = {f.spellID, f.spellId, f.id, f.cooldownID, f.rangeCheckSpellID}
            for _, v in ipairs(ids) do
                if type(v) == "number" and not issecretvalue(v) and v == targetSpellID then
                    return f
                end
            end
            if type(f.data) == "table" and type(f.data.id) == "number" and not issecretvalue(f.data.id) and f.data.id == targetSpellID then 
                return f 
            end
            
            -- 图片验证
            if f.Icon and targetTexture then
                local ok, tex = pcall(function() return f.Icon:GetTexture() end)
                if ok and tex and not issecretvalue(tex) and tex == targetTexture then
                    return f
                end
            end
        end
    end
    return nil
end

local function SafeSetSize(gf, targetFrame)
    local ok, w, h = pcall(function() return targetFrame:GetSize() end)
    if ok and type(w) == "number" and not issecretvalue(w) and type(h) == "number" and not issecretvalue(h) then
        gf:SetSize(w, h)
    else
        local db = E.db.WishFlex.cdManager.Essential
        gf:SetSize(db and db.row1Width or 45, db and db.row1Height or 45)
    end
end

-- 📸 核心重构：一次性快照扫描函数 (只在需要时触发)
function mod:ScanFrames()
    if InCombatLockdown() then return end -- 绝对不在战斗中扫描
    
    local eViewer = _G.EssentialCooldownViewer
    if not (eViewer and eViewer.itemFramePool) then return end

    for spellID in pairs(GlowSpells) do
        local foundFrame = FindFrameForSpell(eViewer, spellID)
        if foundFrame then
            SpellFrameCache[spellID] = foundFrame
        end
    end
end

-- ✨ 发光渲染调度器
function mod:UpdateGlows()
    local eViewer = _G.EssentialCooldownViewer
    if not eViewer then return end

    for spellID in pairs(GlowSpells) do
        local isActive = activeBuffs[spellID]
        local targetFrame = SpellFrameCache[spellID]
        local gf = glowProxyFrames[spellID]

        -- 状态激活，且内存里存有这个框体，且框体当前显示在屏幕上
        if isActive and targetFrame and targetFrame:IsVisible() then
            if not gf then
                gf = CreateFrame("Frame", "WishFlex_GlowProxy_"..spellID, UIParent)
                gf:SetFrameLevel(eViewer:GetFrameLevel() + 50)
                glowProxyFrames[spellID] = gf
            end

            SafeSetSize(gf, targetFrame)
            gf:ClearAllPoints()
            gf:SetPoint("CENTER", targetFrame, "CENTER")
            gf:Show()

            if not gf.isGlowing and LCG then
                LCG.PixelGlow_Start(gf, {0, 1, 1, 1}, 8, 0.25, 10, 2, 0, 0, false, "ActiveBuffGlow_Anim")
                gf.isGlowing = true
            end
        else
            if gf and gf.isGlowing and LCG then
                LCG.PixelGlow_Stop(gf, "ActiveBuffGlow_Anim")
                gf.isGlowing = false
                gf:Hide()
            end
        end
    end
end

-- 🩸 光环事件触发器
function mod:CheckAuras()
    local changed = false
    for spellID in pairs(GlowSpells) do
        local isActive = GetAuraStatus(spellID)
        if isActive ~= (activeBuffs[spellID] or false) then
            activeBuffs[spellID] = isActive
            changed = true
        end
    end

    if changed then
        self:UpdateGlows()
    end
end

function mod:UNIT_AURA(event, unit)
    if unit == "player" then
        self:CheckAuras()
    end
end

function mod:Initialize()
    BuildMaps()
    
    -- 注册光环事件
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckAuras")
    
    -- 当玩家切换天赋时，扫一次重新记忆排版
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "ScanFrames") 
    
    local eViewer = _G.EssentialCooldownViewer
    if eViewer then
        -- 监听 EssentialCooldownViewer 插件自己的排版更新事件，它动我们才扫！
        if type(eViewer.Layout) == "function" then 
            hooksecurefunc(eViewer, "Layout", function() mod:ScanFrames(); mod:UpdateGlows() end) 
        end
        if type(eViewer.UpdateLayout) == "function" then 
            hooksecurefunc(eViewer, "UpdateLayout", function() mod:ScanFrames(); mod:UpdateGlows() end) 
        end
    end
    
    -- 登录游戏 2 秒后（等待UI加载完毕），进行唯一的一次全盘扫描！
    C_Timer.After(2, function() 
        mod:ScanFrames()
        print("|cff00ffcc[WishFlex]|r 走马灯【零占用事件驱动版】已挂载！性能消耗降至0%！") 
    end)
end