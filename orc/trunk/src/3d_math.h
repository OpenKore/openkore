/*
 *  ORC - Open Ragnarok Client
 *  3d_math.h - Vector and matrix operations
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

#ifndef _3D_MATH_H
#define _3D_MATH_H

// Oops, its recursive...
#include "csdl/csdl.h"


#define MIN(a, b) (a>b)?b:a
#define MAX(a, b) (a>b)?a:b


// This is our basic 3D point/vector class
class CVector3 {
public:

    // A default constructor
    CVector3() {}


    // This is our constructor that allows us to initialize our data upon creating an instance
    CVector3(float *pVertex3) {
        x = pVertex3[0];
        y = pVertex3[1];
        z = pVertex3[2];
    }

    // This is our constructor that allows us to initialize our data upon creating an instance
    CVector3(float X, float Y, float Z) {
        x = X;
        y = Y;
        z = Z;
    }

    // Here we overload the + operator so we can add vectors together
    CVector3 operator+(CVector3 vVector) {
        // Return the added vectors result.
        return CVector3(vVector.x + x, vVector.y + y, vVector.z + z);
    }

    // Here we overload the - operator so we can subtract vectors
    CVector3 operator-(CVector3 vVector) {
        // Return the subtracted vectors result
        return CVector3(x - vVector.x, y - vVector.y, z - vVector.z);
    }

    // Here we overload the * operator so we can multiply by scalars
    CVector3 operator*(float num) {
        // Return the scaled vector
        return CVector3(x * num, y * num, z * num);
    }

    CVector3 operator*(GLfloat matrix[16]) {
        CVector3 tempvect;
        tempvect.x = x * matrix[0] + y * matrix[4] + z * matrix[8]  + 1.0 * matrix[12];
        tempvect.y = x * matrix[1] + y * matrix[5] + z * matrix[9]  + 1.0 * matrix[13];
        tempvect.z = x * matrix[2] + y * matrix[6] + z * matrix[10] + 1.0 * matrix[14];
        return tempvect;
    }

    // Here we overload the / operator so we can divide by a scalar
    CVector3 operator/(float num) {
        // Return the scale vector
        return CVector3(x / num, y / num, z / num);
    }

    float x, y, z;
};


//	This returns a perpendicular vector from 2 given vectors by taking the cross product.
CVector3 Cross(CVector3 vVector1, CVector3 vVector2);

//	This returns a vector between 2 points
CVector3 Vector(CVector3 vPoint1, CVector3 vPoint2);

//	This returns the magnitude of a normal (or any other vector)
float Magnitude(CVector3 vNormal);

//	This returns a normalize vector (A vector exactly of length 1)
CVector3 Normalize(CVector3 vNormal);

//	This returns the normal of a polygon (The direction the polygon is facing)
CVector3 Normal(CVector3 vTriangle[]);




void MatrixMultVect(const GLfloat *M, const GLfloat *Vin, GLfloat *Vout);
CVector3 MatrixMultVect3f(const GLfloat *M, float x, float y, float z);



#endif
