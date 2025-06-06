// File contributed by #Francisco Wallison, #megafuji, #gaaradodesertoo, originally by #__codeplay
#define WIN32_LEAN_AND_MEAN
#define _WINSOCK_DEPRECATED_NO_WARNINGS
#include <winsock2.h>
#include <windows.h>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <string>
#include <fstream>
#include <unordered_map>
#include <algorithm>
#include <cstring>

#pragma comment(lib, "ws2_32.lib")

using namespace std;

// Enum para tipo de pacote
enum e_PacketType {
    RECEIVED = 0,
    SENDED   = 1
};

// Ponteiro para a função recv original
typedef int (WINAPI* recv_func_t)(SOCKET s, char* buf, int len, int flags);
recv_func_t original_recv = nullptr;

// Variáveis globais de configuração (serão lidas de config_recv.txt)
DWORD clientSubAddress;                 // antes: 0xB7EF50
DWORD CRagConnection_instanceR_address; // antes: 0xB7F4B0
DWORD recvPtrAddress;                   // antes, dentro de ApplyHook(): 0x1455BB8

// **NOVO**: IP e porta do servidor xKore
std::string koreServerIP;
DWORD koreServerPort;

// **NOVO**: Configurações de hotkeys
std::string applyHookKey;
std::string removeHookKey;
bool applyHookRequiresCtrl = false;
bool applyHookRequiresShift = false;
bool removeHookRequiresCtrl = false;
bool removeHookRequiresShift = false;
int applyHookVK = VK_F11;
int removeHookVK = VK_F12;

// Configuração para múltiplos clientes
bool allowMultiClient = false;

// Variáveis globais de estado
bool hook_applied        = false;
bool koreClientIsAlive   = false;
bool keepMainThread      = true;
HANDLE hThread;

// Typedef para a função de envio internamente no cliente
typedef int(__thiscall* SendToClientFunc)(void* CragConnection, size_t size, char* buffer);
SendToClientFunc sendFunc;

typedef void* (__stdcall* originalInstanceR)(void);
originalInstanceR instanceR;

// Sockets e buffers
static SOCKET koreClient    = INVALID_SOCKET;
static SOCKET roServer      = INVALID_SOCKET;
static string roSendBuf     = "";
static string xkoreSendBuf  = "";
bool imalive                = false;

// Constantes
#define BUF_SIZE             1024 * 32
#define TIMEOUT              600000
#define RECONNECT_INTERVAL   3000
#define PING_INTERVAL        5000
#define SLEEP_TIME           10
#define SF_CLOSED            -1

// Estrutura de pacote
struct Packet {
    char ID;
    unsigned short len;
    char* data;
};

// Protótipos das funções
DWORD WINAPI KeyboardMonitorThread(LPVOID lpParam);
DWORD WINAPI koreConnectionMain(LPVOID lpParam);
bool isConnected(SOCKET s);
SOCKET createSocket(const std::string& ip, int port);
int readSocket(SOCKET s, char* buf, int len);
Packet* unpackPacket(const char* buf, int buflen, int& next);
void processPacket(Packet* packet);

// Console para depuração
void AllocateConsole() {
    AllocConsole();
    freopen_s((FILE**)stdout, "CONOUT$", "w", stdout);
    freopen_s((FILE**)stderr, "CONOUT$", "w", stderr);
    freopen_s((FILE**)stdin,  "CONIN$",  "r", stdin);
#ifdef UNICODE
    SetConsoleTitle(L"Console de Depuração");
#else
    SetConsoleTitle("Console de Depuração");
#endif
}

