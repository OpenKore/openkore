# http://forums.openkore.com/viewtopic.php?f=36
This module contains tools for extracting packet lengths from your ragexe file name.

USAGE

Variant 1 (for noobs):
1) Download start.exe from http://misc.openkore.com and unpack to the same folder where packet_extract.pl is placed (optional)
2) copy target .exe file to the same folder where packet_extract.pl is placed
3) run packet_extract.bat to save extracted packets to text file.

Variant 2 (for profi):
1) Download start.exe from http://misc.openkore.com and unpack to the same folder where packet_extract.pl is placed (optional)
3) copy target .exe file to the same folder where packet_extract.pl is placed
4) run "start.exe ! packet_extract.pl your_exe_name.exe" or "perl packet_extract.pl your_exe_name.exe" to generate extractor.exe
5) run "extractor.exe > recvpackets.txt" to save extracted packets to text file.
