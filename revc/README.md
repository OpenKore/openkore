# recv.asi - Hook ASI Plugin para OpenKore

Este plugin ASI intercepta pacotes de rede do cliente Ragnarok Online e os redireciona para o OpenKore através de X-Kore.

## Recursos

- Intercepta função `recv()` do cliente RO automaticamente
- Conecta ao servidor X-Kore em porta configurável
- Interface de debug com console
- Controle por teclas de atalho
- Suporte a porta variável (input do usuário)
- Carregamento automático pelo cliente RO

## Compilação

### Pré-requisitos
**Opção 1: GCC/MinGW (Recomendado)**
- MSYS2/MinGW-w64
- GNU Make

**Opção 2: Visual Studio**
- Visual Studio 2022 (Community/Professional)
- Windows SDK

### Compilar com GCC
```bash
cd revc
.\build.bat
```

### Compilar com Visual Studio
```bash
cd revc
.\build_vs.bat
```

## Uso

### 1. Instalação do Plugin
1. **Copie** o arquivo `recv.asi` para a pasta onde está instalado o cliente Ragnarok Online
2. **Inicie** o cliente Ragnarok Online normalmente
3. O plugin será **carregado automaticamente** e abrirá um console de debug

### 2. Configuração da Porta
Quando o Ragnarok for iniciado, o console de debug aparecerá perguntando:
```
Digite a porta do X-Kore (padrão 2350): [sua_porta]
```
Digite a porta que será usada para comunicação com o OpenKore.

### 3. Controles
- **F11**: Aplicar hook (começar a interceptar pacotes)
- **F12**: Remover hook (parar interceptação)

### 4. OpenKore
Configure o OpenKore para usar X-Kore na mesma porta especificada:

No arquivo `config.txt` do OpenKore:
```
XKore_mode 2
XKore_port [sua_porta]
```

## Fluxo de Uso

1. **Coloque** `recv.asi` na pasta do Ragnarok Online
2. **Inicie** o OpenKore primeiro com X-Kore configurado
3. **Inicie** o cliente Ragnarok Online
4. **Configure** a porta no console que apareceu
5. **Pressione F11** para ativar o hook
6. O OpenKore deve se conectar e começar a receber/enviar pacotes

## Arquitetura

O plugin funciona em modo 32-bit e é compatível com:
- Windows 10/11
- Cliente RO 32-bit
- ASI Loader integrado ou Ultimate ASI Loader

## Debug

O console de debug mostra:
- Status da conexão com X-Kore
- Pacotes interceptados (hex dump)
- Eventos de hook (F11/F12)
- Erros de rede e conexão

## Limitações

- Endereços de memória são hardcoded para uma versão específica do cliente RO
- Pode precisar de ajustes para diferentes versões do cliente
- Teste em ambiente controlado antes do uso

## Solução de Problemas

### Console não aparece
- Verifique se o arquivo está na pasta correta do RO
- Certifique-se que o cliente suporta plugins ASI
- Tente executar o RO como administrador

### "Endereço inválido para leitura"
- Os endereços de memória precisam ser atualizados para sua versão do cliente RO
- Verifique se está usando a versão correta (32-bit)

### "Não foi possível conectar ao X-Kore"
- Inicie o OpenKore ANTES do cliente RO
- Verifique se a porta está correta
- Confirme configuração do X-Kore no config.txt
- Verifique firewall/antivírus

### Plugin não carrega
- Instale Ultimate ASI Loader se necessário
- Verifique se o cliente RO é 32-bit
- Execute como administrador se necessário 