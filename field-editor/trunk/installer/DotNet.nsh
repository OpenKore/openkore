!macro DOT_NET_CHECK_PAGE
	page custom DotNet_Check DotNet_CheckErrors
!macroend

!macro DOT_NET_RESERVE_FILE
	ReserveFile "DotNet.ini"
!macroend

!macro DOT_NET_INIT
	!insertmacro MUI_INSTALLOPTIONS_EXTRACT "DotNet.ini"
!macroend

Function DotNet_Check
	Banner::show /NOUNLOAD "Checking for .NET Framework..."
	call DotNet_IsInstalled
	Banner::destroy
	pop $0
	StrCmp $0 1 done noDotNet

	noDotNet:
	SetErrors
	!insertmacro MUI_HEADER_TEXT "Microsoft .NET Framework not found" ""
	!insertmacro MUI_INSTALLOPTIONS_DISPLAY "DotNet.ini"
	goto done

	done:
FunctionEnd

Function DotNet_CheckErrors
	IfErrors +1 done
	quit
	done:
FunctionEnd

Function DotNet_IsInstalled
	Push $0
	Push $1

	System::Call "mscoree::GetCORVersion(w .r0, i ${NSIS_MAX_STRLEN}, *i) i .r1"
	StrCmp $1 0 foundDotNet noDotNet

	noDotNET:
	StrCpy $0 0
	Goto done

	foundDotNET:
	StrCpy $0 1

	done:
	Pop $1
	Exch $0
FunctionEnd
