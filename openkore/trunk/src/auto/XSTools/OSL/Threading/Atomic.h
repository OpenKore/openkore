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

#ifndef _OSL_ATOMIC_H_
#define _OSL_ATOMIC_H_

namespace OSL {

	/**
	 * Basic atomic integer operations.
	 *
	 * This class provides functions for atomically increasing and decreasing
	 * integers. On certain platforms, this is implemented as assembly, with
	 * fallback implementations on other platforms. Using these functions can
	 * sometimes avoid the use of relatively expensive mutexes.
	 *
	 * @warning
	 * Be careful with using these functions, they can cause all kinds of
	 * weird problems. Read <a href="http://en.wikipedia.org/wiki/Memory_barrier">the
	 * Wikipedia article about memory barriers</a> on why this is so. As such,
	 * these functions should only be used for simple reference counting,
	 * unless you really know what goes on behind the scenes.
	 *
	 * @class Atomic OSL/Threading/Atomic.h
	 * @ingroup Threading
	 */
	class Atomic {
	public:
		/**
		 * Atomically increase an integer by 1.
		 */
		static void increment(volatile int &i) throw();

		/**
		 * Atomically decrease an integer by 1.
		 *
		 * @return Whether the integer is 0 after the decrement
		 *         was performed.
		 */
		static bool decrement(volatile int &i) throw();
	};

}

#endif /* _OSL_ATOMIC_H_ */
