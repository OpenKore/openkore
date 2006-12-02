/*
 *  ORC - Open Ragnarok Client
 *  grf_interface.h - Wrapper class for libgrf
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

#ifndef GRF_INTERFACE_H
#define GRF_INTERFACE_H

#include <libgrf/grf.h>
#include <SDL.h> // for SDL_RWops

#include <string.h> // for strlen()
#include <ctype.h> // for tolower()

class CGRF_Interface {
public:
    CGRF_Interface( const char* filename ) : grf( NULL ), filepath( filename ) {
        if ( !Open( filename ) ) return;
    }

virtual ~CGRF_Interface() { }

    bool Open( const char* filename ) {
        grf = ::grf_open( filename, "rb", &error );

        if ( !grf ) {
            printf ( "Cannot open %s: error code %d\n", filename, error.type );
            printf ( "Error message: %s\n", ::grf_strerror ( error ) );
            return false;
        }

        return true;
    } // Open

    void Close() {
        if ( grf != NULL ) {
            ::grf_close( grf );
            grf = NULL;
        }
    } // Close

    void Reopen() {
        Close();
        Open( filepath );
    } // Reopen

    void* Get( char* filename, uint32_t* size ) {
        /*
            We need to make grfpath lowercase
            because some RSM files have uppercased
            texture names, but they are lowercase in the GRF
        */
        for ( unsigned int i = 0; i < strlen( filename ); i++ ) filename[ i ] = tolower( filename[ i ] );

        void *data = ::grf_get( grf, filename, size, &error );

        if ( !data ) {
            printf ( "Unable to extract %s. Error code: %d\n", filename, error.type );
            printf ( "Error message: %s\n", ::grf_strerror ( error ) );
            return NULL;
        }

        return data;
    } // Get

    void* GetRSW ( char* filename, uint32_t* size ) {
        char grfpath[ 256 ];
        sprintf( grfpath, "data\\%s", filename );
        void *data = ::grf_get( grf, grfpath, size, &error );

        if ( !data ) {
            printf ( "Unable to extract \"%s\". Error code: %d\n", filename, error.type );
            printf ( "Error message: %s\n", ::grf_strerror ( error ) );
            return NULL;
        }

        return data;
    } // GetRSW

    void* GetRSM ( char* filename, uint32_t* size ) {
        char grfpath[ 256 ];
        sprintf( grfpath, "data\\model\\%s", filename );
        void *data = ::grf_get( grf, grfpath, size, &error );

        if ( !data ) {
            printf ( "Unable to extract \"%s\". Error code: %d\n", filename, error.type );
            printf ( "Error message: %s\n", ::grf_strerror ( error ) );
            return NULL;
        }

        return data;
    } // GetRSM

    void* GetGND ( char* filename, uint32_t* size ) {
        char grfpath[ 256 ];
        sprintf( grfpath, "data\\%s", filename );
        void *data = ::grf_get( grf, grfpath, size, &error );

        if ( !data ) {
            printf ( "Unable to extract \"%s\". Error code: %d\n", filename, error.type );
            printf ( "Error message: %s\n", ::grf_strerror ( error ) );
            return NULL;
        }

        return data;
    } // GetGND

    SDL_RWops* GetTexture ( char* filename ) {
        char grfpath[ 256 ];
        sprintf( grfpath, "data\\texture\\%s", filename );
        return Get( grfpath );
    } // GetTexture


    SDL_RWops* Get( char* grfpath ) {
        uint32_t size;
        void *data = Get( grfpath, &size );
        SDL_RWops* rwops = ::SDL_RWFromMem( data, size );
        return rwops;
    } // Get

protected:
    Grf *grf;
    GrfError error;
    const char* filepath;
};

#endif // GRF_INTERFACE_H
