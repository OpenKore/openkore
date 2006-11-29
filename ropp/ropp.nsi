#########################################################
#  OpenKore - ROpp Installer
#  Copyright (c) 2006 ViVi
#
# This installer is licensed under Creative Commons "Attribution-NonCommercial-ShareAlike 2.5"
#
# You are free:
#    * to copy, distribute, display, and perform the work
#    * to make derivative works
# 
# Under the following conditions:
#    * by Attribution: You must attribute the work in the manner specified by the author or licensor.
#    * Noncommercial: You may not use this work for commercial purposes.
#    * Share Alike: If you alter, transform, or build upon this work, you may distribute the resulting work 
# 	 only under a license identical to this one.
#
#    * For any reuse or distribution, you must make clear to others the license terms of this work.
#    * Any of these conditions can be waived if you get permission from the copyright holder.
#
# Your fair use and other rights are in no way affected by the above.
#
# This is a human-readable summary of the Legal Code 
# ( Full License: http://creativecommons.org/licenses/by-nc-sa/2.5/legalcode ). 
# Disclaimer: http://creativecommons.org/licenses/disclaimer-popup?lang=en
# 
###########################################################

;--------------------------------
;Include Modern UI

  !include "MUI.nsh"

;--------------------------------
;General

	;Name and file
	Name "OpenKore ROpp"
	OutFile "ROpp Installer.exe"

	;Get installation folder from registry if available
	InstallDirRegKey HKCU "Software\OpenKore" ""

	BrandingText "http://www.openkore.com"
	ShowInstDetails show
	ShowUninstDetails show
	CRCCheck force
	
;--------------------------------
;Interface Settings

	!define MUI_ABORTWARNING

;--------------------------------
;Pages
	
	DirText "Please select the folder where Openkore is located" "OpenKore location" "Browse" "Select the folder where OpenKore is located"
	; Installer Pages
	!insertmacro MUI_PAGE_LICENSE "installer_license.txt"
	
	!insertmacro MUI_PAGE_DIRECTORY
	!insertmacro MUI_PAGE_INSTFILES
	!insertmacro MUI_PAGE_FINISH
	
	; Uninstaller pages
	!insertmacro MUI_UNPAGE_WELCOME
	!insertmacro MUI_UNPAGE_CONFIRM
	!insertmacro MUI_UNPAGE_INSTFILES
	!insertmacro MUI_UNPAGE_FINISH

;--------------------------------
;Languages

	!insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Installer Sections

Section !Required
	SectionIn RO
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Product" "OpenKore ROpp" "OpenKore ROpp"
	
	SetOutPath "$INSTDIR"
	;Store installation folder
	WriteRegStr HKCU "Software\OpenKore ROpp" "" $INSTDIR

	; Get files
	  File /r /x "src" /x ".svn" "API.dll"
	  File /r /x "src" /x ".svn" "API.pm"
	  File /r /x "src" /x ".svn" "Callback.pm"
	  File /r /x "src" /x ".svn" "Struct.pm"
	  File /r /x "src" /x ".svn" "Type.pm"
	  File /r /x "src" /x ".svn" "ropp.dll"
	  File /r /x "src" /x ".svn" "ropp.pl"
	  
	;Create uninstaller
	WriteUninstaller "$INSTDIR\ROpp Uninstall.exe"
	
SectionEnd

;--------------------------------

;--------------------------------
;Uninstaller Section

Section "Uninstall"

  ; Delete files  
  Delete "$INSTDIR\auto\win32\api\API.dll"
  Delete "$INSTDIR\plugin\ropp.pl"
  Delete "$INSTDIR\Win32\API.pm"
  Delete "$INSTDIR\Win32\API\Callback.pm"
  Delete "$INSTDIR\Win32\API\Struct.pm"
  Delete "$INSTDIR\Win32\API\Type.pm"
  
  DeleteRegKey HKCU "Software\OpenKore"

SectionEnd

;--------------------------------
; Misc functions
Function .onInit

	; Make sure we're only running the installer ONCE
	System::Call 'kernel32::CreateMutexA(i 0, i 0, t "OpenKore SVN") i .r1 ?e'
	Pop $R0
	StrCmp $R0 0 +3
		MessageBox MB_OK|MB_ICONEXCLAMATION "The installer is already running."
		Abort
	
	; Splash Screen
	InitPluginsDir
	File /oname=$PLUGINSDIR\splash.bmp "splash.bmp"

	advsplash::show 3000 1000 1000 -1 $PLUGINSDIR\splash

	Pop $0          ; $0 has '1' if the user closed the splash screen early,
					; '0' if everything closed normally, and '-1' if some error occurred.

	Delete $PLUGINSDIR\splash.bmp
FunctionEnd