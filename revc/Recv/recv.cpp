#define WIN32_LEAN_AND_MEAN
#define _WINSOCK_DEPRECATED_NO_WARNINGS
#include <winsock2.h>
#include <windows.h>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <string>

#pragma comment(lib, "ws2_32.lib")

using namespace std;

// Enum para tipo de pacote
enum e_PacketType {
    RECEIVED = 0,
    SENDED = 1
};

// Ponteiro para a função recv original
typedef int (WINAPI* recv_func_t)(SOCKET s, char* buf, int len, int flags);
recv_func_t original_recv = nullptr;

// Variáveis globais
bool hook_applied = false;
bool koreClientIsAlive = false;
bool keepMainThread = true;
HANDLE hThread;

// Endereços e funções do cliente
DWORD clientSubAddress = 0xB7A330; // Endereço da função no cliente
DWORD CRagConnection_instanceR_address = 0xB7A890; // Instância

// Typedef para a função do cliente
typedef int(__thiscall* SendToClientFunc)(void* CragConnection, size_t size, char* buffer);
SendToClientFunc sendFunc;

typedef void* (__stdcall* originalInstanceR)(void);
originalInstanceR instanceR;

// Sockets e buffers
static SOCKET koreClient = INVALID_SOCKET;
static SOCKET roServer = INVALID_SOCKET;
static string roSendBuf("");
static string xkoreSendBuf("");
bool imalive = false;

// Constantes
#define BUF_SIZE 1024 * 32
int XKORE_SERVER_PORT = 2350; // Agora é variável
#define TIMEOUT 600000
#define RECONNECT_INTERVAL 3000
#define PING_INTERVAL 5000
#define SLEEP_TIME 10
#define SF_CLOSED -1

// Estrutura de pacote
struct Packet {
    char ID;
    unsigned short len;
    char* data;
};

// Declaração das funções
DWORD WINAPI KeyboardMonitorThread(LPVOID lpParam);
DWORD WINAPI koreConnectionMain(LPVOID lpParam);
bool isConnected(SOCKET s);
SOCKET createSocket(int port);
int readSocket(SOCKET s, char* buf, int len);
Packet* unpackPacket(const char* buf, int buflen, int& next);
void processPacket(Packet* packet);

// Console para debug
void AllocateConsole() {
    AllocConsole();
    freopen_s((FILE**)stdout, "CONOUT$", "w", stdout);
    freopen_s((FILE**)stderr, "CONOUT$", "w", stderr);
    freopen_s((FILE**)stdin, "CONIN$", "r", stdin);
#ifdef UNICODE
    SetConsoleTitle(L"Debug Console"); // Wide string for Visual Studio Unicode
#else
    SetConsoleTitle("Debug Console"); // ANSI string for gcc/MinGW
#endif
}

// Função para debug
void debug(const char* msg) {
    std::cout << "[DEBUG] " << msg << std::endl;
}

// Função para converter bytes para hex
std::string BytesToHex(const char* data, int length) {
    std::stringstream ss;
    ss << std::hex << std::setfill('0');
    for (int i = 0; i < length && i < 64; ++i) {
        ss << std::setw(2) << static_cast<unsigned char>(data[i]) << " ";
        if ((i + 1) % 16 == 0) ss << "\n";
    }
    return ss.str();
}

// Função para enviar dados para Kore
void sendDataToKore(char* buffer, int len, e_PacketType type) {
    bool isAlive = koreClientIsAlive;
    if (isAlive) {
        char* newbuf = (char*)malloc(len + 3);
        unsigned short sLen = (unsigned short)len;
        if (type == e_PacketType::RECEIVED) {
            memcpy(newbuf, "R", 1);
        }
        else {
            memcpy(newbuf, "S", 1);
        }
        memcpy(newbuf + 1, &sLen, 2);
        memcpy(newbuf + 3, buffer, len);
        xkoreSendBuf.append(newbuf, len + 3);
        free(newbuf);

        std::cout << "Dados adicionados ao buffer (" << len + 3 << " bytes, tipo: " << (type == RECEIVED ? "R" : "S") << ")" << std::endl;
    }
}

