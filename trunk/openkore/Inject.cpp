#include <stdio.h>
#include <string.h>
#include <winsock2.h>
#include <mswsock.h>

#define MakePtr( cast, ptr, addValue ) (cast)( (DWORD)(ptr)+(DWORD)(addValue))

#define FALSECLIENT_TIMEOUT 12000
#define FALSECLIENT_SEND_TIMEOUT 5000
#define MAX_BUFFER_LENGTH 10000


////
//FUNCTION PROTOTYPES AND TYPEDEF
////
BOOL IsConnected(SOCKET s);
void falseClientCom();
PROC HookImportedFunction(HMODULE,PSTR,PSTR,PROC);
BOOL DoHookProcs();


typedef int(WINAPI *MyWSASendProc)(
  SOCKET s,
  LPWSABUF lpBuffers,
  DWORD dwBufferCount,
  LPDWORD lpNumberOfBytesSent,
  DWORD dwFlags,
  LPWSAOVERLAPPED lpOverlapped,
  LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine
);

typedef int(WINAPI *MyWSASendToProc)(
  SOCKET s,
  LPWSABUF lpBuffers,
  DWORD dwBufferCount,
  LPDWORD lpNumberOfBytesSent,
  DWORD dwFlags,
  struct sockaddr* lpTo,
  int iToLen,
  LPWSAOVERLAPPED lpOverlapped,
  LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine
);

typedef int(WINAPI *MyWSARecvProc)(
  SOCKET s,
  LPWSABUF lpBuffers,
  DWORD dwBufferCount,
  LPDWORD lpNumberOfBytesRecvd,
  LPDWORD lpFlags,
  LPWSAOVERLAPPED lpOverlapped,
  LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine
);

typedef int(WINAPI *MyWSARecvFromProc)(
  SOCKET s,
  LPWSABUF lpBuffers,
  DWORD dwBufferCount,
  LPDWORD lpNumberOfBytesRecvd,
  LPDWORD lpFlags,
  struct sockaddr* lpFrom,
  LPINT lpFromlen,
  LPWSAOVERLAPPED lpOverlapped,
  LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine
);

typedef int(WINAPI *MySendProc)(
  SOCKET s,
  char* buf,
  int len,
  int flags
);

typedef int(WINAPI *MySendToProc)(
  SOCKET s,
  const char* buf,
  int len,
  int flags,
  struct sockaddr* to,
  int tolen
);

typedef int(WINAPI *MyRecvProc)(
  SOCKET s,
  char* buf,
  int len,
  int flags
);

typedef int(WINAPI *MyRecvFromProc)(
  SOCKET s,
  char* buf,
  int len,
  int flags,
  struct sockaddr* from,
  int* fromlen
);

typedef int (WINAPI *MyConnectProc) (
  SOCKET s,
  const struct sockaddr* name,
  int namelen
);

typedef int (WINAPI *MyWSAAsyncSelectProc) (
  SOCKET s,
  HWND hWnd,
  unsigned int wMsg,
  long lEvent
);

typedef FARPROC (WINAPI *MyGetProcAddressProc)(
  HMODULE hModule,
  LPCSTR lpProcName
);


////
//GLOBAL VARIABLES
////

HINSTANCE g_hInst=0;
MyWSASendProc  OriginalWSASendProc;
MyWSASendToProc  OriginalWSASendToProc;
MyWSARecvProc  OriginalWSARecvProc;
MyWSARecvFromProc  OriginalWSARecvFromProc;
MySendProc  OriginalSendProc;
MySendToProc  OriginalSendToProc;
MyRecvProc  OriginalRecvProc;
MyRecvFromProc  OriginalRecvFromProc;
MyConnectProc  OriginalConnectProc;
MyGetProcAddressProc  OriginalGetProcAddressProc;
MyWSAAsyncSelectProc  OriginalWSAAsyncSelectProc;

ULONG falseClientComId;
SOCKET falseClient;
SOCKET currentServer;

WSADATA WSAData;
char* falseClient_send;
char* falseClient_recvInject;
int falseClient_sendLength;
int falseClient_recvInjectLength;
CRITICAL_SECTION falseClient_sendSection;
CRITICAL_SECTION falseClient_recvInjectSection;
 
////
//FUNCTIONS
////

