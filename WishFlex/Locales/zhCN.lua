local AddonName, ns = ...
local locale = GetLocale()
if locale ~= "zhCN" and locale ~= "zhTW" then return end

local L = ns.L

-- ============================================================================
-- 菜单与导航栏
-- ============================================================================
L["WishFlex Settings"] = "WishFlex 设置"
L["Settings Console"] = "设置中心"
L["Combat"] = "战斗"
L["Cooldown Manager"] = "冷却管理器"
L["Class Resource"] = "资源条"
L["Action Button Glow"] = "发光"

-- ============================================================================
-- 侧边栏及其他模块通用标题 (必须保留)
-- ============================================================================
L["Global Settings"] = "全局"
L["Core Glow"] = "发光"
L["Essential Skills"] = "重要技能"
L["Utility Skills"] = "效能技能"
L["Buff Icons"] = "增益图标"
L["Buff Bars"] = "增益条"
L["Icon Desaturation"] = "自定义图标 (褪色)"
L["Home"] = "主页"
L["MENU"] = "菜单"
L["Reload UI"] = "重载界面"
L["Author"] = "开发与维护"
L["Enter Edit Mode"] = "编辑模式"
-- 能量类型 (Power Types)
L["All Types"] = "所有类型 (默认)"
L["Mana"] = "法力值"
L["Rage"] = "怒气值"
L["Focus"] = "集中值"
L["Energy"] = "能量值"
L["Runic Power"] = "符文能量"
L["Astral Power"] = "星界能量"
L["Maelstrom"] = "漩涡值"
L["Insanity"] = "狂乱值"
L["Fury"] = "恶魔怒气"
L["Essence"] = "精华"
-- ============================================================================
-- 补漏：资源条与自定义排版进阶设置
-- ============================================================================
L["No Spec / General"] = "无专精 / 通用"
L["Enable Independent Texture"] = "启用自定义材质"
L["Enable Independent Color"] = "启用自定义颜色"
L["Enable Independent Background Texture"] = "启用自定义背景材质"
L["Independent Background Texture"] = "自定义背景材质"
L["Enable Independent Background Color"] = "启用自定义背景色"
L["Applicable Power Type"] = "限定生效的能量类型"
L["Custom Monitor"] = "自定义监控"
-- ============================================================================
-- 主页 (Home.lua) 专属展示文本 (新增)
-- ============================================================================
L["WishFlex GeniSys"] = "WishFlex CDM"
L["Home Intro Desc"] = "一款追求极致排版与性能的轻量级无限制优化套装。"

L["GuideTitle1"] = "可视排版"
L["GuideBody1"] = "点击顶部齿轮即可解锁所有框体\n随意移动框体布局支持坐标与微调"
L["GuideTitle2"] = "极简操作"
L["GuideBody2"] = "在预览模式下无需寻找繁琐的菜单\n直接【左右键点击】图标即可调出设置"
L["GuideTitle3"] = "智能隐藏"
L["GuideBody3"] = "在右键菜单中点击【显示隐藏设置】\n即可自定义开启脱战隐藏、条件隐藏等"
L["GuideTitle4"] = "发光设置"
L["GuideBody4"] = "通过右键菜单进入【详细发光设置】\n支持原生高亮接管与自定义高亮调节"

-- ============================================================================
-- UI & Core 通用与提示
-- ============================================================================
L["One or more settings require a UI reload to take effect."] = "部分设置/配置切换需要重载界面(RL)才能生效。"
L["Apply Class Color"] = "一键应用职业色"
L["Entering Edit Mode"] = "正在进入暴雪编辑模式..."
L["Edit Mode not available."] = "编辑模式不可用。"
L["Open Settings Panel"] = "打开设置控制台"

