

import(".deprecated.Deprecated")
import(".deprecated.DeprecatedCocos2dEnum")

import(".utils.Logger")

-- 全局函数导入
import(".global.Functions")
-- 事件类型定义
import(".global.Event")
-- 日志重定向
import(".global.LogToFile")
-- lua错误上报
import(".global.ErrorTrack")
-- 扩展导入
import(".extend.init")

-- 全局类导出
UIBase = import(".ui.UIBase")
ViewBase = import(".ui.ViewBase")
Crypto = import(".utils.Crypto")
ScrollViewBaseItem = import(".extend.ScrollViewBaseItem")

-- 全局网络事件派发器
gNetEventEmitter = import(".utils.EventEmitter").new()
-- 全局系统事件派发器
gSysEventEmitter = import(".utils.EventEmitter").new()
-- 全局UI管理
gUIManager = import(".ui.UIManager").new()
-- 全局view管理
gViewManager = import(".ui.ViewManager").new()
-- 适配
gAdaptive = import(".utils.Adaptive").new()
-- 音效
gSound = import(".utils.Sound").new()
-- 多语言
gLocalization = import(".utils.Localization").new()


function TR(key)
    return gLocalization:getText(key)
end