BOOL IsConnected(SOCKET s) {
	fd_set udtWrite_fd;
	timeval tv;
	tv.tv_sec = 0;
	tv.tv_usec = 1;
	long lngSocketCount = 0;
    udtWrite_fd.fd_count = 1;
    udtWrite_fd.fd_array[0] = s;
    lngSocketCount = select(0, 0, &udtWrite_fd, 0, &tv);
    return (BOOL)(lngSocketCount);
}


void falseClientCom() {
	char * falseClient_recv = (char*)malloc(MAX_BUFFER_LENGTH);
	unsigned short falseClient_recvLength;
	int index;
	int ret;
	int type;
	DWORD falseClient_timeout;
	DWORD falseClient_send_timeout;
	sockaddr_in addr;
	DWORD arg = 1;
	addr.sin_family = AF_INET;
	addr.sin_port = htons(2350);
	addr.sin_addr.s_addr = inet_addr("127.0.0.1");
	falseClient = socket(AF_INET, SOCK_STREAM, 0);
	
	char* keepAlivePacket = (char*)malloc(3);
	unsigned short keepAlivePacketLength = 0;
	memcpy(keepAlivePacket,"K",1);
	memcpy(keepAlivePacket+1,&keepAlivePacketLength,2);
	while (1) {
		while (!falseClient || !IsConnected(falseClient) || (GetTickCount() - falseClient_timeout >= FALSECLIENT_TIMEOUT)) {
			closesocket(falseClient);
			falseClient = socket(AF_INET, SOCK_STREAM, 0);
			connect(falseClient, (struct sockaddr *) &addr, sizeof(sockaddr_in));
			ioctlsocket(falseClient,FIONBIO,&arg);
			falseClient_timeout = GetTickCount();
			falseClient_send_timeout = GetTickCount();
			falseClient_sendLength = 0;
		}
		ret = OriginalRecvProc(falseClient,falseClient_recv,MAX_BUFFER_LENGTH,0);
		if (ret != SOCKET_ERROR && ret >= 3) {
			index = 0;
			while (index < ret) {
				falseClient_recvLength = *(unsigned short *)(falseClient_recv+index+1);
				if (ret-index < falseClient_recvLength) {
					MessageBox(0,"False client sent a bad message!", "False client error",0);
					break;
				}
				if (*(falseClient_recv+index) == 'S') {
					type = 0;
				} else if (*(falseClient_recv+index) == 'R') {
					type = 1;
				} else if (*(falseClient_recv+index) == 'K') {
					//Keep alive
					type = 2;
				} else {
					type = -1;
				}
			
				if (!type && currentServer && IsConnected(currentServer)) {
					OriginalSendProc(currentServer,falseClient_recv+index+3,falseClient_recvLength,0);
				} else if (type == 1) {
					EnterCriticalSection(&falseClient_recvInjectSection);
					memcpy(falseClient_recvInject+falseClient_recvInjectLength,falseClient_recv+index+3,falseClient_recvLength);
					falseClient_recvInjectLength += falseClient_recvLength;
					LeaveCriticalSection(&falseClient_recvInjectSection);
				}
				index += falseClient_recvLength + 3;
			}
			falseClient_timeout = GetTickCount();
		}
		if (falseClient_sendLength) {
			EnterCriticalSection(&falseClient_sendSection);
			OriginalSendProc(falseClient,falseClient_send,falseClient_sendLength,0);
			falseClient_sendLength = 0;
			LeaveCriticalSection(&falseClient_sendSection);
		}
		if (GetTickCount() - falseClient_send_timeout >= FALSECLIENT_SEND_TIMEOUT) {
			EnterCriticalSection(&falseClient_sendSection);
			OriginalSendProc(falseClient,keepAlivePacket,3,0);
			LeaveCriticalSection(&falseClient_sendSection);
			falseClient_send_timeout = GetTickCount();
		}
		Sleep(100);
	}
}


