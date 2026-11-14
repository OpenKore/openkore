/*
 * This DLL is "injected" into the RO client's address space.
 * Once injected, we intercept all network traffic and redirect
 * some of it to Kore.
 */

#include <stdio.h>
#include "common.h"
#include "../thirdlib/minhook/include/MinHook.h"
#include <string>
#include <string.h>

using namespace std;

MyRecvProc		OriginalRecvProc	= (MyRecvProc) recv;
MySendProc		OriginalSendProc	= (MySendProc) send;
MyRecvFromProc		OriginalRecvFromProc	= (MyRecvFromProc) recvfrom;
MySendToProc		OriginalSendToProc	= (MySendToProc) sendto;
MyConnectProc		OriginalConnectProc	= (MyConnectProc) connect;
MySelectProc		OriginalSelectProc	= (MySelectProc) select;
MyWSARecvProc		OriginalWSARecvProc	= (MyWSARecvProc) WSARecv;
MyWSARecvFromProc	OriginalWSARecvFromProc	= (MyWSARecvFromProc) WSARecvFrom;
MyWSASendProc		OriginalWSASendProc	= (MyWSASendProc) WSASend;
MyWSASendToProc		OriginalWSASendToProc	= (MyWSASendToProc) WSASendTo;
MyWSAAsyncSelectProc	OriginalWSAAsyncSelectProc = (MyWSAAsyncSelectProc) WSAAsyncSelect;
MyGetProcAddressProc	OriginalGetProcAddressProc = (MyGetProcAddressProc) GetProcAddress;

bool enableDebug = false;


// Connection to the X-Kore server that Kore created
static SOCKET koreClient = INVALID_SOCKET;
static bool koreClientIsAlive = false;
static CRITICAL_SECTION CS_koreClientIsAlive;

static bool dataAvailableFromKore = false;
static bool dataAvailableFromKore2 = false;
static CRITICAL_SECTION CS_dataAvailableFromKore;

static SOCKET roServer = INVALID_SOCKET;
static CRITICAL_SECTION CS_ro;

static CRITICAL_SECTION CS_rosend;
static CRITICAL_SECTION CS_send;
static string roSendBuf("");	// Data to send to the RO client
static string xkoreSendBuf("");	// Data to send to the X-Kore server

#define SLEEP_TIME 10


// Process a packet that the X-Kore server sent us
static void
processPacket (Packet *packet)
{	
	switch (packet->ID) {
	case 'S': // Send a packet to the RO server
		EnterCriticalSection (&CS_ro);
		if (roServer != INVALID_SOCKET && isConnected (roServer))
			OriginalSendProc (roServer, packet->data, packet->len, 0);
		LeaveCriticalSection (&CS_ro);
		break;

	case 'R': // Fool the RO client into thinking that we got a packet from the RO server
		// We copy the data in this packet into a string
		// Next time the RO client calls recv(), this packet will be returned, along with
		// whatever data the RO server sent
		EnterCriticalSection (&CS_rosend);
		roSendBuf.append (packet->data, packet->len);
		LeaveCriticalSection (&CS_rosend);
		dataAvailableFromKore2 = true;
		break;

	case 'K': default: // Keep-alive
		break;
	}
}

