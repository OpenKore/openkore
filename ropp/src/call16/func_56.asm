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

section .data use32 CLASS=data
    d068AAD6h db 1
    d068AAD7h db 1
section .bss use32 CLASS=bss
; Please check a dup block
    d06E1D24h RESB 89h
    d06E5F58h RESB 89h
    d0723528h RESB 1Ch
    d0723544h RESB 0E4h
    d0723628h RESB 100h
section .code use32 CLASS=code
;############################### sub_420660 ####################################
global _func5
_func5:
    PUSH EBP
    MOV EBP,ESP
    SUB ESP,018h
; May be bug
    MOV AL,byte [d068AAD6h]
    TEST AL,AL
    JZ .Ragexe004206B4
    CALL Ragexe00503650
    PUSH d06E1D24h
    PUSH 0
    LEA EAX,[EBP-8]
    PUSH 8
    LEA ECX,[EBP-8]
    PUSH EAX
    PUSH ECX
    MOV byte [EBP-8],09Ch
    MOV byte [EBP-7],056h
    MOV byte [EBP-6],0D1h
    MOV byte [EBP-5],012h
    MOV byte [EBP-4],023h
    MOV byte [EBP-3],0C0h
    MOV byte [EBP-2],0B4h
    MOV byte [EBP-1],037h
    CALL Ragexe00503690
    ADD ESP,014h
; May be bug
    MOV byte [d068AAD6h],0
.Ragexe004206B4:
    XOR EDX,EDX
    MOV EAX,dword [EBP+8]
    MOV dword [EBP-0Fh],EDX
    LEA ECX,[EBP-018h]
    MOV word [EBP-0Bh],DX
    PUSH ECX
    MOV byte [EBP-9],DL
    LEA EDX,[EBP-010h]
    PUSH d06E1D24h
    PUSH EDX
    MOV dword [EBP-010h],EAX
    CALL Ragexe00503800
    MOV EAX,dword [EBP-018h]
    ADD ESP,0Ch
    MOV ESP,EBP
    POP EBP
    RET

;############################### sub_4206F0 ####################################
global _func6
_func6:
    PUSH EBP
    MOV EBP,ESP
    SUB ESP,018h
; May be bug
    MOV AL,byte [d068AAD7h]
    TEST AL,AL
    JZ .Ragexe00420744
    CALL Ragexe00503650
    PUSH d06E5F58h
    PUSH 0
    LEA EAX,[EBP-8]
    PUSH 8
    LEA ECX,[EBP-8]
    PUSH EAX
    PUSH ECX
    MOV byte [EBP-8],09Ch
    MOV byte [EBP-7],056h
    MOV byte [EBP-6],0DDh
    MOV byte [EBP-5],012h
    MOV byte [EBP-4],023h
    MOV byte [EBP-3],0C1h
    MOV byte [EBP-2],0B4h
    MOV byte [EBP-1],037h
    CALL Ragexe00503690
    ADD ESP,014h
; May be bug
    MOV byte [d068AAD7h],0
.Ragexe00420744:
    XOR EDX,EDX
    MOV EAX,dword [EBP+8]
    MOV dword [EBP-0Fh],EDX
    LEA ECX,[EBP-018h]
    MOV word [EBP-0Bh],DX
    PUSH ECX
    MOV byte [EBP-9],DL
    LEA EDX,[EBP-010h]
    PUSH d06E5F58h
    PUSH EDX
    MOV dword [EBP-010h],EAX
    CALL .Ragexe00503AA0
    MOV EAX,dword [EBP-018h]
    ADD ESP,0Ch
    MOV ESP,EBP
    POP EBP
    RET

