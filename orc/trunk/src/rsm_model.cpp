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

    only = false;
}

CRSM_Mesh::~CRSM_Mesh() {
    if( m_TexIDs != NULL)
        delete[] m_TexIDs;
    if( m_Vertices != NULL)
        delete[] m_Vertices;
    if( m_TexVertices != NULL)
        delete[] m_TexVertices;
    if( m_Faces != NULL)
        delete[] m_Faces;
    if( m_Frames != NULL)
        delete[] m_Frames;
}

int CRSM_Mesh::LoadFromMemory( void* pData, uint32_t nSize, bool bIsParent ) {
    BEGIN_READ(0);

    dump(pData, nSize);

    AUTO_READ(szMeshName, 40);

    if ( bIsParent == true ) {
        AUTO_READ(iUnknown1, 4);
    }

    AUTO_READ(szParentName, 40);

    if ( bIsParent == true ) {
        AUTO_READ(fUnknown2, 40);
    }

    AUTO_READ(iNumTextures, 4);

    m_TexIDs = new unsigned int[iNumTextures];
    AUTO_READ(m_TexIDs[0], 4 * iNumTextures);

    AUTO_READ(m_Transf, sizeof(ro_transf_t));

    AUTO_READ(m_nVertices, 4);
    m_Vertices = new ro_vertex_t[m_nVertices];
    AUTO_READ(m_Vertices[0], sizeof(ro_vertex_t) * m_nVertices);

    AUTO_READ(m_nTexVertices, 4);
    m_TexVertices = new ro_vertex_t[m_nTexVertices];
    AUTO_READ(m_TexVertices[0], sizeof(ro_vertex_t) * m_nTexVertices);

    AUTO_READ(m_nFaces, 4);
    m_Faces = new ro_face_t[m_nFaces];
    AUTO_READ(m_Faces[0], sizeof(ro_face_t) * m_nFaces);

    if( iOffset < nSize) {
        AUTO_READ(m_nFrames, 4);
        m_Frames = new ro_frame_t[m_nFrames];
        AUTO_READ(m_Frames[0], sizeof(ro_frame_t) * m_nFrames);
    }

    // printf( "Loading mesh \"%s\" with %i textures, %i vertices and %i texture vertices on %i faces...\n", szMeshName, iNumTextures, m_nVertices, m_nTexVertices, m_nFaces );

    return iOffset;
} // LoadFromMemory



void CRSM_Mesh::BoundingBox( ro_transf_t *ptransf ) {

    // are we parent or child mesh ?
    bool IsParent = ( ptransf == NULL ) ? true : false;


    float matRotation[16];


    matRotation[ 0 ] = m_Transf.matrix[0][0];
    matRotation[ 1 ] = m_Transf.matrix[0][1];
    matRotation[ 2 ] = m_Transf.matrix[0][2];
    matRotation[ 3 ] = 0.0;

    matRotation[ 4 ] = m_Transf.matrix[1][0];
    matRotation[ 5 ] = m_Transf.matrix[1][1];
    matRotation[ 6 ] = m_Transf.matrix[1][2];
    matRotation[ 7 ] = 0.0;

    matRotation[ 8 ] = m_Transf.matrix[2][0];
    matRotation[ 9 ] = m_Transf.matrix[2][1];
    matRotation[ 10 ] = m_Transf.matrix[2][2];
    matRotation[ 11 ] = 0.0;

    matRotation[ 12 ] = 0.0;
    matRotation[ 13 ] = 0.0;
    matRotation[ 14 ] = 0.0;
    matRotation[ 15 ] = 1.0;

    max[ 0 ] = max[ 1 ] = max[ 2 ] = -999999.0;
    min[ 0 ] = min[ 1 ] = min[ 2 ] = 999999.0;

    // calculate our bounding box
    CVector3 relative;

    for(int i=0; i < m_nVertices; i++ ) {
        // float vout[ 3 ];
        //MatrixMultVect( Rot, m_Vertices[ i ], vout );
        relative = m_Vertices[i]; //MatrixMultVect3f( matRotation, m_Vertices[i][0], m_Vertices[i][1], m_Vertices[i][2] );

/*
        for(int j=0; j<3; j++ ) {
            float f;
            if ( !only )
                f = vout[ j ] + transf.todo[ 12 + j ] + transf.todo[ 9 + j ];
            else
                f = vout[ j ];

            min[ j ] = MIN( f, min[ j ] );
            max[ j ] = MAX( f, max[ j ] );
        }

        CVector3 absolute = relative + transf.position + transf.childpos;
*/
        CVector3 absolute;
        absolute.x = relative.x + m_Transf.position.x + m_Transf.childpos.x;
        absolute.y = relative.y + m_Transf.position.y + m_Transf.childpos.y;
        absolute.z = relative.z + m_Transf.position.z + m_Transf.childpos.z;

        min[0] = MIN( absolute.x, min[0] );
        max[0] = MAX( absolute.x, max[0] );
        min[1] = MIN( absolute.y, min[1] );
        max[1] = MAX( absolute.y, max[1] );
        min[2] = MIN( absolute.z, min[2] );
        max[2] = MAX( absolute.z, max[2] );

    }

    for(int j=0; j<3; j++ ) {
        range[ j ] = ( max[ j ] - min[ j ] ) / 2.0;
    }
}


