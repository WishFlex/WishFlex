local AddonName, ns = ...
local WF = ns.WF
local L = ns.L or {}
local LCG = LibStub("LibCustomGlow-1.0", true)

local Glow = {}
WF.GlowAPI = Glow 

local GLOW_KEY = "WishFlex_CD_GLOW"
local activeGlowFrames = setmetatable({}, { __mode = "k" })
Glow._colorArr = {}

local DefaultConfig = {
    enable = true, glowType = "pixel", useCustomColor = true,
    color = { r = 1, g = 1, b = 1, a = 1 },
    pixelLines = 8, pixelFrequency = 0.25, pixelLength = 0, 
    pixelThickness = 1, 
    pixelXOffset = 0, pixelYOffset = 0,
    autocastParticles = 4, autocastFrequency = 0.2, autocastScale = 1, autocastXOffset = 0, autocastYOffset = 0,
    buttonFrequency = 0, procDuration = 1, procXOffset = 0, procYOffset = 0
}

local function GetDB()
    if not WF.db then WF.db = {} end
    if not WF.db.glow then WF.db.glow = {} end
    local db = WF.db.glow
    for k, v in pairs(DefaultConfig) do if db[k] == nil then db[k] = v end end
    return db
end

-- 接收明确的 w, h 尺寸，掐断 0 尺寸的源头
local function EnsureGlowHost(frame, targetW, targetH)
    local target = frame.wishBd or frame
    if frame.Icon and type(frame.Icon) == "table" then
        if frame.Icon.wishBd then target = frame.Icon.wishBd
        elseif frame.Icon.Icon and frame.Icon.Icon.wishBd then target = frame.Icon.Icon.wishBd end
    end

    local host = frame.cdmGlowHost
    if not host then
        host = CreateFrame("Frame", nil, target) 
        host:SetClampedToScreen(false)
        frame.cdmGlowHost = host
    end

    if host:GetParent() ~= target then host:SetParent(target) end
    
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
    
    -- 【终极修复】：主动硬塞精准浮点尺寸（拒绝 math.floor，拒绝隐式 0 尺寸）
    if targetW and targetH and targetW > 0 and targetH > 0 then
        host:SetSize(targetW, targetH)
    else
        local tw, th = target:GetSize()
        host:SetSize(math.max(tw, 1), math.max(th, 1))
    end
    
    if target:GetFrameStrata() then host:SetFrameStrata(target:GetFrameStrata()) end
    host:SetFrameLevel((target:GetFrameLevel() or 1) + 5)
    return host, target
end

function Glow:Show(frame)
    if not LCG or not frame then return end
    
    local target = frame.wishBd or frame
    if frame.Icon and type(frame.Icon) == "table" then
        if frame.Icon.wishBd then target = frame.Icon.wishBd
        elseif frame.Icon.Icon and frame.Icon.Icon.wishBd then target = frame.Icon.Icon.wishBd end
    end

    if target.IsRectValid and not target:IsRectValid() then
        target:GetWidth() 
    end

    local w, h = target:GetSize()
    if w < 1 or h < 1 then
        return 
    end

    if not frame._wishGlowHideHooked then
        frame:HookScript("OnHide", function(self) WF.GlowAPI:Hide(self) end)
        frame._wishGlowHideHooked = true
    end

    if not frame._wishGlowSizeHooked then
        target:HookScript("OnSizeChanged", function()
            if activeGlowFrames[frame] then
                if frame._glowDebounce then frame._glowDebounce:Cancel() end
                frame._glowDebounce = C_Timer.NewTimer(0.1, function()
                    Glow:Hide(frame)
                    Glow:Show(frame)
                end)
            end
        end)
        frame._wishGlowSizeHooked = true
    end

    local db = GetDB()
    
    if activeGlowFrames[frame] == db.glowType then 
        local host = frame.cdmGlowHost
        if host and host:GetParent() ~= target then
            Glow:Hide(frame)
        else
            return 
        end
    end
    Glow:Hide(frame)
    
    local c = db.color or { r = 1, g = 1, b = 1, a = 1 }
    local colorArr = nil
    if db.useCustomColor then
        colorArr = Glow._colorArr
        colorArr[1] = c.r or 1; colorArr[2] = c.g or 1; colorArr[3] = c.b or 1; colorArr[4] = c.a or 1
    end
    
    local host = EnsureGlowHost(frame, w, h)
    
    if db.glowType == "pixel" then
        local len = db.pixelLength
        if not len or len == 0 then
            len = math.floor((w + h) * (2 / (db.pixelLines or 8) - 0.1))
        end
        local thick = tonumber(db.pixelThickness) or 1
        LCG.PixelGlow_Start(host, colorArr, db.pixelLines, db.pixelFrequency, len, thick, db.pixelXOffset, db.pixelYOffset, false, GLOW_KEY, 0)
    elseif db.glowType == "autocast" then
        LCG.AutoCastGlow_Start(host, colorArr, db.autocastParticles, db.autocastFrequency, db.autocastScale, db.autocastXOffset, db.autocastYOffset, GLOW_KEY, 0)
    elseif db.glowType == "button" then
        local freq = db.buttonFrequency; if freq == 0 then freq = nil end
        LCG.ButtonGlow_Start(host, colorArr, freq, 0)
    elseif db.glowType == "proc" then
        LCG.ProcGlow_Start(host, {color = colorArr, duration = db.procDuration, xOffset = db.procXOffset, yOffset = db.procYOffset, key = GLOW_KEY, frameLevel = 0})
    end

    activeGlowFrames[frame] = db.glowType
end

function Glow:Hide(frame)
    if not LCG or not frame then return end
    local host = frame.cdmGlowHost
    if host then
        LCG.PixelGlow_Stop(host, GLOW_KEY)
        LCG.AutoCastGlow_Stop(host, GLOW_KEY)
        LCG.ButtonGlow_Stop(host)
        LCG.ProcGlow_Stop(host, GLOW_KEY)
    end
    activeGlowFrames[frame] = nil
end

function Glow:RefreshAll()
    for frame in pairs(activeGlowFrames) do 
        local savedType = activeGlowFrames[frame]
        activeGlowFrames[frame] = nil
        self:Show(frame) 
    end
    if WF.UpdateCooldownGlows then WF.UpdateCooldownGlows() end
end

local function InitGlow()
    GetDB()
    if WF.RegisterEvent then
        WF:RegisterEvent("PLAYER_REGEN_DISABLED", function() C_Timer.After(0.15, function() Glow:RefreshAll() end) end)
        WF:RegisterEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, function() Glow:RefreshAll() end) end)
        WF:RegisterEvent("LOADING_SCREEN_DISABLED", function() C_Timer.After(1, function() Glow:RefreshAll() end) end)
    end
end

if WF.RegisterModule then WF:RegisterModule("Glow", L["Core Glow"] or "发光引擎", InitGlow) end