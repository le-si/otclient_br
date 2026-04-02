/*
 * Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#ifdef __APPLE__

#import "cocoawindow.h"
#include <framework/core/eventdispatcher.h>
#include <framework/graphics/image.h>

// Use GLFW for context creation on macOS — NSOpenGL is removed on macOS 26+ (Tahoe) / Apple Silicon
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
// Note: glfw3native.h is intentionally NOT included to avoid Cocoa/Rect type conflicts

#define Size CocoaSize
#define Point CocoaPoint
#define Rect CocoaRect
#define Cursor CocoaCursor
#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#undef Size
#undef Point
#undef Rect
#undef Cursor

// ─── GLFW callbacks ──────────────────────────────────────────────────────────

static CocoaWindow* g_cocoaWindowInstance = nullptr;

static Fw::Key glfwKeyToFw(int key) {
    switch (key) {
        case GLFW_KEY_ESCAPE: return Fw::KeyEscape;
        case GLFW_KEY_TAB: return Fw::KeyTab;
        case GLFW_KEY_BACKSPACE: return Fw::KeyBackspace;
        case GLFW_KEY_ENTER: return Fw::KeyEnter;
        case GLFW_KEY_KP_ENTER: return Fw::KeyEnter;
        case GLFW_KEY_SPACE: return Fw::KeySpace;
        case GLFW_KEY_LEFT_SHIFT: case GLFW_KEY_RIGHT_SHIFT: return Fw::KeyShift;
        case GLFW_KEY_LEFT_CONTROL: case GLFW_KEY_RIGHT_CONTROL: return Fw::KeyCtrl;
        case GLFW_KEY_LEFT_ALT: case GLFW_KEY_RIGHT_ALT: return Fw::KeyAlt;
        case GLFW_KEY_LEFT_SUPER: case GLFW_KEY_RIGHT_SUPER: return Fw::KeyMeta;
        case GLFW_KEY_UP: return Fw::KeyUp;
        case GLFW_KEY_DOWN: return Fw::KeyDown;
        case GLFW_KEY_LEFT: return Fw::KeyLeft;
        case GLFW_KEY_RIGHT: return Fw::KeyRight;
        case GLFW_KEY_INSERT: return Fw::KeyInsert;
        case GLFW_KEY_DELETE: return Fw::KeyDelete;
        case GLFW_KEY_HOME: return Fw::KeyHome;
        case GLFW_KEY_END: return Fw::KeyEnd;
        case GLFW_KEY_PAGE_UP: return Fw::KeyPageUp;
        case GLFW_KEY_PAGE_DOWN: return Fw::KeyPageDown;
        case GLFW_KEY_F1: return Fw::KeyF1;
        case GLFW_KEY_F2: return Fw::KeyF2;
        case GLFW_KEY_F3: return Fw::KeyF3;
        case GLFW_KEY_F4: return Fw::KeyF4;
        case GLFW_KEY_F5: return Fw::KeyF5;
        case GLFW_KEY_F6: return Fw::KeyF6;
        case GLFW_KEY_F7: return Fw::KeyF7;
        case GLFW_KEY_F8: return Fw::KeyF8;
        case GLFW_KEY_F9: return Fw::KeyF9;
        case GLFW_KEY_F10: return Fw::KeyF10;
        case GLFW_KEY_F11: return Fw::KeyF11;
        case GLFW_KEY_F12: return Fw::KeyF12;
        case GLFW_KEY_A: return Fw::KeyA; case GLFW_KEY_B: return Fw::KeyB;
        case GLFW_KEY_C: return Fw::KeyC; case GLFW_KEY_D: return Fw::KeyD;
        case GLFW_KEY_E: return Fw::KeyE; case GLFW_KEY_F: return Fw::KeyF;
        case GLFW_KEY_G: return Fw::KeyG; case GLFW_KEY_H: return Fw::KeyH;
        case GLFW_KEY_I: return Fw::KeyI; case GLFW_KEY_J: return Fw::KeyJ;
        case GLFW_KEY_K: return Fw::KeyK; case GLFW_KEY_L: return Fw::KeyL;
        case GLFW_KEY_M: return Fw::KeyM; case GLFW_KEY_N: return Fw::KeyN;
        case GLFW_KEY_O: return Fw::KeyO; case GLFW_KEY_P: return Fw::KeyP;
        case GLFW_KEY_Q: return Fw::KeyQ; case GLFW_KEY_R: return Fw::KeyR;
        case GLFW_KEY_S: return Fw::KeyS; case GLFW_KEY_T: return Fw::KeyT;
        case GLFW_KEY_U: return Fw::KeyU; case GLFW_KEY_V: return Fw::KeyV;
        case GLFW_KEY_W: return Fw::KeyW; case GLFW_KEY_X: return Fw::KeyX;
        case GLFW_KEY_Y: return Fw::KeyY; case GLFW_KEY_Z: return Fw::KeyZ;
        case GLFW_KEY_0: return Fw::Key0; case GLFW_KEY_1: return Fw::Key1;
        case GLFW_KEY_2: return Fw::Key2; case GLFW_KEY_3: return Fw::Key3;
        case GLFW_KEY_4: return Fw::Key4; case GLFW_KEY_5: return Fw::Key5;
        case GLFW_KEY_6: return Fw::Key6; case GLFW_KEY_7: return Fw::Key7;
        case GLFW_KEY_8: return Fw::Key8; case GLFW_KEY_9: return Fw::Key9;
        default: return Fw::KeyUnknown;
    }
}

static uint8_t glfwModsToFw(int mods) {
    uint8_t m = Fw::KeyboardNoModifier;
    if (mods & GLFW_MOD_SHIFT)   m |= Fw::KeyboardShiftModifier;
    if (mods & GLFW_MOD_CONTROL) m |= Fw::KeyboardCtrlModifier;
    if (mods & GLFW_MOD_ALT)     m |= Fw::KeyboardAltModifier;
    if (mods & GLFW_MOD_SUPER)   m |= Fw::KeyboardCtrlModifier; // Cmd → Ctrl
    return m;
}

static void glfwKeyCallback(GLFWwindow*, int key, int /*scancode*/, int action, int mods) {
    if (!g_cocoaWindowInstance) return;
    if (action == GLFW_REPEAT) return;
    InputEvent ev;
    ev.type = (action == GLFW_PRESS) ? Fw::InputEventType::KeyDownInputEvent
                                      : Fw::InputEventType::KeyUpInputEvent;
    ev.keyCode = glfwKeyToFw(key);
    ev.keyboardModifiers = glfwModsToFw(mods);
    g_cocoaWindowInstance->fireInputEvent(ev);
}

