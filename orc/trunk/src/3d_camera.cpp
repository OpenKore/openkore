//***********************************************************************//
//																		 //
//		- "Talk to me like I'm a 3 year old!" Programming Lessons -		 //
//                                                                       //
//		$Author:		DigiBen		digiben@gametutorials.com			 //
//																		 //
//		$Program:		Frustum Culling									 //
//																		 //
//		$Description:	Demonstrates checking if shapes are in view		 //
//																		 //
//		$Date:			8/28/01											 //
//																		 //
//***********************************************************************//


#include "3d_math.h"
#include "3d_camera.h"

#include <SDL\sdl.h>
#include <SDL\sdl_opengl.h>



// We increased the speed a bit from the Camera Strafing Tutorial
// This is how fast our camera moves
#define kSpeed	50.0f

// Our global float that stores the elapsed time between the current and last frame
float g_FrameInterval = 0.0f;


///////////////////////////////// CALCULATE FRAME RATE \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This function calculates the frame rate and time intervals between frames
/////
///////////////////////////////// CALCULATE FRAME RATE \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

void CalculateFrameRate() {
    static float framesPerSecond    = 0.0f;		// This will store our fps
    static float lastTime			= 0.0f;		// This will hold the time from the last frame
    static char strFrameRate[50] = {0};			// We will store the string here for the window title

    static float frameTime = 0.0f;				// This stores the last frame's time

    // Get the current time in seconds
    float currentTime = ::SDL_GetTicks() * 0.001f;

    // Here we store the elapsed time between the current and last frame,
    // then keep the current frame in our static variable for the next frame.
    g_FrameInterval = currentTime - frameTime;
    frameTime = currentTime;

    // Increase the frame counter
    ++framesPerSecond;

    // Now we want to subtract the current time by the last time that was stored
    // to see if the time elapsed has been over a second, which means we found our FPS.
    if( currentTime - lastTime > 1.0f ) {
        // Here we set the lastTime to the currentTime
        lastTime = currentTime;

        // Copy the frames per second into a string to display in the window title bar
        sprintf(strFrameRate, "Current Frames Per Second: %d", int(framesPerSecond));


/////// * /////////// * /////////// * NEW * /////// * /////////// * /////////// *

        // Commented out for this tutorialwwwwwwwwww

        // Set the window title bar to our string
        //SetWindowText(g_hWnd, strFrameRate);

/////// * /////////// * /////////// * NEW * /////// * /////////// * /////////// *

        // Reset the frames per second
        framesPerSecond = 0;
    }
}

///////////////////////////////// CCAMERA \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This is the class constructor
/////
///////////////////////////////// CCAMERA \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

CCamera::CCamera() {
    CVector3 vZero = CVector3(0.0, 0.0, 0.0);		// Init a vector to 0 0 0 for our position
    CVector3 vView = CVector3(0.0, 1.0, 1.0);		// Init a starting view vector (looking up and out the screen)
    CVector3 vUp   = CVector3(0.0, 1.0, 0.0);		// Init a standard up vector (Rarely ever changes)

    m_vPosition	= vZero;					// Init the position to zero
    m_vView		= vView;					// Init the view to a std starting view
    m_vUpVector	= vUp;						// Init the UpVector
}


///////////////////////////////// POSITION CAMERA \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This function sets the camera's position and view and up vector.
/////
///////////////////////////////// POSITION CAMERA \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

void CCamera::PositionCamera(float positionX, float positionY, float positionZ,
                             float viewX,     float viewY,     float viewZ,
                             float upVectorX, float upVectorY, float upVectorZ) {
    CVector3 vPosition	= CVector3(positionX, positionY, positionZ);
    CVector3 vView		= CVector3(viewX, viewY, viewZ);
    CVector3 vUpVector	= CVector3(upVectorX, upVectorY, upVectorZ);

    // The code above just makes it cleaner to set the variables.
    // Otherwise we would have to set each variable x y and z.

    m_vPosition = vPosition;					// Assign the position
    m_vView     = vView;						// Assign the view
    m_vUpVector = vUpVector;					// Assign the up vector
}


///////////////////////////////// SET VIEW BY MOUSE \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This allows us to look around using the mouse, like in most first person games.
/////
///////////////////////////////// SET VIEW BY MOUSE \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

