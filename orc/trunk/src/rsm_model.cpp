/*
 *  ORC - Open Ragnarok Client
 *  rsm_model.cpp - Resource Model File Loader
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

#include "rsm_model.h"


#include "grf_interface.h"
extern CGRF_Interface* g_pGrfInterface;


#include "memory_manager.h" // Just for dump() for now...


CRSM_Mesh::CRSM_Mesh( GLuint* glTextures, bool* glTextureIsAlpha ) {
    m_glTextures = glTextures;
    m_glTextureIsAlpha = glTextureIsAlpha;
}

CRSM_Mesh::~CRSM_Mesh() {}

int CRSM_Mesh::LoadFromMemory( void* pData, uint32_t nSize, bool bIsParent ) {
    unsigned long iOffset = 0;

    READ(szMeshName, iOffset, 40);
    iOffset += 40;

    if ( bIsParent == true ) {
        READ(iUnknown1, iOffset, 4);
        iOffset += 4;
    }

    READ(szParentName, iOffset, 40);
    iOffset += 40;

    if ( bIsParent == true ) {
        READ(fUnknown2, iOffset, 40);
        iOffset += 40;
    }

    READ(iNumTextures, iOffset, 4);
    iOffset += 4;
    m_TexIDs = new unsigned int[iNumTextures];
    READ(m_TexIDs, iOffset, 4 * iNumTextures);
    iOffset += 4 * iNumTextures;
    READ(m_Transf, iOffset, sizeof(ro_transf_t));
    iOffset += sizeof(ro_transf_t);

    READ(m_nVertices, iOffset, 4);
    iOffset += 4;
    m_Vertices = new ro_vertex_t[m_nVertices];
    READ(m_Vertices[0], iOffset, sizeof(ro_vertex_t) * m_nVertices);
    iOffset += sizeof(ro_vertex_t) * m_nVertices;

    READ(m_nTexVertices, iOffset, 4);
    iOffset += 4;
    m_TexVertices = new ro_vertex_t[m_nTexVertices];
    READ(m_TexVertices[0], iOffset, sizeof(ro_vertex_t) * m_nTexVertices);
    iOffset += sizeof(ro_vertex_t) * m_nTexVertices;

    READ(m_nFaces, iOffset, 4);
    iOffset += 4;
    m_Faces = new ro_face_t[m_nFaces];
    READ(m_Faces[0], iOffset, sizeof(ro_face_t) * m_nFaces);
    iOffset += sizeof(ro_face_t) * m_nFaces;

    if( iOffset < nSize) {
        READ(m_nFrames, iOffset, 4);
        iOffset += 4;
        m_Frames = new ro_frame_t[m_nFrames];
        READ(m_Frames[0], iOffset, sizeof(ro_frame_t) * m_nFrames);
        iOffset += sizeof(ro_frame_t) * m_nFrames;
    }

    printf( "Loading mesh \"%s\" with %i textures, %i vertices and %i texture vertices on %i faces...\n", szMeshName, iNumTextures, m_nVertices, m_nTexVertices, m_nFaces );

    return iOffset;
} // LoadFromMemory



void CRSM_Mesh::BoundingBox( ro_transf_t *ptransf ) {

    int main = ( ptransf == NULL );
    GLfloat Rot[ 16 ];
    int i;
    int j;
    //int k;
    //GLfloat pmax[3], pmin[3];
    ro_transf_t transf = m_Transf;

    Rot[ 0 ] = transf.todo[ 0 ];
    Rot[ 1 ] = transf.todo[ 1 ];
    Rot[ 2 ] = transf.todo[ 2 ];
    Rot[ 3 ] = 0.0;

    Rot[ 4 ] = transf.todo[ 3 ];
    Rot[ 5 ] = transf.todo[ 4 ];
    Rot[ 6 ] = transf.todo[ 5 ];
    Rot[ 7 ] = 0.0;

    Rot[ 8 ] = transf.todo[ 6 ];
    Rot[ 9 ] = transf.todo[ 7 ];
    Rot[ 10 ] = transf.todo[ 8 ];
    Rot[ 11 ] = 0.0;

    Rot[ 12 ] = 0.0;
    Rot[ 13 ] = 0.0;
    Rot[ 14 ] = 0.0;
    Rot[ 15 ] = 1.0;

    max[ 0 ] = max[ 1 ] = max[ 2 ] = -999999.0;
    min[ 0 ] = min[ 1 ] = min[ 2 ] = 999999.0;


    for ( i = 0; i < m_nVertices; i++ ) {
        GLfloat vout[ 3 ]; // vtemp[3]
        MatrixMultVect( Rot, m_Vertices[ i ], vout );

        for ( j = 0; j < 3; j++ ) {
            GLfloat f;

            if ( !only )
                f = vout[ j ] + transf.todo[ 12 + j ] + transf.todo[ 9 + j ];
            else
                f = vout[ j ];

            min[ j ] = MIN( f, min[ j ] );

            max[ j ] = MAX( f, max[ j ] );
        }
    }

    for ( j = 0; j < 3; j++ )
        range[ j ] = ( max[ j ] + min[ j ] ) / 2.0;
}


void CRSM_Mesh::Render( bounding_box_t *box, ro_transf_t *ptransf ) {

    GLfloat Rot[ 16 ];
    GLfloat Ori[ 16 ];

    int main = ( ptransf == NULL );

    CVector3 vNormal;
    CVector3 vTriangle[ 3 ];

    ro_transf_t transf = m_Transf;

    Rot[ 0 ] = transf.todo[ 0 ];
    Rot[ 1 ] = transf.todo[ 1 ];
    Rot[ 2 ] = transf.todo[ 2 ];
    Rot[ 3 ] = 0.0;

    Rot[ 4 ] = transf.todo[ 3 ];
    Rot[ 5 ] = transf.todo[ 4 ];
    Rot[ 6 ] = transf.todo[ 5 ];
    Rot[ 7 ] = 0.0;

    Rot[ 8 ] = transf.todo[ 6 ];
    Rot[ 9 ] = transf.todo[ 7 ];
    Rot[ 10 ] = transf.todo[ 8 ];
    Rot[ 11 ] = 0.0;

    Rot[ 12 ] = 0.0;
    Rot[ 13 ] = 0.0;
    Rot[ 14 ] = 0.0;
    Rot[ 15 ] = 1.0;

    if ( m_nFrames ) {
        int current = 0;
        int next;
        GLfloat t;
        GLfloat q[ 4 ], q1[ 4 ], q2[ 4 ];
        GLfloat x, y, z, w;
        char buffer[ 1024 ];

        for ( int i = 0; i < m_nFrames; i++ ) {
            if ( nstep < m_Frames[ i ].time ) {
                current = i - 1;
                break;
            }
        }

        next = current + 1;

        if ( next == m_nFrames )
            next = 0;

        t = ( ( GLfloat ) ( nstep - m_Frames[ current ].time ) )
            / ( ( GLfloat ) ( m_Frames[ next ].time - m_Frames[ current ].time ) );


        x = m_Frames[ current ].orientation[ 0 ] * ( 1 - t ) + t * m_Frames[ next ].orientation[ 0 ];

        y = m_Frames[ current ].orientation[ 1 ] * ( 1 - t ) + t * m_Frames[ next ].orientation[ 1 ];

        z = m_Frames[ current ].orientation[ 2 ] * ( 1 - t ) + t * m_Frames[ next ].orientation[ 2 ];

        w = m_Frames[ current ].orientation[ 3 ] * ( 1 - t ) + t * m_Frames[ next ].orientation[ 3 ];

        GLfloat norm;

        norm = sqrtf( x * x + y * y + z * z + w * w );

        x /= norm;

        y /= norm;

        z /= norm;

        w /= norm;

        // First row
        Ori[ 0 ] = 1.0f - 2.0f * ( y * y + z * z );

        Ori[ 1 ] = 2.0f * ( x * y + z * w );

        Ori[ 2 ] = 2.0f * ( x * z - y * w );

        Ori[ 3 ] = 0.0f;

        // Second row
        Ori[ 4 ] = 2.0f * ( x * y - z * w );

        Ori[ 5 ] = 1.0f - 2.0f * ( x * x + z * z );

        Ori[ 6 ] = 2.0f * ( z * y + x * w );

        Ori[ 7 ] = 0.0f;

        // Third row
        Ori[ 8 ] = 2.0f * ( x * z + y * w );

        Ori[ 9 ] = 2.0f * ( y * z - x * w );

        Ori[ 10 ] = 1.0f - 2.0f * ( x * x + y * y );

        Ori[ 11 ] = 0.0f;

        // Fourth row
        Ori[ 12 ] = 0;

        Ori[ 13 ] = 0;

        Ori[ 14 ] = 0;

        Ori[ 15 ] = 1.0f;

        nstep += 100;

        if ( nstep >= m_Frames[ m_nFrames - 1 ].time )
            nstep = 0;
    }

    glScalef ( transf.todo[ 19 ], transf.todo[ 20 ], transf.todo[ 21 ] );

    if ( main )
        if ( !only ) {
            glTranslatef( -box->range[ 0 ], -box->max[ 1 ], -box->range[ 2 ] );
        } else {
            glTranslatef( 0.0, -box->max[ 1 ] + box->range[ 1 ], 0.0 );
        }

    if ( !main )
        glTranslatef( transf.todo[ 12 ], transf.todo[ 13 ], transf.todo[ 14 ] );

    if ( !m_nFrames )
        glRotatef( transf.todo[ 15 ] * 180.0 / 3.14159,
                   transf.todo[ 16 ], transf.todo[ 17 ], transf.todo[ 18 ] );
    else
        glMultMatrixf( Ori );


    glPushMatrix();

    if ( main && only )
        glTranslatef( -box->range[ 0 ], -box->range[ 1 ], -box->range[ 2 ] );

    if ( !main || !only )
        glTranslatef( transf.todo[ 9 ], transf.todo[ 10 ], transf.todo[ 11 ] );

    glMultMatrixf( Rot );

    GLfloat Mat[ 16 ];

    for ( int i = 0; i < m_nFaces; i++ ) {
        ro_vertex_t *v;
        ro_vertex_t *t;
        int texture;

        if ( m_Faces[ i ].text > iNumTextures || m_Faces[ i ].text <= 0 ) {
            if ( i == 0 ) texture = 0;
        } else {
            texture = m_Faces[ i ].text;
        }

        glBindTexture( GL_TEXTURE_2D, m_glTextures[ texture ] );
        /*
          if (alphatex[texture]) {
            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE);
          } else {
        */
