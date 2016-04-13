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
public C funcB
public C funcC
dataseg
    d06A453Ch dd 1
    d0723728h db 20h DUP(0)
    d0723748h dd 0
    d072374Ch dd 0
	d0723750h dd 0
    d0723754h dd 0
    d0723758h dd 0
    d072375Ch dd 0
    d0723760h dd 0
    d0723764h dd 0
    d072376Ch dd 0
    d0724910h dd 0
    d0724914h dd 0
    d0724918h dd 0
	d074491Ch db 100h DUP(0)
codeseg
;############################### sub_509E20 ####################################
proc sub_509E20
    PUSH    EBP
    MOV     EBP,ESP
    MOV     EAX,[DWORD EBP+0Ch]
    MOV     ECX,[DWORD EBP+8]
    MOV     DL,[BYTE EBP+0Bh]
    MOV     [BYTE EAX],CL
    MOV     CL,[BYTE EBP+0Ah]
    INC     EAX
    MOV     [BYTE EAX],CH
    INC     EAX
    MOV     [BYTE EAX],CL
    MOV     [BYTE EAX+1],DL
    POP     EBP
    RET
endp
;############################### sub_509DA0 ####################################
proc sub_509DA0
    PUSH    EBP
    MOV     EBP,ESP
    PUSH    EBX
    PUSH    ESI
    MOV     ESI,[DWORD EBP+8]
    PUSH    EDI
    PUSH    ESI
    CALL    sub_509FE0
    ADD     ESI,4
    MOV     EDI,EAX
    PUSH    ESI
    CALL    sub_509FE0
    MOV     EDX,[DWORD d0724910h]
    MOV     ESI,[DWORD d0724914h]
    XOR     EDI,EDX
    XOR     ESI,EAX
    ADD     ESP,8
    XOR     ESI,EDI
    MOV     EBX,OFFSET d0723728h + 1Ch ;0723744h
L509DD4:
    MOV     EAX,[DWORD EBX]
    PUSH    EAX
    PUSH    ESI
    CALL    sub_509EF0
    SUB     EBX,4
    ADD     ESP,8
    XOR     EAX,EDI
    MOV     EDI,ESI
    CMP     EBX,OFFSET d0723728h
    MOV     ESI,EAX
    JAE     L509DD4 ;JGE     L509DD4
    MOV     EDX,[DWORD d0724918h]
    MOV     ECX,[DWORD d072376Ch]
    MOV     ESI,[DWORD EBP+0Ch]
    XOR     EDX,EAX
    XOR     ECX,EAX
    PUSH    ESI
    PUSH    EDX
    XOR     EDI,ECX
    CALL    sub_509E20
    ADD     ESI,4
    PUSH    ESI
    PUSH    EDI
    CALL    sub_509E20
    ADD     ESP,010h
    POP     EDI
    POP     ESI
    POP     EBX
    POP     EBP
    RET
endp
;############################### sub_509EF0 ####################################
proc sub_509EF0
    PUSH    EBP
    MOV     EBP,ESP
    PUSH    ECX
    MOV     CL,[BYTE EBP+0Ah]
    MOV     EAX,[DWORD EBP+0Ch]
    PUSH    EBX
    MOV     BL,[BYTE EBP+0Bh]
    XOR     CL,AH
    PUSH    ESI
    XOR     CL,BL
    MOV     EBX,[DWORD EBP+8]
    MOV     DL,BH
    MOV     [BYTE EBP-4],CL
    MOV     ESI,[DWORD EBP-4]
    XOR     DL,AL
    PUSH    EDI
    XOR     DL,BL
    PUSH    ESI
    PUSH    EDX
    CALL    sub_50A0E0
    MOV     [BYTE EBP+0Ch],AL
    MOV     EDI,[DWORD EBP+0Ch]
    PUSH    EDI
    PUSH    ESI
    CALL    sub_50A080
    MOV     CL,[BYTE EBP+0Ch]
    PUSH    EDI
    PUSH    EBX
    MOV     [BYTE EBP-4],AL
    MOV     [BYTE EBP+0Dh],CL
    MOV     [BYTE EBP+0Eh],AL
    CALL    sub_50A080
    MOV     EDX,[DWORD EBP-4]
    MOV     [BYTE EBP+0Ch],AL
    MOV     EAX,[DWORD EBP+0Bh]
    PUSH    EDX
    PUSH    EAX
    CALL    sub_50A0E0
    ADD     ESP,020h
    MOV     [BYTE EBP+0Fh],AL
    MOV     EAX,[DWORD EBP+0Ch]
    POP     EDI
    POP     ESI
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_509FE0 ####################################
proc sub_509FE0
    PUSH    EBP
    MOV     EBP,ESP
    MOV     EAX,[DWORD EBP+8]
    MOV     CL,[BYTE EAX]
    MOV     DL,[BYTE EAX+1]
    INC     EAX
    MOV     [BYTE EBP+8],CL
    INC     EAX
    MOV     [BYTE EBP+9],DL
    MOV     CL,[BYTE EAX]
    MOV     DL,[BYTE EAX+1]
    MOV     [BYTE EBP+0Ah],CL
    MOV     [BYTE EBP+0Bh],DL
    MOV     EAX,[DWORD EBP+8]
    POP     EBP
    RET
