@ECHO Off
SET mm=%date:~3,2%
SET dd=%date:~0,2%
SET yyyy=%date:~6,4%

IF EXIST extractor.exe (DEL extractor.exe)

FOR %%I IN (*.exe) DO (
	IF %%I NEQ start.exe IF %%I NEQ extractor.exe (
		start.exe ! packet_extract.pl "%%I"
		IF EXIST extractor.exe (
			extractor.exe > recvpackets_%%I_%yyyy%-%mm%-%dd%.txt
			echo .
			DEL extractor.exe
		)
	)
)

PAUSE