// Nossa função recv hookada
int WINAPI hooked_recv(SOCKET s, char* buf, int len, int flags) {
    std::cout << ">>> RECV HOOK CHAMADO <<<" << std::endl;

    // Chama a função original
    int result = original_recv(s, buf, len, flags);

    if (result > 0) {
        std::cout << "=== RECV INTERCEPTED ===" << std::endl;
        std::cout << "Socket: " << s << std::endl;
        std::cout << "Length: " << result << " bytes" << std::endl;
        std::cout << "Data (hex):\n" << BytesToHex(buf, result) << std::endl;

        // Salva o socket do servidor RO
        roServer = s;

        // Envia dados para Kore
        sendDataToKore(buf, result, e_PacketType::RECEIVED);

        std::cout << "===================" << std::endl;
    }

    return result;
}

// Função para aplicar o hook
bool ApplyHook() {
    DWORD recv_ptr_address = 0x144DDB8;

    std::cout << "Tentando aplicar hook no endereço: 0x" << std::hex << recv_ptr_address << std::endl;

    if (IsBadReadPtr((void*)(uintptr_t)recv_ptr_address, sizeof(DWORD))) {
        std::cout << "ERRO: Endereço inválido para leitura!" << std::endl;
        return false;
    }

    original_recv = *(recv_func_t*)(uintptr_t)recv_ptr_address;
    std::cout << "Ponteiro original recv: 0x" << std::hex << (uintptr_t)original_recv << std::endl;

    if (original_recv == nullptr) {
        std::cout << "ERRO: Ponteiro original é nulo!" << std::endl;
        return false;
    }

    *(recv_func_t*)(uintptr_t)recv_ptr_address = hooked_recv;
    std::cout << "Novo ponteiro (hook): 0x" << std::hex << (uintptr_t)hooked_recv << std::endl;

    recv_func_t current_ptr = *(recv_func_t*)(uintptr_t)recv_ptr_address;
    if (current_ptr == hooked_recv) {
        std::cout << "Hook aplicado com sucesso!" << std::endl;
        return true;
    }
    else {
        std::cout << "ERRO: Hook não foi aplicado corretamente!" << std::endl;
        return false;
    }
}

// Função para remover o hook
void RemoveHook() {
    if (original_recv) {
        DWORD recv_ptr_address = 0x144DDB8;
        *(recv_func_t*)(uintptr_t)recv_ptr_address = original_recv;
        std::cout << "Hook removido!" << std::endl;
    }
}

// Verificar se socket está conectado
bool isConnected(SOCKET s) {
    if (s == INVALID_SOCKET) return false;

    fd_set readfds;
    FD_ZERO(&readfds);
    FD_SET(s, &readfds);

    timeval timeout = { 0, 0 };
    int result = select(0, &readfds, NULL, NULL, &timeout);

    if (result == SOCKET_ERROR) return false;
    return true;
}

// Criar socket
SOCKET createSocket(int port) {
    sockaddr_in addr;
    SOCKET sock;
    DWORD arg = 1;

    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock == INVALID_SOCKET)
        return INVALID_SOCKET;

    ioctlsocket(sock, FIONBIO, &arg);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");

    while (connect(sock, (struct sockaddr*)&addr, sizeof(sockaddr_in)) == SOCKET_ERROR) {
        if (WSAGetLastError() == WSAEISCONN)
            break;
        else if (WSAGetLastError() != WSAEWOULDBLOCK) {
            closesocket(sock);
            return INVALID_SOCKET;
        }
        else
            Sleep(10);
    }

    // Volta para modo bloqueante
    arg = 0;
    ioctlsocket(sock, FIONBIO, &arg);

    return sock;
}

// Ler dados do socket
int readSocket(SOCKET s, char* buf, int len) {
    fd_set readfds;
    FD_ZERO(&readfds);
    FD_SET(s, &readfds);

    timeval timeout = { 0, 0 };
    int result = select(0, &readfds, NULL, NULL, &timeout);

    if (result == SOCKET_ERROR) return SF_CLOSED;
    if (result == 0) return 0; // Timeout

    int bytes = recv(s, buf, len, 0);
    if (bytes == 0 || bytes == SOCKET_ERROR) return SF_CLOSED;

    return bytes;
}

