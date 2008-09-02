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

#ifndef _OSL_THREAD_H_
#define _OSL_THREAD_H_

#include "../Object.h"
#include "../Exception.h"
#include "Runnable.h"

namespace OSL {

	/**
	 * Thrown when unable to start a Thread.
	 *
	 * @class ThreadException OSL/Threading/Thread.h
	 * @ingroup Threading
	 */
	class ThreadException: public Exception {
	public:
		ThreadException(const char *msg = NULL, int code = 0);
	};

	/**
	 * A thread object.
	 *
	 * @class Thread OSL/Threading/Thread.h
	 * @ingroup Threading
	 */
	class Thread: public Runnable {
	private:
		Runnable *runnable;
		bool detached;
		void *impl;

		void init(bool detached);
	public:
		/**
		 * Create a new thread. The run() function of this Thread object will be run in the thread.
		 * See the Thread(Runnable *, bool) for general information.
		 *
		 * The thread is not actually started until you call start().
		 *
		 * @param detached  Whether this thread is created in detached mode.
		 */
		Thread(bool detached = false);

		/**
		 * Create a new thread.
		 *
		 * The <tt>runnable</tt> parameter is a Runnable object which contains the
		 * function to be executed in the thread. If <tt>runnable</tt> is NULL, then the
		 * <tt>run()</tt> function of this Thread object is run in the thread instead.
		 *
		 * If <tt>detached</tt> is set to true, the thread will be created in detached mode.
		 * Threads in non-detached mode must be <em>joined</em> later in the program (by calling
		 * <tt>thread->join()</tt> ). Threads in detached mode are "fire-and-forget", which do
		 * not have to be joined.
		 *
		 * In non-detached mode, <tt>runnable</tt> is freed when you destroy this Thread object.
		 * In detached <tt>runnable</tt> is freed when the thread terminates.
		 *
		 * The thread is not actually started until you call start().
		 *
		 * @param runnable  A Runnable object, which contains the function to be executed
		 *                  in the thread. This may also be NULL.
		 * @param detached  Whether this thread is created in detached mode.
		 */
		Thread(Runnable *runnable, bool detached = false);
		virtual ~Thread();

		/**
		 * Start this thread.
		 *
		 * @throws  ThreadException  If the thread cannot be started.
		 * @warning You may only call this function once.
		 */
		void start() throw(ThreadException);

		void interrupt();

		/**
		 * Join this thread. Wait until the thread has finished running, then free its resources.
		 * This method does not destroy this Thread object, so you still have to call <tt>delete</tt>.
		 *
		 * @post  The thread was not created in detached mode.
		 * @warning  You may only call this function once.
		 */
		void join();

		virtual void run();
	};

}

#endif /* _OSL_THREAD_H_ */