static void glfwCharCallback(GLFWwindow*, unsigned int codepoint) {
    if (!g_cocoaWindowInstance) return;
    InputEvent ev;
    ev.type = Fw::InputEventType::KeyPressInputEvent;
    ev.keyCode = Fw::KeyUnknown;
    ev.keyboardModifiers = Fw::KeyboardNoModifier;
    // encode codepoint as UTF-8 in keyText
    char buf[5] = {};
    if (codepoint < 0x80) { buf[0] = (char)codepoint; }
    else if (codepoint < 0x800) { buf[0] = 0xC0|(codepoint>>6); buf[1] = 0x80|(codepoint&0x3F); }
    else if (codepoint < 0x10000) { buf[0] = 0xE0|(codepoint>>12); buf[1] = 0x80|((codepoint>>6)&0x3F); buf[2] = 0x80|(codepoint&0x3F); }
    else { buf[0] = 0xF0|(codepoint>>18); buf[1] = 0x80|((codepoint>>12)&0x3F); buf[2] = 0x80|((codepoint>>6)&0x3F); buf[3] = 0x80|(codepoint&0x3F); }
    ev.keyText = buf;
    g_cocoaWindowInstance->fireInputEvent(ev);
}

static void glfwMouseButtonCallback(GLFWwindow* win, int button, int action, int mods) {
    if (!g_cocoaWindowInstance) return;
    InputEvent ev;
    ev.type = (action == GLFW_PRESS) ? Fw::InputEventType::MousePressInputEvent
                                      : Fw::InputEventType::MouseReleaseInputEvent;
    if (button == GLFW_MOUSE_BUTTON_LEFT)   ev.mouseButton = Fw::MouseButton::MouseLeftButton;
    else if (button == GLFW_MOUSE_BUTTON_RIGHT)  ev.mouseButton = Fw::MouseButton::MouseRightButton;
    else if (button == GLFW_MOUSE_BUTTON_MIDDLE) ev.mouseButton = Fw::MouseButton::MouseMidButton;
    else return;
    double xpos, ypos;
    glfwGetCursorPos(win, &xpos, &ypos);
    float scale = g_cocoaWindowInstance->getDisplayDensity();
    ev.mousePos = TPoint<int>((int)(xpos * scale), (int)(ypos * scale));
    ev.keyboardModifiers = glfwModsToFw(mods);
    g_cocoaWindowInstance->fireInputEvent(ev);
}

