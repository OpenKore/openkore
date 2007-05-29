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
public C func9
public C funcA
dataseg
  d06DDD10h db 4014h DUP(0)
  d06E1E80h db 4014h DUP(0)
	d0723768h	dd 0
codeseg
;############################### sub_507CB0 ####################################
proc sub_507CB0
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,8
    PUSH    EBX
    MOV     EBX,[DWORD EBP+0Ch]
    TEST    EBX,EBX
    PUSH    EDI
    JZ      L507DB1
    MOV     EDI,[DWORD EBP+8]
    TEST    EDI,EDI
    JZ      L507DB1
    MOV     EAX,[DWORD EBX]
    PUSH    ESI
    CDQ
    SUB     EAX,EDX
    PUSH    EBX
    MOV     ESI,EAX
    MOV     EAX,[DWORD EBX+010h]
    SAR     ESI,1
    MOV     [DWORD d0723768h],EAX
    LEA     ECX,[DWORD EBP-8]
    LEA     EAX,[DWORD ESI+EDI]
    PUSH    ESI
    PUSH    ECX
    PUSH    EAX
    MOV     [DWORD EBP+0Ch],EAX
    CALL    sub_508070
    ADD     ESP,010h
    TEST    ESI,ESI
    JLE     L507D12
    LEA     ECX,[DWORD EBP-8]
    MOV     EAX,EDI
    SUB     ECX,EDI
    MOV     [DWORD EBP+8],ESI
L507D03:
    MOV     DL,[BYTE ECX+EAX]
    XOR     [BYTE EAX],DL
    MOV     EDX,[DWORD EBP+8]
    INC     EAX
    DEC     EDX
    MOV     [DWORD EBP+8],EDX
    JNZ     L507D03
L507D12:
    MOV     EAX,[DWORD EBX+0Ch]
    PUSH    EBX
    LEA     ECX,[DWORD EBP-8]
    PUSH    ESI
    PUSH    ECX
    PUSH    EDI
    MOV     [DWORD d0723768h],EAX
    CALL    sub_508070
    ADD     ESP,010h
    XOR     EAX,EAX
    TEST    ESI,ESI
    JLE     L507D3E
L507D2F:
    MOV     ECX,[DWORD EBP+0Ch]
    MOV     DL,[BYTE EBP+EAX-8]
    XOR     [BYTE ECX+EAX],DL
    INC     EAX
    CMP     EAX,ESI
    JL      L507D2F
L507D3E:
    MOV     EDX,[DWORD EBP+0Ch]
    MOV     EAX,[DWORD EBX+8]
    PUSH    EBX
    LEA     ECX,[DWORD EBP-8]
    PUSH    ESI
    PUSH    ECX
    PUSH    EDX
    MOV     [DWORD d0723768h],EAX
    CALL    sub_508070
    ADD     ESP,010h
    TEST    ESI,ESI
    JLE     L507D75
    LEA     ECX,[DWORD EBP-8]
    MOV     EAX,EDI
    SUB     ECX,EDI
    MOV     [DWORD EBP+8],ESI
L507D66:
    MOV     DL,[BYTE EAX+ECX]
    XOR     [BYTE EAX],DL
    MOV     EDX,[DWORD EBP+8]
    INC     EAX
    DEC     EDX
    MOV     [DWORD EBP+8],EDX
    JNZ     L507D66
L507D75:
    PUSH    EBX
    LEA     EAX,[DWORD EBP-8]
    PUSH    ESI
    PUSH    EAX
    PUSH    EDI
    MOV     [DWORD d0723768h],0
    CALL    sub_508070
    ADD     ESP,010h
    XOR     EAX,EAX
    TEST    ESI,ESI
    JLE     L507DA8
L507D94:
    MOV     ECX,[DWORD EBP+0Ch]
    MOV     DL,[BYTE EBP+EAX-8]
    MOV     BL,[BYTE ECX+EAX]
    XOR     BL,DL
    MOV     [BYTE ECX+EAX],BL
    INC     EAX
    CMP     EAX,ESI
    JL      L507D94
