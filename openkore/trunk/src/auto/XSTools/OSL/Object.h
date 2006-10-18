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

/**
 * @defgroup Base Base
 * @defgroup Threading Threading
 * @defgroup IO Input/Output
 * @defgroup Net Networking
 */

#ifndef _OSL_OBJECT_H_
#define _OSL_OBJECT_H_

namespace OSL {

	/**
	 * An object class, which is the parent class of nearly all classes
	 * in the OpenKore Standard Library.
	 *
	 * This object class provides thread-safe reference counting abilities.
	 * Reference counting is very useful if two classes reference the same
	 * Object, but the Object should only be destroyed if both referer classes
	 * are destroyed. (But see also Pointer for an alternative approach, using
	 * smart pointers.)
	 *
	 * Reference counting example:
	 * @code
	 * class Foo {
	 * private:
	 *     Object *o;
	 * public:
	 *     Foo(Object *o) {
	 *         this->o = o;
	 *         // Increase the reference count since
	 *         // we're holding a reference to o.
	 *         o->ref();
	 *     }
	 *
	 *     ~Foo() {
	 *         o->unref();
	 *     }
	 * };
	 *
	 * void some_function() {
	 *     Object *o = new Object();
	 *     // o's reference count is now 1.
	 *
	 *     Foo *foo = new Foo(o);  // o's reference count is now 2.
	 *     Foo *bar = new Foo(o);  // o's reference count is now 3.
	 *
	 *     // We only want to pass o to the two Foo instances,
	 *     // we don't do anything else with o. So we lower o's
	 *     // reference count. It won't be deleted now because
	 *     // both Foo instances have increased o's reference
	 *     // count.
	 *     o->unref();
	 *     // o's reference count is now 2.
	 *
	 *     delete foo;   // o's reference count is now 1.
	 *     delete bar;   // o's reference count is now 0.
	 *     // now o is deleted.
	 * }
	 * @endcode
	 *
	 * @ingroup Base
	 */
	class Object {
	private:
		int refcount;
		bool m_isStackObject;
	public:
		/**
		 * Construct a new Object. This object will have a reference count of 1.
		 */
		Object() throw();

		virtual ~Object();

		/**
		 * Increase the reference count by 1. You should call unref()
		 * when you no longer need to reference to this object anymore.
		 *
		 * This method is thread-safe.
		 */
		void ref() throw();

		/**
		 * Decrease the reference count by 1. When the reference count
		 * drops to 0, the object is deleted (unless markAsStackObject()
		 * was called). You should only call this method if you have
		 * previously called ref() on this object.
		 *
		 * This method is thread-safe.
		 */
		void unref() throw();

		/**
		 * Indicate that this Object is allocated on the stack.
		 * This function will ensure that unref() will never attempt to free
		 * this object.
		 *
		 * @post isStackObject()
		 */
		void markAsStackObject() throw();

		/**
		 * Returns whether this Object is marked as a class that's allocated
		 * on the stack.
		 *
		 * This function cannot automatically detect whether the object is
		 * allocated on the stack. So this function returns true if and only
		 * if markAsStackObject() has been called. By default, this function
		 * returns false.
		 */
		bool isStackObject() throw();
	};

}

#endif /* _OSL_OBJECT_H_ */
