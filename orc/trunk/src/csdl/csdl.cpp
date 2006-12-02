/*
 *  CSDL - Wrapper classes for the Simple Direct Media Layer (SDL) and OpenGL
 *  csdl.cpp - CSDL_ApplicationBase
 *
 *  Copyright (C) 2006 Crypticode <crypticode@users.sf.net>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 *  $Id$
 *
 */

#include "csdl.h"

CSDL_ApplicationBase* g_pApp = NULL;

/* constructor and destructor */
CSDL_ApplicationBase::CSDL_ApplicationBase(long flags) {
    m_bIsRunning = true;
    m_pErrorBuffer = new char[256];
    m_bIsOpenGL = (flags & SDL_OPENGL) ? true : false;
    m_bIsFullscreen = false;
    m_PrimarySurface = NULL;
    ::atexit (::SDL_Quit);
    if(flags & SDL_INIT_VIDEO) {
        InitVideo();
    }

    if(flags & SDL_INIT_AUDIO) {
        InitAudio();
    }
    if(flags & SDL_OPENGL) {
//        InitOpenGL();
        SDL_GL_SetAttribute( SDL_GL_DEPTH_SIZE, 16 );
        SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 ) ;
    }


    Uint32          colorkey;
    SDL_Surface     *image;
    image = SDL_LoadBMP("data/Orc.bmp");
    colorkey = SDL_MapRGB(image->format, 255, 0, 255);
    SDL_SetColorKey(image, SDL_SRCCOLORKEY, colorkey);
    SDL_WM_SetIcon(image,NULL);

    SetCaption("Loading...");

    SetVideoMode(800, 600, 32, ((m_bIsFullscreen) ? SDL_FULLSCREEN : 0) | ((m_bIsOpenGL) ? SDL_OPENGL : SDL_HWSURFACE|SDL_DOUBLEBUF));


    m_MouseCursorSurface = new CSDL_Surface("data/cursor.bmp");
//    m_MouseCursorSurface->SetColorKey(255, 0, 255, SDL_SRCCOLORKEY|SDL_RLEACCEL);

    FPS_Init();

} // constructor

CSDL_ApplicationBase::~CSDL_ApplicationBase() {
    // SDL_Quit or atexit ?
    delete [] m_pErrorBuffer;
} // destructor

void CSDL_ApplicationBase::Log(char* msg, ...) {
    va_list va;
    va_start(va, msg);
    ::vsprintf(m_pErrorBuffer, msg, va);
    va_end(va);
}

void CSDL_ApplicationBase::MsgBox(const char* msg, ...) {
    va_list va;
    va_start(va, msg);
    ::vsprintf(m_pErrorBuffer, msg, va);
//#ifdef WIN32
//    ::MessageBox(NULL, m_pErrorBuffer, "Error", MB_ICONHAND|MB_SYSTEMMODAL);
//#else
    ::printf("Error: %s\n", m_pErrorBuffer);
//#endif
    va_end(va);
}

bool CSDL_ApplicationBase::InitVideo() {
    if(::SDL_Init(SDL_INIT_VIDEO) < 0) {
        MsgBox("Couldn't initialise Video: %s", ::SDL_GetError());
        ::exit(EXIT_VIDEO);
    }
    return true;
}

int CSDL_ApplicationBase::InitAudio() {
    // start SDL with audio support
    if(::SDL_Init(SDL_INIT_AUDIO) < 0) {
        MsgBox("Couldn't initialise Audio: %s", ::SDL_GetError());
        ::exit(EXIT_AUDIO);
    }
    // open 44.1KHz, signed 16bit, system byte order,
    // stereo audio, using 1024 byte chunks
    if(::Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 2048) == -1) {
        MsgBox("Mix_OpenAudio: %s\n", ::Mix_GetError());
        ::exit(EXIT_AUDIO);
    }
    return 0;
}

int CSDL_ApplicationBase::SetVideoMode(int width, int height, int bpp, int flags) {
    if(m_PrimarySurface != NULL) {
        delete m_PrimarySurface;
    }

    EnableCursor(SDL_DISABLE);

    m_PrimarySurface = new CSDL_DisplaySurface(width, height, bpp, flags);
    if (m_PrimarySurface == NULL) {
        MsgBox("Couldn't set video mode: %s\n", ::SDL_GetError());
        ::exit(EXIT_FAILURE + 1);
    }
    m_nScreenWidth = width;
    m_nScreenHeight = height;
    m_nScreenBPP = bpp;
    m_nScreenFlags = flags;
    return 0;
}