-- ============================================================================
-- 导入导出系统与配置文件 (Profiles)
-- ============================================================================
L["Profile"] = "配置"
L["Profile Management"] = "配置"
L["Profile Management Title"] = "|cff00ffcc[0]|r 配置文件管理 (Profiles)"
L["Select and Apply Profile:"] = "选择并应用配置:"
L["New/Copy Current Profile:"] = "新建/复制当前配置:"
L["Create"] = "创建"
L["Profile name invalid or already exists!"] = "|cffff0000[WishFlex]|r 配置文件名称无效或已存在！"
L["Spec Auto-Load Binding"] = "专精自动加载绑定"
L["None"] = "不绑定"
L[" Auto-Load:"] = " 自动加载:"
L["Missing dependencies LibSerialize or LibDeflate."] = "|cffff0000[错误]|r 缺少依赖库 LibSerialize 或 LibDeflate，导入导出功能无法启用。"
L["Export Profile"] = "|cff00ffcc[1]|r 导出配置 (生成代码分享)"
L["Import Profile"] = "|cffffaa00[2]|r 导入配置 (覆盖现有设置)"
L["Export All (Recommended)"] = "【全局】导出所有配置 (推荐)"
L["Cooldown Manager (CD)"] = "冷却管理器"
L["Class Resource (CR)"] = "资源条"
L["Generate Export Code"] = "生成导出代码"
L["Export string generated successfully."] = "|cff00ffcc[WishFlex]|r 导出字符串生成成功，已自动选中。按下 Ctrl+C 复制。"
L["Clear Input"] = "清空输入框"
L["Paste your WishFlex profile code below:"] = "请在下方输入框中粘贴您的 WishFlex 配置代码："
L["Parse and Import"] = "解析并导入代码"
L["Import failed: Invalid format."] = "|cffff0000[WishFlex]|r 导入失败：字符串格式不正确。"
L["Import failed: Cannot decode."] = "|cffff0000[WishFlex]|r 导入失败：无法解码。"
L["Import failed: Cannot decompress."] = "|cffff0000[WishFlex]|r 导入失败：无法解压。"
L["Import failed: Data corrupted."] = "|cffff0000[WishFlex]|r 导入失败：数据结构损坏。"
L["Successfully imported "] = "|cff00ff00[WishFlex]|r 成功导入了 ["
L[" profile! Reloading..."] = "] 模块配置！正在重载界面..."
L["Profile Desc"] = "在此处备份或分享您的专属配置。您可以精确选择导出自定义的模块，或者导出整个插件的全部设置。\n将他人分享的代码字符串粘贴至下方，并点击导入，系统将自动为您合并配置并重载界面。"
L["Open Blizzard CD Settings"] = "打开高级冷却设置 (/cds)"

-- ============================================================================
-- 标准化通用术语 (UI Standard Terminology)
-- ============================================================================
L["Enable"] = "启用"
L["Disable"] = "停用"
L["Enable Module"] = "启用"
L["Width"] = "宽度"
L["Height"] = "高度"
L["Texture"] = "材质"
L["Font"] = "字体"
L["Color"] = "颜色"
L["Background Color"] = "背景色"
L["Font Size"] = "文本大小"
L["Text Color"] = "文本颜色"
L["X Offset"] = "X轴偏移"
L["Y Offset"] = "Y轴偏移"
L["Anchor"] = "对齐方向"
L["Stack Spacing"] = "堆叠间距"
L["Attach to Cooldowns"] = "吸附到冷却管理器"
L["Attach Y Offset"] = "吸附 Y轴偏移"
L["Width Compensation"] = "宽度强行补偿"
L["Independent Layout"] = "自定义排版"
L["Independent Texture"] = "自定义材质"
L["Independent Background Color"] = "自定义背景色与透明度"
L["Icon Gap"] = "间距"
L["Max Per Row"] = "每行最大图标数"
L["Attach To Player"] = "玩家框体"
L["Total Width"] = "整体宽度"

-- ============================================================================
-- 模块：总开关与警告
-- ============================================================================
L["Disable CD & EM"] = "|cffff5555关闭冷却管理器|r"
L["Enable CD & EM"] = "|cff55ff55启用冷却管理器|r"
L["CD System Disabled Msg"] = "冷却管理器已关闭 \n\n- 系统底层挂载已完全熔断断流。\n- 内存占用与渲染循环已清空释放。\n- 排版沙盒与多余设置项已隐藏。\n\n如需使用，请点击上方【启用】按钮并重载界面。"
L["Disable CR & Monitor"] = "|cffff5555关闭资源条|r"
L["Enable CR & Monitor"] = "|cff55ff55启用资源条|r"
L["CR System Disabled Msg"] = "资源条已关闭 \n\n- 系统底层渲染计算已完全拦截。\n- 全部框体与材质已经从内存中清空隐藏。\n- 排版沙盒面板已隐藏消失。\n\n如需使用，请点击上方【启用】按钮并重载界面。"

