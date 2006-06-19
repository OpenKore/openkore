#ifndef CSDL_EVENT_H
#define CSDL_EVENT_H

#include <SDL/SDL.h>

class CSDL_EventHandler {
    public:
        CSDL_EventHandler();
        ~CSDL_EventHandler();

        void HandleEvents();

        virtual void OnAppMouseFocus(Uint8 gain) { }
        virtual void OnAppInputFocus(Uint8 gain) { }
        virtual void OnRestore() { }
        virtual void OnMinimize() { }

        virtual void OnKeypress(SDL_KeyboardEvent key, SDLMod mod) { }
        virtual void OnMouseMotion(SDL_MouseMotionEvent motion) { }
        virtual void OnMouseButton(SDL_MouseButtonEvent button) { }
        virtual void OnJoyAxisMotion(SDL_JoyAxisEvent axis) { }
        virtual void OnJoyBallMotion(SDL_JoyBallEvent ball) { }
        virtual void OnJoyHatMotion(SDL_JoyHatEvent hat) { }
        virtual void OnJoyButton(SDL_JoyButtonEvent joybutton) { }
        virtual void OnSysWM(SDL_SysWMEvent syswm) { }

        virtual void OnChar(Uint8 chr) { }
        virtual void OnPreEvents() { }
        virtual void OnPostEvents() { }

        virtual void OnQuit() { }
    private:
        SDL_Event event;
};

#endif // CSDL_EVENT_H
