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

#ifndef _OSL_MUTEX_H_
#define _OSL_MUTEX_H_

#ifdef WIN32
	#include <winbase.h>
#else
	#include <pthread.h>
#endif

namespace OSL {

	/**
	 * A mutex (also known as critical section on Windows) object.
	 * This is a lock which can be used to ensure that no two
	 * threads can access the same resource simultaneously.
	 *
	 * @ingroup Threading
	 */
	class Mutex {
	private:
		#ifdef WIN32
			CRITICAL_SECTION cs;
		#else
			pthread_mutex_t mutex;
		#endif
	public:
		/**
		 * Create a new Mutex object. This mutex is not locked.
		 */
		Mutex() throw();
		~Mutex() throw();

		/**
		 * Lock this mutex. Do not lock a mutex twice from
		 * the same thread, or it'll cause a deadlock.
		 */
		void lock() throw();

		/**
		 * Try to lock this mutex.
		 *
		 * @return Whether this mutex was successfully locked.
		 *         If the mutex is already locked, then false is returned.
		 */
		bool tryLock() throw();

		/**
		 * Unlock this mutex.
		 */
		void unlock() throw();
	};

}

#endif /* _OSL_MUTEX_H_ */
