#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include "common.h"


/* Creates a packet data structure.
 * Returns NULL if data is not a full packet, or a Packet structure.
 * next is the offset of the next packet, in case data contains more than one packet.
 */
Packet *
unpackPacket (const char *data, int len, int &next)
{
	Packet *packet;

	if (len < 3)
		return NULL;

	packet = (Packet *) calloc (sizeof (Packet), 1);
	packet->ID = (unsigned char) data[0];
	memcpy (&(packet->len), data + 1, 2);
	if (len < packet->len) {
		free (packet);
		return NULL;
	}

	if (packet->len > 0)
		packet->data = (char *) data + 3;
	next = packet->len + 3;
	return packet;
}


SOCKET
createSocket (int port)
{
	sockaddr_in addr;
	SOCKET sock;
	DWORD arg = 1;

	sock = socket (AF_INET, SOCK_STREAM, 0);
	if (sock == INVALID_SOCKET)
		return INVALID_SOCKET;
	// Set to non-blocking mode
	ioctlsocket (sock, FIONBIO, &arg);

	addr.sin_family = AF_INET;
	addr.sin_port = htons (port);
	addr.sin_addr.s_addr = inet_addr ("127.0.0.1");
	while (OriginalConnectProc (sock, (struct sockaddr *) &addr, sizeof (sockaddr_in)) == SOCKET_ERROR) {
		if (WSAGetLastError () == WSAEISCONN)
			break;
		else if (WSAGetLastError () != WSAEWOULDBLOCK) {
			closesocket (sock);
			return INVALID_SOCKET;
		} else
			Sleep (10);
	}

	return sock;
}

// Checks whether a socket is still connected
bool
isConnected (SOCKET s)
{
	fd_set fds;
	long count;
	timeval tv;

	tv.tv_sec = 0;
	tv.tv_usec = 1;
	FD_ZERO (&fds);
	FD_SET (s, &fds);
	count = OriginalSelectProc (1, NULL, &fds, NULL, &tv);
	return (bool) count;
}

// Checks whether there's data available from a socket
bool
dataWaiting (SOCKET s)
{
	fd_set fds;
	long count;
	timeval tv;

	tv.tv_sec = 0;
	tv.tv_usec = 1;
	FD_ZERO (&fds);
	FD_SET (s, &fds);
	count = OriginalSelectProc (1, &fds, NULL, NULL, &tv);
	return (bool) count;
}

int
readSocket (SOCKET s, char *buf, int len)
{
	int ret = OriginalRecvProc (s, buf, len, 0);

	if (ret == 0)
		return SF_CLOSED;
	else if (ret > 0)
		return ret;
	else if (ret == SOCKET_ERROR) {
		if (WSAGetLastError () == WSAEWOULDBLOCK)
			return SF_NODATA;
		else
			return SF_CLOSED;
	} else
		return SF_CLOSED;
}

