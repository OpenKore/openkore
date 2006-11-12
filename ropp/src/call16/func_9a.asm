section .data use32 CLASS=data
  d0723768h dd 0
section .bss use32 CLASS=bss
; Please check a dup block
  d06DDD10h RESB 4014h
  d06E1E80h RESB 4014h
section .code use32 CLASS=code
;############################### sub_4208C0 ####################################
global _func9
_func9:
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,018h
    MOV     AL,0F2h
    PUSH    8
    MOV     byte [EBP-017h],AL
    MOV     byte [EBP-012h],AL
    PUSH    d06E1E80h
    LEA     EAX,[EBP-018h]
    PUSH    010h
    PUSH    EAX
    MOV     byte [EBP-018h],040h
    MOV     byte [EBP-016h],041h
    MOV     byte [EBP-015h],0B2h
    MOV     byte [EBP-014h],069h
    MOV     byte [EBP-013h],0F6h
    MOV     byte [EBP-011h],0AFh
    MOV     byte [EBP-010h],063h
    MOV     byte [EBP-0Fh],0F4h
    MOV     byte [EBP-0Eh],05Dh
    MOV     byte [EBP-0Dh],0FFh
    MOV     byte [EBP-0Ch],0Eh
    MOV     byte [EBP-0Bh],01Ch
    MOV     byte [EBP-0Ah],011h
    MOV     byte [EBP-9],09Bh
    CALL    sub_507DC0
    MOV     EDX,dword [EBP+8]
    XOR     ECX,ECX
    MOV     dword [EBP-7],ECX
    LEA     EAX,[EBP-8]
    MOV     word [EBP-3],CX
    PUSH    d06E1E80h
    PUSH    EAX
    MOV     byte [EBP-1],CL
    MOV     dword [EBP-8],EDX
    CALL    sub_507BB0
    MOV     EAX,dword [EBP-8]
    ADD     ESP,018h
    MOV     ESP,EBP
    POP     EBP
    RET

;############################### sub_420950 ####################################
global _funcA
_funcA:
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,018h
    PUSH    8
    PUSH    d06DDD10h
    LEA     EAX,[EBP-018h]
    PUSH    010h
    PUSH    EAX
    MOV     byte [EBP-018h],040h
    MOV     byte [EBP-017h],0F2h
    MOV     byte [EBP-016h],041h
    MOV     byte [EBP-015h],0B2h
    MOV     byte [EBP-014h],069h
    MOV     byte [EBP-013h],0F6h
    MOV     byte [EBP-012h],0F1h
    MOV     byte [EBP-011h],0A5h
    MOV     byte [EBP-010h],063h
    MOV     byte [EBP-0Fh],0F4h
    MOV     byte [EBP-0Eh],05Dh
    MOV     byte [EBP-0Dh],0FFh
    MOV     byte [EBP-0Ch],0Eh
    MOV     byte [EBP-0Bh],01Ch
    MOV     byte [EBP-0Ah],011h
    MOV     byte [EBP-9],09Bh
    CALL    sub_507DC0
    MOV     EDX,dword [EBP+8]
    XOR     ECX,ECX
    MOV     dword [EBP-7],ECX
    LEA     EAX,[EBP-8]
    MOV     word [EBP-3],CX
    PUSH    d06DDD10h
    PUSH    EAX
    MOV     byte [EBP-1],CL
    MOV     dword [EBP-8],EDX
    CALL    .sub_507CB0
    MOV     EAX,dword [EBP-8]
    ADD     ESP,018h
    MOV     ESP,EBP
    POP     EBP
    RET

