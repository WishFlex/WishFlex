local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WF = E:GetModule('WishFlex')

-- 确保总收集器存在
WF.OptionsArgs = WF.OptionsArgs or {}

-- 载入顶层 Logo
WF.OptionsArgs.logoHeader = {
    order = 1, type = "group", name = " ", guiInline = true,
    args = {
        title = {
            order = 1, type = "description", fontSize = "large",
            name = "\n\n                                     |cff00ffcc W  I  S  H    F  L  E  X \r\n                                    |cff888888V E R S I O N   2 . 0\r\n\n|cff444444━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━|r"
        }
    }
}

-- 【安全挂载】：通过 ElvUI 标准接口插入，保证不丢失，并更名为 WishFlex
local function SetupWishFlexOptions()
    E.Options.args.WishFlex = {
        type = "group",
        name = "|cff00ffccWishFlex|r",
        order = 6,
        childGroups = "tree", 
        args = WF.OptionsArgs 
    }
end

-- 无论 ElvUI 界面处于何种加载阶段，确保菜单能安全打入
tinsert(E.ConfigModeLayouts, SetupWishFlexOptions)
if E.Options and E.Options.args then
    SetupWishFlexOptions()
end