; OpenKore - Padded Packet Emulator.
;
; This program is free software; you can redistribute it and/or
; modify it under the terms of the GNU General Public License
; as published by the Free Software Foundation; either version 2
; of the License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
; See http://www.gnu.org/licenses/gpl.html for the full license.

ideal
p386n
model flat
public C func5
public C func6
dataseg
    d068AAD6h db 1
    d068AAD7h db 1
    d06E1D24h db 89h DUP(0)
    d06E5F58h db 89h DUP(0)
    d0723528h db 1Ch DUP(0)
    d0723544h db 0E4h DUP(0)
    d0723628h db 100h DUP(0)
codeseg
;############################### sub_503AA0 ####################################
proc @Ragexe_e_00503AA0
    PUSH EBP
    MOV EBP,ESP
    SUB ESP,01Ch
    PUSH EBX
    PUSH ESI
    MOV ESI,[DWORD EBP+8]
    PUSH EDI
    MOV EDI,[DWORD EBP+0Ch]
    MOV AL,[BYTE ESI+1]
    MOV CL,[BYTE ESI+2]
    MOV [BYTE EBP-01Ch],AL
    MOV AL,[BYTE ESI+3]
    MOV DL,[BYTE ESI]
    MOV BL,[BYTE ESI+4]
    MOV [BYTE EBP-8],AL
    MOV AL,[BYTE ESI+6]
    MOV [BYTE EBP-4],CL
    MOV CL,[BYTE ESI+5]
    MOV [BYTE EBP-010h],AL
    XOR EAX,EAX
    MOV AL,[BYTE EDI]
    MOV [BYTE EBP-0Ch],CL
    MOV CL,[BYTE ESI+7]
    MOV ESI,EAX
    CMP ESI,0Dh
    JBE @Ragexe_e_00503AE5
    MOV ESI,0Dh
@Ragexe_e_00503AE5:
    MOV EAX,ESI
    SHL EAX,4
    XOR CL,[BYTE EDI+EAX+8]
    LEA EAX,[DWORD EDI+EAX+8]
    DEC EAX
    MOV EDI,ESI
    MOV [BYTE EBP+0Ch],CL
    MOV CL,[BYTE EAX]
    SUB [BYTE EBP-010h],CL
    MOV CL,[BYTE EAX-1]
    SUB [BYTE EBP-0Ch],CL
    DEC EAX
    DEC EAX
    MOV CL,[BYTE EAX]
    XOR BL,CL
    MOV CL,[BYTE EAX-1]
    XOR [BYTE EBP-8],CL
    DEC EAX
    DEC EAX
    MOV CL,[BYTE EAX]
    SUB [BYTE EBP-4],CL
    MOV CL,[BYTE EBP-01Ch]
    SUB CL,[BYTE EAX-1]
    DEC EAX
    DEC EAX
    MOV [BYTE EBP-01Ch],CL
    XOR DL,[BYTE EAX]
    DEC ESI
    TEST EDI,EDI
    JZ @Ragexe_e_00503D00
    INC ESI
