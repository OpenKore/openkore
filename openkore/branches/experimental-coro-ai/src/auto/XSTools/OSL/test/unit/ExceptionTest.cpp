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

#include <string.h>
#include "tut.h"
#include "../../Exception.h"

/*
 * Test case for OSL::Exception
 */
namespace tut {
	struct ExceptionTest {
	};

	DEFINE_TEST_GROUP(ExceptionTest);

	TEST_METHOD(1) {
		try {
			throw Exception("Foo");
		} catch(Exception &e) {
			ensure("Exception message is correct.",
				strcmp("Foo", e.getMessage()) == 0);
			ensure("getMessage() and what() return the same thing.",
				e.getMessage() == e.what());
		}
	}

	TEST_METHOD(2) {
		try {
			throw Exception(NULL, 123);
		} catch(Exception &e) {
			ensure_equals("Error code is correct.", e.getCode(), 123);
			ensure("Message is not NULL.", e.getMessage() != NULL);
			ensure("Message is not NULL (2).", e.what() != NULL);
		}
	}
}
