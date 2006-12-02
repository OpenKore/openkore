/*
 *  CSDL - Wrapper classes for the Simple Direct Media Layer (SDL) and OpenGL
 *  csdl_gl.cpp - Wrapper for SDL & GL
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

#include "csdl_gl.h"



/* constructor and destructor */
CSDLGL_ApplicationBase::CSDLGL_ApplicationBase() : CSDL_ApplicationBase(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_OPENGL){

    m_bIsOpenGL = true; // tell CSDL_ApplicationBase that it has a OpenGL descendant

    // Set OpenGL pre-initialisation attributes
    SDL_GL_SetAttribute( SDL_GL_DEPTH_SIZE, 16 );
    SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 ) ;



} // constructor

CSDLGL_ApplicationBase::~CSDLGL_ApplicationBase() {
} // destructor

bool CSDLGL_ApplicationBase::InitVideoMode(int width, int height, int bpp) {
    SetVideoMode(width, height, bpp, ((m_bIsFullscreen) ? SDL_FULLSCREEN : 0) | ((m_bIsOpenGL) ? SDL_OPENGL : SDL_HWSURFACE|SDL_DOUBLEBUF));
    return true;
}

void CSDLGL_ApplicationBase::ToggleFullscreen() {
    m_nScreenFlags ^= SDL_FULLSCREEN;
    m_bIsFullscreen = (m_nScreenFlags & SDL_FULLSCREEN) ? false : true;

    if( SetVideoMode(m_nScreenWidth, m_nScreenHeight, m_nScreenBPP, m_nScreenFlags) ) {
        InitGL();
        ResizeGL(m_nScreenWidth, m_nScreenHeight);
        // TODO: Reload textures
    } else {
        MsgBox("Unable to toggle fullscreen");
    }

}

void CSDLGL_ApplicationBase::OnPostEvents() {
    OnPaint(m_PrimarySurface, TICK_INTERVAL);   // Let our descendants do their dispaying
    ::SDL_GL_SwapBuffers();                     // Bring it on screen

    ::SDL_Delay(FPS_TimeLeft());                // Keep up the fixed frame rate, TODO: only code it in SDL_ApplicationBase
     m_nNexttime += TICK_INTERVAL;
     FPS_Update();
}

void CSDLGL_ApplicationBase::ResizeGL( GLsizei w, GLsizei h ) {
    glViewport ( 0, 0, ( GLsizei ) w, ( GLsizei ) h );
    glMatrixMode ( GL_PROJECTION );
    glLoadIdentity();
    gluPerspective ( 40.0, ( float ) w / ( float ) h, 1.0, 1000.0 );
    glMatrixMode ( GL_MODELVIEW );
    glLoadIdentity();
}

bool CSDLGL_ApplicationBase::InitGL() {
    float fogColor[ 4 ] = {0.95f, 0.95f, 1.0f, 1.0f};
    float ambience[ 4 ] = {0.3f, 0.3f, 0.3f, 1.0};      // The color of the light in the world
    float diffuse[ 4 ] = {1.0f, 1.0f, 1.0f, 1.0};       // The color of the positioned light
    float light0[ 3 ] = {1.0f, 1.0f, 1.0f};             // The color of the positioned light

    glClearColor ( 1.0f, 1.0f, 1.0f, 0.0f );            // Set the clearing color and depth
    glClearDepth( 1.0f );

    glFogi( GL_FOG_MODE, GL_EXP2 );                     // Fog Mode
    glFogfv( GL_FOG_COLOR, fogColor );                  // Set Fog Color
    glFogf( GL_FOG_DENSITY, 0.05f );                    // How Dense Will The Fog Be
    glHint( GL_FOG_HINT, GL_DONT_CARE );                // The Fog's calculation accuracy
    glFogf( GL_FOG_START, 1.0f );                       // Fog Start Depth
    glFogf( GL_FOG_END, 1000.0f );                      // Fog End Depth

    glShadeModel ( GL_SMOOTH );

    glLightfv( GL_LIGHT0, GL_AMBIENT, ambience );       // Set our ambience values (Default color without direct light)
    glLightfv( GL_LIGHT0, GL_DIFFUSE, diffuse );        // Set our diffuse color (The light color)
    glLightfv( GL_LIGHT0, GL_POSITION, light0 );        // This Sets our light position

    glEnable( GL_COLOR_MATERIAL );
    glEnable( GL_TEXTURE_2D );

    glEnable( GL_LIGHTING );                            // This turns on lighting
    glEnable( GL_LIGHT0 );                              // Turn this light on

    glEnable( GL_DEPTH_TEST );                          // Enable z-buffer
    glDepthFunc( GL_LEQUAL );

    glEnable( GL_BLEND );                               // Enable Blending (disable alpha testing)
    glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );

    glHint( GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST );
    glEnable(GL_FOG);

    glFrontFace(GL_CW);
    glEnable(GL_CULL_FACE);

    return true;                                        // Initialization Went OK
}


