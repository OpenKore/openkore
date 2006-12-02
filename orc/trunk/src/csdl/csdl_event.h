/*
 *  CSDL - Wrapper classes for the Simple Direct Media Layer (SDL) and OpenGL
 *  csdl_event.h - CSDL_EventHandler
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

#ifndef CSDL_EVENT_H
#define CSDL_EVENT_H

#include <SDL.h>

class CSDL_EventHandler {
    public:
        CSDL_EventHandler();
        virtual ~CSDL_EventHandler();

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