@Ragexe_e_00503B2D:
    MOV CL,[BYTE EBP-01Ch]
    MOV [BYTE EBP-014h],CL
    MOV CL,[BYTE EBP-4]
    MOV [BYTE EBP-4],BL
    MOV BL,[BYTE EBP-0Ch]
    MOV [BYTE EBP+0Bh],BL
    MOV BL,[BYTE EBP-8]
    MOV [BYTE EBP-0Ch],BL
    MOV BL,[BYTE EBP-010h]
    MOV [BYTE EBP-8],BL
    MOV BL,[BYTE EBP-014h]
    SUB DL,BL
    SUB BL,DL
    MOV [BYTE EBP-018h],DL
    MOV DL,[BYTE EBP-0Ch]
    MOV [BYTE EBP-014h],BL
    MOV BL,[BYTE EBP-4]
    SUB CL,DL
    SUB DL,CL
    MOV [BYTE EBP-0Ch],DL
    MOV DL,[BYTE EBP+0Bh]
    SUB BL,DL
    SUB DL,BL
    MOV [BYTE EBP-4],BL
    MOV BL,[BYTE EBP+0Ch]
    MOV [BYTE EBP-010h],DL
    MOV DL,[BYTE EBP-8]
    SUB DL,BL
    SUB BL,DL
    MOV [BYTE EBP-8],DL
    MOV DL,[BYTE EBP-4]
    MOV [BYTE EBP+0Ch],BL
    MOV BL,[BYTE EBP-018h]
    SUB BL,DL
    SUB DL,BL
    MOV [BYTE EBP-018h],BL
    MOV BL,[BYTE EBP-010h]
    MOV [BYTE EBP-4],DL
    MOV DL,[BYTE EBP-014h]
    SUB DL,BL
    MOV [BYTE EBP-014h],DL
    SUB BL,DL
    MOV DL,[BYTE EBP-8]
    MOV [BYTE EBP-010h],BL
    MOV BL,[BYTE EBP+0Ch]
    SUB CL,DL
    SUB DL,CL
    MOV [BYTE EBP-8],DL
    MOV DL,[BYTE EBP-0Ch]
    SUB DL,BL
    MOV [BYTE EBP-0Ch],DL
    SUB BL,DL
    MOV DL,[BYTE EBP-018h]
    MOV [BYTE EBP+0Ch],BL
    MOV BL,[BYTE EBP-4]
    SUB DL,CL
    MOV [BYTE EBP-018h],DL
    MOV DL,[BYTE EBP-8]
    SUB BL,DL
    MOV DL,[BYTE EBP-0Ch]
    MOV [BYTE EBP-4],BL
    MOV BL,[BYTE EBP-014h]
    SUB BL,DL
    MOV DL,[BYTE EBP-010h]
    MOV [BYTE EBP-014h],BL
    MOV BL,[BYTE EBP+0Ch]
    SUB DL,BL
    MOV BL,[BYTE EAX-1]
    DEC EAX
    MOV [BYTE EBP-010h],DL
    ADD BL,DL
    MOV DL,[BYTE EBP+0Ch]
    SUB DL,BL
    MOV BL,[BYTE EBP-010h]
    DEC EAX
    MOV [BYTE EBP+0Ch],DL
    MOV DL,[BYTE EAX]
    XOR BL,DL
    MOV DL,[BYTE EBP-0Ch]
    MOV [BYTE EBP-010h],BL
    DEC EAX
    MOV BL,[BYTE EBP-014h]
    SUB DL,BL
    XOR DL,[BYTE EAX]
    DEC EAX
    MOV [BYTE EBP-0Ch],DL
    MOV DL,[BYTE EAX]
    SUB BL,DL
    MOV DL,[BYTE EAX-1]
    DEC EAX
    MOV [BYTE EBP-014h],BL
    MOV BL,[BYTE EBP-4]
    ADD DL,BL
    MOV BL,[BYTE EBP-8]
    SUB BL,DL
    MOV DL,[BYTE EAX-1]
    DEC EAX
    MOV [BYTE EBP-8],BL
    MOV BL,[BYTE EBP-4]
    XOR BL,DL
    MOV DL,[BYTE EBP-018h]
    DEC EAX
    MOV [BYTE EBP-4],BL
    SUB CL,DL
    MOV BL,[BYTE EAX]
    XOR CL,BL
    MOV BL,[BYTE EAX-1]
    DEC EAX
    MOV [BYTE EBP-01Ch],CL
    MOV ECX,[DWORD EBP+0Ch]
    SUB DL,BL
    MOV BL,[BYTE EAX-1]
    AND ECX,0FFh
    DEC EAX
    MOV [BYTE EBP-018h],DL
    MOV DL,[BYTE ECX+d0723628h]
    MOV ECX,[DWORD EBP-010h]
    XOR DL,BL
    MOV BL,[BYTE EAX-1]
    AND ECX,0FFh
    DEC EAX
    MOV [BYTE EBP+0Ch],DL
    MOV DL,[BYTE ECX+d0723528h]
    MOV ECX,[DWORD EBP-0Ch]
    SUB DL,BL
    AND ECX,0FFh
    DEC EAX
    MOV [BYTE EBP-010h],DL
    MOV DL,[BYTE ECX+d0723528h]
    MOV CL,[BYTE EAX]
    SUB DL,CL
    MOV ECX,[DWORD EBP-014h]
    DEC EAX
    AND ECX,0FFh
    MOV [BYTE EBP-0Ch],DL
    MOV BL,[BYTE ECX+d0723628h]
    MOV DL,[BYTE EAX]
    XOR BL,DL
    MOV EDX,[DWORD EBP-8]
    AND EDX,0FFh
    DEC EAX
    MOV CL,[BYTE EDX+d0723628h]
    MOV DL,[BYTE EAX]
    XOR CL,DL
    MOV EDX,[DWORD EBP-4]
    AND EDX,0FFh
    DEC EAX
    MOV [BYTE EBP-8],CL
    MOV CL,[BYTE EDX+d0723528h]
    MOV DL,[BYTE EAX]
    SUB CL,DL
    MOV EDX,[DWORD EBP-01Ch]
    AND EDX,0FFh
    DEC EAX
    MOV [BYTE EBP-4],CL
    MOV CL,[BYTE EDX+d0723528h]
    MOV DL,[BYTE EAX]
    SUB CL,DL
    MOV EDX,[DWORD EBP-018h]
    DEC EAX
    MOV [BYTE EBP-01Ch],CL
    AND EDX,0FFh
    MOV DL,[BYTE EDX+d0723628h]
    XOR DL,[BYTE EAX]
    DEC ESI
    JNZ @Ragexe_e_00503B2D
