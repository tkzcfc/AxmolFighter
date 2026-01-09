NowEpochMS = game_utils.now_epoch_ms
CppResolve = game_utils.resolve


-- NowEpoch10m = game_utils.now_epoch_10m
-- Int64ToDateTime = game_utils.i64_to_datetime
-- Int64ToString = game_utils.i64_to_string
-- createSpriteFromBase64 = game_utils.create_sprite_with_base64
-- unzip = game_utils.unzip
-- BindWebViewJsCallback = game_utils.bind_webView_js_callback
-- CppBase64Decode = game_utils.base64_decode
-- CppBase64Encode = game_utils.base64_encode
-- CppMd5Str = game_utils.md5
-- CppMd5File = game_utils.md5_file
-- CppSha256 = game_utils.sha256
-- CompressStringEx = game_utils.compress
-- CompressStringToFileEx = game_utils.compress_to_file
-- CompressFileToFileEx = game_utils.compress_file_to_file
-- DecompressString = game_utils.decompress
-- LoadChunksFromZIP = game_utils.load_chunks
-- GetConfigurationInfo = game_utils.get_engine_cfg_info

-- GetNodeChildren = game_utils.get_node_children
-- GetFairyGUIChildren = game_utils.get_fgui_component_children

-- createBatchingSpine = game_utils.create_batching_spine
-- clearBatchingSpineCache = game_utils.clear_batching_spine_sache

-- SetClipBoardString = native_utils.set_clipboard_string
-- GetClipBoardString = native_utils.get_clipboard_string


DEBUG = 2                                           -- 0 - disable debug info, 1 - less debug info, 2 - verbose debug info
AX_USE_FRAMEWORK = true                             -- use framework, will disable all deprecated API, false - use legacy API
AX_DISABLE_GLOBAL = false                           -- disable create unexpected global variable

_G.print = release_print

BOOT_VER_HASH = "2025-7-1"
BOOT_BUILD_NUMBER = 1


DESIGNED_RESOLUTION_W = 1280
DESIGNED_RESOLUTION_H = 720


local resolutionWidth = 1280
local resolutionHeight = 720
local resolutionScale = 1

if game_utils.is_pc then
    resolutionScale = 0.7
    resolutionWidth = 1400
    resolutionHeight = 720

    xpcall(
        function()
            require("LuaPanda").start()
        end,
        function(msg)
            print(msg)
        end
    )

    ax.Director:getInstance():setStatsDisplay(true)
end

AX_DESIGN_RESOLUTION = {                            -- for module display
    width = resolutionWidth * resolutionScale,
    height = resolutionHeight * resolutionScale,
    autoscale = "NONE",
    callback = function(framesize)
        local winSize   = cc.Director:getInstance():getWinSize()
        local winWidth = math.max(winSize.width, winSize.height)
        local winHeight = math.min(winSize.width, winSize.height)
        
        local adaptiveDesignedW = math.max(DESIGNED_RESOLUTION_W, DESIGNED_RESOLUTION_H)
        local adaptiveDesignedH = math.min(DESIGNED_RESOLUTION_W, DESIGNED_RESOLUTION_H)

        -- 限制高分辨率
        local scale = math.max(adaptiveDesignedW / winWidth, adaptiveDesignedH / winHeight)
        winWidth = math.ceil(winWidth * scale)
        winHeight = math.ceil(winHeight * scale)

        local cfg = {
            width = winWidth,
            height = winHeight,            
        }

        local frameWidth = math.max(framesize.width, framesize.height)
        local frameHeight = math.min(framesize.width, framesize.height)

        local designedRatio = cfg.width / cfg.height
        local frameSizeRatio = frameWidth / frameHeight

        if frameSizeRatio < designedRatio then
            cfg.autoscale = "EXACT_FIT"
        else
            if framesize.width > framesize.height then
                cfg.autoscale = "FIXED_HEIGHT"
            else
                cfg.autoscale = "FIXED_WIDTH"
            end
        end

        print("winSize", winWidth, winHeight)
        print("scale", scale)
        print("frameSizeRatio", frameSizeRatio, frameWidth, frameHeight)
        print("designedRatio", designedRatio, cfg.width, cfg.height)
        print("autoscale", cfg.autoscale)

        return cfg
    end
}



local director = ax.Director:getInstance()
local view = director:getRenderView()

if not view then
    local width = 960
    local height = 640
    if AX_DESIGN_RESOLUTION then
        if AX_DESIGN_RESOLUTION.width then
            width = AX_DESIGN_RESOLUTION.width
        end
        if AX_DESIGN_RESOLUTION.height then
            height = AX_DESIGN_RESOLUTION.height
        end
    end
    view = ax.RenderViewImpl:createWithRect("Axmol-Lua", {x = 0, y = 0, width = width, height = height})
    director:setRenderView(view)
end