;############################### sub_503AA0 ####################################
.Ragexe00503AA0:
    PUSH EBP
    MOV EBP,ESP
    SUB ESP,01Ch
    PUSH EBX
    PUSH ESI
    MOV ESI,dword [EBP+8]
    PUSH EDI
    MOV EDI,dword [EBP+0Ch]
    MOV AL,byte [ESI+1]
    MOV CL,byte [ESI+2]
    MOV byte [EBP-01Ch],AL
    MOV AL,byte [ESI+3]
    MOV DL,byte [ESI]
    MOV BL,byte [ESI+4]
    MOV byte [EBP-8],AL
    MOV AL,byte [ESI+6]
    MOV byte [EBP-4],CL
    MOV CL,byte [ESI+5]
    MOV byte [EBP-010h],AL
    XOR EAX,EAX
    MOV AL,byte [EDI]
    MOV byte [EBP-0Ch],CL
    MOV CL,byte [ESI+7]
    MOV ESI,EAX
    CMP ESI,0Dh
    JBE .Ragexe00503AE5
    MOV ESI,0Dh
.Ragexe00503AE5:
    MOV EAX,ESI
    SHL EAX,4
    XOR CL,byte [EDI+EAX+8]
    LEA EAX,[EDI+EAX+8]
    DEC EAX
    MOV EDI,ESI
    MOV byte [EBP+0Ch],CL
    MOV CL,byte [EAX]
    SUB byte [EBP-010h],CL
    MOV CL,byte [EAX-1]
    SUB byte [EBP-0Ch],CL
    DEC EAX
    DEC EAX
    MOV CL,byte [EAX]
    XOR BL,CL
    MOV CL,byte [EAX-1]
    XOR byte [EBP-8],CL
    DEC EAX
    DEC EAX
    MOV CL,byte [EAX]
    SUB byte [EBP-4],CL
    MOV CL,byte [EBP-01Ch]
    SUB CL,byte [EAX-1]
    DEC EAX
    DEC EAX
    MOV byte [EBP-01Ch],CL
    XOR DL,byte [EAX]
    DEC ESI
    TEST EDI,EDI
    JZ near .Ragexe00503D00
    INC ESI
