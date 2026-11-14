/*
 * Hacker Disassembler Engine 32 C
 * Copyright (c) 2008-2009, Vyacheslav Patkov.
 * All rights reserved.
 *
 */

#if defined(_M_IX86) || defined(__i386__)

#include <string.h>
#include "hde32.h"
#include "table32.h"

/* An instruction is at most 15 bytes long, so the bytes past that may not be
 * mapped: a decode that would run over the limit stops instead of reading. */
#define NEED(n) do { if (limit - p < (n)) goto error_length; } while (0)

unsigned int hde32_disasm(const void *code, hde32s *hs)
{
    uint8_t x, c, *p = (uint8_t *)code, cflags, opcode, pref = 0, mand = 0;
    uint8_t map0f = 0;          /* the opcode came from the 0F map */
    uint8_t *ht = hde32_table, m_mod, m_reg, m_rm, disp_size = 0;
    uint8_t ext = 0;
    uint8_t *limit = (uint8_t *)code + 15;

    memset(hs, 0, sizeof(hde32s));

    for (x = 15; x; x--)
        switch (c = *p++) {
            case 0xf3:
                hs->p_rep = c;
                pref |= PRE_F3;
                mand = PRE_F3;
                break;
            case 0xf2:
                hs->p_rep = c;
                pref |= PRE_F2;
                mand = PRE_F2;
                break;
            case 0xf0:
                hs->p_lock = c;
                pref |= PRE_LOCK;
                break;
            case 0x26: case 0x2e: case 0x36:
            case 0x3e: case 0x64: case 0x65:
                hs->p_seg = c;
                pref |= PRE_SEG;
                break;
            case 0x66:
                hs->p_66 = c;
                pref |= PRE_66;
                if (!mand)
                    mand = PRE_66;
                break;
            case 0x67:
                hs->p_67 = c;
                pref |= PRE_67;
                break;
            default:
                goto pref_done;
        }
    goto error_length;          /* 15 prefixes leave no room for an opcode */

  pref_done:

    hs->flags = (uint32_t)pref << 23;

    if (!pref)
        pref |= PRE_NONE;
    /* pref says which prefix classes are present, which is what an
     * operand-size or LOCK rule asks. A mandatory prefix is a choice
     * between 66, F2 and F3 rather than a set, so the rules that select
     * an instruction read mand instead. */
    if (!mand)
        mand = PRE_NONE;

    /* VEX, EVEX and XOP. C4, C5 and 62 keep their legacy meaning unless the
     * byte after them has mod = 11, which les, lds and bound cannot encode;
     * 8F is an escape only from map 8 upwards, which leaves 8F /0 as pop. The
     * header names the opcode map, the map decides the immediate, and every
     * instruction reached this way has a ModR/M byte. */
    if (p < limit &&
        (((c == 0xc4 || c == 0xc5 || c == 0x62) && (*p & 0xc0) == 0xc0) ||
         (c == 0x8f && (*p & 0x1f) >= 8))) {
        uint8_t map;

        hs->opcode = c;
        if (c == 0xc5) {
            NEED(3);
            map = 1;
            p++;
        } else if (c == 0x62) {
            NEED(5);
            /* The bit above the map is APX's B4, which selects r16-r31 and
             * so exists only in long mode. Here it is a reserved zero, and
             * an encoding that sets it is not an instruction whatever the
             * map bits below it say. */
            if (*p & 0x08)
                hs->flags |= F_ERROR | F_ERROR_OPCODE;
            map = *p & 0x07;
            p += 3;
        } else {
            NEED(4);
            map = *p & 0x1f;
            p += 2;
        }
        hs->opcode2 = opcode = *p++;

        /* The escape carries the operand size itself, so a 66, F2, F3 or LOCK
         * in front of it is invalid. A segment or 67 prefix still applies. */
        if (pref & (PRE_66 | PRE_F2 | PRE_F3 | PRE_LOCK))
            hs->flags |= F_ERROR | F_ERROR_OPCODE;
        pref &= ~PRE_66;

        cflags = C_MODRM;
        if (c == 0x8f) {
            switch (map) {
                case 8:                 /* every XOP8 opcode takes an imm8 */
                    cflags |= C_IMM8;
                    break;
                case 9:                 /* no XOP9 opcode takes one */
                    break;
                case 10:                /* bextr and the lwp forms: imm32 */
                    cflags |= C_IMM_P66;
                    break;
                default:
                    hs->flags |= F_ERROR | F_ERROR_OPCODE;
                    break;
            }
        } else switch (map) {
            case 1:                     /* 0F map */
                if (opcode == 0x70 || (opcode >= 0x71 && opcode <= 0x73) ||
                    opcode == 0xc2 || (opcode >= 0xc4 && opcode <= 0xc6))
                    cflags |= C_IMM8;
                else if (c != 0x62 && opcode == 0x77)
                    cflags = C_NONE;    /* vzeroupper and vzeroall: no ModR/M */
                break;
            case 2:                     /* 0F 38 map: never an immediate */
                break;
            case 3:                     /* 0F 3A map: always an imm8 */
                cflags |= C_IMM8;
                break;
            case 5: case 6:             /* half-precision maps, EVEX only */
                if (c != 0x62)
                    hs->flags |= F_ERROR | F_ERROR_OPCODE;
                else if (map == 5 && (opcode == 0x08 || opcode == 0x0a ||
                                      opcode == 0x26 || opcode == 0x27 ||
                                      opcode == 0x56 || opcode == 0x57 ||
                                      opcode == 0x66 || opcode == 0x67 ||
                                      opcode == 0xc2))
                    cflags |= C_IMM8;   /* the 0F 3A forms of that map */
                break;
            default:
                hs->flags |= F_ERROR | F_ERROR_OPCODE;
                break;
        }
        ext = 1;
        x = 0;
        goto modrm;
    }

    if ((hs->opcode = c) == 0x0f) {
        NEED(1);
        hs->opcode2 = c = *p++;
        map0f = 1;
        if (c == 0x38 || c == 0x3a) {
            /* Three-byte maps: the opcode follows and always has a ModR/M
             * byte. Every 0F 3A opcode takes an imm8, no 0F 38 one does, and
             * none of them is lockable. */
            NEED(2);
            opcode = *p++;
            cflags = (c == 0x3a) ? (C_MODRM | C_IMM8) : C_MODRM;
            if (pref & PRE_LOCK)
                hs->flags |= F_ERROR | F_ERROR_LOCK;
            ext = 1;
            x = 0;
            goto modrm;
        }
        ht += DELTA_OPCODES;
    } else if (c >= 0xa0 && c <= 0xa3) {
        if (pref & PRE_67)
            pref |= PRE_66;
        else
            pref &= ~PRE_66;
    }

    opcode = c;
    cflags = ht[ht[opcode / 4] + (opcode % 4)];

    if (cflags == C_ERROR) {
        /* The table carries no entry for the opcode. Some of these are real
         * instructions whose shape is known, and flagging one denies the caller a
         * length it could have used; the rest keep F_ERROR, because the opcode
         * is not one this engine can claim to know. */
        cflags = 0;
        if (map0f && (opcode == 0x0b ||
                            (opcode == 0x37 &&
                             mand == PRE_NONE))) {
            ;                           /* ud2 and getsec take no operand */
        } else if (map0f && (opcode == 0xa6 || opcode == 0xa7 ||
                                   opcode == 0xb9 || opcode == 0xff)) {
            cflags = C_MODRM;           /* PadLock, ud1 and ud0 */
        } else {
            hs->flags |= F_ERROR | F_ERROR_OPCODE;
            if (map0f && (opcode & -3) == 0x24)
                cflags = C_MODRM;       /* the test registers: shape only */
        }
    }

    x = 0;
    if (cflags & C_GROUP) {
        uint16_t t;
        t = *(uint16_t *)(ht + (cflags & 0x7f));
        cflags = (uint8_t)t;
        x = (uint8_t)(t >> 8);
    }

    if (map0f) {
        ht = hde32_table + DELTA_PREFIXES;
        /* movntsd and movntss are F2 0F 2B and F3 0F 2B. The row 0F 2B
         * reads rejects both, and it is shared with a neighbour that has
         * no such form, so the exception lives here rather than in the
         * table. */
        if ((ht[ht[opcode / 4] + (opcode % 4)] & mand) &&
            !(opcode == 0x2b && (mand & (PRE_F2 | PRE_F3))))
            hs->flags |= F_ERROR | F_ERROR_OPCODE;
        /* vmread, vmwrite and popcnt take a ModR/M byte that the table cannot
         * give them: their entries share a row with opcodes that take none. */
        if (opcode == 0x78 || opcode == 0x79 || opcode == 0xb8)
            cflags |= C_MODRM;
    }

  modrm:
    if (cflags & C_MODRM) {
        hs->flags |= F_MODRM;
        NEED(1);
        hs->modrm = c = *p++;
        hs->modrm_mod = m_mod = c >> 6;
        hs->modrm_rm = m_rm = c & 7;
        hs->modrm_reg = m_reg = (c & 0x3f) >> 3;

        if (x && ((x << m_reg) & 0x80))
            hs->flags |= F_ERROR | F_ERROR_OPCODE;

        if (ext)
            goto no_error_operand;      /* no legacy operand rule applies */

        if (!map0f && opcode >= 0xd9 && opcode <= 0xdf) {
            uint8_t t = opcode - 0xd9;
            if (m_mod == 3) {
                ht = hde32_table + DELTA_FPU_MODRM + t*8;
                t = ht[m_reg] << m_rm;
            } else {
                ht = hde32_table + DELTA_FPU_REG;
                t = ht[t] << m_reg;
            }
            if (t & 0x80)
                hs->flags |= F_ERROR | F_ERROR_OPCODE;
        }

        if (pref & PRE_LOCK) {
            if (m_mod == 3) {
                hs->flags |= F_ERROR | F_ERROR_LOCK;
            } else {
                uint8_t *table_end, op = opcode;
                if (map0f) {
                    ht = hde32_table + DELTA_OP2_LOCK_OK;
                    table_end = ht + DELTA_OP_ONLY_MEM - DELTA_OP2_LOCK_OK;
                } else {
                    ht = hde32_table + DELTA_OP_LOCK_OK;
                    table_end = ht + DELTA_OP2_LOCK_OK - DELTA_OP_LOCK_OK;
                    op &= -2;
                }
                for (; ht != table_end; ht++)
                    if (*ht++ == op) {
                        if (!((*ht << m_reg) & 0x80))
                            goto no_lock_error;
                        else
                            break;
                    }
                hs->flags |= F_ERROR | F_ERROR_LOCK;
              no_lock_error:
                ;
            }
        }

        if (map0f) {
            switch (opcode) {
                case 0x20: case 0x22:
                    m_mod = 3;
                    if (m_reg > 4 || m_reg == 1)
                        goto error_operand;
                    else
                        goto no_error_operand;
                case 0x21: case 0x23:
                    m_mod = 3;
                    /* dr4 and dr5 alias dr6 and dr7 unless CR4.DE is set, so
                     * they decode rather than fault. */
                    goto no_error_operand;
            }
        } else {
            switch (opcode) {
                case 0x8c:
                    if (m_reg > 5)
                        goto error_operand;
                    else
                        goto no_error_operand;
                case 0x8e:
                    if (m_reg == 1 || m_reg > 5)
                        goto error_operand;
                    else
                        goto no_error_operand;
            }
        }

        if (m_mod == 3) {
            uint8_t *table_end;
            if (map0f) {
                ht = hde32_table + DELTA_OP2_ONLY_MEM;
                table_end = ht + sizeof(hde32_table) - DELTA_OP2_ONLY_MEM;
            } else {
                ht = hde32_table + DELTA_OP_ONLY_MEM;
                table_end = ht + DELTA_OP2_ONLY_MEM - DELTA_OP_ONLY_MEM;
            }
            for (; ht != table_end; ht += 2)
                if (*ht++ == opcode) {
                    if ((*ht++ & mand) && !((*ht << m_reg) & 0x80))
                        goto error_operand;
                    else
                        break;
                }
            goto no_error_operand;
        } else if (map0f) {
            switch (opcode) {
                case 0x50: case 0xd7: case 0xf7:
                    if (mand & (PRE_NONE | PRE_66))
                        goto error_operand;
                    break;
                case 0xd6:
                    if (mand & (PRE_F2 | PRE_F3))
                        goto error_operand;
                    break;
                case 0xc5:
                    goto error_operand;
            }
            goto no_error_operand;
        } else
            goto no_error_operand;

      error_operand:
        hs->flags |= F_ERROR | F_ERROR_OPERAND;
      no_error_operand:

        /* Group 3: F6 /0 and /1 take an imm8, F7 /0 and /1 an imm32 or imm16.
         * The rule belongs to the one-byte map; 0F F6 and 0F F7 are psadbw
         * and maskmovq, which take neither. */
        if (!ext && !map0f && m_reg <= 1) {
            if (opcode == 0xf6)
                cflags |= C_IMM8;
            else if (opcode == 0xf7)
                cflags |= C_IMM_P66;
        }
        /* C7 /7 is xbegin, whose immediate is a displacement. */
        if (!ext && !map0f && opcode == 0xc7 && m_reg == 7)
            hs->flags |= F_RELATIVE;
        /* extrq and insertq take two imm8 operands where vmread takes none. */
        if (!ext && map0f && opcode == 0x78 && (mand & (PRE_66 | PRE_F2)))
            cflags |= C_IMM16;

        switch (m_mod) {
            case 0:
                if (pref & PRE_67) {
                    if (m_rm == 6)
                        disp_size = 2;
                } else
                    if (m_rm == 5)
                        disp_size = 4;
                break;
            case 1:
                disp_size = 1;
                break;
            case 2:
                disp_size = 2;
                if (!(pref & PRE_67))
                    disp_size <<= 1;
                break;
        }

        if (m_mod != 3 && m_rm == 4 && !(pref & PRE_67)) {
            hs->flags |= F_SIB;
            NEED(1);
            hs->sib = c = *p++;
            hs->sib_scale = c >> 6;
            hs->sib_index = (c & 0x3f) >> 3;
            if ((hs->sib_base = c & 7) == 5 && !(m_mod & 1))
                disp_size = 4;
        }

        if (disp_size) {
            NEED(disp_size);
            switch (disp_size) {
                case 1:
                    hs->flags |= F_DISP8;
                    hs->disp.disp8 = *p;
                    break;
                case 2:
                    hs->flags |= F_DISP16;
                    hs->disp.disp16 = *(uint16_t *)p;
                    break;
                case 4:
                    hs->flags |= F_DISP32;
                    hs->disp.disp32 = *(uint32_t *)p;
                    break;
            }
            p += disp_size;
        }
    } else if (pref & PRE_LOCK)
        hs->flags |= F_ERROR | F_ERROR_LOCK;

    if (cflags & C_IMM_P66) {
        if (cflags & C_REL32) {
            if (pref & PRE_66) {
                NEED(2);
                hs->flags |= F_IMM16 | F_RELATIVE;
                hs->imm.imm16 = *(uint16_t *)p;
                p += 2;
                goto disasm_done;
            }
            goto rel32_ok;
        }
        if (pref & PRE_66) {
            NEED(2);
            hs->flags |= F_IMM16;
            hs->imm.imm16 = *(uint16_t *)p;
            p += 2;
        } else {
            NEED(4);
            hs->flags |= F_IMM32;
            hs->imm.imm32 = *(uint32_t *)p;
            p += 4;
        }
    }

    if (cflags & C_IMM16) {
        NEED(2);
        if (hs->flags & F_IMM32) {
            hs->flags |= F_IMM16;
            hs->disp.disp16 = *(uint16_t *)p;
        } else if (hs->flags & F_IMM16) {
            hs->flags |= F_2IMM16;
            hs->disp.disp16 = *(uint16_t *)p;
        } else {
            hs->flags |= F_IMM16;
            hs->imm.imm16 = *(uint16_t *)p;
        }
        p += 2;
    }
    if (cflags & C_IMM8) {
        NEED(1);
        hs->flags |= F_IMM8;
        if (hs->flags & F_IMM16)
            hs->disp.disp8 = *p++;      /* enter: the union holds the imm16 */
        else
            hs->imm.imm8 = *p++;
    }

    if (cflags & C_REL32) {
      rel32_ok:
        NEED(4);
        hs->flags |= F_IMM32 | F_RELATIVE;
        hs->imm.imm32 = *(uint32_t *)p;
        p += 4;
    } else if (cflags & C_REL8) {
        NEED(1);
        hs->flags |= F_IMM8 | F_RELATIVE;
        hs->imm.imm8 = *p++;
    }

  disasm_done:

    hs->len = (uint8_t)(p - (uint8_t *)code);
    return (unsigned int)hs->len;

  error_length:

    hs->flags |= F_ERROR | F_ERROR_LENGTH;
    hs->len = 15;
    return 15;
}

#undef NEED

#endif // defined(_M_IX86) || defined(__i386__)
