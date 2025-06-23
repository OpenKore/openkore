# export_and_convert_recvpackets.py
# By Kurisu (#xsirch Discord)
# Single script (IDAPython) that:
# 1) Traverses all XREFs to sub_A358A0,
#    extracts the four previous "push" instructions (flag, raw2, raw3, opcode),
#    converts raw2/raw3 and flag to signed32, and defines min_len/max_len.
# 2) Generates two files in the .idb directory:
#       • RawRecvpackets.txt     ("push" blocks + mov/call)
#       • recvpackets.txt        ("OPCODE_HEX MIN_LEN MAX_LEN FLAG" lines)
#
# To use:
# 1. Copy this script to the same folder as your IDA .idb.
# 2. Open IDA and load the project.
# 3. Go to File → Script file… (or press Alt+F7) and select this file.
# 4. IDA will create RawRecvpackets.txt and recvpackets.txt in the .idb folder.

import idaapi
import idc
import idautils
import os
import struct

def ea_to_str(ea):
    return "%08X" % ea

def to_signed32(x):
    """
    Interprets x (0 ≤ x < 2^32) as signed int32.
    Ex: 0xFFFFFFFF → -1, 0xFFFFFFFE → -2, etc.
    """
    return x if x < 0x80000000 else x - 0x100000000

def main():
    # 1) Locate the address of sub_A358A0
    ea_func = idc.get_name_ea_simple("sub_A358A0")
    if ea_func == idc.BADADDR:
        print("[ERROR] Function 'sub_A358A0' not found.")
        return

    # 2) Define output paths in the same folder as the .idb
    idb_path      = idaapi.get_root_filename()
    base_dir      = os.path.dirname(os.path.abspath(idb_path))
    raw_path      = os.path.join(base_dir, "RawRecvpackets.txt")
    recv_path     = os.path.join(base_dir, "recvpackets.txt")
    addr_path     = os.path.join(base_dir, "recvpackets_with_addresses.txt")

    # 3) Open recvpackets_with_addresses.txt for rewriting (optional, but keeps history)
    f_addr = open(addr_path, "w", encoding="utf-8")
    f_addr.write("; address      opcode   min     max   flag\n")

    # 4) Collect entries: each element is (ea_push, opcode_u32, min_len, max_len, flag_signed)
    all_entries = []
    for xref in idautils.XrefsTo(ea_func, flags=0):
        call_ea = xref.frm
        pushes  = []
        cur     = call_ea
        # go backwards until capturing 4 PUSH instructions
        while len(pushes) < 4:
            cur = idc.prev_head(cur)
            if cur == idc.BADADDR:
                break
            if idc.print_insn_mnem(cur).lower() == "push":
                pushes.insert(0, cur)
        if len(pushes) != 4:
            continue

        # 5) Extract literal values from each PUSH (interpret as unsigned32)
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

        # 6) Interpret vals = [flag_u32, raw2_u32, raw3_u32, opcode_u32]
        flag_u32   = vals[0]
        raw2_u32   = vals[1]
        raw3_u32   = vals[2]
        opcode_u32 = vals[3]

        # 7) Convert raw2/raw3 to signed32
        signed2 = to_signed32(raw2_u32)
        signed3 = to_signed32(raw3_u32)

        # 8) Define min_len/max_len via signed min/max
        if signed2 <= signed3:
            min_len = signed2
            max_len = signed3
        else:
            min_len = signed3
            max_len = signed2

        # 9) Convert flag to signed32
        flag_signed = to_signed32(flag_u32)

        # 10) The opcode remains unsigned (0 ≤ x < 2^32)
        opcode = opcode_u32

        # 11) Store to generate RawRecvpackets.txt and recvpackets_with_addresses.txt
        all_entries.append((pushes[0], opcode, min_len, max_len, flag_signed))

        # 12) Fill recvpackets_with_addresses.txt
        addr_str   = ea_to_str(pushes[0])
        opcode_str = "%04X" % opcode
        f_addr.write(f"{addr_str}   {opcode_str}      {min_len:>4}  {max_len:>5}  {flag_signed}\n")

    f_addr.close()
    print(f"[+] recvpackets_with_addresses.txt generated at:\n    {addr_path}")

    # 13) Generate RawRecvpackets.txt
    all_entries.sort(key=lambda x: x[0])  # sort by address
    with open(raw_path, "w", encoding="utf-8") as f_raw:
        for ea_push, opcode, min_len, max_len, flag_signed in all_entries:
            # Field formatting for push:
            # - if max_len < 0, write "0xFFFFFFFFh"
            if max_len < 0:
                max_field = "0xFFFFFFFFh"
            else:
                max_field = str(max_len)
            # negative min_len is already in "-1", "-2", etc. format
            min_field = str(min_len)
            # flag_signed negative if it was originally 0xFFFFFFFF, positive otherwise
            flag_field = str(flag_signed)
            opcode_h   = f"{opcode:X}h"

            f_raw.write(f"; at {ea_to_str(ea_push)}\n")
            f_raw.write(f"push    {flag_field}\n")
            f_raw.write(f"push    {min_field}\n")
            f_raw.write(f"push    {max_field}\n")
            f_raw.write(f"push    {opcode_h}\n")
            f_raw.write(f"mov     ecx, esi\n")
            f_raw.write(f"call    sub_A358A0\n\n")

    print(f"[+] RawRecvpackets.txt generated at:\n    {raw_path}")

    # 14) Generate recvpackets.txt directly, using all_entries
    with open(recv_path, "w", encoding="utf-8") as f_recv:
        for (_ea_push, opcode, min_len, max_len, flag_signed) in all_entries:
            opcode_hex = f"{opcode:04X}"
            f_recv.write(f"{opcode_hex} {min_len} {max_len} {flag_signed}\n")

    print(f"[+] recvpackets.txt generated at:\n    {recv_path}")

if __name__ == "__main__":
    main()
