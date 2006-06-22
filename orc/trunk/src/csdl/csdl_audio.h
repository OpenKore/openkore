/*
 *  CSDL - Wrapper classes for the Simple Direct Media Layer (SDL) and OpenGL
 *  csdl_audio.h - CSDL_Chunk and CSDL_Music
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

/*
    Wrapper classes for the SDL_Mixer library

    Created based on the SDL_mixer Documentation located at : http://jcatki.no-ip.org/SDL_mixer/
    TODO: Use the SMPEG Library directly to query MPEG (MP3) information
*/

#ifndef CSDL_AUDIO_H
#define CSDL_AUDIO_H

#include <SDL/SDL.h>

#define USE_RWOPS
#include <SDL/SDL_mixer.h>

//#include <SMPEG/smpeg.h>

/*
struct _Mix_Music {
	Mix_MusicType type;
	union {
        SMPEG *mp3;
	} data;
	Mix_Fading fading;
	int fade_step;
	int fade_steps;
	int error;
};
*/
// information about an SMPEG object */
//extern DECLSPEC void SMPEG_getinfo( SMPEG* mpeg, SMPEG_Info* info );

class CSDL_Chunk {
    public:
        Mix_Chunk *sample;

        CSDL_Chunk();
        CSDL_Chunk(const char* filename);
        ~CSDL_Chunk();

        void Play();
        void Stop();
};

class CSDL_Music {
    public:
        // Constructor & destructor
        CSDL_Music(SDL_RWops* rw);
        CSDL_Music(const char* filename);
        ~CSDL_Music();

        // Load
        bool LoadMUS(const char* filename);

        // Free
        void FreeMUS();

        // Playing
        bool Play(int loops);
        bool FadeIn(int loops, int ms);
        bool FadeInPos(int loops, int ms, double position);
        // Mix_HookMusic

        // Settings
        int SetVolume(int volume);
        void Pause();
        void Resume();
        void Rewind();
        bool SetPosition(double position);
        // Mix_SetMusicCMD

        // Stopping
        void Halt();
        void FadeOut(int ms);
        // Mix_HookMusicFinished

        // Info
        Mix_MusicType GetType();
        bool IsPlaying();
        bool IsPaused();
        Mix_Fading IsFading();
        // Mix_GetMusicHookData

        // Additional
        bool IsStopped();
        int GetVolume(int volume);
        double GetPosition();
        double GetLength();

//        SMPEG_Info info;
        Uint32 timestamp[3]; // needed for GetPosition()

//    protected:
        Mix_Music*      music;
//        Mix_MusicType   type;
//        double          position;
};

#endif // CSDL_AUDIO_H