@Ragexe_e_00503D00:
    MOV EAX,[DWORD EBP+010h]
    POP EDI
    POP ESI
    MOV [BYTE EAX+1],CL
    MOV CL,[BYTE EBP-4]
    MOV [BYTE EAX],DL
    MOV DL,[BYTE EBP-8]
    MOV [BYTE EAX+2],CL
    MOV CL,[BYTE EBP-0Ch]
    MOV [BYTE EAX+3],DL
    MOV DL,[BYTE EBP-010h]
    MOV [BYTE EAX+5],CL
    MOV CL,[BYTE EBP+0Ch]
    MOV [BYTE EAX+4],BL
    MOV [BYTE EAX+6],DL
    MOV [BYTE EAX+7],CL
    POP EBX
    MOV ESP,EBP
    POP EBP
    RETN
endp
;############################### sub_503800 ####################################
@Ragexe_e_00503800:
    PUSH EBP
    MOV EBP,ESP
    SUB ESP,01Ch
    PUSH EBX
    PUSH ESI
    MOV ESI,[DWORD EBP+8]
    XOR EBX,EBX
    PUSH EDI
    MOV AL,[BYTE ESI+2]
    MOV CL,[BYTE ESI]
    MOV [BYTE EBP-014h],AL
    MOV AL,[BYTE ESI+3]
    MOV [BYTE EBP-8],AL
    MOV AL,[BYTE ESI+4]
    MOV [BYTE EBP-010h],AL
    MOV AL,[BYTE ESI+5]
    MOV [BYTE EBP-0Ch],AL
    MOV AL,[BYTE ESI+6]
    MOV DL,[BYTE ESI+1]
    MOV [BYTE EBP-4],AL
    MOV AL,[BYTE ESI+7]
    MOV [BYTE EBP-018h],AL
    MOV EAX,[DWORD EBP+0Ch]
    MOV BL,[BYTE EAX]
    MOV ESI,EBX
    CMP ESI,0Dh
    JBE @Ragexe_e_00503848
    MOV ESI,0Dh
@Ragexe_e_00503848:
    MOV EDI,ESI
    DEC ESI
    TEST EDI,EDI
    JZ @Ragexe_e_00503A32
    MOV BL,[BYTE EBP-8]
    INC ESI
