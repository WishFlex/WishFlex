local AddonName, ns = ...
local WF = ns.WF
local LCG = LibStub("LibCustomGlow-1.0", true)
WF.GlowEngine = {}

local GlowHosts = {}

-- 【极限优化1】：全局复用发光参数表，杜绝高频刷新时产生海量 Table 内存垃圾
local cachedColor = {1, 1, 1, 1}
local cachedProcOpts = {color = nil, duration = 1, xOffset = 0, yOffset = 0, key = nil, frameLevel = 0}

function WF.GlowEngine:EnsureHost(frame)
    if not frame then return nil end
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

    if host:GetParent() ~= target then host:SetParent(target) end
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", target, "TOPLEFT", -0.05, -0.05)
    host:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, -0.05)
    host:SetFrameLevel((target:GetFrameLevel() or 1) + 5)
    if not frame._wfGlowEngineHooked then
        frame:HookScript("OnHide", function()
            WF.GlowEngine:StopAllGlows(frame)
        end)
        frame._wfGlowEngineHooked = true
    end

    return host
end

function WF.GlowEngine:ApplyGlow(targetFrame, glowKey, options)
    if not LCG or not targetFrame or not options then return end
    
    local host = self:EnsureHost(targetFrame)
    if not host then return end
    self:StopGlow(targetFrame, glowKey)

    if not options.enable then return end

    local colorArr = nil
    if options.useCustomColor then
        local c = options.color
        if c then
            cachedColor[1] = c.r or 1; cachedColor[2] = c.g or 1; cachedColor[3] = c.b or 1; cachedColor[4] = c.a or 1
        else
            cachedColor[1] = 1; cachedColor[2] = 1; cachedColor[3] = 1; cachedColor[4] = 1
        end
        colorArr = cachedColor
    end
    
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
        cachedProcOpts.color = colorArr
        cachedProcOpts.duration = tonumber(options.procDuration) or 1
        cachedProcOpts.xOffset = tonumber(options.procXOffset) or 0
        cachedProcOpts.yOffset = tonumber(options.procYOffset) or 0
        cachedProcOpts.key = glowKey
        LCG.ProcGlow_Start(host, cachedProcOpts)
    end
end

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