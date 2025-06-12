#!/usr/bin/env python3
"""
ROla Packet Analyzer - Advanced Pattern Detection
Captura, analisa padrões repetidos e gera relatórios com sugestões de formato Perl
"""

import argparse
import sys
import time
import threading
import json
import os
import signal
from datetime import datetime
from collections import defaultdict, Counter
import socket
import struct
import ipaddress
from pathlib import Path

try:
    from scapy.all import *
    from scapy.layers.inet import IP, TCP
    from scapy.layers.l2 import Ether
except ImportError:
    print("Erro: Scapy não está instalado. Execute: pip install scapy")
    sys.exit(1)

try:
    from colorama import init, Fore, Back, Style
    init()
    COLORS_AVAILABLE = True
except ImportError:
    COLORS_AVAILABLE = False
    class Fore:
        RED = GREEN = BLUE = YELLOW = CYAN = MAGENTA = WHITE = RESET = ""
    class Back:
        BLACK = RESET = ""
    class Style:
        BRIGHT = RESET_ALL = ""

class PacketPattern:
    """Classe para análise de padrões em pacotes"""
    
    def __init__(self, opcode, data):
        self.opcode = opcode
        self.length = len(data)
        self.data = data
        self.hex_data = data.hex().upper()
        
    def get_structure_signature(self):
        """Gera uma assinatura da estrutura do pacote"""
        if len(self.data) < 2:
            return "empty"
            
        signature = []
        
        # Analisa cada posição para detectar padrões
        for i in range(2, len(self.data)):  # Pula os 2 primeiros bytes (opcode)
            byte_val = self.data[i]
            
            # Detecta padrões comuns
            if byte_val == 0:
                signature.append('0')
            elif 32 <= byte_val <= 126:  # ASCII printável
                signature.append('A')
            elif byte_val == 0xFF:
                signature.append('F')
            else:
                signature.append('X')
        
        return ''.join(signature)