static void glfwCursorPosCallback(GLFWwindow* win, double xpos, double ypos) {
    if (!g_cocoaWindowInstance) return;
    float scale = g_cocoaWindowInstance->getDisplayDensity();
    InputEvent ev;
    ev.type = Fw::InputEventType::MouseMoveInputEvent;
    ev.mousePos = TPoint<int>((int)(xpos * scale), (int)(ypos * scale));
    ev.mouseButton = Fw::MouseButton::MouseNoButton;
    ev.keyboardModifiers = Fw::KeyboardNoModifier;
    g_cocoaWindowInstance->fireInputEvent(ev);
}

static void glfwScrollCallback(GLFWwindow*, double /*xoffset*/, double yoffset) {
    if (!g_cocoaWindowInstance) return;
    InputEvent ev;
    ev.type = Fw::InputEventType::MouseWheelInputEvent;
    ev.wheelDirection = (yoffset > 0) ? Fw::MouseWheelUp : Fw::MouseWheelDown;
    ev.mouseButton = Fw::MouseButton::MouseNoButton;
    ev.keyboardModifiers = Fw::KeyboardNoModifier;
    g_cocoaWindowInstance->fireInputEvent(ev);
}

static void glfwFramebufferSizeCallback(GLFWwindow*, int width, int height) {
    fprintf(stderr, "[DEBUG] glfwFramebufferSizeCallback: %dx%d\n", width, height);
    if (!g_cocoaWindowInstance) return;
    g_cocoaWindowInstance->onFramebufferResize(TSize<int>(width, height));
}

static void glfwWindowSizeCallback(GLFWwindow*, int width, int height) {
    fprintf(stderr, "[DEBUG] glfwWindowSizeCallback: %dx%d\n", width, height);
    if (!g_cocoaWindowInstance) return;
    g_cocoaWindowInstance->onWindowResize(TSize<int>(width, height));
}

static void glfwWindowFocusCallback(GLFWwindow*, int focused) {
    if (!g_cocoaWindowInstance) return;
    // nothing critical to do here for now
}

static void glfwWindowCloseCallback(GLFWwindow*) {
    if (!g_cocoaWindowInstance) return;
    g_cocoaWindowInstance->fireCloseRequest();
}

// ─── CocoaWindow implementation ──────────────────────────────────────────────

CocoaWindow::CocoaWindow()
{
}

CocoaWindow::~CocoaWindow()
{
    terminate();
}

