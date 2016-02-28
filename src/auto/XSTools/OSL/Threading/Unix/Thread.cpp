/*
 *  OpenKore C++ Standard Library
 *  Copyright (C) 2006,2007  VCL
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

// Do not compile this file independently, it's supposed to be automatically
// included by another source file.

class PosixThread: public ThreadImplementation {
private:
	pthread_t thread;
	Runnable *runnable;
	bool detached;
	bool runnableShouldBeFreed;

	static void *
	entry(void *arg) {
		PosixThread *self = (PosixThread *) arg;
		self->runnable->run();
		if (self->detached && self->runnableShouldBeFreed) {
			delete self->runnable;
		}
		self->unref();
		return NULL;
	}
public:
	virtual void
	start(Runnable *runnable, bool detached, bool runnableShouldBeFreed) throw(ThreadException) {
		this->runnable = runnable;
		this->detached = detached;
		this->runnableShouldBeFreed = runnableShouldBeFreed;
		if (detached) {
			pthread_attr_t attr;

			if (pthread_attr_init(&attr) != 0) {
				throw ThreadException("Cannot initialize pthread attribute.");
			}
			if (pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED) != 0) {
				throw ThreadException("Cannot set pthread detach state.");
			}
			ref();
			if (pthread_create(&thread, &attr, entry, this) != 0) {
				unref();
				throw ThreadException("Cannot create a thread.");
			}
			pthread_attr_destroy(&attr);
		} else {
			ref();
			if (pthread_create(&thread, NULL, entry, this) != 0) {
				unref();
				throw ThreadException("Cannot create a thread.");
			}
		}
	}

	virtual void
	join() {
		pthread_join(thread, NULL);
	}
};
