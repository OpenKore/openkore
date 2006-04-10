This module contains tools for extracting packet lengths from Ragexe.exe.

disasm is version 0.25 of the Win32Program Disassembler:
http://www.geocities.com/~sangcho/disasm.html
It's modified so it can be compiled on Linux.


First, you use disasm to disassemble Ragexe.exe:

	./disasm Ragexe.exe > disassembled.txt

Then, you run extract-packets.pl to extract packet lengths from 
disassembled.txt:

	./extract-packets.pl disassembled.txt recvpackets.txt