GLuint CSDL_GL_Texture::SDL_GL_LoadTexture( SDL_Surface *surface, float *texcoord, int alpha ) {
    GLuint texture;
    int w, h;
    SDL_Surface *image;
    SDL_Rect area;
    Uint32 saved_flags;
    Uint8 saved_alpha;

    /* Use the surface width and height expanded to powers of 2 */
    w = power_of_two( surface->w );
    h = power_of_two( surface->h );

    // TODO: logging framework
    printf( "%i (%i), %i (%i)\n", surface->w, w, surface->h, h );

    texcoord[ 0 ] = 0.0f;         /* Min X */
    texcoord[ 1 ] = 0.0f;         /* Min Y */
    texcoord[ 2 ] = ( float ) surface->w / w;  /* Max X */
    texcoord[ 3 ] = ( float ) surface->h / h;  /* Max Y */

    image = SDL_CreateRGBSurface(
                SDL_SWSURFACE,
                w, h,
                32,
#if SDL_BYTEORDER == SDL_LIL_ENDIAN /* OpenGL RGBA masks */
                0x000000FF,
                0x0000FF00,
                0x00FF0000,
                0xFF000000
#else
                0xFF000000,
                0x00FF0000,
                0x0000FF00,
                0x000000FF
#endif
            );

    if ( image == NULL ) {
        return 0;
    }

    /* Save the alpha blending attributes */
    saved_flags = surface->flags & ( SDL_SRCALPHA | SDL_RLEACCELOK );

    saved_alpha = surface->format->alpha;

    if ( ( saved_flags & SDL_SRCALPHA ) == SDL_SRCALPHA ) {
        SDL_SetAlpha(surface, 0, alpha );
    }

    /* Copy the surface into the GL texture image */
    area.x = 0;

    area.y = 0;

    area.w = surface->w;

    area.h = surface->h;

    // TODO: make colorkey a loading parameter
    if(alpha == 255) {
        Uint32 colorkey = SDL_MapRGB(surface->format, 255, 0, 255);
        SDL_SetColorKey(surface, SDL_SRCCOLORKEY, colorkey);
    }

    SDL_BlitSurface( surface, &area, image, &area );

    /* Restore the alpha blending attributes */
    if ( ( saved_flags & SDL_SRCALPHA ) == SDL_SRCALPHA ) {
        SDL_SetAlpha( surface, saved_flags, saved_alpha );
    }

    SDL_LockSurface( image );

    /* Create an OpenGL texture for the image */
    glGenTextures( 1, &texture );
    glBindTexture( GL_TEXTURE_2D, texture );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );

    glTexImage2D( GL_TEXTURE_2D,
                  0,
                  GL_RGBA,
                  w, h,
                  0,
                  GL_RGBA,
                  GL_UNSIGNED_BYTE,
                  image->pixels );

    SDL_UnlockSurface( image );
    SDL_FreeSurface( image ); /* No longer needed */

    return texture;
}



void DisplayBoundingBox(float *max, float *min, float r, float g, float b) {
//    glDisable(GL_TEXTURE_2D);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glColor4f(r, g, b, 0.41);
    glBegin(GL_QUADS);
    // back
    glVertex3f(min[0], min[1], max[2]);
    glVertex3f(min[0], max[1], max[2]);
    glVertex3f(max[0], max[1], max[2]);
    glVertex3f(max[0], min[1], max[2]);
    // front
    glVertex3f(max[0], max[1], min[2]);
    glVertex3f(min[0], max[1], min[2]);
    glVertex3f(min[0], min[1], min[2]);
    glVertex3f(max[0], min[1], min[2]);
    // left
    glVertex3f(max[0], max[1], max[2]);
    glVertex3f(max[0], min[1], max[2]);
    glVertex3f(max[0], min[1], min[2]);
    glVertex3f(max[0], max[1], min[2]);
    // right
    glVertex3f(min[0], max[1], max[2]);
    glVertex3f(min[0], min[1], max[2]);
    glVertex3f(min[0], min[1], min[2]);
    glVertex3f(min[0], max[1], min[2]);
    // top
    glVertex3f(max[0], min[1], max[2]);
    glVertex3f(min[0], min[1], max[2]);
    glVertex3f(min[0], min[1], min[2]);
    glVertex3f(max[0], min[1], min[2]);
    // bottom
    glVertex3f(max[0], max[1], max[2]);
    glVertex3f(min[0], max[1], max[2]);
    glVertex3f(min[0], max[1], min[2]);
    glVertex3f(max[0], max[1], min[2]);
    glEnd();
    glColor4f(1.0, 1.0, 1.0, 1.0);
    glDisable(GL_BLEND);
    glEnable(GL_CULL_FACE);
//    glEnable(GL_TEXTURE_2D);
}

void goOrtho() {
    glMatrixMode( GL_PROJECTION );
    glPushMatrix();
    glLoadIdentity();
    glOrtho( 0, 800, 600, 0, 0, 1000 );
    glMatrixMode( GL_MODELVIEW );
}

void goPerspective() {
    glMatrixMode( GL_PROJECTION );
    glPopMatrix();
    glMatrixMode( GL_MODELVIEW );
}

