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

#include <limits.h>

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

// TODO: Name of the .INI file to use, perhaps make it a command line option ?
#define INIFILE "./orc.ini"

// Global subsystem pointers
CGRF_Interface* g_pGrfInterface = NULL;


// The application class
class Orc : public CSDLGL_ApplicationBase {
public:
    Orc();
    ~Orc();

private:
    bool bUseFrustum;
    bool bUseFog;
    bool bShowTextures;
    bool bShowBoxes; // Bounding Boxes
    float fFogDepth;

    virtual bool InitGL();
    virtual void OnPaint( CSDL_Surface* display, double dt );
    virtual void OnKeypress( SDL_KeyboardEvent key, SDLMod mod );

protected:
    CCamera*    m_pCamera;
    CFrustum*   m_pFrustum;

    CSDL_Music* m_pBGM;
    CRSW*       m_pWorld;
    GND*        m_pGnd;

};


Orc::Orc() : CSDLGL_ApplicationBase(), fFogDepth(0.001), bUseFrustum(true), bUseFog(true), bShowTextures(true), bShowBoxes(false) {

    // Load settings from orc.ini (TODO: make it portable)
    char szRagnarokPath[PATH_MAX];
    char szTempPath[PATH_MAX];
    char szDefaultMap[64];
    int  iDisplayWidth = 800, iDisplayHeight = 600, iDisplayBpp = 32;

#ifdef WIN32
    GetPrivateProfileString("data", "folder", "c:/ragnarokonline", szRagnarokPath, MAX_PATH, INIFILE);
    GetPrivateProfileString("world", "map", "newzone01", szDefaultMap, 64, INIFILE);

    iDisplayWidth = GetPrivateProfileInt("viewport", "width", 800, INIFILE);
    iDisplayHeight = GetPrivateProfileInt("viewport", "height", 600, INIFILE);
    iDisplayBpp = GetPrivateProfileInt("viewport", "bpp", 32, INIFILE);
#else
    strcpy(szRagnarokPath, "./");
    strcpy(szDefaultMap, "newzone01");
#endif


    InitVideoMode(iDisplayWidth, iDisplayHeight, iDisplayBpp);


    sprintf(szTempPath, "%s/data.grf", szRagnarokPath);
    g_pGrfInterface = new CGRF_Interface( szTempPath );
    if( !g_pGrfInterface ) {
        return;
    }
    // TODO: Use resnametable.txt in grf_interface
    sprintf(szTempPath, "%s.rsw", szDefaultMap);

    m_pWorld = new CRSW( szTempPath );
    m_pGnd = new GND(m_pWorld->szGndFile, m_pWorld->water_type);

//    bgi_temp = new CSDL_GL_Texture("유저인터페이스\\bgi_temp.bmp");


    sprintf(szTempPath, "%s/bgm/30.mp3", szRagnarokPath);
    m_pBGM = new CSDL_Music(szTempPath);
    //m_pBGM->Play(-1);

    m_pCamera = new CCamera();
    m_pCamera->PositionCamera( 0, 0, 1, 0, 0, 0, 0, 1, 0 );

    m_pFrustum = new CFrustum();

    InitGL();
    ResizeGL( m_nScreenWidth, m_nScreenHeight );
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


bool Orc::InitGL() {
    CSDLGL_ApplicationBase::InitGL();                  // Setup default attributes

    glClearColor ( 1.0f, 1.0f, 1.0f, 0.0f );
    glClearDepth( 1.0f );
    glEnable( GL_TEXTURE_2D );

    float fogColor[ 4 ] = {0.95f, 0.95f, 1.0f, 1.0f};


    glFogi( GL_FOG_MODE, GL_EXP2 );    // Fog Mode
    glFogfv( GL_FOG_COLOR, fogColor );    // Set Fog Color
    glFogf( GL_FOG_DENSITY, fFogDepth );    // How Dense Will The Fog Be
    glHint( GL_FOG_HINT, GL_DONT_CARE );   // The Fog's calculation accuracy
    glFogf( GL_FOG_START, 500.0f );     // Fog Start Depth
    glFogf( GL_FOG_END, 1000.0f );     // Fog End Depth

    float ambience[ 4 ] = {HALF, HALF, HALF, 1.0};  // The color of the light in the world
    float diffuse[ 4 ] = {ONE, ONE, ONE, 1.0};  // The color of the light in the world
    float light0[ 3 ] = {1.0f, 1.0f, 1.0f};       // The color of the positioned light

    glLightfv( GL_LIGHT0, GL_AMBIENT, ambience );  // Set our ambience values (Default color without direct light)
    glLightfv( GL_LIGHT0, GL_DIFFUSE, diffuse );  // Set our diffuse color (The light color)
    glLightfv( GL_LIGHT0, GL_POSITION, light0 );     // This Sets our light position

    glEnable(  GL_LIGHT0   );       // Turn this light on
    glEnable(  GL_LIGHTING );       // This turns on lighting
    glEnable( GL_COLOR_MATERIAL );

    glShadeModel ( GL_SMOOTH );

    glEnable( GL_DEPTH_TEST );
    glDepthFunc( GL_LEQUAL );


    glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );   // Enable Alpha Blending (disable alpha testing)
    glEnable( GL_BLEND );              // Enable Blending       (disable alpha testing)

    glHint( GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST );
//    glEnable(GL_FOG);

    glFrontFace(GL_CW);
    glEnable(GL_CULL_FACE);

    return true;          // Initialization Went OK

}


