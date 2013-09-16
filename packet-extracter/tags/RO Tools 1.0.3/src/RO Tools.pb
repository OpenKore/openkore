; ****************************************************
; * Name: Packet Extractor
; * Version: 1.0.3
; * Usage: Packet Length Extractor
; * Copyright ©2006 JCV <JCV@JCVsite.com>
; * Maintained By: OpenKore Project <www.openkore.com>
; ****************************************************

;{- Enumerations

Enumeration
  #winMain
EndEnumeration

Enumeration
  #strFilePath
  #btnFileOpen
  #tabExtract
  #btnExit
  #btnAbout
  #chkSaveDisasm
  #strExtractResult
  #btnStartExtract
  #optGenType_0
  #optGenType_1
  #optGenType_2
  #chkFindStorageKey
  #strStorageKey
  #strPatchResult
  #btnStartPatch
  #chkDisableGG
  #chkNoSPTele
  #chkStandAlone
  #chkDataFolder
  #chkMoreZoom
  #chkWOEDamage
  #chkMouseFreedom
  #btnOtherPatch
EndEnumeration

#TEXTLEN = 256
#MAXCMDSIZE = 16

#DISASM_SIZE = 0               ; Determine command size only
#DISASM_DATA = 1               ; Determine size And analysis Data
#DISASM_FILE = 3               ; Disassembly, no symbols
#DISASM_CODE = 4               ; Full disassembly

Structure t_disasm
  ip.l
  dump.s{#TEXTLEN}
  Result.s{#TEXTLEN}
  Comment.s{#TEXTLEN}
  cmdtype.l
  memtype.l
  nprefix.l
  indexed.l
  jmpconst.l
  jmptable.l
  adrconst.l
  immconst.l
  zeroconst.l
  fixupoffset.l
  fixupsize.l
  error.l
  warnings.l
EndStructure

Structure t_asmmodel
  code.s{#MAXCMDSIZE}
  mask.s{#MAXCMDSIZE}
  length.l
  jmpsize.l
  jmpoffset.l
  jmppos.l
EndStructure

Structure s_disasm
  dump.s
  offset.s
  command.s
  instLen.l
EndStructure

#IMAGE_SIZEOF_SHORT_NAME = 8

Structure IMAGE_SECTION_HEADER
  Name.b[#IMAGE_SIZEOF_SHORT_NAME]
  StructureUnion
    PhysicalAddress.l
    VirtualSize.l
  EndStructureUnion
  VirtualAddress.l
  SizeOfRawData.l
  PointerToRawData.l
  PointerToRelocations.l
  PointerToLinenumbers.l
  NumberOfRelocations.w
  NumberOfLinenumbers.w
  Characteristics.l
EndStructure

Structure packetList
  switch.s
  length.l
EndStructure

#IMAGE_DOS_SIGNATURE = $5A4D
#IMAGE_NT_SIGNATURE = $4550
#CRLF = Chr(13) + Chr(10)

Global POINTERTORAW, SIZEOFRAW, VIRTUALADR, VIRTUALBASEADR

Global programName.s = "JCV's RO Tools v1.0.3"
Global Filelength = 0
Global exePath.s = GetPathPart(ProgramFilename())
Global roPath.s = ""
Global roPath2.s = ""
Global total.l = 0
Global Dim rawData.c(0)
Global Dim asmArray.s(0)
Global function_start.l = 0
Global function_end.l = 0
Global extractType = 1
Global MemoryPointer

Declare disassemble()
Declare Read_File()

;- Misc Function

Procedure isHex(input.s) ; Check if its a valid hex
  For x = 1 To Len(input)
    If Asc(Mid(input, x, 1)) < 48
      ProcedureReturn #False
    EndIf
    If Asc(Mid(input, x, 1)) > 57 And Asc(Mid(input, x, 1)) < 65
      ProcedureReturn #False
    EndIf
    If Asc(Mid(input, x, 1)) > 70 And Asc(Mid(input, x, 1)) < 97
      ProcedureReturn #False
    EndIf
    If Asc(Mid(input, x, 1)) > 102
      ProcedureReturn #False
    EndIf
  Next
  ProcedureReturn #True
EndProcedure

Procedure hex2Dec(a$) ; Convert Hex to Decimal
  a$=Trim(UCase(a$))  
  If Asc(a$)='$'  
    a$=Trim(Mid(a$,2,Len(a$)-1))  
  EndIf  
  Result=0  
  *adr.Byte=@a$  
  For i=1 To Len(a$)  
    Result<<4  
    Select *adr\b  
      Case '0'  
      Case '1':Result+1  
      Case '2':Result+2  
      Case '3':Result+3  
      Case '4':Result+4  
      Case '5':Result+5  
      Case '6':Result+6  
      Case '7':Result+7  
      Case '8':Result+8  
      Case '9':Result+9  
      Case 'A':Result+10  
      Case 'B':Result+11  
      Case 'C':Result+12  
      Case 'D':Result+13  
      Case 'E':Result+14  
      Case 'F':Result+15  
      Default:i=Len(a$)  
    EndSelect  
    *adr+1  
  Next  
  ProcedureReturn Result  
EndProcedure

;- Window

Procedure winMain_OpenWindow() ; Setup Main Window
  If OpenWindow(#winMain, 392, 291, 465, 268, programName, #PB_Window_SystemMenu|#PB_Window_MinimizeGadget|#PB_Window_TitleBar|#PB_Window_ScreenCentered)
    If CreateGadgetList(WindowID(#winMain))
      StringGadget(#strFilePath, 60, 5, 365, 20, "")
      ButtonGadget(#btnFileOpen, 430, 5, 30, 20, "...")
      TextGadget(#PB_Any, 10, 10, 45, 15, "File Path:")
      ButtonGadget(#btnExit, 385, 240, 75, 25, "E&xit")
      ButtonGadget(#btnAbout, 305, 240, 75, 25, "&About")
      CheckBoxGadget(#chkSaveDisasm, 5, 243, 155, 15, "Save disassembled output")
      PanelGadget(#tabExtract, 5, 30, 455, 205)
        ; Generate recvpackets.txt
        AddGadgetItem(#tabExtract, -1, "Generate recvpackets.txt")
        ContainerGadget(#PB_Any, 0, 0, 450, 180, #PB_Container_Single)
          StringGadget(#strExtractResult, 5, 5, 430, 85, "", # ES_MULTILINE|#ES_AUTOVSCROLL|#WS_VSCROLL)
          SendMessage_(GadgetID(#strExtractResult), #EM_LIMITTEXT, 65536, 0)
          ButtonGadget(#btnStartExtract, 370, 105, 75, 70, "Start")
          OptionGadget(#optGenType_0, 15, 125, 85, 15, "Binary Search")
          OptionGadget(#optGenType_1, 15, 140, 85, 15, "Fast Disasm")
          OptionGadget(#optGenType_2, 15, 155, 85, 15, "Full Disasm")
          SetGadgetState(#optGenType_1, extractType)
          Frame3DGadget(#PB_Any, 5, 105, 115, 70, "Extraction Type")
          StringGadget(#strStorageKey, 135, 125, 225, 45, "")
          Frame3DGadget(#PB_Any, 130, 110, 235, 65, "")
          CheckBoxGadget(#chkFindStorageKey, 140, 105, 95, 20, "Find StorageKey")
        CloseGadgetList()
        ; Auto-Patcher
        AddGadgetItem(#tabExtract, -1, "Auto-Patcher")
        ContainerGadget(#PB_Any, 0, 0, 450, 180, #PB_Container_Single)
          StringGadget(#strPatchResult, 5, 5, 430, 85, "", #ES_MULTILINE|#ES_AUTOVSCROLL|#WS_VSCROLL)
          ButtonGadget(#btnStartPatch, 370, 105, 75, 70, "Patch")
          CheckBoxGadget(#chkDisableGG, 5, 115, 130, 15, "Disable Game-Guard")
          CheckBoxGadget(#chkNoSPTele, 5, 135, 130, 15, "No-SP Teleport")
          CheckBoxGadget(#chkStandAlone, 5, 155, 130, 15, "Stand Alone")
          CheckBoxGadget(#chkDataFolder, 135, 115, 110, 15, "Read Data Folder")
          CheckBoxGadget(#chkMoreZoom, 135, 135, 110, 15, "More Zoom Range")
          CheckBoxGadget(#chkWOEDamage, 135, 155, 110, 15, "Show WOE Damage")
          CheckBoxGadget(#chkMouseFreedom, 255, 115, 105, 15, "Mouse Freedom")
          ButtonGadget(#btnOtherPatch, 255, 145, 110, 25, "Other Patches")
        CloseGadgetList()
      CloseGadgetList()
    EndIf
  EndIf
EndProcedure

Procedure AddText_toExtractor(msg.s) ; Add Text
  SendMessage_(GadgetID(#strExtractResult),#EM_SETSEL,$FFFF,$FFFF)
  SendMessage_(GadgetID(#strExtractResult), #EM_REPLACESEL, 0, msg + #CRLF)  
EndProcedure

Procedure AddText_toPatcher(msg.s) ; Add Text
  SendMessage_(GadgetID(#strPatchResult),#EM_SETSEL,$FFFF,$FFFF)
  SendMessage_(GadgetID(#strPatchResult), #EM_REPLACESEL, 0, msg + #CRLF)  
EndProcedure

Procedure output(loc, msg.s)
  If loc = 0
    AddText_toExtractor(msg)
  ;Else
    ;AddText_toPatcher(msg)
  EndIf
  
EndProcedure

;- Patcher

Procedure.l Patch_File(file.s, location.l, *placeMe, length) 
  If OpenFile(0,file)
    For x = 0 To length
      FileSeek(0, location+x)
      WriteByte(0, PeekC(*placeMe+x))
    Next
    CloseFile(0)
    ProcedureReturn 1
  EndIf 
EndProcedure 

Procedure.l Find_Offset(*findThis, findLength, *findHere, findTotal)
  x = 0
  found = 0
  offset = 0
  While x < findTotal
    If PeekC(*findHere+x) = PeekC(*findThis+found)
      found + 1
      If found = findLength
        x - (found - 1)
        offset = x
        Break
      EndIf
    Else
      If x > 0
        x - found
      EndIf
      found = 0
    EndIf
    x + 1
  Wend
  ProcedureReturn offset
EndProcedure

Procedure Find_GameGuard()
  foundIt = #False
  offset_call.s = ""
  For x = POINTERTORAW To total
    If FindString(asmArray(x), "SUB ESP,500", 8) > 0
      AddText_toPatcher("GameGuard offset found!")
      While FindString(asmArray(x), "PUSH EBP", 8) <= 0
        x - 1
      Wend
      offset_call = "CALL " + Left(asmArray(x), 8)
      Break
    EndIf
  Next
  
  If offset_call = ""
    AddText_toPatcher("GameGuard function not found!")
    ProcedureReturn #False
  EndIf
  
  patch_offset.s = ""
  For x = POINTERTORAW To total
    If FindString(asmArray(x), offset_call, 8) > 0
      AddText_toPatcher("Offset to patch found!")
      patch_offset = Left(asmArray(x), 8)
      Break
    EndIf
  Next
  
  
  If patch_offset = ""
    AddText_toPatcher("GameGuard function call not found!")
    ProcedureReturn #False
  EndIf
  
  offset = hex2Dec(patch_offset) - $400000
  
  AddText_toPatcher("--------------------------------------")
  AddText_toPatcher("offset  : (Hex) " + RSet(Hex(offset), 8, "0") + " Or (Dec) " + Str(offset))
  AddText_toPatcher("Search  : " + RSet(Hex(Asc(Chr(rawData(offset+0)))), 2, "0") + " " + RSet(Hex(Asc(Chr(rawData(offset+1)))), 2, "0") + " " + RSet(Hex(Asc(Chr(rawData(offset+2)))), 2, "0") + " " + RSet(Hex(Asc(Chr(rawData(offset+3)))), 2, "0") + " " + RSet(Hex(Asc(Chr(rawData(offset+4)))), 2, "0") )
  AddText_toPatcher("Replace : 90 90 90 90 90")
  AddText_toPatcher("--------------------------------------")
  
  AddText_toPatcher("Patching GameGuard Call...")
  
  total = 4
  Dim findMe.c(total)
  Dim placeMe.c(total)
  findMe(0) = rawData(offset+0)
  findMe(1) = rawData(offset+1)
  findMe(2) = rawData(offset+2)
  findMe(3) = rawData(offset+3)
  findMe(4) = rawData(offset+4)
  offset.l = Find_Offset(@findMe(), total, @rawData(), Filelength)
  If offset <> 0
    AddText_toPatcher("GameGuard patch found!")
    placeMe(0) = $90
    placeMe(1) = $90
    placeMe(2) = $90
    placeMe(3) = $90
    placeMe(4) = $90
    If Patch_File(roPath2, offset, @placeMe(), total)
      AddText_toPatcher("GameGuard successfully patched!")
    EndIf
  Else
    AddText_toPatcher("GameGuard patch not found!")
  EndIf
  
  ProcedureReturn #True
EndProcedure

Procedure Patch_ChangeCaption()
  total = 9
  Dim findMe.c(total)
  Dim placeMe.c(total)
  findMe(0) = $52
  findMe(1) = $61
  findMe(2) = $67
  findMe(3) = $6E
  findMe(4) = $61
  findMe(5) = $72
  findMe(6) = $6F
  findMe(7) = $6B
  findMe(8) = $00
  findMe(9) = $00
  offset.l = Find_Offset(@findMe(), total, @rawData(), Filelength)
  If offset <> 0
    AddText_toPatcher("Change caption patch found!")
    placeMe(0) = $61
    placeMe(1) = $44
    placeMe(2) = $44
    placeMe(3) = $4F
    placeMe(4) = $4E
    placeMe(5) = $62
    placeMe(6) = $79
    placeMe(7) = $4A
    placeMe(8) = $43
    placeMe(9) = $56
    If Patch_File(roPath2, offset, @placeMe(), total)
      AddText_toPatcher("Change caption successfully patched!")
    EndIf
  Else
    AddText_toPatcher("Change caption patch not found!")
  EndIf
EndProcedure

Procedure Patch_ChangeIcon()
  total = 11
  Dim findMe.c(total)
  Dim placeMe.c(total)
  findMe(0) = $72
  findMe(1) = $00
  findMe(2) = $00
  findMe(3) = $00
  findMe(4) = $10
  findMe(5) = $01
  findMe(6) = $00
  findMe(7) = $80
  findMe(8) = $77
  findMe(9) = $00
  findMe(10) = $00
  findMe(11) = $00
  offset.l = Find_Offset(@findMe(), total, @rawData(), Filelength)
  If offset <> 0
    AddText_toPatcher("Change icon patch found!")
    placeMe(0) = $72
    placeMe(1) = $00
    placeMe(2) = $00
    placeMe(3) = $00
    placeMe(4) = $28
    placeMe(5) = $01
    placeMe(6) = $00
    placeMe(7) = $80
    placeMe(8) = $77
    placeMe(9) = $00
    placeMe(10) = $00
    placeMe(11) = $00
    If Patch_File(roPath2, offset, @placeMe(), total)
      AddText_toPatcher("Change icon successfully patched!")
    EndIf
  Else
    AddText_toPatcher("Change icon patch not found!")
  EndIf
EndProcedure

Procedure Patch_DataFolder()
  total = 7
  Dim findMe.c(total)
  Dim placeMe.c(total)
  findMe(0) = $84
  findMe(1) = $C0
  findMe(2) = $F
  findMe(3) = $84
  findMe(4) = $AB
  findMe(5) = $0
  findMe(6) = $0
  findMe(7) = $0
  offset.l = Find_Offset(@findMe(), total, @rawData(), Filelength)
  If offset <> 0
    AddText_toPatcher("Data folder patch found!")
    placeMe(0) = $90
    placeMe(1) = $90
    placeMe(2) = $90
    placeMe(3) = $90
    placeMe(4) = $90
    placeMe(5) = $90
    placeMe(6) = $90
    placeMe(7) = $90
    If Patch_File(roPath2, offset, @placeMe(), total)
      AddText_toPatcher("Read Data folder successfully patched!")
    EndIf
  Else
    AddText_toPatcher("Data folder patch not found!")
  EndIf
EndProcedure

Procedure Patch_Mouse()
  total = 9
  Dim findMe.c(total)
  Dim placeMe.c(total)
  findMe(0) = $44
  findMe(1) = $49
  findMe(2) = $4E
  findMe(3) = $50
  findMe(4) = $55
  findMe(5) = $54
  findMe(6) = $2E
  findMe(7) = $64
  findMe(8) = $6C
  findMe(9) = $6C
  offset.l = Find_Offset(@findMe(), total, @rawData(), Filelength)
  If offset <> 0
    AddText_toPatcher("Mouse Freedom patch found!")
    placeMe(0) = $6D
    placeMe(1) = $6F
    placeMe(2) = $75
    placeMe(3) = $73
    placeMe(4) = $65
    placeMe(5) = $5F
    placeMe(6) = $2E
    placeMe(7) = $6A
    placeMe(8) = $63
    placeMe(9) = $76
    If Patch_File(roPath2, offset, @placeMe(), total)
      AddText_toPatcher("Mouse Freedom successfully patched!")
    EndIf
  Else
    AddText_toPatcher("Mouse Freedom not found!")
  EndIf
EndProcedure

Procedure Patch_Network1()
  total = 9
  Dim findMe.c(total)
  Dim placeMe.c(total)
  findMe(0) = $77
  findMe(1) = $73
  findMe(2) = $32
  findMe(3) = $5F
  findMe(4) = $33
  findMe(5) = $32
  findMe(6) = $2E
  findMe(7) = $64
  findMe(8) = $6C
  findMe(9) = $6C
  offset.l = Find_Offset(@findMe(), total, @rawData(), Filelength)
  If offset <> 0
    AddText_toPatcher("Network dll offset found!")
    placeMe(0) = $6E 
    placeMe(1) = $6F
    placeMe(2) = $73
    placeMe(3) = $70
    placeMe(4) = $5F
    placeMe(5) = $74
    placeMe(6) = $2E
    placeMe(7) = $6A
    placeMe(8) = $63
    placeMe(9) = $76
    If Patch_File(roPath2, offset, @placeMe(), total)
      AddText_toPatcher("Network dll (1) successfully patched!")
    EndIf
  Else
    AddText_toPatcher("Network dll offset not found!")
  EndIf
EndProcedure

Procedure Patch_Network2()
  total = 9
  Dim findMe.c(total)
  Dim placeMe.c(total)
  findMe(0) = $57
  findMe(1) = $53
  findMe(2) = $32
  findMe(3) = $5F
  findMe(4) = $33
  findMe(5) = $32
  findMe(6) = $2E
  findMe(7) = $64
  findMe(8) = $6C
  findMe(9) = $6C
  offset.l = Find_Offset(@findMe(), total, @rawData(), Filelength)
  If offset <> 0
    AddText_toPatcher("Network dll 2 offset found!")
    placeMe(0) = $6E 
    placeMe(1) = $6F
    placeMe(2) = $73
    placeMe(3) = $70
    placeMe(4) = $5F
    placeMe(5) = $74
    placeMe(6) = $2E
    placeMe(7) = $6A
    placeMe(8) = $63
    placeMe(9) = $76
    If Patch_File(roPath2, offset, @placeMe(), total)
      AddText_toPatcher("Network dll (2) successfully patched!")
    EndIf
  Else
    AddText_toPatcher("Network dll 2 offset NOT found!")
  EndIf
EndProcedure

Procedure Patch_StandAlone()
  total = 11
  Dim findMe.c(total)
  Dim placeMe.c(total)
  findMe(0) = $83
  findMe(1) = $C4
  findMe(2) = $08
  findMe(3) = $85
  findMe(4) = $C0
  findMe(5) = $0F
  findMe(6) = $85
  findMe(7) = $85
  findMe(8) = $00
  findMe(9) = $00
  findMe(10) = $00
  findMe(11) = $68
  offset.l = Find_Offset(@findMe(), total, @rawData(), Filelength)
  If offset <> 0
    AddText_toPatcher("Stand alone patch found!")
    placeMe(0) = $83
    placeMe(1) = $C4
    placeMe(2) = $08
    placeMe(3) = $85
    placeMe(4) = $C0
    placeMe(5) = $90
    placeMe(6) = $E9
    placeMe(7) = $85
    placeMe(8) = $00
    placeMe(9) = $00
    placeMe(10) = $00
    placeMe(11) = $68
    If Patch_File(roPath2, offset, @placeMe(), total)
      AddText_toPatcher("Stand Alone successfully patched!")
    EndIf
  Else
    AddText_toPatcher("Stand alone patch not found!")
  EndIf
EndProcedure

Procedure Patch_WOE()
  total = 5
  Dim findMe.c(total)
  Dim placeMe.c(total)
  findMe(0) = $C0
  findMe(1) = $74
  findMe(2) = $14
  findMe(3) = $6A
  findMe(4) = $07
  findMe(5) = $B9
  offset.l = Find_Offset(@findMe(), total, @rawData(), Filelength)
  If offset <> 0
    AddText_toPatcher("WOE patch found!")
    placeMe(0) = $C0
    placeMe(1) = $EB
    placeMe(2) = $14
    placeMe(3) = $6A
    placeMe(4) = $07
    placeMe(5) = $B9
    If Patch_File(roPath2, offset, @placeMe(), total)
      AddText_toPatcher("WOE Damage successfully patched!")
    EndIf
  Else
    AddText_toPatcher("WOE patch not found!")
  EndIf
EndProcedure

Procedure Start_Patch()
  If roPath = ""
    MessageRequester("Error", "No file found!", #MB_ICONERROR)
  Else
    CopyFile(roPath, roPath2)
    MessageRequester("Notice", "Patched File: " + roPath2)
    DisableGadget(#btnStartPatch, 1)
    AddText_toPatcher("Patcher started...")
    
    Patch_ChangeCaption()
    Patch_ChangeIcon()
    
    If GetGadgetState(#chkNoSPTele) 
      Patch_Network1()
      Patch_Network2()
      
      Protected noSpPath.s = Left(roPath, Len(roPath) - Len(GetFilePart(roPath))) + "nosp_t.jcv"
      If FileSize(noSpPath) = -1
        If OpenFile(1, noSpPath)
          WriteData(1, ?noSP_tele, ?noSP_tele_End-?noSP_tele)
          CloseFile(1)
          AddText_toPatcher("Copying file... done!")
        Else
          MessageRequester("Extraction Error", "Can't write the tele no sp file", #MB_ICONERROR | #MB_OK)
        EndIf
      EndIf
      
    EndIf
    If GetGadgetState(#chkStandAlone) 
      Patch_StandAlone()  
    EndIf    
    If GetGadgetState(#chkDataFolder) 
      Patch_DataFolder()
    EndIf    
    If GetGadgetState(#chkMoreZoom) 
    EndIf    
    If GetGadgetState(#chkWOEDamage) 
      Patch_WOE()
    EndIf
    If GetGadgetState(#chkMouseFreedom) 
      Patch_Mouse()
      Protected mousePath.s = Left(roPath, Len(roPath) - Len(GetFilePart(roPath))) + "mouse_.jcv"
      If FileSize(mousePath) = -1
        If OpenFile(1, mousePath)
          WriteData(1, ?Mouse_, ?Mouse_End-?Mouse_)
          CloseFile(1)
          AddText_toPatcher("Copying file... done!")
        Else
          MessageRequester("Extraction Error", "Can't write the mouse freedom file", #MB_ICONERROR | #MB_OK)
        EndIf
      EndIf
    EndIf    
    If GetGadgetState(#chkDisableGG)
      AddText_toPatcher("Disabling GameGuard...")
      CreateThread(@disassemble(), 1)
    EndIf
  EndIf
EndProcedure

;-- Packet Extract

Procedure Find_StorageEncryptKey()
  Dim storageKeys.s(7)
  
  AddText_toExtractor("Finding storage encryption key started...")
  
  keyFound = #False
  For x = POINTERTORAW To total
    If FindString(asmArray(x), "MOV DWORD PTR [EBP-30]", 8) > 0
      comma_index = FindString(asmArray(x), ",", 8)
      tmpKey$ = Mid(asmArray(x), comma_index + 1, 8)
      If isHex(tmpKey$) = #True And Len(tmpKey$) > 1
        storageKeys(0) = "0x" + RSet(tmpKey$, 8, "0")
      EndIf
      For x2 = 2 To 8
        comma_index = FindString(asmArray(x + x2), ",", 8)
        tmpKey$ = Mid(asmArray(x + x2), comma_index + 1, 8)
        If isHex(tmpKey$) = #True And Len(tmpKey$) > 1
          storageKeys(x2 - 1) = "0x" + RSet(tmpKey$, 8, "0")
          If x2 = 8
            keyFound = #True
          EndIf
        Else
          ReDim storageKeys.s(7)
          Break
        EndIf
      Next
    EndIf
    If keyFound = #True
      AddText_toExtractor("Storage encryption key found at offset " + Left(asmArray(x), 8))
      Break
    EndIf
  Next
  
  If keyFound = #False
    AddText_toExtractor("Storage encryption key not found!")
    ProcedureReturn
  EndIf
  
  For x = 0 To 7
    key$ + "," + storageKeys(x)
  Next
  key$ = Right(key$, Len(key$) - 1)
  SetGadgetText(#strStorageKey, key$)
EndProcedure

Procedure Extract_PacketLength() ; Extract Packet Lengths
  
  AddText_toExtractor("Packet length extraction started...")
  
  time_start = ElapsedMilliseconds()
  
  If function_start = 0 And function_end = 0
    AddText_toExtractor("==================[ ERROR ]==================")
    AddText_toExtractor("Sorry I cant find the offset of the packet length function.")
    AddText_toExtractor("The executable file might be compressed/protected.")
    AddText_toExtractor("=============================================")
    ProcedureReturn
  EndIf
  
  AddText_toExtractor("Function end is at: "+asmArray(function_end))
  
  For x = function_end To 0 Step -1
    If FindString(asmArray(x), "PUSH EBP", 8) > 0
      AddText_toExtractor("Found start of function in offset: " + Left(asmArray(x), 8))
      function_start = x
      Break
    EndIf
  Next  
  
  Dim asmTmp.s(0)
  count = 0
  For x = function_start To function_end
    asmTmp(count) = asmArray(x)
    count + 1
    ReDim asmTmp.s(count)
    If FindString(asmArray(x), "NOP", 8) > 0
      Break
    EndIf
  Next
  
  NewList list.packetList()
  Define.s switch, length
  
  For x = 0 To count
    Ebp_index = FindString(asmTmp(x), "MOV DWORD PTR [EBP", 8)
    Ebx_index = FindString(asmTmp(x), "MOV EBX", 8)
    Eax_index = FindString(asmTmp(x), "MOV [EAX", 8)    
    Eax_index2 = FindString(asmTmp(x), "MOV DWORD PTR [EAX", 8)
    comma_index = FindString(asmTmp(x), ",", 8)
    a$ = Mid(asmTmp(x), comma_index + 1, 6)
    
    If Ebp_index > 0
      switch = RSet(a$, 4, "0")
    EndIf
      
    If Eax_index > 0 Or Eax_index2 > 0
      If a$ = "EBX"
        length = Ebx$
      ElseIf isHex(a$)
        length = a$
      Else
        length = "0"
      EndIf
      AddElement(list())
      list()\switch = switch
      list()\length = hex2Dec(length)
    ElseIf Ebx_index
      If isHex(a$) = #True
        Ebx$ = a$
      EndIf
    EndIf
  Next
  
  time_end = ElapsedMilliseconds()
  
  ; Sort the structured list
  SortStructuredList(list(), 0, OffsetOf(packetList\switch), #PB_Sort_String)
  
  StandardFile$ = exePath + "\recvpackets.txt"
  File$ = SaveFileRequester("Please choose file to save", StandardFile$, "Text (*.txt)|*.txt;Ini (*.ini)|*.ini", 0)
  If File$
    If CreateFile(0, File$)
      WriteStringN(0, "#Generated using " + programName)
      WriteStringN(0, "#Packets Extracted last " + FormatDate("[%mm\%dd\%yyyy] - %hh:%ii:%ss", Date()))
      ForEach list()
        ;This outputs PacketId PacketLen to the window
        ;AddText_toExtractor(list()\switch + " " + Str(list()\length))
        WriteStringN(0, list()\switch + " " + Str(list()\length))
      Next
      CloseFile(0)
      AddText_toExtractor("Total Time Spent: (" + Str(time_end - time_start) + "ms)")
      AddText_toExtractor("Done saving recvpackets in: " + #CRLF + File$)
    EndIf
  EndIf
  
 ; AddText_toExtractor("JCV - For suggestions email: <JCV@JCVsite.com>")
EndProcedure

Procedure Start_Extraction()
  If roPath = ""
    MessageRequester("Error", "No file found!", #MB_ICONERROR)
  Else
    AddText_toExtractor("Extraction started...")
    DisableGadget(#btnStartExtract, 1)
    CreateThread(@disassemble(), 0)
  EndIf
EndProcedure

;- Disassembly

Procedure disassemble() ; Disassemble Executable File
  disAsm_type = GetGadgetState(#tabExtract)
  output(disAsm_type, "Disassembly started...")
  
  time_start = ElapsedMilliseconds()
  
  da.t_disasm
  u = POINTERTORAW
  va = VIRTUALBASEADR + VIRTUALADR
  
  total = 0
  ReDim asmArray.s(total)
  foundIt = #False
  done = #False
  While u < (SIZEOFRAW + POINTERTORAW)
    x = Olly_Disasm( MemoryPointer + u, SIZEOFRAW, va, da, #DISASM_CODE )
    asmArray(total) = RSet(Hex(va), 8, "0") + Chr(9) + da\Result
    ; MOV DWORD PTR [EBP-C],187
    ; MOV DWORD PTR [EBP-8],187
    ; MOV DWORD PTR [EBP-8],64
    ; MOV DWORD PTR [EBP-C],64
    ; Find a unique identifier of packet length function
    If FindString(asmArray(total), "MOV DWORD PTR [EBP-C],187", 1) > 0 Or FindString(asmArray(total), "MOV DWORD PTR [EBP-8],187", 1) > 0  Or FindString(asmArray(total), "MOV DWORD PTR [EBP-8],64", 1) > 0 Or FindString(asmArray(total), "MOV DWORD PTR [EBP-C],64", 1) > 0
      foundIt = #True
      newStyle = #True
      output(disAsm_type, "Found packet length function at"+Left(asmArray(total), 8))
    EndIf
    
    ;NOTE: Disasm tool parses RETN as ????, find POP EBP for now
    If done = #False And foundIt = #True And FindString(asmArray(total), "POP EBP", 1) > 0
      function_end = total
      done = #True
      If ((extractType = 0 Or extractType = 1 ) And disAsm_type = 0)
        Break
      EndIf
    EndIf
    
    total + 1
    ReDim asmArray.s(total)
    
    u + x
    va + x
  Wend
  
  output(disAsm_type, "Done disassembling in (" + Str(ElapsedMilliseconds() - time_start) + "ms)")
  
  If GetGadgetState(#chkSaveDisasm) = #True
    If CreateFile(0, exePath + "\disasm.txt")
      For x = 0 To total
        WriteStringN(0,  asmArray(x))
      Next
      CloseFile(0) 
      output(disAsm_type, "Done saving disassembly in " + exePath + "\disasm.txt")
    EndIf
  EndIf
  
  If disAsm_type = 0
    Extract_PacketLength()
    
    If GetGadgetState(#chkFindStorageKey) = #True
      Find_StorageEncryptKey()
    EndIf
  Else
    Find_GameGuard()
  EndIf
  
  DisableGadget(#btnStartExtract, 0)
  DisableGadget(#btnStartPatch, 0)
  ProcedureReturn
EndProcedure

;- Read File

Procedure Read_File()
  disAsm_type = GetGadgetState(#tabExtract)
  
  If ReadFile(0, roPath)
    
    roPath2 = Left(roPath, Len(roPath) - Len(GetFilePart(roPath))) + "CustomRO.exe"
    
    output(disAsm_type, "Loading executable file... " + GetFilePart(roPath))
    Filelength = Lof(0)
    ReDim rawData.c(Filelength)
    ReadData(0, @rawData(), Filelength)
    CloseFile(0)
    MemoryPointer = @rawData()
    *dosheader.IMAGE_DOS_HEADER
    *dosheader = MemoryPointer
    
    If *dosheader\e_magic <> #IMAGE_DOS_SIGNATURE
      output(disAsm_type, "=================[ ERROR ]=================")
      output(disAsm_type, "The file is not an executable file!")
      output(disAsm_type, "===========================================")
      ProcedureReturn
    EndIf
    
    *ntheaders.IMAGE_NT_HEADERS
    *ntheaders = *dosheader\e_lfanew
    
    If PeekL(*ntheaders+MemoryPointer) <> #IMAGE_NT_SIGNATURE
      output(disAsm_type, "=================[ ERROR ]=================")
      output(disAsm_type, "Invalid IMAGE_NT_SIGNATURE!")
      output(disAsm_type, "===========================================")
      ProcedureReturn
    EndIf
    
    *fileheader.IMAGE_FILE_HEADER
    *fileheader = MemoryPointer+*ntheaders\FileHeader
    *optheader.IMAGE_OPTIONAL_HEADER
    *optheader = MemoryPointer+*ntheaders\OptionalHeader
    *PEsections.IMAGE_SECTION_HEADER
    *PEsections = MemoryPointer + (*dosheader\e_lfanew + SizeOf(IMAGE_NT_HEADERS))
    
    VIRTUALBASEADR = *optheader\ImageBase
    EPOINT = *optheader\AddressOfEntryPoint
    
    For i = 1 To *fileheader\NumberOfSections
      FA = *PEsections\VirtualAddress
      LA = FA + *PEsections\VirtualSize
      If EPOINT >= FA
        If EPOINT <= LA
          POINTERTORAW = *PEsections\PointerToRawData
          SIZEOFRAW = *PEsections\SizeOfRawData
          VIRTUALADR = *PEsections\VirtualAddress
          Break
        EndIf
      EndIf
      *PEsections = *PEsections + SizeOf(IMAGE_SECTION_HEADER)
    Next
    
    output(disAsm_type, "Executive code beginning at Virtual Address: " + Hex(VIRTUALBASEADR + VIRTUALADR))
    output(disAsm_type, "Size Of Executive code: " + Hex(SIZEOFRAW))
    output(disAsm_type, "Entry Point At: " + Hex(VIRTUALBASEADR + EPOINT))
    
  Else
    MessageRequester("Error", "Error on reading file!", #MB_ICONERROR)
  EndIf
EndProcedure

;- Drag n Drop

Procedure.l DropFiles()
  ProcedureReturn EventwParam()
EndProcedure 
; 
Procedure GetNumDropFiles(*dropFiles) 
  ProcedureReturn DragQueryFile_(*dropFiles, $FFFFFFFF, temp$, 0) 
EndProcedure 
; 
Procedure.s GetDropFile (*dropFiles, index) 
  bufferNeeded = DragQueryFile_(*dropFiles, index, 0, 0) 
  For a = 1 To bufferNeeded: buffer$ + " ": Next ; Short by one character! 
  DragQueryFile_ (*dropFiles, index, buffer$, bufferNeeded+1) 
  ProcedureReturn buffer$ 
EndProcedure 
; 
Procedure FreeDropFiles (*dropFiles) 
  DragFinish_ (*dropFiles) 
EndProcedure 

Procedure ProcessDragFile()
  *dropped = DropFiles() 
  num.l = GetNumDropFiles(*dropped)
  files = 0
  ;For files = 0 To num - 1 ; Uncomment for multiple dragged files
  roPath = GetDropFile(*dropped, files)
  SetGadgetText(#strFilePath, roPath)
  Read_File()
  ;Next
  FreeDropFiles(*dropped)
EndProcedure

;- Main Loop

Procedure winMain_Loop() ; Main Loop
  DragAcceptFiles_(WindowID(#winMain), 1) 
  
  Repeat
    Event = WaitWindowEvent()
    Select Event
      Case #PB_Event_Gadget
        EventGadget = EventGadget()
        EventType = EventType()
        Select EventGadget
          Case #strFilePath
          Case #btnFileOpen
            roPath = OpenFileRequester("Open EXE File", "", "EXE | *.exe;", 1)
            SetGadgetText(#strFilePath, roPath)
            Read_File()
          Case #btnExit
            Break
          Case #btnAbout
            MessageRequester("About", programName +  #CRLF + "Copyright ©2006 JCV" +  #CRLF + "<JCV@JCVsite.com>")
          Case #strExtractResult
          Case #btnStartExtract: Start_Extraction()
          Case #optGenType_0: extractType = 0
          Case #optGenType_1: extractType = 1
          Case #optGenType_2: extractType = 2
          Case #chkFindStorageKey
          Case #strStorageKey
          Case #strPatchResult
          Case #btnStartPatch: Start_Patch()
          Case #chkDisableGG: MessageRequester("Notice", "You must not disable gameguard on servers that uses 'GameGuard Check'")
          Case #chkNoSPTele: MessageRequester("Notice", "No SP teleport will only work on Official Servers.")
          Case #chkStandAlone
          Case #chkDataFolder
          Case #chkMoreZoom
          Case #chkWOEDamage
          Case #chkMouseFreedom: MessageRequester("Notice", "GameGuard must be disabled to use MouseFreedom.")
          Case #btnOtherPatch
        EndSelect
    Case #PB_Event_CloseWindow
        EventWindow = EventWindow()
        If EventWindow = #winMain
          Break
        EndIf
        
    Case #WM_DROPFILES
        ProcessDragFile()
    EndSelect
  ForEver
  End
EndProcedure

winMain_OpenWindow()
winMain_Loop()


DataSection

Mouse_:
IncludeBinary ".\bin\mouse_.jcv"
Mouse_End:


noSP_tele:
IncludeBinary ".\bin\nosp_t.jcv"
noSP_tele_End:

EndDataSection
; IDE Options = PureBasic 4.10 (Windows - x86)
; CursorPosition = 815
; FirstLine = 777
; Folding = ------
; EnableXP
; UseIcon = after_boom.ico
; IncludeVersionInfo
; VersionField0 = 1.0.2
; VersionField1 = 1.0.2
; VersionField3 = RO Tools
; VersionField4 = 1.0.2
; VersionField5 = 1.0.2