-- ============================================================================
-- 模块：沙盒操作提示
-- ============================================================================
L["Refresh Sandbox / Fetch Data"] = "刷新沙盒 / 抓取当前数据"
L["Operation Guide"] = "操作指南"
L["Sandbox Operation Guide"] = "【沙盒操作指南】"
L["Left Click"] = "左键"
L["Right Click"] = "右键"
L["Drag"] = "拖拽"
L["Click group background or icon to setup layout"] = "点击组背景或图标：设置该组排版"
L["Click number text to adjust font and offset"] = "点击数字文本：调整字体与偏移"
L["Click icon to open toggle and style menu"] = "点击图标：呼出开关与样式菜单"
L["Hold left click to reorder icons within same group type"] = "按住图标：同类组间自由排列与移组"
L["Click bar or placeholder to setup size"] = "点击条本身或占位框：设置外观尺寸"
L["Click text to setup text layout"] = "点击对应文本：设置文本排版"
L["Hold bar to reorder"] = "按住条拖动：插队到任意顺序"
L["Click bar or placeholder to open quick toggle menu"] = "点击条本身或占位框：呼出快捷开关与删除"
L["Edit text layout"] = "编辑该文本专属排版"

-- ============================================================================
-- 模块：自定义组与其他杂项
-- ============================================================================
L["Extra Monitor (Item/Racial)"] = "额外监控 (物品/种族)"
L["Custom Buff Group "] = "自定义增益组 "
L["Custom Skill Group "] = "自定义技能组 "
L["Click to setup or drag icon here (Empty)"] = "点击设置或拖入图标 (空)"
L["(Currently Disabled)"] = "(当前已停用)"
L["Add Custom Skill Group"] = "新增自定义技能组"
L["Add Custom Buff Group"] = "新增自定义增益组"
L["Sandbox"] = "沙盒"

-- ============================================================================
-- 模块：资源条 (Class Resource)
-- ============================================================================
L["Power Bar"] = "能量条"
L["Class Resource Bar"] = "主资源条"
L["Extra Mana Bar"] = "额外法力条"
L["Vigor Bar"] = "驭空术资源条"
L["Whirling Surge Bar"] = "回旋冲刺条"
L["Global Layout & Settings"] = "全局排版设置"
L["Global Basic Layout"] = "全局通用排版设定"
L["Enable Resource System"] = "启用资源条系统"
L["Editing Context"] = "正在编辑的专精配置"
L["Layout & Size"] = "布局与尺寸"
L["Basic Appearance"] = "基础外观设定"
L["Text Style"] = "文本样式"
L["Enable Main Text"] = "启用主文本"
L["Main Text Anchor"] = "主文本对齐方向"
L["Main Text X Offset"] = "主文本 X轴偏移"
L["Main Text Y Offset"] = "主文本 Y轴偏移"
L["Enable Timer Text"] = "启用倒计时文本"
L["Timer Text Anchor"] = "倒计时文本对齐方向"
L["Timer Text X Offset"] = "倒计时文本 X轴偏移"
L["Timer Text Y Offset"] = "倒计时文本 Y轴偏移"
L["Text Layout"] = "文本排版"

-- 资源条变色与刻度
L["Multi-stage Threshold Color"] = "多段数值变色设置"
L["Enable Multi-stage Color"] = "启用多段变色引擎"
L["Select Stage"] = "选择变色阶段"
L["Stage 1"] = "阶段 1"
L["Stage 2"] = "阶段 2"
L["Stage 3"] = "阶段 3"
L["Stage 4"] = "阶段 4"
L["Stage 5"] = "阶段 5"
L["Enable This Stage"] = "启用此阶段"
L["Trigger Value"] = "触发数值"
L["Threshold Color"] = "突变颜色"
L["Threshold Lines"] = "多重刻度线设置"
L["Select Line"] = "选择刻度线"
L["Thickness"] = "粗细"