// Função para desempacotar pacotes
Packet* unpackPacket(const char* buf, int buflen, int& next) {
    if (buflen < 3) return NULL; // Precisa de pelo menos 3 bytes (ID + length)

    char id = buf[0];
    unsigned short len = *(unsigned short*)(buf + 1);

    if (buflen < 3 + len) return NULL; // Pacote incompleto

    Packet* packet = (Packet*)malloc(sizeof(Packet));
    packet->ID = id;
    packet->len = len;
    packet->data = (char*)malloc(len);
    memcpy(packet->data, buf + 3, len);

    next = 3 + len;
    return packet;
}

// Processar pacote recebido do Kore
void processPacket(Packet* packet) {
    sendFunc = (SendToClientFunc)(uintptr_t)(clientSubAddress);
    instanceR = (originalInstanceR)(uintptr_t)(CRagConnection_instanceR_address);
    switch (packet->ID) {
    case 'S': // Enviar pacote para o servidor RO
        debug("Sending Data From Openkore to Server...");
        if (roServer != INVALID_SOCKET && isConnected(roServer)) {
            sendFunc(instanceR(), packet->len, packet->data);
            std::cout << "Pacote enviado para servidor RO (" << packet->len << " bytes)" << std::endl;
        }
        else {
            std::cout << "ERRO: Socket do servidor RO não disponível" << std::endl;
        }
        break;

    case 'R': // Injetar pacote no cliente RO usando função interna
        break;

    case 'K': default: // Keep-alive
        debug("Received Keep-Alive Packet...");
        break;
    }
}

// Thread principal de conexão com Kore
DWORD WINAPI koreConnectionMain(LPVOID lpParam) {
    char buf[BUF_SIZE + 1];
    char pingPacket[3];
    unsigned short pingPacketLength = 0;
    DWORD koreClientTimeout, koreClientPingTimeout, reconnectTimeout;
    string koreClientRecvBuf;

    debug("Thread started...");
    koreClientTimeout = GetTickCount();
    koreClientPingTimeout = GetTickCount();
    reconnectTimeout = 0;

    memcpy(pingPacket, "K", 1);
    memcpy(pingPacket + 1, &pingPacketLength, 2);

    while (keepMainThread) {
        bool isAlive = koreClientIsAlive;
        bool isAliveChanged = false;

        // Tentar conectar ao servidor X-Kore se necessário
        koreClientIsAlive = koreClient != INVALID_SOCKET;

        if ((!isAlive || !isConnected(koreClient) || GetTickCount() - koreClientTimeout > TIMEOUT)
            && GetTickCount() - reconnectTimeout > RECONNECT_INTERVAL) {
            debug("Connecting to X-Kore server...");

            if (koreClient != INVALID_SOCKET)
                closesocket(koreClient);
            koreClient = createSocket(XKORE_SERVER_PORT);

            isAlive = koreClient != INVALID_SOCKET;
            isAliveChanged = true;
            if (!isAlive)
                debug("Failed...");
            else
                koreClientTimeout = GetTickCount();
            reconnectTimeout = GetTickCount();
        }

        // Receber dados do servidor X-Kore
        if (isAlive) {
            if (!imalive) {
                debug("Connected to xKore-Server");
                imalive = true;
            }

            int ret = readSocket(koreClient, buf, BUF_SIZE);
            if (ret == SF_CLOSED) {
                debug("X-Kore server exited");
                closesocket(koreClient);
                koreClient = INVALID_SOCKET;
                isAlive = false;
                isAliveChanged = true;
                imalive = false;
            }
            else if (ret > 0) {
                // Dados disponíveis
                Packet* packet;
                int next = 0;
                debug("Received Packet from OpenKore...");
                koreClientRecvBuf.append(buf, ret);

                while ((packet = unpackPacket(koreClientRecvBuf.c_str(), (int)koreClientRecvBuf.size(), next))) {
                    // Pacote está completo
                    processPacket(packet);
                    free(packet->data);
                    free(packet);
                    koreClientRecvBuf.erase(0, next);
                }

                koreClientTimeout = GetTickCount();
            }
        }

        // Enviar dados para o servidor X-Kore
        if (xkoreSendBuf.size()) {
            if (isAlive) {
                send(koreClient, (char*)xkoreSendBuf.c_str(), (int)xkoreSendBuf.size(), 0);
            }
            else {
                // Kore não está rodando; enviar diretamente para o servidor RO
                Packet* packet;
                int next;

                while ((packet = unpackPacket(xkoreSendBuf.c_str(), (int)xkoreSendBuf.size(), next))) {
                    if (packet->ID == 'S')
                        send(roServer, (char*)packet->data, packet->len, 0);
                    free(packet->data);
                    free(packet);
                    xkoreSendBuf.erase(0, next);
                }
            }
            xkoreSendBuf.clear();
        }

        // Ping para manter conexão viva
        if (koreClientIsAlive && GetTickCount() - koreClientPingTimeout > PING_INTERVAL) {
            send(koreClient, pingPacket, 3, 0);
            koreClientPingTimeout = GetTickCount();
        }

        if (isAliveChanged) {
            koreClientIsAlive = isAlive;
        }

        Sleep(SLEEP_TIME);
    }
    return 0;
}

