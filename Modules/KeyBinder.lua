local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local KB = WUI:NewModule('WishFlex_KeyBinder', 'AceEvent-3.0')

-- =====================================================================
-- 1. 默认数据库与设置面板注入
-- =====================================================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.keybinder = true

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.system = WUI.OptionsArgs.system or { order = 50, type = "group", name = "|cff0099cc系统设置|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.system.args.keybind = {
        order = 1, type = "group", name = "快捷键同步",
        args = {
            syncGrp = { order = 1, type = "group", name = "动作条快捷键同步", guiInline = true, args = { run = { order = 1, type = "execute", name = "同步动作条按键", func = function() KB:ApplyBindings() end }, desc = { order = 2, type = "description", name = "" } } },
            hotkeyGrp = { order = 2, type = "group", name = "动作条隐藏/显示", guiInline = true, args = { key = { order = 1, type = "keybinding", name = "显示/隐藏", get = function() return GetBindingKey("CLICK WishFlex_ToggleBarsButton:LeftButton") end, set = function(_, key) local old = GetBindingKey("CLICK WishFlex_ToggleBarsButton:LeftButton") if old then SetBinding(old, nil) end if key ~= "" then SetBinding(key, "CLICK WishFlex_ToggleBarsButton:LeftButton") end SaveBindings(GetCurrentBindingSet()) end } } }
        }
    }
end

-- =====================================================================
-- 2. 核心功能逻辑
-- =====================================================================
local toggleBtn = CreateFrame("Button", "WishFlex_ToggleBarsButton", UIParent)
toggleBtn:SetScript("OnClick", function()
    local AB = E:GetModule('ActionBars')
    local bars = {1, 2, 3, 4, 5, 6}
    local currentState = E.db.actionbar["bar1"].visibility
    local nextState = (currentState ~= "hide") and "hide" or ""
    
    for _, n in pairs(bars) do
        local barName = "bar"..n
        E.db.actionbar[barName].visibility = nextState
        if AB and AB.PositionAndSizeBar then AB:PositionAndSizeBar(barName) end
    end
    local statusText = (nextState == "hide") and "|cffff0000已隐藏|r" or "|cff00ff00已显示|r"
    UIErrorsFrame:AddMessage("|cff00ffccWishFlex:|r 动作条 1-6 " .. statusText, 1.0, 1.0, 1.0, 1)
end)

_G["BINDING_HEADER_WishFlex"] = "|cff00ffccWishFlex|r"
_G["BINDING_NAME_CLICK WishFlex_ToggleBarsButton:LeftButton"] = "显示/隐藏动作条 1-6"

