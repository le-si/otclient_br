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

#include "graphics.h"

#include "fontmanager.h"
#include <framework/platform/platformwindow.h>
#include "painter.h"
#include "texturemanager.h"
#include <framework/core/logger.h>

Graphics g_graphics;

#ifdef __APPLE__
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#endif

void Graphics::init()
{
    fprintf(stderr, "[DEBUG] Graphics::init() START\n");
#ifndef OPENGL_ES
    // On macOS/Core Profile, glewExperimental is often required to load extensions correctly.
    g_window.makeCurrent();
    
    fprintf(stderr, "[DEBUG] Graphics::init: Initializing GLEW...\n");
    glewExperimental = GL_TRUE;
    const GLenum err = glewInit();
    if (err != GLEW_OK) {
        fprintf(stderr, "[DEBUG] GLEW init FAILED: %s\n", (const char*)glewGetErrorString(err));
        g_logger.error("Graphics::init: GLEW initialization failed: {}", (const char*)glewGetErrorString(err));
    } else {
        fprintf(stderr, "[DEBUG] GLEW init OK\n");
    }
    
    // Clear any error set by glewInit (common with glewExperimental)
    while (glGetError() != GL_NO_ERROR);
#endif

    auto glStringProc = (const GLubyte* (*)(GLenum))glGetString;
#ifdef __APPLE__
    if (auto proc = (const GLubyte* (*)(GLenum))glfwGetProcAddress("glGetString")) {
        glStringProc = proc;
    }
#endif

    if (const auto* v = reinterpret_cast<const char*>(glStringProc(GL_VENDOR)))
        m_vendor = v;

    if (const auto* v = reinterpret_cast<const char*>(glStringProc(GL_RENDERER)))
        m_renderer = v;

    if (const auto* v = reinterpret_cast<const char*>(glStringProc(GL_VERSION)))
        m_version = v;

    if (const auto* v = reinterpret_cast<const char*>(glStringProc(GL_EXTENSIONS)))
        m_extensions = v;

    g_logger.info("GPU {}", glStringProc(GL_RENDERER) ? (const char*)glStringProc(GL_RENDERER) : "");
    g_logger.info("OpenGL {}", glStringProc(GL_VERSION) ? (const char*)glStringProc(GL_VERSION) : "");

#ifndef OPENGL_ES
    // overwrite framebuffer API if needed
    if (GLEW_EXT_framebuffer_object && !GLEW_ARB_framebuffer_object) {
        glGenFramebuffers = glGenFramebuffersEXT;
        glDeleteFramebuffers = glDeleteFramebuffersEXT;
        glBindFramebuffer = glBindFramebufferEXT;
        glFramebufferTexture2D = glFramebufferTexture2DEXT;
        glCheckFramebufferStatus = glCheckFramebufferStatusEXT;
        glGenerateMipmap = glGenerateMipmapEXT;
    }
#endif

    // blending is always enabled
    glEnable(GL_BLEND);

    // determine max texture size
    int maxTextureSize = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
    if (m_maxTextureSize == -1 || m_maxTextureSize > maxTextureSize)
        m_maxTextureSize = maxTextureSize;

    m_alphaBits = 0;
    glGetIntegerv(GL_ALPHA_BITS, &m_alphaBits);

    m_ok = true;
    fprintf(stderr, "[DEBUG] Graphics::init: creating Painter...\n");

    g_painter = std::make_unique<Painter>();
    fprintf(stderr, "[DEBUG] Graphics::init: Painter created OK\n");

    g_textures.init();
    fprintf(stderr, "[DEBUG] Graphics::init: Textures init OK\n");

    g_fonts.init();
    fprintf(stderr, "[DEBUG] Graphics::init() DONE\n");

}

void Graphics::terminate()
{
    g_painter = nullptr;
    g_fonts.terminate();
    g_textures.terminate();

    m_ok = false;
}

void Graphics::resize(const Size& size) { m_viewportSize = size; }