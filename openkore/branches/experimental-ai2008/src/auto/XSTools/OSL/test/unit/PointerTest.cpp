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
#include "../../Pointer.h"

/*
 * Test case for OSL::Pointer
 */
namespace tut {
	using namespace OSL;

	namespace {
		static int deleteCount;

		class Foo {
		public:
			~Foo() {
				deleteCount++;
			}

			void test() {
			}
		};

		class Bar: public Object, public Foo {
		};
	}

	struct PointerTest {
		PointerTest() {
			deleteCount = 0;
		}

		Pointer<Foo> createFoo() {
			return new Foo();
		}
	};

	DEFINE_TEST_GROUP(PointerTest);

	// Test whether smart pointer deletes referee.
	TEST_METHOD(1) {
		do {
			Pointer<Foo> p1(new Foo());
			ensure_equals(deleteCount, 0);
		} while (0);
		ensure_equals("Referee is deleted.", deleteCount, 1);
	}

	// Test whether only last smart pointer deletes referee.
	TEST_METHOD(2) {
		do {
			Pointer<Foo> p2;
			do {
				Pointer<Foo> p1(new Foo());
				ensure_equals("Referee is not deleted.", deleteCount, 0);
				p2 = p1;
			} while (0);
			ensure_equals("Referee is not deleted.", deleteCount, 0);
		} while (0);
		ensure_equals("Referee is deleted.", deleteCount, 1);
	}

	// Test setting smart pointer to NULL.
	TEST_METHOD(3) {
		Pointer<Foo> p1(new Foo());
		p1 = NULL;
		ensure_equals("Referee is deleted.", deleteCount, 1);
		ensure("Empty smart pointer refers to NULL (1).", p1.operator->() == NULL);
		ensure("Empty smart pointer refers to NULL (2).", (Foo *) p1 == NULL);
		ensure("Empty smart pointer refers to NULL (3).", (void *) p1 == NULL);
	}

	// Test setting smart pointer to NULL when there are multiple smart pointers.
	TEST_METHOD(4) {
		Pointer<Foo> p1(new Foo());
		Pointer<Foo> p2 = p1;
		p1 = NULL;
		ensure("Empty smart pointer 1 refers to NULL.", p1.operator->() == NULL);
		ensure("Empty smart pointer 1 refers to NULL (2).", (Foo *) p1 == NULL);
		ensure_equals("Referee is not deleted.", deleteCount, 0);
		p2 = NULL;
		ensure("Empty smart pointer 2 refers to NULL.", p2.operator->() == NULL);
		ensure("Empty smart pointer 2 refers to NULL (2).", (Foo *) p2 == NULL);
		ensure_equals("Referee is deleted.", deleteCount, 1);
		p2 = NULL;
	}

	// Test dereferencing non-empty smart pointers.
	TEST_METHOD(5) {
		Foo *foo = new Foo();
		Pointer<Foo> p1(foo);
		p1->test();           // Should not crash if it works.
		(*p1).test();         // Ditto.
		((Foo *) p1)->test();  // Ditto.
		((Foo &) p1).test();  // Ditto.
		ensure("Referee is correct.", p1 == foo);
	}

	// Test dereferencing empty smart pointers.
	TEST_METHOD(6) {
		Pointer<Foo> p1;
		bool caught;

		ensure("Newly created smart pointer refers to NULL.", p1.operator->() == NULL);
		try {
			*p1;
			caught = false;
		} catch(PointerException &) {
			caught = true;
		}
		ensure("Dereferencing NULL smart pointer raises exception.", caught);

		p1 = NULL;
		ensure("Empty smart pointer refers to NULL.", (void *) p1 == NULL);
		try {
			Foo &foo = (Foo &) p1;
			foo.test();
			caught = false;
		} catch(PointerException &) {
			caught = true;
		}
		ensure("Dereferencing NULL smart pointer raises exception.", caught);
	}

	// Test setting empty smart pointer to NULL.
	TEST_METHOD(7) {
		Pointer<Foo> p1;

		p1 = NULL;
		ensure("Newly created smart pointer refers to NULL.", p1.operator->() == NULL);
	}

	// Test reassigning existing pointer.
	TEST_METHOD(8) {
		Pointer<Foo> p1 = createFoo();
		Pointer<Foo> p2(createFoo());
		ensure_equals("Referee 2 is not deleted.", deleteCount, 0);
		p2 = p1;
		ensure_equals("Referee 2 is deleted.", deleteCount, 1);
		p1 = NULL;
		ensure_equals("Referee 1 is not deleted.", deleteCount, 1);
		p2 = NULL;
		ensure_equals("Referee 1 is deleted.", deleteCount, 2);
	}

	// Test other operators.
	TEST_METHOD(9) {
		Pointer<Foo> p1;

		ensure("Evaluate as boolean.", !p1);
		ensure("Compare with NULL.", p1 == NULL);
		ensure("Negative compare with NULL.", !(p1 != NULL));
	}

	// Test createForObject()
	TEST_METHOD(10) {
		Bar *o = new Bar();
		do {
			Pointer<Bar> p1 = Pointer<Bar>::createForObject(o);
		} while (0);
		ensure_equals(deleteCount, 0);
		o->unref();
		ensure_equals(deleteCount, 1);
	}

	// Test assignment in combination with Object smart pointers.
	TEST_METHOD(11) {
		Object *o = new Bar();
		Pointer<Object> p1 = Pointer<Object>::createForObject(o);
		Pointer<Object> p2 = p1;
		// o now has reference count of 3
		p1 = NULL;
		p2 = NULL;
		// o now has reference count of 1
		ensure_equals(deleteCount, 0);

		Pointer<Object> p3;
		p3 = o;
		p3 = NULL;
		// p3 doesn't know it's assigned an Object,
		// so it will delete o.
		ensure_equals(deleteCount, 1);
	}
}
