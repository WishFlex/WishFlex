local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex')
local CS = WUI:NewModule('WishFlex_ChatSetup', 'AceEvent-3.0')
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.chatSetup = true

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.system = WUI.OptionsArgs.system or { order = 50, type = "group", name = "|cff0099cc系统设置|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.system.args.chat = {
        order = 2, type = "group", name = "聊天框同步",
        args = { run = { order = 1, type = "execute", name = "同步聊天窗口", confirm = true, func = function() CS:SetupChat() end } }
    }
end
local ChatTypeGroup = {
    ["综合"] = { "SAY", "EMOTE", "YELL", "WHISPER", "BN_WHISPER", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "GUILD_ACHIEVEMENT", "ACHIEVEMENT", "MONSTER_SAY", "MONSTER_EMOTE", "MONSTER_YELL", "MONSTER_WHISPER", "MONSTER_BOSS_EMOTE", "MONSTER_BOSS_WHISPER", "LOOT", "MONEY", "CURRENCY", "SKILL", "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE", "SYSTEM", "ERRORS", "IGNORED", "CHANNEL", "TARGETICONS", "PING" },
    ["团队"] = { "ACHIEVEMENT", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "LOOT", "PING" },
    ["公会"] = { "GUILD", "OFFICER", "GUILD_ACHIEVEMENT" },
    ["密语"] = { "WHISPER", "BN_WHISPER" }
}

local ExtraChannels = { "综合", "交易", "服务", "世界频道", "大脚世界频道" }

function CS:SetupChat()
    for _, chanName in ipairs(ExtraChannels) do JoinChannelByName(chanName) end
    for i = 2, 10 do
        local name = GetChatWindowInfo(i)
        if name then FCF_Close(_G["ChatFrame"..i]) end
    end

    FCF_SetWindowName(ChatFrame1, "综合")
    ChatFrame_RemoveAllMessageGroups(ChatFrame1)
    ChatFrame_RemoveAllChannels(ChatFrame1)
    ChatFrame_ReceiveAllPrivateMessages(ChatFrame1)
    for _, msgType in ipairs(ChatTypeGroup["综合"]) do ChatFrame_AddMessageGroup(ChatFrame1, msgType) end

    E:Delay(0.2, function()
        for _, chanName in ipairs(ExtraChannels) do
            local id = GetChannelName(chanName)
            if id and id > 0 then ChatFrame1:AddChannel(chanName) end
        end
        FCF_SetChatWindowFontSize(nil, ChatFrame1, 12)
    end)

    local order = {"团队", "公会", "密语"}
    for _, name in ipairs(order) do
        local frame = FCF_OpenNewWindow(name)
        if frame then
            ChatFrame_RemoveAllMessageGroups(frame)
            for _, msgType in ipairs(ChatTypeGroup[name]) do ChatFrame_AddMessageGroup(frame, msgType) end
            FCF_SetChatWindowFontSize(nil, frame, 12)
        end
    end

    if QuickJoinToastButton then QuickJoinToastButton:Hide() end
    if ChatFrameChannelButton then ChatFrameChannelButton:Hide() end
    if ChatFrameMenuButton then ChatFrameMenuButton:Hide() end

    local CH = E:GetModule('Chat')
    if CH and CH.UpdateChatTabs then CH:UpdateChatTabs() end
    print("|cff00ffccWishFlex:|r 聊天重置完成！已尝试自动加入并勾选世界频道。")
end

function CS:Initialize()
    InjectOptions()
end