endp
;############################### sub_509E50 ####################################
proc sub_509E50
    PUSH    EBP
    MOV     EBP,ESP
    PUSH    ECX
    PUSH    EBX
    PUSH    ESI
    MOV     ESI,[DWORD EBP+8]
    PUSH    EDI
    PUSH    ESI
    CALL    sub_509FE0
    ADD     ESI,4
    MOV     EBX,EAX
    PUSH    ESI
    CALL    sub_509FE0
    MOV     EDX,[DWORD d0724918h]
    MOV     ESI,[DWORD d072376Ch]
    XOR     EBX,EDX
    XOR     ESI,EAX
    ADD     ESP,8
    XOR     ESI,EBX
    MOV     EDI,OFFSET d0723728h
L509E85:
    MOV     EAX,[DWORD EDI]
    PUSH    EAX
    PUSH    ESI
    CALL    sub_509EF0
    ADD     EDI,4
    ADD     ESP,8
    XOR     EAX,EBX
    MOV     EBX,ESI
    CMP     EDI, OFFSET d0723748h
    MOV     ESI,EAX
		JB      L509E85    ;JL      L509E85
    MOV     ESI,[DWORD d0724914h]
    MOV     ECX,[DWORD d0724910h]
    XOR     EBX,EAX
    XOR     ECX,EAX
    XOR     EBX,ESI
    MOV     ESI,[DWORD EBP+0Ch]
    MOV     [DWORD EBP+8],ECX
    MOV     [DWORD EBP-4],EBX
    MOV     DL,[BYTE EBP+0Bh]
    LEA     EAX,[DWORD ESI+1]
    MOV     [BYTE ESI],CL
    MOV     CL,[BYTE EBP+0Ah]
    MOV     [BYTE EAX],CH
    INC     EAX
    POP     EDI
    MOV     [BYTE EAX],CL
    MOV     [BYTE EAX+1],DL
    LEA     EAX,[DWORD ESI+4]
    MOV     CL,[BYTE EBP-2]
    MOV     DL,[BYTE EBP-1]
    POP     ESI
    MOV     [BYTE EAX],BL
    INC     EAX
    MOV     [BYTE EAX],BH
    INC     EAX
    POP     EBX
    MOV     [BYTE EAX],CL
    MOV     [BYTE EAX+1],DL
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_50A080 ####################################
proc sub_50A080
    PUSH    EBP
    MOV     EBP,ESP
    MOV     EAX,[DWORD d06A453Ch]
    TEST    EAX,EAX
    JZ      L50A0BE
    XOR     ECX,ECX
    XOR     EAX,EAX
    PUSH    EBX
    XOR     EDX,EDX
L50A093:
    MOV     BL,DL
    ADD     BL,AL
    ADD     EAX,4
    CMP     EAX,0FFh
    MOV     [BYTE ECX+d074491Ch],BL
    JLE     L50A0AA
    XOR     EAX,EAX
    INC     EDX
L50A0AA:
    INC     ECX
    CMP     ECX,0100h
    JL      L50A093
    MOV     [DWORD d06A453Ch],0
    POP     EBX
L50A0BE:
    MOV     AL,[BYTE EBP+8]
    MOV     DL,[BYTE EBP+0Ch]
    ADD     AL,DL
    AND     EAX,0FFh
    MOV     AL,[BYTE EAX+d074491Ch]
    POP     EBP
    RET
endp
;############################### sub_50A0E0 ####################################
proc sub_50A0E0
    PUSH    EBP
    MOV     EBP,ESP
    MOV     EAX,[DWORD d06A453Ch]
    PUSH    EBX
    TEST    EAX,EAX
    JZ      L50A11D
    XOR     ECX,ECX
    XOR     EAX,EAX
    XOR     EDX,EDX
