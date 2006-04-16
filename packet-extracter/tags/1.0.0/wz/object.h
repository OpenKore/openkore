/*
 *  Wz - library which fixes WxWidgets's stupidities and extends it
 *  Copyright (C) 2006  Hongli Lai
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

#ifndef _WZ_OBJECT_H_
#define _WZ_OBJECT_H_

// wxObject's reference counting documentation is vague, bah.

namespace Wz {

	/**
	 * An object class, which is the parent class of all classes
	 * in the Wz library. This object class implements reference
	 * counting abilities.
	 */
	class Object {
	private:
		unsigned int refcount;
	public:
		/**
		 * Construct a new Object.
		 *
		 * @ensure getRefCount() == 1
		 */
		Object();

		virtual ~Object();

		/**
		 * Returns the current reference count.
		 */
		unsigned int getRefCount();

		/**
		 * Increase the reference count by 1. You should call unref()
		 * when you no longer need to reference to this object anymore.
		 *
		 * This method is NOT thread-safe.
		 *
		 * @ensure getRefCount() == old.getRefCount() + 1
		 */
		void ref();

		/**
		 * Decrease the reference count by 1. When the reference count
		 * drops to 0, the object is deleted. You should only call this
		 * method if you have previously called ref() on this object.
		 *
		 * This method is NOT thread-safe.
		 */
		void unref();
	};

}

#endif /* _WZ_OBJECT_H_ */
