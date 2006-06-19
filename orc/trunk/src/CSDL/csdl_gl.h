/*
 *  CSDL - Wrapper classes for the Simple Direct Media Layer (SDL) and OpenGL
 *  csdl_gl.h - Wrapper for SDL & GL
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

#ifndef CSDL_GL_H
#define CSDL_GL_H

/*
    I've never read if this type of recursive including is actually recommended.
    If someone knowns, please tell me. (Crypticode)
*/
#include "csdl.h"


/* I'm a very lazy sock */
#define ZERO    0.0f
#define ONE     1.0f
#define HALF    0.5f
#define QUATER  0.25f


/*
    I don't like this approach cause CSDL should be able to be a library sometimes in the future...
*/
#include "../grf_interface.h"
extern CGRF_Interface* g_pGrfInterface;

/*
    SDL_GL_LoadTexture was taken from the SDL mailing list. Though it works i don't like it because:

    1.) Libgrf loads the texture file into memory completly where it resides until the program ends. (e.g. ~2MB for 800x600)
        We use this 2MB as SDL_Surface meaning it will be forced to stay in System Memory.
    2.) SDL_GL_LoadTexture creates another temporarily SDL_Surface in System Memory, but in a size that fits OpenGL's specs
        (3 or 4 MB for 1024x1024), this is then uploaded to OpenGL (Video Memory) where it also stays until its lost. That
        only happens if OpenGL is re-initialised (Toggle Fullscreen). The temporarily surface is then freed.
    3.) But the 2MB from above stay unused in System Memory until Libgrf is closed.

    TODO: We should use grf_chunk_get in the grf_interface and combine 1&2, also there should be a texture cache in a way
          that we can use it like this: glBindTexture( GL_TEXTURE_2D, g_pTextureManager->GetAsGLuint("file.bmp") );
*/
class CSDL_GL_Texture {
public:
    CSDL_GL_Texture( char* grfpath, int alpha ) {
        CSDL_Surface * temp = new CSDL_Surface( g_pGrfInterface->GetTexture( grfpath ) );
        m_iID = SDL_GL_LoadTexture( temp->surface, &m_fRC[ 0 ], alpha );

        if ( !m_iID ) {
            printf( "Error loading texture ...\n" );
        }

        delete temp;
    }

    ~CSDL_GL_Texture() { }

    GLuint m_iID;
    GLfloat m_fRC[ 4 ];

private:
    /* Quick utility function for texture creation */
    static inline int power_of_two( int input ) {
        int value = 1;
        while ( value < input ) {
            value <<= 1;
        }
        return value;
    } // power_of_two

    GLuint SDL_GL_LoadTexture( SDL_Surface *surface, GLfloat *texcoord, int alpha );
};


// OpenGL helper function
void DisplayBoundingBox(float *max, float *min, float r, float g, float b);

void goOrtho();
void goPerspective();

int InitGL();
void ReSizeGLScene( GLsizei w, GLsizei h );


#endif // CSDL_GL_H
