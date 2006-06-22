/*
 *  CSDL - Wrapper classes for the Simple Direct Media Layer (SDL) and OpenGL
 *  csdl_event.cpp - CSDL_EventHandler
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
