/*
 *  ORC - Open Ragnarok Client
 *  ro_types.h - Typedefs used by the loaders
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

#ifndef RO_TYPES_H
#define RO_TYPES_H



#define MEMCPY(dst, src, size, offset, len) \
    if( (offset+len)-1 < size) { \
        memcpy((unsigned char*)&dst, (unsigned char*)src + offset, len); \
    } else { \
        printf("Fatal error: Trying to read array[%i] where size of array == %i in \"%s\" on line %i\n", offset+len, size, __FILE__, __LINE__); \
        exit(0); \
    } \

#define READ(dst, offset, len) MEMCPY(dst, pData, nSize, offset, len);

// TODO: consider byte order
#define GNDHEADER   0x4E475247
#define RSMHEADER   0x4D535247



#ifdef WIN32
/* Pack to 1 byte boundaries */
#include <pshpack1.h>
#else /* WIN32 */
/* Pack to 1 byte boundaries */
#pragma pack(1)
#endif /* WIN32 */


#define FIXEDSTRINGLEN 40
typedef char ro_string_t[FIXEDSTRINGLEN];

typedef char rgb[ 4 ];

typedef struct {
    float x;
    float y;
    float z;
    float rx;
    float ry;
    float rz;
    float sx;
    float sy;
    float sz;
}
ro_position_t;



typedef struct {
    Uint16 m_ModelID;
    ro_string_t m_FilePath;
    Uint8 unknown1[ 120 ];
    Uint8 unknown2[ 56 ];
    ro_position_t position;
}
ro_model_t;

typedef struct {
    char id[ 4 ]; // GRSW
    unsigned char major_version;
    unsigned char minor_version;
    char szIniFile[ FIXEDSTRINGLEN ]; // Only in Alpha
    char szGndFile[ FIXEDSTRINGLEN ];
    char szGatFile[ FIXEDSTRINGLEN ];
    char szSrcFile[ FIXEDSTRINGLEN ]; // Only in Alpha

    // water properties
    float water_height;
    Uint32 water_type;
    float water_amplitude;
    float water_phase;
    float water_curve_level;
    Uint32 water_cycles;

    // light properties
    float ambient_color[ 3 ];
    float diffuse_color[ 3 ];
    float shadow_color[ 3 ];

    float alpha_value; // map transparency, huh ??

    Uint8 _unknown1[ 12 ];
    Uint32 object_count;
}
rsw_header_t;


typedef struct {
    Uint32 type;
    char szName[ FIXEDSTRINGLEN ]; // Unique name

//    Uint32 unknown1; // As long as nobody tells me its terribly wrong i use this for storing a boolean...
    Uint8 bIsUnique;
    Uint8 model; // blerks
    Uint8 unk[ 2 ];

    float unknown2;
    float unknown3;

    char szFilename[ FIXEDSTRINGLEN ]; //
    char szReserved[ FIXEDSTRINGLEN ]; //

    // Ximosoft says that these arrays are only 20 bytes long, but that seems to be wrong...
    char szType[ FIXEDSTRINGLEN ]; // CylinderN, BoxN, SphereN
    char szSound[ FIXEDSTRINGLEN ]; // Sound associated
    // char szUnknown[40];

    /*    float pos_x;
        float pos_y;
        float pos_z;

        float rot_x;
        float rot_y;
        float rot_z;

        float scale_x;
        float scale_y;
        float scale_z;*/

    ro_position_t position;

}
rsw_object_t;




typedef struct {
    float todo[ 22 ];
}
ro_transf_t;

typedef float ro_vertex_t[ 3 ];

typedef struct {
    short v[ 3 ];
    short t[ 3 ];
    unsigned short text;
    unsigned short todo1;
    unsigned int todo2;
    unsigned int nsurf;
}
ro_face_t;

typedef float ro_quat_t[ 4 ];

typedef struct {
    int time;
    ro_quat_t orientation;
}
ro_frame_t;

typedef struct {
    float max[ 3 ];
    float min[ 3 ];
    float range[ 3 ];
}
bounding_box_t;



#endif // RO_TYPES_H