// Handles the connection between the RO client (this process) and the X-Kore server
// Note that this function is run in a thread and never exits
static void
koreConnectionMain ()
{
	#define BUF_SIZE 1024 * 32
	//#define TIMEOUT 10000
	#define TIMEOUT 600000
	#define PING_INTERVAL 5000
	#define RECONNECT_INTERVAL 3000

	char buf[BUF_SIZE + 1];
	char pingPacket[3];
	unsigned short pingPacketLength = 0;
	DWORD koreClientTimeout, koreClientPingTimeout, reconnectTimeout;
	string koreClientRecvBuf;

	debug ("Thread started\n");
	koreClientTimeout = GetTickCount ();
	koreClientPingTimeout = GetTickCount ();
	reconnectTimeout = 0;

	memcpy (pingPacket, "K", 1);
	memcpy (pingPacket + 1, &pingPacketLength, 2);

	while (1) {
		bool isAlive;
		bool isAliveChanged = false;

		// Attempt to connect to the X-Kore server if necessary
		EnterCriticalSection (&CS_koreClientIsAlive);
		koreClientIsAlive = koreClient != INVALID_SOCKET;
		isAlive = koreClientIsAlive; // keep a local copy of that variable so we don't have to enter critical sections over and over
		LeaveCriticalSection (&CS_koreClientIsAlive);

		if ((!isAlive || !isConnected (koreClient) || GetTickCount () - koreClientTimeout > TIMEOUT)
		  && GetTickCount () - reconnectTimeout > RECONNECT_INTERVAL) {
			debug ("Connecting to X-Kore server...\n");

			if (koreClient != INVALID_SOCKET)
				closesocket (koreClient);
			koreClient = createSocket (XKORE_SERVER_PORT);

			isAlive = koreClient != INVALID_SOCKET;
			isAliveChanged = true;
			if (!isAlive)
				debug ("Failed\n");
			else {
				debug ("Connected\n");
				koreClientTimeout = GetTickCount ();
			}
			reconnectTimeout = GetTickCount ();
		}


		// Receive data from the X-Kore server
		if (isAlive) {
			int ret;

			ret = readSocket (koreClient, buf, BUF_SIZE);
			if (ret == SF_CLOSED) {
				// Connection closed
				debug ("X-Kore server exited\n");
				closesocket (koreClient);
				koreClient = INVALID_SOCKET;
				isAlive = false;
				isAliveChanged = true;

			} else if (ret > 0) {
				// Data available
				Packet *packet;
				int next = 0;

				koreClientRecvBuf.append (buf, ret);
				while ((packet = unpackPacket (koreClientRecvBuf.c_str (), koreClientRecvBuf.size (), next))) {
					// Packet is complete
					processPacket (packet);
					free (packet);
					koreClientRecvBuf.erase (0, next);
				}

				if (dataAvailableFromKore2) {
					dataAvailableFromKore2 = false;
					EnterCriticalSection (&CS_dataAvailableFromKore);
					dataAvailableFromKore = true;
					LeaveCriticalSection (&CS_dataAvailableFromKore);
				}

				// Update timeout
				koreClientTimeout = GetTickCount ();
			}
		}


		// Check whether we have data to send to the X-Kore server
		// This data originates from the RO client and is supposed to go to the real RO server
		EnterCriticalSection (&CS_send);
		if (xkoreSendBuf.size ()) {
			if (isAlive) {
				OriginalSendProc (koreClient, (char *) xkoreSendBuf.c_str (), xkoreSendBuf.size (), 0);

			} else {
				Packet *packet;
				int next;

				// Kore is not running; send it to the RO server instead,
				// if this packet is supposed to go to the RO server ('S')
				// Ignore packets that are meant for Kore ('R')
				EnterCriticalSection (&CS_ro);
				while ((packet = unpackPacket (xkoreSendBuf.c_str (), xkoreSendBuf.size (), next))) {
					if (packet->ID == 'S')
						OriginalSendProc (roServer, (char *) packet->data, packet->len, 0);
					free (packet);
					xkoreSendBuf.erase (0, next);
				}
				LeaveCriticalSection (&CS_ro);
			}
			xkoreSendBuf.erase ();
		}
		LeaveCriticalSection (&CS_send);


		// Ping the X-Kore server to keep the connection alive
		if (koreClientIsAlive && GetTickCount () - koreClientPingTimeout > PING_INTERVAL) {
			OriginalSendProc (koreClient, pingPacket, 3, 0);
			koreClientPingTimeout = GetTickCount ();
		}

		if (isAliveChanged) {
			EnterCriticalSection (&CS_koreClientIsAlive);
			koreClientIsAlive = isAlive;
			LeaveCriticalSection (&CS_koreClientIsAlive);
		}
		Sleep (SLEEP_TIME);
	}
}


/*********** Faked functions ************/

int WINAPI
MyWSASend (SOCKET s, LPWSABUF lpBuffers, DWORD dwBufferCount, LPDWORD lpNumberOfBytesSent, DWORD dwFlags, LPWSAOVERLAPPED lpOverlapped, LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine)
{
	debug ("MyWSASend called (s=%d)\n", (int)s);
	return OriginalWSASendProc(s,lpBuffers,dwBufferCount,lpNumberOfBytesSent,dwFlags,lpOverlapped,lpCompletionRoutine);
}

