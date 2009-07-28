/*
 *  OpenKore C++ Standard Library
 *  Copyright (C) 2006  VCL
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 *  MA  02110-1301  USA
 */

#include "Mutex.h"

namespace OSL {

	Mutex::Mutex() throw() {
		#ifdef WIN32
			InitializeCriticalSection(&cs);
		#else
			pthread_mutex_init(&mutex, NULL);
		#endif
	}

	Mutex::~Mutex() throw() {
		#ifdef WIN32
			DeleteCriticalSection(&cs);
		#else
			pthread_mutex_destroy(&mutex);
		#endif
	}

	void
	Mutex::lock() throw() {
		#ifdef WIN32
			EnterCriticalSection(&cs);
		#else
			pthread_mutex_lock(&mutex);
		#endif
	}

	bool
	Mutex::tryLock() throw() {
		#ifdef WIN32
			return TryEnterCriticalSection(&cs);
		#else
			return pthread_mutex_trylock(&mutex) == 0;
		#endif
	}

	void
	Mutex::unlock() throw() {
		#ifdef WIN32
			LeaveCriticalSection(&cs);
		#else
			pthread_mutex_unlock(&mutex);
		#endif
	}
}
