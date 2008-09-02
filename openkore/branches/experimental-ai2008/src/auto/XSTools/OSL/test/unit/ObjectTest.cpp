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
#include "../../Object.h"

// Test for OSL::Object
namespace tut {
	struct ObjectTest {
	public:
		int deleteCount;

		ObjectTest() {
			deleteCount = 0;
		}
	};

	DEFINE_TEST_GROUP(ObjectTest);

	/*
	 * A subclass of Object which increments ObjectTest::deleteCount
	 * whenever it is deleted.
	 */
	class TestInstance: public OSL::Object {
	private:
		ObjectTest *test;
	public:
		TestInstance(ObjectTest *test) {
			this->test = test;
		}

		~TestInstance() {
			test->deleteCount++;
		}
	};


	// Test simplest case of reference counting.
	TEST_METHOD(1) {
		Object *o = new TestInstance(this);
		ensure("Object is not marked as a stack object", !o->isStackObject());
		ensure_equals("Object is not deleted yet", deleteCount, 0);
		o->unref();
		ensure_equals("Object is deleted", deleteCount, 1);
	}

	// Test increasing reference count twice.
	TEST_METHOD(2) {
		Object *o = new TestInstance(this);
		ensure("Object is not marked as a stack object", !o->isStackObject());
		o->ref();
		o->unref();
		ensure_equals("Object is not deleted yet", deleteCount, 0);
		o->unref();
		ensure_equals("Object is deleted", deleteCount, 1);
	}

	// Test increasing reference count 3 times.
	TEST_METHOD(3) {
		Object *o = new TestInstance(this);
		ensure("Object is not marked as a stack object", !o->isStackObject());
		o->ref();
		o->ref();
		o->unref();
		o->unref();
		ensure_equals("Object is not deleted yet", deleteCount, 0);
		o->unref();
		ensure_equals("Object is deleted", deleteCount, 1);
	}

	// Test markAsStackObject() and isStackObject()
	TEST_METHOD(4) {
		TestInstance o(this);
		ensure("Object is not marked as a stack object", !o.isStackObject());
		o.markAsStackObject();
		ensure("Object is marked as a stack object", o.isStackObject());
		for (int i = 0; i < 10; i++) {
			o.unref();
			o.ref();
		}
		// If unref() tries to delete o then this will crash.
	}
}