local BindingKeyGroup = {
    {key = "W", action = "MOVEFORWARD"}, {key = "S", action = "MOVEBACKWARD"}, {key = "A", action = "STRAFELEFT"}, {key = "D", action = "STRAFERIGHT"}, {key = "SPACE", action = "JUMP"}, {key = "=", action = "TOGGLERUN"}, {key = "`", action = "TOGGLEAUTORUN"}, {key = "N", action = "INTERACTTARGET"}, {key = "TAB", action = "TARGETNEARESTENEMY"}, {key = "F12", action = "TOGGLEPINGLISTENER"},
    {key = "ALT-MOUSEWHEELUP", action = "CAMERAZOOMIN"}, {key = "ALT-MOUSEWHEELDOWN", action = "CAMERAZOOMOUT"}, {key = "SHIFT-V", action = "FRIENDNAMEPLATES"}, {key = "CTRL-V", action = "ALLNAMEPLATES"},
    {key = "ESCAPE", action = "TOGGLEGAMEMENU"}, {key = "B", action = "OPENALLBAGS"}, {key = "SHIFT-C", action = "TOGGLECHARACTER0"}, {key = "ENTER", action = "OPENCHAT"}, {key = "U", action = "TOGGLECHARACTER2"}, {key = "P", action = "TOGGLESPELLBOOK"}, {key = "Y", action = "TOGGLEACHIEVEMENT"}, {key = "K", action = "TOGGLEPROFESSIONBOOK"}, {key = "L", action = "TOGGLEQUESTLOG"}, {key = "M", action = "TOGGLEWORLDMAP"}, {key = "J", action = "TOGGLEGUILDTAB"}, {key = "O", action = "TOGGLESOCIAL"}, {key = "I", action = "TOGGLEGROUPFINDER"}, {key = "H", action = "TOGGLECHARACTER4"}, {key = "SHIFT-P", action = "TOGGLECOLLECTIONS"}, {key = "SHIFT-J", action = "TOGGLEENCOUNTERJOURNAL"}, {key = "SHIFT-K", action = "TOGGLEGARRISONLANDINGPAGE"}, {key = "SHIFT-M", action = "TOGGLEBATTLEFIELDMINIMAP"}, {key = "SHIFT-N", action = "TOGGLETALENTS"},
    {key = "1", action = "ACTIONBUTTON1"}, {key = "2", action = "ACTIONBUTTON2"}, {key = "3", action = "ACTIONBUTTON3"}, {key = "4", action = "ACTIONBUTTON4"}, {key = "5", action = "ACTIONBUTTON5"}, {key = "ALT-G", action = "ACTIONBUTTON6"}, {key = "ALT-R", action = "ACTIONBUTTON7"}, {key = "SHIFT-F", action = "ACTIONBUTTON8"}, {key = "SHIFT-E", action = "ACTIONBUTTON9"}, {key = "SHIFT-G", action = "ACTIONBUTTON10"}, {key = "SHIFT-R", action = "ACTIONBUTTON11"},
    {key = "Q", action = "CLICK ElvUI_Bar2Button1:LeftButton"}, {key = "E", action = "CLICK ElvUI_Bar2Button2:LeftButton"}, {key = "R", action = "CLICK ElvUI_Bar2Button3:LeftButton"}, {key = "T", action = "CLICK ElvUI_Bar2Button4:LeftButton"}, {key = "F", action = "CLICK ElvUI_Bar2Button5:LeftButton"}, {key = "G", action = "CLICK ElvUI_Bar2Button6:LeftButton"}, {key = "V", action = "CLICK ElvUI_Bar2Button7:LeftButton"}, {key = "C", action = "CLICK ElvUI_Bar2Button8:LeftButton"}, {key = "X", action = "CLICK ElvUI_Bar2Button9:LeftButton"}, {key = "Z", action = "CLICK ElvUI_Bar2Button10:LeftButton"}, {key = "CAPSLOCK", action = "CLICK ElvUI_Bar2Button11:LeftButton"}, {key = "BUTTON3", action = "CLICK ElvUI_Bar2Button12:LeftButton"},
    {key = "SHIFT-1", action = "CLICK ElvUI_Bar3Button1:LeftButton"}, {key = "SHIFT-2", action = "CLICK ElvUI_Bar3Button2:LeftButton"}, {key = "SHIFT-3", action = "CLICK ElvUI_Bar3Button3:LeftButton"}, {key = "SHIFT-4", action = "CLICK ElvUI_Bar3Button4:LeftButton"}, {key = "ALT-1", action = "CLICK ElvUI_Bar3Button5:LeftButton"}, {key = "ALT-2", action = "CLICK ElvUI_Bar3Button6:LeftButton"}, {key = "ALT-3", action = "CLICK ElvUI_Bar3Button7:LeftButton"}, {key = "ALT-4", action = "CLICK ElvUI_Bar3Button8:LeftButton"}, {key = "F1", action = "CLICK ElvUI_Bar3Button9:LeftButton"}, {key = "F2", action = "CLICK ElvUI_Bar3Button10:LeftButton"}, {key = "F3", action = "CLICK ElvUI_Bar3Button11:LeftButton"}, {key = "F4", action = "CLICK ElvUI_Bar3Button12:LeftButton"},
    {key = "CTRL-1", action = "CLICK ElvUI_Bar4Button12:LeftButton"}, {key = "CTRL-2", action = "CLICK ElvUI_Bar4Button11:LeftButton"}, {key = "CTRL-3", action = "CLICK ElvUI_Bar4Button10:LeftButton"}, {key = "CTRL-4", action = "CLICK ElvUI_Bar4Button9:LeftButton"}, {key = "ALT-5", action = "CLICK ElvUI_Bar4Button8:LeftButton"}, {key = "ALT-6", action = "CLICK ElvUI_Bar4Button7:LeftButton"}, {key = "ALT-Q", action = "CLICK ElvUI_Bar4Button6:LeftButton"}, {key = "ALT-F", action = "CLICK ElvUI_Bar4Button5:LeftButton"}, {key = "MOUSEWHEELUP", action = "CLICK ElvUI_Bar4Button4:LeftButton"}, {key = "MOUSEWHEELDOWN", action = "CLICK ElvUI_Bar4Button3:LeftButton"}, {key = "SHIFT-MOUSEWHEELUP", action = "CLICK ElvUI_Bar4Button2:LeftButton"}, {key = "SHIFT-MOUSEWHEELDOWN", action = "CLICK ElvUI_Bar4Button1:LeftButton"},
}

function KB:ApplyBindings()
    local currentCustomKey = GetBindingKey("CLICK WishFlex_ToggleBarsButton:LeftButton")
    for i = 1, GetNumBindings() do
        local _, k1, k2 = GetBinding(i)
        if k1 then SetBinding(k1, nil) end
        if k2 then SetBinding(k2, nil) end
    end
    for _, v in ipairs(BindingKeyGroup) do SetBinding(v.key, v.action) end
    if currentCustomKey then SetBinding(currentCustomKey, "CLICK WishFlex_ToggleBarsButton:LeftButton") end
    SaveBindings(GetCurrentBindingSet())
    E:Print("|cff00ffccWishFlex:|r |cffffffff全套快捷键初始化成功！|r")
end

function KB:Initialize()
    InjectOptions()
    if not E.db.WishFlex.modules.keybinder then return end
end