;############################### sub_507CB0 ####################################
.sub_507CB0:
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,8
    PUSH    EBX
    MOV     EBX,dword [EBP+0Ch]
    TEST    EBX,EBX
    PUSH    EDI
    JZ      near .L507DB1
    MOV     EDI,dword [EBP+8]
    TEST    EDI,EDI
    JZ      near .L507DB1
    MOV     EAX,dword [EBX]
    PUSH    ESI
    CDQ
    SUB     EAX,EDX
    PUSH    EBX
    MOV     ESI,EAX
    MOV     EAX,dword [EBX+010h]
    SAR     ESI,1
    MOV     dword [d0723768h],EAX
    LEA     ECX,[EBP-8]
    LEA     EAX,[ESI+EDI]
    PUSH    ESI
    PUSH    ECX
    PUSH    EAX
    MOV     dword [EBP+0Ch],EAX
    CALL    sub_508070
    ADD     ESP,010h
    TEST    ESI,ESI
    JLE     .L507D12
    LEA     ECX,[EBP-8]
    MOV     EAX,EDI
    SUB     ECX,EDI
    MOV     dword [EBP+8],ESI
.L507D03:
    MOV     DL,byte [ECX+EAX]
    XOR     byte [EAX],DL
    MOV     EDX,dword [EBP+8]
    INC     EAX
    DEC     EDX
    MOV     dword [EBP+8],EDX
    JNZ     .L507D03
.L507D12:
    MOV     EAX,dword [EBX+0Ch]
    PUSH    EBX
    LEA     ECX,[EBP-8]
    PUSH    ESI
    PUSH    ECX
    PUSH    EDI
    MOV     dword [d0723768h],EAX
    CALL    sub_508070
    ADD     ESP,010h
    XOR     EAX,EAX
    TEST    ESI,ESI
    JLE     .L507D3E
.L507D2F:
    MOV     ECX,dword [EBP+0Ch]
    MOV     DL,byte [EBP+EAX-8]
    XOR     byte [ECX+EAX],DL
    INC     EAX
    CMP     EAX,ESI
    JL      .L507D2F
.L507D3E:
    MOV     EDX,dword [EBP+0Ch]
    MOV     EAX,dword [EBX+8]
    PUSH    EBX
    LEA     ECX,[EBP-8]
    PUSH    ESI
    PUSH    ECX
    PUSH    EDX
    MOV     dword [d0723768h],EAX
    CALL    sub_508070
    ADD     ESP,010h
    TEST    ESI,ESI
    JLE     .L507D75
    LEA     ECX,[EBP-8]
    MOV     EAX,EDI
    SUB     ECX,EDI
    MOV     dword [EBP+8],ESI
.L507D66:
    MOV     DL,byte [EAX+ECX]
    XOR     byte [EAX],DL
    MOV     EDX,dword [EBP+8]
    INC     EAX
    DEC     EDX
    MOV     dword [EBP+8],EDX
    JNZ     .L507D66
.L507D75:
    PUSH    EBX
    LEA     EAX,[EBP-8]
    PUSH    ESI
    PUSH    EAX
    PUSH    EDI
    MOV     dword [d0723768h],0
    CALL    sub_508070
    ADD     ESP,010h
    XOR     EAX,EAX
    TEST    ESI,ESI
    JLE     .L507DA8
.L507D94:
    MOV     ECX,dword [EBP+0Ch]
    MOV     DL,byte [EBP+EAX-8]
    MOV     BL,byte [ECX+EAX]
    XOR     BL,DL
    MOV     byte [ECX+EAX],BL
    INC     EAX
    CMP     EAX,ESI
    JL      .L507D94
.L507DA8:
    POP     ESI
    POP     EDI
    XOR     EAX,EAX
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET
.L507DB1:
    POP     EDI
    OR      EAX,0FFFFFFFFh
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET

