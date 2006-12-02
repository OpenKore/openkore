/*
 *  CSDL - Wrapper classes for the Simple Direct Media Layer (SDL) and OpenGL
 *  csdl_surface.cpp - CSDL_Surface and CSDL_SubSurface
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

#include <math.h>
#include "csdl_surface.h"

#include "textfont8x8.h"

CSDL_SubSurface::CSDL_SubSurface(const char *file, int width, int height) : CSDL_Surface(file) {
    m_nSubWidth = width;
    m_nSubHeight = height;
    m_nSubCols = surface->w / width;
    m_nSubRows = surface->h / height;
    m_nFrames = m_nSubCols * m_nSubRows;
}
CSDL_SubSurface::~CSDL_SubSurface() {
    // destructor
}
int CSDL_SubSurface::Blit(int nFrame, CSDL_Surface *dst, SDL_Rect *dstrect) {

	int row = 1 + (int) floor(nFrame / m_nSubCols);
    int col = 1+ (nFrame % m_nSubCols);
    int x, y, w, h;

    x = ((col - 1) * m_nSubWidth);
    y = ((row - 1) * m_nSubHeight);
    w = m_nSubWidth;
    h = m_nSubHeight;

    SDL_Rect rc = {
                      x, y, w, h
                  };

    CSDL_Surface::Blit(&rc, dst, dstrect);
    return 0;
}
CSDL_Surface::CSDL_Surface() : surface(NULL) {
    CreateSurface(32, 32, 32, SDL_HWSURFACE);   // TODO: flags for constructor
    ::SDL_FillRect(surface, NULL, 0x808080);
}
CSDL_Surface::CSDL_Surface(const char* file) : surface(NULL) {
    if( !LoadBMP(file) ) {
        CSDL_Surface::CSDL_Surface();
    }
}
CSDL_Surface::CSDL_Surface(SDL_RWops* rwops) : surface(NULL) {
    // LoadBMP_RW(rwops);
    LoadImage_RW(rwops);

}

CSDL_Surface::CSDL_Surface(Uint16 width, Uint16 height, Uint8 bpp, Uint32 flags) : surface(NULL) {
    // constructor
    CreateSurface(width, height, bpp, flags);
}

CSDL_Surface::CSDL_Surface(Uint16 width, Uint16 height, Uint8 bpp, void* ptr, long pitch) : surface(NULL) {
    // constructor
    surface = ::SDL_CreateRGBSurfaceFrom(ptr, width, height, bpp, pitch, 0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
}
CSDL_Surface::~CSDL_Surface() {
    // destructor
}

void CSDL_Surface::Lock() {
    ::SDL_LockSurface(surface);
}

void CSDL_Surface::Unlock() {
    ::SDL_UnlockSurface(surface);
}

bool CSDL_Surface::LoadBMP(const char *file) {
    SDL_Surface* s = ::SDL_LoadBMP(file);
    if(s == NULL) {
        fprintf(stderr, "LoadBMP failed: %s\n", ::SDL_GetError());
        return false;
        //        exit(1);
    }
    else {
        if(surface != NULL) {
            ::SDL_FreeSurface(surface);
        }
        surface = s;
        return true;
    }
}

bool CSDL_Surface::LoadBMP_RW(SDL_RWops* rwops) {
    SDL_Surface* s = ::SDL_LoadBMP_RW(rwops, 1);
    if(s == NULL) {
        fprintf(stderr, "LoadBMP_RW failed: %s\n", ::SDL_GetError());
        return false;
        //        exit(1);
    }
    else {
        if(surface != NULL) {
            ::SDL_FreeSurface(surface);
        }
        surface = s;
        return true;
    }
}
bool CSDL_Surface::LoadImage_RW(SDL_RWops* rwops) {
    SDL_Surface* s = ::IMG_Load_RW(rwops, 1);
    if(s == NULL) {
        fprintf(stderr, "IMG_Load_RW failed: %s\n", ::SDL_GetError());
        return false;
        //        exit(1);
    }
    else {
        if(surface != NULL) {
            ::SDL_FreeSurface(surface);
        }
        surface = s;
        return true;
    }
}
bool CSDL_Surface::SaveBMP(const char *file) {
    if(surface == NULL) {
        fprintf(stderr, "SaveBMP failed: %s\n", ::SDL_GetError());
        return false;
        //        exit(1);
    }
    else {
        ::SDL_SaveBMP(surface, file);
        return true;
    }
}

int CSDL_Surface::SetColorKey(Uint8 R, Uint8 G, Uint8 B, Uint32 flag) {
    return ::SDL_SetColorKey(surface, flag, ::SDL_MapRGB(surface->format, R, G, B));
}

int CSDL_Surface::BlitSurface(CSDL_Surface *src, SDL_Rect *srcrect, CSDL_Surface *dst, SDL_Rect *dstrect) {
    return ::SDL_BlitSurface(src->surface, srcrect, dst->surface, dstrect);
}

int CSDL_Surface::Blit(SDL_Rect *srcrect, CSDL_Surface *dst, SDL_Rect *dstrect) {
    return 0; // BlitSurface(this, srcrect, dst, dstrect);
}

void CSDL_Surface::CreateSurface(Uint16 width, Uint16 height, Uint8 bpp, Uint32 flags) {
    Uint32 rmask, gmask, bmask, amask;

    /* SDL interprets each pixel as a 32-bit number, so our masks must depend
       on the endianness (byte order) of the machine */
    if(bpp == 32) {
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
        rmask = 0xff000000;
        gmask = 0x00ff0000;
        bmask = 0x0000ff00;
        amask = 0x000000ff;
#else

        rmask = 0x000000ff;
        gmask = 0x0000ff00;
        bmask = 0x00ff0000;
        amask = 0xff000000;
#endif

    }

    surface = ::SDL_CreateRGBSurface(flags, width, height, bpp, rmask, gmask, bmask, amask);
    if(surface == NULL) {
        fprintf(stderr, "CreateRGBSurface failed: %s\n", ::SDL_GetError());
        //        exit(1);
    }
    SetPixelFunction();
} // EOF

