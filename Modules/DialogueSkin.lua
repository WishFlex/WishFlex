local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local MOD = WUI:NewModule('WishFlex_DialogueSkin', 'AceEvent-3.0')

P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.dialogueSkin = true

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.misc = WUI.OptionsArgs.misc or { order = 40, type = "group", name = "|cff00b3cc杂项|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.misc.args.general = WUI.OptionsArgs.misc.args.general or { order = 1, type = "group", name = "基础美化", args = {} }
    WUI.OptionsArgs.misc.args.general.args.dialogueSkin = { order = 3, type = "toggle", name = "NPC对话框极简美化", get = function() return E.db.WishFlex.modules.dialogueSkin end, set = function(_, v) E.db.WishFlex.modules.dialogueSkin = v; E:StaticPopup_Show("CONFIG_RL") end }
end

local function ApplyElvUISkin()
    local frame = _G["DUIQuestFrame"]
    if not frame then return end

    if frame.BackgroundFrame then frame.BackgroundFrame:SetAlpha(0); frame.BackgroundFrame:Hide() end
    
    if not frame.backdrop then
        frame:CreateBackdrop("Transparent", nil, true) 
        if frame.backdrop then
            frame.backdrop:SetFrameLevel(frame:GetFrameLevel() > 0 and frame:GetFrameLevel() - 1 or 0)
            frame.backdrop:SetAllPoints(frame)
        end
    end

    local regions = {frame:GetRegions()}
    for _, region in ipairs(regions) do
        if region:IsObjectType("Texture") then region:SetTexture(nil); region:SetAlpha(0) end
    end
    
    if frame.ContentFrame then
        local texts = {frame.ContentFrame:GetRegions()}
        for _, r in ipairs(texts) do
            if r:IsObjectType("FontString") then 
                r:SetTextColor(1, 1, 1) 
                r:SetShadowColor(0, 0, 0, 1)
                r:SetShadowOffset(1, -1)
            end
        end
    end
end

function MOD:OnEnable()
    InjectOptions()
    if not E.db.WishFlex.modules.dialogueSkin then return end
    self:RegisterEvent("GOSSIP_SHOW", ApplyElvUISkin)
    self:RegisterEvent("QUEST_DETAIL", ApplyElvUISkin)
    self:RegisterEvent("QUEST_GREETING", ApplyElvUISkin)

    E:Delay(1, function()
        if _G["DUIQuestFrame"] then
            _G["DUIQuestFrame"]:HookScript("OnShow", ApplyElvUISkin)
            if _G["DUIQuestFrame"]:IsShown() then ApplyElvUISkin() end
        end
    end)
end