;############################### sub_508070 ####################################
sub_508070:
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,8
    MOV     EAX,dword [EBP+010h]
    PUSH    EBX
    PUSH    ESI
    CMP     EAX,2
    PUSH    EDI
    JNZ     near .L508129
    MOV     EDI,dword [EBP+8]
    MOV     EDX,dword [d0723768h]
    XOR     ECX,ECX
    MOV     EAX,dword [EBP+0Ch]
    MOV     CL,byte [EDI]
    MOV     ESI,ECX
    MOV     ECX,dword [EBP+014h]
    SHL     EDX,8
    MOV     EBX,ECX
    ADD     EBX,EDX
    MOV     DL,byte [ESI+EBX+014h]
    MOV     BL,byte [EDI+1]
    XOR     DL,BL
    MOV     EBX,ECX
    MOV     byte [EAX+1],DL
    MOV     ESI,dword [d0723768h]
    INC     ESI
    XOR     EDX,EDX
    MOV     dword [d0723768h],ESI
    MOV     DL,byte [EAX+1]
    SHL     ESI,8
    ADD     EBX,ESI
    MOV     DL,byte [EDX+EBX+014h]
    MOV     BL,byte [EDI]
    XOR     DL,BL
    MOV     EDI,ECX
    MOV     byte [EAX],DL
    MOV     ESI,dword [d0723768h]
    INC     ESI
    XOR     EDX,EDX
    MOV     dword [d0723768h],ESI
    MOV     DL,byte [EAX]
    MOV     BL,byte [EAX+1]
    SHL     ESI,8
    ADD     EDI,ESI
    MOV     DL,byte [EDX+EDI+014h]
    POP     EDI
    XOR     BL,DL
    XOR     EDX,EDX
    MOV     byte [EAX+1],BL
    MOV     ESI,dword [d0723768h]
    INC     ESI
    MOV     dword [d0723768h],ESI
    MOV     DL,byte [EAX+1]
    SHL     ESI,8
    ADD     ECX,ESI
    POP     ESI
    POP     EBX
    MOV     CL,byte [EDX+ECX+014h]
    MOV     DL,byte [EAX]
    XOR     DL,CL
    MOV     byte [EAX],DL
    MOV     EAX,dword [d0723768h]
    INC     EAX
    MOV     dword [d0723768h],EAX
    XOR     EAX,EAX
    MOV     ESP,EBP
    POP     EBP
    RET
.L508129:
    MOV     EBX,dword [EBP+014h]
    CDQ
    SUB     EAX,EDX
    PUSH    EBX
    MOV     ESI,EAX
    MOV     EAX,dword [EBP+8]
    SAR     ESI,1
    LEA     EDX,[EBP-8]
    PUSH    ESI
    PUSH    EDX
    PUSH    EAX
    CALL    sub_508070
    MOV     EDI,dword [EBP+0Ch]
    ADD     ESP,010h
    XOR     ECX,ECX
    TEST    ESI,ESI
    JLE     .L508168
    MOV     EDX,dword [EBP+8]
    LEA     EAX,[ESI+EDI]
    SUB     EDX,EDI
.L508156:
    MOV     BL,byte [EDX+EAX]
    XOR     BL,byte [EBP+ECX-8]
    INC     ECX
    MOV     byte [EAX],BL
    INC     EAX
    CMP     ECX,ESI
    JL      .L508156
    MOV     EBX,dword [EBP+014h]
.L508168:
    PUSH    EBX
    LEA     ECX,[EBP-8]
    LEA     EAX,[ESI+EDI]
    PUSH    ESI
    PUSH    ECX
    PUSH    EAX
    CALL    sub_508070
    ADD     ESP,010h
    XOR     ECX,ECX
    TEST    ESI,ESI
    JLE     .L5081B5
    MOV     EDX,dword [EBP+8]
    LEA     EAX,[EBP-8]
    SUB     EDX,EAX
    MOV     EAX,EDI
    LEA     EBX,[EBP-8]
    MOV     dword [EBP+8],EDX
    SUB     EAX,EBX
    MOV     dword [EBP+0Ch],EAX
    JMP     .L50819A
.L508197:
    MOV     EDX,dword [EBP+8]
