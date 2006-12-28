/* Select disassembly routine for specified architecture.
   Copyright 1994, 1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003,
   2004, 2005 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  */

#include "sysdep.h"
#include "dis-asm.h"

#define ARCH_i386


disassembler_ftype
disassembler (abfd)
     bfd *abfd;
{
  enum bfd_architecture a = bfd_get_arch (abfd);
  disassembler_ftype disassemble;

  switch (a)
    {
      /* If you add a case to this table, also add it to the
	 ARCH_all definition right above this function.  */

    case bfd_arch_i386:
      disassemble = print_insn_i386;
      break;
    default:
      return 0;
    }
  return disassemble;
}

void
disassembler_usage (stream)
     FILE * stream ATTRIBUTE_UNUSED;
{
#ifdef ARCH_arm
  print_arm_disassembler_options (stream);
#endif
#ifdef ARCH_mips
  print_mips_disassembler_options (stream);
#endif
#ifdef ARCH_powerpc
  print_ppc_disassembler_options (stream);
#endif

  return;
}

void
disassemble_init_for_target (struct disassemble_info * info)
{
  if (info == NULL)
    return;

  switch (info->arch)
    {
#ifdef ARCH_arm
    case bfd_arch_arm:
      info->symbol_is_valid = arm_symbol_is_valid;
      break;
#endif
#ifdef ARCH_ia64
    case bfd_arch_ia64:
      info->skip_zeroes = 16;
      break;
#endif
#ifdef ARCH_tic4x
    case bfd_arch_tic4x:
      info->skip_zeroes = 32;
#endif
    default:
      break;
    }
}
