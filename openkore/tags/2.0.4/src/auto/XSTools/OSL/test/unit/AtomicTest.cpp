/*
 *  OpenKore C++ Standard Library
 *  Copyright (C) 2006  VCL
 *
 *  Unit tests
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

#include "tut.h"
#include "../../Threading/Atomic.h"

/*
 * Test case for OSL::Atomic
 */
namespace tut {
	struct AtomicTest {
	};

	DEFINE_TEST_GROUP(AtomicTest);

	TEST_METHOD(1) {
		int i = 0;

		Atomic::increment(i);
		ensure(Atomic::decrement(i));
	}

	TEST_METHOD(2) {
		int i = 0;

		Atomic::increment(i);
		Atomic::increment(i);
		Atomic::increment(i);
		ensure(!Atomic::decrement(i));
		ensure(!Atomic::decrement(i));
		ensure(Atomic::decrement(i));
	}
}