.L50819A:
    MOV     BL,byte [EBP+ECX-8]
    LEA     EAX,[EBP+ECX-8]
    MOV     DL,byte [EDX+EAX]
    XOR     DL,BL
    MOV     EBX,dword [EBP+0Ch]
    INC     ECX
    CMP     ECX,ESI
    MOV     byte [EBX+EAX],DL
    JL      .L508197
    MOV     EBX,dword [EBP+014h]
.L5081B5:
    PUSH    EBX
    LEA     EAX,[EBP-8]
    PUSH    ESI
    PUSH    EAX
    PUSH    EDI
    CALL    sub_508070
    ADD     ESP,010h
    XOR     EAX,EAX
    TEST    ESI,ESI
    JLE     .L5081D9
.L5081CA:
    MOV     DL,byte [EBP+EAX-8]
    LEA     ECX,[ESI+EDI]
    XOR     byte [ECX+EAX],DL
    INC     EAX
    CMP     EAX,ESI
    JL      .L5081CA
.L5081D9:
    PUSH    EBX
    LEA     EAX,[EBP-8]
    PUSH    ESI
    PUSH    EAX
    LEA     EAX,[ESI+EDI]
    PUSH    EAX
    CALL    sub_508070
    ADD     ESP,010h
    TEST    ESI,ESI
    JLE     .L508203
    LEA     ECX,[EBP-8]
    MOV     EAX,EDI
    SUB     ECX,EDI
.L5081F6:
    MOV     DL,byte [ECX+EAX]
    MOV     BL,byte [EAX]
    XOR     BL,DL
    MOV     byte [EAX],BL
    INC     EAX
    DEC     ESI
    JNZ     .L5081F6
.L508203:
    POP     EDI
    POP     ESI
    XOR     EAX,EAX
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET

;############################### sub_507BB0 ####################################
sub_507BB0:
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,8
    MOV     ECX,dword [EBP+0Ch]
    PUSH    EDI
    TEST    ECX,ECX
    JZ      near .L507C99
    MOV     EDI,dword [EBP+8]
    TEST    EDI,EDI
    JZ      near .L507C99
    MOV     dword [d0723768h],0
    MOV     EAX,dword [ECX]
    CDQ
    PUSH    EBX
    SUB     EAX,EDX
    PUSH    ESI
    MOV     ESI,EAX
    SAR     ESI,1
    PUSH    ECX
    LEA     EAX,[EBP-8]
    PUSH    ESI
    PUSH    EAX
    PUSH    EDI
    CALL    sub_508070
    ADD     ESP,010h
    XOR     EAX,EAX
    TEST    ESI,ESI
    JLE     .L507C0B
    LEA     ECX,[ESI+EDI]
.L507BFA:
    MOV     DL,byte [EBP+EAX-8]
    MOV     BL,byte [ECX+EAX]
    XOR     BL,DL
    MOV     byte [ECX+EAX],BL
    INC     EAX
    CMP     EAX,ESI
    JL      .L507BFA
.L507C0B:
    MOV     EAX,dword [EBP+0Ch]
    LEA     ECX,[EBP-8]
    PUSH    EAX
    LEA     EBX,[ESI+EDI]
    PUSH    ESI
    PUSH    ECX
    PUSH    EBX
    CALL    sub_508070
    ADD     ESP,010h
    TEST    ESI,ESI
    JLE     .L507C3D
    LEA     ECX,[EBP-8]
    MOV     EAX,EDI
    SUB     ECX,EDI
    MOV     dword [EBP+8],ESI
.L507C2E:
    MOV     DL,byte [ECX+EAX]
    XOR     byte [EAX],DL
    MOV     EDX,dword [EBP+8]
    INC     EAX
    DEC     EDX
    MOV     dword [EBP+8],EDX
    JNZ     .L507C2E
.L507C3D:
    MOV     EAX,dword [EBP+0Ch]
    LEA     ECX,[EBP-8]
    PUSH    EAX
    PUSH    ESI
    PUSH    ECX
    PUSH    EDI
    CALL    sub_508070
    ADD     ESP,010h
    XOR     EAX,EAX
    TEST    ESI,ESI
    JLE     .L507C66