class PacketAnalyzer:
    def __init__(self, target_ip, target_port, interface=None, output_dir=None, quiet=False):
        self.target_ip = target_ip
        self.target_port = target_port
        self.interface = interface
        self.output_dir = output_dir or "packet_analysis"
        self.quiet = quiet
        
        # Verifica se o IP é uma rede CIDR
        self.is_network = False
        self.target_network = None
        try:
            # Tenta interpretar como rede CIDR
            self.target_network = ipaddress.ip_network(target_ip, strict=False)
            self.is_network = True
            if not self.quiet:
                print(f"Detectada rede CIDR: {self.target_network}")
        except ValueError:
            # Se não for CIDR, tenta como IP único
            try:
                ipaddress.ip_address(target_ip)
                self.is_network = False
            except ValueError:
                raise ValueError(f"IP/rede inválida: {target_ip}")
        
        # Verifica se a porta é wildcard
        self.any_port = (str(target_port).lower() in ['*', 'any', 'all'])
        if self.any_port and not self.quiet:
            print("Capturando pacotes de qualquer porta")
        
        # Criar diretório de output
        Path(self.output_dir).mkdir(exist_ok=True)
        
        # Estatísticas básicas
        self.packets_received = 0
        self.packets_sent = 0
        self.total_packets = 0
        
        # Análise avançada
        self.opcodes_data = defaultdict(list)  # opcode -> [PacketPattern]
        self.opcode_patterns = defaultdict(Counter)  # opcode -> {structure: count}
        self.opcode_lengths = defaultdict(set)  # opcode -> {lengths}
        self.packet_examples = defaultdict(list)  # opcode -> [raw_data]
        
        # Controle
        self.running = False
        self.start_time = None
        
    def print_header(self):
        """Imprime cabeçalho da aplicação"""
        if not self.quiet:
            print(f"{Fore.CYAN}{'='*80}")
            print(f"{Fore.CYAN}ROla Packet Analyzer - Advanced Pattern Detection")
            
            if self.is_network:
                target_display = f"Network: {self.target_network}"
            else:
                target_display = f"IP: {self.target_ip}"
            
            if self.any_port:
                target_display += " | Port: ANY"
            else:
                target_display += f" | Port: {self.target_port}"
                
            print(f"{Fore.CYAN}{target_display}")
            print(f"{Fore.CYAN}Output Dir: {self.output_dir}")
            if self.interface:
                print(f"{Fore.CYAN}Interface: {self.interface}")
            print(f"{Fore.CYAN}{'='*80}{Style.RESET_ALL}")
            print()
    
    def analyze_packet_structure(self, data):
        """Analisa a estrutura de um pacote e sugere formato Perl"""
        if len(data) < 2:
            return None, []
            
        # Extrai componentes
        components = []
        param_names = []
        pos = 2  # Pula opcode
        
        # Analisa tamanho total
        total_len = len(data)
        
        # Detecta padrões comuns
        while pos < total_len:
            remaining = total_len - pos
            
            if remaining >= 4:
                # Testa se pode ser um ID de 4 bytes
                bytes_4 = data[pos:pos+4]
                if self._looks_like_id(bytes_4):
                    components.append('a4')
                    param_names.append('targetID')
                    pos += 4
                    continue
            
            if remaining >= 2:
                # Testa se pode ser um short (v)
                short_val = struct.unpack('<H', data[pos:pos+2])[0]
                if self._looks_like_length_or_id(short_val, remaining):
                    components.append('v')
                    param_names.append('len' if short_val == total_len else 'value')
                    pos += 2
                    continue
            
            if remaining >= 1:
                # Verifica se é string ASCII
                string_len = self._detect_string_length(data, pos)
                if string_len > 0:
                    if data[pos + string_len - 1] == 0:  # Null-terminated
                        components.append(f'Z{string_len}')
                        param_names.append('string_data')
                    else:
                        components.append(f'a{string_len}')
                        param_names.append('data')
                    pos += string_len
                    continue
                
                # Single byte
                components.append('C')
                param_names.append('byte_value')
                pos += 1
        
        # Se sobrou dados, adiciona como a*
        if pos < total_len:
            components.append('a*')
            param_names.append('remaining_data')
        
        format_template = ' '.join(components)
        return format_template, param_names
    
    def _looks_like_id(self, bytes_data):
        """Verifica se 4 bytes parecem um ID"""
        # IDs geralmente não são todos zeros ou todos 0xFF
        if bytes_data == b'\x00\x00\x00\x00' or bytes_data == b'\xFF\xFF\xFF\xFF':
            return False
        # Se tem pelo menos um byte não-zero
        return any(b != 0 for b in bytes_data)
    
    def _looks_like_length_or_id(self, value, remaining_bytes):
        """Verifica se um valor de 2 bytes parece um tamanho ou ID"""
        # Tamanhos válidos são geralmente <= remaining bytes
        if value <= remaining_bytes + 2:  # +2 para o próprio campo
            return True
        # IDs podem ser qualquer valor
        return True
    
    def _detect_string_length(self, data, start_pos):
        """Detecta o comprimento de uma string ASCII"""
        pos = start_pos
        ascii_count = 0
        
        while pos < len(data):
            byte_val = data[pos]
            
            # Null terminator
            if byte_val == 0:
                return pos - start_pos + 1
            
            # ASCII printável
            if 32 <= byte_val <= 126:
                ascii_count += 1
                pos += 1
                if ascii_count >= 3:  # Pelo menos 3 chars ASCII consecutivos
                    continue
            else:
                break
        
        # Retorna tamanho se encontrou string ASCII válida
        return pos - start_pos if ascii_count >= 3 else 0
    
    def generate_packet_name(self, opcode, pattern):
        """Gera nome sugerido para o pacote"""
        opcode_hex = f"{opcode:04X}"
        
        # Nomes conhecidos baseados em padrões comuns
        if 'Z' in pattern and 'a4' in pattern:
            return 'login_packet'
        elif 'a4' in pattern and 'C' in pattern:
            return 'actor_action'
        elif pattern.count('v') >= 2:
            return 'coordinate_packet'
        elif 'a*' in pattern:
            return 'variable_data'
        else:
            return f'packet_{opcode_hex.lower()}'
        
    def format_packet_data(self, data, direction, timestamp):
        """Formata os dados do pacote para análise"""
        if len(data) < 2:
            return None
            
        # Extrai opcode
        opcode = struct.unpack('<H', data[:2])[0]
        
        # Cria padrão do pacote
        pattern = PacketPattern(opcode, data)
        self.opcodes_data[opcode].append(pattern)
        
        # Analisa estrutura
        structure_sig = pattern.get_structure_signature()
        self.opcode_patterns[opcode][structure_sig] += 1
        self.opcode_lengths[opcode].add(len(data))
        
        # Salva exemplo (máximo 10 por opcode)
        if len(self.packet_examples[opcode]) < 10:
            self.packet_examples[opcode].append({
                'direction': direction,
                'timestamp': timestamp.isoformat(),
                'data': data.hex().upper(),
                'length': len(data)
            })
        
        if not self.quiet:
            # Cor baseada na direção
            if direction == "RECV":
                color = Fore.GREEN
                direction_text = f"{Back.BLACK}{Fore.GREEN} RECV {Style.RESET_ALL}"
            else:
                color = Fore.BLUE
                direction_text = f"{Back.BLACK}{Fore.BLUE} SEND {Style.RESET_ALL}"
            
            print(f"{color}[{timestamp.strftime('%H:%M:%S.%f')[:-3]}] {direction_text} "
                  f"Opcode: 0x{opcode:04X} | Size: {len(data)} bytes{Style.RESET_ALL}")
            
            # Dump hexadecimal simples
            hex_data = ' '.join(f'{b:02X}' for b in data)
            print(f"{Fore.YELLOW}Raw: {hex_data}{Style.RESET_ALL}")
            print("-" * 60)
        
        return opcode
        
    def print_hex_dump(self, data):
        """Imprime dump hexadecimal formatado"""
        bytes_per_line = 16
        
        for i in range(0, len(data), bytes_per_line):
            # Offset
            offset = f"{i:04X}:"
            print(f"{Fore.BLUE}{offset:<6}{Style.RESET_ALL}", end="")
            
            # Bytes em hex
            hex_part = ""
            ascii_part = ""
            
            for j in range(bytes_per_line):
                if i + j < len(data):
                    byte_val = data[i + j]
                    hex_part += f"{byte_val:02X} "
                    
                    # Parte ASCII
                    if 32 <= byte_val <= 126:
                        ascii_part += chr(byte_val)
                    else:
                        ascii_part += "."
                else:
                    hex_part += "   "
                    ascii_part += " "
                    
                # Espaço extra no meio
                if j == 7:
                    hex_part += " "
            
            print(f"{Fore.GREEN}{hex_part}{Style.RESET_ALL} | {Fore.RED}{ascii_part}{Style.RESET_ALL}")
            
    def _ip_matches_target(self, ip_str):
        """Verifica se um IP corresponde ao target (IP único ou rede)"""
        try:
            ip_addr = ipaddress.ip_address(ip_str)
            if self.is_network:
                return ip_addr in self.target_network
            else:
                return str(ip_addr) == self.target_ip
        except:
            return False
    
    def _port_matches_target(self, port):
        """Verifica se uma porta corresponde ao target"""
        if self.any_port:
            return True
        return port == self.target_port

    def packet_handler(self, packet):
        """Processa cada pacote capturado"""
        try:
            if not packet.haslayer(TCP) or not packet.haslayer(IP):
                return
                
            ip_layer = packet[IP]
            tcp_layer = packet[TCP]
            
            # Verifica se é o IP/rede e porta que queremos monitorar
            src_ip_matches = self._ip_matches_target(ip_layer.src)
            dst_ip_matches = self._ip_matches_target(ip_layer.dst)
            src_port_matches = self._port_matches_target(tcp_layer.sport)
            dst_port_matches = self._port_matches_target(tcp_layer.dport)
            
            is_from_server = src_ip_matches and src_port_matches
            is_to_server = dst_ip_matches and dst_port_matches
            
            if not (is_from_server or is_to_server):
                return
                
            # Extrai payload
            if tcp_layer.payload:
                payload = bytes(tcp_layer.payload)
                if len(payload) >= 2:
                    timestamp = datetime.now()
                    
                    if is_from_server:
                        direction = "RECV"
                        self.packets_received += 1
                    else:
                        direction = "SEND"
                        self.packets_sent += 1
                    
                    self.total_packets += 1
                    
                    # Analisa o pacote
                    self.format_packet_data(payload, direction, timestamp)
                    
        except Exception as e:
            if not self.quiet:
                print(f"{Fore.RED}Erro ao processar pacote: {e}{Style.RESET_ALL}")
            
    def print_statistics(self):
        """Imprime estatísticas dos pacotes"""
        if self.total_packets == 0 or self.quiet:
            return
            
        print(f"\n{Fore.CYAN}{'='*60}")
        print(f"ESTATÍSTICAS DE ANÁLISE")
        print(f"{'='*60}{Style.RESET_ALL}")
        
        elapsed = (datetime.now() - self.start_time).total_seconds()
        
        print(f"{Fore.WHITE}Tempo de execução: {elapsed:.1f}s")
        print(f"Total de pacotes: {self.total_packets}")
        print(f"Pacotes recebidos: {self.packets_received}")
        print(f"Pacotes enviados: {self.packets_sent}")
        print(f"Opcodes únicos: {len(self.opcodes_data)}")
        print(f"Taxa: {self.total_packets/elapsed:.2f} pacotes/s{Style.RESET_ALL}")
        
        if self.opcodes_data:
            print(f"\n{Fore.YELLOW}Top 10 Opcodes Analisados:{Style.RESET_ALL}")
            sorted_opcodes = sorted(self.opcodes_data.items(), key=lambda x: len(x[1]), reverse=True)[:10]
            
            print(f"{'Opcode':<8} {'Count':<8} {'Lengths':<15} {'Patterns'}")
            print("-" * 50)
            
            for opcode, patterns in sorted_opcodes:
                lengths = list(self.opcode_lengths[opcode])
                pattern_count = len(self.opcode_patterns[opcode])
                
                lengths_str = str(lengths[0]) if len(lengths) == 1 else f"{min(lengths)}-{max(lengths)}"
                
                print(f"0x{opcode:04X}   {len(patterns):<8} {lengths_str:<15} {pattern_count}")
        
        print()
        
    def start_statistics_thread(self):
        """Thread para imprimir estatísticas periodicamente"""
        def stats_loop():
            counter = 0
            while self.running:
                time.sleep(1)  # Verifica a cada segundo
                counter += 1
                if counter >= 30 and self.running:  # Estatísticas a cada 30 segundos
                    self.print_statistics()
                    counter = 0
                    
        if not self.quiet:
            thread = threading.Thread(target=stats_loop, daemon=True)
            thread.start()
        
    def save_packet_examples(self):
        """Salva exemplos de pacotes em pastas por opcode"""
        examples_dir = Path(self.output_dir) / "examples"
        examples_dir.mkdir(exist_ok=True)
        
        for opcode, examples in self.packet_examples.items():
            opcode_dir = examples_dir / f"0x{opcode:04X}"
            opcode_dir.mkdir(exist_ok=True)
            
            # Salva exemplos individuais
            for i, example in enumerate(examples):
                example_file = opcode_dir / f"example_{i+1}.json"
                with open(example_file, 'w', encoding='utf-8') as f:
                    json.dump(example, f, indent=2, ensure_ascii=False)
            
            # Salva resumo do opcode
            summary = {
                'opcode': f"0x{opcode:04X}",
                'total_examples': len(examples),
                'unique_lengths': list(self.opcode_lengths[opcode]),
                'patterns': dict(self.opcode_patterns[opcode])
            }
            
            summary_file = opcode_dir / "summary.json"
            with open(summary_file, 'w', encoding='utf-8') as f:
                json.dump(summary, f, indent=2, ensure_ascii=False)
    
    def generate_perl_analysis(self):
        """Gera análise completa com sugestões de formato Perl"""
        analysis = {
            'session_info': {
                'target_ip': str(self.target_network) if self.is_network else self.target_ip,
                'target_port': 'ANY' if self.any_port else self.target_port,
                'is_network': self.is_network,
                'any_port': self.any_port,
                'start_time': self.start_time.isoformat() if self.start_time else None,
                'end_time': datetime.now().isoformat(),
                'total_packets': self.total_packets,
                'packets_received': self.packets_received,
                'packets_sent': self.packets_sent
            },
            'opcode_analysis': {},
            'perl_suggestions': {}
        }
        
        for opcode, patterns in self.opcodes_data.items():
            if not patterns:
                continue
                
            # Analisa o padrão mais comum
            most_common_pattern = patterns[0]  # Pega o primeiro como exemplo
            format_template, param_names = self.analyze_packet_structure(most_common_pattern.data)
            packet_name = self.generate_packet_name(opcode, format_template or '')
            
            # Estatísticas do opcode
            opcode_hex = f"0x{opcode:04X}"
            lengths = list(self.opcode_lengths[opcode])
            pattern_distribution = dict(self.opcode_patterns[opcode])
            
            analysis['opcode_analysis'][opcode_hex] = {
                'count': len(patterns),
                'unique_lengths': lengths,
                'is_fixed_length': len(lengths) == 1,
                'pattern_distribution': pattern_distribution,
                'examples_count': len(self.packet_examples[opcode])
            }
            
            # Sugestão Perl
            if format_template and param_names:
                perl_suggestion = {
                    'packet_name': packet_name,
                    'format_template': format_template,
                    'parameter_names': param_names,
                    'perl_format': f"'{opcode:04X}' => ['{packet_name}', '{format_template}', [qw({' '.join(param_names)})]]"
                }
                
                analysis['perl_suggestions'][opcode_hex] = perl_suggestion
        
        return analysis
    
    def save_analysis_report(self):
        """Salva relatório completo da análise"""
        if not self.quiet:
            print(f"\n{Fore.CYAN}Gerando relatório de análise...{Style.RESET_ALL}")
        
        # Gera análise
        analysis = self.generate_perl_analysis()
        
        # Salva relatório principal
        report_file = Path(self.output_dir) / "packet_analysis_report.json"
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(analysis, f, indent=2, ensure_ascii=False)
        
        # Salva sugestões Perl em formato mais legível
        perl_file = Path(self.output_dir) / "perl_suggestions.txt"
        with open(perl_file, 'w', encoding='utf-8') as f:
            f.write("# ROla Packet Analysis - Perl Format Suggestions\n")
            f.write(f"# Generated: {datetime.now().isoformat()}\n")
            if self.is_network:
                target_str = f"# Target Network: {self.target_network}"
            else:
                target_str = f"# Target IP: {self.target_ip}"
            
            if self.any_port:
                target_str += " | Port: ANY"
            else:
                target_str += f" | Port: {self.target_port}"
                
            f.write(f"{target_str}\n\n")
            
            f.write("# Packet format suggestions:\n")
            for opcode_hex, suggestion in analysis['perl_suggestions'].items():
                f.write(f"\n# {opcode_hex} - {suggestion['packet_name']}\n")
                f.write(f"{suggestion['perl_format']},\n")
                
                # Adiciona comentários explicativos
                format_parts = suggestion['format_template'].split()
                param_parts = suggestion['parameter_names']
                
                if len(format_parts) == len(param_parts):
                    f.write("# ")
                    for fmt, param in zip(format_parts, param_parts):
                        f.write(f"{fmt}={param}, ")
                    f.write("\n")
        
        # Salva exemplos por opcode
        self.save_packet_examples()
        
        if not self.quiet:
            print(f"{Fore.GREEN}Relatório salvo em: {report_file}{Style.RESET_ALL}")
            print(f"{Fore.GREEN}Sugestões Perl salvas em: {perl_file}{Style.RESET_ALL}")
            print(f"{Fore.GREEN}Exemplos salvos em: {Path(self.output_dir) / 'examples'}{Style.RESET_ALL}")
        
    def _signal_handler(self, signum, frame):
        """Manipulador de sinal para Ctrl+C"""
        if not self.quiet:
            print(f"\n{Fore.YELLOW}Sinal de interrupção recebido. Parando análise...{Style.RESET_ALL}")
        self.running = False
        
    def _setup_signal_handlers(self):
        """Configura manipuladores de sinal multiplataforma"""
        signal.signal(signal.SIGINT, self._signal_handler)
        
        # Para Windows, também configura SIGBREAK se disponível
        if hasattr(signal, 'SIGBREAK'):
            signal.signal(signal.SIGBREAK, self._signal_handler)
        
        # Para sistemas Unix, também configura SIGTERM
        if hasattr(signal, 'SIGTERM'):
            signal.signal(signal.SIGTERM, self._signal_handler)
        
    def start_capture(self):
        """Inicia a captura de pacotes"""
        # Configura manipuladores de sinal para Ctrl+C
        self._setup_signal_handlers()
        
        try:
            self.print_header()
            
            # Constrói filtro BPF baseado no target
            if self.is_network:
                # Para redes, usa net em vez de host
                if self.any_port:
                    bpf_filter = f"tcp and net {self.target_network}"
                else:
                    bpf_filter = f"tcp and net {self.target_network} and port {self.target_port}"
            else:
                # Para IP único
                if self.any_port:
                    bpf_filter = f"tcp and host {self.target_ip}"
                else:
                    bpf_filter = f"tcp and host {self.target_ip} and port {self.target_port}"
            
            if not self.quiet:
                print(f"{Fore.GREEN}Iniciando análise de pacotes...")
                print(f"Filtro: {bpf_filter}")
                if self.interface:
                    print(f"Interface: {self.interface}")
                print(f"{Fore.CYAN}═══ PRESSIONE Ctrl+C PARA PARAR E GERAR RELATÓRIO ═══{Style.RESET_ALL}\n")
            
            self.running = True
            self.start_time = datetime.now()
            
            # Inicia thread de estatísticas
            self.start_statistics_thread()
            
            # Inicia captura com timeout para tornar mais responsivo
            while self.running:
                try:
                    # Usar timeout menor para ser mais responsivo ao Ctrl+C
                    packets = sniff(
                        iface=self.interface,
                        filter=bpf_filter,
                        prn=self.packet_handler,
                        store=0,
                        timeout=0.5,  # Timeout de 0.5 segundo para verificar self.running
                        stop_filter=lambda p: not self.running
                    )
                    
                    # Se não capturou pacotes e ainda está rodando, continua
                    if not self.running:
                        break
                        
                except Exception as e:
                    if self.running:  # Só mostra erro se ainda estiver rodando
                        if not self.quiet:
                            print(f"{Fore.RED}Erro durante captura: {e}{Style.RESET_ALL}")
                        time.sleep(0.1)  # Pequena pausa antes de tentar novamente
                    break
            
        except KeyboardInterrupt:
            if not self.quiet:
                print(f"\n{Fore.YELLOW}Análise interrompida pelo usuário{Style.RESET_ALL}")
        except PermissionError:
            print(f"{Fore.RED}Erro: Permissões insuficientes. Execute como administrador/root{Style.RESET_ALL}")
        except Exception as e:
            print(f"{Fore.RED}Erro durante análise: {e}{Style.RESET_ALL}")
        finally:
            self.running = False
            if not self.quiet:
                print(f"\n{Fore.CYAN}═══ FINALIZANDO ANÁLISE ═══{Style.RESET_ALL}")
            self.print_statistics()
            self.save_analysis_report()
            if not self.quiet:
                print(f"\n{Fore.GREEN}✓ Análise concluída com sucesso!{Style.RESET_ALL}")
            
    def stop_capture(self):
        """Para a captura"""
        self.running = False