void CSDL_Surface::SetPixelFunction() {
    switch (surface->format->BytesPerPixel) {
        case 1: {
            m_pDrawPixelFunc = &CSDL_Surface::DrawPixel8;
        }
        break;
        case 2: {
            m_pDrawPixelFunc = &CSDL_Surface::DrawPixel16;
        }
        break;
        case 3: {
            m_pDrawPixelFunc = &CSDL_Surface::DrawPixel24;
        }
        break;
        case 4: {
            m_pDrawPixelFunc = &CSDL_Surface::DrawPixel32;
        }
        break;
        default:

        break;
    } // switch
}


void CSDL_Surface::DrawPixel(Uint16 x, Uint16 y, Uint8 R, Uint8 G, Uint8 B) {
    Uint32 C = SDL_MapRGB(surface->format, R, G, B);
    (this->*m_pDrawPixelFunc)(x, y, C);
}
void CSDL_Surface::DrawPixel(Uint16 x, Uint16 y, Uint8 R, Uint8 G, Uint8 B, Uint8 A) {
    Uint32 C = SDL_MapRGBA(surface->format, R, G, B, A);
    (this->*m_pDrawPixelFunc)(x, y, C);
}
void CSDL_Surface::DrawPixel(Uint16 x, Uint16 y, Uint32 C) {
    (this->*m_pDrawPixelFunc)(x, y, C);
}

// Assuming 8-bpp
void CSDL_Surface::DrawPixel8(Uint16 x, Uint16 y, Uint32 C) {
    Uint8 *bufp;
    bufp = (Uint8*)surface->pixels + y*surface->pitch + x;
    *bufp = C;
}
// Probably 15-bpp or 16-bpp
void CSDL_Surface::DrawPixel16(Uint16 x, Uint16 y, Uint32 C) {
    Uint16 *bufp;
    bufp = (Uint16*)surface->pixels + y*surface->pitch/2 + x;
    *bufp = C;
}
// Slow 24-bpp mode, usually not used
void CSDL_Surface::DrawPixel24(Uint16 x, Uint16 y, Uint32 C) {
    Uint8 *bufp;
    bufp = (Uint8 *)surface->pixels + y*surface->pitch + x * 3;
    if(SDL_BYTEORDER == SDL_LIL_ENDIAN) {
        bufp[0] = C;
        bufp[1] = C >> 8;
        bufp[2] = C >> 16;
    }
    else {
        bufp[2] = C;
        bufp[1] = C >> 8;
        bufp[0] = C >> 16;
    }
}
// Probably 32-bpp
void CSDL_Surface::DrawPixel32(Uint16 x, Uint16 y, Uint32 C) {
    Uint32 *bufp;
    bufp = (Uint32 *)surface->pixels + y*surface->pitch/4 + x;
    *bufp = C;
}



/* Renders the n'th Glyph from the font pointed to by data */
int CSDL_Surface::RenderGlyph8x8(Uint8* data, int x, int y, char n, Uint8 R, Uint8 G, Uint8 B ) {
    Uint8 rowbits;
    Uint16 index, px = x, py = y;
    index = n << 3; // Glyph number * 8
    if(x+7 > 640-1)
        return -1;
    if(y+7 > 480-1)
        return -2;
    for(Uint8 row=0; row<8; row++, px=x, py++) {
        if(py >= 480-1)
            break;
        rowbits = data[index++];
        for(Uint8 col=0; col<8; col++, px++) {
            if(px >= 640-1)
                break;
            if(rowbits & (128 >> col)) { // Is the col'th bit set ?
                DrawPixel(px, py, R, G, B);
            }
        }
    }
    return 0;
} // RenderGlyph8x8


void CSDL_Surface::RenderText(int x, int y, char* str, Uint8 R, Uint8 G, Uint8 B) {
    int px = x, py = y, flag;
    Lock();
    for(unsigned int i=0; i<strlen(str); i++) {
        if(str[i] < 32) { // Control code
            switch(str[i]) {
                case 9:
                px += 8*(8*(1-(px/8)));
                break; // \t
                case 10:
                py += 8;
                break; // \n
                case 13:
                px = x;
                break; // \r
                default:
                break;
            }
        }
        else {
        TRY:
            flag = RenderGlyph8x8(textfont8x8, px, py, str[i] - 32, R, G, B);
            if(flag == -1) {
                py += 8;
                px=0;
                goto TRY;
            }
            if(flag == -2)
                return;
            px += 8;
        }
    }
    Unlock();
} // RenderText


/*
    CSDL_DisplaySurface
*/
CSDL_DisplaySurface::CSDL_DisplaySurface(Uint16 width, Uint16 height, Uint8 bpp, Uint32 flags) {
    CreateSurface(width, height, bpp, flags);
}
CSDL_DisplaySurface::~CSDL_DisplaySurface() {
    ::SDL_FreeSurface(surface);
}
void CSDL_DisplaySurface::Flip() {
    ::SDL_Flip(surface);
}
void CSDL_DisplaySurface::CreateSurface(Uint16 width, Uint16 height, Uint8 bpp, Uint32 flags) {
    surface = ::SDL_SetVideoMode(width, height, bpp, flags);
    if(surface == NULL) {
        fprintf(stderr, "SetVideoMode failed: %s\n", ::SDL_GetError());
        exit(1);
    }
    SetPixelFunction();
}