.L507C55:
    MOV     DL,byte [EBP+EAX-8]
    MOV     CL,byte [EBX+EAX]
    XOR     CL,DL
    MOV     byte [EBX+EAX],CL
    INC     EAX
    CMP     EAX,ESI
    JL      .L507C55
.L507C66:
    MOV     EAX,dword [EBP+0Ch]
    LEA     ECX,[EBP-8]
    PUSH    EAX
    PUSH    ESI
    PUSH    ECX
    PUSH    EBX
    CALL    sub_508070
    ADD     ESP,010h
    TEST    ESI,ESI
    JLE     .L507C90
    LEA     ECX,[EBP-8]
    MOV     EAX,EDI
    SUB     ECX,EDI
.L507C83:
    MOV     DL,byte [EAX+ECX]
    MOV     BL,byte [EAX]
    XOR     BL,DL
    MOV     byte [EAX],BL
    INC     EAX
    DEC     ESI
    JNZ     .L507C83
.L507C90:
    POP     ESI
    POP     EBX
    XOR     EAX,EAX
    POP     EDI
    MOV     ESP,EBP
    POP     EBP
    RET
.L507C99:
    OR      EAX,0FFFFFFFFh
    POP     EDI
    MOV     ESP,EBP
    POP     EBP
    RET

;############################### sub_507F00 ####################################
sub_507F00:
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,8
    MOV     ECX,dword [EBP+8]
    MOV     EDX,1
    PUSH    EBX
    PUSH    ESI
    MOV     EAX,dword [ECX+4]
    MOV     BL,byte [ECX+1]
    SUB     EDX,EAX
    MOV     byte [EBP+8],BL
    SHL     EAX,0Ah
    MOV     ESI,EAX
    MOV     EAX,dword [EBP+8]
    AND     EAX,0FFh
    MOV     dword [EBP-8],EDX
    MOV     DL,byte [ECX]
    ADD     EAX,ESI
    PUSH    EDI
    AND     EBX,0FFh
    MOV     AL,byte [EAX+ECX+8]
    XOR     AL,DL
    AND     EDX,0FFh
    MOV     byte [EBP-4],AL
    MOV     EAX,dword [EBP-4]
    AND     EAX,0FFh
    ADD     EAX,ESI
    MOV     AL,byte [EAX+ECX+0108h]
    XOR     byte [EBP+8],AL
    MOV     EAX,dword [EBP+8]
    AND     EAX,0FFh
    ADD     EAX,ESI
    MOV     AL,byte [EAX+ECX+0208h]
    XOR     byte [EBP-4],AL
    MOV     EDI,dword [EBP-4]
    AND     EDI,0FFh
    LEA     EAX,[EDI+ESI]
    MOV     AL,byte [EAX+ECX+0308h]
    XOR     byte [EBP+8],AL
    MOV     EAX,dword [EBP-8]
    LEA     ESI,[EAX*4]
    ADD     EDX,ESI
    SHL     EDX,8
    ADD     EBX,EDX
    ADD     EDX,EDI
    MOV     DL,byte [EDX+ECX+8]
    MOV     AL,byte [EBX+ECX+8]
    LEA     EBX,[EBX+ECX+8]
    MOV     byte [EBX],DL
    XOR     EDX,EDX
    MOV     DL,byte [ECX]
    ADD     EDX,ESI
    SHL     EDX,8
    ADD     EDX,EDI
    MOV     byte [EDX+ECX+8],AL
    XOR     EDX,EDX
    MOV     DL,byte [ECX+1]
    INC     EDX
    AND     EDX,0800000FFh
    JNS     .L507FC9
    DEC     EDX
    OR      EDX,0FFFFFF00h
    INC     EDX