def analyze_log_file(log_file):
    """Analisa um arquivo de log salvo anteriormente"""
    try:
        with open(log_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            
        print(f"{Fore.CYAN}{'='*60}")
        print(f"ANÁLISE DO LOG: {log_file}")
        print(f"{'='*60}{Style.RESET_ALL}")
        
        session_info = data.get('session_info', {})
        print(f"Target: {session_info.get('target_ip')}:{session_info.get('target_port')}")
        print(f"Início: {session_info.get('start_time')}")
        print(f"Fim: {session_info.get('end_time')}")
        print()
        
        stats = data.get('statistics', {})
        print(f"Total de pacotes: {stats.get('total_packets', 0)}")
        print(f"Pacotes recebidos: {stats.get('packets_received', 0)}")
        print(f"Pacotes enviados: {stats.get('packets_sent', 0)}")
        print(f"Opcodes únicos: {stats.get('unique_opcodes', 0)}")
        print()
        
        if 'packet_types' in stats:
            print(f"{Fore.YELLOW}Opcodes mais frequentes:{Style.RESET_ALL}")
            sorted_opcodes = sorted(stats['packet_types'].items(), key=lambda x: x[1], reverse=True)[:10]
            
            for opcode_str, count in sorted_opcodes:
                opcode = int(opcode_str)
                print(f"0x{opcode:04X}: {count} pacotes")
        
    except Exception as e:
        print(f"{Fore.RED}Erro ao analisar log: {e}{Style.RESET_ALL}")

def get_available_interfaces():
    """Lista interfaces de rede disponíveis com nomes amigáveis"""
    try:
        from scapy.arch import get_if_list
        from scapy.config import conf
        
        interfaces = []
        
        # Tenta usar as interfaces do Scapy com nomes amigáveis
        if hasattr(conf, 'ifaces'):
            for iface_name, iface in conf.ifaces.items():
                try:
                    # Pega informações da interface
                    name = iface.name if hasattr(iface, 'name') else iface_name
                    description = iface.description if hasattr(iface, 'description') else None
                    
                    # Cria nome amigável
                    if description and description != name:
                        friendly_name = f"{name} ({description})"
                    else:
                        friendly_name = name
                    
                    # Simplifica nomes conhecidos do Windows
                    if "Loopback" in friendly_name:
                        friendly_name = "Loopback Interface"
                    elif "Ethernet" in description if description else False:
                        friendly_name = f"Ethernet - {description.split('Ethernet')[-1].strip()}"
                    elif "Wi-Fi" in description if description else False:
                        friendly_name = f"Wi-Fi - {description.split('Wi-Fi')[-1].strip()}"
                    elif "Wireless" in description if description else False:
                        friendly_name = f"Wireless - {description.split('Wireless')[-1].strip()}"
                    
                    interfaces.append({
                        'name': name,
                        'friendly_name': friendly_name,
                        'description': description
                    })
                except:
                    continue
        
        # Fallback para lista básica se não conseguir informações detalhadas
        if not interfaces:
            basic_interfaces = get_if_list()
            for iface in basic_interfaces:
                interfaces.append({
                    'name': iface,
                    'friendly_name': iface,
                    'description': None
                })
        
        return interfaces
    except Exception as e:
        print(f"Erro ao obter interfaces: {e}")
        return []

def main():
    parser = argparse.ArgumentParser(
        description="ROla Packet Analyzer - Analisa padrões e gera sugestões Perl",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos de uso:
  python packet_analyzer.py 192.168.1.100 6900
  python packet_analyzer.py 172.65.0.0/16 *
  python packet_analyzer.py 35.198.41.33 10009 -o analysis_output
  python packet_analyzer.py 10.0.0.0/8 any -i "Wi-Fi" -q
        """
    )
    
    parser.add_argument('ip', nargs='?', help='IP/rede do servidor para monitorar (ex: 192.168.1.100 ou 172.65.0.0/16)')
    parser.add_argument('port', nargs='?', help='Porta do servidor para monitorar (número ou * para qualquer porta)')
    parser.add_argument('-i', '--interface', help='Interface de rede específica (use nome ou número da lista)')
    parser.add_argument('-o', '--output', help='Arquivo para salvar os pacotes capturados (JSON)')
    parser.add_argument('-q', '--quiet', action='store_true', help='Modo silencioso (apenas estatísticas)')
    parser.add_argument('--analyze', help='Analisa um arquivo de log existente')
    parser.add_argument('--list-interfaces', action='store_true', 
                       help='Lista as interfaces de rede disponíveis')
    
    args = parser.parse_args()
    
    # Análise de arquivo de log
    if args.analyze:
        analyze_log_file(args.analyze)
        return
    
    # Lista interfaces se solicitado
    if args.list_interfaces:
        interfaces = get_available_interfaces()
        print(f"{Fore.CYAN}Interfaces de rede disponíveis:{Style.RESET_ALL}")
        print()
        
        for i, iface in enumerate(interfaces, 1):
            print(f"{Fore.WHITE}{i:2d}.{Style.RESET_ALL} {Fore.GREEN}{iface['friendly_name']}{Style.RESET_ALL}")
            if iface['description'] and iface['description'] != iface['friendly_name']:
                print(f"     {Fore.YELLOW}Descrição: {iface['description']}{Style.RESET_ALL}")
            print(f"     {Fore.CYAN}Nome técnico: {iface['name']}{Style.RESET_ALL}")
            print()
        
        print(f"{Fore.YELLOW}Dica: Use o número, nome amigável ou nome técnico com -i{Style.RESET_ALL}")
        return
    
    # Valida argumentos
    if not args.ip or args.port is None:
        parser.print_help()
        return
        
    # Valida IP/rede
    try:
        # Primeiro tenta como rede CIDR
        try:
            ipaddress.ip_network(args.ip, strict=False)
        except ValueError:
            # Se não for CIDR, tenta como IP único
            ipaddress.ip_address(args.ip)
    except ValueError:
        print(f"{Fore.RED}Erro: IP/rede inválida '{args.ip}'. Use formato IP (192.168.1.100) ou CIDR (172.65.0.0/16){Style.RESET_ALL}")
        return
        
    # Valida porta
    port_str = str(args.port).lower()
    if port_str in ['*', 'any', 'all']:
        target_port = '*'
    else:
        try:
            target_port = int(args.port)
            if not (1 <= target_port <= 65535):
                print(f"{Fore.RED}Erro: Porta deve estar entre 1 e 65535 ou usar * para qualquer porta{Style.RESET_ALL}")
                return
        except (ValueError, TypeError):
            print(f"{Fore.RED}Erro: Porta inválida '{args.port}'. Use um número (1-65535) ou * para qualquer porta{Style.RESET_ALL}")
            return
    
    # Resolve interface se especificada
    interface_name = None
    if args.interface:
        interfaces = get_available_interfaces()
        
        # Tenta encontrar por número
        try:
            interface_index = int(args.interface) - 1
            if 0 <= interface_index < len(interfaces):
                interface_name = interfaces[interface_index]['name']
                if not args.quiet:
                    print(f"Usando interface: {interfaces[interface_index]['friendly_name']}")
            else:
                print(f"{Fore.RED}Erro: Número de interface inválido. Use --list-interfaces{Style.RESET_ALL}")
                return
        except ValueError:
            # Tenta encontrar por nome amigável ou técnico
            found = False
            for iface in interfaces:
                if (args.interface.lower() in iface['friendly_name'].lower() or 
                    args.interface == iface['name']):
                    interface_name = iface['name']
                    if not args.quiet:
                        print(f"Usando interface: {iface['friendly_name']}")
                    found = True
                    break
            
            if not found:
                print(f"{Fore.RED}Erro: Interface '{args.interface}' não encontrada. Use --list-interfaces{Style.RESET_ALL}")
                return
    
    # Gera nome de diretório padrão se necessário
    output_dir = args.output
    if not output_dir:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        # Sanitiza nome do arquivo removendo caracteres especiais
        safe_ip = args.ip.replace('/', '_').replace(':', '_')
        safe_port = str(target_port).replace('*', 'any')
        output_dir = f"analysis_{safe_ip}_{safe_port}_{timestamp}"
        if not args.quiet:
            print(f"Salvando análise em: {output_dir}")
    
    # Cria e inicia o analisador
    analyzer = PacketAnalyzer(args.ip, target_port, interface_name, output_dir, args.quiet)
    
    try:
        analyzer.start_capture()
    except KeyboardInterrupt:
        if not args.quiet:
            print(f"\n{Fore.YELLOW}Programa encerrado{Style.RESET_ALL}")

if __name__ == "__main__":
    main() 