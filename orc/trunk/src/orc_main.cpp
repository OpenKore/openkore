/*
 *  ORC - Open Ragnarok Client
 *  orc_main.cpp - The "Big picture"
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

// For our version string
#include "../Orc.h"

// Wrapper for SDL and GL
#include "csdl/csdl.h"

// Basic 3D functions
#include "3d_math.h"
#include "3d_camera.h"
#include "3d_frustum.h"

// Smart interface to libgrf
#include "grf_interface.h"

// File loaders
#include "ro_types.h"
#include "gnd_ground.h"
#include "rsm_model.h"
#include "rsw_world.h"

// Global subsystem pointers
CGRF_Interface* g_pGrfInterface = NULL;

// The application class
class Orc : public CSDL_ApplicationBase {
public:
    Orc();
    ~Orc();

    CCamera*    m_pCamera;
    CFrustum*   m_pFrustum;

    CSDL_Music* m_pBGM;
    // CSDL_GL_Texture* bgi_temp;
    CResource_World_File* m_pWorld;
    GND* m_pGnd;

    virtual void OnPaint( CSDL_Surface* display, double dt );
    virtual void OnKeypress( SDL_KeyboardEvent key, SDLMod mod ) {
        if ( ( key.keysym.sym == SDLK_END ) && ( key.keysym.mod & KMOD_CTRL ) ) m_bIsRunning = false;
        CSDL_ApplicationBase::OnKeypress(key, mod);
    }
};


Orc::Orc() : CSDL_ApplicationBase( SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_OPENGL ) {

    // TODO: Load a configuration file
    // TODO: Use resnametable.txt in grf_interface
    // TODO: automatically search for data.grf or should we use a .INI ?
    char szRagnarokPath[] = "c:/programme/funro";
    char szTmpPath[256];
    sprintf(szTmpPath, "%s/data.grf", szRagnarokPath);
    g_pGrfInterface = new CGRF_Interface( szTmpPath );
    if( g_pGrfInterface == NULL) {
        exit(0);
    }

    m_pWorld = new CResource_World_File( "prontera.rsw" );
    m_pGnd = new GND(m_pWorld->m_Header->szGndFile, m_pWorld->m_Header->water_type);

//    m_loginBkgnd = new CSDL_Surface(g_pGrfInterface->Get("data\\texture\\유저인터페이스\\bgi_temp.bmp"));
//    bgi_temp = new CSDL_GL_Texture("유저인터페이스\\bgi_temp.bmp");
//    m_loginBkgnd = new CSDL_Surface(g_pGrfInterface->GetTexture(world->m_RealModels[1].m_TextureNames[1].szFilename));
//    GLuint m_loginBkgndID = ::SDL_GL_LoadTexture(m_loginBkgnd->surface, &m_loginBkgndID_rc[0]);

    sprintf(szTmpPath, "%s/bgm/30.mp3", szRagnarokPath);
    m_pBGM = new CSDL_Music(szTmpPath);
    m_pBGM->Play(-1);

    m_pCamera = new CCamera();
    m_pCamera->PositionCamera( 0, 0, 1, 0, 0, 0, 0, 1, 0 );

    m_pFrustum = new CFrustum();

    InitGL();
    ReSizeGLScene( m_nScreenWidth, m_nScreenHeight );
}


Orc::~Orc() {

    if( m_pFrustum )
        delete m_pFrustum;

    if( m_pCamera )
        delete m_pCamera;

    if( m_pWorld )
        delete m_pWorld;

    if( m_pBGM )
        delete m_pBGM;

    if( g_pGrfInterface )
        delete g_pGrfInterface;
}


void Orc::OnPaint( CSDL_Surface* display, double dt ) {

    // Everybody wants to know...
    sprintf(m_pErrorBuffer, "%s - %02.02f FPS", APPTITLE, m_fFPS);
    SetCaption(m_pErrorBuffer);

    /*
        CCamera checks mouse & keyboard and updates the camera
        TODO: make camera modes FREEFLY, RAGNAROK, 1STPERSON into camera class !
    */
    m_pCamera->Update();

    // Clear the screen and z-buffer
    glClear ( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    glLoadIdentity();

    glPushMatrix();
    glTranslatef( 0.0f, 0.0f, 0.0f );
    goPerspective(); // hmm
    glPopMatrix();
    m_pCamera->Look(); // Tell OpenGL where to look
    glPushMatrix();

    // m_pWorld->m_Header
    // glLightfv( GL_LIGHT0, GL_POSITION, g_LightPosition ); // This Sets our light position
    glPopMatrix();

    // update the fog
    glFogf( GL_FOG_DENSITY, 0.002 );    // How Dense Will The Fog Be
    glScalef ( 1.0, 1.0, -1.0 );


    // TODO: render landscape
    m_pGnd->Display(m_pFrustum);
    m_pGnd->DisplayWater(0, m_pWorld->m_Header->water_phase, m_pWorld->m_Header->water_height, m_pFrustum);

    goPerspective();
    m_pFrustum->CalculateFrustum();
    glFrontFace(GL_CW);
//    glDisable(GL_BLEND);
    glColor4f(ONE, ONE, ONE, ONE);


    // render the world objects
    for ( int i = 0; i < m_pWorld->m_nModels; i++ ) {
        rsw_object_t* tmp = &m_pWorld->m_Models[ i ];
        CResource_Model_File* tmp2 = &m_pWorld->m_RealModels[ m_pWorld->m_Models[ i ].model ];

        if( m_pFrustum->BoxInFrustum(
                    tmp->position.x,
                    tmp->position.y,
                    tmp->position.z,
                    tmp2->box.range[0] * tmp->position.sx,
                    tmp2->box.range[1] * tmp->position.sy,
                    tmp2->box.range[2] * tmp->position.sz) ) {
            m_pWorld->m_RealModels[ m_pWorld->m_Models[ i ].model ].Render( m_pWorld->m_Models[ i ].position );
        }
    }

} // OnPaint


int
main(int argc, char *argv[]) {
    g_pApp = new Orc();
    if (g_pApp == NULL) {
        printf("%s\n", APPTITLE);
	printf("Fatal error: Constructor Orc::Orc() aborted.\n");
	exit(EXIT_FAILURE);
    }
    g_pApp->SetCaption(APPTITLE);
    return g_pApp->Main(argc, argv);
}


#ifdef WIN32
/* Undo packing */
#include <poppack.h>
#else /* WIN32 */
/* Undo packing */
#pragma pack()
#endif /* WIN32 */
