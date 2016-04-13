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

#include <stdlib.h>
#include "threads.h"


#ifdef WIN32

/* Work around Win32 calling convention problems. */
static DWORD WINAPI
win32_thread_start (LPVOID param)
{
	void **params = (void **) param;
	ThreadCallback callback = (ThreadCallback) params[0];
	void *data = params[1];
	free (params);
	callback (data);
	return 0;
}

#endif


Thread *
thread_new (ThreadCallback callback, void *data, int detachable)
{
#ifdef WIN32
	HANDLE handle;
	DWORD threadID;
	void **param;

	param = malloc (sizeof (void *) * 2);
	param[0] = callback;
	param[1] = data;
	handle = CreateThread (NULL, 0, win32_thread_start, param, 0, &threadID);

	if (handle == NULL) {
		free (param);
		return NULL;
	} else {
		Thread *thread;

		if (detachable) {
			CloseHandle (handle);
			handle = NULL;
		}

		thread = malloc (sizeof (Thread));
		thread->handle = handle;
		return thread;
	}
#else
	pthread_t *thread;
	pthread_attr_t attr, *p_attr = NULL;
	int ret;

	thread = malloc (sizeof (pthread_t));
	if (detachable) {
		pthread_attr_init (&attr);
		pthread_attr_setdetachstate (&attr, PTHREAD_CREATE_DETACHED);
		p_attr = &attr;
	}
	ret = pthread_create (thread, p_attr, (void * (*) (void *)) callback, data);
	if (detachable)
		pthread_attr_destroy (&attr);

	if (ret != 0) {
		free (thread);
		return NULL;
	} else {
		return (Thread *) thread;
	}
#endif
}

void
thread_join (Thread *thread)
{
#ifdef WIN32
	if (thread->handle != NULL) {
		WaitForSingleObject (thread->handle, INFINITE);
		CloseHandle (thread->handle);
	}
	free (thread);
#else
	pthread_join (*thread, NULL);
	free (thread);
#endif
}

Mutex *
mutex_new ()
{
#ifdef WIN32
	CRITICAL_SECTION *cs;

	cs = malloc (sizeof (CRITICAL_SECTION));
	InitializeCriticalSection (cs);
	return (Mutex *) cs;
#else
	pthread_mutex_t *mutex;

	mutex = malloc (sizeof (pthread_mutex_t));
	if (pthread_mutex_init (mutex, NULL) == 0)
		return mutex;
	else {
		free (mutex);
		return NULL;
	}
#endif
}

void
mutex_free (Mutex *mutex)
{
#ifdef WIN32
	DeleteCriticalSection ((LPCRITICAL_SECTION) mutex);
	free (mutex);
#else
	pthread_mutex_destroy ((pthread_mutex_t *) mutex);
	free (mutex);
#endif
}
