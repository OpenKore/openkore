#ifndef _THREADS_POSIX_H_
#define _THREADS_POSIX_H_

#include <pthread.h>

typedef pthread_mutex_t * Mutex;

#define INIT_MUTEX(mutex) mutex = PTHREAD_MUTEX_INITIALIZER
#define LOCK(mutex) pthread_mutex_lock (mutex)
#define UNLOCK(mutex) pthread_mutex_unlock (mutex)

#endif /* _THREADS_POSIX_H_ */
