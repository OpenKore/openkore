/*
 *  ORC - Open Ragnarok Client
 *  rsm_model.h - Resource Model File Loader
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

#ifndef RSM_MODEL_H
#define RSM_MODEL_H

#include "3d_math.h"
#include "3d_frustum.h"

#include "ro_types.h"



class CRSM_Mesh {
public:
    CRSM_Mesh( GLuint* glTextures, bool* glTextureIsAlpha );
    virtual ~CRSM_Mesh();

    int LoadFromMemory( void* pData, uint32_t nSize, bool bIsParent );
    void Render( bounding_box_t *box, ro_transf_t *ptransf );
    void BoundingBox( ro_transf_t *ptransf = NULL );

    bool only;
    bool drawbounds;
    int nstep;

    GLfloat range[ 3 ];
    GLfloat min[ 3 ];
    GLfloat max[ 3 ];

    GLuint* m_glTextures;
    bool* m_glTextureIsAlpha;


    // file structure
    ro_string_t szMeshName;
    unsigned int         iUnknown1;  // TODO: identify
    ro_string_t szParentName;
    float       fUnknown2[10]; // TODO: identify
    unsigned int iNumTextures;

    unsigned int* m_TexIDs;
    ro_transf_t   m_Transf;
    unsigned int m_nVertices;
    ro_vertex_t* m_Vertices;

    unsigned int m_nTexVertices;
    ro_vertex_t* m_TexVertices;

    unsigned int m_nFaces;
    ro_face_t* m_Faces;

    unsigned int m_nFrames;
    ro_frame_t* m_Frames;


};



class CResource_Model_File {
public:
    CResource_Model_File();
    virtual ~CResource_Model_File();

    // rsm file structure
    struct {
        unsigned long dwFileID;
        unsigned char bMajorVersion;
        unsigned char bMinorVersion;
        unsigned char uUnknown1[ 25 ]; // TODO: identify
        unsigned long iNumTextures;
        ro_string_t* szTextureNames; // 40 * iNumTextures
    }; // rsm file structure

    void LoadFromGRF( char* szFilename );
    bool LoadFromMemory( void* pData, uint32_t nSize );

    void BoundingBox();
    void Render( ro_position_t pos );
    void DisplayMesh( bounding_box_t *b, int n, ro_transf_t *ptransf = NULL );

    char m_szFilename[MAX_PATH];

    CRSM_Mesh* m_Mesh[ 8 ];
    GLuint* m_glTextures;
    bounding_box_t box;
    Uint16 m_nMeshes;

    int *father;
};


#endif // RSM_MODEL_H