// Thread para monitorar teclado
DWORD WINAPI KeyboardMonitorThread(LPVOID lpParam) {
    std::cout << "Thread de monitoramento iniciada. Pressione F11 para aplicar hook..." << std::endl;

    while (keepMainThread) {
        if (GetAsyncKeyState(VK_F11) & 0x8000) {
            if (!hook_applied) {
                std::cout << "\nF11 pressionado! Aplicando hook..." << std::endl;
                if (ApplyHook()) {
                    hook_applied = true;
                    std::cout << "Hook aplicado! Pressione F12 para remover hook." << std::endl;
                }
            }
            Sleep(500); // Evita múltiplas ativações
        }

        if (GetAsyncKeyState(VK_F12) & 0x8000) {
            if (hook_applied) {
                std::cout << "\nF12 pressionado! Removendo hook..." << std::endl;
                RemoveHook();
                hook_applied = false;
                std::cout << "Hook removido! Pressione F11 para aplicar novamente." << std::endl;
            }
            Sleep(500); // Evita múltiplas ativações
        }

        Sleep(100);
    }
    return 0;
}

// Função para obter porta do usuário
int getUserPort() {
    int port = 2350; // valor padrão
    char input[256];
    
    std::cout << "Digite a porta do X-Kore (padrão 2350): ";
    if (fgets(input, sizeof(input), stdin)) {
        int inputPort = atoi(input);
        if (inputPort > 0 && inputPort <= 65535) {
            port = inputPort;
        }
    }
    
    std::cout << "Usando porta: " << port << std::endl;
    return port;
}

// Função init
void init() {
    AllocateConsole();
    std::cout << "=== RECV HOOK DLL ===" << std::endl;
    std::cout << "Arquitetura: x86 (32-bit)" << std::endl;
    
    // Solicita porta do usuário
    XKORE_SERVER_PORT = getUserPort();
    
    std::cout << "\nControles:" << std::endl;
    std::cout << "F11 - Aplicar hook" << std::endl;
    std::cout << "F12 - Remover hook" << std::endl;
    std::cout << "====================" << std::endl;

    // Inicializa Winsock
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);

    debug("Creating Main thread...");
    hThread = CreateThread(NULL, 0, koreConnectionMain, NULL, 0, NULL);
    if (hThread) {
        debug("Main Thread created...");
    }
    else {
        debug("Failed to Create Thread...");
    }

    // Cria thread para monitorar teclado
    HANDLE hKeyThread = CreateThread(NULL, 0, KeyboardMonitorThread, NULL, 0, NULL);
    if (hKeyThread == NULL) {
        std::cout << "Erro ao criar thread de monitoramento!" << std::endl;
    }
}

// Função finish
void finish() {
    debug("Closing threads...");
    keepMainThread = false;

    if (hook_applied) {
        RemoveHook();
    }

    if (koreClient != INVALID_SOCKET) {
        closesocket(koreClient);
    }

    WSACleanup();
}

// DLL Entry Point
BOOL APIENTRY DllMain(HMODULE hModule,
    DWORD  ul_reason_for_call,
    LPVOID lpReserved
)
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
        init();
        break;
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:;
    }
    return TRUE;
}