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

/* Threading interface for Unix. */

#ifndef _THREADS_POSIX_H_
#define _THREADS_POSIX_H_

#include <pthread.h>

typedef pthread_mutex_t * Mutex;

#define INIT_MUTEX(mutex) mutex = PTHREAD_MUTEX_INITIALIZER
#define LOCK(mutex) pthread_mutex_lock (mutex)
#define UNLOCK(mutex) pthread_mutex_unlock (mutex)

#endif /* _THREADS_POSIX_H_ */