void CRSM_Mesh::Render( bounding_box_t *box, ro_transf_t *ptransf ) {

    float matRotation[16];
    float matOrientation[16];

    bool IsParent = ( ptransf == NULL) ? true : false;

    CVector3 vNormal;
    CVector3 vTriangle[ 3 ];


    matRotation[ 0 ] = m_Transf.matrix[0][0];
    matRotation[ 1 ] = m_Transf.matrix[0][1];
    matRotation[ 2 ] = m_Transf.matrix[0][2];
    matRotation[ 3 ] = 0.0;

    matRotation[ 4 ] = m_Transf.matrix[1][0];
    matRotation[ 5 ] = m_Transf.matrix[1][1];
    matRotation[ 6 ] = m_Transf.matrix[1][2];
    matRotation[ 7 ] = 0.0;

    matRotation[ 8 ] = m_Transf.matrix[2][0];
    matRotation[ 9 ] = m_Transf.matrix[2][1];
    matRotation[ 10 ] = m_Transf.matrix[2][2];
    matRotation[ 11 ] = 0.0;

    matRotation[ 12 ] = 0.0;
    matRotation[ 13 ] = 0.0;
    matRotation[ 14 ] = 0.0;
    matRotation[ 15 ] = 1.0;


    if ( m_nFrames ) {
        int current = 0;
        int next;
        float t;
        float q[ 4 ], q1[ 4 ], q2[ 4 ];
        float x, y, z, w;
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

        t = ( ( float ) ( nstep - m_Frames[ current ].time ) )
            / ( ( float ) ( m_Frames[ next ].time - m_Frames[ current ].time ) );


        x = m_Frames[ current ].orientation[ 0 ] * ( 1 - t ) + t * m_Frames[ next ].orientation[ 0 ];
        y = m_Frames[ current ].orientation[ 1 ] * ( 1 - t ) + t * m_Frames[ next ].orientation[ 1 ];
        z = m_Frames[ current ].orientation[ 2 ] * ( 1 - t ) + t * m_Frames[ next ].orientation[ 2 ];
        w = m_Frames[ current ].orientation[ 3 ] * ( 1 - t ) + t * m_Frames[ next ].orientation[ 3 ];

        float norm;

        norm = sqrtf( x * x + y * y + z * z + w * w );
        x /= norm;
        y /= norm;
        z /= norm;
        w /= norm;

        // First row
        matOrientation[ 0 ] = 1.0f - 2.0f * ( y * y + z * z );
        matOrientation[ 1 ] = 2.0f * ( x * y + z * w );
        matOrientation[ 2 ] = 2.0f * ( x * z - y * w );
        matOrientation[ 3 ] = 0.0f;

        // Second row
        matOrientation[ 4 ] = 2.0f * ( x * y - z * w );
        matOrientation[ 5 ] = 1.0f - 2.0f * ( x * x + z * z );
        matOrientation[ 6 ] = 2.0f * ( z * y + x * w );
        matOrientation[ 7 ] = 0.0f;

        // Third row
        matOrientation[ 8 ] = 2.0f * ( x * z + y * w );
        matOrientation[ 9 ] = 2.0f * ( y * z - x * w );
        matOrientation[ 10 ] = 1.0f - 2.0f * ( x * x + y * y );
        matOrientation[ 11 ] = 0.0f;

        // Fourth row
        matOrientation[ 12 ] = 0;
        matOrientation[ 13 ] = 0;
        matOrientation[ 14 ] = 0;
        matOrientation[ 15 ] = 1.0f;

        nstep += 100;

        if ( nstep >= m_Frames[ m_nFrames - 1 ].time )
            nstep = 0;
    }


    // apply mesh scaling
    glScalef ( m_Transf.scale.x, m_Transf.scale.y, m_Transf.scale.z );

    if ( IsParent )
        if ( !only ) {
            glTranslatef( -box->range[ 0 ], -box->max[ 1 ], -box->range[ 2 ] );
        } else {
            glTranslatef( 0.0, -box->max[ 1 ] + box->range[ 1 ], 0.0 );
        }

    if ( !IsParent )
        glTranslatef( m_Transf.childpos.x, m_Transf.childpos.y, m_Transf.childpos.z );

    if ( !m_nFrames )
        glRotatef( m_Transf.angle * 180.0 / 3.14159,
                   m_Transf.rotation.x, m_Transf.rotation.y, m_Transf.rotation.z );
    else
        glMultMatrixf( matOrientation );


    glPushMatrix();

    if ( IsParent && only )
        glTranslatef( -box->range[ 0 ], -box->range[ 1 ], -box->range[ 2 ] );

    if ( !IsParent || !only )
        glTranslatef( m_Transf.position.x, m_Transf.position.y, m_Transf.position.z );


   glMultMatrixf( matRotation );

    for ( int i = 0; i < m_nFaces; i++ ) {
        ro_vertex_t *v;
        ro_vertex_t *t;
        int texture;

        if ( m_Faces[ i ].text > iNumTextures-1 || m_Faces[ i ].text < 1 ) {
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

    float Mat[ 16 ];
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

    //BoundingBox();
    glPopMatrix();
}


/*
    Model class
*/
CResource_Model_File::CResource_Model_File() {
    //
}

CResource_Model_File::~CResource_Model_File() {
    if( szTextureNames != NULL )
        delete[] szTextureNames;
}

void CResource_Model_File::LoadFromGRF( char* szFilename ) {
    uint32_t filesize;
    void* filedata;
    strcpy(m_szFilename, szFilename);

    filedata = g_pGrfInterface->GetRSM( szFilename, &filesize );
    if ( filedata == NULL || !LoadFromMemory( filedata, filesize ) )
        return;
}

bool CResource_Model_File::LoadFromMemory( void* pData, uint32_t nSize ) {
    BEGIN_READ(0);
    AUTO_READ(dwFileID, 4);

    if( dwFileID != RSMHEADER ) { // "GRSM"
        printf("No valid RSM header...\n");
        return false;
    }

    AUTO_READ(bMajorVersion, 1);
    AUTO_READ(bMinorVersion, 1);

    AUTO_READ(uUnknown1, 25); // TODO: identify, i bet m_nMeshes is there too :p
    AUTO_READ(iNumTextures, 4);

    // printf( "Loading model file \"%s\" (0x%02X%02X) with %i textures...\n", m_szFilename, bMajorVersion, bMinorVersion, iNumTextures );

    szTextureNames = new ro_string_t[iNumTextures];

    for(int i=0; i<iNumTextures; i++) {
        AUTO_READ(szTextureNames[i], 40);
        printf("\"%s\"\n", szTextureNames[i]);
    }
    // printf("\n");

    m_glTextures = new GLuint[ iNumTextures ];

    for(int i=0; i<iNumTextures; i++ ) {
        CSDL_GL_Texture* temp = new CSDL_GL_Texture( szTextureNames[i], 255 );
        m_glTextures[ i ] = temp->m_iID;
        delete temp;
    }

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

    while ( meshsize > 80 ) {
        m_Mesh[ m_nMeshes ] = new CRSM_Mesh( m_glTextures, NULL );
        bRead = m_Mesh[ m_nMeshes ] ->LoadFromMemory( meshdata, nSize - ( meshdata - ( unsigned char* ) pData ), false );
        printf( "(%i) read %i bytes...\n", meshsize, bRead );

        // crash ?!?!?!
        m_Mesh[ m_nMeshes ]->only = false;

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

    for ( int i = 0; i < m_nMeshes; i++ ) {
        for ( int j = 0; j < m_nMeshes; j++ ) {
            if ( ( j != i ) && ( strcmp( m_Mesh[j]->szParentName, m_Mesh[i]->szMeshName ) == 0) ) {
                father[ j ] = i;
            }
        }
    }


    BoundingBox();
} // LoadFromMemory


void CResource_Model_File::BoundingBox() {
    m_Mesh[0]->BoundingBox();

    for ( int i = 1; i < m_nMeshes; i++ ) {
        if ( father[ i ] == 0 )
            m_Mesh[ i ] ->BoundingBox( ( &m_Mesh[ 0 ] ->m_Transf ) );
    }

        for ( int i = 0; i < 3; i++ ) {
            box.max[ i ] = m_Mesh[ 0 ] ->max[ i ];
            box.min[ i ] = m_Mesh[ 0 ] ->min[ i ];

            for ( int j = 1; j < m_nMeshes; j++ ) {
                if ( father[ j ] == 0 ) {
                    box.max[ i ] = MAX( m_Mesh[ j ] ->max[ i ], box.max[ i ] );
                    box.min[ i ] = MIN( m_Mesh[ j ] ->min[ i ], box.min[ i ] );
                }
            }

            box.range[ i ] = ( box.max[ i ] + box.min[ i ] ) / 2.0;
        }
//    }

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

    for ( int i = 0; i < m_nMeshes; i++ ) {
        if ( ( i != n ) && ( father[ i ] == n ) ) {
          DisplayMesh( ( n == 0 ) ? b : NULL, i, &m_Mesh[ n ] ->m_Transf );
        }
    }

    glPopMatrix();
}