// TODO: Timer Class
// TODO: CIniFile
// TODO:

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


    //glPushMatrix();

    // m_pWorld->m_Header
    // glLightfv( GL_LIGHT0, GL_POSITION, g_LightPosition ); // This Sets our light position
    //glPopMatrix();

    glScalef ( 1.0, 1.0, -1.0 );


    // TODO: render landscape
    m_pGnd->Display(m_pFrustum);



    static Uint32 tLast=0, tNow=0, tDur;
    static Uint32 nFrame = 0;
    tNow = ::SDL_GetTicks();
    if(tLast == 0) tLast = tNow;

    static bool bReverse = false;

    tDur = tNow - tLast;
    if(tDur > 100) {
        tLast = tNow;

        if(!bReverse) {
            nFrame++;
            if(nFrame > m_pWorld->water_cycles ) { bReverse = true; }
        } else {
            nFrame--;
            if(nFrame == 0 ) { bReverse = false; }
        }

        m_pWorld->water_phase += 36;
        if(m_pWorld->water_phase > 360) m_pWorld->water_phase = 0;
    }

    m_pGnd->DisplayWater(nFrame, m_pWorld->water_phase * M_PI / 180, m_pWorld->water_height, m_pFrustum);

    goPerspective();
    m_pFrustum->CalculateFrustum();
//    glFrontFace(GL_CW);
//    glDisable(GL_BLEND);
    glColor4f(ONE, ONE, ONE, ONE);


    // render the world objects
    for ( int i = 0; i < m_pWorld->m_nModels; i++ ) {
        rsw_object_type1* tmp = &m_pWorld->m_Models[ i ];
        CResource_Model_File* tmp2 = &m_pWorld->m_RealModels[ m_pWorld->m_Models[ i ].iModelID ];

        if( (bUseFrustum && m_pFrustum->BoxInFrustum(
                    tmp->position.x,
                    tmp->position.y,
                    tmp->position.z,
                    tmp2->box.range[0] * tmp->position.sx,
                    tmp2->box.range[1] * tmp->position.sy,
                    tmp2->box.range[2] * tmp->position.sz)) || !bUseFrustum ) {

            m_pWorld->m_RealModels[ m_pWorld->m_Models[ i ].iModelID ].Render( m_pWorld->m_Models[ i ].position );

            if(bShowBoxes) {
                m_pWorld->m_RealModels[ m_pWorld->m_Models[ i ].iModelID ].BoundingBox();
                DisplayBoundingBox(
                    &m_pWorld->m_RealModels[ m_pWorld->m_Models[ i ].iModelID ].box.max[0],
                    &m_pWorld->m_RealModels[ m_pWorld->m_Models[ i ].iModelID ].box.min[0], 0, 0, 1
                );
            }
        }
    }

} // OnPaint


void Orc::OnKeypress( SDL_KeyboardEvent key, SDLMod mod ) {
    if ( ( key.keysym.sym == SDLK_END ) && ( key.keysym.mod & KMOD_CTRL ) ) m_bIsRunning = false;
    if ( (key.type == SDL_KEYDOWN) && ( key.keysym.sym == SDLK_F1 ) ) {
        bUseFrustum = (bUseFrustum) ? false : true;
    }
    if ( (key.type == SDL_KEYDOWN) && ( key.keysym.sym == SDLK_F2 ) ) {
        bUseFog = (bUseFog) ? false : true;
        if( bUseFog ) glEnable(GL_FOG);
        else glDisable(GL_FOG);
    }
    if ( (key.type == SDL_KEYDOWN) && ( key.keysym.sym == SDLK_F3 ) ) {
        bShowBoxes = (bShowBoxes) ? false : true;
    }
    if ( (key.type == SDL_KEYDOWN) && ( key.keysym.sym == SDLK_F4 ) ) {
        bShowTextures = (bShowTextures) ? false : true;
        if( bShowTextures ) glEnable(GL_TEXTURE_2D);
        else glDisable(GL_TEXTURE_2D);
    }
    if ( ( key.keysym.sym == SDLK_KP_PLUS ) ) {
        fFogDepth = (fFogDepth < 1.0) ? fFogDepth + 0.001 : 1.0;
        glFogf( GL_FOG_DENSITY, fFogDepth );
    }
    if ( ( key.keysym.sym == SDLK_KP_MINUS ) ) {
        fFogDepth = (fFogDepth > 0.0) ? fFogDepth - 0.001 : 0.0;
        glFogf( GL_FOG_DENSITY, fFogDepth );
    }
    if ( ( key.keysym.sym == SDLK_F12 ) ) {
        // TODO: save screenshot
        // m_PrimarySurface->SaveBMP("screenshot.bmp");
    }
    CSDLGL_ApplicationBase::OnKeypress(key, mod);
}


int main(int argc, char *argv[]) {
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
