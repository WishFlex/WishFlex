local AddonName, ns = ...

-- 将默认配置挂载到 ns 下，避免全局污染
ns.DefaultConfig = {
    minimap = { hide = false, minimapPos = 220 },
    global = {
        ui = { sidebarExpanded = false }, -- 保存侧边栏状态，强迫症福音
    },
    cooldownCustom = { 
        enable = true,
        -- 强制防御组默认吸附到玩家头像，文本默认白色
        Defensive = { attachToPlayer = true, cdFontColor = {r=1,g=1,b=1}, stackFontColor = {r=1,g=1,b=1} },
        Essential = { cdFontColor = {r=1,g=1,b=1}, stackFontColor = {r=1,g=1,b=1} },
        Utility = { cdFontColor = {r=1,g=1,b=1}, stackFontColor = {r=1,g=1,b=1} },
        BuffBar = { cdFontColor = {r=1,g=1,b=1}, stackFontColor = {r=1,g=1,b=1} },
        -- 增益图标默认吸附资源条最上方
        BuffIcon = { snapToResource = true, snapToEssential = false, cdFontColor = {r=1,g=1,b=1}, stackFontColor = {r=1,g=1,b=1} }
    },
    extraMonitor = { 
        enable = true,
        -- 额外监控文本默认白色
        cdFontColor = {r=1,g=1,b=1},
        stackFontColor = {r=1,g=1,b=1}
    },
    classResource = { enable = true },
    glow = { enable = true },
    auraGlow = { enable = true },
    wishMonitor = { enable = true },
    cooldownTracker = { enable = true },
}

-- 保持向下兼容，如果你的其他模块暂时还引用了这个全局变量
WF_DefaultConfig = ns.DefaultConfig