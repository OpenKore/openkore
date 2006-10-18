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

#include "Atomic.h"

#if defined(__GNUC__) && (defined(__i386__) || defined(__x86_64__))
	#define GCC_X86_32_OR_64
#elif defined(WIN32) && defined(_M_IX86)
	#define WIN32_X86
#endif

#if !defined(GCC_X86_32_OR_64) && !defined(WIN32_X86)
	#include "Mutex.h"
	static Mutex lock;
#endif

namespace OSL {

	void
	Atomic::increment(volatile int &i) throw() {
		#if defined(GCC_X86_32_OR_64)
			__asm__ __volatile__(
				"lock;"
				"addl %1,%0"
				: "=m" (i)
				: "ir" (1), "m" (i));
		#elif defined(WIN32_X86)
			InterlockedExchangeAdd(i, 1);
		#else
			lock->lock();
			i++;
			lock->unlock();
		#endif
	}

	bool
	Atomic::decrement(volatile int &i) throw() {
		#if defined(GCC_X86_32_OR_64)
			int result;
			__asm__ __volatile__ (
				"lock;"
				"xaddl %0,%1"
				: "=r" (result), "=m" (i)
				: "0" (-1), "m" (i));
			return result == 1;
		#elif defined(WIN32_X86)
			return InterlockedExchangeAdd(i, -1) == 1;
		#else
			bool result;
			lock->lock();
			i--;
			result = i == 0;
			lock->unlock();
			return result;
		#endif
	}

}