.Ragexe00503B2D:
    MOV CL,byte [EBP-01Ch]
    MOV byte [EBP-014h],CL
    MOV CL,byte [EBP-4]
    MOV byte [EBP-4],BL
    MOV BL,byte [EBP-0Ch]
    MOV byte [EBP+0Bh],BL
    MOV BL,byte [EBP-8]
    MOV byte [EBP-0Ch],BL
    MOV BL,byte [EBP-010h]
    MOV byte [EBP-8],BL
    MOV BL,byte [EBP-014h]
    SUB DL,BL
    SUB BL,DL
    MOV byte [EBP-018h],DL
    MOV DL,byte [EBP-0Ch]
    MOV byte [EBP-014h],BL
    MOV BL,byte [EBP-4]
    SUB CL,DL
    SUB DL,CL
    MOV byte [EBP-0Ch],DL
    MOV DL,byte [EBP+0Bh]
    SUB BL,DL
    SUB DL,BL
    MOV byte [EBP-4],BL
    MOV BL,byte [EBP+0Ch]
    MOV byte [EBP-010h],DL
    MOV DL,byte [EBP-8]
    SUB DL,BL
    SUB BL,DL
    MOV byte [EBP-8],DL
    MOV DL,byte [EBP-4]
    MOV byte [EBP+0Ch],BL
    MOV BL,byte [EBP-018h]
    SUB BL,DL
    SUB DL,BL
    MOV byte [EBP-018h],BL
    MOV BL,byte [EBP-010h]
    MOV byte [EBP-4],DL
    MOV DL,byte [EBP-014h]
    SUB DL,BL
    MOV byte [EBP-014h],DL
    SUB BL,DL
    MOV DL,byte [EBP-8]
    MOV byte [EBP-010h],BL
    MOV BL,byte [EBP+0Ch]
    SUB CL,DL
    SUB DL,CL
    MOV byte [EBP-8],DL
    MOV DL,byte [EBP-0Ch]
    SUB DL,BL
    MOV byte [EBP-0Ch],DL
    SUB BL,DL
    MOV DL,byte [EBP-018h]
    MOV byte [EBP+0Ch],BL
    MOV BL,byte [EBP-4]
    SUB DL,CL
    MOV byte [EBP-018h],DL
    MOV DL,byte [EBP-8]
    SUB BL,DL
    MOV DL,byte [EBP-0Ch]
    MOV byte [EBP-4],BL
    MOV BL,byte [EBP-014h]
    SUB BL,DL
    MOV DL,byte [EBP-010h]
    MOV byte [EBP-014h],BL
    MOV BL,byte [EBP+0Ch]
    SUB DL,BL
    MOV BL,byte [EAX-1]
    DEC EAX
    MOV byte [EBP-010h],DL
    ADD BL,DL
    MOV DL,byte [EBP+0Ch]
    SUB DL,BL
    MOV BL,byte [EBP-010h]
    DEC EAX
    MOV byte [EBP+0Ch],DL
    MOV DL,byte [EAX]
    XOR BL,DL
    MOV DL,byte [EBP-0Ch]
    MOV byte [EBP-010h],BL
    DEC EAX
    MOV BL,byte [EBP-014h]
    SUB DL,BL
    XOR DL,byte [EAX]
    DEC EAX
    MOV byte [EBP-0Ch],DL
    MOV DL,byte [EAX]
    SUB BL,DL
    MOV DL,byte [EAX-1]
    DEC EAX
    MOV byte [EBP-014h],BL
    MOV BL,byte [EBP-4]
    ADD DL,BL
    MOV BL,byte [EBP-8]
    SUB BL,DL
    MOV DL,byte [EAX-1]
    DEC EAX
    MOV byte [EBP-8],BL
    MOV BL,byte [EBP-4]
    XOR BL,DL
    MOV DL,byte [EBP-018h]
    DEC EAX
    MOV byte [EBP-4],BL
    SUB CL,DL
    MOV BL,byte [EAX]
    XOR CL,BL
    MOV BL,byte [EAX-1]
    DEC EAX
    MOV byte [EBP-01Ch],CL
    MOV ECX,dword [EBP+0Ch]
    SUB DL,BL
    MOV BL,byte [EAX-1]
    AND ECX,0FFh
    DEC EAX
    MOV byte [EBP-018h],DL
    MOV DL,byte [ECX+d0723628h]
    MOV ECX,dword [EBP-010h]
    XOR DL,BL
    MOV BL,byte [EAX-1]
    AND ECX,0FFh
    DEC EAX
    MOV byte [EBP+0Ch],DL
    MOV DL,byte [ECX+d0723528h]
    MOV ECX,dword [EBP-0Ch]
    SUB DL,BL
    AND ECX,0FFh
    DEC EAX
    MOV byte [EBP-010h],DL
    MOV DL,byte [ECX+d0723528h]
    MOV CL,byte [EAX]
    SUB DL,CL
    MOV ECX,dword [EBP-014h]
    DEC EAX
    AND ECX,0FFh
    MOV byte [EBP-0Ch],DL
    MOV BL,byte [ECX+d0723628h]
    MOV DL,byte [EAX]
    XOR BL,DL
    MOV EDX,dword [EBP-8]
    AND EDX,0FFh
    DEC EAX
    MOV CL,byte [EDX+d0723628h]
    MOV DL,byte [EAX]
    XOR CL,DL
    MOV EDX,dword [EBP-4]
    AND EDX,0FFh
    DEC EAX
    MOV byte [EBP-8],CL
    MOV CL,byte [EDX+d0723528h]
    MOV DL,byte [EAX]
    SUB CL,DL
    MOV EDX,dword [EBP-01Ch]
    AND EDX,0FFh
    DEC EAX
    MOV byte [EBP-4],CL
    MOV CL,byte [EDX+d0723528h]
    MOV DL,byte [EAX]
    SUB CL,DL
    MOV EDX,dword [EBP-018h]
    DEC EAX
    MOV byte [EBP-01Ch],CL
    AND EDX,0FFh
    MOV DL,byte [EDX+d0723628h]
    XOR DL,byte [EAX]
    DEC ESI
    JNZ .Ragexe00503B2D
