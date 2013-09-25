# http://forums.openkore.com/viewtopic.php?f=36
This module contains tools for extracting packet lengths from your ragexe file name.

USAGE

Variant 1 (for noobs):
1) Download start.exe from http://misc.openkore.com and unpack to the same folder where packet_extract.pl is placed.
2) Copy target .exe file to the same folder where packet_extract.pl is placed.
3) Run packet_extract.bat to save extracted packets to text file.

Variant 2 (for profi):
1) Download start.exe from http://misc.openkore.com and unpack to the same folder where packet_extract.pl is placed (optional).
3) Copy target .exe file to the same folder where packet_extract.pl is placed.
4) Run "start.exe ! packet_extract.pl your_exe_name.exe" or "perl packet_extract.pl your_exe_name.exe" to generate extractor.exe.
5) Run "extractor.exe > recvpackets.txt" to save extracted packets to text file.
