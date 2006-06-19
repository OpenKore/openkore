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
#include "..\Orc.h"

// Wrapper for SDL and GL
#include "csdl\csdl.h"

// Basic 3D functions
#include "3d_math.h"
#include "3d_camera.h"
#include "3d_frustum.h"

// Smart interface to libgrf
#include "grf_interface.h"


#include "ro_types.h"
#include "gnd_ground.h"
#include "rsm_model.h"


// This belongs to CSDL...
#define SET_ENTRY_CLASS(classname) \
int SDL_main( int argc, char * argv[] ) { \
    g_pApp = new classname(); \
    if( g_pApp == NULL ) { \
        printf("Fatal error: Constructor " #classname "::" #classname "() aborted.\n"); \
        exit(EXIT_FAILURE); \
    } \
    g_pApp->SetCaption( APPTITLE ); \
    return g_pApp->Main( argc, argv ); \
} \

// And that too
CSDL_ApplicationBase* g_pApp = NULL;

// Global subsystem pointers
CGRF_Interface* g_pGrfInterface = NULL;


class CGL_Interface {
    CGL_Interface() {}
    virtual ~CGL_Interface() {}
};

class CDebugConsole {
public:
    CDebugConsole() {}
    virtual ~CDebugConsole() {}
    void Render() {

        int posx = 0;
        int posy = 400;
        int width = 480;
        int height = 200;

        goOrtho();
        glLoadIdentity();

        glTranslatef(posx,posy,0);

        glColor4f(ZERO, ZERO, ZERO, 0.60);
        glBegin(GL_QUADS);
        glVertex3f(	ZERO, ZERO, ZERO);
        glVertex3f(	(float)width, ZERO, ZERO);
        glVertex3f( (float)width, (float)height, ZERO);
        glVertex3f( ZERO, (float)height, ZERO);
        glEnd();

        glColor4f(1, 1, 1, 1);

        goPerspective();

    }

};

CDebugConsole* g_pDebugConsole = new CDebugConsole();
// void con_printf(char* sz, ...) {
//   g_pDebugConsole->AddText();
// }




class CResource_World_File {
public:
    CResource_World_File( char* szFilename );
    virtual ~CResource_World_File();

    bool LoadFromMemory( void* pData, uint32_t nSize );

//        int getWidth() { return(ground.sizeX); }
//        int getHeight() { return(ground.sizeY); }
    int GetNumModels() {
        return m_nModels;
    };

    int GetNumUniqueModels() {
        return m_nUniqueModels;
    };

    char m_szMapName[ 128 ];
    char m_szMiniMap[ 128 ];

//private:
    rsw_object_t* m_Models;
    rsw_header_t* m_Header;
    Uint16 m_nModels;
    Uint16 m_nUniqueModels;

    CResource_Model_File* m_RealModels;
//        GND ground;
};

CResource_World_File::CResource_World_File( char* szFilename ) {
    m_nModels = 0;
    m_nUniqueModels = 0;
    memset( &m_szMapName[ 0 ], 0, 128 );
    memset( &m_szMiniMap[ 0 ], 0, 128 );

    uint32_t filesize;
    void* filedata;
    filedata = g_pGrfInterface->GetRSW( szFilename, &filesize );

    if ( filedata == NULL || !LoadFromMemory( filedata, filesize ) )
        return;
}

CResource_World_File::~CResource_World_File() {}

bool CResource_World_File::LoadFromMemory( void* pData, uint32_t nSize ) {
    m_Header = ( rsw_header_t* ) pData;
    m_Models = ( rsw_object_t* ) ( ( ( unsigned char* ) pData ) + sizeof( rsw_header_t ) );

    if ( strcmp( m_Header->id, "GRSW" ) ) {
        memcpy( &m_szMapName[ 0 ], &m_Header->szGndFile[ 0 ], strlen( m_Header->szGndFile ) - 4 );
        strcpy( &m_szMapName[ strlen( m_Header->szGndFile ) - 4 ], "\0" );
        sprintf( m_szMiniMap, "data\\texture\\유저인터페이스\\map\\%s.bmp", m_szMapName );
        printf( "Loading World File \"%s\"...\n", m_szMapName );
    } else {
        printf( "Error: no valid RSW format !\n" );
        return false;
    }

    m_nUniqueModels = 0;

    for ( int i = 0; i < m_Header->object_count; i++ ) {
        if ( m_Models[ i ].type > 1 ) {
            m_nModels = i;
            break;
        }

        m_Models[ i ].bIsUnique = true;

        for ( int j = 0; j < i; j++ ) {
            if ( !strcmp( &m_Models[ j ].szFilename[ 0 ], &m_Models[ i ].szFilename[ 0 ] ) ) {
                m_Models[ i ].bIsUnique = false;
                break;
            }
        }

        if ( m_Models[ i ].bIsUnique ) {
            // loading should be done here
            m_nUniqueModels++;
        }
    }

    printf( "%i/%i (%i) objects are unique\n", m_nUniqueModels, m_nModels, m_Header->object_count );


    ro_string_t *realmodelspath = new ro_string_t[ m_nUniqueModels ];
    m_RealModels = new CResource_Model_File[ m_nUniqueModels ];

    for ( int i = 0, k = 0; i < m_nModels; i++ ) {
        if ( m_Models[ i ].bIsUnique ) {
            strcpy( realmodelspath[ k ], m_Models[ i ].szFilename );
            m_RealModels[ k ].LoadFromGRF( realmodelspath[ k ] );
            k++;
        }
    }

    for ( int i = 0; i < m_nModels; i++ ) {
        m_Models[ i ].model = 1;

        for ( int num = 0; num < m_nUniqueModels; num++ ) {
            if ( !strcmp( m_Models[ i ].szFilename, realmodelspath[ num ] ) ) {
                m_Models[ i ].model = num;
                break;

            }
        }
    }

    return true;
}


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


int InitGL() {
    glClearColor ( 1.0f, 1.0f, 1.0f, 0.0f );
    glClearDepth( 1.0f );
    glEnable( GL_TEXTURE_2D );

    float fogColor[ 4 ] = {0.95f, 0.95f, 1.0f, 1.0f};

    glFogi( GL_FOG_MODE, GL_EXP2 );    // Fog Mode
    glFogfv( GL_FOG_COLOR, fogColor );    // Set Fog Color
    glFogf( GL_FOG_DENSITY, 0.05f );    // How Dense Will The Fog Be
    glHint( GL_FOG_HINT, GL_DONT_CARE );   // The Fog's calculation accuracy
    glFogf( GL_FOG_START, 1000.0f );     // Fog Start Depth
    glFogf( GL_FOG_END, 1000.0f );     // Fog End Depth

//#ifdef LIGHT_ENABLE
    float ambience[ 4 ] = {0.3f, 0.3f, 0.3f, 1.0};  // The color of the light in the world
    float diffuse[ 4 ] = {1.0f, 1.0f, 1.0f, 1.0};   // The color of the positioned light
    float light0[ 3 ] = {1.0f, 1.0f, 1.0f};       // The color of the positioned light
    glLightfv( GL_LIGHT0, GL_AMBIENT, ambience );  // Set our ambience values (Default color without direct light)
    glLightfv( GL_LIGHT0, GL_DIFFUSE, diffuse );  // Set our diffuse color (The light color)
    glLightfv( GL_LIGHT0, GL_POSITION, light0 );     // This Sets our light position

    glEnable(  GL_LIGHT0   );       // Turn this light on
    glEnable(  GL_LIGHTING );       // This turns on lighting
    glEnable( GL_COLOR_MATERIAL );
//#endif

    glShadeModel ( GL_SMOOTH );


    glEnable( GL_DEPTH_TEST );
// glDepthFunc(GL_LESS);
    glDepthFunc( GL_LEQUAL );


    glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );   // Enable Alpha Blending (disable alpha testing)
    glEnable( GL_BLEND );              // Enable Blending       (disable alpha testing)

    glHint( GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST );
    glEnable(GL_FOG);

    glFrontFace(GL_CW);
    glEnable(GL_CULL_FACE);

    return TRUE;          // Initialization Went OK
}

void ReSizeGLScene( GLsizei w, GLsizei h ) {

    glViewport ( 0, 0, ( GLsizei ) w, ( GLsizei ) h );
    glMatrixMode ( GL_PROJECTION );
    glLoadIdentity();

    gluPerspective ( 40.0, ( GLfloat ) w / ( GLfloat ) h, 1.0, 1000.0 );
    glMatrixMode ( GL_MODELVIEW );
    glLoadIdentity();
}

/*
    SET_ENTRY_CLASS creates our class instance and calls the inherited main function,
    which pumps the events and calls OnPreEvents, OnPaint, OnPostEvents...
*/
SET_ENTRY_CLASS(Orc);
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

    //m_pWorld->m_Header
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

    //g_pDebugConsole->Render();
}

//#ifdef WIN32
//* Undo packing */
//#include <poppack.h>
//#else /* WIN32 */
//* Undo packing */
//#pragma pack()
//#endif /* WIN32 */
