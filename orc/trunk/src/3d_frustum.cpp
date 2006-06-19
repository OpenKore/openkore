/*
 *  ORC - Open Ragnarok Client
 *  3d_frustum.cpp - Frustum Culling
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

#include "3d_frustum.h"


// We create an enum of the sides so we don't have to call each side 0 or 1.
// This way it makes it more understandable and readable when dealing with frustum sides.
enum FrustumSide
{
    RIGHT	= 0,		// The RIGHT side of the frustum
    LEFT	= 1,		// The LEFT	 side of the frustum
    BOTTOM	= 2,		// The BOTTOM side of the frustum
    TOP		= 3,		// The TOP side of the frustum
    BACK	= 4,		// The BACK	side of the frustum
    FRONT	= 5			// The FRONT side of the frustum
};

// Like above, instead of saying a number for the ABC and D of the plane, we
// want to be more descriptive.
enum PlaneData
{
    A = 0,				// The X value of the plane's normal
    B = 1,				// The Y value of the plane's normal
    C = 2,				// The Z value of the plane's normal
    D = 3				// The distance the plane is from the origin
};

///////////////////////////////// NORMALIZE PLANE \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This normalizes a plane (A side) from a given frustum.
/////
///////////////////////////////// NORMALIZE PLANE \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

void NormalizePlane(float frustum[6][4], int side) {
    // Here we calculate the magnitude of the normal to the plane (point A B C)
    // Remember that (A, B, C) is that same thing as the normal's (X, Y, Z).
    // To calculate magnitude you use the equation:  magnitude = sqrt( x^2 + y^2 + z^2)
    float magnitude = (float)sqrt( frustum[side][A] * frustum[side][A] +
                                   frustum[side][B] * frustum[side][B] +
                                   frustum[side][C] * frustum[side][C] );

    // Then we divide the plane's values by it's magnitude.
    // This makes it easier to work with.
    frustum[side][A] /= magnitude;
    frustum[side][B] /= magnitude;
    frustum[side][C] /= magnitude;
    frustum[side][D] /= magnitude;
}


///////////////////////////////// CALCULATE FRUSTUM \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This extracts our frustum from the projection and modelview matrix.
/////
///////////////////////////////// CALCULATE FRUSTUM \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

void CFrustum::CalculateFrustum() {
    float   proj[16];								// This will hold our projection matrix
    float   modl[16];								// This will hold our modelview matrix
    float   clip[16];								// This will hold the clipping planes

    // glGetFloatv() is used to extract information about our OpenGL world.
    // Below, we pass in GL_PROJECTION_MATRIX to abstract our projection matrix.
    // It then stores the matrix into an array of [16].
    glGetFloatv( GL_PROJECTION_MATRIX, proj );

    // By passing in GL_MODELVIEW_MATRIX, we can abstract our model view matrix.
    // This also stores it in an array of [16].
    glGetFloatv( GL_MODELVIEW_MATRIX, modl );

    // Now that we have our modelview and projection matrix, if we combine these 2 matrices,
    // it will give us our clipping planes.  To combine 2 matrices, we multiply them.

    clip[ 0] = modl[ 0] * proj[ 0] + modl[ 1] * proj[ 4] + modl[ 2] * proj[ 8] + modl[ 3] * proj[12];
    clip[ 1] = modl[ 0] * proj[ 1] + modl[ 1] * proj[ 5] + modl[ 2] * proj[ 9] + modl[ 3] * proj[13];
    clip[ 2] = modl[ 0] * proj[ 2] + modl[ 1] * proj[ 6] + modl[ 2] * proj[10] + modl[ 3] * proj[14];
    clip[ 3] = modl[ 0] * proj[ 3] + modl[ 1] * proj[ 7] + modl[ 2] * proj[11] + modl[ 3] * proj[15];

    clip[ 4] = modl[ 4] * proj[ 0] + modl[ 5] * proj[ 4] + modl[ 6] * proj[ 8] + modl[ 7] * proj[12];
    clip[ 5] = modl[ 4] * proj[ 1] + modl[ 5] * proj[ 5] + modl[ 6] * proj[ 9] + modl[ 7] * proj[13];
    clip[ 6] = modl[ 4] * proj[ 2] + modl[ 5] * proj[ 6] + modl[ 6] * proj[10] + modl[ 7] * proj[14];
    clip[ 7] = modl[ 4] * proj[ 3] + modl[ 5] * proj[ 7] + modl[ 6] * proj[11] + modl[ 7] * proj[15];

    clip[ 8] = modl[ 8] * proj[ 0] + modl[ 9] * proj[ 4] + modl[10] * proj[ 8] + modl[11] * proj[12];
    clip[ 9] = modl[ 8] * proj[ 1] + modl[ 9] * proj[ 5] + modl[10] * proj[ 9] + modl[11] * proj[13];
    clip[10] = modl[ 8] * proj[ 2] + modl[ 9] * proj[ 6] + modl[10] * proj[10] + modl[11] * proj[14];
    clip[11] = modl[ 8] * proj[ 3] + modl[ 9] * proj[ 7] + modl[10] * proj[11] + modl[11] * proj[15];

    clip[12] = modl[12] * proj[ 0] + modl[13] * proj[ 4] + modl[14] * proj[ 8] + modl[15] * proj[12];
    clip[13] = modl[12] * proj[ 1] + modl[13] * proj[ 5] + modl[14] * proj[ 9] + modl[15] * proj[13];
    clip[14] = modl[12] * proj[ 2] + modl[13] * proj[ 6] + modl[14] * proj[10] + modl[15] * proj[14];
    clip[15] = modl[12] * proj[ 3] + modl[13] * proj[ 7] + modl[14] * proj[11] + modl[15] * proj[15];

    // Now we actually want to get the sides of the frustum.  To do this we take
    // the clipping planes we received above and extract the sides from them.

    // This will extract the RIGHT side of the frustum
    m_Frustum[RIGHT][A] = clip[ 3] - clip[ 0];
    m_Frustum[RIGHT][B] = clip[ 7] - clip[ 4];
    m_Frustum[RIGHT][C] = clip[11] - clip[ 8];
    m_Frustum[RIGHT][D] = clip[15] - clip[12];

    // Now that we have a normal (A,B,C) and a distance (D) to the plane,
    // we want to normalize that normal and distance.

    // Normalize the RIGHT side
    NormalizePlane(m_Frustum, RIGHT);

    // This will extract the LEFT side of the frustum
    m_Frustum[LEFT][A] = clip[ 3] + clip[ 0];
    m_Frustum[LEFT][B] = clip[ 7] + clip[ 4];
    m_Frustum[LEFT][C] = clip[11] + clip[ 8];
    m_Frustum[LEFT][D] = clip[15] + clip[12];

    // Normalize the LEFT side
    NormalizePlane(m_Frustum, LEFT);

    // This will extract the BOTTOM side of the frustum
    m_Frustum[BOTTOM][A] = clip[ 3] + clip[ 1];
    m_Frustum[BOTTOM][B] = clip[ 7] + clip[ 5];
    m_Frustum[BOTTOM][C] = clip[11] + clip[ 9];
    m_Frustum[BOTTOM][D] = clip[15] + clip[13];

    // Normalize the BOTTOM side
    NormalizePlane(m_Frustum, BOTTOM);

    // This will extract the TOP side of the frustum
    m_Frustum[TOP][A] = clip[ 3] - clip[ 1];
    m_Frustum[TOP][B] = clip[ 7] - clip[ 5];
    m_Frustum[TOP][C] = clip[11] - clip[ 9];
    m_Frustum[TOP][D] = clip[15] - clip[13];

    // Normalize the TOP side
    NormalizePlane(m_Frustum, TOP);

    // This will extract the BACK side of the frustum
    m_Frustum[BACK][A] = clip[ 3] - clip[ 2];
    m_Frustum[BACK][B] = clip[ 7] - clip[ 6];
    m_Frustum[BACK][C] = clip[11] - clip[10];
    m_Frustum[BACK][D] = clip[15] - clip[14];

    // Normalize the BACK side
    NormalizePlane(m_Frustum, BACK);

    // This will extract the FRONT side of the frustum
    m_Frustum[FRONT][A] = clip[ 3] + clip[ 2];
    m_Frustum[FRONT][B] = clip[ 7] + clip[ 6];
    m_Frustum[FRONT][C] = clip[11] + clip[10];
    m_Frustum[FRONT][D] = clip[15] + clip[14];

    // Normalize the FRONT side
    NormalizePlane(m_Frustum, FRONT);
}

// The code below will allow us to make checks within the frustum.  For example,
// if we want to see if a point, a sphere, or a cube lies inside of the frustum.
// Because all of our planes point INWARDS (The normals are all pointing inside the frustum)
// we then can assume that if a point is in FRONT of all of the planes, it's inside.

///////////////////////////////// POINT IN FRUSTUM \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This determines if a point is inside of the frustum
/////
///////////////////////////////// POINT IN FRUSTUM \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

bool CFrustum::PointInFrustum( float x, float y, float z ) {
    // If you remember the plane equation (A*x + B*y + C*z + D = 0), then the rest
    // of this code should be quite obvious and easy to figure out yourself.
    // In case don't know the plane equation, it might be a good idea to look
    // at our Plane Collision tutorial at www.GameTutorials.com in OpenGL Tutorials.
    // I will briefly go over it here.  (A,B,C) is the (X,Y,Z) of the normal to the plane.
    // They are the same thing... but just called ABC because you don't want to say:
    // (x*x + y*y + z*z + d = 0).  That would be wrong, so they substitute them.
    // the (x, y, z) in the equation is the point that you are testing.  The D is
    // The distance the plane is from the origin.  The equation ends with "= 0" because
    // that is true when the point (x, y, z) is ON the plane.  When the point is NOT on
    // the plane, it is either a negative number (the point is behind the plane) or a
    // positive number (the point is in front of the plane).  We want to check if the point
    // is in front of the plane, so all we have to do is go through each point and make
    // sure the plane equation goes out to a positive number on each side of the frustum.
    // The result (be it positive or negative) is the distance the point is front the plane.

    // Go through all the sides of the frustum
    for(int i = 0; i < 6; i++ ) {
        // Calculate the plane equation and check if the point is behind a side of the frustum
        if(m_Frustum[i][A] * x + m_Frustum[i][B] * y + m_Frustum[i][C] * z + m_Frustum[i][D] <= 0) {
            // The point was behind a side, so it ISN'T in the frustum
            return false;
        }
    }

    // The point was inside of the frustum (In front of ALL the sides of the frustum)
    return true;
}


///////////////////////////////// SPHERE IN FRUSTUM \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This determines if a sphere is inside of our frustum by it's center and radius.
/////
///////////////////////////////// SPHERE IN FRUSTUM \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

bool CFrustum::SphereInFrustum( float x, float y, float z, float radius ) {
    // Now this function is almost identical to the PointInFrustum(), except we
    // now have to deal with a radius around the point.  The point is the center of
    // the radius.  So, the point might be outside of the frustum, but it doesn't
    // mean that the rest of the sphere is.  It could be half and half.  So instead of
    // checking if it's less than 0, we need to add on the radius to that.  Say the
    // equation produced -2, which means the center of the sphere is the distance of
    // 2 behind the plane.  Well, what if the radius was 5?  The sphere is still inside,
    // so we would say, if(-2 < -5) then we are outside.  In that case it's false,
    // so we are inside of the frustum, but a distance of 3.  This is reflected below.

    // Go through all the sides of the frustum
    for(int i = 0; i < 6; i++ ) {
        // If the center of the sphere is farther away from the plane than the radius
        if( m_Frustum[i][A] * x + m_Frustum[i][B] * y + m_Frustum[i][C] * z + m_Frustum[i][D] <= -radius ) {
            // The distance was greater than the radius so the sphere is outside of the frustum
            return false;
        }
    }

    // The sphere was inside of the frustum!
    return true;
}


///////////////////////////////// CUBE IN FRUSTUM \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This determines if a cube is in or around our frustum by it's center and 1/2 it's length
/////
///////////////////////////////// CUBE IN FRUSTUM \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

bool CFrustum::CubeInFrustum( float x, float y, float z, float size ) {
    // This test is a bit more work, but not too much more complicated.
    // Basically, what is going on is, that we are given the center of the cube,
    // and half the length.  Think of it like a radius.  Then we checking each point
    // in the cube and seeing if it is inside the frustum.  If a point is found in front
    // of a side, then we skip to the next side.  If we get to a plane that does NOT have
    // a point in front of it, then it will return false.

    // *Note* - This will sometimes say that a cube is inside the frustum when it isn't.
    // This happens when all the corners of the bounding box are not behind any one plane.
    // This is rare and shouldn't effect the overall rendering speed.

    for(int i = 0; i < 6; i++ ) {
        if(m_Frustum[i][A] * (x - size) + m_Frustum[i][B] * (y - size) + m_Frustum[i][C] * (z - size) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x + size) + m_Frustum[i][B] * (y - size) + m_Frustum[i][C] * (z - size) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x - size) + m_Frustum[i][B] * (y + size) + m_Frustum[i][C] * (z - size) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x + size) + m_Frustum[i][B] * (y + size) + m_Frustum[i][C] * (z - size) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x - size) + m_Frustum[i][B] * (y - size) + m_Frustum[i][C] * (z + size) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x + size) + m_Frustum[i][B] * (y - size) + m_Frustum[i][C] * (z + size) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x - size) + m_Frustum[i][B] * (y + size) + m_Frustum[i][C] * (z + size) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x + size) + m_Frustum[i][B] * (y + size) + m_Frustum[i][C] * (z + size) + m_Frustum[i][D] > 0)
            continue;

        // If we get here, it isn't in the frustum
        return false;
    }

    return true;
}

///////////////////////////////// BOX IN FRUSTUM \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This determines if a box (rect) is in or around our frustum
/////
///////////////////////////////// BOX IN FRUSTUM \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*


bool CFrustum::BoxInFrustum( float x, float y, float z, float width, float height, float length) {
    for(int i = 0; i < 6; i++ ) {
        if(m_Frustum[i][A] * (x - width) + m_Frustum[i][B] * (y - height) + m_Frustum[i][C] * (z - length) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x + width) + m_Frustum[i][B] * (y - height) + m_Frustum[i][C] * (z - length) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x - width) + m_Frustum[i][B] * (y + height) + m_Frustum[i][C] * (z - length) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x + width) + m_Frustum[i][B] * (y + height) + m_Frustum[i][C] * (z - length) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x - width) + m_Frustum[i][B] * (y - height) + m_Frustum[i][C] * (z + length) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x + width) + m_Frustum[i][B] * (y - height) + m_Frustum[i][C] * (z + length) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x - width) + m_Frustum[i][B] * (y + height) + m_Frustum[i][C] * (z + length) + m_Frustum[i][D] > 0)
            continue;
        if(m_Frustum[i][A] * (x + width) + m_Frustum[i][B] * (y + height) + m_Frustum[i][C] * (z + length) + m_Frustum[i][D] > 0)
            continue;
        // If we get here, it isn't in the frustum
        return false;
    }

    return true;
}

/////////////////////////////////////////////////////////////////////////////////
//
// * QUICK NOTES *
//
// WOZZERS!  That seemed like an incredible amount to look at, but if you break it
// down, it's not.  Frustum culling is a VERY useful thing when it comes to 3D.
// If you want a large world, there is no way you are going to send it down the
// 3D pipeline every frame and let OpenGL take care of it for you.  That would
// give you a 0.001 frame rate.  If you hit '+' and bring the sphere count up to
// 1000, then take off culling, you will see the HUGE difference it makes.
// Also, you wouldn't really be rendering 1000 spheres.  You would most likely
// use the sphere code for larger objects.  Let me explain.  Say you have a bunch
// of objects, well... all you need to do is give the objects a radius, and then
// test that radius against the frustum.  If that sphere is in the frustum, then you
// render that object.  Also, you won't be rendering a high poly sphere so it won't
// be so slow.  This goes for bounding box's too (Cubes).  If you don't want to
// do a cube, it is really easy to convert the code for rectangles.  Just pass in
// a width and height, instead of just a length.  Remember, it's HALF the length of
// the cube, not the full length.  So it would be half the width and height for a rect.
//
// This is a perfect starter for an octree tutorial.  Wrap you head around the concepts
// here and then see if you can apply this to making an octree.  Hopefully we will have
// a tutorial up and running for this subject soon.  Once you have frustum culling,
// the next step is getting space partitioning.  Either it being a BSP tree of an Octree.
//
// Let's go over a brief overview of the things we learned here:
//
// 1) First we need to abstract the frustum from OpenGL.  To do that we need the
//    projection and modelview matrix.  To get the projection matrix we use:
//
//			glGetFloatv( GL_PROJECTION_MATRIX, /* An Array of 16 floats */ );
//    Then, to get the modelview matrix we use:
//
//			glGetFloatv( GL_MODELVIEW_MATRIX, /* An Array of 16 floats */ );
//
//	  These 2 functions gives us an array of 16 floats (The matrix).
//
// 2) Next, we need to combine these 2 matrices.  We do that by matrix multiplication.
//
// 3) Now that we have the 2 matrixes combined, we can abstract the sides of the frustum.
//    This will give us the normal and the distance from the plane to the origin (ABC and D).
//
// 4) After abstracting a side, we want to normalize the plane data.  (A B C and D).
//
// 5) Now we have our frustum, and we can check points against it using the plane equation.
//    Once again, the plane equation (A*x + B*y + C*z + D = 0) says that if, point (X,Y,Z)
//    times the normal of the plane (A,B,C), plus the distance of the plane from origin,
//    will equal 0 if the point (X, Y, Z) lies on that plane.  If it is behind the plane
//    it will be a negative distance, if it's in front of the plane (the way the normal is facing)
//    it will be a positive number.
//
//
// If you need more help on the plane equation and why this works, download our
// Ray Plane Intersection Tutorial at www.GameTutorials.com.
//
// That's pretty much it with frustums.  There is a lot more we could talk about, but
// I don't want to complicate this tutorial more than I already have.
//
// I want to thank Mark Morley for his tutorial on frustum culling.  Most of everything I got
// here comes from his teaching.  If you want more in-depth, visit his tutorial at:
//
// http://www.markmorley.com/opengl/frustumculling.html
//
// Good luck!
//
//
// Ben Humphrey (DigiBen)
// Game Programmer
// DigiBen@GameTutorials.com
// Co-Web Host of www.GameTutorials.com
//
//

