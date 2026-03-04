local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local MOD = WUI:NewModule('WishFlex_Silvermoon', 'AceEvent-3.0')
local LSM = E.Libs.LSM

-- =====================================================================
-- 1. 数据源：自带完美逻辑分类颜色的坐标库
-- =====================================================================
local RAW_PINS = {
    -- [通用服务设施]
    { name = "银行", x = 0.4993, y = 0.6454, color = {r=1, g=0.84, b=0} },       -- 金黄色
    { name = "装备升级", x = 0.4861, y = 0.6198, color = {r=1, g=0.5, b=0} },      -- 橙色
    { name = "拍卖行", x = 0.5150, y = 0.7468, color = {r=1, g=0.84, b=0} },      -- 金黄色
    { name = "传送门", x = 0.5337, y = 0.6631, color = {r=0.25, g=0.78, b=0.92} },-- 亮蓝色
    { name = "转换台", x = 0.4019, y = 0.6519, color = {r=0.8, g=0.4, b=1} },     -- 史诗紫
    { name = "旅店/烹饪", x = 0.5628, y = 0.7033, color = {r=1, g=1, b=1} },        -- 纯白色
    { name = "理发店", x = 0.4318, y = 0.7823, color = {r=1, g=0.4, b=0.7} },     -- 粉红色
    { name = "地下堡", x = 0.5250, y = 0.7821, color = {r=0.7, g=0.5, b=0.3} },   -- 大地棕
    { name = "制造订单", x = 0.4505, y = 0.5559, color = {r=0.4, g=0.8, b=1} },     -- 青色
    { name = "大秘境门", x = 0.4203, y = 0.5830, color = {r=1, g=0.2, b=0.2} },     -- 红色
    { name = "商栈", x = 0.4888, y = 0.7815, color = {r=0.6, g=0.8, b=1} },       -- 冰蓝色
    { name = "PvP", x = 0.3409, y = 0.8111, color = {r=1, g=0.1, b=0.1} },      -- 血红色
    { name = "木桩", x = 0.3678, y = 0.8565, color = {r=1, g=0.1, b=0.1} },       -- 血红色
    { name = "哈兰达尔", x = 0.3697, y = 0.6812, color = {r=0.6, g=0.2, b=0.8} },   -- 虚空紫
    { name = "虚空风暴", x = 0.3528, y = 0.6570, color = {r=0.6, g=0.2, b=0.8} },   -- 虚空紫
    
    -- [专业技能制造台] (统一绿色)
    { name = "炼金", x = 0.4702, y = 0.5188, color = {r=0.2, g=1, b=0.2} },
    { name = "锻造", x = 0.4374, y = 0.5133, color = {r=0.2, g=1, b=0.2} },
    { name = "附魔", x = 0.4797, y = 0.5363, color = {r=0.2, g=1, b=0.2} },
    { name = "工程", x = 0.4353, y = 0.5401, color = {r=0.2, g=1, b=0.2} },
    { name = "铭文", x = 0.4678, y = 0.5148, color = {r=0.2, g=1, b=0.2} },
    { name = "珠宝", x = 0.4793, y = 0.5515, color = {r=0.2, g=1, b=0.2} },
    { name = "制皮", x = 0.4315, y = 0.5570, color = {r=0.2, g=1, b=0.2} },
    { name = "裁缝", x = 0.4825, y = 0.5415, color = {r=0.2, g=1, b=0.2} },

    -- [部落专属设施]
    { name = "部落银行", x = 0.7256, y = 0.6455, faction = "Horde", color = {r=1, g=0.84, b=0} },
    { name = "部落旅店", x = 0.6694, y = 0.6214, faction = "Horde", color = {r=1, g=1, b=1} },
    { name = "部落拍卖", x = 0.6761, y = 0.7250, faction = "Horde", color = {r=1, g=0.84, b=0} },
    { name = "部落转换", x = 0.7012, y = 0.8329, faction = "Horde", color = {r=0.8, g=0.4, b=1} },
    { name = "部落炼金", x = 0.7389, y = 0.7434, faction = "Horde", color = {r=0.2, g=1, b=0.2} },
    { name = "部落锻造", x = 0.6969, y = 0.8451, faction = "Horde", color = {r=0.2, g=1, b=0.2} },
    { name = "部落附魔", x = 0.7289, y = 0.7154, faction = "Horde", color = {r=0.2, g=1, b=0.2} },
    { name = "部落工程", x = 0.6940, y = 0.8435, faction = "Horde", color = {r=0.2, g=1, b=0.2} },
    { name = "部落铭文", x = 0.7258, y = 0.7116, faction = "Horde", color = {r=0.2, g=1, b=0.2} },
    { name = "部落珠宝", x = 0.7370, y = 0.7057, faction = "Horde", color = {r=0.2, g=1, b=0.2} },
    { name = "部落制皮", x = 0.6981, y = 0.8117, faction = "Horde", color = {r=0.2, g=1, b=0.2} },
    { name = "部落裁缝", x = 0.7338, y = 0.7271, faction = "Horde", color = {r=0.2, g=1, b=0.2} },
}

