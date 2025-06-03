# export_and_convert_recvpackets.py
# By Kurisu (#xsirch Discord)
# Script único (IDAPython) que:
# 1) Percorre todos os XREFs a sub_A358A0,
#    extrai os quatro “push” anteriores (flag, raw2, raw3, opcode),
#    converte raw2/raw3 e flag para signed32, e define min_len/max_len.
# 2) Gera dois arquivos no diretório do .idb:
#       • RawRecvpackets.txt     (blocos de “push” + mov/call)
#       • recvpackets.txt        (linhas “OPCODE_HEX MIN_LEN MAX_LEN FLAG”)
#
# Para usar:
# 1. Copie este script para a mesma pasta do seu IDA .idb.
# 2. Abra o IDA e carregue o projeto.
# 3. Vá em File → Script file… (ou pressione Alt+F7) e selecione este arquivo.
# 4. O IDA criará RawRecvpackets.txt e recvpackets.txt na pasta do .idb.

import idaapi
import idc
import idautils
import os
import struct

def ea_to_str(ea):
    return "%08X" % ea

def to_signed32(x):
    """
    Interpreta x (0 ≤ x < 2^32) como signed int32.
    Ex: 0xFFFFFFFF → -1, 0xFFFFFFFE → -2, etc.
    """
    return x if x < 0x80000000 else x - 0x100000000

def main():
    # 1) Localiza o endereço de sub_A358A0
    ea_func = idc.get_name_ea_simple("sub_A358A0")
    if ea_func == idc.BADADDR:
        print("[ERROR] Função 'sub_A358A0' não encontrada.")
        return

    # 2) Define caminhos de saída na mesma pasta do .idb
    idb_path      = idaapi.get_root_filename()
    base_dir      = os.path.dirname(os.path.abspath(idb_path))
    raw_path      = os.path.join(base_dir, "RawRecvpackets.txt")
    recv_path     = os.path.join(base_dir, "recvpackets.txt")
    addr_path     = os.path.join(base_dir, "recvpackets_with_addresses.txt")

    # 3) Abre recvpackets_with_addresses.txt para regravar (opcional, mas mantém histórico)
    f_addr = open(addr_path, "w", encoding="utf-8")
    f_addr.write("; endereço     opcode   min     max   flag\n")

    # 4) Coleta entradas: cada elemento é (ea_push, opcode_u32, min_len, max_len, flag_signed)
    all_entries = []
    for xref in idautils.XrefsTo(ea_func, flags=0):
        call_ea = xref.frm
        pushes  = []
        cur     = call_ea
        # retrocede até capturar 4 instruções PUSH
        while len(pushes) < 4:
            cur = idc.prev_head(cur)
            if cur == idc.BADADDR:
                break
            if idc.print_insn_mnem(cur).lower() == "push":
                pushes.insert(0, cur)
        if len(pushes) != 4:
            continue

        # 5) Extrai valores literais de cada PUSH (interpreta como unsigned32)
        vals = []
        for ea_push in pushes:
            op = idc.print_operand(ea_push, 0).rstrip(",")
            if op.lower().endswith("h"):
                try:
                    v = int(op[:-1], 16) & 0xFFFFFFFF
                except:
                    v = 0
            else:
                try:
                    v = int(op, 10) & 0xFFFFFFFF
                except:
                    v = 0
            vals.append(v)

        # 6) Interpreta vals = [flag_u32, raw2_u32, raw3_u32, opcode_u32]
        flag_u32   = vals[0]
        raw2_u32   = vals[1]
        raw3_u32   = vals[2]
        opcode_u32 = vals[3]

        # 7) Converte raw2/raw3 para signed32
        signed2 = to_signed32(raw2_u32)
        signed3 = to_signed32(raw3_u32)

        # 8) Define min_len/max_len via signed‐min/max
        if signed2 <= signed3:
            min_len = signed2
            max_len = signed3
        else:
            min_len = signed3
            max_len = signed2

        # 9) Converte flag para signed32
        flag_signed = to_signed32(flag_u32)

        # 10) O opcode permanece unsigned (0 ≤ x < 2^32)
        opcode = opcode_u32

        # 11) Armazena para gerar RawRecvpackets.txt e recvpackets_with_addresses.txt
        all_entries.append((pushes[0], opcode, min_len, max_len, flag_signed))

        # 12) Preenche recvpackets_with_addresses.txt
        addr_str   = ea_to_str(pushes[0])
        opcode_str = "%04X" % opcode
        f_addr.write(f"{addr_str}   {opcode_str}      {min_len:>4}  {max_len:>5}  {flag_signed}\n")

    f_addr.close()
    print(f"[+] recvpackets_with_addresses.txt gerado em:\n    {addr_path}")

    # 13) Gera RawRecvpackets.txt
    all_entries.sort(key=lambda x: x[0])  # ordena por endereço
    with open(raw_path, "w", encoding="utf-8") as f_raw:
        for ea_push, opcode, min_len, max_len, flag_signed in all_entries:
            # Formação dos campos para o push:
            # - se max_len < 0, escrevemos "0xFFFFFFFFh"
            if max_len < 0:
                max_field = "0xFFFFFFFFh"
            else:
                max_field = str(max_len)
            # min_len negativo já está em forma "-1", "-2", etc.
            min_field = str(min_len)
            # flag_signed negativo se era 0xFFFFFFFF originalmente, caso contrário positivo
            flag_field = str(flag_signed)
            opcode_h   = f"{opcode:X}h"

            f_raw.write(f"; at {ea_to_str(ea_push)}\n")
            f_raw.write(f"push    {flag_field}\n")
            f_raw.write(f"push    {min_field}\n")
            f_raw.write(f"push    {max_field}\n")
            f_raw.write(f"push    {opcode_h}\n")
            f_raw.write(f"mov     ecx, esi\n")
            f_raw.write(f"call    sub_A358A0\n\n")

    print(f"[+] RawRecvpackets.txt gerado em:\n    {raw_path}")

    # 14) Gera recvpackets.txt diretamente, usando all_entries
    with open(recv_path, "w", encoding="utf-8") as f_recv:
        for (_ea_push, opcode, min_len, max_len, flag_signed) in all_entries:
            opcode_hex = f"{opcode:04X}"
            f_recv.write(f"{opcode_hex} {min_len} {max_len} {flag_signed}\n")

    print(f"[+] recvpackets.txt gerado em:\n    {recv_path}")

if __name__ == "__main__":
    main()