L507DA8:
    POP     ESI
    POP     EDI
    XOR     EAX,EAX
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET
L507DB1:
    POP     EDI
    OR      EAX,0FFFFFFFFh
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_508070 ####################################
proc sub_508070
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,8
    MOV     EAX,[DWORD EBP+010h]
    PUSH    EBX
    PUSH    ESI
    CMP     EAX,2
    PUSH    EDI
    JNZ     L508129
    MOV     EDI,[DWORD EBP+8]
    MOV     EDX,[DWORD d0723768h]
    XOR     ECX,ECX
    MOV     EAX,[DWORD EBP+0Ch]
    MOV     CL,[BYTE EDI]
    MOV     ESI,ECX
    MOV     ECX,[DWORD EBP+014h]
    SHL     EDX,8
    MOV     EBX,ECX
    ADD     EBX,EDX
    MOV     DL,[BYTE ESI+EBX+014h]
    MOV     BL,[BYTE EDI+1]
    XOR     DL,BL
    MOV     EBX,ECX
    MOV     [BYTE EAX+1],DL
    MOV     ESI,[DWORD d0723768h]
    INC     ESI
    XOR     EDX,EDX
    MOV     [DWORD d0723768h],ESI
    MOV     DL,[BYTE EAX+1]
    SHL     ESI,8
    ADD     EBX,ESI
    MOV     DL,[BYTE EDX+EBX+014h]
    MOV     BL,[BYTE EDI]
    XOR     DL,BL
    MOV     EDI,ECX
    MOV     [BYTE EAX],DL
    MOV     ESI,[DWORD d0723768h]
    INC     ESI
    XOR     EDX,EDX
    MOV     [DWORD d0723768h],ESI
    MOV     DL,[BYTE EAX]
    MOV     BL,[BYTE EAX+1]
    SHL     ESI,8
    ADD     EDI,ESI
    MOV     DL,[BYTE EDX+EDI+014h]
    POP     EDI
    XOR     BL,DL
    XOR     EDX,EDX
    MOV     [BYTE EAX+1],BL
    MOV     ESI,[DWORD d0723768h]
    INC     ESI
    MOV     [DWORD d0723768h],ESI
    MOV     DL,[BYTE EAX+1]
    SHL     ESI,8
    ADD     ECX,ESI
    POP     ESI
    POP     EBX
    MOV     CL,[BYTE EDX+ECX+014h]
    MOV     DL,[BYTE EAX]
    XOR     DL,CL
    MOV     [BYTE EAX],DL
    MOV     EAX,[DWORD d0723768h]
    INC     EAX
    MOV     [DWORD d0723768h],EAX
    XOR     EAX,EAX
    MOV     ESP,EBP
    POP     EBP
    RET
L508129:
    MOV     EBX,[DWORD EBP+014h]
    CDQ
    SUB     EAX,EDX
    PUSH    EBX
    MOV     ESI,EAX
    MOV     EAX,[DWORD EBP+8]
    SAR     ESI,1
    LEA     EDX,[DWORD EBP-8]
    PUSH    ESI
    PUSH    EDX
    PUSH    EAX
    CALL    sub_508070
    MOV     EDI,[DWORD EBP+0Ch]
    ADD     ESP,010h
    XOR     ECX,ECX
    TEST    ESI,ESI
    JLE     L508168
    MOV     EDX,[DWORD EBP+8]
    LEA     EAX,[DWORD ESI+EDI]
    SUB     EDX,EDI
L508156:
    MOV     BL,[BYTE EDX+EAX]
    XOR     BL,[BYTE EBP+ECX-8]
    INC     ECX
    MOV     [BYTE EAX],BL
    INC     EAX
    CMP     ECX,ESI
    JL      L508156
    MOV     EBX,[DWORD EBP+014h]
