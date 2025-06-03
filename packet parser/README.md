# ROla Sniff - Packet Parser para Ragnarok Online

## Descrição

O **ROla Sniff** é uma ferramenta de análise de pacotes de rede desenvolvida pelo Jailson Panal (#jailsonpanal_86571 no Discord) especificamente para capturar e analisar a comunicação entre o cliente e servidor do jogo Ragnarok Online. Esta ferramenta é útil para desenvolvedores, pesquisadores e entusiastas que desejam entender a estrutura de comunicação do protocolo RO.

## Funcionalidades

### 🔍 **Captura de Pacotes**
- Captura em tempo real de pacotes TCP
- Filtragem por IP e porta específicos do servidor
- Interface gráfica intuitiva para seleção de adaptadores de rede

### 📊 **Análise de Dados**
- **Visualização Hexadecimal**: Exibição dos dados em formato hex com representação ASCII
- **Identificação de Opcodes**: Detecção automática de códigos de operação
- **Classificação de Pacotes**: 
  - Pacotes de tamanho fixo
  - Pacotes de tamanho variável
- **Estatísticas em Tempo Real**: Contadores de pacotes processados

### 🔎 **Busca Avançada**
- Busca por texto ou valores hexadecimais
- Busca com diferenciação de maiúsculas/minúsculas
- Navegação bidirecional (para frente/para trás)
- Destaque visual dos resultados encontrados

### 💾 **Persistência de Configurações**
- Salvamento automático de IP e porta do servidor
- Lembrança da interface de rede selecionada
- Configurações salvas em arquivo XML

## Requisitos do Sistema

### Software Necessário
- **Sistema Operacional**: Windows 10/11
- **Framework**: .NET 7.0 ou superior
- **Npcap**: Obrigatório para captura de pacotes ([Download](https://npcap.com/dist/npcap-1.79.exe))

### Dependências
- `SharpPcap` 6.3.1 - Biblioteca para captura de pacotes
- `PacketDotNet` - Análise de protocolos de rede
- `System.Management` - Gerenciamento de interfaces de rede

## Instalação

### 1. Pré-requisitos
```bash
# Instalar o Npcap (obrigatório)
# Baixe de: https://npcap.com/dist/npcap-1.79.exe
# Execute como administrador
# Marque a opção "Install Npcap in WinPcap API-compatible Mode"
```

### 2. Compilação
```bash
# Navegar para o diretório do projeto
cd "packet parser"

# Restaurar dependências
dotnet restore

# Compilar o projeto
dotnet build --configuration Release
```

### 3. Execução
```bash
# Executar o aplicativo
dotnet run
# ou execute o arquivo .exe gerado em bin/Release/
```

## Como Usar

### 1. **Configuração Inicial**
- Abra o aplicativo
- Selecione a interface de rede apropriada
- Configure o IP do servidor RO (ex: `35.198.41.33`, para garantir, rode `ping lt-account-01.gnjoylatam.com` e copie o endereço)
- Configure a porta do servidor (ex: `10009`)

### 2. **Captura de Pacotes**
- Clique em "Iniciar Captura"
- Inicie o cliente do Ragnarok Online
- Faça login no jogo
- Observe os pacotes sendo capturados em tempo real

### 3. **Análise dos Dados**
- **Painel Esquerdo**: Pacotes recebidos (RECV)
- **Painel Direito**: Pacotes enviados (SEND)
- **Lista Central**: Resumo dos opcodes capturados
- **Status Bar**: Estatísticas em tempo real

### 4. **Busca de Dados**
- Pressione `Ctrl+F` para abrir a janela de busca
- Digite texto ou valores hexadecimais (ex: `FF 00 1A`)
- Use as setas para navegar entre resultados

## Estrutura dos Dados Capturados

### Formato de Exibição
```
[14:30:25.123] RECV Opcode: 0x08C8 | Tamanho: 42 bytes
0000:  C8 08 2A 00 01 00 00 00  FF FF FF FF 00 00 00 00  |..*.............
0010:  48 65 6C 6C 6F 20 57 6F  72 6C 64 00 00 00 00 00  |Hello World.....
0020:  00 00 00 00 00 00 00 00  00 00                    |..........

Dados brutos (hex):
C8082A0001000000FFFFFFFF000000004865616C6C6F20576F726C6400000000000000000000000000000000
```

### Elementos da Análise
- **Timestamp**: Horário de captura (HH:mm:ss.fff)
- **Direção**: RECV (recebido) ou SEND (enviado)
- **Opcode**: Código de operação em hexadecimal
- **Tamanho**: Quantidade de bytes do pacote
- **Dump Hex**: Visualização hexadecimal com ASCII
- **Dados Brutos**: Sequência hex contínua

## Configurações Avançadas

### Arquivo de Configuração (config.xml)
```xml
<Settings>
  <ServerIP>35.198.41.33</ServerIP>
  <ServerPort>10009</ServerPort>
  <SelectedInterface>Nome da Interface de Rede</SelectedInterface>
</Settings>
```

### Filtros de Captura
O aplicativo aplica automaticamente um filtro Berkeley Packet Filter (BPF):
```
tcp and host [SERVER_IP] and port [SERVER_PORT]
```

## Solução de Problemas

### ❌ Erro: "Unable to load DLL 'wpcap'"
**Causa**: Npcap não instalado
**Solução**: 
1. Baixe o Npcap em https://npcap.com/dist/npcap-1.79.exe
2. Execute como administrador
3. Reinicie o aplicativo

### ❌ "Nenhuma interface de rede encontrada"
**Causa**: Problemas com drivers ou permissões
**Solução**:
1. Execute o aplicativo como administrador
2. Verifique se o Npcap está instalado corretamente
3. Reinstale o Npcap se necessário

### ❌ Nenhum pacote sendo capturado
**Verificações**:
1. IP e porta do servidor estão corretos?
2. Interface de rede correta selecionada?
3. Firewall não está bloqueando?
4. Cliente RO está realmente conectando no servidor especificado?

## Estrutura do Projeto

```
packet parser/
├── PACKET PARSE RO/
│   ├── Form1.cs              # Interface principal
│   ├── Form1.Designer.cs     # Designer da interface
│   ├── pacotesrec.cs         # Processamento de pacotes recebidos
│   ├── pacotesenv.cs         # Processamento de pacotes enviados
│   ├── SearchForm.cs         # Janela de busca
│   ├── Program.cs            # Ponto de entrada
│   └── PACKET PARSE RO.csproj # Arquivo do projeto
├── PACKET PARSE RO.sln       # Solution do Visual Studio
└── README.md                 # Este arquivo
```

## Contribuição

Este projeto faz parte do OpenKore e contribuições são bem-vindas:

1. Fork o repositório
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## Licença

Este projeto segue a mesma licença do OpenKore. Consulte o arquivo LICENSE no diretório raiz.

## Avisos Importantes

⚠️ **Uso Responsável**: Esta ferramenta deve ser usada apenas para fins educacionais, pesquisa ou desenvolvimento. Não use para trapacear ou violar termos de serviço.

⚠️ **Privacidade**: Esta ferramenta captura dados de rede. Use apenas em redes próprias ou com autorização adequada.

⚠️ **Segurança**: Execute sempre com o mínimo de privilégios necessários. O modo administrador é necessário apenas para captura de pacotes.

## Suporte

Para suporte, bugs ou sugestões:
- Abra uma issue no repositório do OpenKore
- Consulte a documentação do OpenKore
- Participe das discussões da comunidade OpenKore

---

**Desenvolvido para a comunidade OpenKore** 🎮 