// Função para depuração
void debug(const char* msg) {
    std::cout << "[DEPURAÇÃO] " << msg << std::endl;
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
    if (koreClientIsAlive) {
        char* newbuf        = (char*)malloc(len + 3);
        unsigned short sLen = (unsigned short)len;

        // Prefixo "R" ou "S"
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

        std::cout << "Dados adicionados ao buffer (" << (len + 3)
                  << " bytes, tipo: " << (type == RECEIVED ? "R" : "S") << ")" << std::endl;
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

// Função para converter string de tecla em código VK
int ParseKeyString(const std::string& keyStr, bool& requiresCtrl, bool& requiresShift) {
    std::string key = keyStr;
    requiresCtrl = false;
    requiresShift = false;
    
    // Converte para maiúscula para facilitar comparação
    std::transform(key.begin(), key.end(), key.begin(), ::toupper);
    
    // Verifica modificadores
    if (key.find("CTRL+") == 0) {
        requiresCtrl = true;
        key = key.substr(5); // Remove "CTRL+"
    }
    if (key.find("SHIFT+") == 0) {
        requiresShift = true;
        key = key.substr(6); // Remove "SHIFT+"
    }
    if (key.find("CTRL+SHIFT+") == 0) {
        requiresCtrl = true;
        requiresShift = true;
        key = key.substr(11); // Remove "CTRL+SHIFT+"
    }
    if (key.find("SHIFT+CTRL+") == 0) {
        requiresCtrl = true;
        requiresShift = true;
        key = key.substr(11); // Remove "SHIFT+CTRL+"
    }
    
    // Mapeamento de teclas F1-F12
    if (key == "F1") return VK_F1;
    if (key == "F2") return VK_F2;
    if (key == "F3") return VK_F3;
    if (key == "F4") return VK_F4;
    if (key == "F5") return VK_F5;
    if (key == "F6") return VK_F6;
    if (key == "F7") return VK_F7;
    if (key == "F8") return VK_F8;
    if (key == "F9") return VK_F9;
    if (key == "F10") return VK_F10;
    if (key == "F11") return VK_F11;
    if (key == "F12") return VK_F12;
    
    // Teclas especiais adicionais
    if (key == "ESC" || key == "ESCAPE") return VK_ESCAPE;
    if (key == "SPACE") return VK_SPACE;
    if (key == "ENTER") return VK_RETURN;
    if (key == "TAB") return VK_TAB;
    if (key == "INSERT") return VK_INSERT;
    if (key == "DELETE") return VK_DELETE;
    if (key == "HOME") return VK_HOME;
    if (key == "END") return VK_END;
    if (key == "PAGEUP") return VK_PRIOR;
    if (key == "PAGEDOWN") return VK_NEXT;
    if (key == "LEFT") return VK_LEFT;
    if (key == "RIGHT") return VK_RIGHT;
    if (key == "UP") return VK_UP;
    if (key == "DOWN") return VK_DOWN;
    
    // Teclas alfanuméricas (A-Z, 0-9)
    if (key.length() == 1) {
        char c = key[0];
        if (c >= 'A' && c <= 'Z') {
            return c; // VK codes para A-Z são os mesmos que ASCII
        }
        if (c >= '0' && c <= '9') {
            return c; // VK codes para 0-9 são os mesmos que ASCII
        }
    }
    
    // Se não encontrou, retorna F11 como padrão
    return VK_F11;
}

// Função para criar arquivo de configuração padrão
bool CreateDefaultConfig(const std::string& filename) {
    std::ofstream fout(filename);
    if (!fout.is_open()) {
        std::cout << "[ERRO] Não foi possível criar o arquivo de configuração: " << filename << std::endl;
        return false;
    }

    fout << "# Arquivo de configuração para recv.cpp\n";
    fout << "# Endereços de memória do cliente RO (valores em hexadecimal)\n";
    fout << "clientSubAddress=B7EF50\n";
    fout << "instanceRAddress=B7F4B0\n";
    fout << "recvPtrAddress=1455BB8\n";
    fout << "\n";
    fout << "# Configurações do servidor xKore\n";
    fout << "koreServerIP=127.0.0.1\n";
    fout << "koreServerPort=2350\n";
    fout << "\n";
    fout << "# Configurações de hotkeys (opcional)\n";
    fout << "# Formato: [Ctrl+][Shift+]TECLA\n";
    fout << "# Teclas disponíveis: F1-F12, A-Z, 0-9, ESC, SPACE, ENTER, TAB, INSERT, DELETE, HOME, END, PAGEUP, PAGEDOWN, LEFT, RIGHT, UP, DOWN\n";
    fout << "# Exemplos: F1, Ctrl+F5, Shift+F2, Ctrl+Shift+F9, Ctrl+A, Alt+Tab (não suportado), etc.\n";
    fout << "applyHookKey=Ctrl+F11\n";
    fout << "removeHookKey=Ctrl+F12\n";
    fout << "\n";
    fout << "# Configuração para múltiplos clientes\n";
    fout << "# Se true, pergunta a porta no terminal a cada execução\n";
    fout << "# Se false, usa sempre a porta padrão do koreServerPort\n";
    fout << "allowMultiClient=true\n";

    fout.close();
    
    std::cout << "[INFO] Arquivo de configuração padrão criado: " << filename << std::endl;
    return true;
}

// Função para ler o arquivo de configuração
bool LoadConfig(const std::string& filename) {
    std::ifstream fin(filename);
    if (!fin.is_open()) {
        std::cout << "[INFO] Arquivo de configuração não encontrado. Criando arquivo padrão..." << std::endl;
        if (!CreateDefaultConfig(filename)) {
            return false;
        }
        
        // Tenta abrir novamente após criar
        fin.open(filename);
        if (!fin.is_open()) {
            std::cout << "[ERRO] Não foi possível abrir o arquivo de configuração criado: " << filename << std::endl;
            return false;
        }
    }

    std::string line;
    // Usamos um map temporário para achar cada chave
    std::unordered_map<std::string, std::string> mapa;
    while (std::getline(fin, line)) {
        // Ignora linhas vazias ou que comecem com '#' ou ';'
        if (line.empty()) continue;
        if (line[0] == '#' || line[0] == ';') continue;

        // Encontra o '='
        size_t pos = line.find('=');
        if (pos == std::string::npos) continue;

        std::string chave = line.substr(0, pos);
        std::string valor = line.substr(pos + 1);

        // Remove espaços em excesso (caso haja)
        while (!chave.empty() && isspace(chave.back())) chave.pop_back();
        while (!valor.empty() && isspace(valor.front())) valor.erase(0, 1);
        while (!valor.empty() && isspace(valor.back())) valor.pop_back();

        mapa[chave] = valor;
    }
    fin.close();

    // Verifica existência das chaves obrigatórias
    if (mapa.count("clientSubAddress") == 0 ||
        mapa.count("instanceRAddress") == 0 ||
        mapa.count("recvPtrAddress") == 0 ||
        mapa.count("koreServerIP") == 0 ||
        mapa.count("koreServerPort") == 0)
    {
        std::cout << "[ERRO] Chaves faltando em config_recv.txt. Precisamos de:\n"
            << "  clientSubAddress\n"
            << "  instanceRAddress\n"
            << "  recvPtrAddress\n"
            << "  koreServerIP\n"
            << "  koreServerPort\n";
        return false;
    }

    // Agora converte cada valor
    try {
        // Conversão dos hex para DWORD
        clientSubAddress = static_cast<DWORD>(std::stoul(mapa.at("clientSubAddress"), nullptr, 16));
        CRagConnection_instanceR_address = static_cast<DWORD>(std::stoul(mapa.at("instanceRAddress"), nullptr, 16));
        recvPtrAddress = static_cast<DWORD>(std::stoul(mapa.at("recvPtrAddress"), nullptr, 16));

        // Novos valores: IP e porta
        koreServerIP = mapa.at("koreServerIP");
        koreServerPort = static_cast<DWORD>(std::stoul(mapa.at("koreServerPort"), nullptr, 10));

        // Configurações de hotkeys (opcional, com valores padrão)
        applyHookKey = mapa.count("applyHookKey") > 0 ? mapa.at("applyHookKey") : "Ctrl+F11";
        removeHookKey = mapa.count("removeHookKey") > 0 ? mapa.at("removeHookKey") : "Ctrl+F12";
        
        // Processa as strings das teclas
        applyHookVK = ParseKeyString(applyHookKey, applyHookRequiresCtrl, applyHookRequiresShift);
        removeHookVK = ParseKeyString(removeHookKey, removeHookRequiresCtrl, removeHookRequiresShift);

        // Configuração de múltiplos clientes (opcional, padrão false)
        if (mapa.count("allowMultiClient") > 0) {
            std::string allowMultiStr = mapa.at("allowMultiClient");
            std::transform(allowMultiStr.begin(), allowMultiStr.end(), allowMultiStr.begin(), ::tolower);
            allowMultiClient = (allowMultiStr == "true" || allowMultiStr == "1" || allowMultiStr == "yes");
        }
    }
    catch (std::exception& e) {
        std::cout << "[ERRO] Exceção ao converter valor: " << e.what() << std::endl;
        return false;
    }

    std::cout << "[INFO] Configuration loaded successfully:\n\n"
        << "  clientSubAddress = 0x" << std::hex << clientSubAddress << "\n"
        << "  instanceRAddress = 0x" << std::hex << CRagConnection_instanceR_address << "\n"
        << "  recvPtrAddress   = 0x" << std::hex << recvPtrAddress << std::dec << "\n"
        << "  koreServerIP     = " << koreServerIP << "\n"
        << "  koreServerPort   = " << koreServerPort << "\n"
        << "  applyHookKey     = " << applyHookKey << "\n"
        << "  removeHookKey    = " << removeHookKey << "\n"
        << "  allowMultiClient = " << (allowMultiClient ? "true" : "false") << std::endl;

    return true;
}

// Função para aplicar o hook (agora usa recvPtrAddress em vez de valor fixo)
bool ApplyHook() {
    DWORD recv_ptr_address = recvPtrAddress; // lido do config

    std::cout << "Attempting to apply hook at address: 0x" << std::hex << recv_ptr_address << std::dec << std::endl;

    if (IsBadReadPtr((void*)recv_ptr_address, sizeof(DWORD))) {
        std::cout << "ERRO: Endereço inválido para leitura!" << std::endl;
        return false;
    }

    original_recv = *(recv_func_t*)recv_ptr_address;
    std::cout << "Original recv pointer: 0x" << std::hex << (DWORD)original_recv << std::dec << std::endl;

    if (original_recv == nullptr) {
        std::cout << "ERRO: Ponteiro original é nulo!" << std::endl;
        return false;
    }

    *(recv_func_t*)recv_ptr_address = hooked_recv;
    std::cout << "New pointer (hook): 0x" << std::hex << (DWORD)hooked_recv << std::dec << std::endl;

    recv_func_t current_ptr = *(recv_func_t*)recv_ptr_address;
    if (current_ptr == hooked_recv) {
        std::cout << "Hook applied successfully!" << std::endl;
        return true;
    }
    else {
        std::cout << "ERRO: Hook não foi aplicado corretamente!" << std::endl;
        return false;
    }
}

// Função para remover o hook (usa também recvPtrAddress)
void RemoveHook() {
    if (original_recv) {
        DWORD recv_ptr_address = recvPtrAddress;
        *(recv_func_t*)recv_ptr_address = original_recv;
        std::cout << "Hook removido!" << std::endl;
    }
}

// Verificar se socket está conectado
bool isConnected(SOCKET s) {
    if (s == INVALID_SOCKET) return false;

    fd_set  readfds;
    FD_ZERO(&readfds);
    FD_SET(s, &readfds);

    timeval timeout = { 0, 0 };
    int result = select(0, &readfds, NULL, NULL, &timeout);

    if (result == SOCKET_ERROR) return false;
    return true;
}

// Criar socket usando IP e porta passados como parâmetros
SOCKET createSocket(const std::string& ip, int port) {
    sockaddr_in addr;
    SOCKET sock;
    DWORD arg = 1;

    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock == INVALID_SOCKET)
        return INVALID_SOCKET;

    ioctlsocket(sock, FIONBIO, &arg);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(static_cast<u_short>(port));
    addr.sin_addr.s_addr = inet_addr(ip.c_str());

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
    fd_set  readfds;
    FD_ZERO(&readfds);
    FD_SET(s, &readfds);

    timeval timeout = { 0, 0 };
    int result = select(0, &readfds, NULL, NULL, &timeout);

    if (result == SOCKET_ERROR) return SF_CLOSED;
    if (result == 0)            return 0; // Timeout

    int bytes = recv(s, buf, len, 0);
    if (bytes == 0 || bytes == SOCKET_ERROR) return SF_CLOSED;

    return bytes;
}

// Função para desempacotar pacotes
Packet* unpackPacket(const char* buf, int buflen, int& next) {
    if (buflen < 3) return NULL; // Precisa de pelo menos 3 bytes (ID + comprimento)

    char            id  = buf[0];
    unsigned short len = *(unsigned short*)(buf + 1);

    if (buflen < 3 + len) return NULL; // Pacote incompleto

    Packet* packet = (Packet*)malloc(sizeof(Packet));
    packet->ID   = id;
    packet->len  = len;
    packet->data = (char*)malloc(len);
    memcpy(packet->data, buf + 3, len);

    next = 3 + len;
    return packet;
}

// Processar pacote recebido do Kore (igual)
void processPacket(Packet* packet) {
    sendFunc = (SendToClientFunc)(clientSubAddress);
    instanceR = (originalInstanceR)(CRagConnection_instanceR_address);
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
        // (Opcional: implementar lógica de injeção, se necessário)
        break;

    case 'K': default: // Keep-alive
        debug("Received Keep-Alive Packet...");
        break;
    }
}