int WINAPI
MyWSASendTo (SOCKET s, LPWSABUF lpBuffers, DWORD dwBufferCount, LPDWORD lpNumberOfBytesSent, DWORD dwFlags, struct sockaddr* lpTo, int iToLen, LPWSAOVERLAPPED lpOverlapped, LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine) {
	return OriginalWSASendToProc(s,lpBuffers,dwBufferCount,lpNumberOfBytesSent,dwFlags,lpTo,iToLen,lpOverlapped,lpCompletionRoutine);
}

int WINAPI
MyWSARecv (SOCKET s, LPWSABUF lpBuffers, DWORD dwBufferCount, LPDWORD lpNumberOfBytesRecvd, LPDWORD lpFlags, LPWSAOVERLAPPED lpOverlapped, LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine)
{
	debug ("MyWSARecv called (s=%d)\n", (int)s);
	return OriginalWSARecvProc(s,lpBuffers,dwBufferCount,lpNumberOfBytesRecvd,lpFlags,lpOverlapped,lpCompletionRoutine);
}

int WINAPI
MyWSARecvFrom (SOCKET s, LPWSABUF lpBuffers, DWORD dwBufferCount, LPDWORD lpNumberOfBytesRecvd, LPDWORD lpFlags, struct sockaddr* lpFrom, LPINT lpFromlen, LPWSAOVERLAPPED lpOverlapped, LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine)
{
	return OriginalWSARecvFromProc(s,lpBuffers,dwBufferCount,lpNumberOfBytesRecvd,lpFlags,lpFrom,lpFromlen,lpOverlapped,lpCompletionRoutine);
}

int WINAPI
MySelect (int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, const struct timeval *timeout)
{
	if (readfds != NULL) {
		EnterCriticalSection (&CS_dataAvailableFromKore);
		if (dataAvailableFromKore) {
			dataAvailableFromKore = false;
			LeaveCriticalSection (&CS_dataAvailableFromKore);
			if (writefds != NULL)
				FD_ZERO (writefds);
			if (exceptfds != NULL)
				FD_ZERO (exceptfds);
			return 1;
		}
		LeaveCriticalSection (&CS_dataAvailableFromKore);
	}
	return OriginalSelectProc(nfds, readfds, writefds, exceptfds, timeout);
}

int WINAPI
MySend (SOCKET s, char* buf, int len, int flags)
{
	int ret;
	bool isRoSocket;

	EnterCriticalSection (&CS_ro);
	isRoSocket = (s == roServer);
	LeaveCriticalSection (&CS_ro);

	if (!isRoSocket)
		return OriginalSendProc (s, buf, len, flags);

	// See if the socket to the RO server is still alive, and make
	// sure WSAGetLastError() returns the right error if something's wrong
	ret = OriginalSendProc (s, buf, 0, flags);

	if (ret != SOCKET_ERROR && len > 0) {
		bool isAlive;

		// Is Kore running?
		EnterCriticalSection (&CS_koreClientIsAlive);
		isAlive = koreClientIsAlive;
		LeaveCriticalSection (&CS_koreClientIsAlive);

		if (isAlive) {
			// Don't send this packet to the RO server; send it to the X-Kore server instead
			char *newbuf = (char *) malloc (len + 3);

			unsigned short sLen = (unsigned short) len;
			memcpy (newbuf, "S", 1);
			memcpy (newbuf + 1, &sLen, 2);
			memcpy (newbuf + 3, buf, len);

			// We put this packet in a string, and let the X-Kore client thread send it
			EnterCriticalSection (&CS_send);
			xkoreSendBuf.append (newbuf, len + 3);
			LeaveCriticalSection (&CS_send);
			free (newbuf);
			return len;

		} else {
			// Send packet directly to the RO server
			ret = OriginalSendProc (s, buf, len, flags);
			return ret;
		}
	} else
		return ret;
}

int WINAPI
MySendTo (SOCKET s, char* buf, int len, int flags, struct sockaddr* to, int tolen)
{
	return OriginalSendToProc(s,buf,len,flags, to, tolen);
}

