@Echo Off
set mm=%date:~3,2%
set dd=%date:~0,2%
set yyyy=%date:~6,4%
for %%I In (*.exe) Do (
if %%I neq start.exe if %%I neq extractor.exe start.exe ! packet_extract.pl "%%I"
if exist extractor.exe extractor.exe > recvpackets_%%I_%yyyy%-%mm%-%dd%.txt)
pause