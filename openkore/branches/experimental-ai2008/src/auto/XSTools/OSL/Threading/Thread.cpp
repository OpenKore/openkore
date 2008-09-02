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

#include "Thread.h"

#ifdef WIN32
	#define WIN32_LEAN_AND_MEAN
	#include <windows.h>
#else
	#include <pthread.h>
#endif

namespace OSL {

	ThreadException::ThreadException(const char *msg, int code)
		: Exception(msg, code)
	{
	}

	namespace {
		/**
		* An interface which implements an operating-specific thread.
		*/
		class ThreadImplementation: public Object {
		public:
			virtual ~ThreadImplementation() {}
	
			/**
			* Start a new thread which runs <tt>runnable</tt>.
			* This function may only be called once.
			*
			* If the thread was successfully started, then the reference count
			* will be incremented by 1.
			*
			* @param detached  Whether to start the thread in detached mode.
			* @param runnableShouldBeFreed   Whether <tt>runnable</tt> should be freed
			*                  after the thread has exited, but only if <tt>detached</tt>
			*                  is set to true.
			* @require runnable != NULL
			* @throws ThreadException  If the thread cannot be started.
			*/
			virtual void start(Runnable *runnable, bool detached,
					bool runnableShouldBeFreed) throw(ThreadException) = 0;
	
			/**
			* Join this thread. This function may only be called once.
			*
			* @require  start() has been called before.
			*/
			virtual void join() = 0;
		};

		#ifdef WIN32
			#include "Win32/Thread.cpp"
		#else
			#include "Unix/Thread.cpp"
		#endif
	}


	Thread::Thread(bool detached) {
		runnable = NULL;
		init(detached);
	}

	Thread::Thread(Runnable *runnable, bool detached) {
		this->runnable = runnable;
		init(detached);
	}

	Thread::~Thread() {
		if (runnable != NULL && !detached) {
			delete runnable;
		}
		static_cast<ThreadImplementation *>(impl)->unref();
	}

	void
	Thread::init(bool detached) {
		this->detached = detached;
		#ifdef WIN32
			impl = new Win32Thread();
		#else
			impl = new PosixThread();
		#endif
	}

	void
	Thread::start() throw(ThreadException) {
		if (runnable != NULL) {
			static_cast<ThreadImplementation *>(impl)->start(runnable, detached, true);
		} else {
			static_cast<ThreadImplementation *>(impl)->start(this, detached, false);
		}
	}

	void
	Thread::interrupt() {
	}

	void
	Thread::join() {
		static_cast<ThreadImplementation *>(impl)->join();
	}

	void
	Thread::run() {
		// Default implementation does nothing.
	}

}
