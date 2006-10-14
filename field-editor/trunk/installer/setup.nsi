; ---- Installer attributes ----

Name "OpenKore Field Editor"
SetCompressor /SOLID zlib
OutFile InstallFieldEditor.exe
SetPluginUnload alwaysoff
ShowInstDetails show
InstallDir "$PROGRAMFILES\OpenKore Field Editor"
XPStyle on


; ---- Initialization ----

!include "MUI.nsh"
!include "WinMessages.nsh"
!include "DotNet.nsh"
!include "GtkSharp.nsh"


!insertmacro DOT_NET_RESERVE_FILE
!insertmacro GTK_SHARP_RESERVE_FILE
!insertmacro MUI_RESERVEFILE_INSTALLOPTIONS
!insertmacro MUI_RESERVEFILE_LANGDLL


; ---- Global variables ----

var StartMenuName
var AddRemoveKey


; ---- Pages ----

!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro DOT_NET_CHECK_PAGE
!insertmacro MUI_PAGE_LICENSE "..\LICENSE.TXT"
!insertmacro MUI_PAGE_DIRECTORY

!define MUI_STARTMENUPAGE_DEFAULTFOLDER "OpenKore"
!define MUI_STARTMENUPAGE_REGISTRY_ROOT "HKCU" 
!define MUI_STARTMENUPAGE_REGISTRY_KEY "Software\OpenKore Field Editor"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "Start Menu Folder"
!insertmacro MUI_PAGE_STARTMENU OpenKore $StartMenuName

!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"


; ---- Sections ----

Section "Field Editor"
	call GtkSharp_Install

	SetOutPath $INSTDIR

	File ..\bin\Release\FieldEditor.exe

	!insertmacro MUI_STARTMENU_WRITE_BEGIN OpenKore
	CreateDirectory "$SMPROGRAMS\$StartMenuName"
	CreateShortCut "$SMPROGRAMS\$StartMenuName\Field Editor.lnk" "$INSTDIR\FieldEditor.exe"
	!insertmacro MUI_STARTMENU_WRITE_END

	WriteUninstaller "$INSTDIR\UninstallFieldEditor.exe"

	StrCpy $AddRemoveKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenKore Field Editor"
	WriteRegStr HKLM $AddRemoveKey "DisplayName" "OpenKore Field Editor"
	WriteRegStr HKLM $AddRemoveKey "UninstallString" "$INSTDIR\UninstallFieldEditor.exe"
SectionEnd

Section "Uninstall"
	!insertmacro MUI_STARTMENU_GETFOLDER OpenKore $R0
	Delete "$SMPROGRAMS\$R0\Field Editor.lnk"
	RMDir "$SMPROGRAMS\$R0"

	Delete "$INSTDIR\FieldEditor.exe"
	Delete "$INSTDIR\UninstallFieldEditor.exe"

	StrCpy $AddRemoveKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenKore Field Editor"
	DeleteRegValue HKLM $AddRemoveKey "DisplayName"
	DeleteRegValue HKLM $AddRemoveKey "UninstallString"
	DeleteRegKey HKLM $AddRemoveKey
	RMDir "$INSTDIR"
SectionEnd


; ---- Functions ----

Function .onInit
	!insertmacro DOT_NET_INIT
	!insertmacro GTK_SHARP_INIT
FunctionEnd