.Ragexe00503D00:
    MOV EAX,dword [EBP+010h]
    POP EDI
    POP ESI
    MOV byte [EAX+1],CL
    MOV CL,byte [EBP-4]
    MOV byte [EAX],DL
    MOV DL,byte [EBP-8]
    MOV byte [EAX+2],CL
    MOV CL,byte [EBP-0Ch]
    MOV byte [EAX+3],DL
    MOV DL,byte [EBP-010h]
    MOV byte [EAX+5],CL
    MOV CL,byte [EBP+0Ch]
    MOV byte [EAX+4],BL
    MOV byte [EAX+6],DL
    MOV byte [EAX+7],CL
    POP EBX
    MOV ESP,EBP
    POP EBP
    RET

;############################### sub_503800 ####################################
Ragexe00503800:
    PUSH EBP
    MOV EBP,ESP
    SUB ESP,01Ch
    PUSH EBX
    PUSH ESI
    MOV ESI,dword [EBP+8]
    XOR EBX,EBX
    PUSH EDI
    MOV AL,byte [ESI+2]
    MOV CL,byte [ESI]
    MOV byte [EBP-014h],AL
    MOV AL,byte [ESI+3]
    MOV byte [EBP-8],AL
    MOV AL,byte [ESI+4]
    MOV byte [EBP-010h],AL
    MOV AL,byte [ESI+5]
    MOV byte [EBP-0Ch],AL
    MOV AL,byte [ESI+6]
    MOV DL,byte [ESI+1]
    MOV byte [EBP-4],AL
    MOV AL,byte [ESI+7]
    MOV byte [EBP-018h],AL
    MOV EAX,dword [EBP+0Ch]
    MOV BL,byte [EAX]
    MOV ESI,EBX
    CMP ESI,0Dh
    JBE .Ragexe00503848
    MOV ESI,0Dh
.Ragexe00503848:
    MOV EDI,ESI
    DEC ESI
    TEST EDI,EDI
    JZ near .Ragexe00503A32
    MOV BL,byte [EBP-8]
    INC ESI