int WINAPI
MyRecv (SOCKET s, char* buf, int len, int flags)
{
	int ret = 0;
	int ret2 = 0;
	bool isRoSocket;

	EnterCriticalSection (&CS_ro);
	isRoSocket = (s == roServer);
	LeaveCriticalSection (&CS_ro);

	if (!isRoSocket)
		return OriginalRecvProc (s, buf, len, flags);

	// Is Kore running?
	EnterCriticalSection (&CS_koreClientIsAlive);
	bool isAlive = koreClientIsAlive;
	LeaveCriticalSection (&CS_koreClientIsAlive);

	if (isAlive) {
		// Data that the RO server sent
		if (dataWaiting(s)) {
			// Grab data
			ret2 = OriginalRecvProc(s, buf, len, flags);
			if (ret2 != SOCKET_ERROR && ret2 > 0) {
				// Redirect it to Kore
				char *newbuf = (char *) malloc (ret2 + 3);
				unsigned short sLen = (unsigned short) ret2;
				memcpy (newbuf, "R", 1);
				memcpy (newbuf + 1, &sLen, 2);
				memcpy (newbuf + 3, buf, ret2);

				EnterCriticalSection(&CS_send);
				xkoreSendBuf.append (newbuf, ret2 + 3);
				LeaveCriticalSection(&CS_send);

				free (newbuf);

			} else if (ret2 == 0 || (ret2 == SOCKET_ERROR && WSAGetLastError () != WSAEWOULDBLOCK)) {
				// Connection with RO server closed
				EnterCriticalSection(&CS_ro);
				roServer = INVALID_SOCKET;
				LeaveCriticalSection(&CS_ro);
			}
		}

		// Pass data from Kore to RO Client
		EnterCriticalSection (&CS_rosend);
		int roSendBufsize = roSendBuf.size();
		if (roSendBufsize) {
			ret = roSendBufsize < len? roSendBufsize : len;
			memcpy (buf, (char *) roSendBuf.c_str (), ret);
			roSendBuf.erase (0, ret);
		} else {
			WSASetLastError (WSAEWOULDBLOCK);
			ret = SOCKET_ERROR;
		}
		LeaveCriticalSection (&CS_rosend);
	} else {
		EnterCriticalSection (&CS_rosend);
		int roSendBufsize = roSendBuf.size();
		if (roSendBufsize) {
			// Flush out anything left thats kore->ROclient
			ret = roSendBufsize < len? roSendBufsize : len;
			memcpy (buf, (char *) roSendBuf.c_str(), ret);
			roSendBuf.erase(0, ret);
			LeaveCriticalSection (&CS_rosend);
		} else {
			LeaveCriticalSection (&CS_rosend);
			ret2 = OriginalRecvProc(s, buf, len, flags);
			if (ret2 == 0 || (ret2 == SOCKET_ERROR && WSAGetLastError () != WSAEWOULDBLOCK)) {
				EnterCriticalSection(&CS_ro);
				roServer = INVALID_SOCKET;
				LeaveCriticalSection(&CS_ro);
			}
			ret = ret2;
		}
	}

	return ret;
}

int WINAPI
MyRecvFrom (SOCKET s, char* buf, int len, int flags, struct sockaddr* from, int *fromlen)
{
	return OriginalRecvFromProc(s,buf,len,flags,from,fromlen);
}

int WINAPI
MyConnect (SOCKET s, struct sockaddr* name, int namelen)
{
	bool isIgnoredPort = false;
	unsigned short port = 0;
	if (name != NULL && namelen >= (int)sizeof(struct sockaddr_in) && name->sa_family == AF_INET) {
		struct sockaddr_in *addr = (struct sockaddr_in *) name;
		port = ntohs (addr->sin_port);
		if (port == XKORE_SERVER_PORT || port == 80 || port == 443 || port == 8888 || port == 0 || port == 2052 || port == 3000)
			isIgnoredPort = true;
	}
	if (!isIgnoredPort) {
		EnterCriticalSection (&CS_ro);
		roServer = s;
		LeaveCriticalSection (&CS_ro);
	}
	int ret = OriginalConnectProc(s, name, namelen);
	int err = WSAGetLastError ();
	debug ("MyConnect(s=%d, port=%u) -> ret=%d, err=%d\n", (int)s, port, ret, err);
	WSASetLastError (err);
	return ret;
}