//    glEnable(GL_ALPHA_TEST);
//    glAlphaFunc(GL_GREATER, 0.90);
        /*
          }
        */


        glGetFloatv( GL_MODELVIEW_MATRIX, &Mat[ 0 ] );


//  float vin[3], vout[3];

        vTriangle[ 0 ] = CVector3( m_Vertices[ m_Faces[ i ].v[ 0 ] ] );
        vTriangle[ 1 ] = CVector3( m_Vertices[ m_Faces[ i ].v[ 1 ] ] );
        vTriangle[ 2 ] = CVector3( m_Vertices[ m_Faces[ i ].v[ 2 ] ] );

        vTriangle[ 0 ] = vTriangle[ 0 ] * Mat;
        vTriangle[ 1 ] = vTriangle[ 1 ] * Mat;
        vTriangle[ 2 ] = vTriangle[ 2 ] * Mat;

        vNormal = Normal( vTriangle );

        glBegin( GL_TRIANGLES );
//
        glNormal3f ( vNormal.x, vNormal.y, vNormal.z );

        glTexCoord2fv ( &m_TexVertices[ m_Faces[ i ].t[ 0 ] ][ 1 ] );
        glVertex3fv ( m_Vertices[ m_Faces[ i ].v[ 0 ] ] );

        glTexCoord2fv ( &m_TexVertices[ m_Faces[ i ].t[ 2 ] ][ 1 ] );
        glVertex3fv ( m_Vertices[ m_Faces[ i ].v[ 2 ] ] );

        glTexCoord2fv ( &m_TexVertices[ m_Faces[ i ].t[ 1 ] ][ 1 ] );
        glVertex3fv ( m_Vertices[ m_Faces[ i ].v[ 1 ] ] );
        glEnd();

        /*
          if (alphatex[texture]) {
           glDisable(GL_BLEND);
          } else {
           glDisable(GL_ALPHA_TEST);
          }
        */
    }

    DisplayBoundingBox(&max[0], &min[0], 1, 0, 0);
}