.Ragexe00503857:
    XOR CL,byte [EAX+1]
    INC EAX
    INC EAX
    MOV byte [EBP-01Ch],CL
    MOV CL,byte [EAX]
    ADD DL,CL
    MOV CL,byte [EAX+1]
    INC EAX
    MOV byte [EBP+0Ch],DL
    MOV DL,byte [EBP-014h]
    ADD DL,CL
    INC EAX
    MOV byte [EBP-014h],DL
    MOV DL,byte [EAX]
    MOV EDI,dword [EBP-014h]
    XOR BL,DL
    MOV DL,byte [EAX+1]
    INC EAX
    MOV byte [EBP-8],BL
    MOV BL,byte [EBP-010h]
    AND EDI,0FFh
    MOV CL,byte [EAX+1]
    XOR BL,DL
    MOV DL,byte [EBP-0Ch]
    INC EAX
    ADD DL,CL
    INC EAX
    MOV byte [EBP-010h],BL
    MOV BL,byte [EBP-4]
    MOV CL,byte [EAX+1]
    MOV byte [EBP-0Ch],DL
    MOV DL,byte [EAX]
    ADD BL,DL
    MOV DL,byte [EBP-018h]
    INC EAX
    XOR DL,CL
    MOV byte [EBP-018h],DL
    MOV EDX,dword [EBP-01Ch]
    AND EDX,0FFh
    INC EAX
    MOV byte [EBP-4],BL
    MOV CL,byte [EDX+d0723528h]
    MOV DL,byte [EAX]
    MOV BL,byte [EAX+1]
    ADD CL,DL
    MOV EDX,dword [EBP+0Ch]
    INC EAX
    AND EDX,0FFh
    MOV DL,byte [EDX+d0723628h]
    XOR DL,BL
    MOV BL,byte [EDI+d0723628h]
    MOV EDI,dword [EBP-8]
    XOR BL,byte [EAX+1]
    INC EAX
    AND EDI,0FFh
    MOV byte [EBP-014h],BL
    INC EAX
    MOV BL,byte [EDI+d0723528h]
    MOV EDI,dword [EBP-010h]
    ADD BL,byte [EAX]
    AND EDI,0FFh
    INC EAX
    MOV byte [EBP-8],BL
    MOV BL,byte [EDI+d0723528h]
    MOV EDI,dword [EBP-0Ch]
    ADD BL,byte [EAX]
    AND EDI,0FFh
    INC EAX
    MOV byte [EBP-010h],BL
    MOV BL,byte [EDI+d0723628h]
    MOV EDI,dword [EBP-4]
    XOR BL,byte [EAX]
    AND EDI,0FFh
    INC EAX
    MOV byte [EBP-0Ch],BL
    MOV BL,byte [EDI+d0723628h]
    XOR BL,byte [EAX]
    INC EAX
    ADD DL,CL
    MOV byte [EBP-4],BL
    MOV byte [EBP+0Ch],DL
    MOV BL,byte [EBP-8]
    ADD CL,DL
    MOV DL,byte [EBP-014h]
    ADD BL,DL
    MOV DL,byte [EBP-010h]
    MOV byte [EBP-8],BL
    MOV BL,byte [EBP-0Ch]
    ADD BL,DL
    ADD DL,BL
    MOV byte [EBP-0Ch],BL
    MOV BL,byte [EAX]
    MOV byte [EBP-010h],DL
    MOV EDX,dword [EBP-018h]
    AND EDX,0FFh
    MOV DL,byte [EDX+d0723528h]
    ADD DL,BL
    MOV BL,byte [EBP-4]
    ADD DL,BL
    MOV BL,byte [EBP-8]
    MOV byte [EBP-018h],DL
    MOV DL,byte [EBP-014h]
    ADD BL,CL
    ADD DL,BL
    MOV BL,byte [EBP-010h]
    MOV byte [EBP-014h],DL
    ADD CL,DL
    MOV DL,byte [EBP-018h]
    ADD DL,BL
    MOV BL,byte [EBP-4]
    ADD BL,DL
    MOV DL,byte [EBP+0Ch]
    MOV byte [EBP-4],BL
    MOV BL,byte [EBP-8]
    ADD BL,DL
    ADD DL,BL
    MOV byte [EBP-8],BL
    MOV BL,byte [EBP-018h]
    MOV byte [EBP+0Ch],DL
    MOV DL,byte [EBP-0Ch]
    ADD BL,DL
    MOV DL,byte [EBP-010h]
    MOV byte [EBP-018h],BL
    MOV BL,byte [EBP-4]
    ADD BL,CL
    ADD DL,BL
    MOV BL,byte [EBP+0Ch]
    MOV byte [EBP-010h],DL
    ADD CL,DL
    MOV DL,byte [EBP-018h]
    ADD DL,BL
    MOV BL,byte [EBP-0Ch]
    ADD BL,DL
    MOV DL,byte [EBP-014h]
    MOV byte [EBP-0Ch],BL
    MOV BL,byte [EBP-4]
    ADD BL,DL
    MOV DL,byte [EBP-8]
    MOV byte [EBP-4],BL
    MOV BL,byte [EBP-018h]
    ADD BL,DL
    MOV DL,byte [EBP-0Ch]
    MOV byte [EBP-018h],BL
    MOV BL,byte [EBP+0Ch]
    ADD DL,BL
    MOV BL,byte [EBP-014h]
    MOV byte [EBP+0Bh],DL
    MOV DL,byte [EBP-010h]
    MOV byte [EBP+0Ch],DL
    MOV DL,byte [EBP-4]
    ADD DL,BL
    MOV BL,byte [EBP-8]
    MOV byte [EBP-010h],DL
    MOV DL,byte [EBP+0Bh]
    MOV byte [EBP-014h],DL
    MOV DL,byte [EBP-018h]
    ADD DL,BL
    MOV BL,byte [EBP-0Ch]
    MOV byte [EBP+0Bh],DL
    MOV DL,byte [EBP-4]
    MOV byte [EBP-8],BL
    MOV byte [EBP-0Ch],DL
    MOV DL,byte [EBP+0Bh]
    DEC ESI
    MOV byte [EBP-4],DL
    MOV DL,byte [EBP+0Ch]
    JNZ .Ragexe00503857
