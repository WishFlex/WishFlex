local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local mod = WUI:NewModule('ActiveBuffGlow', 'AceEvent-3.0')

local LCG = E.Libs and E.Libs.CustomGlow
if not LCG then LCG = LibStub and LibStub("LibCustomGlow-1.0", true) end

-- ==========================================
-- ⚙️ 核心配置区：你想监视的走马灯技能写在这里
-- ==========================================
local GlowSpells = {
    [107574] = 107574, -- 天神下凡
    [31884]  = 31884,  -- 复仇之怒 (翅膀)
    [196718] = 196718, -- 幻影打击 (DH)
    [51271]  = 51271,  -- 冰霜之柱 (DK)
    [1719]   = 1719,   -- 鲁莽 (狂暴战)
    [10060]  = 10060,  -- 能量灌注 (牧师)
}

local activeBuffs = {}

-- 🎯 精确打击获取 ID，绝不触碰暴雪禁区
local function FindTargetSpellInFrame(frame)
    if not frame then return nil end

    local directIDs = {
        frame.spellID, frame.spellId, frame.id,
        frame.SpellID, frame.spell, frame.ActionID,
        frame.cooldownID
    }

    for _, rawID in ipairs(directIDs) do
        if rawID then
            local numID = tonumber(rawID)
            if numID and GlowSpells[numID] then return numID end
        end
    end

    if type(frame.data) == "table" then
        local dataID = frame.data.id or frame.data.spellID
        if dataID then
            local numID = tonumber(dataID)
            if numID and GlowSpells[numID] then return numID end
        end
    end

    if type(frame.cooldownInfo) == "table" then
        local infoID = frame.cooldownInfo.spellID or frame.cooldownInfo.id
        if infoID then
            local numID = tonumber(infoID)
            if numID and GlowSpells[numID] then return numID end
        end
    end

    if frame.action then
        local actionType, id = GetActionInfo(frame.action)
        if actionType == "spell" and id then
            local numID = tonumber(id)
            if numID and GlowSpells[numID] then return numID end
        end
    end

    return nil
end

function mod:UpdateGlows()
    if not LCG then return end
    local eViewer = _G.EssentialCooldownViewer
    if not (eViewer and eViewer.itemFramePool) then return end

    -- 遍历所有正在显示的冷却图标
    for f in eViewer.itemFramePool:EnumerateActive() do
        if f:IsShown() then
            local sID = FindTargetSpellInFrame(f)

            if sID then
                -- 判断这个技能的 Buff 当前是否在身上
                local shouldGlow = (activeBuffs[sID] == true)

                if shouldGlow then
                    -- 🚀 核心修复：不要用 true/false，用 SpellID 判断！
                    -- 如果这个框体之前记录的发光 ID 跟现在不一致（说明被回收利用了），或者根本没发光
                    if f._glowingSpellID ~= sID then
                        
                        -- 确保遮罩层存在并处于最高层级，防止被黑圈挡住
                        if not f._glowOverlay then
                            f._glowOverlay = CreateFrame("Frame", nil, f)
                            f._glowOverlay:SetAllPoints(f)
                            f._glowOverlay:SetFrameStrata("HIGH") 
                            f._glowOverlay:SetFrameLevel(100)
                        end
                        
                        -- 🌟 防残影：先强制停止可能存在的旧发光
                        pcall(LCG.PixelGlow_Stop, f._glowOverlay, "ActiveBuffGlow_Anim")
                        
                        -- 重新启动走马灯
                        local ok = pcall(LCG.PixelGlow_Start, f._glowOverlay, {0, 1, 1, 1}, 8, 0.25, 10, 2, 0, 0, false, "ActiveBuffGlow_Anim")
                        if ok then
                            -- 把当前的技能 ID 刻在这个框体上
                            f._glowingSpellID = sID
                        end
                    end
                else
                    -- 应该熄灭时，如果它还带着发光标记，立刻停止并清空标记
                    if f._glowingSpellID then
                        if f._glowOverlay then
                            pcall(LCG.PixelGlow_Stop, f._glowOverlay, "ActiveBuffGlow_Anim")
                        end
                        f._glowingSpellID = nil
                    end
                end
            else
                -- 极端情况：连技能 ID 都获取不到了，但框体还带着发光标记（说明是彻底错乱的回收框体）
                if f._glowingSpellID then
                    if f._glowOverlay then
                        pcall(LCG.PixelGlow_Stop, f._glowOverlay, "ActiveBuffGlow_Anim")
                    end
                    f._glowingSpellID = nil
                end
            end
        end
    end
end

function mod:CheckAuras()
    local changed = false

    for buffID, _ in pairs(GlowSpells) do
        -- C_UnitAuras.GetPlayerAuraBySpellID 绝对安全
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(buffID)
        local isNowActive = (aura ~= nil)
        
        if isNowActive ~= (activeBuffs[buffID] or false) then
            activeBuffs[buffID] = isNowActive
            changed = true
            -- 调试：让你明确看到 BUFF 是否被成功识别
            -- print("|cff00e5cc[WishFlex]|r 技能状态改变: ID", buffID, "当前激活:", isNowActive)
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
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckAuras")
    
    local eViewer = _G.EssentialCooldownViewer
    if eViewer then
        if type(eViewer.Layout) == "function" then hooksecurefunc(eViewer, "Layout", function() mod:UpdateGlows() end) end
        if type(eViewer.UpdateLayout) == "function" then hooksecurefunc(eViewer, "UpdateLayout", function() mod:UpdateGlows() end) end
    end
    
    C_Timer.NewTicker(0.5, function() mod:CheckAuras() end)
    C_Timer.After(2, function() print("|cff00ffcc[WishFlex]|r 走马灯纯净遮罩版已挂载！") end)
end