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

#ifndef _OSL_MUTEX_LOCKER_H_
#define _OSL_MUTEX_LOCKER_H_

#include "Mutex.h"

namespace OSL {

	/**
	 * Automatic locking and unlocking a mutex.
	 *
	 * This class locks a mutex immediately, and unlocks it when
	 * it is deleted. This can be used to easy and exception-safe
	 * mutex locking.
	 *
	 * For example, consider the following:
	 * @code
	 * void foo()
	 * {
	 *     mutex->lock();
	 *     do_something();
	 *     mutex->unlock();
	 * }
	 * @endcode
	 * Suppose <tt>do_something()</tt> throws an exception. The mutex
	 * will never be unlocked. You can fix that with try..catch but that
	 * will result in more (unnecessary) code.
	 *
	 * By using MutexLocker, things will be greatly simplified:
	 * @code
	 * void foo()
	 * {
	 *     MutexLocker lock(mutex);
	 *     do_something();
	 * }
	 * @endcode
	 * MutexLocker immediately acquires a lock on the mutex. Whenever
	 * <tt>foo()</tt> exits, the MutexLocker is automatically deleted, and
	 * thus the mutex is automatically unlocked, even in the event of an
	 * unhandled exception.
	 *
	 * @class MutexLocker OSL/Threading/MutexLocker.h
	 * @ingroup Threading
	 */
	class MutexLocker {
	private:
		Mutex *mutex;
	public:
		/**
		 * Create a new MutexLocker object from the specified mutex.
		 */
		MutexLocker(Mutex &mutex);

		/**
		 * Create a new MutexLocker object from the specified mutex.
		 *
		 * @pre mutex != NULL
		 */
		MutexLocker(Mutex *mutex);
		~MutexLocker();
	};

}

#endif /* _OSL_MUTEX_LOCKER_H_ */