void CocoaWindow::init()
{
    fprintf(stderr, "[DEBUG] CocoaWindow::init() START\n");
    g_cocoaWindowInstance = this;

    if (!glfwInit()) {
        fprintf(stderr, "[DEBUG] glfwInit() FAILED\n");
        g_logger.fatal("GLFW: glfwInit() failed");
        return;
    }
    fprintf(stderr, "[DEBUG] glfwInit() OK\n");

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
    glfwWindowHint(GLFW_DOUBLEBUFFER, GLFW_TRUE);
    glfwWindowHint(GLFW_RED_BITS,   8);
    glfwWindowHint(GLFW_GREEN_BITS, 8);
    glfwWindowHint(GLFW_BLUE_BITS,  8);
    glfwWindowHint(GLFW_ALPHA_BITS, 8);
    glfwWindowHint(GLFW_DEPTH_BITS, 24);
    glfwWindowHint(GLFW_RESIZABLE,  GLFW_TRUE);
    glfwWindowHint(GLFW_FOCUSED,    GLFW_TRUE);
    glfwWindowHint(GLFW_COCOA_RETINA_FRAMEBUFFER, GLFW_TRUE);
    glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);  // Start hidden, show() will make visible

    fprintf(stderr, "[DEBUG] Creating GLFW window...\n");
    GLFWwindow* glfwWin = glfwCreateWindow(800, 600, "OTClient", nullptr, nullptr);
    if (!glfwWin) {
        fprintf(stderr, "[DEBUG] OpenGL 2.1 window failed, trying 3.2 Core...\n");
        glfwDefaultWindowHints();
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);
        glfwWindowHint(GLFW_COCOA_RETINA_FRAMEBUFFER, GLFW_TRUE);
        glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
        glfwWin = glfwCreateWindow(800, 600, "OTClient (Core)", nullptr, nullptr);
    }

    if (!glfwWin) {
        fprintf(stderr, "[DEBUG] ALL window creation attempts FAILED\n");
        g_logger.fatal("GLFW: Could not create window.");
        return;
    }
    fprintf(stderr, "[DEBUG] GLFW window created OK\n");

    glfwMakeContextCurrent(glfwWin);
    m_window = (void*)glfwWin;
    fprintf(stderr, "[DEBUG] GL context made current\n");

    // Initial Retina scale factor and sizes
    int fbW, fbH, winW, winH;
    glfwGetFramebufferSize(glfwWin, &fbW, &fbH);
    glfwGetWindowSize(glfwWin, &winW, &winH);
    
    m_displayDensity = (winW > 0) ? (float)fbW / (float)winW : 1.0f;
    if (m_displayDensity < 1.0f) m_displayDensity = 1.0f;
    m_size = TSize<int>(fbW, fbH);

    fprintf(stderr, "[DEBUG] Window: %dx%d, FB: %dx%d, Density: %.1f\n", winW, winH, fbW, fbH, m_displayDensity);
    g_logger.info("GLFW: Window size: {}x{}, Framebuffer: {}x{}, Density: {}", winW, winH, fbW, fbH, m_displayDensity);

    // Verify context
    typedef const GLubyte* (*PFN_glGetString)(GLenum);
    PFN_glGetString p_glGetString = (PFN_glGetString)glfwGetProcAddress("glGetString");
    if (p_glGetString) {
        const char* renderer = (const char*)p_glGetString(GL_RENDERER);
        const char* version  = (const char*)p_glGetString(GL_VERSION);
        fprintf(stderr, "[DEBUG] GL Renderer: %s, Version: %s\n", renderer ? renderer : "NULL", version ? version : "NULL");
        if (renderer && version) {
            g_logger.info("GLFW/OpenGL: Renderer: {}, Version: {}", renderer, version);
        }
    } else {
        fprintf(stderr, "[DEBUG] Could not get glGetString proc!\n");
    }

    // Register GLFW callbacks
    fprintf(stderr, "[DEBUG] Registering GLFW callbacks...\n");
    glfwSetKeyCallback(glfwWin, glfwKeyCallback);
    glfwSetCharCallback(glfwWin, glfwCharCallback);
    glfwSetMouseButtonCallback(glfwWin, glfwMouseButtonCallback);
    glfwSetCursorPosCallback(glfwWin, glfwCursorPosCallback);
    glfwSetScrollCallback(glfwWin, glfwScrollCallback);
    glfwSetFramebufferSizeCallback(glfwWin, glfwFramebufferSizeCallback);
    glfwSetWindowSizeCallback(glfwWin, glfwWindowSizeCallback);
    glfwSetWindowFocusCallback(glfwWin, glfwWindowFocusCallback);
    glfwSetWindowCloseCallback(glfwWin, glfwWindowCloseCallback);

    fprintf(stderr, "[DEBUG] CocoaWindow::init() DONE\n");
}