void CSDL_ApplicationBase::SetCaption(char* str) {
    ::SDL_WM_SetCaption (str, NULL);
}

void CSDL_ApplicationBase::OnQuit() {
    m_bIsRunning = false;
}


void CSDL_ApplicationBase::OnKeypress(SDL_KeyboardEvent key, SDLMod mod) {
    if( (key.type == SDL_KEYDOWN) && (key.keysym.sym == SDLK_RETURN) && (key.keysym.mod & KMOD_ALT) ) {
        ToggleFullscreen();
    }
}

void CSDL_ApplicationBase::ToggleFullscreen() {
    m_nScreenFlags ^= SDL_FULLSCREEN;
    m_bIsFullscreen = (m_nScreenFlags & SDL_FULLSCREEN) ? false : true;

    if( SetVideoMode(m_nScreenWidth, m_nScreenHeight, m_nScreenBPP, m_nScreenFlags) ) {
        if( m_bIsOpenGL ) {
            // TODO: reaquire open gl context, reload textures and states :(
        }
    } else {
        MsgBox("Unable to toggle fullscreen");
    }

}

void CSDL_ApplicationBase::OnMouseMotion(SDL_MouseMotionEvent motion) {
    m_nMouseX = motion.x;
    m_nMouseY = motion.y;
    m_nMouseXrel = motion.xrel;
    m_nMouseYrel = motion.yrel;
    m_nMouseState = motion.state;
}

void CSDL_ApplicationBase::OnAppMouseFocus(Uint8 gain) {
    m_bShowCursor = (gain > 0) ? true : false;
}

int CSDL_ApplicationBase::EnableCursor(int state) {
    return ::SDL_ShowCursor(state);
}

void CSDL_ApplicationBase::OnPreEvents() {
    //
}

    void CSDL_ApplicationBase::OnPostEvents() {
        //    Uint32 color;
        //    color = ::SDL_MapRGB (m_PrimarySurface->surface->format, 0, 0, 0);
        //    ::SDL_FillRect (m_PrimarySurface->surface, NULL, color);
        // ::SDL_FillRect(m_PrimarySurface->surface, NULL, 0);
        OnPaint(m_PrimarySurface, TICK_INTERVAL);
        if(m_bShowCursor == true) {
            SDL_Rect rc = {
                              m_nMouseX-16, m_nMouseY-16, m_MouseCursorSurface->surface->clip_rect.w, m_MouseCursorSurface->surface->clip_rect.h
                          };
            m_MouseCursorSurface->Blit(&m_MouseCursorSurface->surface->clip_rect, m_PrimarySurface, &rc);
        }
        if( m_bIsOpenGL ) {
            SDL_GL_SwapBuffers();
        } else {
            m_PrimarySurface->Flip();
        }

        ::SDL_Delay(FPS_TimeLeft());
        m_nNexttime += TICK_INTERVAL;
        FPS_Update();
    }


    void CSDL_ApplicationBase::FPS_Init() {
        memset(m_nFrametimes, 0, sizeof(m_nFrametimes));
        m_nFramecount = 0;
        m_fFPS = 0.0;
        m_nFrametimeLast = ::SDL_GetTicks();
        m_nNexttime = ::SDL_GetTicks();
    }

    void CSDL_ApplicationBase::FPS_Update() {
        Uint32 frametimesindex;
        Uint32 getticks;
        Uint32 count;
        Uint32 i;

        frametimesindex = m_nFramecount % FRAME_VALUES;
        getticks = ::SDL_GetTicks();
        m_nFrametimes[frametimesindex] = getticks - m_nFrametimeLast;
        m_nFrametimeLast = getticks;
        m_nFramecount++;
        if (m_nFramecount < FRAME_VALUES) {
            count = m_nFramecount;
        }
        else {
            count = FRAME_VALUES;
        }

        m_fFPS = 0;
        for (i = 0; i < count; i++) {
            m_fFPS += m_nFrametimes[i];
        }
        m_fFPS /= count;
        m_fFPS = 1000.0 / m_fFPS;
    }

    Uint32 CSDL_ApplicationBase::FPS_TimeLeft() {
        Uint32 now;
        now = ::SDL_GetTicks();
        if(m_nNexttime <= now)
            return 0;
        else
            return m_nNexttime - now;
    }

    int CSDL_ApplicationBase::Main(int argc, char *argv[]) {
        while(m_bIsRunning) {
            m_pKeystate = ::SDL_GetKeyState(NULL);
            m_Modstate = ::SDL_GetModState();
            HandleEvents();
        }

        return EXIT_SUCCESS;
    }

