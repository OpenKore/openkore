!macro GTK_SHARP_RESERVE_FILE
	ReserveFile "..\bin\Release\GtkSharpCheck.exe"
	ReserveFile "GtkSharp.ini"
!macroend

!macro GTK_SHARP_INIT
	!insertmacro MUI_INSTALLOPTIONS_EXTRACT "GtkSharp.ini"
!macroend

Function GtkSharp_Install
	DetailPrint "Checking whether Gtk-Sharp Runtime Environment is installed..."
	call GtkSharp_IsInstalled
	pop $0
	StrCmp $0 0 done noGtkSharp

	; Download and install Gtk-Sharp.
	noGtkSharp:
	DetailPrint "Gtk-Sharp is not installed. Downloading it from Internet..."
	NSISdl::download \
		"http://forgeftp.novell.com/gtks-inst4win/Win32%20Runtime%20Installer/v2.7.1/gtksharp-runtime-2.7.1-win32-0.4.exe" \
		"$PLUGINSDIR\gtksharp-runtime.exe"
	pop $0
	StrCmp $0 "success" downloaded
	StrCmp $0 "cancel" canceled

	; Some download error occured.
	!insertmacro MUI_HEADER_TEXT "Gtk-Sharp Runtime Environment not found" $0
	!insertmacro MUI_INSTALLOPTIONS_DISPLAY "GtkSharp.ini"
	; The user can only click Cancel at this point.

	; Gtk-Sharp downloaded, run the Gtk-Sharp installer.
	downloaded:
	ExecWait "$PLUGINSDIR\gtksharp-runtime.exe" $0
	StrCmp $0 0 done
	DetailPrint "Unable to install Gtk-Sharp Runtime Environment."
	Abort "Installation aborted."

	; Download canceled.
	canceled:
	DetailPrint "You chose to stop downloading Gtk-Sharp."
	DetailPrint "Setup cannot continue without Gtk-Sharp."
	Abort "Installation aborted."

	; Gtk-Sharp installed.
	done:
FunctionEnd

; Check whether Gtk-Sharp is installed.
; Usage:
;   call IsGtkSharpInstalled
;   pop $0
;   StrCmp $0 0 is_installed not_installed
Function GtkSharp_IsInstalled
	Push $0
	File "/oname=$PLUGINSDIR\GtkSharpCheck.exe" ..\bin\Release\GtkSharpCheck.exe
	ExecWait '"$PLUGINSDIR\GtkSharpCheck.exe"' $0
	Exch $0
FunctionEnd