L508168:
    PUSH    EBX
    LEA     ECX,[DWORD EBP-8]
    LEA     EAX,[DWORD ESI+EDI]
    PUSH    ESI
    PUSH    ECX
    PUSH    EAX
    CALL    sub_508070
    ADD     ESP,010h
    XOR     ECX,ECX
    TEST    ESI,ESI
    JLE     L5081B5
    MOV     EDX,[DWORD EBP+8]
    LEA     EAX,[DWORD EBP-8]
    SUB     EDX,EAX
    MOV     EAX,EDI
    LEA     EBX,[DWORD EBP-8]
    MOV     [DWORD EBP+8],EDX
    SUB     EAX,EBX
    MOV     [DWORD EBP+0Ch],EAX
    JMP     L50819A
L508197:
    MOV     EDX,[DWORD EBP+8]
L50819A:
    MOV     BL,[BYTE EBP+ECX-8]
    LEA     EAX,[DWORD EBP+ECX-8]
    MOV     DL,[BYTE EDX+EAX]
    XOR     DL,BL
    MOV     EBX,[DWORD EBP+0Ch]
    INC     ECX
    CMP     ECX,ESI
    MOV     [BYTE EBX+EAX],DL
    JL      L508197
    MOV     EBX,[DWORD EBP+014h]
L5081B5:
    PUSH    EBX
    LEA     EAX,[DWORD EBP-8]
    PUSH    ESI
    PUSH    EAX
    PUSH    EDI
    CALL    sub_508070
    ADD     ESP,010h
    XOR     EAX,EAX
    TEST    ESI,ESI
    JLE     L5081D9
L5081CA:
    MOV     DL,[BYTE EBP+EAX-8]
    LEA     ECX,[DWORD ESI+EDI]
    XOR     [BYTE ECX+EAX],DL
    INC     EAX
    CMP     EAX,ESI
    JL      L5081CA
L5081D9:
    PUSH    EBX
    LEA     EAX,[DWORD EBP-8]
    PUSH    ESI
    PUSH    EAX
    LEA     EAX,[DWORD ESI+EDI]
    PUSH    EAX
    CALL    sub_508070
    ADD     ESP,010h
    TEST    ESI,ESI
    JLE     L508203
    LEA     ECX,[DWORD EBP-8]
    MOV     EAX,EDI
    SUB     ECX,EDI
L5081F6:
    MOV     DL,[BYTE ECX+EAX]
    MOV     BL,[BYTE EAX]
    XOR     BL,DL
    MOV     [BYTE EAX],BL
    INC     EAX
    DEC     ESI
    JNZ     L5081F6
L508203:
    POP     EDI
    POP     ESI
    XOR     EAX,EAX
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_507BB0 ####################################
proc sub_507BB0
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,8
    MOV     ECX,[DWORD EBP+0Ch]
    PUSH    EDI
    TEST    ECX,ECX
    JZ      L507C99
    MOV     EDI,[DWORD EBP+8]
    TEST    EDI,EDI
    JZ      L507C99
    MOV     [DWORD d0723768h],0
    MOV     EAX,[DWORD ECX]
    CDQ
    PUSH    EBX
    SUB     EAX,EDX
    PUSH    ESI
    MOV     ESI,EAX
    SAR     ESI,1
    PUSH    ECX
    LEA     EAX,[DWORD EBP-8]
    PUSH    ESI
    PUSH    EAX
    PUSH    EDI
    CALL    sub_508070
    ADD     ESP,010h
    XOR     EAX,EAX
    TEST    ESI,ESI
    JLE     L507C0B
    LEA     ECX,[DWORD ESI+EDI]
L507BFA:
    MOV     DL,[BYTE EBP+EAX-8]
    MOV     BL,[BYTE ECX+EAX]
    XOR     BL,DL
    MOV     [BYTE ECX+EAX],BL
    INC     EAX
    CMP     EAX,ESI
    JL      L507BFA
L507C0B:
    MOV     EAX,[DWORD EBP+0Ch]
    LEA     ECX,[DWORD EBP-8]
    PUSH    EAX
    LEA     EBX,[DWORD ESI+EDI]
    PUSH    ESI
    PUSH    ECX
    PUSH    EBX
    CALL    sub_508070
    ADD     ESP,010h
    TEST    ESI,ESI
    JLE     L507C3D
    LEA     ECX,[DWORD EBP-8]
    MOV     EAX,EDI
    SUB     ECX,EDI
    MOV     [DWORD EBP+8],ESI