.Ragexe00503A32:
    MOV BL,byte [EAX+1]
    INC EAX
    XOR CL,BL
    INC EAX
    POP EDI
    POP ESI
    MOV BL,byte [EAX]
    ADD DL,BL
    MOV BL,byte [EAX+1]
    ADD byte [EBP-014h],BL
    INC EAX
    INC EAX
    MOV BL,byte [EAX]
    XOR byte [EBP-8],BL
    MOV BL,byte [EAX+1]
    XOR byte [EBP-010h],BL
    INC EAX
    INC EAX
    MOV BL,byte [EAX]
    ADD byte [EBP-0Ch],BL
    MOV BL,byte [EAX+1]
    ADD byte [EBP-4],BL
    MOV BL,byte [EBP-018h]
    INC EAX
    XOR BL,byte [EAX+1]
    MOV EAX,dword [EBP+010h]
    MOV byte [EAX],CL
    MOV CL,byte [EBP-014h]
    MOV byte [EAX+1],DL
    MOV DL,byte [EBP-8]
    MOV byte [EAX+2],CL
    MOV CL,byte [EBP-010h]
    MOV byte [EAX+3],DL
    MOV DL,byte [EBP-0Ch]
    MOV byte [EAX+4],CL
    MOV CL,byte [EBP-4]
    MOV byte [EAX+7],BL
    MOV byte [EAX+5],DL
    MOV byte [EAX+6],CL
    POP EBX
    MOV ESP,EBP
    POP EBP
    RET

;############################### sub_503690 ####################################
Ragexe00503690:
    PUSH EBP
    MOV EBP,ESP
    SUB ESP,018h
    MOV ECX,dword [EBP+010h]
    MOV EAX,0Dh
    CMP ECX,EAX
    JBE .Ragexe005036A5
    MOV dword [EBP+010h],EAX
.Ragexe005036A5:
    MOV ECX,dword [EBP+018h]
    MOV AL,byte [EBP+010h]
    PUSH EBX
    MOV EBX,dword [EBP+0Ch]
    PUSH ESI
    MOV ESI,dword [EBP+8]
    PUSH EDI
    MOV byte [ECX],AL
    LEA EDI,[EBP-0Ch]
    LEA EAX,[EBP-018h]
    INC ECX
    SUB EDI,ESI
    SUB EBX,ESI
    SUB EAX,ESI
    MOV byte [EBP-4],0
    MOV byte [EBP-010h],0
    MOV dword [EBP+8],EAX
    MOV dword [EBP+018h],8
.Ragexe005036D5:
    MOV DL,byte [ESI]
    MOV AL,DL
    SHR AL,3
    SHL DL,5
    OR AL,DL
    MOV byte [EDI+ESI],AL
    MOV DL,byte [EBP-4]
    XOR DL,AL
    MOV AL,byte [EBX+ESI]
    MOV byte [EBP-4],DL
    MOV EDX,dword [EBP+8]
    MOV byte [ECX],AL
    MOV byte [EDX+ESI],AL
    MOV DL,byte [EBP-010h]
    XOR DL,AL
    MOV EAX,dword [EBP+018h]
    INC ECX
    INC ESI
    DEC EAX
    MOV byte [EBP-010h],DL
    MOV dword [EBP+018h],EAX
    JNZ .Ragexe005036D5
    MOV EAX,dword [EBP+010h]
    MOV EDX,1
    CMP EAX,EDX
    MOV dword [EBP+018h],EDX
    JB near .Ragexe005037F3
    MOV EDI, d0723544h