.L507FC9:
    POP     EDI
    POP     ESI
    TEST    DL,DL
    MOV     byte [ECX+1],DL
    POP     EBX
    JNZ     .L507FE8
    XOR     EAX,EAX
    MOV     AL,byte [ECX]
    INC     EAX
    AND     EAX,0800000FFh
    JNS     .L507FE6
    DEC     EAX
    OR      EAX,0FFFFFF00h
    INC     EAX
.L507FE6:
    MOV     byte [ECX],AL
.L507FE8:
    CMP     byte [ECX],3
    JBE     .L507FFA
    MOV     EDX,dword [EBP-8]
    MOV     byte [ECX],0
    MOV     byte [ECX+1],0
    MOV     dword [ECX+4],EDX
.L507FFA:
    MOV     AL,byte [EBP+8]
    MOV     ESP,EBP
    POP     EBP
    RET

;############################### sub_508210 ####################################
sub_508210:
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,018h
    PUSH    ESI
    MOV     ESI,dword [EBP+014h]
    TEST    ESI,ESI
    JLE     .L508239
    MOV     ECX,dword [EBP+8]
    MOV     EDX,ESI
.L508223:
    XOR     EAX,EAX
.L508225:
    MOV     byte [ECX+EAX],AL
    INC     EAX
    CMP     EAX,0100h
    JL      .L508225
    ADD     ECX,0100h
    DEC     EDX
    JNZ     .L508223
.L508239:
    MOV     EAX,dword [EBP+010h]
    XOR     EDX,EDX
    TEST    ESI,ESI
    MOV     dword [EBP-010h],EAX
    MOV     dword [EBP-018h],EDX
    JLE     near .L508302
    XOR     ESI,ESI
    PUSH    EBX
    PUSH    EDI
    MOV     dword [EBP-0Ch],ESI
.L508253:
    MOV     ECX,dword [EBP+8]
    MOV     dword [EBP-8],0
    ADD     ESI,ECX
    MOV     dword [EBP-014h],8
.L508266:
    MOV     EAX,dword [EBP-8]
    XOR     ECX,ECX
    MOV     dword [EBP-4],EAX
.L50826E:
    MOV     EAX,dword [EBP-4]
    AND     EAX,0800000FFh
    JNS     .L50827F
    DEC     EAX
    OR      EAX,0FFFFFF00h
    INC     EAX
.L50827F:
    MOV     EDI,dword [EBP-0Ch]
    XOR     EBX,EBX
    ADD     EAX,EDI
    MOV     EDI,dword [EBP+8]
    MOV     BL,byte [EAX+EDI]
    MOV     EDI,dword [EBP+0Ch]
    XOR     EAX,EAX
    MOV     AL,byte [EDX+EDI]
    MOV     EDI,dword [EBP-010h]
    ADD     EDI,EBX
    ADD     EDI,EAX
    AND     EDI,0800000FFh
    JNS     .L5082AB
    DEC     EDI
    OR      EDI,0FFFFFF00h
    INC     EDI
.L5082AB:
    MOV     BL,byte [ESI+EDI]
    MOV     AL,byte [ESI+ECX]
    MOV     byte [ESI+ECX],BL
    MOV     byte [ESI+EDI],AL
    LEA     EAX,[EDX+1]
    MOV     dword [EBP-010h],EDI
    MOV     EDI,dword [EBP-4]
    CDQ
    IDIV    dword [EBP+010h]
    INC     ECX
    INC     EDI
    CMP     ECX,0100h
    MOV     dword [EBP-4],EDI
    JL      .L50826E
    MOV     EAX,dword [EBP-018h]
    MOV     EDI,dword [EBP-8]
    MOV     ECX,dword [EBP-014h]
    ADD     EDI,EAX
    DEC     ECX
    MOV     dword [EBP-8],EDI
    MOV     dword [EBP-014h],ECX
    JNZ     .L508266
    MOV     ESI,dword [EBP-0Ch]
    MOV     ECX,dword [EBP+014h]
    INC     EAX
    ADD     ESI,0100h
    CMP     EAX,ECX
    MOV     dword [EBP-018h],EAX
    MOV     dword [EBP-0Ch],ESI
    JL      .L508253
    POP     EDI
    POP     EBX