void CocoaWindow::terminate()
{
    g_cocoaWindowInstance = nullptr;
    if (m_window) {
        glfwDestroyWindow((GLFWwindow*)m_window);
        m_window = nullptr;
    }
    glfwTerminate();
    m_cursors.clear();
}

void CocoaWindow::move(const TPoint<int>& pos)
{
    if (!m_window) return;
    float scale = m_displayDensity > 0 ? m_displayDensity : 1.0f;
    
    // pos is pixels; glfw needs points
    int winX = (int)(pos.x / scale);
    int winY = (int)(pos.y / scale);
    
    // Clamp to non-negative to avoid invisible windows off-screen
    if (winX < 0) winX = 0;
    if (winY < 0) winY = 0;
    
    glfwSetWindowPos((GLFWwindow*)m_window, winX, winY);
}

void CocoaWindow::resize(const TSize<int>& size)
{
    if (!m_window) return;
    if (size.width() <= 0 || size.height() <= 0) return;
    
    m_size = size;
    float scale = m_displayDensity > 0 ? m_displayDensity : 1.0f;
    glfwSetWindowSize((GLFWwindow*)m_window, (int)(size.width() / scale), (int)(size.height() / scale));
}

void CocoaWindow::onFramebufferResize(const TSize<int>& size)
{
    fprintf(stderr, "[DEBUG] onFramebufferResize: %dx%d\n", size.width(), size.height());
    if (size.width() <= 0 || size.height() <= 0) return;
    m_size = size;
    if (m_onResize) {
        fprintf(stderr, "[DEBUG] Calling m_onResize...\n");
        m_onResize(size);
        fprintf(stderr, "[DEBUG] m_onResize returned OK\n");
    }
}

void CocoaWindow::onWindowResize(const TSize<int>& size)
{
    fprintf(stderr, "[DEBUG] onWindowResize: %dx%d\n", size.width(), size.height());
    if (!m_window || size.width() <= 0) return;
    
    // Recalculate density based on window coords vs framebuffer
    int fbW, fbH;
    glfwGetFramebufferSize((GLFWwindow*)m_window, &fbW, &fbH);
    m_displayDensity = (float)fbW / (float)size.width();
    if (m_displayDensity < 1.0f) m_displayDensity = 1.0f;
}

void CocoaWindow::show()
{
    fprintf(stderr, "[DEBUG] CocoaWindow::show()\n");
    if (!m_window) { fprintf(stderr, "[DEBUG] show() - NO WINDOW!\n"); return; }
    glfwShowWindow((GLFWwindow*)m_window);
    m_visible = true;
    fprintf(stderr, "[DEBUG] show() done, visible=true\n");
}

void CocoaWindow::hide()
{
    fprintf(stderr, "[DEBUG] CocoaWindow::hide()\n");
    if (!m_window) return;
    glfwHideWindow((GLFWwindow*)m_window);
    m_visible = false;
}

void CocoaWindow::maximize()
{
    if (!m_window) return;
    glfwMaximizeWindow((GLFWwindow*)m_window);
}

void CocoaWindow::poll()
{
    if (!m_window) return;
    glfwPollEvents();
}

void CocoaWindow::swapBuffers()
{
    if (!m_window) return;
    glfwSwapBuffers((GLFWwindow*)m_window);
}

void CocoaWindow::makeCurrent()
{
    if (!m_window) return;
    glfwMakeContextCurrent((GLFWwindow*)m_window);
}