CResource_Model_File::CResource_Model_File() {}

CResource_Model_File::~CResource_Model_File() {}

void CResource_Model_File::LoadFromGRF( char* szFilename ) {
    uint32_t filesize;
    void* filedata;
    filedata = g_pGrfInterface->GetRSM( szFilename, &filesize );
    if ( filedata == NULL || !LoadFromMemory( filedata, filesize ) )
        return;

    printf( "Loading object \"%s\"...\n", szFilename );
}

bool CResource_Model_File::LoadFromMemory( void* pData, uint32_t nSize ) {

    READ(dwFileID, 0, 4);

    if( dwFileID != RSMHEADER ) { // "GRSM"
        printf("No valid RSM header...\n");
        return false;
    }

    READ(bMajorVersion, 4, 1);
    READ(bMinorVersion, 5, 1);

    READ(uUnknown1, 6, 25); // TODO: identify, i bet m_nMeshes is there too :p
    READ(iNumTextures, 31, 4);

    printf( "Loading model file \"%s\" (0x%02X%02X) with %i textures...\n", "filename.rsm", bMajorVersion, bMinorVersion, iNumTextures );

    szTextureNames = new ro_string_t[iNumTextures];

    for(int i=0; i<iNumTextures; i++) {
        READ(szTextureNames[i], 35 + (i * 40), 40);
        printf("Loading model texture: \"%s\"\n", szTextureNames[i]);
    }

    m_glTextures = new GLuint[ iNumTextures ];

    for(int i=0; i<iNumTextures; i++ ) {
        CSDL_GL_Texture* temp = new CSDL_GL_Texture( szTextureNames[i], 255 );
        m_glTextures[ i ] = temp->m_iID;
        delete temp;
    }

    unsigned long iOffset = 35 + (iNumTextures * 40);

    // now load the meshes
    // set pointer to start of mesh data
    unsigned char* meshdata = (unsigned char*)pData + iOffset;
    unsigned int meshsize = nSize - ( meshdata - (unsigned char*) pData );

    printf( "mesh size = %i bytes...\n", meshsize );
    int bRead = 0;
    // load main mesh
    m_nMeshes = 0;

    m_Mesh[ m_nMeshes ] = new CRSM_Mesh( m_glTextures, NULL );

    bRead = m_Mesh[ m_nMeshes ] ->LoadFromMemory( meshdata, nSize - ( meshdata - ( unsigned char* ) pData ), true );

    printf( "read %i bytes...\n", bRead );

    m_nMeshes++;

    // load child meshes
    meshdata += bRead;
    meshsize -= bRead;

    unsigned char* pEnd = ( unsigned char* ) pData + nSize;
//        for(m_nMeshes=1; (meshdata < pEnd-8) && meshdata != NULL; m_nMeshes++) {
    while ( meshsize > 8 ) {
        m_Mesh[ m_nMeshes ] = new CRSM_Mesh( m_glTextures, NULL );
        bRead = m_Mesh[ m_nMeshes ] ->LoadFromMemory( meshdata, nSize - ( meshdata - ( unsigned char* ) pData ), false );
        printf( "(%i) read %i bytes...\n", meshsize, bRead );
        m_nMeshes++;
        meshdata += bRead;
        meshsize -= bRead;
    }


    //dump(uUnknown1, 25);
    //printf("LOADED %i MESHES (%i)\n", m_nMeshes);

    // TODO: Load more than 1 mesh
    if ( m_nMeshes == 1 )
        m_Mesh[ 0 ] ->only = true;
    else
        m_Mesh[ 0 ] ->only = false;

    father = new int[ m_nMeshes ];

    father[ 0 ] = 0;

    for ( int i = 0; i < m_nMeshes; i++ )
        for ( int j = 0; j < m_nMeshes; j++ )
            if ( ( j != i ) && ( !strcmp( m_Mesh[j]->szParentName, m_Mesh[i]->szMeshName ) ) )
                father[ j ] = i;

    BoundingBox();
} // LoadFromMemory