.L508302:
    POP     ESI
    MOV     ESP,EBP
    POP     EBP
    RET

;############################### sub_507DC0 ####################################
sub_507DC0:
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,080Ch
    MOV     EAX,dword [EBP+014h]
    PUSH    EBX
    CMP     EAX,4
    PUSH    EDI
    JL      near L507EEB
    CMP     EAX,8
    JG      near L507EEB
    MOV     EBX,dword [EBP+010h]
    TEST    EBX,EBX
    JZ      near L507EEB
    MOV     EDI,dword [EBP+8]
    TEST    EDI,EDI
    JZ      near L507EEB
    PUSH    ESI
    MOV     ESI,EAX
    IMUL    ESI,EAX
    LEA     ECX,[EBP-080Ch]
    MOV     dword [EBP-4],ESI
    TEST    ECX,ECX
    JZ      .L507E4D
    MOV     EDX,dword [EBP+0Ch]
    PUSH    4
    PUSH    EDX
    LEA     EAX,[EBP-0804h]
    PUSH    EDI
    PUSH    EAX
    CALL    sub_508210
    MOV     ECX,dword [EBP+0Ch]
    PUSH    4
    PUSH    ECX
    LEA     EDX,[EBP-0404h]
    PUSH    EDI
    PUSH    EDX
    CALL    sub_508210
    MOV     EAX,dword [EBP+014h]
    ADD     ESP,020h
    MOV     dword [EBP-0808h],0
    MOV     byte [EBP-080Ch],0
    MOV     byte [EBP-080Bh],0
.L507E4D:
    TEST    ESI,ESI
    JLE     near L507EBF
    MOV     EAX,-014h
    LEA     EDI,[EBX+014h]
    SUB     EAX,EBX
    MOV     dword [EBP+0Ch],ESI
    MOV     dword [EBP+8],EAX
.L507E61:
    XOR     EAX,EAX
.L507E63:
    MOV     byte [EDI+EAX],AL
    INC     EAX
    CMP     EAX,0100h
    JL      .L507E63
    XOR     ESI,ESI
.L507E70:
    LEA     EAX,[EBP-080Ch]
    PUSH    EAX
    CALL    sub_507F00
    MOV     byte [EBP+010h],AL
    MOV     EAX,dword [EBP+8]
    MOV     EDX,dword [EBP+010h]
    ADD     EAX,EDI
    AND     EDX,0FFh
    MOV     CL,byte [EDI+ESI]
    ADD     EDX,EAX
    ADD     ESP,4
    INC     ESI
    LEA     EAX,[EDX+EBX+014h]
    CMP     ESI,0100h
    MOV     DL,byte [EAX]
    MOV     byte [EDI+ESI-1],DL
    MOV     byte [EAX],CL
    JL      .L507E70
    MOV     EAX,dword [EBP+0Ch]
    ADD     EDI,0100h
    DEC     EAX
    MOV     dword [EBP+0Ch],EAX
    JNZ     .L507E61
    MOV     ESI,dword [EBP-4]
    MOV     EAX,dword [EBP+014h]
L507EBF:
    MOV     dword [EBX],EAX
    MOV     EAX,ESI
    CDQ
    AND     EDX,3
    POP     ESI
    ADD     EAX,EDX
    MOV     dword [EBX+4],0
    SAR     EAX,2
    MOV     dword [EBX+8],EAX
    POP     EDI
    LEA     ECX,[EAX+EAX*2]
    LEA     EDX,[EAX+EAX]
    MOV     dword [EBX+010h],ECX
    MOV     dword [EBX+0Ch],EDX
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

end

