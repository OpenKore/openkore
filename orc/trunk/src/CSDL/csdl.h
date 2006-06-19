#ifndef CSDL_H
#define CSDL_H

// what do i need here, c or c++ headers ??
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#ifdef WIN32
#include <windows.h>
#endif

//
#include <SDL/SDL.h>
#include <SDL/SDL_mixer.h>
#include <SDL/SDL_image.h>

#include <SDL/SDL_opengl.h>

#include "csdl_surface.h"
#include "csdl_event.h"
#include "csdl_audio.h"

#include "csdl_gl.h"

#define EXIT_OK     EXIT_SUCCESS
#define EXIT_VIDEO  EXIT_FAILURE + 1
#define EXIT_AUDIO  EXIT_FAILURE + 2


#define FRAME_VALUES 10
#define TICK_INTERVAL 30


class CSDL_ApplicationBase : public CSDL_EventHandler {
    public:
        /* constructor and destructor */
        CSDL_ApplicationBase(long flags);
        ~CSDL_ApplicationBase();


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
        int InitVideo();
        int SetVideoMode(int width, int height, int bpp, int flags);
        void ToggleFullscreen();


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

#endif // CSDL_H