L507C2E:
    MOV     DL,[BYTE ECX+EAX]
    XOR     [BYTE EAX],DL
    MOV     EDX,[DWORD EBP+8]
    INC     EAX
    DEC     EDX
    MOV     [DWORD EBP+8],EDX
    JNZ     L507C2E
L507C3D:
    MOV     EAX,[DWORD EBP+0Ch]
    LEA     ECX,[DWORD EBP-8]
    PUSH    EAX
    PUSH    ESI
    PUSH    ECX
    PUSH    EDI
    CALL    sub_508070
    ADD     ESP,010h
    XOR     EAX,EAX
    TEST    ESI,ESI
    JLE     L507C66
L507C55:
    MOV     DL,[BYTE EBP+EAX-8]
    MOV     CL,[BYTE EBX+EAX]
    XOR     CL,DL
    MOV     [BYTE EBX+EAX],CL
    INC     EAX
    CMP     EAX,ESI
    JL      L507C55
L507C66:
    MOV     EAX,[DWORD EBP+0Ch]
    LEA     ECX,[DWORD EBP-8]
    PUSH    EAX
    PUSH    ESI
    PUSH    ECX
    PUSH    EBX
    CALL    sub_508070
    ADD     ESP,010h
    TEST    ESI,ESI
    JLE     L507C90
    LEA     ECX,[DWORD EBP-8]
    MOV     EAX,EDI
    SUB     ECX,EDI
L507C83:
    MOV     DL,[BYTE EAX+ECX]
    MOV     BL,[BYTE EAX]
    XOR     BL,DL
    MOV     [BYTE EAX],BL
    INC     EAX
    DEC     ESI
    JNZ     L507C83
L507C90:
    POP     ESI
    POP     EBX
    XOR     EAX,EAX
    POP     EDI
    MOV     ESP,EBP
    POP     EBP
    RET
L507C99:
    OR      EAX,0FFFFFFFFh
    POP     EDI
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_507F00 ####################################
proc sub_507F00
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,8
    MOV     ECX,[DWORD EBP+8]
    MOV     EDX,1
    PUSH    EBX
    PUSH    ESI
    MOV     EAX,[DWORD ECX+4]
    MOV     BL,[BYTE ECX+1]
    SUB     EDX,EAX
    MOV     [BYTE EBP+8],BL
    SHL     EAX,0Ah
    MOV     ESI,EAX
    MOV     EAX,[DWORD EBP+8]
    AND     EAX,0FFh
    MOV     [DWORD EBP-8],EDX
    MOV     DL,[BYTE ECX]
    ADD     EAX,ESI
    PUSH    EDI
    AND     EBX,0FFh
    MOV     AL,[BYTE EAX+ECX+8]
    XOR     AL,DL
    AND     EDX,0FFh
    MOV     [BYTE EBP-4],AL
    MOV     EAX,[DWORD EBP-4]
    AND     EAX,0FFh
    ADD     EAX,ESI
    MOV     AL,[BYTE EAX+ECX+0108h]
    XOR     [BYTE EBP+8],AL
    MOV     EAX,[DWORD EBP+8]
    AND     EAX,0FFh
    ADD     EAX,ESI
    MOV     AL,[BYTE EAX+ECX+0208h]
    XOR     [BYTE EBP-4],AL
    MOV     EDI,[DWORD EBP-4]
    AND     EDI,0FFh
    LEA     EAX,[DWORD EDI+ESI]
    MOV     AL,[BYTE EAX+ECX+0308h]
    XOR     [BYTE EBP+8],AL
    MOV     EAX,[DWORD EBP-8]
    LEA     ESI,[DWORD EAX*4]
    ADD     EDX,ESI
    SHL     EDX,8
    ADD     EBX,EDX
    ADD     EDX,EDI
    MOV     DL,[BYTE EDX+ECX+8]
    MOV     AL,[BYTE EBX+ECX+8]
    LEA     EBX,[DWORD EBX+ECX+8]
    MOV     [BYTE EBX],DL
    XOR     EDX,EDX
    MOV     DL,[BYTE ECX]
    ADD     EDX,ESI
    SHL     EDX,8
    ADD     EDX,EDI
    MOV     [BYTE EDX+ECX+8],AL
    XOR     EDX,EDX
    MOV     DL,[BYTE ECX+1]
    INC     EDX
    AND     EDX,0800000FFh
    JNS     L507FC9
    DEC     EDX
    OR      EDX,0FFFFFF00h
    INC     EDX