@Ragexe_e_00503857:
    XOR CL,[BYTE EAX+1]
    INC EAX
    INC EAX
    MOV [BYTE EBP-01Ch],CL
    MOV CL,[BYTE EAX]
    ADD DL,CL
    MOV CL,[BYTE EAX+1]
    INC EAX
    MOV [BYTE EBP+0Ch],DL
    MOV DL,[BYTE EBP-014h]
    ADD DL,CL
    INC EAX
    MOV [BYTE EBP-014h],DL
    MOV DL,[BYTE EAX]
    MOV EDI,[DWORD EBP-014h]
    XOR BL,DL
    MOV DL,[BYTE EAX+1]
    INC EAX
    MOV [BYTE EBP-8],BL
    MOV BL,[BYTE EBP-010h]
    AND EDI,0FFh
    MOV CL,[BYTE EAX+1]
    XOR BL,DL
    MOV DL,[BYTE EBP-0Ch]
    INC EAX
    ADD DL,CL
    INC EAX
    MOV [BYTE EBP-010h],BL
    MOV BL,[BYTE EBP-4]
    MOV CL,[BYTE EAX+1]
    MOV [BYTE EBP-0Ch],DL
    MOV DL,[BYTE EAX]
    ADD BL,DL
    MOV DL,[BYTE EBP-018h]
    INC EAX
    XOR DL,CL
    MOV [BYTE EBP-018h],DL
    MOV EDX,[DWORD EBP-01Ch]
    AND EDX,0FFh
    INC EAX
    MOV [BYTE EBP-4],BL
    MOV CL,[BYTE EDX+d0723528h]
    MOV DL,[BYTE EAX]
    MOV BL,[BYTE EAX+1]
    ADD CL,DL
    MOV EDX,[DWORD EBP+0Ch]
    INC EAX
    AND EDX,0FFh
    MOV DL,[BYTE EDX+d0723628h]
    XOR DL,BL
    MOV BL,[BYTE EDI+d0723628h]
    MOV EDI,[DWORD EBP-8]
    XOR BL,[BYTE EAX+1]
    INC EAX
    AND EDI,0FFh
    MOV [BYTE EBP-014h],BL
    INC EAX
    MOV BL,[BYTE EDI+d0723528h]
    MOV EDI,[DWORD EBP-010h]
    ADD BL,[BYTE EAX]
    AND EDI,0FFh
    INC EAX
    MOV [BYTE EBP-8],BL
    MOV BL,[BYTE EDI+d0723528h]
    MOV EDI,[DWORD EBP-0Ch]
    ADD BL,[BYTE EAX]
    AND EDI,0FFh
    INC EAX
    MOV [BYTE EBP-010h],BL
    MOV BL,[BYTE EDI+d0723628h]
    MOV EDI,[DWORD EBP-4]
    XOR BL,[BYTE EAX]
    AND EDI,0FFh
    INC EAX
    MOV [BYTE EBP-0Ch],BL
    MOV BL,[BYTE EDI+d0723628h]
    XOR BL,[BYTE EAX]
    INC EAX
    ADD DL,CL
    MOV [BYTE EBP-4],BL
    MOV [BYTE EBP+0Ch],DL
    MOV BL,[BYTE EBP-8]
    ADD CL,DL
    MOV DL,[BYTE EBP-014h]
    ADD BL,DL
    MOV DL,[BYTE EBP-010h]
    MOV [BYTE EBP-8],BL
    MOV BL,[BYTE EBP-0Ch]
    ADD BL,DL
    ADD DL,BL
    MOV [BYTE EBP-0Ch],BL
    MOV BL,[BYTE EAX]
    MOV [BYTE EBP-010h],DL
    MOV EDX,[DWORD EBP-018h]
    AND EDX,0FFh
    MOV DL,[BYTE EDX+d0723528h]
    ADD DL,BL
    MOV BL,[BYTE EBP-4]
    ADD DL,BL
    MOV BL,[BYTE EBP-8]
    MOV [BYTE EBP-018h],DL
    MOV DL,[BYTE EBP-014h]
    ADD BL,CL
    ADD DL,BL
    MOV BL,[BYTE EBP-010h]
    MOV [BYTE EBP-014h],DL
    ADD CL,DL
    MOV DL,[BYTE EBP-018h]
    ADD DL,BL
    MOV BL,[BYTE EBP-4]
    ADD BL,DL
    MOV DL,[BYTE EBP+0Ch]
    MOV [BYTE EBP-4],BL
    MOV BL,[BYTE EBP-8]
    ADD BL,DL
    ADD DL,BL
    MOV [BYTE EBP-8],BL
    MOV BL,[BYTE EBP-018h]
    MOV [BYTE EBP+0Ch],DL
    MOV DL,[BYTE EBP-0Ch]
    ADD BL,DL
    MOV DL,[BYTE EBP-010h]
    MOV [BYTE EBP-018h],BL
    MOV BL,[BYTE EBP-4]
    ADD BL,CL
    ADD DL,BL
    MOV BL,[BYTE EBP+0Ch]
    MOV [BYTE EBP-010h],DL
    ADD CL,DL
    MOV DL,[BYTE EBP-018h]
    ADD DL,BL
    MOV BL,[BYTE EBP-0Ch]
    ADD BL,DL
    MOV DL,[BYTE EBP-014h]
    MOV [BYTE EBP-0Ch],BL
    MOV BL,[BYTE EBP-4]
    ADD BL,DL
    MOV DL,[BYTE EBP-8]
    MOV [BYTE EBP-4],BL
    MOV BL,[BYTE EBP-018h]
    ADD BL,DL
    MOV DL,[BYTE EBP-0Ch]
    MOV [BYTE EBP-018h],BL
    MOV BL,[BYTE EBP+0Ch]
    ADD DL,BL
    MOV BL,[BYTE EBP-014h]
    MOV [BYTE EBP+0Bh],DL
    MOV DL,[BYTE EBP-010h]
    MOV [BYTE EBP+0Ch],DL
    MOV DL,[BYTE EBP-4]
    ADD DL,BL
    MOV BL,[BYTE EBP-8]
    MOV [BYTE EBP-010h],DL
    MOV DL,[BYTE EBP+0Bh]
    MOV [BYTE EBP-014h],DL
    MOV DL,[BYTE EBP-018h]
    ADD DL,BL
    MOV BL,[BYTE EBP-0Ch]
    MOV [BYTE EBP+0Bh],DL
    MOV DL,[BYTE EBP-4]
    MOV [BYTE EBP-8],BL
    MOV [BYTE EBP-0Ch],DL
    MOV DL,[BYTE EBP+0Bh]
    DEC ESI
    MOV [BYTE EBP-4],DL
    MOV DL,[BYTE EBP+0Ch]
    JNZ @Ragexe_e_00503857
