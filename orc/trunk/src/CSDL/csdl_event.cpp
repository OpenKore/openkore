#include "csdl_event.h"

/*
    CSDL_EventHandler
*/
CSDL_EventHandler::CSDL_EventHandler() {}
CSDL_EventHandler::~CSDL_EventHandler() {}
void CSDL_EventHandler::HandleEvents() {
    OnPreEvents();
    while(::SDL_PollEvent(&event)) {
        switch (event.type) {
            case SDL_ACTIVEEVENT:
            switch(event.active.state) {
                case SDL_APPMOUSEFOCUS:
                OnAppMouseFocus(event.active.gain);
                break;
                case SDL_APPINPUTFOCUS:
                OnAppInputFocus(event.active.gain);
                break;
                case SDL_APPACTIVE:
                if(event.active.gain) {
                    OnRestore();
                }
                else {
                    OnMinimize();
                }
                break;
            }
            break;
            case SDL_KEYDOWN:
            case SDL_KEYUP:
            OnKeypress(event.key, event.key.keysym.mod);
            break;
            case SDL_MOUSEMOTION:
            OnMouseMotion(event.motion);
            break;
            case SDL_MOUSEBUTTONDOWN:
            break;
            case SDL_MOUSEBUTTONUP:
            break;
            case SDL_JOYAXISMOTION:
            break;
            case SDL_JOYBALLMOTION:
            break;
            case SDL_JOYHATMOTION:
            break;
            case SDL_JOYBUTTONDOWN:
            break;
            case SDL_JOYBUTTONUP:
            break;
            case SDL_QUIT:
            OnQuit();
            break;
            case SDL_SYSWMEVENT:
            break;
            case SDL_VIDEORESIZE:
            break;
            case SDL_VIDEOEXPOSE:
            break;
            case SDL_USEREVENT:
            break;

            default:
            break;
        }
    }
    OnPostEvents();
} // HandleEvents()
