/*
 *  CSDL - Wrapper classes for the Simple Direct Media Layer (SDL) and OpenGL
 *  csdl.h - CSDL_ApplicationBase
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

#ifndef CSDL_H
#define CSDL_H

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <math.h>

#ifdef WIN32
	#include <windows.h>
#endif

#include <SDL.h>
#include <SDL/SDL_mixer.h>
#include <SDL/SDL_image.h>
#include <SDL_opengl.h>

#include "csdl_surface.h"
#include "csdl_event.h"
#include "csdl_audio.h"
#include "csdl_gl.h"

// Used to indicate the reason for a failure to the calling process
#define EXIT_OK     EXIT_SUCCESS
#define EXIT_VIDEO  EXIT_FAILURE + 1
#define EXIT_AUDIO  EXIT_FAILURE + 2

// Round the framerate over 10 frames
#define FRAME_VALUES 10

// Fixed frame rate = 1000/30 = 33.3
#define TICK_INTERVAL 30


// Used to create a instance of a derived class with SET_ENTRY_CLASS
class CSDL_ApplicationBase; // Forward declaration
extern CSDL_ApplicationBase* g_pApp;


class CSDL_ApplicationBase : public CSDL_EventHandler {
    public:
        /* constructor and destructor */
        CSDL_ApplicationBase() { }

        CSDL_ApplicationBase(long flags);
        virtual ~CSDL_ApplicationBase();


        CSDL_DisplaySurface* m_PrimarySurface;
        CSDL_Surface* m_MouseCursorSurface;

        bool m_bIsRunning;
        bool m_bIsOpenGL;
        bool m_bIsFullscreen;

        char* m_pErrorBuffer;

        Uint8 *m_pKeystate;
        SDLMod m_Modstate;

        inline bool IsKeyPressed(int keysym) {
            return ( m_pKeystate[keysym] );
        }

        inline bool IsKeyPressed(SDLMod mod) {
            return ( m_Modstate & mod );
        }

        void Log(char* msg, ...);
        void MsgBox(const char* msg, ...);

        /* Video handling */
        Uint16 m_nScreenWidth;
        Uint16 m_nScreenHeight;
        Uint8 m_nScreenBPP;
        Uint32 m_nScreenFlags;

        bool InitVideo(); // OpenGL need a different setup

        int SetVideoMode(int width, int height, int bpp, int flags);
        virtual void ToggleFullscreen();


        /* Audio handling */
        int InitAudio();

        /* Mouse handling */
        int EnableCursor(int state);
        int m_nMouseX, m_nMouseY, m_nMouseXrel, m_nMouseYrel, m_nMouseState;
        bool m_bShowCursor;

        void SetCaption(char* str);

        virtual int Main(int argc, char *argv[]);

        void OnQuit();

        virtual void OnPreEvents();
        virtual void OnPostEvents();
        virtual void OnPaint(CSDL_Surface* display, double dt) { }

        void OnKeypress(SDL_KeyboardEvent key, SDLMod mod);
        void OnMouseMotion(SDL_MouseMotionEvent motion);
        void OnAppMouseFocus(Uint8 gain);

        /* FPS measure and control */
        Uint32 m_nFrametimes[FRAME_VALUES];
        Uint32 m_nFrametimeLast;
        Uint32 m_nFramecount;
        Uint32 m_nNexttime;
        float m_fFPS;

        void FPS_Init();
        void FPS_Update();
        Uint32 FPS_TimeLeft();

};

class CSDLGL_ApplicationBase : public CSDL_ApplicationBase {
    public:
        /* constructor and destructor */
        CSDLGL_ApplicationBase();
        ~CSDLGL_ApplicationBase();

        bool InitVideoMode(int width, int height, int bpp);

        virtual void ToggleFullscreen();
        virtual void OnPostEvents();

        virtual void ResizeGL( GLsizei w, GLsizei h );
        virtual bool InitGL();
};


#endif // CSDL_H
