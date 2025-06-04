#!/usr/bin/env python3
"""
ROla Packet Sniffer - Python Version
Captura e analisa pacotes de rede para IP e porta específicos
"""

import argparse
import sys
import time
import threading
from datetime import datetime
from collections import defaultdict
import socket
import struct

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

class PacketSniffer:
    def __init__(self, target_ip, target_port, interface=None):
        self.target_ip = target_ip
        self.target_port = target_port
        self.interface = interface
        
        # Estatísticas
        self.packets_received = 0
        self.packets_sent = 0
        self.total_packets = 0
        self.packet_types = defaultdict(int)
        self.packet_lengths = defaultdict(list)
        
        # Controle
        self.running = False
        self.start_time = None
        
    def print_header(self):
        """Imprime cabeçalho da aplicação"""
        print(f"{Fore.CYAN}{'='*80}")
        print(f"{Fore.CYAN}ROla Packet Sniffer - Python Version")
        print(f"{Fore.CYAN}Target: {self.target_ip}:{self.target_port}")
        if self.interface:
            print(f"{Fore.CYAN}Interface: {self.interface}")
        print(f"{Fore.CYAN}{'='*80}{Style.RESET_ALL}")
        print()
        
    def format_packet_data(self, data, direction, timestamp):
        """Formata os dados do pacote para exibição"""
        if len(data) < 2:
            return
            
        # Extrai opcode (primeiros 2 bytes, little endian)
        opcode = struct.unpack('<H', data[:2])[0]
        
        # Cor baseada na direção
        if direction == "RECV":
            color = Fore.GREEN
            direction_text = f"{Back.BLACK}{Fore.GREEN} RECV {Style.RESET_ALL}"
        else:
            color = Fore.BLUE
            direction_text = f"{Back.BLACK}{Fore.BLUE} SEND {Style.RESET_ALL}"
        
        # Cabeçalho do pacote
        print(f"{color}[{timestamp.strftime('%H:%M:%S.%f')[:-3]}] {direction_text} "
              f"Opcode: 0x{opcode:04X} | Size: {len(data)} bytes{Style.RESET_ALL}")
        
        # Dump hexadecimal
        self.print_hex_dump(data)
        
        # Dados brutos em hex
        hex_data = ' '.join(f'{b:02X}' for b in data)
        print(f"{Fore.YELLOW}Raw: {hex_data}{Style.RESET_ALL}")
        print("-" * 80)
        
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
            
    def packet_handler(self, packet):
        """Processa cada pacote capturado"""
        try:
            if not packet.haslayer(TCP) or not packet.haslayer(IP):
                return
                
            ip_layer = packet[IP]
            tcp_layer = packet[TCP]
            
            # Verifica se é o IP e porta que queremos monitorar
            is_from_server = (ip_layer.src == self.target_ip and tcp_layer.sport == self.target_port)
            is_to_server = (ip_layer.dst == self.target_ip and tcp_layer.dport == self.target_port)
            
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
                    
                    # Formata e exibe o pacote
                    opcode = self.format_packet_data(payload, direction, timestamp)
                    
                    if opcode is not None:
                        self.packet_types[opcode] += 1
                        self.packet_lengths[opcode].append(len(payload))
                    
        except Exception as e:
            print(f"{Fore.RED}Erro ao processar pacote: {e}{Style.RESET_ALL}")
            
    def print_statistics(self):
        """Imprime estatísticas dos pacotes"""
        if self.total_packets == 0:
            return
            
        print(f"\n{Fore.CYAN}{'='*60}")
        print(f"ESTATÍSTICAS")
        print(f"{'='*60}{Style.RESET_ALL}")
        
        elapsed = (datetime.now() - self.start_time).total_seconds()
        
        print(f"{Fore.WHITE}Tempo de execução: {elapsed:.1f}s")
        print(f"Total de pacotes: {self.total_packets}")
        print(f"Pacotes recebidos: {self.packets_received}")
        print(f"Pacotes enviados: {self.packets_sent}")
        print(f"Taxa: {self.total_packets/elapsed:.2f} pacotes/s{Style.RESET_ALL}")
        
        if self.packet_types:
            print(f"\n{Fore.YELLOW}Top 10 Opcodes:{Style.RESET_ALL}")
            sorted_opcodes = sorted(self.packet_types.items(), key=lambda x: x[1], reverse=True)[:10]
            
            print(f"{'Opcode':<8} {'Count':<8} {'Avg Size':<10} {'Type'}")
            print("-" * 40)
            
            for opcode, count in sorted_opcodes:
                lengths = self.packet_lengths[opcode]
                avg_size = sum(lengths) / len(lengths)
                
                # Determina se é pacote fixo ou variável
                unique_lengths = set(lengths)
                packet_type = "Fixed" if len(unique_lengths) == 1 else "Variable"
                type_color = Fore.GREEN if packet_type == "Fixed" else Fore.YELLOW
                
                print(f"0x{opcode:04X}   {count:<8} {avg_size:<10.1f} {type_color}{packet_type}{Style.RESET_ALL}")
        
        print()
        
    def start_statistics_thread(self):
        """Thread para imprimir estatísticas periodicamente"""
        def stats_loop():
            while self.running:
                time.sleep(30)  # Estatísticas a cada 30 segundos
                if self.running:
                    self.print_statistics()
                    
        thread = threading.Thread(target=stats_loop, daemon=True)
        thread.start()
        
    def start_capture(self):
        """Inicia a captura de pacotes"""
        try:
            self.print_header()
            
            # Filtro BPF para TCP no IP e porta específicos
            bpf_filter = f"tcp and host {self.target_ip} and port {self.target_port}"
            
            print(f"{Fore.GREEN}Iniciando captura...")
            print(f"Filtro: {bpf_filter}")
            if self.interface:
                print(f"Interface: {self.interface}")
            print(f"Pressione Ctrl+C para parar{Style.RESET_ALL}\n")
            
            self.running = True
            self.start_time = datetime.now()
            
            # Inicia thread de estatísticas
            self.start_statistics_thread()
            
            # Inicia captura
            sniff(
                iface=self.interface,
                filter=bpf_filter,
                prn=self.packet_handler,
                store=0,
                stop_filter=lambda p: not self.running
            )
            
        except KeyboardInterrupt:
            print(f"\n{Fore.YELLOW}Captura interrompida pelo usuário{Style.RESET_ALL}")
        except PermissionError:
            print(f"{Fore.RED}Erro: Permissões insuficientes. Execute como administrador/root{Style.RESET_ALL}")
        except Exception as e:
            print(f"{Fore.RED}Erro durante captura: {e}{Style.RESET_ALL}")
        finally:
            self.running = False
            self.print_statistics()
            
    def stop_capture(self):
        """Para a captura"""
        self.running = False

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
        description="ROla Packet Sniffer - Monitora tráfego TCP para IP e porta específicos",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos de uso:
  python packet_sniffer.py 192.168.1.100 6900
  python packet_sniffer.py 35.198.41.33 10009 -i "Wi-Fi"
  python packet_sniffer.py --list-interfaces
        """
    )
    
    parser.add_argument('ip', nargs='?', help='IP do servidor para monitorar')
    parser.add_argument('port', nargs='?', type=int, help='Porta do servidor para monitorar')
    parser.add_argument('-i', '--interface', help='Interface de rede específica (use nome ou número da lista)')
    parser.add_argument('--list-interfaces', action='store_true', 
                       help='Lista as interfaces de rede disponíveis')
    
    args = parser.parse_args()
    
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
    if not args.ip or not args.port:
        parser.print_help()
        return
        
    # Valida IP
    try:
        socket.inet_aton(args.ip)
    except socket.error:
        print(f"{Fore.RED}Erro: IP inválido '{args.ip}'{Style.RESET_ALL}")
        return
        
    # Valida porta
    if not (1 <= args.port <= 65535):
        print(f"{Fore.RED}Erro: Porta deve estar entre 1 e 65535{Style.RESET_ALL}")
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
                    print(f"Usando interface: {iface['friendly_name']}")
                    found = True
                    break
            
            if not found:
                print(f"{Fore.RED}Erro: Interface '{args.interface}' não encontrada. Use --list-interfaces{Style.RESET_ALL}")
                return
    
    # Cria e inicia o sniffer
    sniffer = PacketSniffer(args.ip, args.port, interface_name)
    
    try:
        sniffer.start_capture()
    except KeyboardInterrupt:
        print(f"\n{Fore.YELLOW}Programa encerrado{Style.RESET_ALL}")

if __name__ == "__main__":
    main() 