-- =====================================================================
-- 2. 默认数据库注入 (极简设置)
-- =====================================================================
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.silvermoon = true
P["WishFlex"].silvermoon = {
    font = "Expressway", 
    fontSize = 60, -- 默认给大一点对抗地图缩放
    fontOutline = "OUTLINE", 
    useLogicalColor = true, -- 新增：是否使用逻辑颜色
    fontColor = {r=1, g=1, b=1},
}

-- =====================================================================
-- 3. 动态生成控制面板 (清爽纯净版)
-- =====================================================================
local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.misc = WUI.OptionsArgs.misc or { order = 40, type = "group", name = "|cff00b3cc杂项|r", childGroups = "tab", args = {} }
    
    WUI.OptionsArgs.misc.args.silvermoon = { 
        order = 6, type = "group", name = "12.0 银月城标记", 
        get = function(i) return E.db.WishFlex.silvermoon[i[#i]] end,
        set = function(i, v) E.db.WishFlex.silvermoon[i[#i]] = v; MOD:RefreshPins() end,
        args = {
            enable = { order = 1, type = "toggle", name = "启用银月城标记", get = function() return E.db.WishFlex.modules.silvermoon end, set = function(_, v) E.db.WishFlex.modules.silvermoon = v; MOD:RefreshPins() end },
            font = { order = 2, type = "select", dialogControl = 'LSM30_Font', name = "全局标记字体", values = LSM:HashTable("font") },
            fontSize = { order = 3, type = "range", name = "字体大小", min = 8, max = 200, step = 1 }, -- 突破上限到200！
            fontOutline = { order = 4, type = "select", name = "字体描边", values = { ["NONE"] = "无", ["OUTLINE"] = "普通", ["THICKOUTLINE"] = "粗描边" } },
            useLogicalColor = { order = 5, type = "toggle", name = "使用 NPC 专属颜色", desc = "开启后，银行显示金色、传送门蓝色、专业绿色等。关闭则统一使用下方的文字颜色。" },
            fontColor = { order = 6, type = "color", name = "全局文字颜色", disabled = function() return E.db.WishFlex.silvermoon.useLogicalColor end, get = function() local t = E.db.WishFlex.silvermoon.fontColor; return t.r, t.g, t.b end, set = function(_, r, g, b) E.db.WishFlex.silvermoon.fontColor = {r=r,g=g,b=b}; MOD:RefreshPins() end },
        }
    }
end

-- =====================================================================
-- 4. 核心渲染 (最高层级霸权防遮挡)
-- =====================================================================
local SILVERMOON_MAP_ID = 2393
local pins = {}

function MOD:RefreshPins()
    if not WorldMapFrame or not WorldMapFrame:GetCanvas() then return end
    
    local currentMapID = WorldMapFrame.mapID
    local isEnabled = E.db.WishFlex.modules.silvermoon
    local shouldShow = isEnabled and (currentMapID == SILVERMOON_MAP_ID)
    local db = E.db.WishFlex.silvermoon
    local myFaction = UnitFactionGroup("player")

    for i, data in ipairs(RAW_PINS) do
        local pin = pins[i]
        
        local factionShow = true
        if data.faction and data.faction ~= myFaction then factionShow = false end
        
        if not pin then
            pin = CreateFrame("Frame", nil, WorldMapFrame:GetCanvas())
            
            -- 【核心修复】：挂载最高系统层级 TOOLTIP，并在该层级中排到 9000，绝对不会被暴雪地图图标遮挡！
            pin:SetFrameStrata("TOOLTIP")
            pin:SetFrameLevel(9000)
            
            pin:SetSize(400, 60)
            
            pin.text = pin:CreateFontString(nil, "OVERLAY")
            pin.text:SetPoint("CENTER", pin, "CENTER", 0, 0)
            pin.text:SetWidth(0) 
            pin.text:SetWordWrap(false)
            
            pins[i] = pin
        end

        if shouldShow and factionShow then
            local fontPath = LSM:Fetch('font', db.font or "Expressway")
            pin.text:FontTemplate(fontPath, db.fontSize or 60, db.fontOutline or "OUTLINE")
            
            -- 【颜色逻辑判定】：
            if db.useLogicalColor and data.color then
                pin.text:SetTextColor(data.color.r, data.color.g, data.color.b)
            else
                local c = db.fontColor or {r=1, g=1, b=1}
                pin.text:SetTextColor(c.r, c.g, c.b)
            end
            
            pin.text:SetText(data.name)
            
            pin:ClearAllPoints()
            local canvas = WorldMapFrame:GetCanvas()
            local width = canvas:GetWidth()
            local height = canvas:GetHeight()
            pin:SetPoint("CENTER", canvas, "TOPLEFT", width * data.x, -height * data.y)
            pin:Show()
        else
            pin:Hide()
        end
    end
end

function MOD:OnEnable()
    InjectOptions()
    hooksecurefunc(WorldMapFrame, "OnMapChanged", function() MOD:RefreshPins() end)
    if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetCanvas then
        hooksecurefunc(WorldMapFrame.ScrollContainer, "MarkCanvasDirty", function() 
            C_Timer.After(0.01, function() MOD:RefreshPins() end)
        end)
    end
end