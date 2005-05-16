#include <pthread.h>
#include "threads.h"

int
run_in_thread (ThreadCallback callback, void *data)
{
	pthread_t thread;
	pthread_attr_t attr;
	int ret;

	pthread_attr_init (&attr);
	pthread_attr_setdetachstate (&attr, PTHREAD_CREATE_DETACHED);
	ret = pthread_create (&thread, NULL, (void * (*) (void *)) callback, data);
	pthread_attr_destroy (&attr);
	return ret == 0;
}
