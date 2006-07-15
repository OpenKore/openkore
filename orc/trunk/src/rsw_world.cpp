/*
 *  ORC - Open Ragnarok Client
 *  rsw_world.cpp - Resource World File Loader
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

#include "rsw_world.h"



CRSW::CRSW( char* szFilename ) {
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

CRSW::~CRSW() {
    if( m_Models != NULL )
        delete[] m_Models;

    if( m_RealModels != NULL )
        delete[] m_RealModels;
}

bool CRSW::LoadFromMemory( void* pData, uint32_t nSize ) {
    BEGIN_READ(0);
    AUTO_READ(dwFileID, 4);

    if( dwFileID != RSWHEADER ) { // "GRSW"
        printf("No valid RSW header...\n");
        return false;
    }

    AUTO_READ(bMajorVersion, 1);
    AUTO_READ(bMinorVersion, 1);
    AUTO_READ(szIniFile, 240);  // read in the header in one go

    // TODO: make all types into a union ?
    m_Models = new rsw_object_type1[object_count];

    // now read in all objects
    unsigned long objType = 1;
    while(objType == 1) {
        AUTO_READ(objType, 4);
        if(objType == 1) {
            AUTO_READ(m_Models[m_nModels++], sizeof(rsw_object_type1));
        }
    }

    // TODO: Move to another function ?
    m_nUniqueModels = 0;
    for(int i=0; i<m_nModels; i++) {
        m_Models[ i ].bIsUnique = true;
        for ( int j = 0; j < i; j++ ) {
            if ( !strcmp( m_Models[j].szFilename, m_Models[i].szFilename) ) {
                m_Models[ i ].bIsUnique = false;
                break;
            }
        }
        if ( m_Models[i].bIsUnique ) {
            // loading should be done here ?
            m_nUniqueModels++;
        }
    }

    // printf( "Loading world file with %i objects, %i models (%i)...\n", object_count, m_nModels, m_nUniqueModels );

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
        m_Models[ i ].iModelID = 1;

        for ( int num = 0; num < m_nUniqueModels; num++ ) {
            if ( !strcmp( m_Models[ i ].szFilename, realmodelspath[ num ] ) ) {
                m_Models[ i ].iModelID = num;
                break;

            }
        }
    }

    delete[] realmodelspath;

    // printf("-------------------------------------------------------------------------------\n\n");

    return true;
}


