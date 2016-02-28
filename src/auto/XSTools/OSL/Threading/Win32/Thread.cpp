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

// Do not compile this file independently, it's supposed to be automatically
// included by another source file.

class Win32Thread: public ThreadImplementation {
private:
	HANDLE thread;
	Runnable *runnable;
	bool detached;
	bool runnableShouldBeFreed;

	static DWORD WINAPI
	entry(LPVOID arg) {
		Win32Thread *self = (Win32Thread *) arg;
		self->runnable->run();
		if (self->detached) {
			CloseHandle(self->thread);
			if (self->runnableShouldBeFreed) {
				delete self->runnable;
			}
		}
		self->unref();
		return 0;
	}
public:
	virtual void
	start(Runnable *runnable, bool detached, bool runnableShouldBeFreed) throw(ThreadException) {
		DWORD threadID;

		this->runnable = runnable;
		this->detached = detached;
		this->runnableShouldBeFreed = runnableShouldBeFreed;
		thread = CreateThread(NULL, 0, entry, this, CREATE_SUSPENDED, &threadID);
		if (thread == NULL) {
			throw ThreadException("Cannot create a thread.");
		} else {
			ref();
			if (ResumeThread(thread) == (DWORD) -1) {
				unref();
				CloseHandle(thread);
				throw ThreadException("Cannot resume thread.");
			}
		}
	}

	virtual void
	join() {
		WaitForSingleObject(thread, INFINITE);
		CloseHandle(thread);
	}
};