L50A0F3:
    MOV     BL,DL
    ADD     BL,AL
    ADD     EAX,4
    CMP     EAX,0FFh
    MOV     [BYTE ECX+d074491Ch],BL
    JLE     L50A10A
    XOR     EAX,EAX
    INC     EDX
L50A10A:
    INC     ECX
    CMP     ECX,0100h
    JL      L50A0F3
    MOV     [DWORD d06A453Ch],0
L50A11D:
    MOV     AL,[BYTE EBP+8]
    MOV     BL,[BYTE EBP+0Ch]
    ADD     AL,BL
    POP     EBX
    INC     AL
    AND     EAX,0FFh
    MOV     AL,[BYTE EAX+d074491Ch]
    POP     EBP
    RET
endp
;############################### sub_509F60 ####################################
proc sub_509F60
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,8
    MOV     AL,[BYTE EBP+0Ah]
    MOV     CL,[BYTE EBP+0Bh]
    XOR     AL,CL
    MOV     CL,[BYTE EBP+0Ch]
    MOV     [BYTE EBP-8],AL
    XOR     CL,AL
    MOV     EAX,[DWORD EBP+8]
    PUSH    EBX
    MOV     DL,AH
    PUSH    ECX
    XOR     DL,AL
    PUSH    EDX
    CALL    sub_50A0E0
    MOV     ECX,[DWORD EBP-8]
    MOV     BL,AL
    MOV     AL,[BYTE EBP+0Dh]
    XOR     AL,BL
    PUSH    EAX
    PUSH    ECX
    CALL    sub_50A080
    MOV     DL,[BYTE EBP+0Eh]
    MOV     [BYTE EBP-8],AL
    MOV     [BYTE EBP-2],AL
    MOV     EAX,[DWORD EBP+8]
    XOR     DL,BL
    MOV     [BYTE EBP-3],BL
    PUSH    EDX
    PUSH    EAX
    CALL    sub_50A080
    MOV     CL,[BYTE EBP+0Fh]
    MOV     DL,[BYTE EBP-8]
    XOR     CL,DL
    MOV     EDX,[DWORD EBP+0Bh]
    PUSH    ECX
    PUSH    EDX
    MOV     [BYTE EBP-4],AL
    CALL    sub_50A0E0
    ADD     ESP,020h
    MOV     [BYTE EBP-1],AL
    MOV     EAX,[DWORD EBP-4]
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_50A140 ####################################
proc sub_50A140
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,8
    MOV     EAX,[DWORD EBP+8]
    PUSH    EBX
    PUSH    ESI
    PUSH    EDI
    MOV     CL,[BYTE EAX]
    MOV     DL,[BYTE EAX+1]
    INC     EAX
    MOV     [BYTE EBP+8],CL
    INC     EAX
    MOV     [BYTE EBP+9],DL
    MOV     ESI,OFFSET d0723728h
    MOV     [DWORD EBP-8],8
    MOV     CL,[BYTE EAX]
    MOV     DL,[BYTE EAX+1]
    INC     EAX
    MOV     [BYTE EBP+0Ah],CL
    INC     EAX
    MOV     [BYTE EBP+0Bh],DL
    MOV     EDI,[DWORD EBP+8]
    MOV     CL,[BYTE EAX]
    MOV     DL,[BYTE EAX+1]
    INC     EAX
    MOV     [BYTE EBP-4],CL
    INC     EAX
    MOV     [BYTE EBP-3],DL
    MOV     CL,[BYTE EAX]
    MOV     DL,[BYTE EAX+1]
    MOV     [BYTE EBP-2],CL
    MOV     [BYTE EBP-1],DL
    MOV     EBX,[DWORD EBP-4]
    XOR     ECX,ECX
