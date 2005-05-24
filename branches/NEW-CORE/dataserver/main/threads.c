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


Thread *
thread_new (ThreadCallback callback, void *data, int detachable)
{
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
}

void
thread_join (Thread *thread)
{
	pthread_join (*thread, NULL);
	free (thread);
}

Mutex *
mutex_new ()
{
	pthread_mutex_t *mutex;

	mutex = malloc (sizeof (pthread_mutex_t));
	if (pthread_mutex_init (mutex, NULL) == 0)
		return mutex;
	else {
		free (mutex);
		return NULL;
	}
}

void
mutex_free (Mutex *mutex)
{
	pthread_mutex_destroy ((pthread_mutex_t *) mutex);
	free (mutex);
}