void CCamera::SetViewByMouse() {
    //POINT mousePos;			// This is a window structure that holds an X and Y
    int mouseX, mouseY;
    Uint8 mouseState;

    int middleX = 800 >> 1;				// This is a binary shift to get half the width
    int middleY = 600 >> 1;				// This is a binary shift to get half the height
    float angleY = 0.0f;							// This is the direction for looking up or down
    float angleZ = 0.0f;							// This will be the value we need to rotate around the Y axis (Left and Right)
    static float currentRotX = 0.0f;

    // Get the mouse's current X,Y position
    // GetCursorPos(&mousePos);
    mouseState = ::SDL_GetMouseState(&mouseX, &mouseY);
//    SDL_GetRelativeMouseState(&mouseX, &mouseY);

    // If our cursor is still in the middle, we never moved... so don't update the screen
    if( (mouseX == middleX) && (mouseY == middleY) ) return;

    // Set the mouse position to the middle of our window
    // SetCursorPos(middleX, middleY);
    ::SDL_WarpMouse(middleX, middleY);

    // Get the direction the mouse moved in, but bring the number down to a reasonable amount
    angleY = (float)( (middleX - mouseX) ) / 500.0f;
    angleZ = (float)( (middleY - mouseY) ) / 500.0f;

    // Here we keep track of the current rotation (for up and down) so that
    // we can restrict the camera from doing a full 360 loop.
    currentRotX -= angleZ;

    // If the current rotation (in radians) is greater than 1.0, we want to cap it.
    if(currentRotX > 1.0f)
        currentRotX = 1.0f;
    // Check if the rotation is below -1.0, if so we want to make sure it doesn't continue
    else if(currentRotX < -1.0f)
        currentRotX = -1.0f;
    // Otherwise, we can rotate the view around our position
    else {
        // To find the axis we need to rotate around for up and down
        // movements, we need to get a perpendicular vector from the
        // camera's view vector and up vector.  This will be the axis.
        CVector3 vAxis = Cross(m_vView - m_vPosition, m_vUpVector);
        vAxis = Normalize(vAxis);

        // Rotate around our perpendicular axis and along the y-axis
        RotateView(angleZ, vAxis.x, vAxis.y, vAxis.z);
    }

    // Rotate around the y axis no matter what the currentRotX is
    RotateView(angleY, 0, 1, 0);
}


///////////////////////////////// ROTATE VIEW \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This rotates the view around the position using an axis-angle rotation
/////
///////////////////////////////// ROTATE VIEW \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

void CCamera::RotateView(float angle, float x, float y, float z) {
    CVector3 vNewView;

    // Get the view vector (The direction we are facing)
    CVector3 vView = m_vView - m_vPosition;

    // Calculate the sine and cosine of the angle once
    float cosTheta = (float)cos(angle);
    float sinTheta = (float)sin(angle);

    // Find the new x position for the new rotated point
    vNewView.x  = (cosTheta + (1 - cosTheta) * x * x)		* vView.x;
    vNewView.x += ((1 - cosTheta) * x * y - z * sinTheta)	* vView.y;
    vNewView.x += ((1 - cosTheta) * x * z + y * sinTheta)	* vView.z;

    // Find the new y position for the new rotated point
    vNewView.y  = ((1 - cosTheta) * x * y + z * sinTheta)	* vView.x;
    vNewView.y += (cosTheta + (1 - cosTheta) * y * y)		* vView.y;
    vNewView.y += ((1 - cosTheta) * y * z - x * sinTheta)	* vView.z;

    // Find the new z position for the new rotated point
    vNewView.z  = ((1 - cosTheta) * x * z - y * sinTheta)	* vView.x;
    vNewView.z += ((1 - cosTheta) * y * z + x * sinTheta)	* vView.y;
    vNewView.z += (cosTheta + (1 - cosTheta) * z * z)		* vView.z;

    // Now we just add the newly rotated vector to our position to set
    // our new rotated view of our camera.
    m_vView = m_vPosition + vNewView;
}


///////////////////////////////// STRAFE CAMERA \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This strafes the camera left and right depending on the speed (-/+)
/////
///////////////////////////////// STRAFE CAMERA \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

void CCamera::StrafeCamera(float speed) {
    // Add the strafe vector to our position
    m_vPosition.x += m_vStrafe.x * speed;
    m_vPosition.z += m_vStrafe.z * speed;

    // Add the strafe vector to our view
    m_vView.x += m_vStrafe.x * speed;
    m_vView.z += m_vStrafe.z * speed;
}


void CCamera::DollyCamera(float speed) {
    m_vPosition.x += m_vDolly.x * speed;
    m_vPosition.z += m_vDolly.z * speed;

    m_vView.x += m_vDolly.x * speed;
    m_vView.z += m_vDolly.z * speed;
}


void CCamera::LiftCamera(float speed) {
    m_vPosition.y += 1 * speed;
    m_vView.y += 1 * speed;
}

///////////////////////////////// MOVE CAMERA \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This will move the camera forward or backward depending on the speed
/////
///////////////////////////////// MOVE CAMERA \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

