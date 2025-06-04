# ROla Packet Sniffer - Python Version

Versão em Python do analisador de pacotes para Ragnarok Online. Oferece captura e análise de tráfego TCP em tempo real com interface de terminal colorida.

## 🚀 Instalação Rápida

### Pré-requisitos

**Windows:**
- Python 3.7+
- [Npcap](https://npcap.com/dist/npcap-1.79.exe) (executar como Administrador)
- Terminal como Administrador

**Linux:**
```bash
sudo apt-get install libpcap-dev
```

**macOS:**
```bash
# Nenhum pré-requisito adicional
```

### Dependências
```bash
pip install -r requirements.txt
```

## 📖 Uso

### Listar interfaces disponíveis
```bash
python packet_sniffer.py --list-interfaces
```

Agora você verá uma saída mais amigável:
```
Interfaces de rede disponíveis:

 1. Wi-Fi - Microsoft Wi-Fi Direct Virtual Adapter
    Descrição: Microsoft Wi-Fi Direct Virtual Adapter
    Nome técnico: \Device\NPF_{7BB8E731-9A60-441E-AF44-2E033ECD64D2}

 2. Ethernet - Realtek PCIe GbE Family Controller
    Descrição: Realtek PCIe GbE Family Controller
    Nome técnico: \Device\NPF_{99D7525F-6F6E-49F7-88EA-FD2B047D7237}

 3. Loopback Interface
    Nome técnico: \Device\NPF_Loopback

Dica: Use o número, nome amigável ou nome técnico com -i
```

### Captura básica
```bash
# Usando número da interface
python packet_sniffer.py 172.65.200.86 6900 -i 2

# Usando nome amigável
python packet_sniffer.py 172.65.200.86 6900 -i "Wi-Fi"

# Auto-detectar interface (recomendado para teste)
python packet_sniffer.py 172.65.200.86 6900
```

### Salvar logs (versão estendida)
```bash
# Captura com log em arquivo
python packet_logger.py 172.65.200.86 6900 -o session.json

# Modo silencioso (apenas salva arquivo)
python packet_logger.py 172.65.200.86 6900 -q

# Analisar arquivo salvo
python packet_logger.py --analyze session.json
```

## 🎯 Principais Melhorias

### ✅ Nomenclatura Amigável de Interfaces
- `Wi-Fi - Microsoft Wi-Fi Direct Virtual Adapter`

### ✅ Múltiplas Formas de Selecionar Interface
- Por número: `-i 1`
- Por nome amigável: `-i "Wi-Fi"`
- Por busca parcial: `-i ethernet`
- Por nome técnico: `-i "\Device\NPF_{...}"`

### ✅ Interface Colorida
- 🟢 **Verde**: Pacotes recebidos (RECV)
- 🔵 **Azul**: Pacotes enviados (SEND)  
- 🟡 **Amarelo**: Dados hex e dicas
- 🔴 **Vermelho**: ASCII e erros
- 🟦 **Ciano**: Informações gerais

## 📊 Exemplo de Saída

```
================================================================================
ROla Packet Sniffer - Python Version
Target: 35.198.41.33:10009
Interface: Wi-Fi - Microsoft Wi-Fi Direct Virtual Adapter
================================================================================

Iniciando captura...
Filtro: tcp and host 35.198.41.33 and port 10009
Interface: \Device\NPF_{99D7525F-6F6E-49F7-88EA-FD2B047D7237}
Pressione Ctrl+C para parar

[14:30:25.123] RECV Opcode: 0x0080 | Size: 24 bytes
0000:  80 00 16 00 01 00 00 00  00 00 00 00 00 00 00 00  | ................
0010:  00 00 00 00 00 00 00 00                           | ........        
Raw: 80 00 16 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
--------------------------------------------------------------------------------

============================================================
ESTATÍSTICAS
============================================================
Tempo de execução: 30.5s
Total de pacotes: 142
Pacotes recebidos: 89
Pacotes enviados: 53
Taxa: 4.66 pacotes/s

Top 10 Opcodes:
Opcode   Count    Avg Size   Type
----------------------------------------
0x0080   45       24.0       Fixed
0x009A   23       32.5       Variable
0x007F   18       8.0        Fixed
```

## 🛠️ Solução de Problemas

### Interface não aparece com nome amigável
- Execute `ipconfig /all` no Windows para ver nomes reais
- Use o nome técnico como fallback
- Verifique se os drivers de rede estão atualizados

### Permissões insuficientes
- **Windows**: Execute como Administrador
- **Linux/macOS**: Use `sudo`

### Nenhum pacote capturado
1. Verifique se há tráfego ativo na porta
2. Teste sem especificar interface (`-i`)
3. Confirme IP e porta
4. Verifique firewall

## 📝 Arquivos

- **`packet_sniffer.py`**: Versão básica para uso interativo
- **`packet_logger.py`**: Versão avançada com logging em JSON
- **`requirements.txt`**: Dependências Python

## 💡 Dicas

- Use `--list-interfaces` sempre que trocar de rede
- Modo silencioso é ideal para logging automatizado
- Arquivos JSON podem ser analisados com ferramentas externas
- Ctrl+C para parar graciosamente e ver estatísticas finais