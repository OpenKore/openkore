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

#define BEGIN_READ(n)       unsigned long iOffset = n;
#define AUTO_READ(d, l)     READ(d, iOffset, l) \
                            iOffset += l; \


// TODO: consider byte order
#define GNDHEADER   0x4E475247
#define RSMHEADER   0x4D535247
#define RSWHEADER   0x57535247


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
} ro_position_t;


typedef struct {
//    Uint32 type;
    char szName[ FIXEDSTRINGLEN ]; // Unique name

    // Uint32 unknown1; // TODO: identify
    // As long as i don't know, i use this for my purpose... :P
    Uint16 iModelID;
    Uint16 bIsUnique;

    float unknown2;
    float unknown3;

    char szFilename[ FIXEDSTRINGLEN ]; //
    char szReserved[ FIXEDSTRINGLEN ]; //

    // Ximosoft says that these arrays are only 20 bytes long, but that seems to be wrong...
    char szType[ FIXEDSTRINGLEN ]; // CylinderN, BoxN, SphereN
    char szSound[ FIXEDSTRINGLEN ]; // Sound associated
    // char szUnknown[40];

    ro_position_t position;
} rsw_object_type1;


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