void CocoaWindow::showMouse()
{
    if (!m_window) return;
    glfwSetInputMode((GLFWwindow*)m_window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
    m_mouseVisible = true;
}

void CocoaWindow::hideMouse()
{
    if (!m_window) return;
    glfwSetInputMode((GLFWwindow*)m_window, GLFW_CURSOR, GLFW_CURSOR_HIDDEN);
    m_mouseVisible = false;
}

void CocoaWindow::setMouseCursor(int cursorId)
{
    if (!m_window) return;
    if (cursorId >= 0 && cursorId < (int)m_cursors.size()) {
        GLFWcursor* cursor = (GLFWcursor*)m_cursors[cursorId];
        glfwSetCursor((GLFWwindow*)m_window, cursor);
    }
}

void CocoaWindow::restoreMouseCursor()
{
    if (!m_window) return;
    glfwSetCursor((GLFWwindow*)m_window, nullptr);
    glfwSetInputMode((GLFWwindow*)m_window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
}

void CocoaWindow::setTitle(std::string_view title)
{
    if (!m_window) return;
    glfwSetWindowTitle((GLFWwindow*)m_window, title.data());
}

void CocoaWindow::setMinimumSize(const TSize<int>& minimumSize)
{
    if (!m_window) return;
    float scale = m_displayDensity > 0 ? m_displayDensity : 1.0f;
    glfwSetWindowSizeLimits((GLFWwindow*)m_window,
        (int)(minimumSize.width() / scale), (int)(minimumSize.height() / scale),
        GLFW_DONT_CARE, GLFW_DONT_CARE);
}

void CocoaWindow::setFullscreen(bool fullscreen)
{
    if (!m_window) return;
    GLFWwindow* win = (GLFWwindow*)m_window;
    if (fullscreen == m_fullscreen) return;
    if (fullscreen) {
        GLFWmonitor* monitor = glfwGetPrimaryMonitor();
        const GLFWvidmode* mode = glfwGetVideoMode(monitor);
        glfwSetWindowMonitor(win, monitor, 0, 0, mode->width, mode->height, mode->refreshRate);
    } else {
        float scale = m_displayDensity > 0 ? m_displayDensity : 1.0f;
        glfwSetWindowMonitor(win, nullptr, 100, 100,
            (int)(m_size.width() / scale), (int)(m_size.height() / scale), GLFW_DONT_CARE);
    }
    m_fullscreen = fullscreen;
}

void CocoaWindow::setVerticalSync(bool enable)
{
    glfwSwapInterval(enable ? 1 : 0);
    m_vsync = enable;
}

void CocoaWindow::setIcon(const std::string& /*iconFile*/)
{
    // GLFW icon is set via glfwSetWindowIcon with pixel data; skip for now.
}

void CocoaWindow::setClipboardText(std::string_view text)
{
    if (!m_window) return;
    glfwSetClipboardString((GLFWwindow*)m_window, text.data());
}

TSize<int> CocoaWindow::getDisplaySize()
{
    GLFWmonitor* monitor = glfwGetPrimaryMonitor();
    if (!monitor) return TSize<int>(1920, 1080);
    const GLFWvidmode* mode = glfwGetVideoMode(monitor);
    return TSize<int>(mode->width, mode->height);
}

std::string CocoaWindow::getClipboardText()
{
    if (!m_window) return "";
    const char* text = glfwGetClipboardString((GLFWwindow*)m_window);
    return text ? text : "";
}

int CocoaWindow::internalLoadMouseCursor(const ImagePtr& image, const TPoint<int>& hotSpot)
{
    if (!image) return 0;

    int width  = image->getWidth();
    int height = image->getHeight();
    uint8_t* pixels = image->getPixelData();

    GLFWimage img;
    img.width  = width;
    img.height = height;
    img.pixels = pixels;

    GLFWcursor* cursor = glfwCreateCursor(&img, hotSpot.x, hotSpot.y);
    m_cursors.push_back((void*)cursor);
    return (int)m_cursors.size() - 1;
}

#endif