@Ragexe_e_00503A32:
    MOV BL,[BYTE EAX+1]
    INC EAX
    XOR CL,BL
    INC EAX
    POP EDI
    POP ESI
    MOV BL,[BYTE EAX]
    ADD DL,BL
    MOV BL,[BYTE EAX+1]
    ADD [BYTE EBP-014h],BL
    INC EAX
    INC EAX
    MOV BL,[BYTE EAX]
    XOR [BYTE EBP-8],BL
    MOV BL,[BYTE EAX+1]
    XOR [BYTE EBP-010h],BL
    INC EAX
    INC EAX
    MOV BL,[BYTE EAX]
    ADD [BYTE EBP-0Ch],BL
    MOV BL,[BYTE EAX+1]
    ADD [BYTE EBP-4],BL
    MOV BL,[BYTE EBP-018h]
    INC EAX
    XOR BL,[BYTE EAX+1]
    MOV EAX,[DWORD EBP+010h]
    MOV [BYTE EAX],CL
    MOV CL,[BYTE EBP-014h]
    MOV [BYTE EAX+1],DL
    MOV DL,[BYTE EBP-8]
    MOV [BYTE EAX+2],CL
    MOV CL,[BYTE EBP-010h]
    MOV [BYTE EAX+3],DL
    MOV DL,[BYTE EBP-0Ch]
    MOV [BYTE EAX+4],CL
    MOV CL,[BYTE EBP-4]
    MOV [BYTE EAX+7],BL
    MOV [BYTE EAX+5],DL
    MOV [BYTE EAX+6],CL
    POP EBX
    MOV ESP,EBP
    POP EBP
    RETN
endp
;############################### sub_503690 ####################################
@Ragexe_e_00503690:
    PUSH EBP
    MOV EBP,ESP
    SUB ESP,018h
    MOV ECX,[DWORD EBP+010h]
    MOV EAX,0Dh
    CMP ECX,EAX
    JBE @Ragexe_e_005036A5
    MOV [DWORD EBP+010h],EAX
@Ragexe_e_005036A5:
    MOV ECX,[DWORD EBP+018h]
    MOV AL,[BYTE EBP+010h]
    PUSH EBX
    MOV EBX,[DWORD EBP+0Ch]
    PUSH ESI
    MOV ESI,[DWORD EBP+8]
    PUSH EDI
    MOV [BYTE ECX],AL
    LEA EDI,[DWORD EBP-0Ch]
    LEA EAX,[DWORD EBP-018h]
    INC ECX
    SUB EDI,ESI
    SUB EBX,ESI
    SUB EAX,ESI
    MOV [BYTE EBP-4],0
    MOV [BYTE EBP-010h],0
    MOV [DWORD EBP+8],EAX
    MOV [DWORD EBP+018h],8