L507FC9:
    POP     EDI
    POP     ESI
    TEST    DL,DL
    MOV     [BYTE ECX+1],DL
    POP     EBX
    JNZ     L507FE8
    XOR     EAX,EAX
    MOV     AL,[BYTE ECX]
    INC     EAX
    AND     EAX,0800000FFh
    JNS     L507FE6
    DEC     EAX
    OR      EAX,0FFFFFF00h
    INC     EAX
L507FE6:
    MOV     [BYTE ECX],AL
L507FE8:
    CMP     [BYTE ECX],3
    JBE     L507FFA
    MOV     EDX,[DWORD EBP-8]
    MOV     [BYTE ECX],0
    MOV     [BYTE ECX+1],0
    MOV     [DWORD ECX+4],EDX
L507FFA:
    MOV     AL,[BYTE EBP+8]
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_508210 ####################################
proc sub_508210
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,018h
    PUSH    ESI
    MOV     ESI,[DWORD EBP+014h]
    TEST    ESI,ESI
    JLE     L508239
    MOV     ECX,[DWORD EBP+8]
    MOV     EDX,ESI
L508223:
    XOR     EAX,EAX
L508225:
    MOV     [BYTE ECX+EAX],AL
    INC     EAX
    CMP     EAX,0100h
    JL      L508225
    ADD     ECX,0100h
    DEC     EDX
    JNZ     L508223
L508239:
    MOV     EAX,[DWORD EBP+010h]
    XOR     EDX,EDX
    TEST    ESI,ESI
    MOV     [DWORD EBP-010h],EAX
    MOV     [DWORD EBP-018h],EDX
    JLE     L508302
    XOR     ESI,ESI
    PUSH    EBX
    PUSH    EDI
    MOV     [DWORD EBP-0Ch],ESI
L508253:
    MOV     ECX,[DWORD EBP+8]
    MOV     [DWORD EBP-8],0
    ADD     ESI,ECX
    MOV     [DWORD EBP-014h],8
L508266:
    MOV     EAX,[DWORD EBP-8]
    XOR     ECX,ECX
    MOV     [DWORD EBP-4],EAX
L50826E:
    MOV     EAX,[DWORD EBP-4]
    AND     EAX,0800000FFh
    JNS     L50827F
    DEC     EAX
    OR      EAX,0FFFFFF00h
    INC     EAX
L50827F:
    MOV     EDI,[DWORD EBP-0Ch]
    XOR     EBX,EBX
    ADD     EAX,EDI
    MOV     EDI,[DWORD EBP+8]
    MOV     BL,[BYTE EAX+EDI]
    MOV     EDI,[DWORD EBP+0Ch]
    XOR     EAX,EAX
    MOV     AL,[BYTE EDX+EDI]
    MOV     EDI,[DWORD EBP-010h]
    ADD     EDI,EBX
    ADD     EDI,EAX
    AND     EDI,0800000FFh
    JNS     L5082AB
    DEC     EDI
    OR      EDI,0FFFFFF00h
    INC     EDI
