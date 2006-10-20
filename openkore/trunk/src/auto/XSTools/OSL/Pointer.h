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

#include <typeinfo>
#include <stdio.h>
#include "Object.h"
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
		/**
		 * Class which contains metadata about a referee, such as
		 * the reference count.
		 */
		template <class T>
		class PointerSharedData {
		private:
			friend class Pointer<T>;

			/**
			 * The reference count.
			 * @invariant refcount >= 0
			 */
			int refcount;

			/** Whether referee is an OSL::Object */
			bool isObject;

			/** The referee. */
			T *data;
		public:
			PointerSharedData() {
				refcount = 1;
				isObject = false;
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
	 * @warning
	 * Do NOT create an empty smart pointer by passing an empty parameter list to its
	 * constructor! The following will not work:
	 * @code
	 * Pointer<Foo> p();
	 * @endcode
	 * while the following will:
	 * @code
	 * Pointer<Foo> p;
	 * @endcode
	 *
	 *
	 * @section object Special support for Object reference counting
	 * Since Object provides manual reference counting support, Pointer provides
	 * a way to automatically make use of that. Use createForObject() to create
	 * a smart pointer to an Object. See createForObject() for more information,
	 * examples and caveats.
	 *
	 *
	 * @anchor Pointer-Caveats
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
	 * The only exception is when you use smart pointers in combination with
	 * Object reference counting. See createForObject() for more information.
	 *
	 * @class Pointer OSL/Pointer.h
	 * @ingroup Base
	 */
	template <class T>
	class Pointer {
	private:
		_Intern::PointerSharedData<T> *shared;

		Pointer(T *data, bool isObject) throw() {
			createReference(data, isObject);
		}

		void
		dereferenceCurrent() throw() {
			if (shared != NULL && Atomic::decrement(shared->refcount)) {
				if (shared->isObject) {
					reinterpret_cast<Object *>(shared->data)->unref();
				} else {
					delete shared->data;
				}
				delete shared;
			}
		}

		void
		createReference(T *data, bool isObject) throw() {
			if (data != NULL) {
				shared = new _Intern::PointerSharedData<T>();
				shared->isObject = isObject;
				if (isObject) {
					reinterpret_cast<Object *>(data)->ref();
				}
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
			createReference(data, false);
		}

		/**
		 * Creates a smart pointer for the given Object. Unlike a normal
		 * smart pointer, smart pointers created using this method use
		 * the Object's own reference counting support.
		 *
		 * Each instance of a smart pointer created by this function will
		 * increment the Obejct's reference count by 1, and will decrement
		 * it by 1 when the smart pointer is deleted. This also means that
		 * if the last smart pointer to this Object is deleted, the Object
		 * won't be deleted - you have to unreference it one more time.
		 *
		 * This is best illustrated by an example. Normal smart pointers
		 * work like this:
		 * @code
		 * Object *foo = new Object();
		 * foo->ref();
		 * do {
		 *     Pointer<Object> p(foo);
		 * } while (0);
		 * // foo is now deleted. The ref() call didn't prevent it from
		 * // being deleted since the smart pointer calls 'delete foo'
		 * @endcode
		 *
		 * A smart pointer created with this method works like this:
		 * @code
		 * Object *foo = new Object();
		 * // foo has a reference count of 1.
		 * do {
		 *     Pointer<Object> p = Pointer<Object>::createForObject(foo);
		 *     // foo now has a reference count of 2.
		 * } while (0);
		 * // p is deleted, so foo now has a reference count of 1.
		 * // We unreference it 1 more time to really delete it:
		 * foo->unref();
		 * @endcode
		 *
		 * Thus, using this method also gives you the advantage of being able
		 * to create multiple Pointer instances for Object objects without
		 * problems (as documented by the @ref Pointer-Caveats "Caveats"
		 * section).
		 *
		 * @section Caveats
		 * There is only one caveat. The = operator doesn't know whether it's
		 * been assigned an Object (due to limitations in C++).
		 * For example:
		 * @code
		 * Object *foo = new Object();
		 * do {
		 *     Pointer<Object> p;
		 *     p = foo; // <----------
		 * } while (0);
		 * // p doesn't know that foo is an Object. So it won't increase
		 * // p's reference count. Therefore, foo is now deleted.
		 * @endcode
		 */
		static Pointer<T>
		createForObject(Object *data) throw() {
			return Pointer<T>(static_cast<T *>(data), true);
		}

		Pointer(const Pointer<T> &pointer) throw() {
			createReference(pointer);
		}

		virtual ~Pointer() throw() {
			dereferenceCurrent();
		}

		Pointer<T> &
		operator=(T *data) throw() {
			if (shared == NULL || data != shared->data) {
				dereferenceCurrent();
				createReference(data, false);
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
