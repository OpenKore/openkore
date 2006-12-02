/*
 *  CSDL - Wrapper classes for the Simple Direct Media Layer (SDL) and OpenGL
 *  csdl_surface.h - CSDL_Surface and CSDL_SubSurface
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

#ifndef CSDL_SURFACE_H
#define CSDL_SURFACE_H


#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#include <SDL.h>
#include <SDL/SDL_image.h>

/*
    Wrapper class for SDL_Surface
*/
class CSDL_Surface {
    public:
        SDL_Surface *surface;
        // TODO: SDL_Rect cliprect

        // Constructor and destructor
        CSDL_Surface(); // Create a empty Surface
        CSDL_Surface(const char *file); // Load a BMP
        CSDL_Surface(SDL_RWops* rwops); // Load a BMP from RWops

        // TODO: CSDL_Surface(CSDL_Surface &tmp); // Copy constructor
        CSDL_Surface(Uint16 width, Uint16 height, Uint8 bpp, Uint32 flags);
        virtual ~CSDL_Surface();

        CSDL_Surface(Uint16 width, Uint16 height, Uint8 bpp, void* ptr, long pitch);

        // Initialisation functions
        virtual void CreateSurface(Uint16 width, Uint16 height, Uint8 bpp, Uint32 flags);
        void SetPixelFunction();

        // DrawPixel
        void DrawPixel(Uint16 x, Uint16 y, Uint8 R, Uint8 G, Uint8 B);
        void DrawPixel(Uint16 x, Uint16 y, Uint8 R, Uint8 G, Uint8 B, Uint8 A);
        void DrawPixel(Uint16 x, Uint16 y, Uint32 C);

        // Fixed font support
        // TODO: Support Bitmap-Fonts and SDL_TTF
        // Flexible Texturing for the Fixed Fonts, Color, Gradient, Texture
        int RenderGlyph8x8(Uint8* data, int x, int y, char n, Uint8 R, Uint8 G, Uint8 B);
        void RenderText(int x, int y, char* str, Uint8 R, Uint8 G, Uint8 B);

        // Wrapper functions
        void Lock();
        void Unlock();

        bool LoadBMP(const char *file);
        bool LoadBMP_RW(SDL_RWops* rwops);

        bool LoadImage_RW(SDL_RWops* rwops);

        bool SaveBMP(const char *file);

        int SetColorKey(Uint8 R, Uint8 G, Uint8 B, Uint32 flag);

        int BlitSurface(CSDL_Surface *src, SDL_Rect *srcrect, CSDL_Surface *dst, SDL_Rect *dstrect);
        int Blit(SDL_Rect *srcrect, CSDL_Surface *dst, SDL_Rect *dstrect);

    protected:

    private:
        // Individual pixel functions
        void DrawPixel8(Uint16 x, Uint16 y, Uint32 C);
        void DrawPixel16(Uint16 x, Uint16 y, Uint32 C);
        void DrawPixel24(Uint16 x, Uint16 y, Uint32 C);
        void DrawPixel32(Uint16 x, Uint16 y, Uint32 C);
        void (CSDL_Surface::*m_pDrawPixelFunc)(Uint16 x, Uint16 y, Uint32 C);
};



class CSDL_SubSurface : public CSDL_Surface {
    public:
        Uint16 m_nSubWidth;
        Uint16 m_nSubHeight;
        Uint8 m_nSubCols;
        Uint8 m_nSubRows;
        Uint8 m_nFrames;

        // Constructor and destructor
        CSDL_SubSurface(const char *file, int width, int height); // Load a BMP
        ~CSDL_SubSurface();

        int Blit(int nFrame, CSDL_Surface *dst, SDL_Rect *dstrect);
};



class CSDL_DisplaySurface : public CSDL_Surface {
      public:
            CSDL_DisplaySurface(Uint16 width, Uint16 height, Uint8 bpp, Uint32 flags);
            ~CSDL_DisplaySurface();

            void CreateSurface(Uint16 width, Uint16 height, Uint8 bpp, Uint32 flags);

            void Flip();
      private:
      protected:
};

#endif // CSDL_SURFACE_H