L5082AB:
    MOV     BL,[BYTE ESI+EDI]
    MOV     AL,[BYTE ESI+ECX]
    MOV     [BYTE ESI+ECX],BL
    MOV     [BYTE ESI+EDI],AL
    LEA     EAX,[DWORD EDX+1]
    MOV     [DWORD EBP-010h],EDI
    MOV     EDI,[DWORD EBP-4]
    CDQ
    IDIV    [DWORD EBP+010h]
    INC     ECX
    INC     EDI
    CMP     ECX,0100h
    MOV     [DWORD EBP-4],EDI
    JL      L50826E
    MOV     EAX,[DWORD EBP-018h]
    MOV     EDI,[DWORD EBP-8]
    MOV     ECX,[DWORD EBP-014h]
    ADD     EDI,EAX
    DEC     ECX
    MOV     [DWORD EBP-8],EDI
    MOV     [DWORD EBP-014h],ECX
    JNZ     L508266
    MOV     ESI,[DWORD EBP-0Ch]
    MOV     ECX,[DWORD EBP+014h]
    INC     EAX
    ADD     ESI,0100h
    CMP     EAX,ECX
    MOV     [DWORD EBP-018h],EAX
    MOV     [DWORD EBP-0Ch],ESI
    JL      L508253
    POP     EDI
    POP     EBX
L508302:
    POP     ESI
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_507DC0 ####################################
proc sub_507DC0
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,080Ch
    MOV     EAX,[DWORD EBP+014h]
    PUSH    EBX
    CMP     EAX,4
    PUSH    EDI
    JL      L507EEB
    CMP     EAX,8
    JG      L507EEB
    MOV     EBX,[DWORD EBP+010h]
    TEST    EBX,EBX
    JZ      L507EEB
    MOV     EDI,[DWORD EBP+8]
    TEST    EDI,EDI
    JZ      L507EEB
    PUSH    ESI
    MOV     ESI,EAX
    IMUL    ESI,EAX
    LEA     ECX,[DWORD EBP-080Ch]
    MOV     [DWORD EBP-4],ESI
    TEST    ECX,ECX
    JZ      L507E4D
    MOV     EDX,[DWORD EBP+0Ch]
    PUSH    4
    PUSH    EDX
    LEA     EAX,[DWORD EBP-0804h]
    PUSH    EDI
    PUSH    EAX
    CALL    sub_508210
    MOV     ECX,[DWORD EBP+0Ch]
    PUSH    4
    PUSH    ECX
    LEA     EDX,[DWORD EBP-0404h]
    PUSH    EDI
    PUSH    EDX
    CALL    sub_508210
    MOV     EAX,[DWORD EBP+014h]
    ADD     ESP,020h
    MOV     [DWORD EBP-0808h],0
    MOV     [BYTE EBP-080Ch],0
    MOV     [BYTE EBP-080Bh],0
L507E4D:
    TEST    ESI,ESI
    JLE     L507EBF
    MOV     EAX,-014h
    LEA     EDI,[DWORD EBX+014h]
    SUB     EAX,EBX
    MOV     [DWORD EBP+0Ch],ESI
    MOV     [DWORD EBP+8],EAX
L507E61:
    XOR     EAX,EAX
L507E63:
    MOV     [BYTE EDI+EAX],AL
    INC     EAX
    CMP     EAX,0100h
    JL      L507E63
    XOR     ESI,ESI
L507E70:
    LEA     EAX,[DWORD EBP-080Ch]
    PUSH    EAX
    CALL    sub_507F00
    MOV     [BYTE EBP+010h],AL
    MOV     EAX,[DWORD EBP+8]
    MOV     EDX,[DWORD EBP+010h]
    ADD     EAX,EDI
    AND     EDX,0FFh
    MOV     CL,[BYTE EDI+ESI]
    ADD     EDX,EAX
    ADD     ESP,4
    INC     ESI
    LEA     EAX,[DWORD EDX+EBX+014h]
    CMP     ESI,0100h
    MOV     DL,[BYTE EAX]
    MOV     [BYTE EDI+ESI-1],DL
    MOV     [BYTE EAX],CL
    JL      L507E70
    MOV     EAX,[DWORD EBP+0Ch]
    ADD     EDI,0100h
    DEC     EAX
    MOV     [DWORD EBP+0Ch],EAX
    JNZ     L507E61
    MOV     ESI,[DWORD EBP-4]
    MOV     EAX,[DWORD EBP+014h]
