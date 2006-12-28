This was the old packet extractor script, which was used before
a GUI was written. To use this script, follow these instructions:

1. Disassemble the RO client with the following command:

       objdump -d -M intel Ragexe.exe > ragexe.exe

2. Generate a recvpackets.txt:

       ./extract-packets.pl ragexe.exe recvpackets.txt