// Thread principal de conexão com Kore (ajustada para usar koreServerIP e koreServerPort)
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

    // Monta o pacote de ping
    memcpy(pingPacket, "K", 1);
    memcpy(pingPacket + 1, &pingPacketLength, 2);

    // NOVO: controla se já imprimimos "Aguardando Openkore"
    bool waitingPrinted = false;

    while (keepMainThread) {
        bool isAlive = koreClientIsAlive;
        bool isAliveChanged = false;

        // Se ainda não conectado e não marcamos a mensagem, imprimimos "Aplique o Hook e abra o Openkore" UMA ÚNICA VEZ
        if ((!isAlive || !isConnected(koreClient)) && !waitingPrinted) {
            std::cout << "\n- If you have already applied the hook (" << applyHookKey << "), open Openkore." << std::endl;
            waitingPrinted = true;
        }

        // Tentar conectar ao servidor xKore se necessário
        koreClientIsAlive = koreClient != INVALID_SOCKET;

        if ((!isAlive || !isConnected(koreClient) || GetTickCount() - koreClientTimeout > TIMEOUT)
            && GetTickCount() - reconnectTimeout > RECONNECT_INTERVAL) {

            // Ao entrar aqui, já temos impresso "Aguardando Openkore" (se ainda não estivesse conectado)
            // Faz a tentativa de conectar sem imprimir debug("Connecting...") nem debug("Failed...").

            if (koreClient != INVALID_SOCKET) {
                closesocket(koreClient);
            }

            // Usa IP e porta lidos do config
            koreClient = createSocket(koreServerIP, koreServerPort);

            isAlive = koreClient != INVALID_SOCKET;
            isAliveChanged = true;
            if (isAlive) {
                // Conectou com sucesso: resetamos o timeout e liberamos a flag de aguardando
                koreClientTimeout = GetTickCount();
                waitingPrinted = false;
            }
            reconnectTimeout = GetTickCount();
        }

        // Receber dados do servidor xKore
        if (isAlive) {
            if (!imalive) {
                debug("Connected to xKore-Server");  // Imprime apenas UMA VEZ, ao receber o primeiro pacote
                imalive = true;
            }

            int ret = readSocket(koreClient, buf, BUF_SIZE);
            if (ret == SF_CLOSED) {
                debug("xKore server exited");
                closesocket(koreClient);
                koreClient = INVALID_SOCKET;
                isAlive = false;
                isAliveChanged = true;
                imalive = false;
            }
            else if (ret > 0) {
                Packet* packet;
                int next = 0;
                debug("Received Packet from xKore...");
                koreClientRecvBuf.append(buf, ret);

                while ((packet = unpackPacket(koreClientRecvBuf.c_str(), koreClientRecvBuf.size(), next))) {
                    processPacket(packet);
                    free(packet->data);
                    free(packet);
                    koreClientRecvBuf.erase(0, next);
                }

                koreClientTimeout = GetTickCount();
            }
        }

        // Enviar dados para o servidor xKore
        if (xkoreSendBuf.size()) {
            if (isAlive) {
                send(koreClient, (char*)xkoreSendBuf.c_str(), xkoreSendBuf.size(), 0);
            }
            else {
                // xKore não está rodando; envia direto para o servidor RO
                Packet* packet;
                int next;

                while ((packet = unpackPacket(xkoreSendBuf.c_str(), xkoreSendBuf.size(), next))) {
                    if (packet->ID == 'S')
                        send(roServer, (char*)packet->data, packet->len, 0);
                    free(packet->data);
                    free(packet);
                    koreClientRecvBuf.erase(0, next);
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

// Thread para monitorar teclado (hotkeys customizáveis via config)
DWORD WINAPI KeyboardMonitorThread(LPVOID lpParam) {
    while (keepMainThread) {
        // Verifica a tecla de aplicar hook
        bool applyKeyPressed = (GetAsyncKeyState(applyHookVK) & 0x8000) != 0;
        bool applyCtrlOk = !applyHookRequiresCtrl || (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
        bool applyShiftOk = !applyHookRequiresShift || (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;
        
        if (applyKeyPressed && applyCtrlOk && applyShiftOk) {
            if (!hook_applied) {
                std::cout << "\n" << applyHookKey << " pressionado! Aplicando hook..." << std::endl;
                if (ApplyHook()) {
                    hook_applied = true;
                    std::cout << "Hook aplicado! Pressione " << removeHookKey << " para remover hook." << std::endl;
                }
            }
            Sleep(500); // Evita múltiplas ativações
        }

        // Verifica a tecla de remover hook
        bool removeKeyPressed = (GetAsyncKeyState(removeHookVK) & 0x8000) != 0;
        bool removeCtrlOk = !removeHookRequiresCtrl || (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
        bool removeShiftOk = !removeHookRequiresShift || (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;
        
        if (removeKeyPressed && removeCtrlOk && removeShiftOk) {
            if (hook_applied) {
                std::cout << "\n" << removeHookKey << " pressionado! Removendo hook..." << std::endl;
                RemoveHook();
                hook_applied = false;
                std::cout << "Hook removido! Pressione " << applyHookKey << " para aplicar novamente." << std::endl;
            }
            Sleep(500); // Evita múltiplas ativações
        }

        Sleep(100);
    }
    return 0;
}

// Função para solicitar porta do usuário (para allowMultiClient=true)
DWORD GetUserPort() {
    char input[256];
    std::cout << "\n[MULTI-CLIENT MODE]" << std::endl;
    std::cout << "Digite a porta do servidor xKore (padrão: " << koreServerPort << "): ";
    
    if (fgets(input, sizeof(input), stdin)) {
        // Remove quebra de linha
        input[strcspn(input, "\r\n")] = 0;
        
        // Se string vazia (só Enter), usa porta padrão
        if (strlen(input) == 0) {
            std::cout << "Usando porta padrão: " << koreServerPort << std::endl;
            return koreServerPort;
        }
        
        // Tenta converter para número
        int inputPort = atoi(input);
        if (inputPort > 0 && inputPort <= 65535) {
            std::cout << "Usando porta customizada: " << inputPort << std::endl;
            return static_cast<DWORD>(inputPort);
        }
        else {
            std::cout << "Porta inválida! Usando porta padrão: " << koreServerPort << std::endl;
            return koreServerPort;
        }
    }
    
    std::cout << "Erro na leitura! Usando porta padrão: " << koreServerPort << std::endl;
    return koreServerPort;
}

// Função init (agora cria primeiro a KeyboardMonitorThread, depois a koreConnectionMain)
void init() {
    AllocateConsole();
    std::cout << "=== RECV HOOK DLL ===" << std::endl;
    std::cout << "Architecture: x86 (32-bit)" << std::endl;

    // Tenta carregar arquivo de configuração (incluindo IP e porta)
    if (!LoadConfig("config_recv.txt")) {
        std::cout << "[FATAL] Falha ao carregar config_recv.txt. Abortando." << std::endl;
        keepMainThread = false;
        return;
    }

    // Se allowMultiClient estiver habilitado, pergunta a porta ao usuário
    if (allowMultiClient) {
        koreServerPort = GetUserPort();
    }

    std::cout << "\n[INFO] Controls:\n" << std::endl;
    std::cout << "  " << applyHookKey << " - Apply hook" << std::endl;
    std::cout << "  " << removeHookKey << " - Remove hook" << std::endl;
    std::cout << "====================\n" << std::endl;

    // Inicializa Winsock
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);

    // Cria thread para monitorar teclado primeiro
    HANDLE hKeyThread = CreateThread(NULL, 0, KeyboardMonitorThread, NULL, 0, NULL);
    if (hKeyThread == NULL) {
        std::cout << "Erro ao criar thread de monitoramento!" << std::endl;
    }

    // Agora cria a thread principal de conexão com Kore
    debug("Creating Main thread...");
    hThread = CreateThread(NULL, 0, koreConnectionMain, NULL, 0, NULL);
    if (hThread) {
        debug("Main Thread created...");
    }
    else {
        debug("Failed to Create Thread...");
    }
}

// Função finish (igual, RemoveHook se necessário)
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

// DLL Entry Point (igual)
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
