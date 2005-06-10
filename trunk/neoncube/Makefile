# Microsoft Developer Studio Generated NMAKE File, Based on neoncube.dsp
!IF "$(CFG)" == ""
CFG=neoncube - Win32 Debug
!MESSAGE No configuration specified. Defaulting to neoncube - Win32 Debug.
!ENDIF 

!IF "$(CFG)" != "neoncube - Win32 Release" && "$(CFG)" != "neoncube - Win32 Debug"
!MESSAGE Invalid configuration "$(CFG)" specified.
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "neoncube.mak" CFG="neoncube - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "neoncube - Win32 Release" (based on "Win32 (x86) Application")
!MESSAGE "neoncube - Win32 Debug" (based on "Win32 (x86) Application")
!MESSAGE 
!ERROR An invalid configuration is specified.
!ENDIF 

!IF "$(OS)" == "Windows_NT"
NULL=
!ELSE 
NULL=nul
!ENDIF 

!IF  "$(CFG)" == "neoncube - Win32 Release"

OUTDIR=.\Release
INTDIR=.\Release
# Begin Custom Macros
OutDir=.\Release
# End Custom Macros

ALL : "$(OUTDIR)\neoncube.exe"


CLEAN :
	-@erase "$(INTDIR)\btn_load.obj"
	-@erase "$(INTDIR)\grf_func.obj"
	-@erase "$(INTDIR)\main.obj"
	-@erase "$(INTDIR)\resource.res"
	-@erase "$(INTDIR)\vc60.idb"
	-@erase "$(OUTDIR)\neoncube.exe"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

CPP=cl.exe
CPP_PROJ=/nologo /ML /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /Fp"$(INTDIR)\neoncube.pch" /YX /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /c 

