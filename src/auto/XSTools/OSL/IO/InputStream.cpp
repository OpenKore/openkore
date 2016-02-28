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

#include "InputStream.h"
#include "../Threading/MutexLocker.h"

namespace OSL {

	namespace {

		/**
		 * @internal
		 * A thread-safe wrapper class around an InputStream,
		 * used to implement InputStream::createThreadSafe()
		 */
		class ThreadSafeInputStream: public InputStream {
		private:
			mutable Mutex mutex;
			InputStream *wrapped;
		public:
			ThreadSafeInputStream(InputStream *wrapped) {
				this->wrapped = wrapped;
				wrapped->ref();
			}

			~ThreadSafeInputStream() {
				wrapped->unref();
			}

			virtual void
			close() {
				MutexLocker lock(mutex);
				wrapped->close();
			}

			virtual bool
			eof() const throw(IOException) {
				MutexLocker lock(mutex);
				return wrapped->eof();
			}

			virtual int
			read(char *buffer, unsigned int size) throw(IOException) {
				MutexLocker lock(mutex);
				return wrapped->read(buffer, size);
			}
		};

	}

	InputStream *
	InputStream::createThreadSafe() throw() {
		return new ThreadSafeInputStream(this);
	}

}