@Ragexe_e_005036D5:
    MOV DL,[BYTE ESI]
    MOV AL,DL
    SHR AL,3
    SHL DL,5
    OR AL,DL
    MOV [BYTE EDI+ESI],AL
    MOV DL,[BYTE EBP-4]
    XOR DL,AL
    MOV AL,[BYTE EBX+ESI]
    MOV [BYTE EBP-4],DL
    MOV EDX,[DWORD EBP+8]
    MOV [BYTE ECX],AL
    MOV [BYTE EDX+ESI],AL
    MOV DL,[BYTE EBP-010h]
    XOR DL,AL
    MOV EAX,[DWORD EBP+018h]
    INC ECX
    INC ESI
    DEC EAX
    MOV [BYTE EBP-010h],DL
    MOV [DWORD EBP+018h],EAX
    JNZ @Ragexe_e_005036D5
    MOV EAX,[DWORD EBP+010h]
    MOV EDX,1
    CMP EAX,EDX
    MOV [DWORD EBP+018h],EDX
    JB @Ragexe_e_005037F3
    MOV EDI, offset d0723544h
@Ragexe_e_00503722:
    XOR ESI,ESI
@Ragexe_e_00503724:
    MOV AL,[BYTE EBP+ESI-0Ch]
    MOV BL,AL
    SHL BL,6
    SHR AL,2
    OR BL,AL
    MOV AL,[BYTE EBP+ESI-018h]
    MOV [BYTE EBP+ESI-0Ch],BL
    MOV BL,AL
    SHL BL,6
    SHR AL,2
    OR BL,AL
    MOV [BYTE EBP+ESI-018h],BL
    INC ESI
    CMP ESI,9
    JB @Ragexe_e_00503724
    XOR ESI,ESI
@Ragexe_e_00503750:
    MOV EAX,[DWORD EBP+014h]
    TEST EAX,EAX
    JZ @Ragexe_e_0050377E
    LEA EAX,[DWORD ESI+EDX*2-1]
    XOR EDX,EDX
    MOV EBX,9
    DIV EBX
    XOR EAX,EAX
    MOV AL,[BYTE EDI+ESI-9]
    MOV BL,[BYTE EAX+d0723528h]
    MOV DL,[BYTE EBP+EDX-0Ch]
    ADD DL,BL
    MOV [BYTE ECX],DL
    MOV EDX,[DWORD EBP+018h]
    INC ECX
    JMP @Ragexe_e_00503793
@Ragexe_e_0050377E:
    MOV BL,[BYTE EBP+ESI-0Ch]
    XOR EAX,EAX
    MOV AL,[BYTE EDI+ESI-9]
    MOV AL,[BYTE EAX+d0723528h]
    ADD AL,BL
    MOV [BYTE ECX],AL
    INC ECX
@Ragexe_e_00503793:
    INC ESI
    CMP ESI,8
    JB @Ragexe_e_00503750
    XOR ESI,ESI
@Ragexe_e_0050379B:
    MOV EAX,[DWORD EBP+014h]
    TEST EAX,EAX
    JZ @Ragexe_e_005037C7
    LEA EAX,[DWORD ESI+EDX*2]
    XOR EDX,EDX
    MOV EBX,9
    DIV EBX
    XOR EAX,EAX
    MOV AL,[BYTE EDI+ESI]
    MOV BL,[BYTE EAX+d0723528h]
    MOV DL,[BYTE EBP+EDX-018h]
    ADD DL,BL
    MOV [BYTE ECX],DL
    MOV EDX,[DWORD EBP+018h]
    INC ECX
    JMP @Ragexe_e_005037DB
@Ragexe_e_005037C7:
    MOV BL,[BYTE EBP+ESI-018h]
    XOR EAX,EAX
    MOV AL,[BYTE EDI+ESI]
    MOV AL,[BYTE EAX+d0723528h]
    ADD AL,BL
    MOV [BYTE ECX],AL
    INC ECX
@Ragexe_e_005037DB:
    INC ESI
    CMP ESI,8
    JB @Ragexe_e_0050379B
    MOV EAX,[DWORD EBP+010h]
    INC EDX
    ADD EDI,012h
    CMP EDX,EAX
    MOV [DWORD EBP+018h],EDX
    JBE @Ragexe_e_00503722