.c{$(INTDIR)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cpp{$(INTDIR)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cxx{$(INTDIR)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.c{$(INTDIR)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cpp{$(INTDIR)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cxx{$(INTDIR)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

MTL=midl.exe
MTL_PROJ=/nologo /D "NDEBUG" /mktyplib203 /win32 
RSC=rc.exe
RSC_PROJ=/l 0x409 /fo"$(INTDIR)\resource.res" /d "NDEBUG" 
BSC32=bscmake.exe
BSC32_FLAGS=/nologo /o"$(OUTDIR)\neoncube.bsc" 
BSC32_SBRS= \
	
LINK32=link.exe
LINK32_FLAGS=kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib comctl32.lib wininet.lib grf.lib /nologo /subsystem:windows /incremental:no /pdb:"$(OUTDIR)\neoncube.pdb" /machine:I386 /out:"$(OUTDIR)\neoncube.exe" 
LINK32_OBJS= \
	"$(INTDIR)\btn_load.obj" \
	"$(INTDIR)\grf_func.obj" \
	"$(INTDIR)\main.obj" \
	"$(INTDIR)\resource.res"

"$(OUTDIR)\neoncube.exe" : "$(OUTDIR)" $(DEF_FILE) $(LINK32_OBJS)
    $(LINK32) @<<
  $(LINK32_FLAGS) $(LINK32_OBJS)
<<

!ELSEIF  "$(CFG)" == "neoncube - Win32 Debug"

OUTDIR=.\Debug
INTDIR=.\Debug
# Begin Custom Macros
OutDir=.\Debug
# End Custom Macros

ALL : "$(OUTDIR)\neoncube.exe" "$(OUTDIR)\neoncube.bsc"


CLEAN :
	-@erase "$(INTDIR)\btn_load.obj"
	-@erase "$(INTDIR)\btn_load.sbr"
	-@erase "$(INTDIR)\grf_func.obj"
	-@erase "$(INTDIR)\grf_func.sbr"
	-@erase "$(INTDIR)\main.obj"
	-@erase "$(INTDIR)\main.sbr"
	-@erase "$(INTDIR)\resource.res"
	-@erase "$(INTDIR)\vc60.idb"
	-@erase "$(INTDIR)\vc60.pdb"
	-@erase "$(OUTDIR)\neoncube.bsc"
	-@erase "$(OUTDIR)\neoncube.exe"
	-@erase "$(OUTDIR)\neoncube.ilk"
	-@erase "$(OUTDIR)\neoncube.pdb"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

CPP=cl.exe
CPP_PROJ=/nologo /MTd /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "_MBCS" /FR"$(INTDIR)\\" /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /GZ /c 

.c{$(INTDIR)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cpp{$(INTDIR)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cxx{$(INTDIR)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.c{$(INTDIR)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cpp{$(INTDIR)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cxx{$(INTDIR)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

MTL=midl.exe
MTL_PROJ=/nologo /D "_DEBUG" /mktyplib203 /win32 
RSC=rc.exe
RSC_PROJ=/l 0x409 /fo"$(INTDIR)\resource.res" /d "_DEBUG" 
BSC32=bscmake.exe
BSC32_FLAGS=/nologo /o"$(OUTDIR)\neoncube.bsc" 
BSC32_SBRS= \
	"$(INTDIR)\btn_load.sbr" \
	"$(INTDIR)\grf_func.sbr" \
	"$(INTDIR)\main.sbr"

"$(OUTDIR)\neoncube.bsc" : "$(OUTDIR)" $(BSC32_SBRS)
    $(BSC32) @<<
  $(BSC32_FLAGS) $(BSC32_SBRS)
<<

LINK32=link.exe
LINK32_FLAGS=kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib comctl32.lib wininet.lib grf.lib /nologo /subsystem:windows /incremental:yes /pdb:"$(OUTDIR)\neoncube.pdb" /debug /machine:I386 /out:"$(OUTDIR)\neoncube.exe" /pdbtype:sept 
LINK32_OBJS= \
	"$(INTDIR)\btn_load.obj" \
	"$(INTDIR)\grf_func.obj" \
	"$(INTDIR)\main.obj" \
	"$(INTDIR)\resource.res"

"$(OUTDIR)\neoncube.exe" : "$(OUTDIR)" $(DEF_FILE) $(LINK32_OBJS)
    $(LINK32) @<<
  $(LINK32_FLAGS) $(LINK32_OBJS)
<<

!ENDIF 


!IF "$(NO_EXTERNAL_DEPS)" != "1"
!IF EXISTS("neoncube.dep")
!INCLUDE "neoncube.dep"
!ELSE 
!MESSAGE Warning: cannot find "neoncube.dep"
!ENDIF 
!ENDIF 


!IF "$(CFG)" == "neoncube - Win32 Release" || "$(CFG)" == "neoncube - Win32 Debug"
SOURCE=.\btn_load.cpp

!IF  "$(CFG)" == "neoncube - Win32 Release"


"$(INTDIR)\btn_load.obj" : $(SOURCE) "$(INTDIR)"


!ELSEIF  "$(CFG)" == "neoncube - Win32 Debug"


"$(INTDIR)\btn_load.obj"	"$(INTDIR)\btn_load.sbr" : $(SOURCE) "$(INTDIR)"


!ENDIF 

SOURCE=.\grf_func.cpp

!IF  "$(CFG)" == "neoncube - Win32 Release"


"$(INTDIR)\grf_func.obj" : $(SOURCE) "$(INTDIR)"


!ELSEIF  "$(CFG)" == "neoncube - Win32 Debug"


"$(INTDIR)\grf_func.obj"	"$(INTDIR)\grf_func.sbr" : $(SOURCE) "$(INTDIR)"


!ENDIF 

SOURCE=.\main.cpp

!IF  "$(CFG)" == "neoncube - Win32 Release"


"$(INTDIR)\main.obj" : $(SOURCE) "$(INTDIR)"


!ELSEIF  "$(CFG)" == "neoncube - Win32 Debug"


"$(INTDIR)\main.obj"	"$(INTDIR)\main.sbr" : $(SOURCE) "$(INTDIR)"


!ENDIF 

SOURCE=.\resource.rc

"$(INTDIR)\resource.res" : $(SOURCE) "$(INTDIR)"
	$(RSC) $(RSC_PROJ) $(SOURCE)



!ENDIF 

