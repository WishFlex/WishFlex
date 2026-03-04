local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local T = WUI:NewModule('WishFlex_Teleport', 'AceEvent-3.0')
local LSM = E.Libs.LSM

-- ==========================================
-- 1. 默认数据库注入
-- ==========================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.teleport = true
P["WishFlex"].teleport = {
    font = "Expressway", fontSize = 14, fontOutline = "OUTLINE",
    useCustomColor = false, fontColor = { r = 1, g = 0.5, b = 0 }, xOffset = 0, yOffset = 0,
}

-- ==========================================
-- 2. 设置菜单注入
-- ==========================================
local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { order = 30, type = "group", name = "|cff00cccc小工具|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.widgets.args.teleport = {
        order = 3, type = "group", name = "大秘传送门",
        get = function(info) return E.db.WishFlex.teleport[info[#info]] end,
        set = function(info, value) E.db.WishFlex.teleport[info[#info]] = value; T:UpdateAllStyles() end,
        args = {
            baseGrp = { order = 1, type = "group", name = "", guiInline = true, args = { enable = { order = 1, type = "toggle", name = "启用", get = function() return E.db.WishFlex.modules.teleport end, set = function(_, v) E.db.WishFlex.modules.teleport = v; E:StaticPopup_Show("CONFIG_RL") end }, useCustomColor = { order = 2, type = "toggle", name = "自定义颜色" } } },
            styleGrp = { order = 10, type = "group", name = "文本设置", guiInline = true, args = { font = { order = 1, type = "select", dialogControl = 'LSM30_Font', name = "字体", values = LSM:HashTable("font") }, fontSize = { order = 2, type = "range", name = "大小", min = 8, max = 60, step = 1 }, fontColor = { order = 3, type = "color", name = "颜色", get = function() local t = E.db.WishFlex.teleport.fontColor or {r=1,g=1,b=1} return t.r, t.g, t.b end, set = function(_, r, g, b) E.db.WishFlex.teleport.fontColor = {r=r,g=g,b=b}; T:UpdateAllStyles() end }, xOffset = { order = 4, type = "range", name = "X偏移", min = -1000, max = 1000, step = 1 }, yOffset = { order = 5, type = "range", name = "Y偏移", min = -1000, max = 1000, step = 1 } } }
        }
    }
end

-- ==========================================
-- 3. 核心逻辑 (保持原有功能不变)
-- ==========================================
local SEASON_MAPS = { [542]=1237215, [525]=1216786, [391]=367416, [392]=367416, [378]=354465, [499]=445444, [505]=445414, [503]=445417 }

local function GetScoreColor()
    local db = E.db.WishFlex.teleport
    if db.useCustomColor and db.fontColor then return db.fontColor.r, db.fontColor.g, db.fontColor.b end
    return 1.0, 0.5, 0.0
end

function T:UpdateAllStyles()
    if not _G.ChallengesFrame or not _G.ChallengesFrame:IsShown() then return end
    local icons = _G.ChallengesFrame.DungeonIcons
    if not icons then return end
    local db = E.db.WishFlex.teleport
    local font = LSM:Fetch('font', db.font or "Expressway")
    local r, g, b = GetScoreColor()
    for _, icon in ipairs(icons) do
        if icon.WishScore then
            icon.WishScore:SetFont(font, db.fontSize or 14, db.fontOutline or "OUTLINE")
            icon.WishScore:SetTextColor(r, g, b)
            icon.WishScore:ClearAllPoints()
            icon.WishScore:SetPoint("CENTER", icon, "CENTER", db.xOffset or 0, db.yOffset or 0)
        end
    end
end

function T:SetupIcon(icon)
    if not icon or not icon.mapID then return end
    local mID = icon.mapID
    local sID = SEASON_MAPS[mID]
    local db = E.db.WishFlex.teleport
    local font = LSM:Fetch('font', db.font or "Expressway")
    local r, g, b = GetScoreColor()

    if not icon.WishScore then icon.WishScore = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") end
    local score = select(2, C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mID)) or 0
    icon.WishScore:SetFont(font, db.fontSize or 14, db.fontOutline or "OUTLINE")
    icon.WishScore:ClearAllPoints()
    icon.WishScore:SetPoint("CENTER", icon, "CENTER", db.xOffset or 0, db.yOffset or 0)
    icon.WishScore:SetText(score > 0 and score or "")
    icon.WishScore:SetTextColor(r, g, b)
    icon.WishScore:Show()

    if sID then
        local btnName = "WishTeleBtn" .. mID
        local btn = _G[btnName] or CreateFrame("Button", btnName, icon, "InsecureActionButtonTemplate")
        btn:SetAllPoints(icon)
        btn:SetFrameStrata("HIGH") 
        btn:SetFrameLevel(icon:GetFrameLevel() + 50)
        btn:RegisterForClicks("AnyDown", "AnyUp") 
        if not InCombatLockdown() then
            local spellName = C_Spell.GetSpellName(sID)
            if spellName and IsSpellKnown(sID) then
                btn:SetAttribute("type", "spell")
                btn:SetAttribute("spell", spellName)
                btn:Show()
                btn:SetScript("OnEnter", function(self)
                    icon:GetScript("OnEnter")(icon) 
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cff00ffccWishFlex:|r 点击传送至 [" .. spellName .. "]")
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function() icon:GetScript("OnLeave")(icon); GameTooltip:Hide() end)
            else
                btn:Hide()
            end
        end
    end
end

function T:Initialize()
    InjectOptions()
    if not E.db.WishFlex.modules.teleport then return end
    local monitor = CreateFrame("Frame")
    monitor:SetScript("OnUpdate", function(self, elapsed)
        self.timer = (self.timer or 0) + elapsed
        if self.timer >= 0.2 then 
            if _G.ChallengesFrame and _G.ChallengesFrame:IsShown() then
                local icons = _G.ChallengesFrame.DungeonIcons
                if icons then for _, icon in ipairs(icons) do T:SetupIcon(icon) end end
            end
            self.timer = 0
        end
    end)
    self:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE", "UpdateAllStyles")
end