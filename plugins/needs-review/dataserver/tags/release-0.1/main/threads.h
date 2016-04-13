/*  Kore Shared Data Server
 *  Copyright (C) 2005  Hongli Lai <hongli AT navi DOT cx>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/* Cross-platform threading abstraction layer. */
#ifndef _THREADS_H_
#define _THREADS_H_


#ifdef WIN32
	#include <windows.h>

	typedef struct {
		HANDLE handle;
	} Thread;
	typedef CRITICAL_SECTION Mutex;

	#define LOCK(mutex) EnterCriticalSection (mutex)
	#define UNLOCK(mutex) LeaveCriticalSection (mutex)
	#define TRYLOCK(mutex) TryEnterCriticalSection (mutex)

	#define milisleep Sleep
	#define yield SwitchToThread
#else
	#define __USE_GNU
	#include <pthread.h>
	#include <unistd.h>

	#if defined(LINUX) || defined(__LINUX__) || defined(__linux__) || defined(__FreeBSD__)
		#define yield pthread_yield
	#else
		#include <sched.h>
		#define yield sched_yield
	#endif

	typedef pthread_t Thread;
	typedef pthread_mutex_t Mutex;

	#define LOCK(mutex) pthread_mutex_lock (mutex)
	#define UNLOCK(mutex) pthread_mutex_unlock (mutex)
	#define TRYLOCK(mutex) pthread_mutex_trylock (mutex) == 0

	#define milisleep(x) usleep (x * 1000)
#endif


typedef void (*ThreadCallback) (void *data);

Thread *thread_new  (ThreadCallback callback, void *data, int detachable);
void    thread_join (Thread *thread);

Mutex *mutex_new  ();
void   mutex_free (Mutex *mutex);


#endif /* _THREADS_H_ */