L50A192:
    XOR     ECX,EBX
    PUSH    ECX
    PUSH    EDI
    CALL    sub_509F60
    MOV     ECX,EDI
    MOV     EDI,EBX
    MOV     [DWORD EBP-4],EAX
    MOV     DL,[BYTE EBP-2]
    MOV     EBX,EAX
    MOV     [BYTE EBP+8],AL
    MOV     [BYTE EBP+9],AH
    MOV     EAX,[DWORD EBP+8]
    MOV     [DWORD ESI],EAX
    MOV     AL,[BYTE EBP-1]
    ADD     ESI,4
    MOV     [BYTE EBP+8],DL
    MOV     [BYTE EBP+9],AL
    MOV     EDX,[DWORD EBP+8]
    MOV     EAX,[DWORD EBP-8]
    MOV     [DWORD ESI],EDX
    ADD     ESP,8
    ADD     ESI,4
    DEC     EAX
    MOV     [DWORD EBP-8],EAX
    JNZ     L50A192
    MOV     EAX,[DWORD d0723748h]
    MOV     ECX,[DWORD d072374Ch]
    MOV     [BYTE EBP+8],AL
    MOV     [BYTE EBP+9],AH
    MOV     [BYTE EBP+0Ah],CL
    MOV     [BYTE EBP+0Bh],CH
    MOV     EAX,[DWORD EBP+8]
    MOV     ECX,[DWORD d0723754h]
    MOV     [DWORD d0724918h],EAX
    MOV     EAX,[DWORD d0723750h]
    MOV     [BYTE EBP+8],AL
    MOV     [BYTE EBP+9],AH
    MOV     EAX,[DWORD d0723758h]
    MOV     [BYTE EBP+0Ah],CL
    MOV     [BYTE EBP+0Bh],CH
    MOV     ECX,[DWORD EBP+8]
    MOV     [DWORD d072376Ch],ECX
    MOV     ECX,[DWORD d072375Ch]
    MOV     [BYTE EBP+8],AL
    MOV     [BYTE EBP+9],AH
    MOV     EAX,[DWORD d0723760h]
    MOV     [BYTE EBP+0Ah],CL
    MOV     [BYTE EBP+0Bh],CH
    MOV     ECX,[DWORD d0723764h]
    MOV     EDX,[DWORD EBP+8]
    MOV     [BYTE EBP+8],AL
    MOV     [BYTE EBP+9],AH
    MOV     [BYTE EBP+0Ah],CL
    MOV     [BYTE EBP+0Bh],CH
    MOV     EAX,[DWORD EBP+8]
    POP     EDI
    POP     ESI
    MOV     [DWORD d0724910h],EDX
    MOV     [DWORD d0724914h],EAX
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_4209E0 ####################################
proc funcB
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,018h
    LEA     EAX,[DWORD EBP-8]
    MOV     [BYTE EBP-8],012h
    PUSH    EAX
    MOV     [BYTE EBP-7],043h
    MOV     [BYTE EBP-6],09Fh
    MOV     [BYTE EBP-5],01Fh
    MOV     [BYTE EBP-4],0ABh
    MOV     [BYTE EBP-3],0FFh
    MOV     [BYTE EBP-2],03Ah
    MOV     [BYTE EBP-1],06Fh
    CALL    sub_50A140
    XOR     ECX,ECX
    MOV     EDX,[DWORD EBP+8]
    MOV     [DWORD EBP-0Fh],ECX
    LEA     EAX,[DWORD EBP-018h]
    MOV     [WORD EBP-0Bh],CX
    PUSH    EAX
    MOV     [BYTE EBP-9],CL
    LEA     ECX,[DWORD EBP-010h]
    PUSH    ECX
    MOV     [DWORD EBP-010h],EDX
    CALL    sub_509E50
    MOV     EAX,[DWORD EBP-018h]
    ADD     ESP,0Ch
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_420A40 ####################################
proc funcC
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,018h
    LEA     EAX,[DWORD EBP-8]
    MOV     [BYTE EBP-8],022h
    PUSH    EAX
    MOV     [BYTE EBP-7],043h
    MOV     [BYTE EBP-6],09Fh
    MOV     [BYTE EBP-5],01Fh
    MOV     [BYTE EBP-4],0ACh
    MOV     [BYTE EBP-3],0FFh
    MOV     [BYTE EBP-2],03Ah
    MOV     [BYTE EBP-1],06Fh
    CALL    sub_50A140
    XOR     ECX,ECX
    MOV     EDX,[DWORD EBP+8]
    MOV     [DWORD EBP-0Fh],ECX
    LEA     EAX,[DWORD EBP-018h]
    MOV     [WORD EBP-0Bh],CX
    PUSH    EAX
    MOV     [BYTE EBP-9],CL
    LEA     ECX,[DWORD EBP-010h]
    PUSH    ECX
    MOV     [DWORD EBP-010h],EDX
    CALL    sub_509DA0
    MOV     EAX,[DWORD EBP-018h]
    ADD     ESP,0Ch
    MOV     ESP,EBP
    POP     EBP
    RET
endp
end

