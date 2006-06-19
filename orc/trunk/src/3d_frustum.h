/*
*  ORC - Open Ragnarok Client
*  3d_frustum.h - Frustum Culling
*
*  Copyright (C) 2001 DigiBen <digiben@gametutorials.com>
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

#ifndef _3D_FRUSTUM_H
#define _3D_FRUSTUM_H

#include "3d_math.h"

// This will allow us to create an object to keep track of our frustum

class CFrustum {

public:

    // Call this every time the camera moves to update the frustum
    void CalculateFrustum();

    // This takes a 3D point and returns TRUE if it's inside of the frustum
    bool PointInFrustum(float x, float y, float z);

    // This takes a 3D point and a radius and returns TRUE if the sphere is inside of the frustum
    bool SphereInFrustum(float x, float y, float z, float radius);

    // This takes the center and half the length of the cube.
    bool CubeInFrustum( float x, float y, float z, float size );

    bool BoxInFrustum( float x, float y, float z, float width, float height, float length);

private:

    // This holds the A B C and D values for each side of our frustum.
    float m_Frustum[6][4];
};


#endif // _3D_FRUSTUM_H
