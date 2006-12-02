/*
 *  CSDL - Wrapper classes for the Simple Direct Media Layer (SDL) and OpenGL
 *  csdl_audio.cpp - CSDL_Chunk and CSDL_Music
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

#include "csdl_audio.h"

/*
    CSDL_Chunk - Sound Sample
*/
CSDL_Chunk::CSDL_Chunk() {}

CSDL_Chunk::CSDL_Chunk(const char* filename) {
    // load filename in to sample
    sample = ::Mix_LoadWAV(filename);
    if(!sample) {
        printf("Mix_LoadWAV: %s\n", ::Mix_GetError());
        return;
    }
}

CSDL_Chunk::~CSDL_Chunk() {
    ::Mix_FreeChunk(sample);
}

void CSDL_Chunk::Play() {
    // play sample on first free unreserved channel
    if(::Mix_PlayChannel(-1, sample, 0) == -1) {
        printf("Mix_PlayChannel: %s\n",::Mix_GetError());
        // may be critical error, or maybe just no channels were free.
        // you could allocated another channel in that case...
    }
}

void CSDL_Chunk::Stop() {
    ::Mix_HaltChannel(-1);
}



/*
    CSDL_Music - Should be a Singleton !?
*/


CSDL_Music::CSDL_Music(const char* filename) {
    music = NULL;
    if(!LoadMUS(filename)) {
        return;
    }
} // constructor

CSDL_Music::CSDL_Music(SDL_RWops* rw) {
    music = NULL;
    FreeMUS(); // free previously loaded data
    // load filename to play as music
    music = ::Mix_LoadMUS_RW(rw);
    if(music == NULL) {
        fprintf(stderr, "Mix_LoadMUS_RW(\"%p\"): %s\n", rw, Mix_GetError());
    }
    //    type = GetType();
    //    position = 0.0f;
    timestamp[0] = timestamp[1] = timestamp[2] = 0;
} // constructor


CSDL_Music::~CSDL_Music() {
    FreeMUS();
} // destructor


// Load
bool CSDL_Music::LoadMUS(const char* filename) {
    FreeMUS(); // free previously loaded data
    // load filename to play as music
    music = ::Mix_LoadMUS(filename);
    if(music == NULL) {
        fprintf(stderr, "Mix_LoadMUS(\"%s\"): %s\n", filename, ::Mix_GetError());
        return false;
    }
    //    type = GetType();
    //    position = 0.0f;
    timestamp[0] = timestamp[1] = timestamp[2] = 0;
    return true;
}


// Free
void CSDL_Music::FreeMUS() {
    if(music != NULL) {
        ::Mix_FreeMusic(music);
        music = NULL;
        //        type = MUS_NONE;
        //        position = 0.0f;
        timestamp[0] = timestamp[1] = timestamp[2] = 0;
    }
}


// Playing
bool CSDL_Music::Play(int loops) {
    if(::Mix_PlayMusic(music, loops) == -1) {
        fprintf(stderr, "Mix_PlayMusic: %s\n", ::Mix_GetError());
        return false;
    }
    timestamp[0] = ::SDL_GetTicks();
    timestamp[1] = timestamp[2] = 0;
    return true;
}
bool CSDL_Music::FadeIn(int loops, int ms) {
    if(::Mix_FadeInMusic(music, loops, ms) == -1) {
        fprintf(stderr, "Mix_FadeInMusic: %s\n", ::Mix_GetError());
        return false;
    }
    timestamp[0] = ::SDL_GetTicks();
    timestamp[1] = timestamp[2] = 0;
    return true;
}
bool CSDL_Music::FadeInPos(int loops, int ms, double position) {
    if(::Mix_FadeInMusicPos(music, loops, ms, position) == -1) {
        fprintf(stderr, "Mix_FadeInMusicPos: %s\n", ::Mix_GetError());
        return false;
    }
    timestamp[0] = ::SDL_GetTicks() - (int)(position * 1000);
    timestamp[1] = timestamp[2] = 0;
    return true;
}


// Settings
int CSDL_Music::SetVolume(int volume) {
    return ::Mix_VolumeMusic(volume);
}
void CSDL_Music::Pause() {
    if(!IsPaused())
        timestamp[1] = ::SDL_GetTicks();
    ::Mix_PauseMusic();
}
void CSDL_Music::Resume() {
    if(IsPaused())
        timestamp[2] += (::SDL_GetTicks() - timestamp[1]);
    ::Mix_ResumeMusic();
}
void CSDL_Music::Rewind() {
    // rewind music playback to the start
    ::Mix_RewindMusic();
    timestamp[0] = ::SDL_GetTicks();
    timestamp[1] = timestamp[2] = 0;
}
bool CSDL_Music::SetPosition(double position) {
    if(position <= 0 && position >= GetLength())
        position = 0;
    position /= 1000;
    Rewind();
    ::SDL_Delay(30); // it's a shame
    if(::Mix_SetMusicPosition(position) == -1) {
        fprintf(stderr, "Mix_SetMusicPosition: %s\n", ::Mix_GetError());
        return false;
    }
    timestamp[0] -= (Uint32) (position * 1000);
    return true;
}


// Stopping
void CSDL_Music::Halt() {
    ::Mix_HaltMusic();
    timestamp[0] = timestamp[1] = timestamp[2] = 0;
}
void CSDL_Music::FadeOut(int ms) {
    while(!::Mix_FadeOutMusic(ms) && IsPlaying()) {
        ::SDL_Delay(30);
    }
}


// Info
Mix_MusicType CSDL_Music::GetType() {
    return ::Mix_GetMusicType(music);
}
bool CSDL_Music::IsPlaying() {
    return (::Mix_PlayingMusic() && !::Mix_PausedMusic()) ? true : false;
}
bool CSDL_Music::IsPaused() {
    return (::Mix_PausedMusic() && ::Mix_PlayingMusic()) ? true : false;
}
Mix_Fading CSDL_Music::IsFading() {
    return ::Mix_FadingMusic();
}


// Additional
bool CSDL_Music::IsStopped() {
    return (!::Mix_PausedMusic() && !::Mix_PlayingMusic()) ? true : false;
}
int CSDL_Music::GetVolume(int volume) {
    return SetVolume(-1);
}
double CSDL_Music::GetPosition() {
    if(IsPlaying()) {
        return (::SDL_GetTicks() - timestamp[0]) - timestamp[2];
    }
    else if (IsPaused()) {
        return (timestamp[1] - timestamp[0]) - timestamp[2];
    }
    else
        return 0;
}
double CSDL_Music::GetLength() {
/*
    if(music != NULL && music->type == MUS_MP3) {
        ::SMPEG_getinfo(music->data.mp3, &info);
        return info.total_time * 1000;
    }
*/
	return 0;
}
