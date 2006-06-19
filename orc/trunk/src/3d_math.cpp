/*
 *  ORC - Open Ragnarok Client
 *  3d_math.cpp - Vector and matrix operations
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

#include "3d_math.h"


void MatrixMultVect(const GLfloat *M, const GLfloat *Vin, GLfloat *Vout) {
    Vout[0] = Vin[0]*M[0] + Vin[1]*M[4] + Vin[2]*M[8] + 1.0*M[12];
    Vout[1] = Vin[0]*M[1] + Vin[1]*M[5] + Vin[2]*M[9] + 1.0*M[13];
    Vout[2] = Vin[0]*M[2] + Vin[1]*M[6] + Vin[2]*M[10] + 1.0*M[14];
}


CVector3 MatrixMultVect3f(const GLfloat *M, float x, float y, float z) {
    CVector3 tempvect;
    tempvect.x = x * M[0] + y * M[4] + z * M[8]  + 1.0 * M[12];
    tempvect.y = x * M[1] + y * M[5] + z * M[9]  + 1.0 * M[13];
    tempvect.z = x * M[2] + y * M[6] + z * M[10] + 1.0 * M[14];
    return tempvect;
}



CVector3 Cross(CVector3 vVector1, CVector3 vVector2) {
    CVector3 vNormal;

    // Calculate the cross product with the non communitive equation
    vNormal.x = ((vVector1.y * vVector2.z) - (vVector1.z * vVector2.y));
    vNormal.y = ((vVector1.z * vVector2.x) - (vVector1.x * vVector2.z));
    vNormal.z = ((vVector1.x * vVector2.y) - (vVector1.y * vVector2.x));

    // Return the cross product
    return vNormal;
}


float Magnitude(CVector3 vNormal) {
    // Here is the equation:  magnitude = sqrt(V.x^2 + V.y^2 + V.z^2) : Where V is the vector
    return (float)sqrt( (vNormal.x * vNormal.x) +
                        (vNormal.y * vNormal.y) +
                        (vNormal.z * vNormal.z) );
}

CVector3 Vector(CVector3 vPoint1, CVector3 vPoint2) {
    CVector3 vVector;								// Initialize our variable to zero

    // In order to get a vector from 2 points (a direction) we need to
    // subtract the second point from the first point.

    vVector.x = vPoint1.x - vPoint2.x;					// Get the X value of our new vector
    vVector.y = vPoint1.y - vPoint2.y;					// Get the Y value of our new vector
    vVector.z = vPoint1.z - vPoint2.z;					// Get the Z value of our new vector

    // Now that we have our new vector between the 2 points, we will return it.

    return vVector;										// Return our new vector
}

CVector3 Normalize(CVector3 vVector) {
    // Get the magnitude of our normal
    float magnitude = Magnitude(vVector);

    // Now that we have the magnitude, we can divide our vector by that magnitude.
    // That will make our vector a total length of 1.
    vVector = vVector / magnitude;

    // Finally, return our normalized vector
    return vVector;
}

CVector3 Normal(CVector3 vTriangle[]) {
    CVector3 vVector1 = Vector(vTriangle[2], vTriangle[0]);
    CVector3 vVector2 = Vector(vTriangle[1], vTriangle[0]);

    CVector3 vNormal = Cross(vVector1, vVector2);

    vNormal = Normalize(vNormal);

    return vNormal;
}
