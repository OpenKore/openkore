/* Cross-platform threading abstraction layer. */
#ifndef _THREADS_H_
#define _THREADS_H_

typedef void (*ThreadCallback) (void *data);

void run_in_thread (ThreadCallback callback, void *data);

#ifdef WIN32
	#include "threads-win32.h"
#else
	#include "threads-posix.h"
#endif

#endif /* _THREADS_H_ */
