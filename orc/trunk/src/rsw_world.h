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