int WINAPI
MyWSAAsyncSelect (SOCKET s, HWND hWnd, unsigned int wMsg, long lEvent)
{
	debug ("MyWSAAsyncSelect(s=%d, lEvent=0x%lx)\n", (int)s, lEvent);
	return OriginalWSAAsyncSelectProc(s,hWnd,wMsg,lEvent);
}

FARPROC WINAPI
MyGetProcAddress (HMODULE hModule, LPCSTR lpProcName)
{
	FARPROC ret = OriginalGetProcAddressProc (hModule, lpProcName);
	HMODULE WS2_32 = LoadLibrary ("WS2_32.DLL");
	if (hModule == WS2_32) {
		if (stricmp (lpProcName, "WSASend") == 0) {
			OriginalWSASendProc = (MyWSASendProc) ret;
			ret = (FARPROC) MyWSASend;

		} else if (stricmp (lpProcName, "WSASendTo") == 0) {
			OriginalWSASendToProc = (MyWSASendToProc) ret;
			ret = (FARPROC) MyWSASendTo;

		} else if (stricmp (lpProcName, "WSARecv") == 0) {
			OriginalWSARecvProc = (MyWSARecvProc) ret;
			ret = (FARPROC) MyWSARecv;

		} else if (stricmp (lpProcName, "WSARecvFrom") == 0) {
			OriginalWSARecvFromProc = (MyWSARecvFromProc) ret;
			ret = (FARPROC) MyWSARecvFrom;

		} else if (stricmp (lpProcName, "send") == 0) {
			OriginalSendProc = (MySendProc) ret;
			ret = (FARPROC) MySend;

		} else if (stricmp (lpProcName, "sendto") == 0) {
			OriginalSendToProc = (MySendToProc) ret;
			ret = (FARPROC) MySendTo;

		} else if (stricmp (lpProcName, "recv") == 0) {
			OriginalRecvProc = (MyRecvProc) ret;
			ret = (FARPROC) MyRecv;

		} else if (stricmp (lpProcName, "recvfrom") == 0) {
			OriginalRecvFromProc = (MyRecvFromProc) ret;
			ret = (FARPROC) MyRecvFrom;

		} else if (stricmp (lpProcName, "connect") == 0) {
			OriginalConnectProc = (MyConnectProc) ret;
			ret = (FARPROC) MyConnect;

		} else if (stricmp (lpProcName, "WSAAsyncSelect") == 0) {
			OriginalWSAAsyncSelectProc = (MyWSAAsyncSelectProc) ret;
			ret = (FARPROC) MyWSAAsyncSelect;
		}
	}
 	return ret;
}

/************************************************/


static void
DoHookProcs ()
{
	if (MH_Initialize () != MH_OK) {
		debug ("MH_Initialize failed\n");
		return;
	}

	MH_CreateHookApi (L"ws2_32.dll", "WSASend", (LPVOID)MyWSASend, (LPVOID *)&OriginalWSASendProc);
	MH_CreateHookApi (L"ws2_32.dll", "WSASendTo", (LPVOID)MyWSASendTo, (LPVOID *)&OriginalWSASendToProc);
	MH_CreateHookApi (L"ws2_32.dll", "WSARecv", (LPVOID)MyWSARecv, (LPVOID *)&OriginalWSARecvProc);
	MH_CreateHookApi (L"ws2_32.dll", "WSARecvFrom", (LPVOID)MyWSARecvFrom, (LPVOID *)&OriginalWSARecvFromProc);
	MH_CreateHookApi (L"ws2_32.dll", "send", (LPVOID)MySend, (LPVOID *)&OriginalSendProc);
	MH_CreateHookApi (L"ws2_32.dll", "sendto", (LPVOID)MySendTo, (LPVOID *)&OriginalSendToProc);
	MH_CreateHookApi (L"ws2_32.dll", "recv", (LPVOID)MyRecv, (LPVOID *)&OriginalRecvProc);
	MH_CreateHookApi (L"ws2_32.dll", "recvfrom", (LPVOID)MyRecvFrom, (LPVOID *)&OriginalRecvFromProc);
	MH_CreateHookApi (L"ws2_32.dll", "connect", (LPVOID)MyConnect, (LPVOID *)&OriginalConnectProc);
	MH_CreateHookApi (L"ws2_32.dll", "select", (LPVOID)MySelect, (LPVOID *)&OriginalSelectProc);
	MH_CreateHookApi (L"ws2_32.dll", "WSAAsyncSelect", (LPVOID)MyWSAAsyncSelect, (LPVOID *)&OriginalWSAAsyncSelectProc);
	// MH_CreateHookApi (L"kernel32.dll", "GetProcAddress", (LPVOID)MyGetProcAddress, (LPVOID *)&OriginalGetProcAddressProc);

	if (MH_EnableHook (MH_ALL_HOOKS) != MH_OK) {
		debug ("MH_EnableHook failed\n");
	}
}