void CCamera::MoveCamera(float speed) {
    // Get the current view vector (the direction we are looking)
    CVector3 vVector = m_vView - m_vPosition;
    vVector = Normalize(vVector);

    m_vPosition.x += vVector.x * speed;		// Add our acceleration to our position's X
    m_vPosition.y += vVector.y * speed;		// Add our acceleration to our position's Y
    m_vPosition.z += vVector.z * speed;		// Add our acceleration to our position's Z
    m_vView.x += vVector.x * speed;			// Add our acceleration to our view's X
    m_vView.y += vVector.y * speed;			// Add our acceleration to our view's Y
    m_vView.z += vVector.z * speed;			// Add our acceleration to our view's Z
}


//////////////////////////// CHECK FOR MOVEMENT \\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This function handles the input faster than in the WinProc()
/////
//////////////////////////// CHECK FOR MOVEMENT \\\\\\\\\\\\\\\\\\\\\\\\\\\\*

bool IsKeyPressed(int keysym) {
    Uint8 *keystate = ::SDL_GetKeyState(NULL);
    if ( keystate[keysym] ) return true;
    else return false;
}
bool IsKeyPressed(SDLMod mod) {
    SDLMod modstate = ::SDL_GetModState();
    if ( modstate & mod ) return true;
    else return false;
}

void CCamera::CheckForMovement() {
    // Once we have the frame interval, we find the current speed
    float speed = kSpeed * g_FrameInterval;

    // Check if we hit the Up arrow or the 'w' key
    if(!(IsKeyPressed(KMOD_SHIFT)) && (IsKeyPressed(SDLK_UP) || IsKeyPressed(SDLK_w))) {
        // Move our camera forward by a positive SPEED
        MoveCamera(speed);
    }

    // Check if we hit the Down arrow or the 's' key
    if(!(IsKeyPressed(KMOD_SHIFT)) && (IsKeyPressed(SDLK_DOWN) || IsKeyPressed(SDLK_s))) {
        // Move our camera backward by a negative SPEED
        MoveCamera(-speed);
    }

    // Check if we hit the Left arrow or the 'a' key
    if(IsKeyPressed(SDLK_LEFT) || IsKeyPressed(SDLK_a)) {
        // Strafe the camera left
        StrafeCamera(-speed);
    }

    // Check if we hit the Right arrow or the 'd' key
    if(IsKeyPressed(SDLK_RIGHT) || IsKeyPressed(SDLK_d)) {
        // Strafe the camera right
        StrafeCamera(speed);
    }

    if(IsKeyPressed(KMOD_SHIFT) && IsKeyPressed(SDLK_w)) {
        DollyCamera(-speed);
    }

    if(IsKeyPressed(KMOD_SHIFT) && IsKeyPressed(SDLK_s)) {
        DollyCamera(speed);
    }

    if(IsKeyPressed(KMOD_CTRL) && IsKeyPressed(SDLK_w)) {
        LiftCamera(speed);
    }

    if(IsKeyPressed(KMOD_CTRL) && IsKeyPressed(SDLK_s)) {
        LiftCamera(-speed);
    }


}


///////////////////////////////// UPDATE \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This updates the camera's view and strafe vector
/////
///////////////////////////////// UPDATE \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

void CCamera::Update() {
    // Initialize a variable for the cross product result
    CVector3 vCross = Cross(m_vView - m_vPosition, m_vUpVector);

    // Normalize the strafe vector
    m_vStrafe = Normalize(vCross);

    vCross = Cross(m_vStrafe, m_vUpVector);
    m_vDolly = Normalize(vCross);

    // Move the camera's view by the mouse
    SetViewByMouse();


/////// * /////////// * /////////// * NEW * /////// * /////////// * /////////// *

    // We commented this line out so the camera can't move around
    // in this tutorial.

    // This checks to see if the keyboard was pressed
    CheckForMovement();

/////// * /////////// * /////////// * NEW * /////// * /////////// * /////////// *


    // Calculate our frame rate and set our frame interval for time-based movement
    CalculateFrameRate();
}


///////////////////////////////// LOOK \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*
/////
/////	This updates the camera according to the
/////
///////////////////////////////// LOOK \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*

void CCamera::Look() {
    // Give openGL our camera position, then camera view, then camera up vector
    gluLookAt(m_vPosition.x, m_vPosition.y, m_vPosition.z,
              m_vView.x,	 m_vView.y,     m_vView.z,
              m_vUpVector.x, m_vUpVector.y, m_vUpVector.z);
}


/////////////////////////////////////////////////////////////////////////////////
//
// * QUICK NOTES *
//
// Nothing was changed for the camera code in this tutorial except that
// we commented out the line that checks for keyboard movement in Update().
// We also commented out the SetWindowText() function in CalculateFrameRate().
//
//
// Ben Humphrey (DigiBen)
// Game Programmer
// DigiBen@GameTutorials.com
// Co-Web Host of www.GameTutorials.com
//
//
