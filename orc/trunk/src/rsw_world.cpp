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