void CResource_Model_File::BoundingBox() {
    m_Mesh[0]->BoundingBox();

    for ( int i = 1; i < m_nMeshes; i++ ) {
        if ( father[ i ] == 0 )
            m_Mesh[ i ] ->BoundingBox( ( &m_Mesh[ 0 ] ->m_Transf ) );

        for ( int bi = 0; bi < 3; bi++ ) {
            box.max[ bi ] = m_Mesh[ 0 ] ->max[ bi ];
            box.min[ bi ] = m_Mesh[ 0 ] ->min[ bi ];

            for ( int j = 1; j < m_nMeshes; j++ ) {
                if ( father[ j ] == 0 ) {
                    box.max[ bi ] = MAX( m_Mesh[ j ] ->max[ bi ], box.max[ bi ] );
                    box.min[ bi ] = MIN( m_Mesh[ j ] ->min[ bi ], box.min[ bi ] );
                }
            }

            box.range[ bi ] = ( box.max[ bi ] + box.min[ bi ] ) / 2.0;
        }
    }

} //

void CResource_Model_File::Render( ro_position_t pos ) {
    glPushMatrix();
    glTranslatef( pos.x, -pos.y, pos.z );
    glRotatef( pos.ry, 0.0, 1.0, 0.0 );
    glRotatef( pos.rz, 1.0, 0.0, 0.0 );
    glRotatef( pos.rx, 0.0, 0.0, 1.0 );
    glScalef( pos.sx, -pos.sy, pos.sz );
    DisplayMesh( &box, 0 );
    glPopMatrix();
}

void CResource_Model_File::DisplayMesh( bounding_box_t *b, int n, ro_transf_t *ptransf ) {
    glPushMatrix();
    m_Mesh[ n ] ->Render( b, ptransf );

    for ( int i = 0; i < m_nMeshes; i++ )
        if ( ( i != n ) && ( father[ i ] == n ) ) {
            DisplayMesh( ( n == 0 ) ? b : NULL, i, &m_Mesh[ n ] ->m_Transf );
        }

    glPopMatrix();
}
