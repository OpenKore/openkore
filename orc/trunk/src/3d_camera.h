/*
 *  ORC - Open Ragnarok Client
 *  3d_camera.h - 3D camera class
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

#ifndef _3D_CAMERA_H
#define _3D_CAMERA_H

// This is our camera class
class CCamera {

public:

    // Our camera constructor
    CCamera();

    // These are are data access functions for our camera's private data
    CVector3 Position() {
        return m_vPosition;
    }
    CVector3 View()		{
        return m_vView;
    }
    CVector3 UpVector() {
        return m_vUpVector;
    }
    CVector3 Strafe()	{
        return m_vStrafe;
    }

    // This changes the position, view, and up vector of the camera.
    // This is primarily used for initialization
    void PositionCamera(float positionX, float positionY, float positionZ,
                        float viewX,     float viewY,     float viewZ,
                        float upVectorX, float upVectorY, float upVectorZ);

    // This rotates the camera's view around the position depending on the values passed in.
    void RotateView(float angle, float X, float Y, float Z);

    // This moves the camera's view by the mouse movements (First person view)
    void SetViewByMouse();

    // This rotates the camera around a point (I.E. your character).
    void RotateAroundPoint(CVector3 vCenter, float X, float Y, float Z);

    // This strafes the camera left or right depending on the speed (+/-)
    void StrafeCamera(float speed);

    void DollyCamera(float speed);

    void LiftCamera(float speed);

    // This will move the camera forward or backward depending on the speed
    void MoveCamera(float speed);

    // This checks for keyboard movement
    void CheckForMovement();

    // This updates the camera's view and other data (Should be called each frame)
    void Update();

    // This uses gluLookAt() to tell OpenGL where to look
    void Look();

private:

    // The camera's position
    CVector3 m_vPosition;

    // The camera's view
    CVector3 m_vView;

    // The camera's up vector
    CVector3 m_vUpVector;

    // The camera's strafe vector
    CVector3 m_vStrafe;

    CVector3 m_vDolly;
};

#endif // _3D_CAMERA_H

/////////////////////////////////////////////////////////////////////////////////
//
// * QUICK NOTES *
//
// Nothing was added to this file since the Camera5 tutorial on strafing.
//
//
// Ben Humphrey (DigiBen)
// Game Programmer
// DigiBen@GameTutorials.com
// Co-Web Host of www.GameTutorials.com
//
//
