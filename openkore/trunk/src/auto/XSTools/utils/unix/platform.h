#include <pthread.h>
#include <sys/time.h>
#include <unistd.h>

#define Thread pthread_t *
#define Mutex pthread_mutex_t *
#define ThreadValue void *
#define ThreadCallConvention
#define THREAD_DEFAULT_RETURN_VALUE NULL
#define DWORD unsigned long

#define NewThread(handle, entry, userData) \
	thread = (pthread_t *) malloc(sizeof(pthread_t)); \
	pthread_create(thread, NULL, entry, userData)
#define WaitThread(handle) \
	do { \
		void *ret; \
		pthread_join(*handle, &ret); \
		free(handle); \
	} while (0)
#define NewMutex(mutex) mutex = (pthread_mutex_t *) malloc(sizeof(pthread_mutex_t)); pthread_mutex_init(mutex, NULL)
#define FreeMutex(mutex) pthread_mutex_destroy(mutex); free(mutex)
#define LockMutex(mutex) pthread_mutex_lock(mutex)
#define UnlockMutex(mutex) pthread_mutex_unlock(mutex)
#define Sleep(msec) usleep(msec * 1000)

static DWORD
GetTickCount() {
	struct timeval tv;
	gettimeofday(&tv, (struct timezone *) NULL);
	return (tv.tv_sec * 1000) + (tv.tv_usec / 1000);
}
