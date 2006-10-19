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

#ifndef _OSL_POINTER_H_
#define _OSL_POINTER_H_

#include "Exception.h"
#include "Threading/Atomic.h"

namespace OSL {

	/**
	 * Thrown when a NULL Pointer class is unable to dereference itself.
	 *
	 * @class PointerException OSL/Pointer.h
	 * @ingroup Base
	 */
	class PointerException: public Exception {
	public:
		PointerException(const char *msg = NULL, int code = 0);
	};

	template <class T> class Pointer;

	namespace _Intern {
		template <class T>
		class PointerSharedData {
		private:
			friend class Pointer<T>;

			int refcount;
			T *data;
		public:
			PointerSharedData() {
				refcount = 1;
				data = NULL;
			}
		};
	}

	/**
	 * Thread-safe shared smart pointer.
	 *
	 * Smart pointers allow you to create multiple references to shared
	 * data structures, and can perform automatic memory management.
	 * See <a href="http://www.google.com/search?q=C%2B%2B+smart+pointer">Google
	 * search results on C++ smart pointers</a> for more information and tutorials.
	 *
	 * Normal pointers have to be managed manually:
	 * @code
	 * string *some_function() {
	 *     string *foo = new string("hello world");
	 *     string *bar = foo;
	 *     delete foo;  // bar is now an invalid pointer!
	 *     return new string("hello world");
	 * }
	 *
	 * void some_function_2() {
	 *     some_function();  // Memory leak!
	 * }
	 * @endcode
	 *
	 * With smart pointers, the referenced data only deleted automatically
	 * when the last smart pointer is deleted:
	 * @code
	 * Pointer<string> some_function() {
	 *     Pointer<string> bar;
	 *     do {
	 *         Pointer<string> foo(string("hello world"));
	 *         bar = foo;
	 *     } while (0);
	 *     // foo is now deleted, but its string is not.
	 *     // bar is still a valid pointer.
	 *     return bar;
	 * }
	 *
	 * void some_function2() {
	 *     some_function();
	 *     // bar is now automatically deleted. No memory leak!
	 * }
	 * @endcode
	 *
	 *
	 * @section Usage
	 * Smart pointers behave just like normal pointers. Instead of <tt>Foo *</tt>
	 * you write <tt>Pointer<Foo></tt>.
	 *
	 * To create a smart pointer, use the following syntax:
	 * @code
	 * Pointer<Foo> bar(new Foo());
	 * @endcode
	 *
	 * The following pointer operations are all valid, as smart pointers behave like
	 * normal pointers:
	 * @code
	 * bar->hello();
	 * (*bar).hello();
	 * Foo *normal_pointer = bar;
	 * @endcode
	 *
	 * If you want to force a smart pointer to dereference its data, set it to NULL:
	 * @code
	 * Pointer<Foo> bar(new Foo());
	 * bar = NULL;   // The Foo instance is now deleted.
	 * @endcode
	 *
	 * If you try to dereference an empty smart pointer, it will throw PointerException:
	 * @code
	 * Pointer<Foo> empty;
	 * *empty; // PointerException thrown!
	 * @endcode
	 *
	 * On the other hand, the -> operator will return NULL if the smart pointer
	 * is empty:
	 * @code
	 * Pointer<Foo> empty;
	 * empty.operator->();   // NULL
	 * (void *) empty;       // NULL
	 * empty->test();        // Crash!
	 * @endcode
	 *
	 *
	 * @section Caveats
	 * Don't create two smart pointers to the same data. Newly instantiated
	 * smart pointers don't know about other smart pointers that reference
	 * the same data. You may only copy existing smart pointers.
	 *
	 * So the following will result in memory corruption:
	 * @code
	 * do {
	 *     Foo *bar = new Foo();
	 *     Pointer<Foo> pointer1 = bar;
	 *     do {
	 *         Pointer<Foo> pointer2 = bar;
	 *         // pointer2 doesn't know pointer1 references bar.
	 *     } while (0);
	 *     // At this point, pointer2 is deleted, and bar is too.
	 *     // pointer1 is now an invalid pointer.
	 *     // You should have written this instead: pointer2 = pointer1
	 * } while(0);
	 * // Memory corruption!
	 * @endcode
	 *
	 * @class Pointer OSL/Pointer.h
	 * @ingroup Base
	 */
	template <class T>
	class Pointer {
	private:
		int id;
		_Intern::PointerSharedData<T> *shared;

		void
		dereferenceCurrent() throw() {
			if (shared != NULL && Atomic::decrement(shared->refcount)) {
				delete shared->data;
				delete shared;
			}
		}

		void
		createReference(T *data = NULL) throw() {
			if (data != NULL) {
				shared = new _Intern::PointerSharedData<T>();
				shared->data = data;
			} else {
				shared = NULL;
			}
		}

		void
		createReference(const Pointer<T> &pointer) throw() {
			shared = pointer.shared;
			Atomic::increment(shared->refcount);
		}
	public:
		Pointer(T *data = NULL) throw() {
			createReference(data);
		}

		Pointer(const Pointer<T> &pointer) throw() {
			createReference(pointer);
		}

		~Pointer() throw() {
			dereferenceCurrent();
		}

		Pointer<T> &
		operator=(T *data) throw() {
			if (shared == NULL || data != shared->data) {
				dereferenceCurrent();
				createReference(data);
			}
			return *this;
		}

		Pointer<T> &
		operator=(const Pointer<T> &pointer) throw() {
			if (shared == NULL || pointer.shared->data != shared->data) {
				dereferenceCurrent();
				createReference(pointer);
			}
			return *this;
		}

		T& operator*() throw(PointerException) {
			if (shared != NULL && shared->data != NULL) {
				return *shared->data;
			} else {
				throw PointerException("Cannot dereference a NULL Pointer.");
			}
		}

		T* operator->() throw() {
			if (shared != NULL) {
				return shared->data;
			} else {
				return NULL;
			}
		}

		operator T * () throw() {
			if (shared != NULL) {
				return shared->data;
			} else {
				return NULL;
			}
		}

		operator T & () throw(PointerException) {
			if (shared != NULL) {
				return *shared->data;
			} else {
				throw PointerException("Cannot dereference a NULL Pointer.");
			}
		}
	};

}

#endif /* _OSL_POINTER_H_ */
