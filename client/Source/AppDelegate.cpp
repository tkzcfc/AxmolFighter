/****************************************************************************
 Copyright (c) 2017-2018 Xiamen Yaji Software Co., Ltd.
 Copyright (c) 2019-present Axmol Engine contributors (see AUTHORS.md).

 https://axmol.dev/

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 ****************************************************************************/

#include "AppDelegate.h"

#define USE_AUDIO_ENGINE 1

#if USE_AUDIO_ENGINE
#    include "audio/AudioEngine.h"
#endif

#include "entry.h"

using namespace ax;
using namespace std;

AppDelegate::AppDelegate() {}

AppDelegate::~AppDelegate() {}

// if you want a different context, modify the value of gfxContextAttrs
// it will affect all platforms
void AppDelegate::initGfxContextAttrs()
{
    // set graphics context attributes: red,green,blue,alpha,depth,stencil,multisamplesCount
    GfxContextAttrs gfxContextAttrs = {8, 8, 8, 8, 24, 8, 0};
    // gfxContextAttrs.vsync = false
    RenderView::setGfxContextAttrs(gfxContextAttrs);
}

bool AppDelegate::applicationDidFinishLaunching()
{
#ifdef AX_PLATFORM_PC
    // Enable logging output colored text style and prefix timestamp
    ax::setLogFmtFlag(ax::LogFmtFlag::Full);
#endif
    // whether enable global SDF font render support, since axmol-2.0.1
    // FontFreeType::setShareDistanceFieldEnabled(true);

    return app_start();
}

// This function will be called when the app is inactive. Note, when receiving a phone call it is invoked.
void AppDelegate::applicationDidEnterBackground()
{
    Director::getInstance()->stopAnimation();

#if USE_AUDIO_ENGINE
    AudioEngine::pauseAll();
#endif
    Director::getInstance()->getEventDispatcher()->dispatchCustomEvent("APP_ENTER_BACKGROUND_EVENT");
}

// this function will be called when the app is active again
void AppDelegate::applicationWillEnterForeground()
{
    Director::getInstance()->startAnimation();

#if USE_AUDIO_ENGINE
    AudioEngine::resumeAll();
#endif
    Director::getInstance()->getEventDispatcher()->dispatchCustomEvent("APP_ENTER_FOREGROUND_EVENT");
}

void AppDelegate::applicationWillQuit() {}

void AppDelegate::applicationRestartStart()
{
    app_restart_start();
}

void AppDelegate::applicationRestartFinish()
{
    app_restart_finish();
}

#if AX_TARGET_PLATFORM == AX_PLATFORM_IOS
void AppDelegate::applicationScreenSizeChanged(int newWidth, int newHeight)
{
    app_screen_size_changed(newWidth, newHeight);
}
#endif