L507EBF:
    MOV     [DWORD EBX],EAX
    MOV     EAX,ESI
    CDQ
    AND     EDX,3
    POP     ESI
    ADD     EAX,EDX
    MOV     [DWORD EBX+4],0
    SAR     EAX,2
    MOV     [DWORD EBX+8],EAX
    POP     EDI
    LEA     ECX,[DWORD EAX+EAX*2]
    LEA     EDX,[DWORD EAX+EAX]
    MOV     [DWORD EBX+010h],ECX
    MOV     [DWORD EBX+0Ch],EDX
    XOR     EAX,EAX
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET
L507EEB:
    POP     EDI
    OR      EAX,0FFFFFFFFh
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_4208C0 ####################################
proc func9
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,018h
    MOV     AL,0F2h
    PUSH    8
    MOV     [BYTE EBP-017h],AL
    MOV     [BYTE EBP-012h],AL
    PUSH    offset d06E1E80h
    LEA     EAX,[DWORD EBP-018h]
    PUSH    010h
    PUSH    EAX
    MOV     [BYTE EBP-018h],040h
    MOV     [BYTE EBP-016h],041h
    MOV     [BYTE EBP-015h],0B2h
    MOV     [BYTE EBP-014h],069h
    MOV     [BYTE EBP-013h],0F6h
    MOV     [BYTE EBP-011h],0AFh
    MOV     [BYTE EBP-010h],063h
    MOV     [BYTE EBP-0Fh],0F4h
    MOV     [BYTE EBP-0Eh],05Dh
    MOV     [BYTE EBP-0Dh],0FFh
    MOV     [BYTE EBP-0Ch],0Eh
    MOV     [BYTE EBP-0Bh],01Ch
    MOV     [BYTE EBP-0Ah],011h
    MOV     [BYTE EBP-9],09Bh
    CALL    sub_507DC0
    MOV     EDX,[DWORD EBP+8]
    XOR     ECX,ECX
    MOV     [DWORD EBP-7],ECX
    LEA     EAX,[DWORD EBP-8]
    MOV     [WORD EBP-3],CX
    PUSH    offset d06E1E80h
    PUSH    EAX
    MOV     [BYTE EBP-1],CL
    MOV     [DWORD EBP-8],EDX
    CALL    sub_507BB0
    MOV     EAX,[DWORD EBP-8]
    ADD     ESP,018h
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_420950 ####################################
proc funcA
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,018h
    PUSH    8
    PUSH    offset d06DDD10h
    LEA     EAX,[DWORD EBP-018h]
    PUSH    010h
    PUSH    EAX
    MOV     [BYTE EBP-018h],040h
    MOV     [BYTE EBP-017h],0F2h
    MOV     [BYTE EBP-016h],041h
    MOV     [BYTE EBP-015h],0B2h
    MOV     [BYTE EBP-014h],069h
    MOV     [BYTE EBP-013h],0F6h
    MOV     [BYTE EBP-012h],0F1h
    MOV     [BYTE EBP-011h],0A5h
    MOV     [BYTE EBP-010h],063h
    MOV     [BYTE EBP-0Fh],0F4h
    MOV     [BYTE EBP-0Eh],05Dh
    MOV     [BYTE EBP-0Dh],0FFh
    MOV     [BYTE EBP-0Ch],0Eh
    MOV     [BYTE EBP-0Bh],01Ch
    MOV     [BYTE EBP-0Ah],011h
    MOV     [BYTE EBP-9],09Bh
    CALL    sub_507DC0
    MOV     EDX,[DWORD EBP+8]
    XOR     ECX,ECX
    MOV     [DWORD EBP-7],ECX
    LEA     EAX,[DWORD EBP-8]
    MOV     [WORD EBP-3],CX
    PUSH    offset d06DDD10h
    PUSH    EAX
    MOV     [BYTE EBP-1],CL
    MOV     [DWORD EBP-8],EDX
    CALL    sub_507CB0
    MOV     EAX,[DWORD EBP-8]
    ADD     ESP,018h
    MOV     ESP,EBP
    POP     EBP
    RET
endp
end

