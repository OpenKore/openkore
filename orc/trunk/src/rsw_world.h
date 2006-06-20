/*
 *  ORC - Open Ragnarok Client
 *  rsw_world.h - Resource World File Loader
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

#include "3d_math.h"
#include "3d_frustum.h"
#include "ro_types.h"
#include "rsm_model.h"

class CRSW {
public:
    CRSW( char* szFilename );
    virtual ~CRSW();

    // rsw file structure
    struct {
        // field
        unsigned long dwFileID;
        unsigned char bMajorVersion;
        unsigned char bMinorVersion;
        char szIniFile[ FIXEDSTRINGLEN ]; // Only in Alpha
        char szGndFile[ FIXEDSTRINGLEN ];
        char szGatFile[ FIXEDSTRINGLEN ];
        char szSrcFile[ FIXEDSTRINGLEN ]; // Only in Alpha

        // water properties
        float   water_height;
        Uint32  water_type;
        float   water_amplitude;
        float   water_phase;
        float   water_curve_level;
        Uint32  water_cycles;

        // light properties
        float ambient_color[ 3 ];
        float diffuse_color[ 3 ];
        float shadow_color[ 3 ];
        float alpha_value; // map transparency, huh ??

        Uint8 _unknown1[ 12 ];
        Uint32 object_count;
    }; // rsw file structure

//private:
    bool LoadFromMemory( void* pData, uint32_t nSize );

    char m_szMapName[ 128 ];
    char m_szMiniMap[ 128 ];

    rsw_object_type1* m_Models;

    Uint16 m_nModels;
    Uint16 m_nUniqueModels;

    CResource_Model_File* m_RealModels;

};