.Ragexe00503722:
    XOR ESI,ESI
.Ragexe00503724:
    MOV AL,byte [EBP+ESI-0Ch]
    MOV BL,AL
    SHL BL,6
    SHR AL,2
    OR BL,AL
    MOV AL,byte [EBP+ESI-018h]
    MOV byte [EBP+ESI-0Ch],BL
    MOV BL,AL
    SHL BL,6
    SHR AL,2
    OR BL,AL
    MOV byte [EBP+ESI-018h],BL
    INC ESI
    CMP ESI,9
    JB .Ragexe00503724
    XOR ESI,ESI
.Ragexe00503750:
    MOV EAX,dword [EBP+014h]
    TEST EAX,EAX
    JZ .Ragexe0050377E
    LEA EAX,[ESI+EDX*2-1]
    XOR EDX,EDX
    MOV EBX,9
    DIV EBX
    XOR EAX,EAX
    MOV AL,byte [EDI+ESI-9]
    MOV BL,byte [EAX+d0723528h]
    MOV DL,byte [EBP+EDX-0Ch]
    ADD DL,BL
    MOV byte [ECX],DL
    MOV EDX,dword [EBP+018h]
    INC ECX
    JMP .Ragexe00503793
.Ragexe0050377E:
    MOV BL,byte [EBP+ESI-0Ch]
    XOR EAX,EAX
    MOV AL,byte [EDI+ESI-9]
    MOV AL,byte [EAX+d0723528h]
    ADD AL,BL
    MOV byte [ECX],AL
    INC ECX
.Ragexe00503793:
    INC ESI
    CMP ESI,8
    JB .Ragexe00503750
    XOR ESI,ESI
.Ragexe0050379B:
    MOV EAX,dword [EBP+014h]
    TEST EAX,EAX
    JZ .Ragexe005037C7
    LEA EAX,[ESI+EDX*2]
    XOR EDX,EDX
    MOV EBX,9
    DIV EBX
    XOR EAX,EAX
    MOV AL,byte [EDI+ESI]
    MOV BL,byte [EAX+d0723528h]
    MOV DL,byte [EBP+EDX-018h]
    ADD DL,BL
    MOV byte [ECX],DL
    MOV EDX,dword [EBP+018h]
    INC ECX
    JMP .Ragexe005037DB
.Ragexe005037C7:
    MOV BL,byte [EBP+ESI-018h]
    XOR EAX,EAX
    MOV AL,byte [EDI+ESI]
    MOV AL,byte [EAX+d0723528h]
    ADD AL,BL
    MOV byte [ECX],AL
    INC ECX
.Ragexe005037DB:
    INC ESI
    CMP ESI,8
    JB .Ragexe0050379B
    MOV EAX,dword [EBP+010h]
    INC EDX
    ADD EDI,012h
    CMP EDX,EAX
    MOV dword [EBP+018h],EDX
    JBE .Ragexe00503722
.Ragexe005037F3:
    POP EDI
    POP ESI
    POP EBX
    MOV ESP,EBP
    POP EBP
    RET

;############################### sub_503650 ####################################
Ragexe00503650:
    PUSH ESI
    MOV EDX,1
    XOR ECX,ECX
.Ragexe00503658:
    MOV EAX,EDX
; May be bug
    MOV byte [ECX+d0723528h],DL
    AND EAX,0FFh
    MOV ESI,0101h
; May be bug
    MOV byte [EAX+d0723628h],CL
    LEA EAX,[EDX+EDX*4]
    XOR EDX,EDX
    LEA EAX,[EAX+EAX*8]
    DIV ESI
    INC ECX
    CMP ECX,0100h
    JB .Ragexe00503658
    POP ESI
    RET

end