-- 资源条：添加自定义监控沙盒
L["Monitor Management"] = "监控管理"
L["Enable Monitor"] = "启用此监控"
L["Disable Monitor"] = "停用此监控"
L["Add Custom Monitor"] = "新增监控"
L["Monitor Type"] = "监控类型"
L["Aura/Buff"] = "光环/增益"
L["Spell/Skill"] = "法术/技能"
L["Display Mode"] = "表现形式"
L["Status Bar"] = "进度条"
L["Pure Text"] = "纯文本"
L["Skill Mechanism"] = "技能机制"
L["Single Cooldown"] = "单次冷却"
L["Multiple Charges"] = "多次充能"
L["Buff Mechanism"] = "增益机制"
L["Duration"] = "持续时间"
L["Stacking"] = "层数堆叠"
L["Max Stacks"] = "最大层数"
L["Click to select target"] = "点击选择目标 (基于当前专精原生扫描):"
L["No Data"] = "暂无数据"
L["Confirm Add"] = "确认添加"

-- 资源条：编辑自定义监控
L["Bar Layout"] = "条排版"
L["Pure Text Layout"] = "纯文本排版"
L["Visuals & Positioning"] = "外观排版与位置"
L["Always Show Background"] = "常驻显示"
L["Reverse Fill"] = "反向填充"
L["Foreground Color"] = "前景色"
L["Enable Independent Background"] = "启用自定义背景色"
L["Hide in Original UI"] = "隐藏图标"
L["Timer Text Layout (No Stacks)"] = "倒计时文本排版"
L["Delete This Monitor"] = "删除此监控"
L["Monitor Not Found"] = "该监控不存在或已删除"

-- 九宫格锚点
L["TOPLEFT"] = "左上"
L["TOP"] = "顶部"
L["TOPRIGHT"] = "右上"
L["LEFT"] = "左侧"
L["CENTER"] = "居中"
L["RIGHT"] = "右侧"
L["BOTTOMLEFT"] = "左下"
L["BOTTOM"] = "底部"
L["BOTTOMRIGHT"] = "右下"

-- 冷却与其他
L["Default Swipe Color"] = "冷却遮罩"
L["Active Swipe Color"] = "触发遮罩"
L["Reverse Swipe"] = "冷却反向"
L["Enable Split Layout"] = "启用双行布局"
L["Row Y Gap"] = "行间距"
L["Row 1 Settings"] = "第一行设置"
L["Row 2 Settings"] = "第二行设置"
L["Stack Text"] = "层数文本"
L["CD Text"] = "倒计时文本"

-- 发光设置
L["Glow Style"] = "发光样式"
L["Pixel"] = "像素发光"
L["Autocast"] = "触发发光"
L["Button"] = "按键高亮"
L["Proc"] = "触发频闪"
L["Enable Custom Color"] = "启用自定义染色"
L["Lines"] = "线条数"
L["Frequency"] = "频率"
L["Length"] = "长度"
L["Particles"] = "数量"
L["Scale"] = "大小"
L["Live Glow Sandbox Title"] = "|cff00ccff[Live Sandbox]|r 实时发光特效预览"

-- SmartHide (智能条件隐藏)
L["<- Back to Menu"] = "<- 返回上一级菜单"
L["Enable SmartHide"] = "开启该组条件隐藏 (SmartHide)"
L["├ Hide Out of Combat"] = "  ├ 脱战且无目标时隐藏"
L["├ Hide on Friendly"] = "  ├ 目标为友方NPC时隐藏"
L["├ Hide Flying"] = "  ├ 驭空术/飞行时强制隐藏"
L["└ Hide in Vehicle"] = "  └ 乘坐载具时强制隐藏"
L["Visibility Settings"] = "显示条件设置"
L["SmartHide Settings ->"] = "显示/隐藏条件设置 ->"