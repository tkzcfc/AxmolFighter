local utils = {}

local langCfg = {}
local rootNode

function utils:init(rootNode)
    local layout = {}
    local size = cc.Director:getInstance():getVisibleSize()
    local designedX = DESIGNED_RESOLUTION_W
    local designedY = DESIGNED_RESOLUTION_H
    
    local scaleX    = size.width  / designedX
    local scaleY    = size.height / designedY

    layout.scaleMax = math.max(scaleX, scaleY)
    layout.scaleMin = math.min(scaleX, scaleY)
    layout.center   = {x = size.width * 0.5, y = size.height * 0.5}
    layout.size     = size

    self.layout = layout
    self.rootNode = rootNode
end

function utils:langText(text)
    local cfg = langCfg[text]
    if not cfg then
        return text
    end

    -- 当前语言
    local lang = nil

    -- 使用默认配置
    if gConfigData then
        lang = gConfigData["DefaultLanguage"]
    end

    -- 使用导航下发的配置
    if gNavConfigData then
        local langIndex = checkint(gNavConfigData["default_language"])
        if langIndex <= 0 then langIndex = 1 end

        -- 使用本地存储配置
        langIndex = cc.UserDefault:getInstance():getIntegerForKey("language", langIndex)

        local langs = string.split(gNavConfigData["language"], ",")
        if type(langs) == "table" then
            lang = langs[langIndex]
        end
    end

    if lang then
        if cfg[lang] == nil or cfg[lang] == "" then lang = nil end
    end

    -- 语言获取失败，使用默认配置
    if lang == nil then lang = "en" end

    return cfg[lang] or ""
end

function utils:pop(node)
    self.rootNode:addChild(node, 100)
    return node
end

function utils:showMsgBox(text, on_confirm, on_cancel)
    local node = require("boot.src.layer.MsgBoxLayer").new()
    node:showMsgBox(text, on_confirm, on_cancel)
    return self:pop(node)
end

function utils:delay(callback, time)
    time = time or 0
    local sharedScheduler = cc.Director:getInstance():getScheduler()
    local handle
    handle = sharedScheduler:scheduleScriptFunc(function(dt)
        sharedScheduler:unscheduleScriptEntry(handle)
        if callback then callback() end
    end, time, false)
end

function utils:exit()
    local targetPlatform = cc.Application:getInstance():getTargetPlatform() 
    if cc.PLATFORM_IOS == targetPlatform then
        os.exit(0)
    else
        cc.Director:getInstance():endToLua()
    end
end

function utils:getLangs()
    -- 使用导航下发的配置
    if gNavConfigData and type(gNavConfigData["language"]) == "string" then
        local langs = string.split(gNavConfigData["language"], ",")
        if type(langs) == "table" then
            return langs
        end
    end
    return { "en" }
end

