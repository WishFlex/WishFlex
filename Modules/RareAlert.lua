local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local MOD = WUI:NewModule('RareAlert', 'AceEvent-3.0', 'AceTimer-3.0')
local LCG = LibStub("LibCustomGlow-1.0", true)
local S = E:GetModule('Skins')
local LSM = E.Libs.LSM

-- ==========================================
-- 1. 默认数据库注入
-- ==========================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.rareAlert = true
P["WishFlex"].rareAlert = {
    enable = true, sound = "Warning", soundID = 11466,
}

-- ==========================================
-- 2. 设置菜单注入
-- ==========================================
local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { order = 30, type = "group", name = "|cff00cccc小工具|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.widgets.args.rareAlert = {
        order = 4, type = "group", name = "稀有报警",
        args = {
            enable = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.modules.rareAlert end, set = function(_, v) E.db.WishFlex.modules.rareAlert = v; E:StaticPopup_Show("CONFIG_RL") end },
            sound = { order = 2, type = "select", dialogControl = 'LSM30_Sound', name = "警报声音", values = LSM:HashTable("sound"), get = function() return E.db.WishFlex.rareAlert.sound end, set = function(_, v) E.db.WishFlex.rareAlert.sound = v end },
            test = { order = 3, type = "execute", name = "测试报警", func = function() MOD:TestAlert() end },
        }
    }
end

-- ==========================================
-- 3. 核心逻辑 (保持原有功能不变)
-- ==========================================
local STRIPE_TEX = [[Interface\AddOns\ElvUI_WishFlex\Media\stripes.blp]]
local lastAlertName = ""

function MOD:CreateAlertFrame()
    if self.frame then return end
    local holder = CreateFrame("Frame", "WishFlex_RareAlertHolder", E.UIParent)
    holder:SetSize(280, 60)
    holder:SetPoint("TOP", E.UIParent, "TOP", 0, -180)
    self.holder = holder

    local f = CreateFrame("Button", "WishFlex_RareAlertFrame", holder, "SecureActionButtonTemplate, BackdropTemplate")
    f:SetSize(280, 60)
    f:SetPoint("CENTER", holder, "CENTER")
    f:SetTemplate("Transparent")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:RegisterForClicks("AnyUp", "AnyDown")
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetInside()
    bg:SetTexture(STRIPE_TEX)
    bg:SetAlpha(0.7)
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    f.bg = bg

    local portrait = CreateFrame("PlayerModel", nil, f)
    portrait:SetSize(48, 48)
    portrait:SetPoint("LEFT", f, "LEFT", 8, 0)
    f.portrait = portrait
    
    local portraitBack = CreateFrame("Frame", nil, f, "BackdropTemplate")
    portraitBack:SetAllPoints(portrait)
    portraitBack:SetTemplate("Default")
    portraitBack:SetFrameLevel(f:GetFrameLevel() + 1)
    portrait:SetParent(portraitBack)

    local text = f:CreateFontString(nil, "OVERLAY")
    text:FontTemplate(nil, 16, "OUTLINE")
    text:SetPoint("LEFT", portrait, "RIGHT", 15, 0)
    text:SetJustifyH("LEFT")
    f.text = text

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    if S then S:HandleCloseButton(close) end
    close:SetScript("OnClick", function() if LCG then LCG.PixelGlow_Stop(f) end; f:Hide() end)
    f.close = close

    self.frame = f
    E:CreateMover(holder, "WishFlex_RareAlertMover", "稀有精英报警", nil, nil, nil, "ALL,WishFlex")
end

function MOD:TriggerAlert(name, unit)
    if not name or name == "" then return end
    if lastAlertName == name and name ~= "测试稀有精英" then return end
    
    lastAlertName = name
    E:Delay(10, function() lastAlertName = "" end)

    self:CreateAlertFrame()
    if unit and UnitExists(unit) then self.frame.portrait:SetUnit(unit) else self.frame.portrait:SetUnit("player") end
    self.frame.portrait:SetCamera(0)

    self.frame.text:SetText("|cff00ffcc发现稀有!|r\n" .. name)
    self.frame:Show()

    if not InCombatLockdown() then
        self.frame:SetAttribute("type", "macro")
        self.frame:SetAttribute("macrotext", "/target " .. name .. "\n/tm 8")
    end

    if LCG then
        LCG.PixelGlow_Stop(self.frame)
        LCG.PixelGlow_Start(self.frame, {0, 1, 0.8, 1}, 8, 0.2, 35, 1)
    end

    local db = E.db.WishFlex.rareAlert
    local soundPath = db and db.sound and LSM:Fetch("sound", db.sound)
    if soundPath then PlaySoundFile(soundPath, "Master") else PlaySound(11466, "Master") end

    if self.hideTimer then E:CancelTimer(self.hideTimer) end
    self.hideTimer = E:Delay(10, function() 
        if LCG then LCG.PixelGlow_Stop(self.frame) end
        self.frame:Hide(); self.hideTimer = nil
    end)
end

function MOD:TestAlert()
    if self.frame then self.frame:Hide() end
    self:TriggerAlert("测试稀有精英", "player")
end

function MOD:CheckVignette(vignetteGUID)
    local getInfoFunc = C_VignetteInfo.GetVignetteInfoFromGUID or C_VignetteInfo.GetVignetteInfoByGUID
    if getInfoFunc then
        local info = getInfoFunc(vignetteGUID)
        if info and info.name then self:TriggerAlert(info.name, nil) end
    end
end

function MOD:CheckUnit(unit)
    if not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local class = UnitClassification(unit)
    if class == "rare" or class == "rareelite" then self:TriggerAlert(UnitName(unit), unit) end
end

function MOD:Initialize()
    InjectOptions()
    if not E.db.WishFlex.modules.rareAlert then return end
    self:CreateAlertFrame()
    self:RegisterEvent("VIGNETTE_MINIMAP_UPDATED", function(_, id) if id then self:CheckVignette(id) end end)
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit) self:CheckUnit(unit) end)
    self:RegisterEvent("PLAYER_TARGET_CHANGED", function() self:CheckUnit("target") end)
end