@Ragexe_e_005037F3:
    POP EDI
    POP ESI
    POP EBX
    MOV ESP,EBP
    POP EBP
    RETN
endp
;############################### sub_503650 ####################################
proc @Ragexe_e_00503650
    PUSH ESI
    MOV EDX,1
    XOR ECX,ECX
@Ragexe_e_00503658:
    MOV EAX,EDX
    MOV [BYTE ECX+d0723528h],DL
    AND EAX,0FFh
    MOV ESI,0101h
    MOV [BYTE EAX+d0723628h],CL
    LEA EAX,[DWORD EDX+EDX*4]
    XOR EDX,EDX
    LEA EAX,[DWORD EAX+EAX*8]
    DIV ESI
    INC ECX
    CMP ECX,0100h
    JB @Ragexe_e_00503658
    POP ESI
    RETN
endp
;############################### sub_420660 ####################################
proc func5
    PUSH EBP
    MOV EBP,ESP
    SUB ESP,018h
    MOV AL,[BYTE d068AAD6h]
    TEST AL,AL
    JZ @Ragexe_e_004206B4
    CALL @Ragexe_e_00503650
    PUSH offset d06E1D24h
    PUSH 0
    LEA EAX,[DWORD EBP-8]
    PUSH 8
    LEA ECX,[DWORD EBP-8]
    PUSH EAX
    PUSH ECX
    MOV [BYTE EBP-8],09Ch
    MOV [BYTE EBP-7],056h
    MOV [BYTE EBP-6],0D1h
    MOV [BYTE EBP-5],012h
    MOV [BYTE EBP-4],023h
    MOV [BYTE EBP-3],0C0h
    MOV [BYTE EBP-2],0B4h
    MOV [BYTE EBP-1],037h
    CALL @Ragexe_e_00503690
    ADD ESP,014h
    MOV [BYTE d068AAD6h],0
@Ragexe_e_004206B4:
    XOR EDX,EDX
    MOV EAX,[DWORD EBP+8]
    MOV [DWORD EBP-0Fh],EDX
    LEA ECX,[DWORD EBP-018h]
    MOV [WORD EBP-0Bh],DX
    PUSH ECX
    MOV [BYTE EBP-9],DL
    LEA EDX,[DWORD EBP-010h]
    PUSH offset d06E1D24h
    PUSH EDX
    MOV [DWORD EBP-010h],EAX
    CALL @Ragexe_e_00503800
    MOV EAX,[DWORD EBP-018h]
    ADD ESP,0Ch
    MOV ESP,EBP
    POP EBP
    RETN
endp
;############################### sub_4206F0 ####################################
proc func6
    PUSH EBP
    MOV EBP,ESP
    SUB ESP,018h
    MOV AL,[BYTE d068AAD7h]
    TEST AL,AL
    JZ @Ragexe_e_00420744
    CALL @Ragexe_e_00503650
    PUSH offset d06E5F58h
    PUSH 0
    LEA EAX,[DWORD EBP-8]
    PUSH 8
    LEA ECX,[DWORD EBP-8]
    PUSH EAX
    PUSH ECX
    MOV [BYTE EBP-8],09Ch
    MOV [BYTE EBP-7],056h
    MOV [BYTE EBP-6],0DDh
    MOV [BYTE EBP-5],012h
    MOV [BYTE EBP-4],023h
    MOV [BYTE EBP-3],0C1h
    MOV [BYTE EBP-2],0B4h
    MOV [BYTE EBP-1],037h
    CALL @Ragexe_e_00503690
    ADD ESP,014h
    MOV [BYTE d068AAD7h],0
@Ragexe_e_00420744:
    XOR EDX,EDX
    MOV EAX,[DWORD EBP+8]
    MOV [DWORD EBP-0Fh],EDX
    LEA ECX,[DWORD EBP-018h]
    MOV [WORD EBP-0Bh],DX
    PUSH ECX
    MOV [BYTE EBP-9],DL
    LEA EDX,[DWORD EBP-010h]
    PUSH offset d06E5F58h
    PUSH EDX
    MOV [DWORD EBP-010h],EAX
    CALL @Ragexe_e_00503AA0
    MOV EAX,[DWORD EBP-018h]
    ADD ESP,0Ch
    MOV ESP,EBP
    POP EBP
    RETN
endp
end