// This function "replaces" a function with another function
// So, for example, if you do this:
//   OriginalWSASendProc = (MyWSASendProc) HookImportedFunction (GetModuleHandle (0), "WS2_32.DLL", "WSASend", (PROC) MyWSASend);
// This will "replaces" WSASend() with MyWSASend(). Every time the app calls WSASend(), MyWSASend() gets called instead.
// This function returns a pointer to the original function.
PROC
HookImportedFunction (HMODULE hModule,		// Module to intercept calls from
			PSTR FunctionModule,	// The dll file that contains the function you want to hook
			PSTR FunctionName,	// The function that you want to hook
			PROC pfnNewProc)	// New function, this gets called instead
{
	#define MakePtr( cast, ptr, addValue ) (cast)( (DWORD)(ptr)+(DWORD)(addValue))
	PROC pfnOriginalProc;
	IMAGE_DOS_HEADER *pDosHeader;
	IMAGE_NT_HEADERS *pNTHeader;
	IMAGE_IMPORT_DESCRIPTOR *pImportDesc;
	IMAGE_THUNK_DATA *pThunk;

	if (IsBadCodePtr (pfnNewProc)) return NULL;
	if (OriginalGetProcAddressProc) {
		pfnOriginalProc = OriginalGetProcAddressProc(GetModuleHandle(FunctionModule), FunctionName);
	} else {
		pfnOriginalProc = GetProcAddress(GetModuleHandle(FunctionModule), FunctionName);
	}
	if(!pfnOriginalProc) return NULL;

	pDosHeader = (PIMAGE_DOS_HEADER)hModule;

	if ( IsBadReadPtr(pDosHeader, sizeof(IMAGE_DOS_HEADER)) )
		return NULL;
	if ( pDosHeader->e_magic != IMAGE_DOS_SIGNATURE )
		return NULL;

	pNTHeader = MakePtr(PIMAGE_NT_HEADERS, pDosHeader, pDosHeader->e_lfanew);

	if ( IsBadReadPtr(pNTHeader, sizeof(IMAGE_NT_HEADERS)) )
		return NULL;

	if ( pNTHeader->Signature != IMAGE_NT_SIGNATURE )
		return NULL;

	pImportDesc = MakePtr(PIMAGE_IMPORT_DESCRIPTOR, pDosHeader,
			pNTHeader->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress);

	if ( pImportDesc == (PIMAGE_IMPORT_DESCRIPTOR)pNTHeader )
		return NULL;


	while ( pImportDesc->Name ) {
		PSTR pszModName = MakePtr(PSTR, pDosHeader, pImportDesc->Name);
		if ( stricmp(pszModName, FunctionModule) == 0 )
			break;
		pImportDesc++;
	}

	pNTHeader = MakePtr(PIMAGE_NT_HEADERS, pDosHeader, pDosHeader->e_lfanew);
	if ( pImportDesc->Name == 0 )
		return 0;

	pThunk = MakePtr(PIMAGE_THUNK_DATA, pDosHeader, pImportDesc->FirstThunk);

	MEMORY_BASIC_INFORMATION mbi_thunk;
	while ( pThunk->u1.Function ) {
		if ( (DWORD)pThunk->u1.Function == (DWORD)pfnOriginalProc) {
			VirtualQuery(pThunk, &mbi_thunk, sizeof(MEMORY_BASIC_INFORMATION));
			if (FALSE == VirtualProtect(mbi_thunk.BaseAddress, mbi_thunk.RegionSize, PAGE_READWRITE, &mbi_thunk.Protect))
				return NULL;
			DWORD * pTemp = (DWORD*)&pThunk->u1.Function;
			*pTemp = (DWORD)(pfnNewProc);

			VirtualProtect(mbi_thunk.BaseAddress, mbi_thunk.RegionSize,mbi_thunk.Protect, NULL);

			break;
		}
		pThunk++;
	}

	SYSTEM_INFO si;
	DWORD i;
	byte *data = NULL;
	GetSystemInfo(&si);
	LPVOID lpMem = si.lpMinimumApplicationAddress;
	while (lpMem < si.lpMaximumApplicationAddress) {
		VirtualQuery(lpMem, &mbi_thunk,sizeof(MEMORY_BASIC_INFORMATION));

		if ((DWORD)mbi_thunk.BaseAddress <= (DWORD)pDosHeader + pNTHeader->OptionalHeader.SizeOfImage
			&& mbi_thunk.State == MEM_COMMIT && mbi_thunk.RegionSize > 0 && !(mbi_thunk.Protect & PAGE_GUARD)) {

			if (VirtualProtect(mbi_thunk.BaseAddress, mbi_thunk.RegionSize, PAGE_READWRITE, &mbi_thunk.Protect)) {
				data = (byte*)mbi_thunk.BaseAddress;
				for (i = 0; i < mbi_thunk.RegionSize - 3; i++) {

					if (*(DWORD*)(data+i) == (DWORD)pfnOriginalProc) {
						*(DWORD*)(data+i) = (DWORD)pfnNewProc;
					}
					
				}
			VirtualProtect(mbi_thunk.BaseAddress, mbi_thunk.RegionSize,mbi_thunk.Protect, NULL);
			}
		}
		lpMem = MakePtr(LPVOID, mbi_thunk.BaseAddress, mbi_thunk.RegionSize+1);
	}

	return pfnOriginalProc;
}


void
debugInit ()
{
	if (enableDebug)
		AllocConsole ();
}

void
debug (const char *format, ...)
{
	if (enableDebug) {
		va_list ap;
		char msg[1024];

		va_start (ap, format);
		vsprintf (msg, format, ap);
		va_end (ap);
		WriteConsole (GetStdHandle (STD_OUTPUT_HANDLE), msg, strlen (msg), NULL, NULL);
	}
}
