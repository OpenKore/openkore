#ifndef _COMMON_H_
#define _COMMON_H_

#include <windows.h>
#include <winsock2.h>

#ifndef NULL
	#define NULL ((void *) 0)
#endif
#define XKORE_SERVER_PORT 2350
typedef struct {
	char ID;
	unsigned short len;
	char *data;
} Packet;

Packet *unpackPacket (const char *data, int len, int &next);


typedef int (WINAPI *MyRecvProc) (SOCKET s, char *buf, int len, int flags);
typedef int (WINAPI *MyRecvFromProc) (SOCKET s, char* buf, int len, int flags, struct sockaddr* from, int* fromlen);
typedef int (WINAPI *MySendProc) (SOCKET s, char *buf, int len, int flags);
typedef int (WINAPI *MySendToProc) (SOCKET s, const char* buf, int len, int flags, struct sockaddr* to, int tolen);
typedef int (WINAPI *MyConnectProc) (SOCKET s, const struct sockaddr* name, int namelen);
typedef int (WINAPI *MySelectProc) (int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, const struct timeval *timeout);
typedef int (WINAPI *MyWSARecvProc) (SOCKET s, LPWSABUF lpBuffers, DWORD dwBufferCount, LPDWORD lpNumberOfBytesRecvd, LPDWORD lpFlags, LPWSAOVERLAPPED lpOverlapped, LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);
typedef int (WINAPI *MyWSARecvFromProc) (SOCKET s, LPWSABUF lpBuffers, DWORD dwBufferCount, LPDWORD lpNumberOfBytesRecvd, LPDWORD lpFlags, struct sockaddr* lpFrom, LPINT lpFromlen, LPWSAOVERLAPPED lpOverlapped, LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);
typedef int (WINAPI *MyWSASendProc) (SOCKET s, LPWSABUF lpBuffers, DWORD dwBufferCount, LPDWORD lpNumberOfBytesSent, DWORD dwFlags, LPWSAOVERLAPPED lpOverlapped, LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);
typedef int (WINAPI *MyWSASendToProc) (SOCKET s, LPWSABUF lpBuffers, DWORD dwBufferCount, LPDWORD lpNumberOfBytesSent, DWORD dwFlags, struct sockaddr* lpTo, int iToLen, LPWSAOVERLAPPED lpOverlapped, LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);
typedef int (WINAPI *MyWSAAsyncSelectProc) (SOCKET s, HWND hWnd, unsigned int wMsg, long lEvent);
typedef FARPROC (WINAPI *MyGetProcAddressProc) (HMODULE hModule, LPCSTR lpProcName);

extern MyRecvProc		OriginalRecvProc;
extern MyRecvFromProc		OriginalRecvFromProc;
extern MySendProc		OriginalSendProc;
extern MySendToProc		OriginalSendToProc;
extern MyConnectProc		OriginalConnectProc;
extern MySelectProc		OriginalSelectProc;
extern MyWSARecvProc		OriginalWSARecvProc;
extern MyWSARecvFromProc	OriginalWSARecvFromProc;
extern MyWSASendProc		OriginalWSASendProc;
extern MyWSASendToProc		OriginalWSASendToProc;
extern MyWSAAsyncSelectProc	OriginalWSAAsyncSelectProc;
extern MyGetProcAddressProc	OriginalGetProcAddressProc;

extern bool enableDebug;


// readSocket() error codes
#define SF_NODATA 0
#define SF_CLOSED -1


SOCKET createSocket (int port);
bool isConnected (SOCKET s);
bool dataWaiting (SOCKET s);
int readSocket (SOCKET s, char *buf, int len);
PROC HookImportedFunction (HMODULE hModule, PSTR FunctionModule, PSTR FunctionName, PROC pfnNewProc);

void debugInit ();
void debug(const char *format, ...);

#endif /* _COMMON_H_ */
