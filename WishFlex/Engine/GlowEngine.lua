local AddonName, ns = ...
local WF = ns.WF
local LCG = LibStub("LibCustomGlow-1.0", true)

-- 初始化发光引擎
WF.GlowEngine = {}

-- 内部缓存，防止重复创建 Host
local GlowHosts = {}

-- 【核心】：为目标框体创建一个干净的宿主层，防止污染原版框体或被裁剪
function WF.GlowEngine:EnsureHost(frame)
    if not frame then return nil end
    
    -- 适配 ElvUI 等带有 wishBd 背景的框体
    local target = frame.wishBd or frame
    if frame.Icon and type(frame.Icon) == "table" then
        if frame.Icon.wishBd then target = frame.Icon.wishBd
        elseif frame.Icon.Icon and frame.Icon.Icon.wishBd then target = frame.Icon.Icon.wishBd end
    end

    local host = GlowHosts[frame]
    if not host then
        host = CreateFrame("Frame", nil, target)
        host:SetClampedToScreen(false)
        GlowHosts[frame] = host
    end

    -- 动态纠正父子关系和层级
    if host:GetParent() ~= target then host:SetParent(target) end
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", target, "TOPLEFT", -0.05, -0.05)
    host:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, -0.05)
    host:SetFrameLevel((target:GetFrameLevel() or 1) + 5)
    
    -- 挂载一个清理钩子
    if not frame._wfGlowEngineHooked then
        frame:HookScript("OnHide", function()
            WF.GlowEngine:StopAllGlows(frame)
        end)
        frame._wfGlowEngineHooked = true
    end

    return host
end

-- 【API】：应用发光效果
-- @param targetFrame: 暴雪原生动作条、Buff图标，或你的自定义框体
-- @param glowKey: 唯一标识符，防止不同模块的发光冲突 (如 "AuraGlowDirect", "MaxStackGlow")
-- @param options: table，包含 type, color, lines, freq 等参数
function WF.GlowEngine:ApplyGlow(targetFrame, glowKey, options)
    if not LCG or not targetFrame or not options then return end
    
    local host = self:EnsureHost(targetFrame)
    if not host then return end

    -- 先停止旧的同名光效
    self:StopGlow(targetFrame, glowKey)

    if not options.enable then return end

    local c = options.color or {r = 1, g = 1, b = 1, a = 1}
    local colorArr = options.useCustomColor and {c.r or 1, c.g or 1, c.b or 1, c.a or 1} or nil
    local t = options.type or "pixel"

    if t == "pixel" then
        local len = tonumber(options.pixelLength) or 0
        if len == 0 then len = nil end
        LCG.PixelGlow_Start(host, colorArr, tonumber(options.pixelLines) or 8, tonumber(options.pixelFrequency) or 0.25, len, tonumber(options.pixelThickness) or 1, tonumber(options.pixelXOffset) or 0, tonumber(options.pixelYOffset) or 0, false, glowKey, 0)
    elseif t == "autocast" then
        LCG.AutoCastGlow_Start(host, colorArr, tonumber(options.autocastParticles) or 4, tonumber(options.autocastFrequency) or 0.2, tonumber(options.autocastScale) or 1, tonumber(options.autocastXOffset) or 0, tonumber(options.autocastYOffset) or 0, glowKey, 0)
    elseif t == "button" then
        local freq = tonumber(options.buttonFrequency) or 0
        if freq == 0 then freq = nil end
        LCG.ButtonGlow_Start(host, colorArr, freq, 0)
    elseif t == "proc" then
        LCG.ProcGlow_Start(host, {color = colorArr, duration = tonumber(options.procDuration) or 1, xOffset = tonumber(options.procXOffset) or 0, yOffset = tonumber(options.procYOffset) or 0, key = glowKey, frameLevel = 0})
    end
end

-- 【API】：停止指定的发光
function WF.GlowEngine:StopGlow(targetFrame, glowKey)
    if not LCG or not targetFrame then return end
    local host = GlowHosts[targetFrame]
    if host then
        LCG.PixelGlow_Stop(host, glowKey)
        LCG.AutoCastGlow_Stop(host, glowKey)
        LCG.ButtonGlow_Stop(host)
        LCG.ProcGlow_Stop(host, glowKey)
    end
end

-- 【API】：停止框体上的所有发光
function WF.GlowEngine:StopAllGlows(targetFrame)
    if not LCG or not targetFrame then return end
    local host = GlowHosts[targetFrame]
    if host then
        LCG.PixelGlow_Stop(host)
        LCG.AutoCastGlow_Stop(host)
        LCG.ButtonGlow_Stop(host)
        LCG.ProcGlow_Stop(host)
    end
end