PROC HookImportedFunction(HMODULE hModule,     //Module to intercept calls from
				 PSTR FunctionModule, //The dll file that contains the function you want to hook
				 PSTR FunctionName,   //The function that you want to hook
				 PROC pfnNewProc)     //New function, this gets called instead
{
    PROC pfnOriginalProc;
    IMAGE_DOS_HEADER *pDosHeader;
    IMAGE_NT_HEADERS *pNTHeader;
    IMAGE_IMPORT_DESCRIPTOR *pImportDesc;
    IMAGE_THUNK_DATA *pThunk;

    if ( IsBadCodePtr(pfnNewProc) ) return 0;
	if (OriginalGetProcAddressProc) {
		pfnOriginalProc = OriginalGetProcAddressProc(GetModuleHandle(FunctionModule), FunctionName);
	} else {
		pfnOriginalProc = GetProcAddress(GetModuleHandle(FunctionModule), FunctionName);
	}
    if(!pfnOriginalProc) return 0; 

    pDosHeader = (PIMAGE_DOS_HEADER)hModule;

    if ( IsBadReadPtr(pDosHeader, sizeof(IMAGE_DOS_HEADER)) )
        return 0;
    if ( pDosHeader->e_magic != IMAGE_DOS_SIGNATURE )
        return 0;

	pNTHeader = MakePtr(PIMAGE_NT_HEADERS, pDosHeader, pDosHeader->e_lfanew);
	
    if ( IsBadReadPtr(pNTHeader, sizeof(IMAGE_NT_HEADERS)) )
        return 0;

    if ( pNTHeader->Signature != IMAGE_NT_SIGNATURE )
        return 0;

    pImportDesc = MakePtr(PIMAGE_IMPORT_DESCRIPTOR, pDosHeader,
                            pNTHeader->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress);

    if ( pImportDesc == (PIMAGE_IMPORT_DESCRIPTOR)pNTHeader )
        return 0;
	

    while ( pImportDesc->Name )
    {
		
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

	while ( pThunk->u1.Function )
    {
		if ( (DWORD)pThunk->u1.Function == (DWORD)pfnOriginalProc)
        {
            VirtualQuery(pThunk, &mbi_thunk, sizeof(MEMORY_BASIC_INFORMATION));
			if (FALSE == VirtualProtect(mbi_thunk.BaseAddress, mbi_thunk.RegionSize, PAGE_READWRITE, &mbi_thunk.Protect)) {
					return 0;
			}
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

int WINAPI MyWSASend (
  SOCKET s,
  LPWSABUF lpBuffers,
  DWORD dwBufferCount,
  LPDWORD lpNumberOfBytesSent,
  DWORD dwFlags,
  LPWSAOVERLAPPED lpOverlapped,
  LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine
) {
	
	int ret = OriginalWSASendProc(s,lpBuffers,dwBufferCount,lpNumberOfBytesSent,dwFlags,lpOverlapped,lpCompletionRoutine);
	return ret;
}

int WINAPI MyWSASendTo (
  SOCKET s,
  LPWSABUF lpBuffers,
  DWORD dwBufferCount,
  LPDWORD lpNumberOfBytesSent,
  DWORD dwFlags,
  struct sockaddr* lpTo,
  int iToLen,
  LPWSAOVERLAPPED lpOverlapped,
  LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine
) {
	int ret = OriginalWSASendToProc(s,lpBuffers,dwBufferCount,lpNumberOfBytesSent,dwFlags,lpTo,iToLen,lpOverlapped,lpCompletionRoutine);
	return ret;
}

int WINAPI MyWSARecv (
  SOCKET s,
  LPWSABUF lpBuffers,
  DWORD dwBufferCount,
  LPDWORD lpNumberOfBytesRecvd,
  LPDWORD lpFlags,
  LPWSAOVERLAPPED lpOverlapped,
  LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine
  ) {
	
	int ret = OriginalWSARecvProc(s,lpBuffers,dwBufferCount,lpNumberOfBytesRecvd,lpFlags,lpOverlapped,lpCompletionRoutine);
	return ret;
}

int WINAPI MyWSARecvFrom (
  SOCKET s,
  LPWSABUF lpBuffers,
  DWORD dwBufferCount,
  LPDWORD lpNumberOfBytesRecvd,
  LPDWORD lpFlags,
  struct sockaddr* lpFrom,
  LPINT lpFromlen,
  LPWSAOVERLAPPED lpOverlapped,
  LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine
  ) {

	int ret = OriginalWSARecvFromProc(s,lpBuffers,dwBufferCount,lpNumberOfBytesRecvd,lpFlags,lpFrom,lpFromlen,lpOverlapped,lpCompletionRoutine);
	return ret;
}

int WINAPI MySend (
  SOCKET s,
  char* buf,
  int len,
  int flags
  ) {
	
	int ret;
	currentServer = s;
	
	ret = OriginalSendProc(s, buf, 0, flags);

	if (ret != SOCKET_ERROR & len > 0 && falseClient_sendLength + len + 3 < MAX_BUFFER_LENGTH) {
		char* newbuf = (char*)malloc(len+3);
		unsigned short sLen = (unsigned short)len;
		memcpy(newbuf,"S",1);
		memcpy(newbuf+1,&sLen,2);
		memcpy(newbuf+3, buf,len);
		EnterCriticalSection(&falseClient_sendSection);
		memcpy(falseClient_send+falseClient_sendLength,newbuf,len+3);
		falseClient_sendLength += len+3;
		LeaveCriticalSection(&falseClient_sendSection);
		free(newbuf);
	} else {
		return ret;
	}
	return len;
}

int WINAPI MySendTo (
  SOCKET s,
  char* buf,
  int len,
  int flags,
  struct sockaddr* to,
  int tolen
  ) {
	int ret = OriginalSendToProc(s,buf,len,flags, to, tolen);
	return ret;
}

int WINAPI MyRecv (
  SOCKET s,
  char* buf,
  int len,
  int flags
  ) {
	int ret = 0;
	int ret2 = 0;
	currentServer = s;
	if (falseClient_recvInjectLength) {
		EnterCriticalSection(&falseClient_recvInjectSection);
		memcpy(buf,falseClient_recvInject,falseClient_recvInjectLength);
		ret = falseClient_recvInjectLength;
		falseClient_recvInjectLength = 0;
		LeaveCriticalSection(&falseClient_recvInjectSection);
	}
	ret2 = OriginalRecvProc(s, buf+ret, len, flags);
	if (ret2 != SOCKET_ERROR && ret2>0 && falseClient_sendLength + ret2 + 1 < MAX_BUFFER_LENGTH) {
		char* newbuf = (char*)malloc(ret2+3);
		unsigned short sLen = (unsigned short)ret2;
		memcpy(newbuf,"R",1);
		memcpy(newbuf+1, &sLen,2);
		memcpy(newbuf+3, buf+ret,ret2);
		EnterCriticalSection(&falseClient_sendSection);
		memcpy(falseClient_send+falseClient_sendLength,newbuf,ret2+3);
		falseClient_sendLength += ret2+3;
		LeaveCriticalSection(&falseClient_sendSection);
		free(newbuf);
	}
	if (ret2 != SOCKET_ERROR) {
		ret += ret2;
	}
	if (!ret) {
		ret = SOCKET_ERROR;
		WSASetLastError(WSAEWOULDBLOCK);
	}
	return ret;
}

int WINAPI MyRecvFrom (
  SOCKET s,
  char* buf,
  int len,
  int flags,
  struct sockaddr* from,
  int* fromlen
  ) {
	int ret = OriginalRecvFromProc(s,buf,len,flags,from,fromlen);
	return ret;
}

int WINAPI MyConnect (
  SOCKET s,
  struct sockaddr* name,
  int namelen
  ) {
	currentServer = s;
	int ret = OriginalConnectProc(s, name, namelen);
	return ret;
	
}

int WINAPI MyWSAAsyncSelect (
  SOCKET s,
  HWND hWnd,
  unsigned int wMsg,
  long lEvent
  ) {
	currentServer = s;
	OriginalWSAAsyncSelectProc(s,hWnd,wMsg, lEvent);
	return 0;
}

FARPROC WINAPI MyGetProcAddress (
  HMODULE hModule,
  LPCSTR lpProcName
  ) {
	FARPROC ret = OriginalGetProcAddressProc(hModule,lpProcName);
	HMODULE WS2_32 = LoadLibrary("WS2_32.DLL");
	if (hModule == WS2_32) {
		if (!stricmp(lpProcName, "WSASend")) {
			OriginalWSASendProc = (MyWSASendProc)ret;
			ret = (FARPROC)MyWSASend;

		} else if (!stricmp(lpProcName, "WSASendTo")) {
			OriginalWSASendToProc = (MyWSASendToProc)ret;
			ret = (FARPROC)MyWSASendTo;

		} else if (!stricmp(lpProcName, "WSARecv")) {
			OriginalWSARecvProc = (MyWSARecvProc)ret;
			ret = (FARPROC)MyWSARecv;

		} else if (!stricmp(lpProcName, "WSARecvFrom")) {
			OriginalWSARecvFromProc = (MyWSARecvFromProc)ret;
			ret = (FARPROC)MyWSARecvFrom;
	
		} else if (!stricmp(lpProcName, "send")) {
			OriginalSendProc = (MySendProc)ret;
			ret = (FARPROC)MySend;

		} else if (!stricmp(lpProcName, "sendto")) {
			OriginalSendToProc = (MySendToProc)ret;
			ret = (FARPROC)MySendTo;

		} else if (!stricmp(lpProcName, "recv")) {
			OriginalRecvProc = (MyRecvProc)ret;
			ret = (FARPROC)MyRecv;

		} else if (!stricmp(lpProcName, "recvfrom")) {
			OriginalRecvFromProc = (MyRecvFromProc)ret;
			ret = (FARPROC)MyRecvFrom;

		} else if (!stricmp(lpProcName, "connect")) {
			OriginalConnectProc = (MyConnectProc)ret;
			ret = (FARPROC)MyConnect;

		} else if (!stricmp(lpProcName, "WSAAsyncSelect")) {
			OriginalWSAAsyncSelectProc = (MyWSAAsyncSelectProc)ret;
			ret = (FARPROC)MyWSAAsyncSelect;
		}
	}
 	return ret;
}

BOOL DoHookProcs()
{

	OriginalWSASendProc = (MyWSASendProc)
                           HookImportedFunction( GetModuleHandle(0), "WS2_32.DLL", "WSASend", (PROC)MyWSASend);
	
	OriginalWSASendToProc = (MyWSASendToProc)
                           HookImportedFunction( GetModuleHandle(0), "WS2_32.DLL", "WSASendTo", (PROC)MyWSASendTo);

	OriginalWSARecvProc = (MyWSARecvProc)
                           HookImportedFunction( GetModuleHandle(0), "WS2_32.DLL", "WSARecv", (PROC)MyWSARecv);

	OriginalWSARecvFromProc = (MyWSARecvFromProc)
                           HookImportedFunction( GetModuleHandle(0), "WS2_32.DLL", "WSARecvFrom", (PROC)MyWSARecvFrom);

	OriginalSendProc = (MySendProc)
                           HookImportedFunction( GetModuleHandle(0), "WS2_32.DLL", "send", (PROC)MySend);

	OriginalSendToProc = (MySendToProc)
                           HookImportedFunction( GetModuleHandle(0), "WS2_32.DLL", "sendto", (PROC)MySendTo);

	OriginalRecvProc = (MyRecvProc)
                           HookImportedFunction( GetModuleHandle(0), "WS2_32.DLL", "recv", (PROC)MyRecv);

	OriginalRecvFromProc = (MyRecvFromProc)
                           HookImportedFunction( GetModuleHandle(0), "WS2_32.DLL", "recvfrom", (PROC)MyRecvFrom);

	OriginalConnectProc = (MyConnectProc)
                           HookImportedFunction( GetModuleHandle(0), "WS2_32.DLL", "connect", (PROC)MyConnect);

	OriginalWSAAsyncSelectProc = (MyWSAAsyncSelectProc)
                           HookImportedFunction( GetModuleHandle(0), "WS2_32.DLL", "WSAAsyncSelect", (PROC)MyWSAAsyncSelect);

	OriginalGetProcAddressProc = (MyGetProcAddressProc)
                           HookImportedFunction( GetModuleHandle(0), "KERNEL32.DLL", "GetProcAddress", (PROC)MyGetProcAddress);

	return true;
}

BOOL WINAPI DllMain(HINSTANCE hInstance, DWORD dwReason, LPVOID _Reserved)
{
	switch(dwReason)
	{
	case DLL_PROCESS_ATTACH:
		g_hInst = hInstance;
		falseClient_send = (char*)malloc(MAX_BUFFER_LENGTH);
		falseClient_sendLength = 0;
		falseClient_recvInject = (char*)malloc(MAX_BUFFER_LENGTH);
		falseClient_recvInjectLength = 0;
		currentServer = 0;
		WSAStartup(MAKEWORD(2,2),&WSAData);
		InitializeCriticalSection(&falseClient_sendSection);
		InitializeCriticalSection(&falseClient_recvInjectSection);
		CreateThread(0, 0, (LPTHREAD_START_ROUTINE)falseClientCom, 0,	0, &falseClientComId);
		DoHookProcs();
		break;

	case DLL_THREAD_ATTACH:
		break;

	case DLL_THREAD_DETACH:
		break;

	case DLL_PROCESS_DETACH:
		break;
	}

	return true;
}
