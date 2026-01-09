const_def = {}

const_def.LangList = {
    cn    =   "简体中文",
    en    =   "ENGLISH",            --英国
    mm    =   "ဗမာစာ",              --缅甸
    es    =   "Español",            --西班牙
    pt    =   "Português",          --葡萄牙
    tha   =   "ภาษาไทย",           --泰国
    bd    =   "বেঙ্গল",              --孟加拉
    ind   =   "Bahasa Indonesia",   --印尼
    vn    =   "Tiếng Việt",         --越南
    rus   =   "Русский",            --俄罗斯

    -- tc    =   "繁體中文",
    -- ina   =   "हिन्दी",                --印度
    -- ko    =   "한국어",              --韩国
    -- da    =   "dansk",              --丹麦
    -- bg    =   "български",          --保加利亚
    -- nl    =   "Nederlands",         --荷兰
    -- it    =   "Italiano",           --意大利
    -- de    =   "Deutsch",            --德国
    -- fr    =   "Français",           --法国
    -- ja    =   "日本語",
    -- ph    =   "Filipino",           --菲律宾
}

--横屏
const_def.H_Screen_Type = 1
--竖屏
const_def.V_Screen_Type = 2


-- 网络断开通知
SysEvent.ON_MSG_NET_DISCONNECT = "ON_MSG_NET_DISCONNECT"
-- 网络连接结果通知
SysEvent.ON_MSG_NET_CONNECT_RESULT = "ON_MSG_NET_CONNECT_RESULT"

-- 大厅连接成功
SysEvent.ON_MSG_LOBBY_CONNECT_SUCCESS = "ON_MSG_LOBBY_CONNECT_SUCCESS"

-- 收到推送消息
SysEvent.ON_MSG_RECV_PUSH_MSG = "ON_MSG_RECV_PUSH_MSG"

-- 登录成功通知
SysEvent.ON_MSG_LOGIN_SUCCESS = "ON_MSG_LOGIN_SUCCESS"
-- 用户退出登录通知
SysEvent.ON_MSG_LOGOUT = "ON_MSG_LOGOUT"
-- 登录结果通知
SysEvent.ON_MSG_LOGIN_RESULT = "ON_MSG_LOGIN_RESULT"
-- 用户信息改变成功通知
SysEvent.ON_MSG_CHANGE_USERINFO = "ON_MSG_CHANGE_USERINFO"