langCfg = {
    ["正在检查版本信息..."] = {
        ["it"] = "Controllo delle informazioni sulla versione...",
        ["fr"] = "Vérification des informations sur la version...",
        ["es-es"] = "Comprobando la información de la versión...",
        ["de"] = "Überprüfung der Versionsinformationen...",
        ["pt"] = "Verificando informações da versão...",
        ["ina"] = "वर्शन जानकारी की जाँच की जा रही है... ",
        ["vn"] = "Đang Kiểm tra thông tin phiên bản",
        ["bg"] = "Проверка на информацията за версията...",
        ["da"] = "Kontrollerer versionsoplysninger...",
        ["ph"] = "Sinusuri ang impormasyon ng bersyon...",
        ["ja"] = "バージョン情報の確認中...",
        ["mm2"] = "ဗားရှင်းသတင်းအချက်အလက်စစ်ဆေးနေသည်",
        ["mm"] = "ဗားရှင်းသတင်းအချက်အလက်စစ်ဆေးနေသည်",
        ["tha"] = "กำลังตรวจสอบข้อมูลเวอร์ชัน...",
        ["cn"] = "正在检查版本信息...",
        ["es"] = "Comprobando la información de la versión...",
        ["ko"] = "버전 정보 확인",
        ["en"] = "Checking version information...",
        ["tc"] = "正在檢查版本資訊...",
        ["nl"] = "Controle van versie-informatie...",
        ["ind"] = "Sedang memeriksa informasi versi",
        ["bd"] = "সংস্করণ তথ্য পরীক্ষা করা হচ্ছে...",
        ["rus"] = "Проверка информации о версии...",
    },
    ["正在获取导航信息..."] = {
        ["it"] = "Si stanno ottenendo informazioni sulla navigazione...",
        ["fr"] = "Récupération des informations de navigation...",
        ["es-es"] = "Obtención de información de navegación...",
        ["de"] = "Abrufen von Navigationsinformationen...",
        ["pt"] = "Obtendo informações de navegação...",
        ["ina"] = "नेविगेशन जानकारी प्राप्त हो रही है... ",
        ["vn"] = "Nhận thông tin tự la bàn",
        ["bg"] = "Извличане на информация за навигацията...",
        ["da"] = "Henter navigationsoplysninger...",
        ["ph"] = "Pagkuha ng impormasyon sa nabigasyon",
        ["ja"] = "ナビゲーション情報を取得する...",
        ["mm2"] = "ညွှန်ပြအချက်အလက်များရယူနေခြင်း",
        ["mm"] = "ညွှန်ပြအချက်အလက်များရယူနေခြင်း",
        ["tha"] = "กำลังรับข้อมูลการนำทาง",
        ["cn"] = "正在获取导航信息...",
        ["es"] = "Obtención de información de navegación...",
        ["ko"] = "네비게이션 정보를 얻고 있습니다 …",
        ["en"] = "Getting navigation information...",
        ["tc"] = "正在獲取導航資訊...",
        ["nl"] = "Het ophalen van navigatie informatie...",
        ["ind"] = "Sedang mendapatkan informasi Pemandu",
        ["bd"] = "নেভিগেশন তথ্য প্রাপ্ত করা হচ্ছে...",
        ["rus"] = "Получение навигационной информации...",
    },
    ["取消"] = {
        ["it"] = "Cancellazione",
        ["fr"] = "Annuler",
        ["es-es"] = "Cancelar",
        ["de"] = "Abbrechen",
        ["pt"] = "Cancelar",
        ["ina"] = "रद्द करना ",
        ["vn"] = "HỦY BỎ",
        ["bg"] = "Отмяна на",
        ["da"] = "Afbestille",
        ["ph"] = "Kanselahin",
        ["ja"] = "キャンセル",
        ["mm2"] = "ပယ်ဖျက်ပါ",
        ["mm"] = "ပယ်ဖျက်ပါ",
        ["tha"] = "ยกเลิก",
        ["cn"] = "取消",
        ["es"] = "Cancelar",
        ["ko"] = "취소",
        ["en"] = "Cancel",
        ["tc"] = "取消",
        ["nl"] = "Annuleren",
        ["ind"] = "Batal",
        ["bd"] = "বাতিল করুন",
        ["rus"] = "Отмена",
    },
    ["获取导航信息失败, 是否重试？"] = {
        ["it"] = "Non è stato possibile ottenere informazioni sulla navigazione, devo riprovare?",
        ["fr"] = "L'obtention des informations de navigation a échoué, voulez-vous réessayer ?",
        ["es-es"] = "No se ha podido obtener la información de navegación, ¿quieres volver a intentarlo?",
        ["de"] = "Die Navigationsinformationen konnten nicht abgerufen werden. Möchten Sie es erneut versuchen?",
        ["pt"] = "Falha ao obter informações de navegação, deseja tentar novamente?",
        ["ina"] = "नेविगेशन जानकारी प्राप्त करने में विफल, पुन: प्रयास करें? ",
        ["vn"] = "Nhận thông tin tự la bàn Thất bại Thử lại",
        ["bg"] = "Не успяхте да получите информация за навигацията, искате ли да повторите опита?",
        ["da"] = "Kunne ikke hente navigationsoplysninger. Vil du prøve igen?",
        ["ph"] = "Nabigong makakuha ng impormasyon sa nabigasyon, gusto mo bang subukang muli?",
        ["ja"] = "ナビゲーション情報の取得に失敗しました、再試行しますか？",
        ["mm2"] = "ညွှန်ပြအချက်အလက်များရယူရန်မအောင်မြင်ပါ၊ သင်ထပ်ကြိုးစားလိုပါသလား",
        ["mm"] = "ညွှန်ပြအချက်အလက်များရယူရန်မအောင်မြင်ပါ၊ သင်ထပ်ကြိုးစားလိုပါသလား",
        ["tha"] = "รับข้อมูลการนำทางล้มเหลว คุณต้องการลองอีกครั้งไหม",
        ["cn"] = "获取导航信息失败, 是否重试？",
        ["es"] = "No se ha podido obtener la información de navegación, ¿quieres volver a intentarlo?",
        ["ko"] = "탐색 정보를 가져오지 못했습니다. 다시 시도해야 합니까?",
        ["en"] = "Failed to obtain navigation information, do you want to try again?",
        ["tc"] = "獲取導航資訊失敗, 是否重試？",
        ["nl"] = "Het is niet gelukt om navigatie informatie te krijgen, wilt u het opnieuw proberen?",
        ["ind"] = "Gagal mendapatkan informasi Pemandu, apakah Anda ingin mencoba lagi?",
        ["bd"] = "তথ্য পেতে ব্যর্থ, আপনি আবার চেষ্টা করতে চান?",
        ["rus"] = "Не удалось получить навигационную информацию. Хотите попробовать еще раз?",
    },
    ["确定"] = {
        ["it"] = "Determinazione",
        ["fr"] = "OK",
        ["es-es"] = "OK",
        ["de"] = "OK",
        ["pt"] = "confirmado",
        ["ina"] = "ठीक है",
        ["vn"] = "XÁC ĐỊNH",
        ["bg"] = "ОК",
        ["da"] = "Bekræfte",
        ["ph"] = "kumpirmahin",
        ["ja"] = "よっしゃー",
        ["mm2"] = "အတည်ပြုသည်",
        ["mm"] = "အတည်ပြုသည်",
        ["tha"] = "ตกลง",
        ["cn"] = "确定",
        ["es"] = "Sí",
        ["ko"] = "결심",
        ["en"] = "Confirm",
        ["tc"] = "確定",
        ["nl"] = "OK",
        ["ind"] = "Yakin",
        ["bd"] = "নিশ্চিত",
        ["rus"] = "Конечно",
    },
    ["版本更新失败, 是否重试？"] = {
        ["it"] = "L'aggiornamento della versione non è riuscito, devo riprovare?",
        ["fr"] = "La mise à jour de la version a échoué, voulez-vous réessayer ?",
        ["es-es"] = "No se ha podido actualizar la versión, ¿quieres volver a intentarlo?",
        ["de"] = "Die Aktualisierung der Version ist fehlgeschlagen, wollen Sie es erneut versuchen?",
        ["pt"] = "A atualização da versão falhou, deseja tentar novamente?",
        ["ina"] = "वर्शन अपडेट विफल, पुन: प्रयास करें? ",
        ["vn"] = "Cập nhật phiên bản không thành công,cho dù Thử lại",
        ["bg"] = "Не успяхте да актуализирате версията, искате ли да повторите опита?",
        ["da"] = "Versionsopdateringen mislykkedes, vil du prøve igen?",
        ["ph"] = "Nabigo ang pag-update ng bersyon, gusto mo bang subukang muli?",
        ["ja"] = "バージョンアップに失敗しました、再試行しますか？",
        ["mm2"] = "ဗားရှင်းအပ်ဒိတ်မအောင်မြင်ပါ၊ သင်ထပ်ကြိုးစားလိုပါသလား",
        ["mm"] = "ဗားရှင်းအပ်ဒိတ်မအောင်မြင်ပါ၊ သင်ထပ်ကြိုးစားလိုပါသလား",
        ["tha"] = "การอัปเดตเวอร์ชันล้มเหลว ต้องการลองอีกครั้งหรือไม่",
        ["cn"] = "版本更新失败, 是否重试？",
        ["es"] = "No se ha podido actualizar la versión, ¿quieres volver a intentarlo?",
        ["ko"] = "버전 업데이트가 실패했는데 다시 시도해야 합니까?",
        ["en"] = "The version update failed, do you want to try again?",
        ["tc"] = "版本更新失敗, 是否重試？",
        ["nl"] = "Het bijwerken van de versie is mislukt, wilt u het opnieuw proberen?",
        ["ind"] = "Pembaruan versi gagal, Apakah anda ingin mencoba lagi ?",
        ["bd"] = "আপডেট ব্যর্থ হয়েছে, আপনি কি আবার চেষ্টা করতে চান?",
        ["rus"] = "Не удалось обновить версию. Хотите попробовать еще раз?",
    },
    ["提示"] = {
        ["it"] = "Suggerimento",
        ["fr"] = "Astuce",
        ["es-es"] = "Tip",
        ["de"] = "Tip",
        ["pt"] = "Tip",
        ["ina"] = "Tip",
        ["vn"] = "Tip",
        ["bg"] = "Tip",
        ["da"] = "Tip",
        ["ph"] = "Tip",
        ["ja"] = "ヒント",
        ["mm2"] = "Tip",
        ["mm"] = "Tip",
        ["tha"] = "Tip",
        ["cn"] = "提示",
        ["es"] = "Tip",
        ["ko"] = "힌트",
        ["en"] = "Tip",
        ["tc"] = "提示",
        ["nl"] = "Tip",
        ["ind"] = "Tip",
        ["bd"] = "Tip",
        ["rus"] = "намекать",
    },
}


return utils