static void
init ()
{
	WSAData WSAData;
	ULONG threadID;

	WSAStartup (MAKEWORD (2,2),&WSAData);
	InitializeCriticalSection (&CS_koreClientIsAlive);
	InitializeCriticalSection (&CS_dataAvailableFromKore);
	InitializeCriticalSection (&CS_ro);
	InitializeCriticalSection (&CS_send);
	InitializeCriticalSection (&CS_rosend);
	debugInit ();

	debug ("Hooking functions...\n");
	DoHookProcs ();
	debug ("Creating thread...\n");
	CreateThread (0, 0, (LPTHREAD_START_ROUTINE) koreConnectionMain, 0, 0, &threadID);
	debug ("Thread created\n");
}


/********* DLL injection support for Win9x *********/

//#define TESTING_INJECT9x

static int isNT = 0;
static int started = 0;
static HINSTANCE hDll = 0;
static HHOOK hookID = 0;

static int
start ()
{
	init ();
	return 0;
}

// This function is called when we're injected into another process
static LRESULT WINAPI
hookProc (int code, WPARAM wParam, LPARAM lParam)
{
	if (!started) {
		char lib[MAX_PATH];
		ULONG threadID;

		started = 1;
		GetModuleFileName (hDll, lib, MAX_PATH);
		if (LoadLibrary (lib))
			UnhookWindowsHookEx (hookID);

		// For some reason RO crashes if I call init() here.
		// Calling it in a thread seems to fix the problem.
		// (but won't we get race conditions??)
		CreateThread (NULL, 0, (LPTHREAD_START_ROUTINE) start, NULL, 0, &threadID);
	}
	return CallNextHookEx (hookID, code, wParam, lParam);
}

// Inject this DLL into the process that owns window hwnd
extern "C" int WINAPI __declspec(dllexport)
injectSelf (HWND hwnd)
{
	int idHook;

	if (isNT)
		idHook = WH_CALLWNDPROC;
	else
		idHook = WH_GETMESSAGE;

	hookID = SetWindowsHookEx (idHook, (HOOKPROC) hookProc, hDll,
		GetWindowThreadProcessId (hwnd, NULL));
	if (hookID == NULL)
		return 0;

	SendMessage (hwnd, WM_USER + 10, 0, 1);
	return 1;
}

/***************************************************/


extern "C" BOOL APIENTRY
DllMain (HINSTANCE hInstance, DWORD dwReason, LPVOID _Reserved)
{
	switch (dwReason) {
	case DLL_PROCESS_ATTACH:
		hDll = hInstance;

		// Check whether debugging should be enabled
		HKEY key;
		DWORD type, size;
		BYTE val[1024];

		size = sizeof (val) - 1;
		val[0] = '\0';
		RegOpenKey (HKEY_CURRENT_USER,
			"Software\\Kore",
			&key);
		RegQueryValueEx (key,
			"DebugNetRedirect",
			NULL,
			&type,
			val,
			&size);
		RegCloseKey (key);
		enableDebug = val[0] == '1';


		#ifndef TESTING_INJECT9x
		OSVERSIONINFO version;

		version.dwOSVersionInfoSize = sizeof (OSVERSIONINFO);
		GetVersionEx (&version);
		isNT = version.dwPlatformId == VER_PLATFORM_WIN32_NT;

		// If we're injected on Win9x, then init() must
		// be called from a different function (see above).
		// This is because Kore LoadLibrary() this dll when on Win9x.
		if (isNT) {
			ULONG threadID;
			CreateThread (NULL, 0, (LPTHREAD_START_ROUTINE) init, NULL, 0, &threadID);
		}
		#endif
		break;

	default:
		break;
	}

	return true;
}
