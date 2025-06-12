# Packet Analyzer - Ferramenta de Análise de Pacotes RO

## O que faz?
Captura pacotes de rede do Ragnarok Online e gera automaticamente sugestões de formato Perl para usar no OpenKore.

## Uso Básico

### Comando Simples
```bash
python packet_analyzer.py <IP> <PORTA> [opções]
```

### Exemplo com Faixa de IPs (Gravity)
```bash
python packet_analyzer.py 172.65.0.0/16 * -o FreyaFull -i 4
```

**Explicação do comando:**
- `172.65.0.0/16` = Monitora TODOS os IPs da faixa 172.65.x.x (rede da Gravity)
- `*` = Monitora TODAS as portas (não apenas uma específica)
- `-o FreyaFull` = Salva os resultados na pasta "FreyaFull"
- `-i 4` = Usa a interface de rede número 4

### Outras Opções Úteis
```bash
# Ver quais interfaces estão disponíveis
python packet_analyzer.py --list-interfaces

# Modo silencioso (sem mostrar pacotes na tela)
python packet_analyzer.py 172.65.0.0/16 * -o FreyaFull -i 4 -q

# IP específico, porta específica
python packet_analyzer.py 192.168.1.100 6900 -o MeuServidor
```

## O que é gerado?

### 1. Arquivo `perl_suggestions.txt`
Contém sugestões prontas para usar no OpenKore:
```perl
# 0x0825 - login_packet  
'0825' => ['login_packet', 'v V Z51 a17', [qw(len version username mac)]],

# 0x0437 - actor_action
'0437' => ['actor_action', 'a4 C', [qw(targetID action)]],
```

### 2. Pasta `examples/`
Exemplos reais de cada tipo de pacote capturado para você verificar se está correto.

### 3. Arquivo `packet_analysis_report.json`
Relatório completo com estatísticas (mais técnico).

## Instalação Rápida

```bash
pip install scapy colorama
```

**Windows**: Baixe e instale Npcap primeiro.

## Permissões

- **Windows**: Execute PowerShell como Administrador
- **Linux/Mac**: Use `sudo python packet_analyzer.py ...`

## Fluxo de Trabalho

1. **Execute o comando** durante uma sessão do jogo
2. **Pare com Ctrl+C** quando tiver capturado o suficiente
3. **Abra o arquivo `perl_suggestions.txt`** na pasta de output
4. **Copie as sugestões** para seu arquivo de recv/send do OpenKore
5. **Teste** se os pacotes funcionam

## Exemplo Prático

```bash
# 1. Inicie a captura
python packet_analyzer.py 172.65.0.0/16 * -o MinhaAnalise -i 4

# 2. Faça login no jogo, ande um pouco, use algumas skills
# 3. Pare com Ctrl+C

# 4. Veja os resultados
cat MinhaAnalise/perl_suggestions.txt
```

## Dicas

- **Capture por 5-10 minutos** fazendo várias ações no jogo
- **Quanto mais ações diferentes**, melhores as sugestões
- **Use `-q`** se quiser ver menos informações na tela
- **Use `--list-interfaces`** se não souber qual interface usar

## Formatos Perl Mais Comuns

| Código | O que é | Exemplo |
|---------|---------|---------|
| `a4` | ID de 4 bytes | Player ID, Item ID |
| `Z24` | Texto de até 24 chars | Nome do player |
| `v` | Número pequeno (0-65535) | HP, SP, quantidade |
| `V` | Número grande | Experiência, Zeny |
| `C` | Número tiny (0-255) | Level, tipo |

## Troubleshooting

**Não vê pacotes?**
- Confirme o IP do servidor com `ping`
- Teste com uma interface diferente
- Use `sudo` (Linux/Mac) ou Admin (Windows)